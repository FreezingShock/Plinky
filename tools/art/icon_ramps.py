"""Icon ramp families for the staged icon set (Gower style rules 2, 7 and 9, part T11).

Every icon is drawn with the 8 role indices of tools/art/staged_kit.py. This module turns a role into one of the
4-step hue-shifted ramps from render/palettes.gd (the same RAMP the world uses), so icon colour comes from the same
ramps as the world and nothing is a one-off colour. Each icon belongs to one family:
  meadow    stats, Sunlight, Seeds, Cash, Mult, nature, Cinder (green stone with an orange seam) and the meadow materials
  quarry    Embers, Slag, Ore, Alloy, Emberheart, Shards, Heat and the quarry relics
  iris      the rebirth relics (crowns, pearl, lens, lantern)
  tidewater Rebirth points, Rebirth, prestige and bloom crown (teal and gold, so they stay apart from purple Ingot), time, rest and offline

shade() picks the ramp step per texel from the grid itself: texels on the lit upper-left edge take step 3, texels on
the shaded lower-right edge take step 1, everything else takes step 2 (the anchor). Ink (role 0) stays ink.

RAMP is read from render/palettes.gd so the icons follow the palette whenever it is regenerated.
"""
import colorsys
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PALETTES = ROOT / "render" / "palettes.gd"

FAMILY_OF: dict[str, str] = {}
for _n in ("cash", "mult", "seeds", "sunlight", "crit", "crit_dmg", "rate", "luck", "walk", "mastery",
           "presses", "lore", "fortune", "dewdrop", "clover", "thistle", "heather", "foxglove", "starbloom",
           "stats_menu", "attrs_menu", "menu_stats", "menu_attributes", "menu_upgrades", "menu_log", "menu_travel",
           "menu_history", "menu_settings", "menu_ledger", "menu_relics", "menu_hamburger"):
    FAMILY_OF[_n] = "meadow"
FAMILY_OF["cinder"] = "meadow"  # green stone with an orange seam: not warm, so it stays apart from Embers
for _n in ("embers", "slag", "ironore", "ingot", "alloy", "emberheart", "shards", "heat", "nucleus_crown"):
    FAMILY_OF[_n] = "quarry"
for _n in ("rp", "reb", "prestige", "bloom_crown", "clock", "rest", "offline"):
    FAMILY_OF[_n] = "tidewater"  # teal and gold: Rebirth stays apart from purple Ingot
# relics: object colour is literal, the family only shades the texels that use a role index
for _n in ("r_quarry_coal", "r_warm_ember", "r_obsidian_spur"):
    FAMILY_OF[_n] = "quarry"
for _n in ("r_solar_crown", "r_singularity_pearl", "r_starfall_lens", "r_eternal_lantern"):
    FAMILY_OF[_n] = "iris"
DEFAULT_FAMILY = "meadow"

# Literal extras (%letter=#hex) that are material identity colours (dewdrop white, heather purple, ...) stay literal.


def load_ramps() -> dict[str, list[list[tuple[int, int, int, int]]]]:
    """-> {zone: steps[step][role] as RGBA}, read from the RAMP block of render/palettes.gd."""
    src = PALETTES.read_text(encoding="utf-8")
    block = src.split("# BEGIN RAMPS", 1)[1].split("# END RAMPS", 1)[0]
    out: dict[str, list[list[tuple[int, int, int, int]]]] = {}
    for m in re.finditer(r'&"(\w+)": \[(.*?)\n\t\],', block, re.S):
        steps = []
        for row in re.findall(r"\[([^\]]*)\]", m.group(2)):
            hexes = re.findall(r'"([0-9a-f]{6})"', row)
            steps.append([tuple(int(h[k:k + 2], 16) for k in (0, 2, 4)) + (255,) for h in hexes])
        out[m.group(1)] = steps
    return out


RAMPS = load_ramps()
ZONE_FOR_FAMILY = {"meadow": "meadow", "quarry": "quarry", "iris": "iris", "tidewater": "tidewater"}


def family_steps(family: str) -> list[list[tuple[int, int, int, int]]]:
    return RAMPS[ZONE_FOR_FAMILY[family]]


def union_palette() -> list[tuple[int, int, int, int]]:
    """Every ramp colour of every family, for snapping literal colours onto the ramps."""
    seen: list[tuple[int, int, int, int]] = []
    for zone in ZONE_FOR_FAMILY.values():
        for row in RAMPS[zone]:
            for c in row:
                if c not in seen:
                    seen.append(c)
    return seen


def snap(c: tuple[int, int, int, int], palette: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    """Nearest colour in `palette` by weighted RGB distance (hue matters more than value here)."""
    def dist(p: tuple[int, int, int, int]) -> float:
        return (2 * (p[0] - c[0]) ** 2) + (4 * (p[1] - c[1]) ** 2) + (3 * (p[2] - c[2]) ** 2)
    return min(palette, key=dist)


def shade(grid: list[list], n: int, family: str, snap_literals: bool = False) -> list[list]:
    """Map a staged grid (int roles, RGBA literals, None) to RGBA using the family's ramp steps."""
    steps = family_steps(family)
    palette = union_palette()

    def empty(x: int, y: int) -> bool:
        if not (0 <= x < n and 0 <= y < n):
            return True
        c = grid[y][x]
        return c is None or c == 0

    out: list[list] = [[None] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            c = grid[y][x]
            if c is None:
                continue
            if isinstance(c, tuple):
                out[y][x] = snap(c, palette) if snap_literals else c
                continue
            if c == 0:
                out[y][x] = steps[2][0]
                continue
            lit = empty(x - 1, y) or empty(x, y - 1)
            dark = empty(x + 1, y) or empty(x, y + 1)
            step = 3 if (lit and not dark) else 1 if (dark and not lit) else 2
            out[y][x] = steps[step][c]
    return out


def remodel_image(im, family: str = DEFAULT_FAMILY):
    """A PIL RGBA drawing made from the 8 meadow anchors (or transparent) -> the same drawing on the family ramps.
    Each anchor pixel is mapped back to its role, then shade() picks the ramp step. Off-anchor pixels snap to the
    nearest anchor and are counted, so a drawing that strays from the palette is visible in the build log."""
    from PIL import Image

    n = im.width
    anchors = [c[:3] for c in family_steps("meadow")[2]]
    grid: list[list] = [[None] * n for _ in range(n)]
    snapped = 0
    for y in range(n):
        for x in range(n):
            r, g, b, a = im.getpixel((x, y))
            if a == 0:
                continue
            rgb = (r, g, b)
            if rgb in anchors:
                grid[y][x] = anchors.index(rgb)
            else:
                snapped += 1
                grid[y][x] = min(range(8), key=lambda i: sum((anchors[i][k] - rgb[k]) ** 2 for k in range(3)))
    if snapped:
        print("remodel_image: snapped %d off-anchor texels" % snapped)
    return to_image(shade(grid, n, family), n)


def to_image(rgba: list[list], n: int):
    """RGBA grid from shade() -> PIL image."""
    from PIL import Image

    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            if rgba[y][x] is not None:
                out.putpixel((x, y), rgba[y][x])
    return out
