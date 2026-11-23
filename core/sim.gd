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
## A zone reset (Bloom, ...) was done: its id and the currency it paid.
signal reset_done(reset_id: StringName, gained: int)
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
## A flower tier's pads just became pressable (the last pad of the tier below was pressed).
signal tier_opened(tier_id: StringName)
## An achievement just unlocked (core/achievements.gd). Never fires for ones a loaded save already had.
signal achievement_unlocked(achievement_id: StringName)

# Content (filled by ContentLoader)
var config: GameConfig
var stat_defs: Dictionary = {}       # StringName -> StatDef
var button_defs: Dictionary = {}     # StringName -> ButtonDef
var zone_defs: Dictionary = {}       # StringName -> ZoneDef
var attribute_defs: Dictionary = {}  # StringName -> AttributeDef
var area_defs: Dictionary = {}       # StringName -> AreaDef (zone menu grouping only)
var reset_defs: Dictionary = {}      # StringName -> ZoneResetDef (the zone resets, content/resets)
var tier_defs: Dictionary = {}       # StringName -> TierDef (the flower rows, content/tiers)
## Owned and equipped relics. Built by ContentLoader. Always non-null after load.
var relics: RelicInventory
## Pad XP and levels. Replaced by ContentLoader with the content's config.
var mastery: Mastery = Mastery.new()
## History numbers (income graph, time per zone, bests) for the History screen. Lifetime part is saved.
var run_stats: RunStats = RunStats.new()
## Which achievements are unlocked (the Ledger). Replaced by ContentLoader with the content's list.
var achievements: Achievements = Achievements.new()
## The in-game calendar (core/game_calendar.gd). Ticks with the sim, saved with it, set up by ContentLoader.
var calendar: GameCalendar = GameCalendar.new()

# State
var stats: Dictionary = {}           # StringName -> BigNum
var prestige_spent: BigNum = BigNum.zero()
var zone_id: StringName = &""
var gates_open: Dictionary = {}      # zone id -> true (latched; survives rebirth)
var tiers_open: Dictionary = {}      # tier id -> true (latched; survives rebirth). A zone's first tier needs no entry.
var zones_entered: Dictionary = {}   # zone id -> true once its entry grants were paid (latched)
var attr_levels: Dictionary = {}     # StringName -> int
var play_seconds: float = 0.0
var press_count: int = 0
## Every stat as it stood just before the last zone reset (stat id -> BigNum). The reset animation counts down from it.
var bloom_before: Dictionary = {}
## True while an automatic press (Dew Sprites, Wildflower) is running, so the UI can skip momentum and the press streak.
var auto_press_active: bool = false
var _auto_acc: float = 0.0
var _wild_acc: float = 0.0
var reset_counts: Dictionary = {}    # reset id -> times done (ZoneResetDef); each adds its bonus to every pad reward
var rebirth_count: int = 0   # rebirth actions done; unlocks relic slots
## While a relic pulse presses a neighbour, the pad that started it (else &""). Read inside the button_pressed handler so
## the world can draw the pulse differently. pulse_order counts the neighbours hit by this pulse, from 0.
var pulse_source: StringName = &""
var pulse_order: int = 0
var relic_drops: int = 0     # relics dropped from presses this save
## Which stat rows the HUD strip shows per zone (core/hud_layout.gd). Saved with the game.
var hud_layout: HudLayout = HudLayout.new()
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

var _ach_clock: float = 0.0
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
	for t: TierDef in tier_defs.values():
		if not stat_defs.has(t.stat):
			errs.append("tier %s: unknown stat %s" % [t.id, t.stat])
		if not zone_defs.has(t.zone):
			errs.append("tier %s: unknown zone %s" % [t.id, t.zone])
	for b: ButtonDef in button_defs.values():
		if not tier_defs.is_empty() and not tier_defs.has(b.row):
			errs.append("button %s: row %s is not a tier" % [b.id, b.row])
		elif tier_defs.has(b.row) and (tier_defs[b.row] as TierDef).stat != b.reward_stat:
			errs.append("button %s: pays %s but its tier pays %s" % [b.id, b.reward_stat, (tier_defs[b.row] as TierDef).stat])
	for z: ZoneDef in zone_defs.values():
		for sid: Variant in z.entry_grants:
			if not stat_defs.has(StringName(str(sid))):
				errs.append("zone %s: entry grant for unknown stat %s" % [z.id, sid])
		if z.boost_stat != &"" and not stat_defs.has(z.boost_stat):
			errs.append("zone %s: unknown boost_stat %s" % [z.id, z.boost_stat])
	for s: StatDef in stat_defs.values():
		for t: String in s.buff_stats:
			if not stat_defs.has(StringName(t)):
				errs.append("stat %s: unknown buff target %s" % [s.id, t])
		for ref: StringName in [s.income_boost_stat, s.gain_boost_stat]:
			if ref != &"" and not stat_defs.has(ref):
				errs.append("stat %s: unknown boost stat %s" % [s.id, ref])
	for r: ZoneResetDef in reset_defs.values():
		for key: StringName in [r.currency, r.source_stat]:
			if not stat_defs.has(key):
				errs.append("reset %s: unknown stat %s" % [r.id, key])
		for sid: String in r.resets:
			if not stat_defs.has(StringName(sid)):
				errs.append("reset %s: resets unknown stat %s" % [r.id, sid])
		if not zone_defs.has(r.gate_zone):
			errs.append("reset %s: unknown gate zone %s" % [r.id, r.gate_zone])
		for zid: String in r.zones:
			if not zone_defs.has(StringName(zid)):
				errs.append("reset %s: unknown zone %s" % [r.id, zid])
	var known: Dictionary = achievement_counters()
	for a: AchievementDef in achievements.sorted:
		if Achievements.category_index(a.category) >= Achievements.CATEGORIES.size():
			errs.append("achievement %s: unknown category %s" % [a.id, a.category])
		var peak_ok: bool = String(a.counter).begins_with("peak_") and stat_defs.has(StringName(String(a.counter).trim_prefix("peak_")))
		if not known.has(a.counter) and not peak_ok:
			errs.append("achievement %s: unknown counter %s" % [a.id, a.counter])
		if a.target <= 0.0:
			errs.append("achievement %s: target must be above zero" % a.id)
	for z: ZoneDef in zone_defs.values():
		if z.prestige_source_stat != &"" and not stat_defs.has(z.prestige_source_stat):
			errs.append("zone %s: unknown prestige_source_stat %s" % [z.id, z.prestige_source_stat])
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
	tiers_open.clear()
	zones_entered.clear()
	attr_levels.clear()
	play_seconds = 0.0
	press_count = 0
	rebirth_count = 0
	reset_counts.clear()
	relic_drops = 0
	mastery.clear()
	run_stats.clear()
	achievements.clear()
	_ach_clock = 0.0
	calendar.reset()
	ui_flags = {}
	hud_layout.clear()
	momentum = 0.0
	momentum_hold = 0.0
	_momentum_tier = 0
	heat = 0.0
	bloom_before.clear()
	_auto_acc = 0.0
	_wild_acc = 0.0
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
	if d == null or z == null or not d.passive or not d.in_zone(z.id):
		return BigNum.zero()
	var boost: BigNum = BigNum.one()
	if d.income_boost_stat != &"":
		boost = get_stat(d.income_boost_stat).add(BigNum.one())
	for s: StatDef in stat_defs.values():
		if s.income_factor_per_unit > 0.0 and s.in_zone(z.id):
			boost = boost.mul(get_stat(s.id).mul(BigNum.from_float(s.income_factor_per_unit)).add(BigNum.one()))
	var pm: BigNum = prestige_mult() if d.prestige_boosts_income else BigNum.one()
	var rm: BigNum = BigNum.from_float(relics.multiplier(RelicDef.Effect.CASH_MULT)) if d.relics_boost_income and relics != null else BigNum.one()
	rm = rm.mul(BigNum.from_float((1.0 + momentum_bonus()) * (1.0 + effect_total(&"sun_rate") + effect_total(&"ember_rate"))))
	return Formulas.income(z.base_cash_per_second, boost, pm, rm)


