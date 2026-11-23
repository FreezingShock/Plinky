class_name RunStats
extends RefCounted
## History numbers for the History screen: a rolling income graph for this session, time spent per zone, and the
## personal bests. Pure data, no nodes. Sim owns one, feeds it from step() and the press path, and saves the
## lifetime part (zone time and bests). The graph and the session clock are not saved: they start fresh each launch.

const SAMPLE_EVERY: float = 5.0   ## seconds between graph samples
const MAX_SAMPLES: int = 120      ## 120 x 5 s = the last 10 minutes

## One value per sample: log10 of income per second (0 when income is under 1/s). Oldest first.
var samples: PackedFloat32Array = PackedFloat32Array()
## Sample indices where a rebirth happened, so the graph can mark them. Shifted as old samples fall off.
var rebirth_marks: Array[int] = []
var session_seconds: float = 0.0

# Saved.
var zone_seconds: Dictionary = {}     # StringName -> float
var best_chain: int = 0               ## longest pad chain, pressed in order within the streak window
var streaks_done: int = 0             ## chains finished to the end of a row
var best_tier: int = 0                ## highest Momentum stage reached
var crits: int = 0
var best_income: BigNum = BigNum.zero()

var _clock: float = SAMPLE_EVERY   ## starts due, so the graph has its first bar right away


func clear() -> void:
	samples = PackedFloat32Array()
	rebirth_marks.clear()
	session_seconds = 0.0
	zone_seconds.clear()
	best_chain = 0
	streaks_done = 0
	best_tier = 0
	crits = 0
	best_income = BigNum.zero()
	_clock = SAMPLE_EVERY


## Advance time. Returns true when a graph sample is due: the caller then passes the current income to record_income().
func step(dt: float, zone_id: StringName) -> bool:
	session_seconds += dt
	zone_seconds[zone_id] = float(zone_seconds.get(zone_id, 0.0)) + dt
	_clock += dt
	if _clock >= SAMPLE_EVERY:
		_clock = fmod(_clock, SAMPLE_EVERY)
		return true
	return false


func record_income(income: BigNum) -> void:
	samples.append(log10_of(income))
	if samples.size() > MAX_SAMPLES:
		samples.remove_at(0)
		var kept: Array[int] = []
		for m: int in rebirth_marks:
			if m > 0:
				kept.append(m - 1)
		rebirth_marks = kept
	if income.gt(best_income):
		best_income = income.copy()


func mark_rebirth() -> void:
	rebirth_marks.append(samples.size())


func on_press(crit: bool) -> void:
	if crit:
		crits += 1


## A chain advanced to `length` presses in order.
func on_chain(length: int) -> void:
	best_chain = maxi(best_chain, length)


func on_streak_done() -> void:
	streaks_done += 1


func on_tier(tier: int) -> void:
	best_tier = maxi(best_tier, tier)


static func log10_of(v: BigNum) -> float:
	if v == null or v.m <= 0.0:
		return 0.0
	return maxf(0.0, log(v.m) / log(10.0) + float(v.e))


## Seconds spent in each zone, as [{"zone": id, "seconds": s}], largest first.
func zone_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for z: Variant in zone_seconds:
		out.append({"zone": StringName(z), "seconds": float(zone_seconds[z])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["seconds"] > b["seconds"])
	return out


func to_dict() -> Dictionary:
	var z: Dictionary = {}
	for id: Variant in zone_seconds:
		z[String(id)] = zone_seconds[id]
	return {"zone_seconds": z, "best_chain": best_chain, "streaks_done": streaks_done, "best_tier": best_tier,
		"crits": crits, "best_income": best_income.to_array()}


func from_dict(d: Dictionary) -> void:
	clear()
	var z: Variant = d.get("zone_seconds", {})
	if z is Dictionary:
		for k: Variant in (z as Dictionary):
			zone_seconds[StringName(str(k))] = maxf(0.0, float((z as Dictionary)[k]))
	best_chain = maxi(0, int(d.get("best_chain", 0)))
	streaks_done = maxi(0, int(d.get("streaks_done", 0)))
	best_tier = maxi(0, int(d.get("best_tier", 0)))
	crits = maxi(0, int(d.get("crits", 0)))
	best_income = BigNum.from_variant(d.get("best_income"), BigNum.zero()).max_zero()
