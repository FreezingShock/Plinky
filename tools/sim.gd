extends SceneTree
## Plays zone 1 with the greedy strategy from docs/balance-sim.py and prints minutes to each button and the gate.
## Run: godot --headless --path . --script tools/sim.gd

const DT: float = 0.1
const MAX_SECONDS: float = 6.0 * 3600.0


func _init() -> void:
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
		return
	sim.new_game()
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(sim.zone_id)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		return Formulas.button_cost(a).to_float() > Formulas.button_cost(b).to_float())
	var first: Dictionary = {}
	var t: float = 0.0
	var next_press: float = 0.0
	var gate: StringName = sim.zone_id
	while not sim.is_gate_open(gate) and t < MAX_SECONDS:
		sim.step(DT)
		t += DT
		if t >= next_press:
			next_press += sim.press_interval()
			for b: ButtonDef in buttons:
				if sim.try_press(b.id):
					if not first.has(b.id):
						first[b.id] = t
					break
	for id: StringName in first:
		print("%s first bought at %.1f min" % [id, first[id] / 60.0])
	print("gate %s %s at %.1f min" % [gate, "open" if sim.is_gate_open(gate) else "NOT reached", t / 60.0])
	quit(0)
