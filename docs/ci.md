# CI, release and the main ruleset

## Jobs (`.github/workflows/ci.yml`)
| Job | What it runs |
|---|---|
| `changes` | Detects docs-only PRs (only `docs/**`, `changelog.d/**`, `*.md` changed). Always runs, a few seconds. |
| `unit` | Version script tests, `tests/run.gd`, boot smoke test. |
| `sim` | Balance sim `tools/sim.gd`. |
| `play` | Play smoke `tools/bench.gd` and the frame budget check. |
| `changelog-guard` | PRs only. Fails if the PR edits `CHANGELOG.md`, `core/build_info.gd` or `export_presets.cfg`, or changes game folders (core, data, world, render, ui, boot, audio, theme, fonts, content, assets, project.godot) without a `changelog.d/*.patch|minor.md` fragment. Label `no-changelog` waives the fragment rule. |
| `test` | Aggregate. Passes when every job above passed or was skipped. **This is the only required check.** |

Each engine job uses `.github/actions/setup-godot`, which restores the cached Godot binary and `.godot/imported`, then runs the import. Docs-only PRs skip `unit`, `sim` and `play` and `test` still reports green. A new push to a PR cancels its older run, and the `test` job then shows as skipped (`if: !cancelled()`), never as a false red; a real job failure still fails it. If a PR shows red, open the newest run on its head commit; runs on `main` are never cancelled. Thresholds (frame budget 150/300/250/1300, sim gates, script-error greps) are unchanged.

## Timings (GitHub-hosted, measured 2026-11-23)
- Before: one serial job, about 45 s to 90 s total, of which import about 8 s and the sim 4 s to 58 s.
- After (PR #203, cold import cache): `unit` about 18 s, `play` about 27 s, `sim` about 115 s, all in parallel; the run ends when `sim` does. Docs-only PRs: about 10 s. A warm-cache run was not measured; re-measure before claiming a gain. Expect the sim to be the critical path.

## Main ruleset
`.github/rulesets/main.json` is a copy of the live ruleset (repo Settings > Rules). It is active on the default branch and: blocks deleting `main`, blocks force pushes, requires the `test` status check with "up to date" off, requires no approvals and no pull request. Bypass: Repository admin role. Re-import it from that file if it is ever lost. Renaming or splitting `test` needs a ruleset change first.

## Release (`.github/workflows/release.yml`)
Runs on every push to `main` touching `changelog.d/`. It folds fragments into CHANGELOG.md, bumps `core/build_info.gd` and `export_presets.cfg`, and pushes `Release vX.Y.Z [skip ci]` to `main`. The default Actions token cannot pass the ruleset, so the job checks out and pushes with the repo secret **`RELEASE_TOKEN`**, a fine-grained personal access token owned by an admin (Contents: read and write, Plinky only). The admin bypass lets that push through. Never print or echo the token.

**Expiry: Dec 23, 2026.** After it expires the job only warns and fragments pile up for the next release; nothing else breaks. To renew: GitHub > Settings > Developer settings > Fine-grained tokens > regenerate (or create a new one with the same scope), then repo Settings > Secrets and variables > Actions > update `RELEASE_TOKEN`. Then run Actions > Release > Run workflow once.
