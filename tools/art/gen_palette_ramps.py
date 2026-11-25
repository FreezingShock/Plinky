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
STEP_VALUE = [0.78, 0.92, 1.0, 1.08]      # value multiplier per step, clamped to 1.0
# Hue moves toward a target along the short way round the wheel: shade toward teal-blue, light toward yellow.
STEP_HUE_TARGET = [0.56, 0.56, None, 0.12]
STEP_HUE_AMOUNT = [0.12, 0.06, 0.0, 0.16]  # fraction of that arc travelled per step
STEP_SAT = [0.10, 0.05, 0.0, 0.08]        # saturation lift per step; the anchor keeps its own saturation

# Earth (role 6) keeps its own hue on the meadow palette: a hue drift toward yellow reads olive-khaki under the noon grade.
HUE_HOLD = {("meadow", 6)}

# Grass variants for warm and cool patches (Larkmoor, T2 ground thread wires them into the bake). Each is a target hue and
# how far to move toward it, applied to the meadow grass anchor (role 3) in every step.
GRASS_ANCHOR_ROLE = 3
GRASS_VARIANTS = {"warm": (0.12, 0.75), "cool": (0.55, 0.8)}

BEGIN = "# BEGIN RAMPS"
END = "# END RAMPS"
GBEGIN = "# BEGIN GRASS"
GEND = "# END GRASS"


def hex_to_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: tuple[float, float, float]) -> str:
    return "".join("%02x" % round(max(0.0, min(1.0, c)) * 255) for c in rgb)


def ramp(anchor: str, hold: bool = False) -> list[str]:
    h, s, v = colorsys.rgb_to_hsv(*hex_to_rgb(anchor))
    out = []
    for k in range(4):
        if k == 2:
            out.append(anchor.lstrip("#"))  # the anchor is exact
            continue
        target = STEP_HUE_TARGET[k]
        arc = ((target - h + 0.5) % 1.0) - 0.5 if (target is not None and not hold) else 0.0
        hh = (h + arc * STEP_HUE_AMOUNT[k]) % 1.0
        ss = min(1.0, s * (1.0 + STEP_SAT[k]))
        vv = min(1.0, v * STEP_VALUE[k])
        out.append(rgb_to_hex(colorsys.hsv_to_rgb(hh, ss, vv)))
    return out


def grass_variant(anchor: str, target: float, amount: float) -> list[str]:
    """Four steps of a grass variant: the anchor's hue moved toward `target` by `amount` of the short arc, then the same
    value and saturation steps as the ramps."""
    h, s, v = colorsys.rgb_to_hsv(*hex_to_rgb(anchor))
    arc = ((target - h + 0.5) % 1.0) - 0.5
    out = []
    for k in range(4):
        hh = (h + arc * amount) % 1.0
        ss = min(1.0, s * (1.0 + STEP_SAT[k]))
        vv = min(1.0, v * STEP_VALUE[k])
        out.append(rgb_to_hex(colorsys.hsv_to_rgb(hh, ss, vv)))
    return out


def role_steps_32(anchors: list[str]) -> list[str]:
    """32 hex colours with a leading '#', role-major: index role * 4 + step (0 darkest, 2 the anchor, 3 lit)."""
    out: list[str] = []
    for a in anchors:
        out.extend("#" + h for h in ramp(a))
    return out


def prop_ramp_steps(roles: list[int]) -> list[int]:
    """Map a material ramp of roles (dark to light) to RAMP_PAL indices, role * 4 + step.

    Steps run 1 to 3 from dark to light, the same bands the post shader draws (step = light band + 1). A one-element
    ramp takes the anchor step, 2.
    """
    n = len(roles)
    if n == 1:
        steps = [2]
    else:
        steps = [1 + int(2 * k / (n - 1) + 0.5) for k in range(n)]
    return [r * 4 + s for r, s in zip(roles, steps)]


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
        steps = [ramp(a, hold=(z, r) in HUE_HOLD) for r, a in enumerate(data[z])]          # per role: 4 steps
        lines.append("\t&\"%s\": [" % z)
        for k in range(4):
            row = ", ".join('"%s"' % steps[r][k] for r in range(8))
            lines.append("\t\t[%s]," % row)
        lines.append("\t],")
    lines += ["}", END]
    block = "\n".join(lines)
    glines = [GBEGIN, "const GRASS: Dictionary = {"]
    anchor = data["meadow"][GRASS_ANCHOR_ROLE]
    for name, (target, amount) in GRASS_VARIANTS.items():
        row = ", ".join('"%s"' % h for h in grass_variant(anchor, target, amount))
        glines.append('\t&"%s": [%s],' % (name, row))
    glines += ["}", GEND]
    gblock = "\n".join(glines)
    new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _m: block, src, flags=re.S)
    new = re.sub(re.escape(GBEGIN) + r".*?" + re.escape(GEND), lambda _m: gblock, new, flags=re.S)
    if BEGIN not in src or GBEGIN not in src:
        raise SystemExit("markers missing in %s" % TARGET)
    TARGET.write_text(new, encoding="utf-8")
    print("wrote %d zone ramps to %s" % (len(zones), TARGET))


if __name__ == "__main__":
    main()
