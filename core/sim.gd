class_name Sim
extends RefCounted
## The whole game simulation. No nodes, no scenes, no autoloads: it runs from tests and tools/sim.gd.
## GameState (autoload) owns one Sim and forwards its signals to EventBus.

signal stat_changed(stat_id: StringName, value: BigNum)
signal button_pressed(button_id: StringName, world_pos: Vector3, gain: BigNum, crit: bool)
signal button_denied(button_id: StringName)
signal zone_entered(zone_id: StringName)
signal gate_opened(gate_id: StringName)
signal rebirth_done(prestige_gained: BigNum)
signal attribute_bought(attribute_id: StringName, level: int)
signal offline_gained(seconds: float, gains: Dictionary)

# Content (filled by ContentLoader)
var config: GameConfig
var stat_defs: Dictionary = {}       # StringName -> StatDef
var button_defs: Dictionary = {}     # StringName -> ButtonDef
var zone_defs: Dictionary = {}       # StringName -> ZoneDef
var attribute_defs: Dictionary = {}  # StringName -> AttributeDef

# State
var stats: Dictionary = {}           # StringName -> BigNum
var prestige_spent: BigNum = BigNum.zero()
var zone_id: StringName = &""
var gates_open: Dictionary = {}      # zone id -> true (latched; survives rebirth)
var attr_levels: Dictionary = {}     # StringName -> int
var play_seconds: float = 0.0
var press_count: int = 0
## Hook for relics (M4). 1 = no effect.
var relic_mult: BigNum = BigNum.one()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _dirty: Dictionary = {}


## Checks that content refers only to things that exist. Returns error strings (empty = fine).
func validate() -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	if config == null:
		errs.append("no config")
		return errs
	if zone_defs.is_empty():
		errs.append("no zones")
	for b: ButtonDef in button_defs.values():
		if not stat_defs.has(b.cost_stat):
			errs.append("button %s: unknown cost_stat %s" % [b.id, b.cost_stat])
		if not stat_defs.has(b.reward_stat):
			errs.append("button %s: unknown reward_stat %s" % [b.id, b.reward_stat])
		if not zone_defs.has(b.zone):
			errs.append("button %s: unknown zone %s" % [b.id, b.zone])
	for z: ZoneDef in zone_defs.values():
		if z.gate_stat != &"" and not stat_defs.has(z.gate_stat):
			errs.append("zone %s: unknown gate_stat %s" % [z.id, z.gate_stat])
		if z.next_zone != &"" and not zone_defs.has(z.next_zone):
			errs.append("zone %s: unknown next_zone %s" % [z.id, z.next_zone])
	for s: StatDef in stat_defs.values():
		for ref: StringName in [s.income_boost_stat, s.gain_boost_stat]:
			if ref != &"" and not stat_defs.has(ref):
				errs.append("stat %s: unknown boost stat %s" % [s.id, ref])
	for key: StringName in [config.prestige_source_stat, config.prestige_stat]:
		if not stat_defs.has(key):
			errs.append("config: unknown stat %s" % key)
	return errs


func new_game() -> void:
	stats.clear()
	for s: StatDef in stat_defs.values():
		stats[s.id] = BigNum.from_float(s.start)
	prestige_spent = BigNum.zero()
	gates_open.clear()
	attr_levels.clear()
	play_seconds = 0.0
	press_count = 0
	zone_id = _first_zone()
	_dirty.clear()


func _first_zone() -> StringName:
	var best: ZoneDef = null
	for z: ZoneDef in zone_defs.values():
		if best == null or z.order < best.order:
			best = z
	return best.id if best != null else &""


# ---------------------------------------------------------------- queries

func get_stat(stat_id: StringName) -> BigNum:
	var v: Variant = stats.get(stat_id)
	return (v as BigNum) if v != null else BigNum.zero()


func current_zone() -> ZoneDef:
	return zone_defs.get(zone_id) as ZoneDef


func prestige_mult() -> BigNum:
	return Formulas.prestige_mult(get_stat(config.prestige_stat), config.prestige_exponent)


func income_per_second(stat_id: StringName) -> BigNum:
	var d: StatDef = stat_defs.get(stat_id) as StatDef
	var z: ZoneDef = current_zone()
	if d == null or z == null or not d.passive:
		return BigNum.zero()
	var boost: BigNum = BigNum.one()
	if d.income_boost_stat != &"":
		boost = get_stat(d.income_boost_stat).add(BigNum.one())
	var pm: BigNum = prestige_mult() if d.prestige_boosts_income else BigNum.one()
	return Formulas.income(z.base_cash_per_second, boost, pm, relic_mult)


