# CI, release and the main ruleset

## Jobs (`.github/workflows/ci.yml`)
| Job | What it runs |
|---|---|
| `changes` | Detects docs-only PRs (only `docs/**`, `changelog.d/**`, `*.md` changed). Also fails if `docs/decisions.md` grows past 20 lines (the log is split by topic). Always runs, a few seconds. |
| `unit` | Version script tests, `tests/run.gd`, boot smoke test. |
| `sim` | Balance sim `tools/sim.gd`. |
| `play` | Play smoke `tools/bench.gd` and the frame budget check. |
| `playtest` | Playtest bot `tools/playtest.gd` plays the first in-game hour of a fresh save (about 30 s), then `tools/check_playtest.py` judges the run. It fails on a script or script-call error (other engine messages are notes in the JSON), a stall in income, a frame over 150 ms (300 ms under the zone wipe), or a milestone past its deadline (Larkmoor, Bloom, Ember Quarry by minute 30). Thresholds live in `check_playtest.py`. |
| `changelog-guard` | PRs only. Fails if the PR edits `CHANGELOG.md`, `core/build_info.gd` or `export_presets.cfg`, or changes game folders (core, data, world, render, ui, boot, audio, theme, fonts, content, assets, project.godot) without a `changelog.d/*.patch|minor.md` fragment. Label `no-changelog` waives the fragment rule. |
| `uid-guard` | Fails if a tracked `.gd` or `.gdshader` has no `.uid` sidecar file in the checkout. Scenes (`.tscn`) are not checked: Godot keeps their uid in the file header, not in a sidecar. |
| `test` | Aggregate over every job above, `playtest` included. Passes when each passed or was skipped. **This is the only required check.** |

Each engine job uses `.github/actions/setup-godot`, which restores the cached Godot binary and `.godot/imported`, then runs the import. Docs-only PRs skip `unit`, `sim` and `play`. `sim` also skips when none of its inputs change (`core/`, `data/`, `content/`, `tools/sim.gd`, `.github/`), so art, render, world and UI PRs skip it too. `test` still reports green. A new push to a PR cancels its older run, and the `test` job then shows as skipped (`if: !cancelled()`), never as a false red; a real job failure still fails it. If a PR shows red, open the newest run on its head commit; runs on `main` are never cancelled. Thresholds (frame budget 150/300/250/1350, sim gates, script-error greps) are unchanged.

