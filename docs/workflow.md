# Working process

How work moves from idea to a tested change on Nathan's PC. Every thread, human or Claude, follows this. Decided by Nathan, 2026-11-23.

## The five steps

1. **One cloud thread per task.** Branch from `main`, open a PR with a CHANGELOG line and a version bump (`python3 tools/bump_version.py patch|minor`, see docs/versioning.md), and merge straight to `main` once CI is green. Take the next free version number at merge time: parallel PRs clash, so merge `main` in and re-run the bump with the next number. Merges happen from the cloud. Draft or conflicting PRs never run CI: merge `main` in and mark the PR ready. Only work with an open design question is held.
2. **A single PC QA Remote Control thread tests after merges.** It is the only thread that runs Godot with real hardware, so other threads leave PC runs to it.
   - Pull `main` into `C:\dev\Plinky`. Stash Nathan's local `project.godot` change, pull, then pop it; never discard it. Move any clashing untracked `.uid` files aside.
   - Run the headless tests with an isolated `APPDATA` / user folder. Never touch Nathan's real save (`%APPDATA%\Godot\app_userdata\Plinky\save.json`).
   - Take screenshots with the `tools/` capture scenes. Every run is bounded and has a timeout; a looping run is a bug.
   - Post one batched report per pull, with screenshots.
3. **The coordinator routes every QA finding** to the thread that owns the area. That thread fixes it in a follow-up PR (same rules as step 1).
4. **A thread is resolved only when its PR is merged, pulled to the PC and passed by QA.** Merged alone is not done.
5. **Taste questions go to the coordinator with a recommended pick.** Threads make a reasonable call, log it in `docs/decisions.md`, and keep working. They never sit idle waiting on Nathan. Stop and ask only before anything hard to undo.

## Reports
Lead with the result, then the reasoning. Include screenshots or previews. Say plainly what has not been run in-engine (cloud sessions cannot run Godot, but CI runs it headless).

## PC pitfalls
- Run `godot --headless --import` once on a fresh checkout, or headless tests fail.
- Autoloads cannot be named in `--script` mode (tests and tools that run as scripts must not reference `GameState`, `EventBus` and the rest).
- Auto mode on the PC blocks `gh pr merge`; merge from a cloud thread.
- Never run anything inside `nateanderson-dev`; the project lives in `C:\dev\Plinky`.
- Nathan plays from the editor in `C:\dev\Plinky`. After each merge he must stop the game, refocus the editor and press F5, so pull after every merge.
