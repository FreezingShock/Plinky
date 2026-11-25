#!/usr/bin/env python3
"""Verdict for the playtest bot. Reads the JSON that tools/playtest.gd writes and fails the job when the first hour
shows something a new player would hit.

Usage: check_playtest.py [shots/playtest.json]

Fails on:
- a script, shader or script-call error logged during the run, or the wall-clock limit ending the run early.
  Other engine messages are listed as notes and do not fail the run;
- a stall: no passive income and no paid press for stall_seconds of sim time (the bot logs each one);
- a frame over NORMAL_FRAME_MS, or a frame under the zone wipe over COVERED_FRAME_MS;
- a milestone in MILESTONES that is missing, or reached after its deadline (sim minutes).

The thresholds are here, in one place. The bot only measures.
"""
import json
import sys

NORMAL_FRAME_MS = 150.0   # the play job's frame budget (ci.yml, tools/bench.gd)
COVERED_FRAME_MS = 300.0  # a frame under the zone wipe may take this long (tools/check_frame_budget.py swap limit)

# (event kind, event id, deadline in sim minutes, label). Observed on main 2026-11-25 with the greedy bot: Larkmoor 9.6,
# Bloom 14.7, Ember Quarry 14.7. The deadlines leave room for normal tuning but catch a broken first half hour.
MILESTONES = [
    ("zone", "larkmoor", 30.0, "Larkmoor entered"),
    ("reset", "bloom", 30.0, "first Bloom reset"),
    ("zone", "zone2", 30.0, "Ember Quarry entered"),
]


def check(data: dict) -> list[str]:
    """Returns one line per failure. An empty list is a pass."""
    fails: list[str] = []
    if data.get("timed_out"):
        fails.append("the run hit its wall-clock limit at %.1f sim minutes" % data.get("sim_minutes", 0.0))
    for e in data.get("errors", []):
        fails.append("error: " + e)
    for s in data.get("stalls", []):
        fails.append("stall: no income and no paid press for %.1f min, from minute %.1f in %s"
                     % (s["idle_minutes"], s["minute"], s["zone"]))

    over_budget = False
    for h in data.get("hitches", []):
        covered = bool(h.get("covered"))
        limit = COVERED_FRAME_MS if covered else NORMAL_FRAME_MS
        if h["ms"] > limit:
            over_budget = True
            fails.append("frame: %.1f ms at minute %.1f in %s%s (limit %.0f)"
                         % (h["ms"], h["minute"], h["zone"], " under the wipe" if covered else "", limit))
    # The hitch list is capped, so the frame maxima stand on their own too.
    frames = data.get("frames", {})
    if not over_budget and frames.get("normal_max_ms", 0.0) > NORMAL_FRAME_MS:
        fails.append("frame: worst %.1f ms outside the wipe (limit %.0f)" % (frames["normal_max_ms"], NORMAL_FRAME_MS))
    if not over_budget and frames.get("covered_max_ms", 0.0) > COVERED_FRAME_MS:
        fails.append("frame: worst %.1f ms under the wipe (limit %.0f)" % (frames["covered_max_ms"], COVERED_FRAME_MS))

    events = data.get("events", [])
    for kind, event_id, deadline, label in MILESTONES:
        hit = next((e for e in events if e.get("kind") == kind and e.get("id") == event_id), None)
        if hit is None:
            fails.append("milestone: %s never happened (deadline minute %.0f)" % (label, deadline))
        elif hit["minute"] > deadline:
            fails.append("milestone: %s at minute %.1f (deadline minute %.0f)" % (label, hit["minute"], deadline))
    return fails


def summary(data: dict) -> str:
    frames = data.get("frames", {})
    lines = ["Playtest: %.1f sim minutes, %d frames, normal worst %.1f ms (p99 %.1f), under the wipe worst %.1f ms"
             % (data.get("sim_minutes", 0.0), frames.get("normal", 0), frames.get("normal_max_ms", 0.0),
                frames.get("normal_p99_ms", 0.0), frames.get("covered_max_ms", 0.0))]
    for kind, event_id, _deadline, label in MILESTONES:
        hit = next((e for e in data.get("events", []) if e.get("kind") == kind and e.get("id") == event_id), None)
        lines.append("  %s: %s" % (label, "minute %.1f" % hit["minute"] if hit else "not reached"))
    return "\n".join(lines)


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "shots/playtest.json"
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        print("Playtest: no readable result at %s (%s). The bot did not finish." % (path, e))
        return 1
    print(summary(data))
    fails = check(data)
    if fails:
        print("Playtest FAILED: %d problem(s)" % len(fails))
        for f in fails:
            print("  " + f)
        return 1
    for n in data.get("engine_notes", []):
        print("  note (engine message, not a failure): " + n)
    print("Playtest OK: no stall, no error, frames in budget, milestones on time")
    return 0


if __name__ == "__main__":
    sys.exit(main())
