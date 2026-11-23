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
## Streak or critter payout. kind is &"streak" or &"critter"; gains is StringName -> BigNum.
signal bonus_gained(kind: StringName, gains: Dictionary)
signal critter_spawned()
signal critter_gone()
## Heat crossed the zone's hot line (see ZoneDef.heat_hot_at).
signal heat_hot_changed(hot: bool)
signal momentum_tier_changed(tier: int, rising: bool)
## A press gave a pad XP. level and xp are the pad's after the press.
signal mastery_changed(button_id: StringName, level: int, xp: float)
signal mastery_leveled(button_id: StringName, level: int)

# Content (filled by ContentLoader)
var config: GameConfig
var stat_defs: Dictionary = {}       # StringName -> StatDef
var button_defs: Dictionary = {}     # StringName -> ButtonDef
var zone_defs: Dictionary = {}       # StringName -> ZoneDef
var attribute_defs: Dictionary = {}  # StringName -> AttributeDef
var area_defs: Dictionary = {}       # StringName -> AreaDef (zone menu grouping only)
## Owned and equipped relics. Built by ContentLoader. Always non-null after load.
var relics: RelicInventory
## Pad XP and levels. Replaced by ContentLoader with the content's config.
var mastery: Mastery = Mastery.new()
## The in-game calendar (core/game_calendar.gd). Ticks with the sim, saved with it, set up by ContentLoader.
var calendar: GameCalendar = GameCalendar.new()

# State
var stats: Dictionary = {}           # StringName -> BigNum
var prestige_spent: BigNum = BigNum.zero()
var zone_id: StringName = &""
var gates_open: Dictionary = {}      # zone id -> true (latched; survives rebirth)
var attr_levels: Dictionary = {}     # StringName -> int
var play_seconds: float = 0.0
var press_count: int = 0
var rebirth_count: int = 0   # rebirth actions done; unlocks relic slots
var relic_drops: int = 0     # relics dropped from presses this save
var ui_flags: Dictionary = {}  # onboarding: {"unlocked": {id: true}, "seen": {id: true}}. Opaque to the sim, saved with it.
## 0 to 1. Walking charges it (feed_momentum), pressing nudges it (feed_press_momentum). Once charging stops it holds
## for `momentum_hold` seconds, then drains. Stages come from GameConfig.momentum_tiers. Not saved.
var momentum: float = 0.0
var momentum_hold: float = 0.0
var _momentum_tier: int = 0
## 0 to ZoneDef.heat_cap. Standing on a vent charges it, time drains it. Not saved, cleared on zone entry and rebirth.
var heat: float = 0.0
var critter_active: bool = false
var critter_left: float = 0.0
var _critter_next: float = 60.0
var _streak_row: StringName = &""
var _streak_next: int = 0
var _streak_at: float = 0.0
var _streak_ready_at: float = 0.0
var _last_roll_at: float = -1000.0   # play_seconds of the last drop roll
var _last_drop_at: float = 0.0       # play_seconds of the last drop (0 = none yet)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Dev console only (core/dev_commands.gd). Presses cost nothing. Never saved.
var god_mode: bool = false

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
	for z: ZoneDef in zone_defs.values():
		for bid in z.pad_buttons:
			if not button_defs.has(StringName(bid)):
				errs.append("zone %s: pad_buttons has unknown button %s" % [z.id, bid])
	for a: AreaDef in area_defs.values():
		if not zone_defs.has(a.zone):
			errs.append("area %s: unknown zone %s" % [a.id, a.zone])
		for bid in a.pad_buttons:
			var bd: ButtonDef = button_defs.get(StringName(bid)) as ButtonDef
			if bd == null:
				errs.append("area %s: unknown button %s" % [a.id, bid])
			elif bd.zone != a.zone:
				errs.append("area %s: button %s belongs to zone %s" % [a.id, bid, bd.zone])
	for s: StatDef in stat_defs.values():
		for ref: StringName in [s.income_boost_stat, s.gain_boost_stat]:
			if ref != &"" and not stat_defs.has(ref):
				errs.append("stat %s: unknown boost stat %s" % [s.id, ref])
	for key: StringName in [config.prestige_source_stat, config.prestige_stat, config.rp_stat]:
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
	rebirth_count = 0
	relic_drops = 0
	mastery.clear()
	calendar.reset()
	ui_flags = {}
	momentum = 0.0
	momentum_hold = 0.0
	_momentum_tier = 0
	heat = 0.0
	critter_active = false
	critter_left = 0.0
	_streak_row = &""
	_streak_next = 0
	_streak_ready_at = 0.0
	_schedule_critter()
	_last_roll_at = -1000.0
	_last_drop_at = 0.0
	if relics != null:
		relics.from_dict({})
		relics.set_rebirths(0)
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


