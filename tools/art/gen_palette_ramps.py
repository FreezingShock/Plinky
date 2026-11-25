#!/usr/bin/env python3
"""Generate the 4-step ramps in render/palettes.gd from the 8 role anchors in DATA.

Each role gets four steps: 0 deepest shade, 1 shade, 2 the anchor (exactly the DATA colour, so colors() and the
ramp agree), 3 lit highlight. Shade steps lean cool (teal and blue), lit steps lean warm (yellow), per the Gower
style guide (hue-shifted ramps, rule 2). The post shader reads step = light band + 1 (see post_dither.gdshader).

Run from the repo root: python3 tools/art/gen_palette_ramps.py
"""
import colorsys
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
TARGET = ROOT / "render" / "palettes.gd"

# Recipe B ("warm lit, cool shade") from the palette mockup the art thread picked (Nathan, 2026-11-25).
STEP_VALUE = [0.62, 0.84, 1.0, 1.12]      # value multiplier per step, clamped to 1.0
# Hue moves toward a target along the short way round the wheel: shade toward teal-blue, light toward yellow.
STEP_HUE_TARGET = [0.56, 0.56, None, 0.12]
STEP_HUE_AMOUNT = [0.22, 0.12, 0.0, 0.12]  # fraction of that arc travelled per step
STEP_SAT = [0.20, 0.10, 0.0, 0.10]        # saturation lift per step; the anchor keeps its own saturation

BEGIN = "# BEGIN RAMPS"
END = "# END RAMPS"


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: tuple[float, float, float]) -> str:
    return "".join("%02x" % round(max(0.0, min(1.0, c)) * 255) for c in rgb)


def ramp(anchor: str) -> list[str]:
    h, s, v = colorsys.rgb_to_hsv(*hex_to_rgb(anchor))
    out = []
    for k in range(4):
        if k == 2:
            out.append(anchor)  # the anchor is exact
            continue
        target = STEP_HUE_TARGET[k]
        arc = ((target - h + 0.5) % 1.0) - 0.5 if target is not None else 0.0
        hh = (h + arc * STEP_HUE_AMOUNT[k]) % 1.0
        ss = min(1.0, s * (1.0 + STEP_SAT[k]))
        vv = min(1.0, v * STEP_VALUE[k])
        out.append(rgb_to_hex(colorsys.hsv_to_rgb(hh, ss, vv)))
    return out


def main() -> None:
    src = TARGET.read_text(encoding="utf-8")
    # anchors come from DATA only: the RAMP block below it has nested rows that would match the same pattern
    anchors_src = src.split("const DATA", 1)[1].split("\n}", 1)[0]
    data = dict(
        (m.group(1), re.findall(r'"([0-9a-f]{6})"', m.group(2)))
        for m in re.finditer(r'&"(\w+)": \[([^\]]*)\]', anchors_src)
    )
    zones = [z for z in data if len(data[z]) == 8]
    lines = [BEGIN, "const RAMP: Dictionary = {"]
    for z in zones:
        steps = [ramp(a) for a in data[z]]          # per role: 4 steps
        lines.append("\t&\"%s\": [" % z)
        for k in range(4):
            row = ", ".join('"%s"' % steps[r][k] for r in range(8))
            lines.append("\t\t[%s]," % row)
        lines.append("\t],")
    lines += ["}", END]
    block = "\n".join(lines)
    new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), block, src, flags=re.S)
    if new == src and BEGIN not in src:
        raise SystemExit("markers missing in %s" % TARGET)
    TARGET.write_text(new, encoding="utf-8")
    print("wrote %d zone ramps to %s" % (len(zones), TARGET))


if __name__ == "__main__":
    main()
