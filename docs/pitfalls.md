# Pitfalls

Read this before your first change. Each line is a mistake that has already cost a thread time. Red-check causes and fixes are in the table in [docs/ci.md](ci.md#reading-a-red-check-audit-2026-11-24); do not copy it here.

## Godot and code
- **Run `godot --headless --path . --import` once on a fresh checkout**, or the headless tests fail.
- **`--script` mode has no autoloads.** A tested script or tool must never name `Audio`, `EventBus`, `GameState`, `Save`, `Fx`, `Juice`, `Calendar` or `Banner`. Pass the node in, or route through `FxConfig` or a signal. Compile error text is in [ci.md](ci.md#reading-a-red-check-audit-2026-11-24).
- **Commit a `.uid` for every new `.gd` and `.gdshader`.** Without it `uid-guard` fails and Nathan's editor reports "class not declared" on pull.
- **Never commit `__pycache__/` or `*.pyc`.** They are ignored, but merges have pulled them in before. If one shows up in a diff, `git rm --cached` it.
- **Node ceiling is 1350** (the `play` job passes it to `tools/check_frame_budget.py`). Larkmoor sits near it (see [perf.md](perf.md)). Build long lists lazily, one row per visible item.
- **Shared tooltips are `Tip` and `TipHost`.** Never hand-roll a tooltip.
- **Toasts, banners and tips wait on `FxConfig.bloom_running`** while the ritual plays. A new popup that ignores it will fight the ritual.
- **All stat values are `BigNum`**, formatted only through `core/number_format.gd`. A float in a stat path is a bug even when it looks harmless.

## Process and git
- **Draft and conflicting PRs never run CI.** Merge `main` in, mark the PR ready, and enable auto-merge (`gh pr merge --auto --squash <PR>` or the GitHub tool).
- **Keep watching your PR until it merges.** Fix red checks and merge conflicts yourself. The stuck-PR watch (see [ci.md](ci.md)) flags PRs that stall, but it does not fix them.
- **Never edit the version, `CHANGELOG.md`, `core/build_info.gd` or `export_presets.cfg`.** Add a `changelog.d/<slug>.patch.md` or `.minor.md` fragment instead. `changelog-guard` checks this.
- **Two threads editing one file cause duplicates and conflicts** (HUD, upgrades menu, toast holds have all hit this). Name the owning thread in your brief and tell overlapping threads about each other.
- **Decision-log conflicts: keep both entries.** `docs/decisions/*.md` uses `merge=union`, so local merges keep both sides. Check the result if you edited an existing entry, since that is not append-only. Log new decisions in the matching topic file, see [decisions/README.md](decisions/README.md).
- **A cancelled run is not a failure.** A newer push cancels the older one and `test` shows skipped. Open the newest run on the head commit.

## PC and QA (Nathan's machine)
- **Never run anything inside `nateanderson-dev`.** The project lives in `C:\dev\Plinky`.
- **Auto mode on the PC blocks `gh pr merge`.** Merge from a cloud thread.
- **Nathan's save is off-limits.** Never touch `%APPDATA%\Godot\app_userdata\Plinky\save.json`.
- **Pull `main` after every merge, then stop the game, refocus the editor and press F5.** The editor runs the old code until then.
- **Before you explain a behaviour to Nathan, check the facts.** Verify in the code or ask the owning thread first.