## The areas of a zone, in listing order. Empty when the zone has none.
func areas_in_zone(z_id: StringName) -> Array[AreaDef]:
	var out: Array[AreaDef] = []
	for a: AreaDef in area_defs.values():
		if a.zone == z_id:
			out.append(a)
	out.sort_custom(func(x: AreaDef, y: AreaDef) -> bool: return x.order < y.order)
	return out


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
	for s: StatDef in stat_defs.values():
		if s.income_factor_per_unit > 0.0:
			boost = boost.mul(get_stat(s.id).mul(BigNum.from_float(s.income_factor_per_unit)).add(BigNum.one()))
	var pm: BigNum = prestige_mult() if d.prestige_boosts_income else BigNum.one()
	var rm: BigNum = BigNum.from_float(relics.multiplier(RelicDef.Effect.CASH_MULT)) if d.relics_boost_income and relics != null else BigNum.one()
	rm = rm.mul(BigNum.from_float(1.0 + momentum_bonus()))
	return Formulas.income(z.base_cash_per_second, boost, pm, rm)


## Rarity id of a pad (&"common" when unknown).
func pad_rarity(button_id: StringName) -> StringName:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	return b.rarity if b != null else &"common"


func can_afford(button_id: StringName) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null:
		return false
	if god_mode:
		return true
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
	return Formulas.button_gain(b, _gain_boost(b.reward_stat), _relic_gain_mult(b), 1.0).mul(BigNum.from_float(mastery.yield_mult(button_id) * pad_yield_mult()))


## MULT_GAIN relics apply to rewards that go into a stat flagged relics_boost_gain.
func _relic_gain_mult(b: ButtonDef) -> BigNum:
	var rs: StatDef = stat_defs.get(b.reward_stat) as StatDef
	if rs == null or not rs.relics_boost_gain or relics == null:
		return BigNum.one()
	return BigNum.from_float(relics.multiplier(RelicDef.Effect.MULT_GAIN))


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


func luck_level() -> int:
	var n: int = 0
	for a: AttributeDef in attribute_defs.values():
		if a.effect == &"luck":
			n += attr_level(a.id)
	return n


## Multiplier on every press reward from the Pad yield attribute.
func pad_yield_mult() -> float:
	return 1.0 + effect_total(&"pad_yield")


## True once the player has rebirthed enough times for this attribute to be bought. Levels bought stay when saves load.
func attr_unlocked(attr_id: StringName) -> bool:
	var a: AttributeDef = attribute_defs.get(attr_id) as AttributeDef
	return a != null and rebirth_count >= a.unlock_rebirths


func walk_speed_mult() -> float:
	return 1.0 + effect_total(&"walk_speed")


## Crit chance, 0 to 1. Pass a button id to include that pad's mastery bonus.
func crit_chance(button_id: StringName = &"") -> float:
	var c: float = effect_total(&"crit_chance")
	if button_id != &"":
		c += mastery.crit_chance_bonus(button_id)
	return clampf(c, 0.0, 1.0)


## What a crit multiplies the reward by: base + pad mastery, then relic crit damage.
func crit_damage(button_id: StringName = &"") -> float:
	var base: float = config.crit_multiplier + effect_total(&"crit_damage")
	if button_id != &"":
		base += mastery.crit_damage_bonus(button_id)
	return base * (relics.multiplier(RelicDef.Effect.CRIT_DAMAGE) if relics != null else 1.0)


