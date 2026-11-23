class_name Mastery
extends RefCounted
## Pad mastery: XP and levels per pad. Pure data and maths, no nodes. Sim owns one and exposes it.
## Numbers come from MasteryConfig (content/config/mastery.tres).

var config: MasteryConfig
var _level: Dictionary = {}  # StringName -> int
var _xp: Dictionary = {}     # StringName -> float, XP earned inside the current level


func _init(cfg: MasteryConfig = null) -> void:
	config = cfg if cfg != null else MasteryConfig.new()


func clear() -> void:
	_level.clear()
	_xp.clear()


func level(id: StringName) -> int:
	return int(_level.get(id, 0))


func xp(id: StringName) -> float:
	return float(_xp.get(id, 0.0))


func is_max(id: StringName) -> bool:
	return level(id) >= config.max_level


## XP needed to go from `lv` to `lv + 1`. 0 at the cap.
func xp_for_next(lv: int) -> float:
	if lv >= config.max_level:
		return 0.0
	return config.first_level_xp * pow(config.xp_growth, float(lv))


## 0 to 1 through the current level; 1 at the cap.
func progress(id: StringName) -> float:
	var need: float = xp_for_next(level(id))
	return 1.0 if need <= 0.0 else clampf(xp(id) / need, 0.0, 1.0)


## Adds XP. Returns the number of levels gained.
func add_xp(id: StringName, amount: float) -> int:
	if amount <= 0.0 or is_max(id):
		return 0
	var lv: int = level(id)
	var have: float = xp(id) + amount
	var gained: int = 0
	while lv < config.max_level:
		var need: float = xp_for_next(lv)
		if have < need:
			break
		have -= need
		lv += 1
		gained += 1
	if lv >= config.max_level:
		have = 0.0
	_level[id] = lv
	_xp[id] = have
	return gained


## Multiplier on a press reward from this pad's level.
func yield_mult(id: StringName) -> float:
	return 1.0 + float(level(id)) * config.yield_per_level


func crit_chance_bonus(id: StringName) -> float:
	return float(level(id)) * config.crit_chance_per_level


func crit_damage_bonus(id: StringName) -> float:
	return float(level(id)) * config.crit_damage_per_level


## Rolls up a set of pads: {"pads", "level_sum", "level_cap", "fraction", "maxed"}.
func area(button_ids: Array) -> Dictionary:
	var sum: int = 0
	var maxed: int = 0
	for id: Variant in button_ids:
		var sid: StringName = StringName(str(id))
		sum += level(sid)
		if is_max(sid):
			maxed += 1
	var cap: int = button_ids.size() * config.max_level
	return {
		"pads": button_ids.size(),
		"level_sum": sum,
		"level_cap": cap,
		"fraction": (float(sum) / float(cap)) if cap > 0 else 0.0,
		"maxed": maxed,
	}


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _level:
		out[String(id)] = [level(id), xp(id)]
	return out


## Unknown ids are dropped through `valid`; levels clamp to the cap. Never throws.
func from_dict(d: Variant, valid: Dictionary) -> void:
	clear()
	if not (d is Dictionary):
		return
	for k: Variant in (d as Dictionary):
		var id: StringName = StringName(str(k))
		var v: Variant = (d as Dictionary)[k]
		if not valid.has(id) or not (v is Array) or (v as Array).size() < 2:
			continue
		var lv: int = clampi(int((v as Array)[0]), 0, config.max_level)
		_level[id] = lv
		_xp[id] = 0.0 if lv >= config.max_level else maxf(0.0, float((v as Array)[1]))
