#!/usr/bin/env python3
"""Print the real cause of a failed CI step. Usage: python3 tools/ci_summary.py LOG [LOG...]

Scans Godot logs for FAIL lines, SCRIPT ERROR / Parse Error / Compile Error lines and "NOT reached", prints them as
GitHub ::error annotations and appends them to the job summary, so a red check shows the cause without opening
a 5000-line log. Always exits 0 (it only reports). See docs/ci.md, "Reading a red check".
"""
import os, pathlib, re, sys

PATTERN = re.compile(r"^(FAIL \[|SCRIPT ERROR|.*Compile Error|.*Parse Error|.*NOT reached|ERROR:)")
# The first `godot --import` on a fresh checkout prints font preload errors; they are harmless and not part of these logs.


def main() -> int:
    lines: list[str] = []
    for arg in sys.argv[1:]:
        p = pathlib.Path(arg)
        if not p.exists():
            continue
        for raw in p.read_text(errors="replace").splitlines():
            line = re.sub(r"^\d{4}-\d\d-\d\dT[\d:.]+Z ", "", raw).strip()
            if PATTERN.match(line) and line not in lines:
                lines.append(line)
    if not lines:
        return 0
    shown = lines[:20]
    for line in shown:
        print("::error::" + line.replace("%", "%25"))
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("### Why this job failed\n\n```\n" + "\n".join(shown) + "\n```\n")
            if len(lines) > len(shown):
                f.write(f"\n{len(lines) - len(shown)} more lines in the log.\n")
            if any("Identifier not found" in l for l in lines):
                f.write("\nTip: `--script` tests cannot name autoloads (Audio, EventBus, GameState...). See docs/ci.md.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
