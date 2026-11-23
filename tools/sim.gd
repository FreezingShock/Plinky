extends SceneTree
## Balance sim for the meadow ladder. Plays Meadow then Larkmoor with a greedy strategy under each play profile
## (content/config/sim_profiles.tres), over several seeded runs, and prints the median minutes to each tier and gate.
## Strategy: at every press, buy the highest-row pad you can afford (top tier first). No walking, attributes or relics:
## a floor for the pacing, not a prediction. Mastery and crits still run, so seeds matter.
## Run: godot --headless --path . --script tools/sim.gd [-- rebirth_every_minutes]
## Prints "NOT reached" for a gate the strategy could not open in MAX_SECONDS, which CI treats as a failure.

const DT: float = 0.25
const MAX_SECONDS: float = 8.0 * 3600.0
const PROFILES_PATH: String = "res://content/config/sim_profiles.tres"

var t_now: float = 0.0


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
func _play(sim: Sim, zone: StringName, t0: float, log: Dictionary, tier_log: Dictionary, every: float, interval: float) -> float:
	var buttons: Array[ButtonDef] = _order(sim, zone)
	var on_open: Callable = func(id: StringName) -> void: tier_log[id] = t_now
	sim.tier_opened.connect(on_open)
	var t: float = t0
	var next_press: float = t
	var last_rebirth: float = t
	while t < MAX_SECONDS and not sim.is_gate_open(zone):
		sim.step(DT)
		t += DT
		t_now = t
		if t >= next_press:
			next_press += interval
			for b: ButtonDef in buttons:
				if sim.try_press(b.id):
					if not log.has(b.id):
						log[b.id] = t
					break
		if every > 0.0 and zone != &"zone1" and t - last_rebirth > every and sim.can_rebirth():
			sim.try_rebirth()
			last_rebirth = t
			log["rebirths"] = int(log.get("rebirths", 0)) + 1
	sim.tier_opened.disconnect(on_open)
	return t


## One seeded run of one profile. Returns {gates: {zone: minutes or -1}, tiers: {tier: minutes}, pads: {pad: minutes}}.
func _run(presses_per_second: float, seed_value: int, every: float) -> Dictionary:
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
	sim.events = SeasonalEvents.new()   # the balance floor must not depend on which season the run starts in
	sim.rng.seed = seed_value
	sim.new_game()
	var out: Dictionary = {"gates": {}, "tiers": {}, "pads": {}, "carry": {}}
	var interval: float = 1.0 / maxf(presses_per_second, 0.001)
	var t: float = 0.0
	var zone: StringName = sim.zone_id
	while zone != &"":
		var log: Dictionary = {}
		var tiers: Dictionary = {}
		var z: ZoneDef = sim.zone_defs[zone] as ZoneDef
		var t_end: float = _play(sim, zone, t, log, tiers, every, interval)
		for id: StringName in tiers:
			out["tiers"][id] = float(tiers[id]) / 60.0
		for id: StringName in log:
			out["pads"][id] = float(log[id]) / 60.0
		var open: bool = sim.is_gate_open(zone)
		out["gates"][zone] = t_end / 60.0 if open else -1.0
		out["carry"][zone] = sim.get_stat(&"sunlight").format()
		t = t_end
		var next: StringName = z.next_zone
		if open and next != &"":
			sim.enter_zone(next)
			zone = next
		else:
			zone = &""
	return out


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return values[values.size() / 2]


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var every: float = (float(args[0]) * 60.0) if args.size() > 0 else 0.0
	var profiles: SimProfiles = load(PROFILES_PATH) as SimProfiles
	if profiles == null:
		push_error("missing " + PROFILES_PATH)
		quit(1)
		return
	var failed: bool = false
	var table: Array[String] = []
	var keys: Array[StringName] = [&"clover_1", &"clover_2", &"clover_3", &"thistle_1", &"thistle_2", &"thistle_3", &"heather_1", &"heather_2", &"heather_3", &"foxglove_1", &"foxglove_2", &"foxglove_3", &"starbloom_1", &"starbloom_2", &"starbloom_3"]
	for i: int in profiles.profile_names.size():
		var name: String = profiles.profile_names[i]
		var pps: float = profiles.presses_per_second[i]
		var gates: Dictionary = {&"zone1": [], &"larkmoor": []}
		var tiers: Dictionary = {}
		var pads: Dictionary = {}
		var carry: String = ""
		for s: int in profiles.seeds:
			var r: Dictionary = _run(pps, s + 1, every)
			if s == 0:
				carry = str(r["carry"].get(&"zone1", ""))
			for z: StringName in gates:
				var g: float = r["gates"].get(z, -1.0)
				if g < 0.0:
					failed = true
				gates[z].append(g)
			for id: StringName in r["tiers"]:
				if not tiers.has(id):
					tiers[id] = []
				tiers[id].append(r["tiers"][id])
			for id: StringName in r["pads"]:
				if not pads.has(id):
					pads[id] = []
				pads[id].append(r["pads"][id])
		print("== %s (%.2f presses/s, %d seeds)" % [name, pps, profiles.seeds])
		for z: StringName in gates:
			var vals: Array = gates[z]
			var label: String = "meadow gate" if z == &"zone1" else "larkmoor gate"
			print("   %s: median %.1f min (range %.1f to %.1f)%s" % [label, _median(vals.duplicate()), vals.min(), vals.max(), "  NOT reached" if vals.has(-1.0) else ""])
		print("   Sunlight carried into Larkmoor (seed 1): %s" % carry)
		for id: StringName in tiers:
			print("   tier %s opens: median %.1f min" % [id, _median(tiers[id].duplicate())])
		for id: StringName in keys:
			if pads.has(id):
				print("   %s first bought: median %.1f min" % [id, _median(pads[id].duplicate())])
	print("Done. %s" % ["FAILED: a gate was not reached" if failed else "all gates reached"])
	quit(1 if failed else 0)