func can_afford(button_id: StringName) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null:
		return false
	return get_stat(b.cost_stat).gte(Formulas.button_cost(b))


func buttons_in_zone(z_id: StringName) -> Array[ButtonDef]:
	var out: Array[ButtonDef] = []
	for b: ButtonDef in button_defs.values():
		if b.zone == z_id:
			out.append(b)
	return out


## Reward a press would give right now, without crit.
func press_gain_preview(button_id: StringName) -> BigNum:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null:
		return BigNum.zero()
	return Formulas.button_gain(b, _gain_boost(b.reward_stat), relic_mult, 1.0)


func _gain_boost(reward_stat: StringName) -> BigNum:
	var d: StatDef = stat_defs.get(reward_stat) as StatDef
	if d == null or d.gain_boost_stat == &"":
		return BigNum.one()
	return get_stat(d.gain_boost_stat).add(BigNum.one())


# ---------------------------------------------------------------- attribute effects

func attr_level(attr_id: StringName) -> int:
	return int(attr_levels.get(attr_id, 0))


func effect_total(effect: StringName) -> float:
	var total: float = 0.0
	for a: AttributeDef in attribute_defs.values():
		if a.effect == effect:
			total += a.per_level * float(attr_level(a.id))
	return total


func walk_speed_mult() -> float:
	return 1.0 + effect_total(&"walk_speed")


func crit_chance() -> float:
	return clampf(effect_total(&"crit_chance"), 0.0, 1.0)


## Seconds between repeat presses while standing on a pad.
func press_interval() -> float:
	var z: ZoneDef = current_zone()
	var rate: float = (z.press_rate if z != null else 1.0) * (1.0 + effect_total(&"press_rate"))
	return 1.0 / maxf(rate, 0.001)


func offline_cap_seconds() -> float:
	return (config.offline_base_cap_hours + effect_total(&"offline_hours")) * 3600.0


# ---------------------------------------------------------------- actions

func try_press(button_id: StringName, world_pos: Vector3 = Vector3.ZERO) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null or b.zone != zone_id:
		return false
	if not can_afford(button_id):
		button_denied.emit(button_id)
		return false
	_set_stat(b.cost_stat, get_stat(b.cost_stat).sub(Formulas.button_cost(b)).max_zero())
	var chance: float = crit_chance()
	var crit: bool = chance > 0.0 and rng.randf() < chance
	var gain: BigNum = Formulas.button_gain(b, _gain_boost(b.reward_stat), relic_mult, config.crit_multiplier if crit else 1.0)
	_set_stat(b.reward_stat, get_stat(b.reward_stat).add(gain))
	press_count += 1
	_check_gates()
	_flush()
	button_pressed.emit(button_id, world_pos, gain, crit)
	return true


## Advance the simulation by dt seconds of passive income. Presses are separate (try_press).
func step(dt: float) -> void:
	play_seconds += dt
	var dtb: BigNum = BigNum.from_float(dt)
	for s: StatDef in stat_defs.values():
		if s.passive:
			_set_stat(s.id, get_stat(s.id).add(income_per_second(s.id).mul(dtb)))
	_check_gates()
	_flush()


func can_rebirth() -> bool:
	return get_stat(config.prestige_source_stat).gte(BigNum.from_float(config.rebirth_min_value))


func prestige_gain_preview() -> BigNum:
	return get_stat(config.prestige_source_stat) if can_rebirth() else BigNum.zero()


## Resets stats flagged resets_on_rebirth and banks the source stat into Prestige.
## Rebirths therefore only boost Multiplier gain (via gain_boost_stat). Gates stay open.
func try_rebirth() -> bool:
	if not can_rebirth():
		return false
	var gained: BigNum = get_stat(config.prestige_source_stat).copy()
	for s: StatDef in stat_defs.values():
		if s.resets_on_rebirth:
			_set_stat(s.id, BigNum.from_float(s.start))
	_set_stat(config.prestige_stat, get_stat(config.prestige_stat).add(gained))
	_flush()
	rebirth_done.emit(gained)
	return true


## Prestige earned and not yet spent on attributes. prestige_mult uses lifetime prestige.
func prestige_available() -> BigNum:
	return get_stat(config.prestige_stat).sub(prestige_spent).max_zero()


func attribute_cost(attr_id: StringName) -> BigNum:
	var a: AttributeDef = attribute_defs.get(attr_id) as AttributeDef
	if a == null:
		return BigNum.zero()
	return Formulas.attribute_cost(a, attr_level(attr_id))