## Where a stat or attribute comes from: rows of {source, amount, how_to, kind}. See StatSources.
func stat_sources(id: StringName, is_attribute: bool = false) -> Array[Dictionary]:
	return StatSources.of(self, id, is_attribute)


## Mastery rollup for a zone's pads (see Mastery.area). Empty zone gives zeros.
func area_mastery(z_id: StringName) -> Dictionary:
	var ids: Array = []
	for b: ButtonDef in buttons_in_zone(z_id):
		ids.append(b.id)
	return mastery.area(ids)


## Seconds between repeat presses while standing on a pad.
func press_interval() -> float:
	var z: ZoneDef = current_zone()
	var rate: float = (z.press_rate if z != null else 1.0) * (1.0 + effect_total(&"press_rate"))
	if relics != null:
		rate *= relics.multiplier(RelicDef.Effect.PRESS_RATE)
	return 1.0 / maxf(rate, 0.001)


func offline_cap_seconds() -> float:
	return (config.offline_base_cap_hours + effect_total(&"offline_hours")) * 3600.0


# ---------------------------------------------------------------- actions

func try_press(button_id: StringName, world_pos: Vector3 = Vector3.ZERO) -> bool:
	return _press(button_id, world_pos, true)


func _press(button_id: StringName, world_pos: Vector3, allow_pulse: bool) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null or b.zone != zone_id:
		return false
	if not can_afford(button_id):
		if allow_pulse:
			button_denied.emit(button_id)
		return false
	if not god_mode:
		_set_stat(b.cost_stat, get_stat(b.cost_stat).sub(Formulas.button_cost(b)).max_zero())
	var chance: float = crit_chance(button_id)
	var crit: bool = chance > 0.0 and rng.randf() < chance
	var crit_mult: float = 1.0
	if crit:
		crit_mult = crit_damage(button_id)
	var presses: int = 1
	var dbl: float = relics.total_effect(RelicDef.Effect.DOUBLE_CHANCE)
	if dbl > 0.0 and rng.randf() < dbl:
		presses = 2
	var gain: BigNum = Formulas.button_gain(b, _gain_boost(b.reward_stat), _relic_gain_mult(b), crit_mult).mul(BigNum.from_float(float(presses) * mastery.yield_mult(button_id) * pad_yield_mult()))
	if is_hot():
		gain = gain.mul(BigNum.from_float(current_zone().heat_hot_mult))
	_set_stat(b.reward_stat, get_stat(b.reward_stat).add(gain))
	press_count += 1
	var levels_up: int = mastery.add_xp(button_id, mastery.config.xp_per_press * (1.0 + effect_total(&"mastery_xp")))
	_check_gates()
	_flush()
	button_pressed.emit(button_id, world_pos, gain, crit)
	mastery_changed.emit(button_id, mastery.level(button_id), mastery.xp(button_id))
	if levels_up > 0:
		mastery_leveled.emit(button_id, mastery.level(button_id))
	if allow_pulse:
		_update_streak(b)
		var drop: StringName = _roll_relic_drop()
		if drop != &"":
			relics.add_relic(drop)
		var pulse: float = relics.total_effect(RelicDef.Effect.PULSE_CHANCE)
		if pulse > 0.0 and rng.randf() < pulse:
			for other: ButtonDef in button_defs.values():
				if other.zone == b.zone and other.row == b.row and absi(other.row_index - b.row_index) == 1:
					_press(other.id, world_pos, false)
	return true


func heat_enabled() -> bool:
	var z: ZoneDef = current_zone()
	return z != null and z.heat_cap > 0.0


## True while Heat is at or above the zone's hot line. A Hot press pays heat_hot_mult times the reward.
func is_hot() -> bool:
	return heat_enabled() and heat >= current_zone().heat_hot_at


## The world calls this with the seconds the walker spent on a vent. Fills Heat up to the zone's cap.
func feed_heat(seconds: float) -> void:
	if not heat_enabled() or seconds <= 0.0:
		return
	var z: ZoneDef = current_zone()
	_set_heat(minf(z.heat_cap, heat + z.heat_charge_per_second * seconds))


func _set_heat(value: float) -> void:
	var was: bool = is_hot()
	heat = maxf(0.0, value)
	if is_hot() != was:
		heat_hot_changed.emit(is_hot())


