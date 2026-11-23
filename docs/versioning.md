# Versioning

The version is `MAJOR.MINOR.PATCH`, e.g. `0.5.0`. Any number can pass 9 (0.12.3 is fine).

| Part | When | Who decides |
|---|---|---|
| MAJOR | A deploy or a big change | Only when Nathan asks |
| MINOR | Medium changes: a feature, a new system, a menu, a zone | The PR author |
| PATCH | Small changes: fixes, tuning, copy, art tweaks | The PR author |

Bumping MINOR resets PATCH to 0. Docs-only, test-only and CI-only PRs need no bump.

## Source of truth
`core/build_info.gd` (`BuildInfo.VERSION`). It is shown small on the boot screen and in the Update Log (`BuildInfo.string()`, `BuildInfo.changelog()`),
and stamped on feedback notes. `export_presets.cfg` must match; `tests/test_version.gd` checks that and that
CHANGELOG.md has a heading for the current version. **PRs never edit these three files.** CI stamps the version after merge.

## Every PR: add a changelog fragment
1. Add one file to `changelog.d/`, named `<short-slug>.<patch|minor>.md`, with a one-line release note, for example
   `changelog.d/larkmoor-fog-fix.patch.md`. Pick `patch` or `minor` from the table above; no number to choose.
2. That is all. Do not run `tools/bump_version.py`, and do not touch CHANGELOG.md, `core/build_info.gd` or `export_presets.cfg`.
3. Docs-only, test-only and CI-only PRs need no fragment.

## After merge: the Release workflow
`.github/workflows/release.yml` runs on every push to `main` that touches `changelog.d/`. It runs `python3 tools/bump_version.py release`,
which folds all fragments into one new dated CHANGELOG.md heading, bumps `core/build_info.gd` and `export_presets.cfg`
(biggest fragment wins: one `minor` makes the release a MINOR bump and resets PATCH), deletes the fragments, and pushes a
`Release vX.Y.Z` commit to `main`. Runs are serialised, so quick merges never race for a number; two PRs merged back to back
can share a release (one version, both notes). Because no PR touches the version files, **PRs no longer conflict on the version**
and there is no "take the next free number" step. Pull `main` to see the new version.

Manual bumps still work for emergencies (`python3 tools/bump_version.py patch|minor|set X.Y.Z`); never run `major` unless Nathan asked.

## If the main ruleset blocks the Release push
The Release job pushes to `main`, so a ruleset that requires the `test` check or a pull request will refuse it. The job then
only warns and leaves the fragments for the next release, so nothing is lost and no PR breaks. To let it through, either
add the GitHub Actions app to the ruleset's bypass list (not always offered on personal repos), or, the reliable way,
create a fine-grained personal access token with Contents: read and write on this repo, save it as the repo secret
`RELEASE_TOKEN`, and add the **Repository admin** role to the ruleset's bypass list. The workflow uses the secret when it exists.
