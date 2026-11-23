class_name Achievements
extends RefCounted
## Pure logic for achievements: which are unlocked, in what order, and the stat peaks they need. No nodes, no autoloads.
## Sim owns one, feeds it counters once a second (Sim.check_achievements) and saves it with to_dict().
## Rewards are cosmetic only (a title), so nothing here touches balance.

## Category id and Title Case name, in Ledger order. Colours live in ui/ledger_panel.gd.
const CATEGORIES: Array = [
	[&"presses", "Presses"],
	[&"meadow", "Meadow"],
	[&"streaks", "Streaks"],
	[&"relics", "Relics"],
	[&"rebirth", "Rebirth"],
	[&"growth", "Growth"],
	[&"quarry", "Quarry"],
	[&"journey", "Journey"],
]

var defs: Dictionary = {}        ## StringName -> AchievementDef
var sorted: Array[AchievementDef] = []   ## category order, then AchievementDef.order
var unlock_log: Array[StringName] = []  ## unlocked ids, oldest first
var peaks: Dictionary = {}       ## stat id -> BigNum, the highest value each stat has had (survives rebirth)
var _have: Dictionary = {}       ## id -> true, mirrors log


func _init(p_defs: Array = []) -> void:
	for d: Variant in p_defs:
		var def: AchievementDef = d as AchievementDef
		if def != null:
			defs[def.id] = def
			sorted.append(def)
	sorted.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool:
		var ca: int = category_index(a.category)
		var cb: int = category_index(b.category)
		return a.order < b.order if ca == cb else ca < cb)


func clear() -> void:
	unlock_log.clear()
	peaks.clear()
	_have.clear()


static func category_index(id: StringName) -> int:
	for i in CATEGORIES.size():
		if CATEGORIES[i][0] == id:
			return i
	return CATEGORIES.size()


static func category_name(id: StringName) -> String:
	var i: int = category_index(id)
	return CATEGORIES[i][1] if i < CATEGORIES.size() else String(id)


func is_unlocked(id: StringName) -> bool:
	return _have.has(id)


func unlocked_count() -> int:
	return unlock_log.size()


func total() -> int:
	return sorted.size()


## Defs of one category in order.
func in_category(cat: StringName) -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for d: AchievementDef in sorted:
		if d.category == cat:
			out.append(d)
	return out


func unlocked_in(cat: StringName) -> int:
	var n: int = 0
	for d: AchievementDef in in_category(cat):
		if is_unlocked(d.id):
			n += 1
	return n


## Remember the highest value of each stat. `stats` is StringName -> BigNum.
func note_stats(stats: Dictionary) -> void:
	for id: Variant in stats:
		note_stat(id, stats[id] as BigNum)


func note_stat(id: Variant, v: BigNum) -> void:
	if v == null:
		return
	var old: BigNum = peaks.get(id) as BigNum
	if old == null or v.gt(old):
		peaks[id] = v.copy()


## Adds `peak_<stat>` floats to a counter dictionary and returns it.
func with_peaks(counters: Dictionary) -> Dictionary:
	for id: Variant in peaks:
		counters["peak_" + String(id)] = (peaks[id] as BigNum).to_float()
	return counters


static func value_of(d: AchievementDef, counters: Dictionary) -> float:
	return float(counters.get(d.counter, 0.0))


## 0 to 1 towards the target; 1 once unlocked.
func progress(d: AchievementDef, counters: Dictionary) -> float:
	if is_unlocked(d.id):
		return 1.0
	return clampf(value_of(d, counters) / maxf(d.target, 0.000001), 0.0, 1.0)


## Unlocks every achievement whose counter has reached its target. Returns the ids unlocked just now, in order.
func check(counters: Dictionary) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for d: AchievementDef in sorted:
		if not _have.has(d.id) and value_of(d, counters) >= d.target:
			_have[d.id] = true
			unlock_log.append(d.id)
			fresh.append(d.id)
	return fresh


## The title of the most recently unlocked achievement that has one, or "".
func current_title() -> String:
	for i in range(unlock_log.size() - 1, -1, -1):
		var d: AchievementDef = defs.get(unlock_log[i]) as AchievementDef
		if d != null and d.title != "":
			return d.title
	return ""


func to_dict() -> Dictionary:
	var p: Dictionary = {}
	for id: Variant in peaks:
		p[String(id)] = (peaks[id] as BigNum).to_array()
	return {"log": unlock_log.map(func(i: StringName) -> String: return String(i)), "peaks": p}


## Loads a dict from to_dict(). Unknown ids are dropped, repeats ignored. Never throws.
func from_dict(d: Variant) -> void:
	clear()
	if not (d is Dictionary):
		return
	var l: Variant = (d as Dictionary).get("log", [])
	if l is Array:
		for k: Variant in (l as Array):
			var id: StringName = StringName(str(k))
			if defs.has(id) and not _have.has(id):
				_have[id] = true
				unlock_log.append(id)
	var p: Variant = (d as Dictionary).get("peaks", {})
	if p is Dictionary:
		for k: Variant in (p as Dictionary):
			peaks[StringName(str(k))] = BigNum.from_variant((p as Dictionary)[k], BigNum.zero()).max_zero()