## Walking calls this with the distance moved (texels). Fills momentum up to 1.
func feed_momentum(distance: float) -> void:
	_add_momentum(maxf(distance, 0.0) * config.momentum_per_unit)


## A pad press (from the game's pad input, not the headless balance sim) nudges momentum; a crit nudges it more.
func feed_press_momentum(crit: bool) -> void:
	_add_momentum(config.momentum_per_press + (config.momentum_per_crit if crit else 0.0))


## Stage index for a momentum value: 0 is idle, then one more for each threshold reached.
func momentum_tier_for(value: float) -> int:
	var t: int = 0
	for th: float in config.momentum_tier_thresholds:
		if value >= th:
			t += 1
	return t


func momentum_tier() -> int:
	return _momentum_tier


func momentum_tier_name(tier: int) -> String:
	var names: PackedStringArray = config.momentum_tier_names
	return names[clampi(tier, 0, names.size() - 1)]


## Income bonus (0.4 = +40%): a smooth part that follows the bar, plus a kicker for each stage reached.
func momentum_bonus() -> float:
	var extra: float = 0.0
	for i in _momentum_tier:
		extra += config.momentum_tier_bonus[i]
	return momentum * config.momentum_max_bonus + extra


func _add_momentum(amount: float) -> void:
	if amount <= 0.0:
		return
	momentum = minf(1.0, momentum + amount)
	momentum_hold = config.momentum_surge_hold if momentum >= 1.0 else config.momentum_grace
	_sync_momentum_tier()


func _sync_momentum_tier() -> void:
	var t: int = momentum_tier_for(momentum)
	if t != _momentum_tier:
		var rising: bool = t > _momentum_tier
		_momentum_tier = t
		momentum_tier_changed.emit(t, rising)


func _schedule_critter() -> void:
	if config != null:
		_critter_next = rng.randf_range(config.critter_min_interval, config.critter_max_interval)


func _step_critter(dt: float) -> void:
	if critter_active:
		critter_left -= dt
		if critter_left <= 0.0:
			critter_active = false
			_schedule_critter()
			critter_gone.emit()
	else:
		_critter_next -= dt
		if _critter_next <= 0.0:
			critter_active = true
			critter_left = config.critter_lifetime
			critter_spawned.emit()


## Click on the golden critter. Pays critter_income_seconds of income. False if none is out.
func catch_critter() -> bool:
	if not critter_active:
		return false
	critter_active = false
	_schedule_critter()
	var gains: Dictionary = _grant_income_seconds(config.critter_income_seconds)
	critter_gone.emit()
	bonus_gained.emit(&"critter", gains)
	return true


func _grant_income_seconds(seconds: float) -> Dictionary:
	var gains: Dictionary = {}
	var sb: BigNum = BigNum.from_float(seconds)
	for s: StatDef in stat_defs.values():
		if s.passive:
			var g: BigNum = income_per_second(s.id).mul(sb)
			_set_stat(s.id, get_stat(s.id).add(g))
			gains[s.id] = g
	_check_gates()
	_flush()
	return gains


## Pad streak: m1, m2, m3 in order, each within streak_window of the last, pays streak_bonus_seconds of income.
func _update_streak(b: ButtonDef) -> void:
	if b.row_index == 0:
		_streak_row = b.row
		_streak_next = 1
		_streak_at = play_seconds
		return
	if b.row == _streak_row and b.row_index == _streak_next and play_seconds - _streak_at <= config.streak_window:
		_streak_at = play_seconds
		_streak_next += 1
		var last_index: int = 0
		for other: ButtonDef in button_defs.values():
			if other.zone == b.zone and other.row == b.row:
				last_index = maxi(last_index, other.row_index)
		if b.row_index >= last_index:
			_streak_row = &""
			if play_seconds >= _streak_ready_at:
				_streak_ready_at = play_seconds + config.streak_cooldown
				bonus_gained.emit(&"streak", _grant_income_seconds(config.streak_bonus_seconds))
	else:
		_streak_row = &""


