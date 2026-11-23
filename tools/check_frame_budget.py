#!/usr/bin/env python3
"""Fails when shots/bench.json (written by tools/bench.gd) holds a frame over the hitch budget.

CI runs the bench headless, so this catches script-side stalls (a synchronous load, a big build in one frame), not GPU
cost. On real hardware use the full bench (docs/perf.md). Usage: check_frame_budget.py [bench.json] [max_ms] [swap_max_ms]

A zone swap happens under the fully covering transition wipe, so its first rendered frame (about 100 ms on the PC,
133 to 165 ms on a CI runner) is allowed up to swap_max_ms (default 300). The pre-fix swap was one 330 ms frame on a
GPU machine with the wipe about to clear. Every other frame must stay under max_ms.
"""
import json
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shots/bench.json"
limit = float(sys.argv[2]) if len(sys.argv) > 2 else 150.0
swap_limit = float(sys.argv[3]) if len(sys.argv) > 3 else 300.0
data = json.load(open(path))
bad = []
for h in data.get("hitches", []):
    m = re.search(r"([\d.]+) ms", h)
    cap = swap_limit if "after entering" in h else limit
    if m and float(m.group(1)) > cap:
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
