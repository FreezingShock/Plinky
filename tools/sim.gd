extends SceneTree
## Plays the whole meadow ladder with a greedy strategy and prints the minutes to each pad, each tier and each gate:
## the onboarding meadow (Sprout, Clover) to its gate, then Larkmoor (Thistle, Heather, Foxglove, Starbloom) to the far gate.
## Strategy: at every press, buy the highest-row pad you can afford (top tier first, then the biggest pad of the tier). No
## walking time, no attributes, no relics: a floor for the pacing, not a prediction. Mastery is the real sim's.
## Run: godot --headless --path . --script tools/sim.gd [-- rebirth_every_minutes]
## Prints "NOT reached" for a gate the strategy could not open in MAX_SECONDS, which CI treats as a failure.

const DT: float = 0.25
const MAX_SECONDS: float = 8.0 * 3600.0


func _order(sim: Sim, zone: StringName) -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(zone)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		var ta: TierDef = sim.tier_of(a.id)
		var tb: TierDef = sim.tier_of(b.id)
		var oa: int = ta.order if ta != null else 0
		var ob: int = tb.order if tb != null else 0
		return oa > ob if oa != ob else a.row_index > b.row_index)
	return buttons


## Plays `zone` until its gate opens (or time runs out). Returns the clock at the end.
func _play(sim: Sim, zone: StringName, t0: float, log: Dictionary, tier_log: Dictionary, every: float) -> float:
	var buttons: Array[ButtonDef] = _order(sim, zone)
	sim.tier_opened.connect(func(id: StringName) -> void: tier_log[id] = tier_log.get(id, t_now))
	var t: float = t0
	var next_press: float = t
	var last_rebirth: float = t
	while t < MAX_SECONDS and not sim.is_gate_open(zone):
		sim.step(DT)
		t += DT
		t_now = t
		if t >= next_press:
			next_press += sim.press_interval()
			for b: ButtonDef in buttons:
				if sim.try_press(b.id):
					if not log.has(b.id):
						log[b.id] = t
					break
		if every > 0.0 and zone != &"zone1" and t - last_rebirth > every and sim.can_rebirth():
			sim.try_rebirth()
			last_rebirth = t
			log["rebirths"] = int(log.get("rebirths", 0)) + 1
	return t


var t_now: float = 0.0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var every: float = (float(args[0]) * 60.0) if args.size() > 0 else 0.0
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
		return
	sim.new_game()
	sim.rng.seed = 7   # fixed, so the run is repeatable; relic drops still swing the real time by a few minutes
	var failed: bool = false
	var t: float = 0.0
	var zone: StringName = sim.zone_id
	var clock0: float = 0.0
	while zone != &"" and not failed:
		var log: Dictionary = {}
		var tiers: Dictionary = {}
		var z: ZoneDef = sim.zone_defs[zone] as ZoneDef
		print("-- %s (arrived at %.1f min)" % [z.display_name, t / 60.0])
		var t_end: float = _play(sim, zone, t, log, tiers, every)
		for tier: TierDef in sim.tiers_in_zone(zone):
			if tiers.has(tier.id):
				print("%s tier opens at %.1f min" % [tier.display_name, float(tiers[tier.id]) / 60.0])
		for b: ButtonDef in sim.buttons_in_zone(zone):
			if log.has(b.id):
				print("%s first bought at %.1f min" % [b.id, float(log[b.id]) / 60.0])
		var open: bool = sim.is_gate_open(zone)
		print("gate %s %s at %.1f min (%s %s)" % [zone, "open" if open else "NOT reached", t_end / 60.0, (sim.stat_defs[z.gate_stat] as StatDef).display_name, sim.get_stat(z.gate_stat).format()])
		failed = not open
		t = t_end
		var next: StringName = z.next_zone
		if open and next != &"" and next != &"zone2":   # the quarry has its own sim (docs/zone2.md)
			sim.enter_zone(next)
			zone = next
		else:
			zone = &""
	var area: Dictionary = sim.area_mastery(&"larkmoor")
	print("larkmoor mastery: %d of %d levels (%.1f%%)" % [area["level_sum"], area["level_cap"], float(area["fraction"]) * 100.0])
	quit(1 if failed else 0)
