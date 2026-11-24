extends Node
## Autoload. Owns the Sim, drives the fixed tick, and forwards every Sim signal to EventBus.
## World and UI code call the API below; they never touch Sim internals except through `sim` reads.

var sim: Sim
var relics: RelicInventory  # same object as sim.relics, for UI binding
var onboarding: Onboarding  # which systems are visible yet, and the next tip
var paused: bool = false
var _tick: Tick = Tick.new()
var _onboard_clock: float = 1.0


func _ready() -> void:
	sim = Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("GameState: content failed to load")
	sim.new_game()
	relics = sim.relics
	onboarding = Onboarding.new(sim, Onboarding.load_config())
	onboarding.completed.connect(func() -> void: get_node("/root/EventBus").onboarding_complete.emit())
	var bus: Node = get_node("/root/EventBus")
	sim.stat_changed.connect(func(id: StringName, v: BigNum) -> void: bus.stat_changed.emit(id, v))
	sim.button_pressed.connect(func(id: StringName, p: Vector3, g: BigNum, c: bool) -> void: bus.button_pressed.emit(id, p, g, c))
	sim.button_denied.connect(func(id: StringName) -> void: bus.button_denied.emit(id))
	sim.mastery_changed.connect(func(id: StringName, lv: int, xp: float) -> void: bus.mastery_changed.emit(id, lv, xp))
	sim.mastery_leveled.connect(func(id: StringName, lv: int) -> void: bus.mastery_leveled.emit(id, lv))
	sim.zone_entered.connect(func(id: StringName) -> void: bus.zone_entered.emit(id))
	sim.gate_opened.connect(func(id: StringName) -> void: bus.gate_opened.emit(id))
	sim.rebirth_done.connect(func(p: BigNum) -> void: bus.rebirth_done.emit(p))
	sim.reset_done.connect(func(id: StringName, n: int) -> void: bus.reset_done.emit(id, n))
	sim.attribute_bought.connect(func(id: StringName, lv: int) -> void: bus.attribute_bought.emit(id, lv))
	relics.relic_gained.connect(func(id: StringName, n: int) -> void: bus.relic_gained.emit(id, n))
	relics.relic_equipped.connect(func(id: StringName) -> void: bus.relic_equipped.emit(id))
	relics.relic_unequipped.connect(func(id: StringName) -> void: bus.relic_unequipped.emit(id))
	sim.bonus_gained.connect(func(k: StringName, g: Dictionary) -> void: bus.bonus_gained.emit(k, g))
	sim.critter_spawned.connect(func() -> void: bus.critter_spawned.emit())
	sim.heat_hot_changed.connect(func(h: bool) -> void: bus.heat_hot_changed.emit(h))
	sim.momentum_tier_changed.connect(func(t: int, up: bool) -> void: bus.momentum_tier_changed.emit(t, up))
	sim.critter_gone.connect(func() -> void: bus.critter_gone.emit())
	sim.calendar.day_changed.connect(func(d: int) -> void: bus.day_changed.emit(d))
	sim.calendar.month_changed.connect(func(m: int) -> void: bus.month_changed.emit(m))
	sim.calendar.season_changed.connect(func(s: int) -> void: bus.season_changed.emit(s))
	sim.calendar.year_changed.connect(func(y: int) -> void: bus.year_changed.emit(y))
	sim.achievement_unlocked.connect(func(id: StringName) -> void: bus.achievement_unlocked.emit(id))
	sim.offline_gained.connect(func(s: float, g: Dictionary) -> void: bus.offline_gained.emit(s, g))


func _process(delta: float) -> void:
	if paused:
		return
	var n: int = _tick.advance(delta, sim.config.tick_rate, sim.config.max_ticks_per_frame)
	var dt: float = 1.0 / float(sim.config.tick_rate)
	for i in n:
		sim.step(dt)
	_onboard_clock += delta
	if _onboard_clock >= 0.2:
		_onboard_clock = 0.0
		onboarding.update()


# --- API (SPEC section 5 contract) ---
func get_stat(stat_id: StringName) -> BigNum:
	return sim.get_stat(stat_id)


func can_afford(button_id: StringName) -> bool:
	return sim.can_afford(button_id)


func try_press(button_id: StringName, world_pos: Vector3 = Vector3.ZERO) -> bool:
	return sim.try_press(button_id, world_pos)


func income_per_second(stat_id: StringName) -> BigNum:
	return sim.income_per_second(stat_id)


func try_rebirth() -> bool:
	return sim.try_rebirth()


func try_reset(reset_id: StringName) -> bool:
	return sim.try_reset(reset_id)


func buy_attribute(attribute_id: StringName) -> bool:
	return sim.buy_attribute(attribute_id)


## Opens one sealed cache (see SealedPulls). Returns the relic it granted, or &"" when nothing was bought.
func try_sealed_pull(cache_id: StringName) -> StringName:
	return sim.try_sealed_pull(cache_id)


func enter_zone(zone_id: StringName) -> bool:
	return sim.enter_zone(zone_id)
