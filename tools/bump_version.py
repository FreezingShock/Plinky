#!/usr/bin/env python3
"""Bump the Plinky version. Usage: python3 tools/bump_version.py patch|minor|major|set X.Y.Z|release [--dry-run]

`release` is what CI runs on main (docs/versioning.md): it folds every changelog.d/<slug>.<patch|minor>.md
fragment into CHANGELOG.md, bumps by the biggest fragment (minor beats patch), and deletes the fragments.
PRs add a fragment instead of bumping, so they never conflict on the version files.

Updates core/build_info.gd (the source of truth), export_presets.cfg, and moves the CHANGELOG.md
"Unreleased" lines under a new dated heading. MAJOR only when Nathan asks.
"""
import datetime, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INFO = ROOT / "core/build_info.gd"
PRESETS = ROOT / "export_presets.cfg"
LOG = ROOT / "CHANGELOG.md"


def move_unreleased(log: str, new: str, date: str) -> str:
    """Open a dated heading for `new` directly under "## Unreleased", keeping a blank line on each side so the
    first note stays on its own line instead of being glued to the heading."""
    return re.sub(r"## Unreleased[ \t]*\n+", f"## Unreleased\n\n## {new} - {date}\n", log, count=1)


FRAGMENTS = ROOT / "changelog.d"
FRAGMENT_RE = re.compile(r"^.+\.(patch|minor)\.md$")


def collect_fragments(directory: pathlib.Path) -> tuple[str, list[str], list[pathlib.Path]]:
    """Read changelog.d fragments. Returns (bump, note lines, files). Bump is "" when there are none.
    A fragment is named <slug>.patch.md or <slug>.minor.md; each non-empty line is one note ("- " added if missing)."""
    files = sorted(f for f in directory.glob("*.md") if FRAGMENT_RE.match(f.name))
    bump, notes = "", []
    for f in files:
        kind = FRAGMENT_RE.match(f.name).group(1)
        if kind == "minor" or not bump:
            bump = kind
        for line in f.read_text().splitlines():
            line = line.strip()
            if line:
                notes.append(line if line.startswith("- ") else "- " + line)
    return bump, notes, files


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if not args:
        print(__doc__)
        return 2
    info = INFO.read_text()
    m = re.search(r'const VERSION: String = "(\d+)\.(\d+)\.(\d+)"', info)
    if not m:
        print("VERSION not found in core/build_info.gd")
        return 1
    maj, mi, pa = (int(x) for x in m.groups())
    fragment_files: list[pathlib.Path] = []
    fragment_notes: list[str] = []
    if args[0] == "release":
        bump, fragment_notes, fragment_files = collect_fragments(FRAGMENTS)
        if not bump:
            print("no changelog fragments; nothing to release")
            return 0
        args = [bump]
    if args[0] == "patch":
        pa += 1
    elif args[0] == "minor":
        mi, pa = mi + 1, 0
    elif args[0] == "major":
        maj, mi, pa = maj + 1, 0, 0
    elif args[0] == "set" and len(args) == 2 and re.fullmatch(r"\d+\.\d+\.\d+", args[1]):
        maj, mi, pa = (int(x) for x in args[1].split("."))
    else:
        print(__doc__)
        return 2
    new = f"{maj}.{mi}.{pa}"
    print(f"{m.group(1)}.{m.group(2)}.{m.group(3)} -> {new}")
    if dry:
        return 0
    INFO.write_text(re.sub(r'(const VERSION: String = ")[^"]+(")', rf"\g<1>{new}\2", info))
    p = PRESETS.read_text()
    p = re.sub(r'(application/(?:file|product)_version=")[^"]*(")', rf"\g<1>{new}.0\2", p)
    p = re.sub(r'(application/(?:short_)?version=")[^"]*(")', rf"\g<1>{new}\2", p)
    PRESETS.write_text(p)
    log = LOG.read_text()
    if fragment_notes:
        log = re.sub(r"## Unreleased[ \t]*\n+", "## Unreleased\n\n" + "\n".join(fragment_notes) + "\n", log, count=1)
    for f in fragment_files:
        f.unlink()
    LOG.write_text(move_unreleased(log, new, str(datetime.date.today())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