## Timings (GitHub-hosted, measured 2026-11-23)
- Before: one serial job, about 45 s to 90 s total, of which import about 8 s and the sim 4 s to 58 s.
- After (PR #203, cold import cache): `unit` about 18 s, `play` about 27 s, `sim` about 115 s, all in parallel; the run ends when `sim` does. Docs-only PRs: about 10 s. A warm-cache run was not measured; re-measure before claiming a gain. Expect the sim to be the critical path.
- Measured on main runs, 2026-11-24 (step times from the job log): "Balance sim" 4 min 12 s and 4 min 50 s; `setup-godot` about 16 s; `unit` about 35 s; `play` about 35 s. A cached Godot binary would save about 16 s, so the sim is the cost to cut, and the path filter above is how this PR cuts it.

## Main ruleset
`.github/rulesets/main.json` is a copy of the live ruleset (repo Settings > Rules). It is active on the default branch and: blocks deleting `main`, blocks force pushes, requires the `test` status check with "up to date" off, requires no approvals and no pull request. Bypass: Repository admin role. Re-import it from that file if it is ever lost. Renaming or splitting `test` needs a ruleset change first.

## Release (`.github/workflows/release.yml`)
Runs on every push to `main` touching `changelog.d/`. It folds fragments into CHANGELOG.md, bumps `core/build_info.gd` and `export_presets.cfg`, and pushes `Release vX.Y.Z [skip ci]` to `main`. The default Actions token cannot pass the ruleset, so the job checks out and pushes with the repo secret **`RELEASE_TOKEN`**, a fine-grained personal access token owned by an admin (Contents: read and write, Plinky only). The admin bypass lets that push through. Never print or echo the token.

**Expiry: Dec 23, 2026.** After it expires the Release run goes red with the message "Release push to main was refused", and fragments pile up for the next release; nothing else breaks. `.github/workflows/token-expiry-reminder.yml` opens one issue, assigned to the owner, from 2 Dec 2026, because GitHub does not report a PAT's expiry to workflows. To renew: GitHub > Settings > Developer settings > Fine-grained tokens > regenerate (or create a new one with the same scope), then repo Settings > Secrets and variables > Actions > update `RELEASE_TOKEN`. Then run Actions > Release > Run workflow once, and close the reminder issue. If the date changes, update `EXPIRES` in the reminder workflow.

**Public release gate.** Nothing in the repo pushes a tag. The Release workflow only pushes `Release vX.Y.Z [skip ci]` to `main`. In `build.yml`, the `publish` job creates the GitHub release (prerelease) for a `v*` tag, and it runs in the `public-release` environment. That environment has Nathan as a required reviewer, so a tag push waits for his approval before anything goes public. Manual Build runs only build and never publish. The environment's reviewer setting lives in repo settings, so check it there if the gate ever seems to skip.

## Reading a red check (audit 2026-11-24)
When a PR says "All checks have failed", open the failed job: its **Summary** tab and the red annotations now show the cause (`tools/ci_summary.py`). Causes seen so far:

| Cause | What it looks like | Fix |
|---|---|---|
| Real test failure | `FAIL [test_x.gd] ... (got A, expected B)` | The PR's owner fixes the test or the code. Most red runs are this. |
| Suite does not compile | `FAIL [test_x.gd] suite failed to load or compile`, `Compile Error: Failed to compile depended scripts` | Fix the script error above it. |
| Autoload named in a `--script` test | `Compile Error: Identifier not found: Audio` (also EventBus, GameState, Save, Fx, Juice) | `--script` mode has no autoloads: pass the node in, or look it up by `get_node` in the running game, never name the autoload in a tested script. |
| Missing `.uid` | `uid-guard`: `Missing <file>.uid` | Open the project in Godot once and commit the `.uid` file it creates. |
| `changelog-guard` | PR edits the version files, or game folders without a fragment | Add `changelog.d/<slug>.patch.md`, and revert version/CHANGELOG edits. |
| Perf gates | `NOT reached`, frame budget, node ceiling in the bench | Real regression: fix it, or raise the documented ceiling in docs/perf.md and ci.yml with a reason. |
| Superseded run | Run shows grey "cancelled", usually two runs on one commit seconds apart | Not a failure. A newer push cancelled it; `test` is skipped, not red. Open the newest run on the head commit. |
| Cancelled run on `main` | Grey run on a merge commit | Was a shared concurrency group cancelling the older queued run when merges landed close together. Each push to `main` now has its own group (its sha). |
| Release bot commit | `Release vX.Y.Z [skip ci]` has no checks | Expected: it only edits version files and runs no CI. Its own Release run is the check; look there. |
| `Preload file ... has no resource loaders` | Printed by the first `--import` step | Harmless noise (fonts preloaded before the first import). Not a failure; the test steps are the real gate. |
| Conflicting PR | No CI at all, `mergeable_state: dirty` | Merge main in. Draft and conflicting PRs never run CI. |
| Decision log too long | `changes` fails: `docs/decisions.md has N lines` (seen 4 times on 2026-11-24, on branches that still held the old monolith) | Merge main, then move new entries into `docs/decisions/<topic>.md`. |
| Release refused | `Release` run red: `Release push to main was refused` | Renew `RELEASE_TOKEN` (see Release above), then re-run the Release workflow. |

## Merge conflicts in the decision log
`.gitattributes` marks `docs/decisions.md` and `docs/decisions/*.md` as `merge=union`, so `git merge main` on your machine or in a cloud thread keeps both sides' appended entries without a conflict. It only works for local merges, and only for append-only edits; if you edited an existing entry, check the result. Union merge can also bring back lines that main removed, so after merging main run `wc -l docs/decisions.md`: it must stay at or under 20 lines.

## Stuck PR watch (`.github/workflows/stuck-pr-watch.yml`)
Runs at :07, :22, :37 and :52 past each hour, from `main`. The schedule is off the hour because top-of-hour scheduled runs are the ones GitHub documents as most often delayed. As of 2026-11-24 the repo had produced no scheduled run of any workflow, only manual dispatches, so check the Actions tab for an `event: schedule` run after any change here. It looks at open, non-draft PRs quiet for 20 minutes and flags any with no check runs, a merge conflict, a failed or cancelled `test`, a run going for 30+ minutes, or auto-merge on while `test` has not passed. A `test` cancelled on the current head commit is re-run once automatically (`run_attempt` 1 only, so it cannot loop); a second cancel is left to the owner. Each flagged PR gets one comment, updated in place, and the run writes a summary table. The owning thread fixes the PR or closes it. The workflow only takes effect once it is on `main`; test it with Actions > Stuck PR watch > Run workflow.

It does not merge main into PR branches. The ruleset has "up to date" off, so a PR behind main still merges once `test` passes. Only a real conflict blocks it. A branch update made with the default token would not start CI (GitHub does not trigger workflows from that token), so a rebase bot needs a GitHub App or PAT token, which is a decision for the repo owner.
