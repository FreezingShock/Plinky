#!/usr/bin/env python3
"""Fails when shots/bench.json (written by tools/bench.gd) holds a frame over the hitch budget.

CI runs the bench headless, so this catches script-side stalls (a synchronous load, a big build in one frame), not GPU
cost. On real hardware use the full bench (docs/perf.md). Usage: check_frame_budget.py [bench.json] [max_ms]
"""
import json
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shots/bench.json"
limit = float(sys.argv[2]) if len(sys.argv) > 2 else 150.0
data = json.load(open(path))
bad = []
for h in data.get("hitches", []):
    m = re.search(r"([\d.]+) ms", h)
    if m and float(m.group(1)) > limit:
        bad.append(h)
for r in data.get("results", []):
    if float(r["max"]) > limit:
        bad.append("%s %s: worst frame %.1f ms" % (r["quality"], r["phase"], float(r["max"])))
if bad:
    print("Frame budget: %d frame(s) over %.0f ms" % (len(bad), limit))
    for b in bad:
        print("  " + b)
    sys.exit(1)
print("Frame budget OK: no frame over %.0f ms in %d phases" % (limit, len(data.get("results", []))))
