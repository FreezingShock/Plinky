extends SceneTree
## Plays the onboarding meadow, then Larkmoor, with a greedy strategy and prints when each Larkmoor pad is first
## bought and when its far gate opens. Provisional balance check, not a tuning tool.
## Run: godot --headless --path . --script tools/sim_larkmoor.gd [-- rebirth_every_minutes]

const DT: float = 0.25
const MAX_SECONDS: float = 12.0 * 3600.0


func _play(sim: Sim, zone: StringName, until_gate: bool, t0: float, rebirth_every: float, log: Dictionary) -> float:
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(zone)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		return Formulas.button_cost(a).to_float() > Formulas.button_cost(b).to_float())
	var t: float = t0
	var next_press: float = t
	var last_rebirth: float = t
	while t < MAX_SECONDS and not (until_gate and sim.is_gate_open(zone)):
		sim.step(DT)
		t += DT
		if t >= next_press:
			next_press += sim.press_interval()
			for b: ButtonDef in buttons:
				if sim.try_press(b.id):
					if not log.has(b.id):
						log[b.id] = t
					break
		if rebirth_every > 0.0 and zone != &"zone1" and t - last_rebirth > rebirth_every and sim.can_rebirth():
			sim.try_rebirth()
			last_rebirth = t
			log["rebirths"] = int(log.get("rebirths", 0)) + 1
	return t


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var every: float = (float(args[0]) * 60.0) if args.size() > 0 else 0.0
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		quit(1)
		return
	sim.new_game()
	var log: Dictionary = {}
	var t: float = _play(sim, &"zone1", true, 0.0, 0.0, log)
	print("zone1 gate at %.1f min; mult %s reb %s cash %s" % [t / 60.0, sim.get_stat(&"mult").to_float(), sim.get_stat(&"reb").to_float(), sim.get_stat(&"cash").to_float()])
	sim.enter_zone(&"larkmoor")
	var t2: float = t
	var log2: Dictionary = {}
	t2 = _play(sim, &"larkmoor", true, t, every, log2)
	for id: Variant in log2:
		if id is StringName:
			print("%s first bought at +%.1f min" % [id, (float(log2[id]) - t) / 60.0])
	print("larkmoor gate %s at +%.1f min (rebirths %d)" % ["open" if sim.is_gate_open(&"larkmoor") else "NOT reached", (t2 - t) / 60.0, int(log2.get("rebirths", 0))])
	quit(0)