## Rarity id of a pad (&"common" when unknown).
func pad_rarity(button_id: StringName) -> StringName:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	return b.rarity if b != null else &"common"


## The tiers of a zone, lowest order first.
func tiers_in_zone(z_id: StringName) -> Array[TierDef]:
	var out: Array[TierDef] = []
	for t: TierDef in tier_defs.values():
		if t.zone == z_id:
			out.append(t)
	out.sort_custom(func(a: TierDef, b: TierDef) -> bool: return a.order < b.order)
	return out


## The tier a pad belongs to, or null (the Ember Quarry rows are not tiers).
func tier_of(button_id: StringName) -> TierDef:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	return tier_defs.get(b.row) as TierDef if b != null else null


## A zone's first tier is open from the start; every other opens once the last pad of the tier below was pressed.
func is_tier_open(tier_id: StringName) -> bool:
	var t: TierDef = tier_defs.get(tier_id) as TierDef
	if t == null:
		return true
	var first: Array[TierDef] = tiers_in_zone(t.zone)
	return first.is_empty() or first[0].id == tier_id or bool(tiers_open.get(tier_id, false))


## The tier a tier opens when its last pad is pressed (same zone, next order), or null.
func next_tier(tier_id: StringName) -> TierDef:
	var t: TierDef = tier_defs.get(tier_id) as TierDef
	if t == null:
		return null
	var list: Array[TierDef] = tiers_in_zone(t.zone)
	var i: int = list.find(t)
	return list[i + 1] if i >= 0 and i + 1 < list.size() else null


## True while the pad's tier has not opened yet. Locked pads cannot be pressed or bought.
func is_pad_locked(button_id: StringName) -> bool:
	var t: TierDef = tier_of(button_id)
	return t != null and not is_tier_open(t.id)


## The pad that opens the next tier: the last one of the row.
func is_row_finisher(b: ButtonDef) -> bool:
	for other: ButtonDef in button_defs.values():
		if other.zone == b.zone and other.row == b.row and other.row_index > b.row_index:
			return false
	return true


func can_afford(button_id: StringName) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null or is_pad_locked(button_id):
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


## Reward of one press right now, with every current multiplier. The real press and the tooltips both use this.
## `crit_mult` is 1.0 for a normal press; `presses` is 2 on a relic double.
func press_gain(button_id: StringName, crit_mult: float = 1.0, presses: int = 1) -> BigNum:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null:
		return BigNum.zero()
	var gain: BigNum = Formulas.button_gain(b, _gain_boost(b.reward_stat), _relic_gain_mult(b), crit_mult).mul(BigNum.from_float(float(presses) * mastery.yield_mult(button_id) * pad_yield_mult()))
	if is_hot():
		gain = gain.mul(BigNum.from_float(current_zone().heat_hot_mult))
	return gain


## Reward a press would give right now, without crit or a double.
func press_gain_preview(button_id: StringName) -> BigNum:
	return press_gain(button_id)


## Expected reward per press: the preview times the average crit and double-press boosts.
func press_gain_average(button_id: StringName) -> BigNum:
	var chance: float = crit_chance(button_id)
	var dbl: float = _double_chance()
	var boost: float = (1.0 + chance * (crit_damage(button_id) - 1.0)) * (1.0 + clampf(dbl, 0.0, 1.0))
	return press_gain(button_id).mul(BigNum.from_float(boost))


## Chance a press counts twice: relics plus the Twin Petals gift.
func _double_chance() -> float:
	return (relics.total_effect(RelicDef.Effect.DOUBLE_CHANCE) if relics != null else 0.0) + effect_total(&"double_chance")