## One drop roll per roll_interval of play time, with a guaranteed first drop and a pity timer.
func _roll_relic_drop() -> StringName:
	var rc: RelicConfig = relics.config
	if play_seconds - _last_roll_at < rc.roll_interval:
		return &""
	_last_roll_at = play_seconds
	var due: float = rc.first_drop_seconds if relic_drops == 0 else rc.pity_seconds
	var force: bool = play_seconds - _last_drop_at >= due
	var drop: StringName = relics.roll_drop(rng, luck_level(), force)
	if drop != &"":
		relic_drops += 1
		_last_drop_at = play_seconds
	return drop


## Advance the simulation by dt seconds of passive income. Presses are separate (try_press).
func step(dt: float) -> void:
	play_seconds += dt
	calendar.advance(dt)
	if momentum_hold > 0.0:
		momentum_hold = maxf(0.0, momentum_hold - dt)
	elif momentum > 0.0:
		momentum = maxf(0.0, momentum - config.momentum_decay_per_second * dt)
		_sync_momentum_tier()
	if heat > 0.0:
		var zd: ZoneDef = current_zone()
		_set_heat(heat - (zd.heat_decay_per_second if zd != null else heat) * dt)
	_step_critter(dt)
	var dtb: BigNum = BigNum.from_float(dt)
	for s: StatDef in stat_defs.values():
		if s.passive:
			_set_stat(s.id, get_stat(s.id).add(income_per_second(s.id).mul(dtb)))
	_check_gates()
	_flush()


## Dev console: set a stat outright, then settle gates and signals like any other change.
func dev_set_stat(stat_id: StringName, value: BigNum) -> bool:
	if not stat_defs.has(stat_id):
		return false
	_set_stat(stat_id, value.max_zero())
	_check_gates()
	_flush()
	return true


## Dev console: move to a zone whether or not it is unlocked. Opens the gate that leads there so the move sticks.
func dev_force_zone(z_id: StringName) -> bool:
	if not zone_defs.has(z_id):
		return false
	if z_id == zone_id:
		return true
	for z: ZoneDef in zone_defs.values():
		if z.next_zone == z_id:
			gates_open[z.id] = true
	zone_id = z_id
	zone_entered.emit(z_id)
	return true


func can_rebirth() -> bool:
	return get_stat(config.prestige_source_stat).gte(BigNum.from_float(config.rebirth_min_value))


func prestige_gain_preview() -> BigNum:
	return _prestige_gain() if can_rebirth() else BigNum.zero()


## The source stat, boosted once it passes prestige_push_threshold so pushing further pays more than linearly.
func _prestige_gain() -> BigNum:
	var v: BigNum = get_stat(config.prestige_source_stat).copy()
	var th: float = config.prestige_push_threshold
	var f: float = v.to_float()
	if th > 0.0 and f > th:
		v = v.mul(BigNum.from_float(pow(f / th, config.prestige_push_exponent)))
	return v


## Resets stats flagged resets_on_rebirth and banks the source stat into Prestige.
## Rebirths therefore only boost Multiplier gain (via gain_boost_stat). Gates stay open.
func try_rebirth() -> bool:
	if not can_rebirth():
		return false
	var gained: BigNum = _prestige_gain()
	for s: StatDef in stat_defs.values():
		if s.resets_on_rebirth:
			_set_stat(s.id, BigNum.from_float(s.start))
	_set_stat(config.prestige_stat, get_stat(config.prestige_stat).add(gained))
	_set_stat(config.rp_stat, get_stat(config.rp_stat).add(BigNum.from_float(float(rp_for_rebirth(rebirth_count)))))
	rebirth_count += 1
	relics.set_rebirths(rebirth_count)
	_set_heat(0.0)
	_flush()
	rebirth_done.emit(gained)
	return true


## Rebirth Points paid by the rebirth that follows `done` earlier ones: rp_base + rp_growth * done, rounded down, at least 1.
func rp_for_rebirth(done: int) -> int:
	return maxi(1, int(floorf(config.rp_base + config.rp_growth * float(done))))


## Everything `count` rebirths have paid in total. Used to backfill saves from before Rebirth Points.
func rp_total_for(count: int) -> int:
	var n: int = 0
	for i: int in count:
		n += rp_for_rebirth(i)
	return n


