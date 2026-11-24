class_name BloomTimeline
extends RefCounted
## The clock of the Bloom animation (ui/fx/bloom_ritual.gd). Pure numbers, no nodes, so tests check it headless.
##
##   0 .. count      every stat on the HUD counts down to its new value, all landing at the same moment
##   charge .. burst the screen dims in a light dither and a ring of ASCII marks closes in on the middle
##   burst           flash, rings, sparkles, and the big Seeds icon pops in
##   burst+pop ..    the Seeds earned count up beside the icon, one tick per step
##   hold .. fly     the icon and number rest, a gift hint shows if one can be bought
##   fly .. total    icon and number drift up off the centre line and shrink away; the HUD's Seeds row then rolls up to its new total
##
## calm (Reduce flashing, Still meadow or Reduce screen effects): shorter, no flash, rings or particles, the icon only
## fades in. The countdown and the number are the same.

## Seconds of the HUD countdown; every counting row ends exactly here.
const COUNT: float = 1.4
const COUNT_CALM: float = 1.0

## Steps of the icon pop: integer pixel scales (the 32 px icon stays crisp), each held for POP_STEP seconds.
const POP_SCALES: Array[int] = [2, 5, 6, 5, 4]
const POP_STEP: float = 0.045
const SETTLED_SCALE: int = 4
## Where the fly-out takes the icon: scales stepped down as it travels.
const FLY_SCALES: Array[int] = [3, 2, 1]


## The moments of one run, in seconds from the Bloom.
static func plan(calm: bool) -> Dictionary:
	var count: float = COUNT_CALM if calm else COUNT
	var charge: float = count - 0.35
	var burst: float = count + 0.1
	var count_up: float = 1.0 if not calm else 0.7
	var up_end: float = burst + 0.15 + count_up
	var hold_end: float = up_end + (1.3 if not calm else 1.1)
	var fly_end: float = hold_end + (0.55 if not calm else 0.35)
	return {"count": count, "charge": charge, "burst": burst, "up_start": burst + 0.15, "up_end": up_end,
		"hold_end": hold_end, "fly_end": fly_end, "total": fly_end + 0.2}


## How many of the earned Seeds the number shows at time `t` (0 before the count starts, `gained` once it ends).
## Eased out, and stepped so it climbs in whole numbers.
static func number_at(gained: int, t: float, p: Dictionary) -> int:
	var a: float = float(p["up_start"])
	var b: float = float(p["up_end"])
	if t <= a:
		return 0
	if t >= b:
		return gained
	var u: float = (t - a) / (b - a)
	var eased: float = 1.0 - pow(1.0 - u, 2.2)
	return clampi(int(floorf(eased * float(gained))), 0, gained)


## Whole count steps shown so far (one tick sound each, capped so a big number is not a machine gun).
static func tick_steps(gained: int, t: float, p: Dictionary) -> int:
	var shown: int = number_at(gained, t, p)
	return mini(shown, 12) if gained <= 12 else int(floorf(float(shown) / float(gained) * 12.0))


## Integer pixel scale of the icon at `t`: 0 before the burst, the pop steps, the settled scale, then the fly-out steps.
static func icon_scale(t: float, p: Dictionary) -> int:
	var burst: float = float(p["burst"])
	if t < burst:
		return 0
	var fly_start: float = float(p["hold_end"])
	if t >= fly_start:
		var f: float = (t - fly_start) / maxf(float(p["fly_end"]) - fly_start, 0.01)
		if f >= 1.0:
			return 0
		return FLY_SCALES[clampi(int(floorf(f * float(FLY_SCALES.size()))), 0, FLY_SCALES.size() - 1)]
	var i: int = int(floorf((t - burst) / POP_STEP))
	return POP_SCALES[i] if i < POP_SCALES.size() else SETTLED_SCALE


## 0 to 1 progress of the fly-out (0 while resting), eased in so the icon leaves slowly and arrives fast.
static func fly_progress(t: float, p: Dictionary) -> float:
	var a: float = float(p["hold_end"])
	var b: float = float(p["fly_end"])
	if t <= a:
		return 0.0
	if t >= b:
		return 1.0
	var u: float = (t - a) / (b - a)
	return u * u


## 0 to 1 strength of the dark dither veil: grows through the charge, peaks at the burst, thins away over the hold.
static func veil_at(t: float, p: Dictionary) -> float:
	var charge: float = float(p["charge"])
	var burst: float = float(p["burst"])
	if t < charge:
		return 0.0
	if t < burst:
		return (t - charge) / (burst - charge) * 0.6
	var hold_end: float = float(p["hold_end"])
	if t < hold_end:
		return 0.6
	return clampf(0.6 * (1.0 - (t - hold_end) / 0.5), 0.0, 0.6)


## 0 to 1 strength of the bright flash: a sharp rise at the burst and a quick fall.
static func flash_at(t: float, p: Dictionary) -> float:
	var burst: float = float(p["burst"])
	var dt: float = t - burst
	if dt < 0.0 or dt > 0.45:
		return 0.0
	return 1.0 - dt / 0.45
