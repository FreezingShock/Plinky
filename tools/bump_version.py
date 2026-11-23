#!/usr/bin/env python3
"""Bump the Plinky version. Usage: python3 tools/bump_version.py patch|minor|major|set X.Y.Z [--dry-run]

Updates core/build_info.gd (the source of truth), export_presets.cfg, and moves the CHANGELOG.md
"Unreleased" lines under a new dated heading. MAJOR only when Nathan asks.
"""
import datetime, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INFO = ROOT / "core/build_info.gd"
PRESETS = ROOT / "export_presets.cfg"
LOG = ROOT / "CHANGELOG.md"


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
    log = log.replace("## Unreleased\n", f"## Unreleased\n\n## {new} - {datetime.date.today()}", 1)
    LOG.write_text(log)
    return 0


if __name__ == "__main__":
    sys.exit(main())