## MULT_GAIN relics apply to rewards that go into a stat flagged relics_boost_gain.
func _relic_gain_mult(b: ButtonDef) -> BigNum:
	var rs: StatDef = stat_defs.get(b.reward_stat) as StatDef
	if rs == null or not rs.relics_boost_gain or relics == null:
		return BigNum.one()
	return BigNum.from_float(relics.multiplier(RelicDef.Effect.MULT_GAIN))


func _gain_boost(reward_stat: StringName) -> BigNum:
	var d: StatDef = stat_defs.get(reward_stat) as StatDef
	if d == null:
		return BigNum.one()
	var boost: BigNum = BigNum.one()
	if d.gain_boost_stat != &"":
		boost = get_stat(d.gain_boost_stat).add(BigNum.one())
	return boost.mul(BigNum.from_float(buff_factor_for(reward_stat)))


## The combined multiplier on rewards into `stat_id` from every higher stat that lists it in buff_stats and is held (>= 1).
func buff_factor_for(stat_id: StringName) -> float:
	var f: float = 1.0
	for s: StatDef in stat_defs.values():
		if s.buff_stats.has(String(stat_id)) and get_stat(s.id).gte(BigNum.one()):
			f *= s.buff_factor
	return f


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
	return 1.0 + effect_total(&"pad_yield") + reset_bonus()


## True once the player has rebirthed enough times for this attribute to be bought. Levels bought stay when saves load.
func attr_unlocked(attr_id: StringName) -> bool:
	var a: AttributeDef = attribute_defs.get(attr_id) as AttributeDef
	if a == null or rebirth_count < a.unlock_rebirths:
		return false
	if a.unlock_resets > 0:
		var r: ZoneResetDef = reset_for_currency(a.currency)
		return r != null and reset_count(r.id) >= a.unlock_resets
	return true


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


## `free` presses cost nothing (the Wildflower gift). The pad must still be open.
func _press(button_id: StringName, world_pos: Vector3, allow_pulse: bool, free: bool = false) -> bool:
	var b: ButtonDef = button_defs.get(button_id) as ButtonDef
	if b == null or b.zone != zone_id:
		return false
	if free:
		if is_pad_locked(button_id):
			return false
	elif not can_afford(button_id):
		if allow_pulse:
			button_denied.emit(button_id)
		return false
	if not god_mode and not free:
		_set_stat(b.cost_stat, get_stat(b.cost_stat).sub(Formulas.button_cost(b)).max_zero())
	var chance: float = crit_chance(button_id)
	var crit: bool = chance > 0.0 and rng.randf() < chance
	var crit_mult: float = 1.0
	if crit:
		crit_mult = crit_damage(button_id)
	var presses: int = 1
	var dbl: float = _double_chance()
	if dbl > 0.0 and rng.randf() < dbl:
		presses = 2
	var gain: BigNum = press_gain(button_id, crit_mult, presses)
	_set_stat(b.reward_stat, get_stat(b.reward_stat).add(gain))
	press_count += 1
	_open_next_tier(b)
	run_stats.on_press(crit)
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
			pulse_source = button_id
			var order: int = 0
			for other: ButtonDef in button_defs.values():
				if other.zone == b.zone and other.row == b.row and absi(other.row_index - b.row_index) == 1:
					pulse_order = order
					order += 1
					_press(other.id, world_pos, false)
			pulse_source = &""
			pulse_order = 0
	return true


func _open_next_tier(b: ButtonDef) -> void:
	if not is_row_finisher(b):
		return
	var nxt: TierDef = next_tier(b.row)
	if nxt != null and not bool(tiers_open.get(nxt.id, false)):
		tiers_open[nxt.id] = true
		tier_opened.emit(nxt.id)


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
		run_stats.on_tier(t)
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


## Pad streak: the pads of a row in order (Sprout 1, 2, 3), each within streak_window of the last, pays streak_bonus_seconds of income.
func _update_streak(b: ButtonDef) -> void:
	if b.row_index == 0:
		_streak_row = b.row
		_streak_next = 1
		_streak_at = play_seconds
		return
	if b.row == _streak_row and b.row_index == _streak_next and play_seconds - _streak_at <= config.streak_window:
		_streak_at = play_seconds
		_streak_next += 1
		run_stats.on_chain(_streak_next)
		var last_index: int = 0
		for other: ButtonDef in button_defs.values():
			if other.zone == b.zone and other.row == b.row:
				last_index = maxi(last_index, other.row_index)
		if b.row_index >= last_index:
			_streak_row = &""
			run_stats.on_streak_done()
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


## The pad an automatic press picks: the best open one (highest tier, then furthest along the row). `affordable` limits it
## to pads whose cost is in stock; the Wildflower gift picks among the pads of the highest open tier instead (random).
func auto_pick(affordable: bool) -> StringName:
	var best: ButtonDef = null
	var best_key: int = -1
	var pool: Array[ButtonDef] = []
	for b: ButtonDef in buttons_in_zone(zone_id):
		if is_pad_locked(b.id) or (affordable and not can_afford(b.id)):
			continue
		var t: TierDef = tier_of(b.id)
		var key: int = (t.order if t != null else 0) * 100 + b.row_index
		if affordable:
			if key > best_key:
				best_key = key
				best = b
		else:
			var tier_key: int = (t.order if t != null else 0) * 100
			if tier_key > best_key:
				best_key = tier_key
				pool.clear()
			if tier_key == best_key:
				pool.append(b)
	if affordable:
		return best.id if best != null else &""
	return pool[rng.randi() % pool.size()].id if not pool.is_empty() else &""


