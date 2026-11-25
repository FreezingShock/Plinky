#!/usr/bin/env python3
"""Tests for tools/check_playtest.py, the verdict on the playtest bot. Run: python3 tests/test_check_playtest.py"""
import pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tools"))
import check_playtest as cp  # noqa: E402


def clean() -> dict:
    return {
        "sim_minutes": 60.0,
        "timed_out": False,
        "errors": [],
        "stalls": [],
        "hitches": [],
        "frames": {"normal": 3240, "normal_max_ms": 46.1, "normal_p99_ms": 10.0, "covered": 360, "covered_max_ms": 90.9},
        "events": [
            {"kind": "zone", "id": "larkmoor", "minute": 9.6},
            {"kind": "reset", "id": "bloom", "minute": 14.7},
            {"kind": "zone", "id": "zone2", "minute": 14.7},
        ],
    }


def check(cond: bool, name: str) -> bool:
    print(("ok   " if cond else "FAIL ") + name)
    return cond


def main() -> int:
    ok = True
    ok &= check(cp.check(clean()) == [], "a clean hour passes")
    d = clean()
    d["engine_notes"] = ["./servers/rendering/dummy/storage/texture_storage.h:85 Parameter \"t\" is null. (x1)"]
    ok &= check(cp.check(d) == [], "an engine note alone does not fail the run")

    d = clean()
    d["errors"] = ["res://ui/x.gd:3 Error calling from signal"]
    ok &= check(len(cp.check(d)) == 1, "a logged error fails the run")

    d = clean()
    d["timed_out"] = True
    ok &= check(any("wall-clock" in f for f in cp.check(d)), "hitting the wall-clock limit fails")

    d = clean()
    d["stalls"] = [{"minute": 20.0, "zone": "zone2", "idle_minutes": 5.0}]
    ok &= check(any(f.startswith("stall:") for f in cp.check(d)), "a stall fails the run")

    d = clean()
    d["hitches"] = [{"minute": 3.0, "ms": 200.0, "covered": False, "zone": "larkmoor"}]
    ok &= check(any("200.0 ms" in f for f in cp.check(d)), "a normal frame over 150 ms fails")

    d = clean()
    d["hitches"] = [{"minute": 9.6, "ms": 220.0, "covered": True, "zone": "larkmoor"}]
    ok &= check(cp.check(d) == [], "a frame of 220 ms under the wipe passes (limit 300)")

    d = clean()
    d["hitches"] = [{"minute": 9.6, "ms": 350.0, "covered": True, "zone": "larkmoor"}]
    ok &= check(any("under the wipe" in f for f in cp.check(d)), "a frame of 350 ms under the wipe fails")

    d = clean()
    d["frames"]["normal_max_ms"] = 180.0  # no hitch listed (the list is capped): the maximum still fails
    ok &= check(any("worst 180.0 ms" in f for f in cp.check(d)), "a frame maximum over budget fails without a hitch entry")

    d = clean()
    d["events"] = [e for e in d["events"] if e["id"] != "bloom"]
    ok &= check(any("first Bloom reset never happened" in f for f in cp.check(d)), "a missing Bloom reset fails")

    d = clean()
    d["events"][0]["minute"] = 45.0
    ok &= check(any("Larkmoor entered" in f and "45.0" in f for f in cp.check(d)), "a milestone past its deadline fails")

    ok &= check("Larkmoor entered: minute 9.6" in cp.summary(clean()), "summary names the milestone minutes")
    print("PASS" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