## What the next rebirth would pay, or 0 while it is not available.
func rp_gain_preview() -> int:
	return rp_for_rebirth(rebirth_count) if can_rebirth() else 0


## Rebirth Points in hand.
func rp_available() -> BigNum:
	return get_stat(config.rp_stat)


## What an attribute is paid with, as a balance: Prestige earned and not yet spent, or Rebirth Points.
func attribute_available(a: AttributeDef) -> BigNum:
	return rp_available() if a.currency == config.rp_stat else prestige_available()


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
	if a == null or attr_level(attr_id) >= a.cap or not attr_unlocked(attr_id):
		return false
	var cost: BigNum = attribute_cost(attr_id)
	if attribute_available(a).lt(cost):
		return false
	if a.currency == config.rp_stat:
		_set_stat(config.rp_stat, rp_available().sub(cost).max_zero())
	else:
		prestige_spent = prestige_spent.add(cost)
	attr_levels[attr_id] = attr_level(attr_id) + 1
	attribute_bought.emit(attr_id, attr_level(attr_id))
	return true


## Saves from before Larkmoor: players who had walked on to zone 2 keep it. Larkmoor's far gate is latched open for them
## (and the onboarding gate with it), so zone 2 stays unlocked. Players still in the onboarding meadow are untouched:
## their gate now leads to Larkmoor.
func _migrate_zones() -> void:
	if zone_id == &"zone2" and zone_defs.has(&"larkmoor"):
		gates_open[&"larkmoor"] = true
		gates_open[&"zone1"] = true


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
	_set_heat(0.0)
	zone_entered.emit(z_id)
	return true


func is_gate_open(z_id: StringName) -> bool:
	return bool(gates_open.get(z_id, false))


## Credits passive income for time away. Capped by offline_cap_seconds(). Returns seconds credited.
func apply_offline(seconds: float) -> float:
	var secs: float = clampf(seconds, 0.0, offline_cap_seconds())
	if secs <= 0.0:
		return 0.0
	calendar.advance(secs)   # the world keeps turning while you are away
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
		"rebirth_count": rebirth_count,
		"relic_drops": relic_drops,
		"last_drop_at": _last_drop_at,
		"ui_flags": ui_flags.duplicate(true),
		"relics": relics.to_dict(),
		"mastery": mastery.to_dict(),
		"calendar": calendar.to_dict(),
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
	if bool(d.get("rp_backfill", false)):   # save v4: rebirths done before Rebirth Points existed paid out retroactively
		stats[config.rp_stat] = BigNum.from_float(float(rp_total_for(int(d.get("rebirth_count", 0)))))
	var z: StringName = StringName(str(d.get("zone", "")))
	if zone_defs.has(z):
		zone_id = z
	var g: Variant = d.get("gates", [])
	if g is Array:
		for k: Variant in (g as Array):
			var gid: StringName = StringName(str(k))
			if zone_defs.has(gid):
				gates_open[gid] = true
	_migrate_zones()
	var a: Variant = d.get("attributes", {})
	if a is Dictionary:
		for k: Variant in (a as Dictionary):
			var aid: StringName = StringName(str(k))
			if attribute_defs.has(aid):
				var cap: int = (attribute_defs[aid] as AttributeDef).cap
				attr_levels[aid] = clampi(int((a as Dictionary)[k]), 0, cap)
	play_seconds = float(d.get("play_seconds", 0.0))
	press_count = int(d.get("press_count", 0))
	rebirth_count = int(d.get("rebirth_count", 0))
	relic_drops = int(d.get("relic_drops", 0))
	_last_drop_at = float(d.get("last_drop_at", play_seconds))
	var uf: Variant = d.get("ui_flags", {})
	if uf is Dictionary:
		ui_flags = (uf as Dictionary).duplicate(true)
	var rd: Variant = d.get("relics", {})
	if rd is Dictionary:
		relics.from_dict(rd)
	relics.set_rebirths(rebirth_count)
	mastery.from_dict(d.get("mastery", {}), button_defs)
	calendar.from_dict(d.get("calendar", {}))
	_dirty.clear()
	return true