## Dew Sprites press the best affordable pad on their own; the Wildflower blooms a pad for free now and then.
func _step_auto(dt: float) -> void:
	if zone_id == &"":
		return
	var sprites: float = effect_total(&"auto_press")
	if sprites > 0.0:
		_auto_acc = minf(_auto_acc + sprites * dt, 3.0)
		while _auto_acc >= 1.0:
			_auto_acc -= 1.0
			var id: StringName = auto_pick(true)
			if id == &"":
				_auto_acc = 0.0
				break
			auto_press_active = true
			_press(id, Vector3.ZERO, false)
			auto_press_active = false
	var wild: float = effect_total(&"wild_bloom")
	if wild > 0.0:
		_wild_acc = minf(_wild_acc + wild * dt, 3.0)
		while _wild_acc >= 1.0:
			_wild_acc -= 1.0
			var wid: StringName = auto_pick(false)
			if wid == &"":
				_wild_acc = 0.0
				break
			auto_press_active = true
			_press(wid, Vector3.ZERO, false, true)
			auto_press_active = false


## Seconds between achievement checks while playing.
const ACHIEVEMENT_EVERY: float = 1.0


## Everything an achievement can count, by name: plain totals, `tier_<id>` and `zone_<id>` flags, and `peak_<stat>`.
func achievement_counters() -> Dictionary:
	var best_rank: int = 0
	var kinds: int = 0
	for id: Variant in relics.owned:
		if relics.stacks_of(id) > 0 and relics.defs.has(id):
			kinds += 1
			best_rank = maxi(best_rank, (relics.defs[id] as RelicDef).rarity.rank + 1)
	var attrs: int = 0
	for lv: Variant in attr_levels.values():
		attrs += int(lv)
	var top_mastery: int = 0
	for bid: Variant in button_defs:
		top_mastery = maxi(top_mastery, mastery.level(bid))
	var c: Dictionary = {
		&"presses": float(press_count), &"crits": float(run_stats.crits), &"streaks_done": float(run_stats.streaks_done),
		&"best_chain": float(run_stats.best_chain), &"best_momentum": float(run_stats.best_tier),
		&"rebirths": float(rebirth_count), &"relic_drops": float(relic_drops), &"relic_kinds": float(kinds),
		&"best_relic_rank": float(best_rank), &"attributes_bought": float(attrs), &"mastery_best": float(top_mastery),
		&"play_hours": play_seconds / 3600.0, &"gates_open": float(gates_open.size()),
	}
	for tid: Variant in tier_defs:
		var zid: StringName = (tier_defs[tid] as TierDef).zone
		var reached: bool = zones_entered.has(zid) or zone_id == zid   # a zone's first tier is open on arrival, not before
		c[&"tier_" + String(tid)] = 1.0 if reached and is_tier_open(tid) else 0.0
	for zid: Variant in zone_defs:
		c[&"zone_" + String(zid)] = 1.0 if zones_entered.has(zid) or zone_id == zid else 0.0
	return achievements.with_peaks(c)


## Unlocks what has been earned and returns the ids unlocked just now. Quiet: no signal.
func _evaluate_achievements() -> Array[StringName]:
	achievements.note_stats(stats)
	return achievements.check(achievement_counters())


## Checks every achievement and announces new unlocks. Runs once a second from step() and after a rebirth.
func check_achievements() -> void:
	for id: StringName in _evaluate_achievements():
		achievement_unlocked.emit(id)


## Advance the simulation by dt seconds of passive income. Presses are separate (try_press).
func step(dt: float) -> void:
	play_seconds += dt
	if run_stats.step(dt, zone_id):
		run_stats.record_income(income_per_second(config.income_stat))
	calendar.advance(dt)
	_ach_clock += dt
	if _ach_clock >= ACHIEVEMENT_EVERY:
		_ach_clock = 0.0
		check_achievements()
	if momentum_hold > 0.0:
		momentum_hold = maxf(0.0, momentum_hold - dt)
	elif momentum > 0.0:
		momentum = maxf(0.0, momentum - config.momentum_decay_per_second * dt)
		_sync_momentum_tier()
	if heat > 0.0:
		var zd: ZoneDef = current_zone()
		_set_heat(heat - (zd.heat_decay_per_second if zd != null else heat) * dt)
	_step_critter(dt)
	_step_auto(dt)
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


## Dev console: open one flower tier, or all of them when `tier_id` is empty.
func dev_open_tiers(tier_id: StringName = &"") -> void:
	for t: TierDef in tier_defs.values():
		if tier_id == &"" or t.id == tier_id:
			tiers_open[t.id] = true
			tier_opened.emit(t.id)


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


## True in the zones where Rebirth, Prestige and Rebirth Points are shown (the meadow runs on Bloom instead).
func rebirth_here() -> bool:
	return String(zone_id) in config.rebirth_zones


## Times a zone reset has been done.
func reset_count(reset_id: StringName) -> int:
	return int(reset_counts.get(reset_id, 0))


## What every reset done adds to every pad's reward (0.05 = +5%).
func reset_bonus() -> float:
	var total: float = 0.0
	for r: ZoneResetDef in reset_defs.values():
		total += float(reset_count(r.id)) * (r.bonus_per_use + (effect_total(r.bonus_effect) if r.bonus_effect != &"" else 0.0))
	return total


## The reset that belongs to a zone (the current zone by default), or null.
func reset_for_zone(z_id: StringName = &"") -> ZoneResetDef:
	var zid: String = String(zone_id if z_id == &"" else z_id)
	var best: ZoneResetDef = null
	for r: ZoneResetDef in reset_defs.values():
		if zid in r.zones and (best == null or r.order < best.order):
			best = r
	return best


## The reset a currency stat is paid by, or null (Prestige and Rebirth Points have none).
func reset_for_currency(currency: StringName) -> ZoneResetDef:
	for r: ZoneResetDef in reset_defs.values():
		if r.currency == currency:
			return r
	return null