func buy_attribute(attr_id: StringName) -> bool:
	var a: AttributeDef = attribute_defs.get(attr_id) as AttributeDef
	if a == null or attr_level(attr_id) >= a.cap:
		return false
	var cost: BigNum = attribute_cost(attr_id)
	if prestige_available().lt(cost):
		return false
	prestige_spent = prestige_spent.add(cost)
	attr_levels[attr_id] = attr_level(attr_id) + 1
	attribute_bought.emit(attr_id, attr_level(attr_id))
	return true


func is_zone_unlocked(z_id: StringName) -> bool:
	if not zone_defs.has(z_id):
		return false
	if z_id == _first_zone():
		return true
	for z: ZoneDef in zone_defs.values():
		if z.next_zone == z_id and gates_open.get(z.id, false):
			return true
	return false


func enter_zone(z_id: StringName) -> bool:
	if z_id == zone_id or not is_zone_unlocked(z_id):
		return false
	zone_id = z_id
	zone_entered.emit(z_id)
	return true


func is_gate_open(z_id: StringName) -> bool:
	return bool(gates_open.get(z_id, false))


## Credits passive income for time away. Capped by offline_cap_seconds(). Returns seconds credited.
func apply_offline(seconds: float) -> float:
	var secs: float = clampf(seconds, 0.0, offline_cap_seconds())
	if secs <= 0.0:
		return 0.0
	var gains: Dictionary = {}
	var sb: BigNum = BigNum.from_float(secs)
	for s: StatDef in stat_defs.values():
		if s.passive:
			var g: BigNum = income_per_second(s.id).mul(sb)
			_set_stat(s.id, get_stat(s.id).add(g))
			gains[s.id] = g
	_check_gates()
	_flush()
	offline_gained.emit(secs, gains)
	return secs


# ---------------------------------------------------------------- internals

func _set_stat(stat_id: StringName, value: BigNum) -> void:
	stats[stat_id] = value
	_dirty[stat_id] = true


func _flush() -> void:
	if _dirty.is_empty():
		return
	var ids: Array = _dirty.keys()
	_dirty.clear()
	for id: StringName in ids:
		stat_changed.emit(id, get_stat(id))


func _check_gates() -> void:
	var z: ZoneDef = current_zone()
	if z == null or z.gate_stat == &"" or is_gate_open(z.id):
		return
	if get_stat(z.gate_stat).gte(BigNum.from_float(z.gate_threshold)):
		gates_open[z.id] = true
		gate_opened.emit(z.id)


# ---------------------------------------------------------------- save format

func to_dict() -> Dictionary:
	var s: Dictionary = {}
	for id: StringName in stats:
		s[String(id)] = (stats[id] as BigNum).to_array()
	var a: Dictionary = {}
	for id: StringName in attr_levels:
		a[String(id)] = attr_levels[id]
	var g: Array = []
	for id: StringName in gates_open:
		g.append(String(id))
	return {
		"stats": s,
		"prestige_spent": prestige_spent.to_array(),
		"zone": String(zone_id),
		"gates": g,
		"attributes": a,
		"play_seconds": play_seconds,
		"press_count": press_count,
	}


## Loads a dict from to_dict(). Unknown ids are ignored, missing ones keep defaults. Never throws.
func from_dict(d: Dictionary) -> bool:
	new_game()
	if d.is_empty():
		return false
	var s: Variant = d.get("stats", {})
	if s is Dictionary:
		for k: Variant in (s as Dictionary):
			var id: StringName = StringName(str(k))
			if stat_defs.has(id):
				stats[id] = BigNum.from_variant((s as Dictionary)[k], BigNum.zero()).max_zero()
	prestige_spent = BigNum.from_variant(d.get("prestige_spent"), BigNum.zero()).max_zero()
	var z: StringName = StringName(str(d.get("zone", "")))
	if zone_defs.has(z):
		zone_id = z
	var g: Variant = d.get("gates", [])
	if g is Array:
		for k: Variant in (g as Array):
			var gid: StringName = StringName(str(k))
			if zone_defs.has(gid):
				gates_open[gid] = true
	var a: Variant = d.get("attributes", {})
	if a is Dictionary:
		for k: Variant in (a as Dictionary):
			var aid: StringName = StringName(str(k))
			if attribute_defs.has(aid):
				var cap: int = (attribute_defs[aid] as AttributeDef).cap
				attr_levels[aid] = clampi(int((a as Dictionary)[k]), 0, cap)
	play_seconds = float(d.get("play_seconds", 0.0))
	press_count = int(d.get("press_count", 0))
	_dirty.clear()
	return true
