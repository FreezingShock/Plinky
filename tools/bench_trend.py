#!/usr/bin/env python3
"""Adds one row per bench run to a trend CSV, and writes the run's table to the CI step summary.

Reads shots/bench.json (written by tools/bench.gd, one result per quality and phase) and appends its rows to the trend
file, which gets a header the first time. CI uploads the file as an artifact, so each run's numbers can be compared
with earlier runs (perf.md, "Bench trend"). Exits 0 with a note when there is no bench.json, so a failed bench does not
hide its own log.

Usage: bench_trend.py [bench.json] [trend.csv] [summary.md]
  summary.md (optional) gets the markdown table appended; CI passes $GITHUB_STEP_SUMMARY.
  The commit column is GITHUB_SHA when set, else "local".
"""
import csv
import json
import os
import sys

bench_path = sys.argv[1] if len(sys.argv) > 1 else "shots/bench.json"
trend_path = sys.argv[2] if len(sys.argv) > 2 else "shots/bench_trend.csv"
summary_path = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("GITHUB_STEP_SUMMARY", "")

if not os.path.exists(bench_path):
    print("bench trend: no %s, nothing recorded" % bench_path)
    sys.exit(0)

data = json.load(open(bench_path))
commit = os.environ.get("GITHUB_SHA", "local")[:9]
columns = ["date", "commit", "quality", "phase", "fps", "avg_ms", "p99_ms", "max_ms", "draws_max", "objects_max", "nodes_max"]
rows = []
for r in data.get("results", []):
    rows.append({
        "date": data.get("date", ""),
        "commit": commit,
        "quality": r.get("quality", ""),
        "phase": r.get("phase", ""),
        "fps": round(float(r.get("fps", 0.0)), 1),
        "avg_ms": round(float(r.get("avg", 0.0)), 2),
        "p99_ms": round(float(r.get("p99", 0.0)), 2),
        "max_ms": round(float(r.get("max", 0.0)), 2),
        "draws_max": int(r.get("draw_calls_max", 0)),
        "objects_max": int(r.get("objects_max", 0)),
        "nodes_max": int(r.get("nodes_max", 0)),
    })

is_new = not os.path.exists(trend_path)
with open(trend_path, "a", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=columns)
    if is_new:
        writer.writeheader()
    writer.writerows(rows)
print("bench trend: %d row(s) appended to %s" % (len(rows), trend_path))

table = ["### Bench: %s (%s)" % (commit, data.get("date", "")), "",
         "| quality | phase | fps | avg ms | p99 ms | max ms | draws | objects | nodes |",
         "|---|---|---|---|---|---|---|---|---|"]
for row in rows:
    table.append("| %s | %s | %s | %s | %s | %s | %d | %d | %d |" % (
        row["quality"], row["phase"], row["fps"], row["avg_ms"], row["p99_ms"], row["max_ms"],
        row["draws_max"], row["objects_max"], row["nodes_max"]))
text = "\n".join(table) + "\n"
print(text)
if summary_path:
    with open(summary_path, "a") as f:
        f.write(text)