## Resets in menu order.
func resets_ordered() -> Array[ZoneResetDef]:
	var out: Array[ZoneResetDef] = []
	for r: ZoneResetDef in reset_defs.values():
		out.append(r)
	out.sort_custom(func(a: ZoneResetDef, b: ZoneResetDef) -> bool: return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return out


## A reset opens with its gate zone's gate.
func reset_unlocked(reset_id: StringName) -> bool:
	var r: ZoneResetDef = reset_defs.get(reset_id) as ZoneResetDef
	return r != null and bool(gates_open.get(r.gate_zone, false))


## The source amount the next payout is measured against: the gate zone's own threshold (so the reset follows the gate),
## shrunk a little by every use already done.
func reset_ref(reset_id: StringName) -> float:
	var r: ZoneResetDef = reset_defs.get(reset_id) as ZoneResetDef
	if r == null:
		return 1.0
	var z: ZoneDef = zone_defs.get(r.gate_zone) as ZoneDef
	var base: float = z.gate_threshold if z != null and z.gate_threshold > 0.0 else r.ref_fallback
	return base * maxf(r.ref_floor, pow(r.ref_shrink_per_use, float(reset_count(reset_id))))


## What a reset would pay now (0 until it is available).
func reset_gain(reset_id: StringName) -> int:
	var r: ZoneResetDef = reset_defs.get(reset_id) as ZoneResetDef
	if r == null or not reset_unlocked(reset_id):
		return 0
	var v: float = maxf(0.0, get_stat(r.source_stat).to_float())
	var n: int = int(floorf(r.pay_scale * sqrt(v / reset_ref(reset_id))))
	if float(n) < r.min_pay:
		return 0
	if r.pay_effect != &"":
		n = int(floorf(float(r.pay_scale * sqrt(v / reset_ref(reset_id))) * (1.0 + effect_total(r.pay_effect))))
	return n


func can_reset(reset_id: StringName) -> bool:
	return reset_gain(reset_id) > 0


## What a stat restarts at after a reset: its start, plus the reset's gift total for its start stat.
func reset_start_value(reset_id: StringName, stat_id: StringName) -> BigNum:
	var r: ZoneResetDef = reset_defs.get(reset_id) as ZoneResetDef
	var d: StatDef = stat_defs.get(stat_id) as StatDef
	var extra: float = effect_total(r.start_effect) if r != null and r.start_stat == stat_id and r.start_effect != &"" else 0.0
	return BigNum.from_float((d.start if d != null else 0.0) + extra)


## Resets the stats the def lists, pays its currency and counts the use. Gates, tiers, relics, mastery and every other
## currency stay.
func try_reset(reset_id: StringName) -> bool:
	if not can_reset(reset_id):
		return false
	var r: ZoneResetDef = reset_defs[reset_id] as ZoneResetDef
	var gained: int = reset_gain(reset_id)
	bloom_before = stats.duplicate()   # what the reset animation counts down from (BloomRitual)
	var keep: int = int(floorf(effect_total(r.keep_effect))) if r.keep_effect != &"" else 0
	for sid: String in r.resets:
		if StringName(sid) != r.start_stat and keep > 0:
			keep -= 1   # a kept flower: the gift saves the lowest ones listed
			continue
		_set_stat(StringName(sid), reset_start_value(reset_id, StringName(sid)))
	_set_stat(r.currency, get_stat(r.currency).add(BigNum.from_float(float(gained))))
	reset_counts[reset_id] = reset_count(reset_id) + 1
	rebirth_count += 1   # every zone reset counts toward the relic slots (5 and 20)
	relics.set_rebirths(rebirth_count)
	_set_heat(0.0)
	_flush()
	run_stats.mark_rebirth()
	reset_done.emit(reset_id, gained)
	return true


## True once any zone reset has been done or could be done now (opens the Upgrades menu).
func resets_started() -> bool:
	for r: ZoneResetDef in reset_defs.values():
		if reset_count(r.id) > 0 or can_reset(r.id):
			return true
	return false


## The stat Rebirth banks in the current zone: the zone's own (Ingots in the quarry) or the game's (Clover Leaves).
func prestige_source() -> StringName:
	var z: ZoneDef = current_zone()
	return z.prestige_source_stat if z != null and z.prestige_source_stat != &"" else config.prestige_source_stat


func can_rebirth() -> bool:
	return get_stat(prestige_source()).gte(BigNum.from_float(config.rebirth_min_value))


func prestige_gain_preview() -> BigNum:
	return _prestige_gain() if can_rebirth() else BigNum.zero()


## The source stat, boosted once it passes prestige_push_threshold so pushing further pays more than linearly.
func _prestige_gain() -> BigNum:
	var v: BigNum = get_stat(prestige_source()).copy()
	var th: float = config.prestige_push_threshold
	var f: float = v.to_float()
	if th > 0.0 and f > th:
		v = v.mul(BigNum.from_float(pow(f / th, config.prestige_push_exponent)))
	var z: ZoneDef = current_zone()
	if z != null and z.prestige_per_rebirth_bonus > 0.0:   # the zone's own rebirth count (reb: quarry rebirths, not reset)
		v = v.mul(BigNum.from_float(1.0 + z.prestige_per_rebirth_bonus * get_stat(&"reb").to_float()))
	return v


## Resets stats flagged resets_on_rebirth and banks the source stat into Prestige.
## Prestige then multiplies passive income (Embers in the quarry). Gates stay open.
func try_rebirth() -> bool:
	if not can_rebirth():
		return false
	var gained: BigNum = _prestige_gain()
	for s: StatDef in stat_defs.values():
		if s.resets_on_rebirth and s.in_zone(zone_id):   # a rebirth only resets the zone it was done in
			_set_stat(s.id, BigNum.from_float(s.start))
	if stat_defs.has(&"reb") and (stat_defs[&"reb"] as StatDef).in_zone(zone_id):
		_set_stat(&"reb", get_stat(&"reb").add(BigNum.one()))   # the quarry counts its rebirths (Rebirths stat)
	_set_stat(config.prestige_stat, get_stat(config.prestige_stat).add(gained))
	_set_stat(config.rp_stat, get_stat(config.rp_stat).add(BigNum.from_float(float(rp_for_rebirth(rebirth_count)))))
	rebirth_count += 1
	relics.set_rebirths(rebirth_count)
	_set_heat(0.0)
	_flush()
	run_stats.mark_rebirth()
	rebirth_done.emit(gained)
	check_achievements()
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
	if reset_for_currency(a.currency) != null:
		return get_stat(a.currency)
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
	elif reset_for_currency(a.currency) != null:
		_set_stat(a.currency, get_stat(a.currency).sub(cost).max_zero())
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
	_pay_entry_grants(z_id)
	zone_entered.emit(z_id)
	return true


## First arrival in a zone: pay its entry_grants from the stock of its entry_source_stat (see ZoneDef).
func _pay_entry_grants(z_id: StringName) -> void:
	var z: ZoneDef = zone_defs.get(z_id) as ZoneDef
	if z == null or bool(zones_entered.get(z_id, false)):
		return
	zones_entered[z_id] = true
	if z.entry_grants.is_empty():
		return
	var src: BigNum = get_stat(z.entry_source_stat) if z.entry_source_stat != &"" else BigNum.one()   # no source = a flat purse
	for sid: Variant in z.entry_grants:
		var id: StringName = StringName(str(sid))
		if stat_defs.has(id):
			_set_stat(id, get_stat(id).add(src.mul(BigNum.from_float(float(z.entry_grants[sid])))))
	_flush()


func is_gate_open(z_id: StringName) -> bool:
	return bool(gates_open.get(z_id, false))


## What the last apply_offline gave beyond stat income: {"relics": Array[StringName], "tend": {tier id: {"presses", "levels", "level"}}}.
var last_offline: Dictionary = {}


## Credits time away, capped by offline_cap_seconds(): passive income, flower tending (reduced-rate presses that also
## earn mastery XP), and reduced-rate relic drop rolls. Returns seconds credited.
func apply_offline(seconds: float) -> float:
	var secs: float = clampf(seconds, 0.0, offline_cap_seconds())
	last_offline = {}
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
	last_offline["tend"] = _offline_tend(secs, gains)
	last_offline["relics"] = _offline_relics(secs)
	_check_gates()
	_flush()
	offline_gained.emit(secs, gains)
	return secs


## Each open tier of the zone (lowest first, so its yield can feed the next) presses its top unlocked pad at a fraction
## of the press rate, as many times as the stock allows. Adds rewards to `gains` and returns per-tier results.
func _offline_tend(secs: float, gains: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if config.offline_tend_fraction <= 0.0:
		return out
	var target: float = floorf(secs * config.offline_tend_fraction / press_interval())
	if target < 1.0:
		return out
	for t: TierDef in tiers_in_zone(zone_id):
		if not is_tier_open(t.id):
			continue
		var pad: ButtonDef = null
		for b: ButtonDef in buttons_in_zone(zone_id):
			if b.row == t.id and not is_pad_locked(b.id) and (pad == null or b.row_index > pad.row_index):
				pad = b
		if pad == null:
			continue
		var cost: BigNum = Formulas.button_cost(pad)
		var afford: float = floorf(get_stat(pad.cost_stat).div(cost).to_float()) if not cost.is_zero() else target
		var n: float = minf(target, afford)
		if n < 1.0:
			continue
		var nb: BigNum = BigNum.from_float(n)
		var reward: BigNum = press_gain_preview(pad.id).mul(nb)
		_set_stat(pad.cost_stat, get_stat(pad.cost_stat).sub(cost.mul(nb)).max_zero())
		_set_stat(pad.reward_stat, get_stat(pad.reward_stat).add(reward))
		gains[pad.reward_stat] = (gains[pad.reward_stat] as BigNum).add(reward) if gains.has(pad.reward_stat) else reward
		press_count += int(n)
		var levels: int = mastery.add_xp(pad.id, mastery.config.xp_per_press * n * (1.0 + effect_total(&"mastery_xp")))
		out[t.id] = {"presses": int(n), "levels": levels, "level": mastery.level(pad.id)}
	return out


## Drop rolls for the time away, at offline_relic_roll_fraction of the awake rate, with the pity timer running on that
## slower clock. Returns the relic ids found (at most offline_relic_max_drops).
func _offline_relics(secs: float) -> Array[StringName]:
	var found: Array[StringName] = []
	var rc: RelicConfig = relics.config
	if config.offline_relic_roll_fraction <= 0.0 or config.offline_relic_max_drops <= 0 or rc.roll_interval <= 0.0:
		return found
	var step_s: float = rc.roll_interval / config.offline_relic_roll_fraction
	var now: float = play_seconds
	var last_drop: float = _last_drop_at
	var t: float = step_s
	while t <= secs and found.size() < config.offline_relic_max_drops:
		var due: float = rc.first_drop_seconds if relic_drops == 0 else rc.pity_seconds
		var drop: StringName = relics.roll_drop(rng, luck_level(), now + t - last_drop >= due)
		if drop != &"":
			relics.add_relic(drop)
			relic_drops += 1
			last_drop = now + t
			found.append(drop)
		t += step_s
	if not found.is_empty():
		_last_drop_at = play_seconds
	return found


func _set_stat(stat_id: StringName, value: BigNum) -> void:
	stats[stat_id] = value
	_dirty[stat_id] = true
	achievements.note_stat(stat_id, value)


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

## Save format of the flower ladder (the meadow's Sunlight to Starbloom economy). Older saves are migrated on load.
const LADDER_SAVE: int = 4   # 3: the quarry's Cash and Multiplier became Embers and Cinder; 4: Rebirth became the Nucleus

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
		"tiers": tiers_open.keys().map(func(k: Variant) -> String: return String(k)),
		"zones_entered": zones_entered.keys().map(func(k: Variant) -> String: return String(k)),
		"ladder": LADDER_SAVE,
		"attributes": a,
		"play_seconds": play_seconds,
		"press_count": press_count,
		"rebirth_count": rebirth_count,
		"reset_counts": reset_counts.duplicate(),
		"relic_drops": relic_drops,
		"last_drop_at": _last_drop_at,
		"ui_flags": ui_flags.duplicate(true),
		"hud_layout": hud_layout.to_dict(),
		"relics": relics.to_dict(),
		"mastery": mastery.to_dict(),
		"calendar": calendar.to_dict(),
		"run_stats": run_stats.to_dict(),
		"achievements": achievements.to_dict(),
	}


## Loads a dict from to_dict(). Unknown ids are ignored, missing ones keep defaults. Never throws.
func from_dict(d_in: Dictionary) -> bool:
	new_game()
	if d_in.is_empty():
		return false
	var d: Dictionary = d_in
	var save_ladder: int = int(d.get("ladder", 0))
	var old_ladder: bool = save_ladder < 1
	var old_quarry: bool = save_ladder < 2   # before the Ember Quarry ladder (Cinder to Emberheart)
	if old_ladder or old_quarry:
		d = _ladder_save_ids(d)
	if save_ladder < 3:
		d = _rename_quarry_stats(d)
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
	var tl: Variant = d.get("tiers", [])
	if tl is Array:
		for k: Variant in (tl as Array):
			if tier_defs.has(StringName(str(k))):
				tiers_open[StringName(str(k))] = true
	var ze: Variant = d.get("zones_entered", [])
	if ze is Array:
		for k: Variant in (ze as Array):
			if zone_defs.has(StringName(str(k))):
				zones_entered[StringName(str(k))] = true
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
	var rc: Variant = d.get("reset_counts", {})
	if rc is Dictionary:
		for k: Variant in (rc as Dictionary):
			if reset_defs.has(StringName(str(k))):
				reset_counts[StringName(str(k))] = maxi(0, int((rc as Dictionary)[k]))
	if int(d.get("bloom_count", 0)) > 0 and reset_defs.has(&"bloom") and reset_count(&"bloom") == 0:   # saves from 0.31 kept the count on its own
		reset_counts[&"bloom"] = int(d.get("bloom_count", 0))
	relic_drops = int(d.get("relic_drops", 0))
	_last_drop_at = float(d.get("last_drop_at", play_seconds))
	var uf: Variant = d.get("ui_flags", {})
	if uf is Dictionary:
		ui_flags = (uf as Dictionary).duplicate(true)
	hud_layout.from_dict(d.get("hud_layout"), stat_defs.keys())   # saves from before the strip was editable have none: Default
	var rd: Variant = d.get("relics", {})
	if rd is Dictionary:
		relics.from_dict(rd)
	relics.set_rebirths(rebirth_count)
	mastery.from_dict(d.get("mastery", {}), button_defs)
	calendar.from_dict(d.get("calendar", {}))
	var rs: Variant = d.get("run_stats", {})
	if rs is Dictionary:
		run_stats.from_dict(rs)
	if old_ladder:
		_migrate_to_ladder(d_in)
	if d.has("achievements"):
		achievements.from_dict(d["achievements"])
	else:
		_evaluate_achievements()   # a save from before the Ledger: what is already earned counts, with no pop-ups
	if old_quarry:
		_migrate_to_quarry_ladder()
	if save_ladder < 4:
		_migrate_quarry_rebirth()
	_dirty.clear()
	return true


# ---------------------------------------------------------------- flower ladder migration

## Old pad id (Multiplier and Rebirth pads, before the flower ladder) -> the pad that took its place. Used for mastery.
const LADDER_PAD_MAP: Dictionary = {
	"m1": "sprout_1", "m2": "sprout_2", "m3": "sprout_3", "r1": "clover_1", "r2": "clover_2",
	"g1": "thistle_1", "g2": "thistle_2", "o1": "thistle_3", "h1": "heather_1", "c1": "heather_2", "h2": "heather_3",
	"t1": "foxglove_1", "l1": "foxglove_2", "t2": "foxglove_3", "e1": "starbloom_1",
}


## The three Forge pads of the old quarry became the Slag row of the new ladder (they paid Slag).
const QUARRY_PAD_MAP: Dictionary = {"f1": "slagrow_1", "f2": "slagrow_2", "f3": "slagrow_3"}


func old_pre_ladder(d: Dictionary) -> bool:
	return int(d.get("ladder", 0)) < 1


## A save from before the quarry ladder. A player who already was in the quarry (or had Slag, Forge mastery or an open
## quarry gate) gets the rows they already played opened, so nothing locks behind a tier they got past. Their Embers,
## Cinder, Rebirths and Slag are kept as they are; the new stats start at zero.
func _migrate_to_quarry_ladder() -> void:
	var played: bool = zone_id == &"zone2" or bool(zones_entered.get(&"zone2", false)) or not get_stat(&"slag").is_zero()
	for b: ButtonDef in button_defs.values():
		if b.zone == &"zone2" and mastery.xp(b.id) > 0.0:
			played = true
	if not played:
		return
	for id: StringName in [&"cinder", &"ore", &"slagrow"]:
		if tier_defs.has(id):
			tiers_open[id] = true
	if gates_open.get(&"zone2", false):   # the old gate (9 Slag) was beaten: keep every row open for the new one
		for t: TierDef in tiers_in_zone(&"zone2"):
			tiers_open[t.id] = true


## Saves from before the Nucleus: the quarry's old Rebirth, Prestige, Rebirth Points and the Prestige-bought upgrades are
## retired. Every old Rebirth counts as a Nucleus (so the pad bonus carries on, up to nucleus_carry_max), pays 2 Core Shards,
## and every level bought in the old upgrades pays 1 Core Shard back. The old levels, Prestige and Rebirth Points are cleared;
## the relic slots (rebirth_count) stay. Core Shards then buy the new Nucleus gifts.
func _migrate_quarry_rebirth() -> void:
	var r: ZoneResetDef = reset_defs.get(&"nucleus") as ZoneResetDef
	if r == null or not (bool(zones_entered.get(&"zone2", false)) or zone_id == &"zone2"):   # only players who have been to the quarry
		return
	var refund: int = 0
	for a: AttributeDef in attribute_defs.values():
		if a.currency == config.prestige_stat or a.currency == config.rp_stat:
			refund += attr_level(a.id)
			attr_levels.erase(a.id)
	var done: int = rebirth_count
	if done <= 0 and refund <= 0 and get_stat(config.prestige_stat).is_zero():
		return
	reset_counts[r.id] = maxi(reset_count(r.id), mini(done, config.nucleus_carry_max))
	_set_stat(r.currency, get_stat(r.currency).add(BigNum.from_float(float(refund + 2 * done))))
	_set_stat(config.prestige_stat, BigNum.zero())
	_set_stat(config.rp_stat, BigNum.zero())
	prestige_spent = BigNum.zero()


## Saves from before Cash and Multiplier left the quarry (ladder < 3): the Cash stock becomes Embers and the Multiplier
## stock becomes Cinder, one for one, so a quarry run carries on exactly as it was. (The old stats are parked in
## content/parked/.) A copy of the save; the stats of every older zone are rewritten by _migrate_to_ladder afterwards.
func _rename_quarry_stats(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var st: Variant = out.get("stats")
	if st is Dictionary:
		for pair: Array in [["cash", "embers"], ["mult", "cinder"]]:
			if (st as Dictionary).has(pair[0]):
				(st as Dictionary)[pair[1]] = (st as Dictionary)[pair[0]]
				(st as Dictionary).erase(pair[0])
	return out


## A copy of a pre-ladder save with its mastery keys renamed to the new pad ids.
func _ladder_save_ids(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var m: Variant = out.get("mastery")
	if m is Dictionary:
		var renamed: Dictionary = {}
		for k: Variant in (m as Dictionary):
			var nk: String = str(k)
			if old_pre_ladder(d):
				nk = LADDER_PAD_MAP.get(nk, nk)
			renamed[QUARRY_PAD_MAP.get(nk, nk)] = (m as Dictionary)[k]
		out["mastery"] = renamed
	var uf: Variant = out.get("ui_flags")
	if uf is Dictionary:   # tutorial steps were renamed with the rows they reveal
		var renames: Dictionary = {"mult": "dewdrop", "rebirth_row": "clover_row"}
		for bag: String in ["unlocked", "seen"]:
			var b: Variant = (uf as Dictionary).get(bag)
			if b is Dictionary:
				for old_id: String in renames:
					if (b as Dictionary).has(old_id):
						(b as Dictionary)[renames[old_id]] = (b as Dictionary)[old_id]
						(b as Dictionary).erase(old_id)
	return out


## A save from before the flower ladder. Cash, Multiplier and Rebirths then only lived in the Ember Quarry, so a player who
## has left the meadow gets their progress as the matching flower stock instead: the old Multiplier becomes Thistle Down
## (it was the income multiplier Larkmoor ran on) and the old Rebirths become Heather Sprigs. Tiers and arrivals the
## player already got past are opened and latched, so nothing locks behind them.
func _migrate_to_ladder(old: Dictionary) -> void:
	var os: Variant = old.get("stats", {})
	var old_cash: BigNum = BigNum.zero()
	var old_mult: BigNum = BigNum.zero()
	var old_reb: BigNum = BigNum.zero()
	if os is Dictionary:
		old_cash = BigNum.from_variant((os as Dictionary).get("cash"), BigNum.zero()).max_zero()
		old_mult = BigNum.from_variant((os as Dictionary).get("mult"), BigNum.zero()).max_zero()
		old_reb = BigNum.from_variant((os as Dictionary).get("reb"), BigNum.zero()).max_zero()
	var first: StringName = _first_zone()
	var z: ZoneDef = zone_defs.get(zone_id) as ZoneDef
	zones_entered[first] = true
	zones_entered[zone_id] = true
	for zd: ZoneDef in zone_defs.values():
		if gates_open.get(zd.id, false) and zd.next_zone != &"":
			zones_entered[zd.next_zone] = true
			for t: TierDef in tiers_in_zone(zd.id):   # a zone whose gate is open was finished: all its tiers are open
				tiers_open[t.id] = true
	if zone_id == &"zone2" or zone_id == &"":
		for t: TierDef in tier_defs.values():
			tiers_open[t.id] = true
		return   # still in the quarry: Embers, Cinder and Rebirths carry on as they were
	_set_stat(&"sunlight", old_cash)
	if z != null and z.order > zone_defs[first].order:
		_set_stat(&"dewdrop", BigNum.from_float(64.0))
		_set_stat(&"clover", BigNum.from_float(9.0))
		_set_stat(&"thistle", old_mult)
		_set_stat(&"heather", old_reb)
		tiers_open[&"heather"] = true
	else:
		_set_stat(&"dewdrop", old_mult)
		_set_stat(&"clover", old_reb)
	for id: StringName in [&"embers", &"cinder", &"reb"]:   # the quarry's own stock starts fresh
		_set_stat(id, BigNum.from_float((stat_defs[id] as StatDef).start) if id == &"embers" else BigNum.zero())
	for t: TierDef in tier_defs.values():   # any pad the player had practised opens its own tier and the one under it
		for b: ButtonDef in button_defs.values():
			if b.row == t.id and mastery.xp(b.id) > 0.0:
				tiers_open[t.id] = true
