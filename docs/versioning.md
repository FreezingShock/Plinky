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
CHANGELOG.md has a heading for the current version.

## Every PR
1. Add a one-line entry under `## Unreleased` in CHANGELOG.md.
2. Pick the bump: `python3 tools/bump_version.py patch` or `minor`. It updates build_info.gd, export_presets.cfg
   and moves the Unreleased lines under the new dated heading.
3. If two PRs bump at once, merge main in and re-run the script with `set X.Y.Z` to the next free number.
4. Never run `major` unless Nathan asked.
