# Changelog fragments

A PR does not bump the version. It adds **one file** here, named `<short-slug>.<patch|minor>.md`
(for example `larkmoor-fog-fix.patch.md` or `bloom-gifts.minor.md`), holding one line (or a few) of release notes:

    Larkmoor fog no longer hides the travel pad at noon.

When the PR merges to `main`, the Release workflow folds every fragment into CHANGELOG.md under a new
version heading, bumps `core/build_info.gd` and `export_presets.cfg` (biggest fragment wins: minor beats patch),
and deletes the fragments. Because no PR touches those files, PRs never conflict on the version.
Docs-only, test-only and CI-only PRs add no fragment. Details: docs/versioning.md.
