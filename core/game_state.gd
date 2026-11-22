extends Node
## Autoload. Owns the Sim, drives the fixed tick, and forwards every Sim signal to EventBus.
## World and UI code call the API below; they never touch Sim internals except through `sim` reads.

var sim: Sim
var paused: bool = false
var _tick: Tick = Tick.new()


func _ready() -> void:
	sim = Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("GameState: content failed to load")
	sim.new_game()
	var bus: Node = get_node("/root/EventBus")
	sim.stat_changed.connect(func(id: StringName, v: BigNum) -> void: bus.stat_changed.emit(id, v))
	sim.button_pressed.connect(func(id: StringName, p: Vector3, g: BigNum, c: bool) -> void: bus.button_pressed.emit(id, p, g, c))
	sim.button_denied.connect(func(id: StringName) -> void: bus.button_denied.emit(id))
	sim.zone_entered.connect(func(id: StringName) -> void: bus.zone_entered.emit(id))
	sim.gate_opened.connect(func(id: StringName) -> void: bus.gate_opened.emit(id))
	sim.rebirth_done.connect(func(p: BigNum) -> void: bus.rebirth_done.emit(p))
	sim.attribute_bought.connect(func(id: StringName, lv: int) -> void: bus.attribute_bought.emit(id, lv))
	sim.offline_gained.connect(func(s: float, g: Dictionary) -> void: bus.offline_gained.emit(s, g))


func _process(delta: float) -> void:
	if paused:
		return
	var n: int = _tick.advance(delta, sim.config.tick_rate, sim.config.max_ticks_per_frame)
	var dt: float = 1.0 / float(sim.config.tick_rate)
	for i in n:
		sim.step(dt)


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


func buy_attribute(attribute_id: StringName) -> bool:
	return sim.buy_attribute(attribute_id)


func enter_zone(zone_id: StringName) -> bool:
	return sim.enter_zone(zone_id)
