#!/usr/bin/env python3
"""Tests for tools/bump_version.py changelog handling. Run: python3 tests/test_bump_version.py"""
import pathlib, re, sys, tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tools"))
from bump_version import collect_fragments, move_unreleased  # noqa: E402


def check(cond: bool, name: str) -> bool:
    print(("ok   " if cond else "FAIL ") + name)
    return cond


def main() -> int:
    ok = True
    # note directly under the heading (the bug: it was glued onto the new version heading)
    out = move_unreleased("## Unreleased\n- Fix a thing.\n\n## 0.1.0 - 2026-01-01\n- a\n", "0.1.1", "2026-02-02")
    ok &= check(out == "## Unreleased\n\n## 0.1.1 - 2026-02-02\n- Fix a thing.\n\n## 0.1.0 - 2026-01-01\n- a\n", "note stays on its own line")
    # blank line already there
    out = move_unreleased("## Unreleased\n\n- Fix.\n\n## 0.1.0\n- a\n", "0.2.0", "2026-02-02")
    ok &= check("## 0.2.0 - 2026-02-02\n- Fix.\n" in out and out.count("## Unreleased") == 1, "blank line under heading is not doubled")
    # empty Unreleased
    out = move_unreleased("## Unreleased\n\n## 0.1.0\n- a\n", "0.1.1", "2026-02-02")
    ok &= check(out.startswith("## Unreleased\n\n## 0.1.1 - 2026-02-02\n"), "empty Unreleased still gets a heading")
    # every version heading is alone on its line
    ok &= check(all(re.fullmatch(r"## \d+\.\d+\.\d+ - \d{4}-\d{2}-\d{2}", l) for l in out.splitlines() if l.startswith("## 0.1.1")), "heading has no trailing note text")
    # changelog.d fragments: biggest bump wins, notes keep their order, non-fragments are ignored
    with tempfile.TemporaryDirectory() as d:
        dp = pathlib.Path(d)
        bump, notes, files = collect_fragments(dp)
        ok &= check(bump == "" and not notes and not files, "no fragments means no release")
        (dp / "a-fix.patch.md").write_text("Fix a thing.\n")
        (dp / "b-feat.patch.md").write_text("- Tune a thing.\n\n")
        (dp / "README.md").write_text("not a fragment")
        bump, notes, files = collect_fragments(dp)
        ok &= check(bump == "patch" and notes == ["- Fix a thing.", "- Tune a thing."] and len(files) == 2, "patch fragments, dash added")
        (dp / "c-new.minor.md").write_text("Add a zone.")
        bump, notes, _ = collect_fragments(dp)
        ok &= check(bump == "minor" and len(notes) == 3, "minor beats patch")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
