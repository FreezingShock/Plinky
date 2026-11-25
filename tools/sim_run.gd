extends SceneTree
## Full-run pacing chart. Plays Meadow, then Larkmoor, then the Ember Quarry with the greedy buyer (top affordable pad
## first, no walking, attributes or relics) and reports the median minutes to each zone gate, each zone reset's tier
## (1, 2, 3, 5, 7 and 10 uses: the gift tiers) and the longest stretch in each zone with nothing affordable.
## Modes:
##   push  leave each zone the moment its gate opens; no zone resets. Slower to the Quarry than loop, because the Bloom
##         bonus (+25% per use) is what carries the Quarry's costs.
##   loop  after a gate opens, stay in that zone and take its reset (Bloom in Larkmoor, Nucleus in the Quarry) each time
##         it pays at least `gain`, until it has been used LOOP_RESETS times or LOOP_CAP_MIN minutes have passed. The
##         Meadow has no reset yet (Bloom opens with Larkmoor), so the Meadow is always left at its gate.
## Times are for a floor strategy: no gift or attribute is bought, so resets are weaker than in play. Their bonus
## (every use adds to every pad) still runs.
## Run one profile per process: godot --headless --path . --script tools/sim_run.gd -- <mode> <gain> <profile index>
## Chart of the 2026-11-25 run: docs/balance.md section 14.
## Prints "NOT reached" for any gate the run could not open within MAX_MIN, and exits 1 then.

const DT: float = 0.25
const MAX_MIN: float = 600.0
const LOOP_RESETS: int = 10
const LOOP_CAP_MIN: float = 240.0
const MILESTONES: Array[int] = [1, 2, 3, 5, 7, 10]
const PROFILES_PATH: String = "res://content/config/sim_profiles.tres"
const ZONES: Array[StringName] = [&"zone1", &"larkmoor", &"zone2"]

var t_now: float = 0.0   # seconds of game time, read by the signal handlers


func _order(sim: Sim, zone: StringName) -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(zone)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		var ta: TierDef = sim.tier_of(a.id)
		var tb: TierDef = sim.tier_of(b.id)
		var oa: int = ta.order if ta != null else 0
		var ob: int = tb.order if tb != null else 0
		return oa > ob if oa != ob else a.row_index > b.row_index)
	return buttons


## One seeded run. Returns {zones: {zone: {arrive, gate, idle_max}}, tiers: {tier: min}, resets: {"id:n": min}, end: min}.
func _run(pps: float, seed_value: int, loop: bool, gain: float) -> Dictionary:
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
	sim.events = SeasonalEvents.new()   # the floor must not depend on the season the run starts in
	sim.rng.seed = seed_value
	sim.new_game()
	var out: Dictionary = {"zones": {}, "tiers": {}, "resets": {}, "goals": {}, "end": -1.0}
	t_now = 0.0
	var on_tier: Callable = func(id: StringName) -> void: out["tiers"][id] = t_now / 60.0
	var on_goal: Callable = func(gid: StringName) -> void: out["goals"][gid] = t_now / 60.0
	var on_reset: Callable = func(rid: StringName, _gained: BigNum) -> void:
		var n: int = sim.reset_count(rid)
		if n in MILESTONES:
			out["resets"]["%s:%d" % [rid, n]] = t_now / 60.0
	sim.tier_opened.connect(on_tier)
	sim.reset_done.connect(on_reset)
	if sim.has_signal("goal_reached"):   # mid-game goals (PR #521) exist only on builds that have them
		sim.connect("goal_reached", on_goal)
	var interval: float = 1.0 / maxf(pps, 0.001)
	var next_press: float = 0.0
	var zone: StringName = sim.zone_id
	while zone != &"" and t_now < MAX_MIN * 60.0:
		var z: ZoneDef = sim.zone_defs[zone] as ZoneDef
		var buttons: Array[ButtonDef] = _order(sim, zone)
		var rdef: ZoneResetDef = sim.reset_for_zone(zone)
		var arrive: float = t_now / 60.0
		var gate_at: float = -1.0
		var idle_run: float = 0.0
		var idle_max: float = 0.0
		var next_sample: float = t_now
		while t_now < MAX_MIN * 60.0:
			sim.step(DT)
			t_now += DT
			if t_now >= next_press:
				next_press += interval
				for b: ButtonDef in buttons:
					if sim.try_press(b.id):
						break
			if t_now >= next_sample:
				next_sample += 1.0
				var any_affordable: bool = false
				for b: ButtonDef in buttons:
					if not sim.is_pad_locked(b.id) and sim.can_afford(b.id):
						any_affordable = true
						break
				idle_run = 0.0 if any_affordable else idle_run + 1.0
				idle_max = maxf(idle_max, idle_run)
			if gate_at < 0.0 and sim.is_gate_open(zone):
				gate_at = t_now / 60.0
				if not loop or rdef == null or not sim.reset_unlocked(rdef.id):
					break
			if gate_at >= 0.0:
				# loop: take the reset whenever it pays enough, then stop when its tier count or the cap is reached
				if sim.reset_gain(rdef.id).gte(BigNum.from_float(gain)):
					sim.try_reset(rdef.id)
				if sim.reset_count(rdef.id) >= LOOP_RESETS or t_now / 60.0 - gate_at > LOOP_CAP_MIN:
					break
		out["zones"][zone] = {"arrive": arrive, "gate": gate_at, "idle_max": idle_max}
		var nxt: StringName = z.next_zone
		if gate_at >= 0.0 and nxt != &"" and sim.enter_zone(nxt):
			zone = nxt
		else:
			zone = &""
	sim.tier_opened.disconnect(on_tier)
	sim.reset_done.disconnect(on_reset)
	if sim.has_signal("goal_reached"):
		sim.disconnect("goal_reached", on_goal)
	out["end"] = t_now / 60.0 if sim.is_gate_open(&"zone2") else -1.0   # the run ends when the Quarry's loop is done
	return out


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return values[values.size() / 2]


func _fmt(values: Array) -> String:
	var nums: Array = values.duplicate()
	if nums.has(-1.0):
		return "NOT reached"
	nums.sort()
	return "%6.1f (range %.1f to %.1f)" % [_median(values.duplicate()), nums.front(), nums.back()]


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "loop"
	var gain: float = float(args[1]) if args.size() > 1 else 4.0
	var only: int = int(args[2]) if args.size() > 2 else -1
	var loop: bool = mode == "loop"   # push: no zone resets
	var profiles: SimProfiles = load(PROFILES_PATH) as SimProfiles
	if profiles == null:
		push_error("missing " + PROFILES_PATH)
		quit(1)
		return
	var failed: bool = false
	for i: int in profiles.profile_names.size():
		if only >= 0 and i != only:
			continue
		var pname: String = profiles.profile_names[i]
		var pps: float = profiles.presses_per_second[i]
		var zone_vals: Dictionary = {}
		var tier_vals: Dictionary = {}
		var reset_vals: Dictionary = {}
		var end_vals: Array = []
		var goal_vals: Dictionary = {}
		for z: StringName in ZONES:
			zone_vals[z] = {"arrive": [], "gate": [], "idle_max": []}
		for s: int in profiles.seeds:
			var r: Dictionary = _run(pps, s + 1, loop, gain)
			for z: StringName in ZONES:
				var zr: Dictionary = r["zones"].get(z, {"arrive": -1.0, "gate": -1.0, "idle_max": -1.0})
				for k: String in ["arrive", "gate", "idle_max"]:
					zone_vals[z][k].append(float(zr[k]))
				if float(zr["gate"]) < 0.0:
					failed = true   # never arrived, or the gate did not open in time
			for id: StringName in r["tiers"]:
				if not tier_vals.has(id):
					tier_vals[id] = []
				tier_vals[id].append(r["tiers"][id])
			for key: String in r["resets"]:
				if not reset_vals.has(key):
					reset_vals[key] = []
				reset_vals[key].append(r["resets"][key])
			end_vals.append(float(r["end"]))
			for gid: StringName in r["goals"]:
				if not goal_vals.has(gid):
					goal_vals[gid] = []
				goal_vals[gid].append(r["goals"][gid])
		print("== %s (%.2f presses/s, %d seeds, mode %s, reset at %.0f+ paid)" % [pname, pps, profiles.seeds, mode, gain])
		for z: StringName in ZONES:
			var gate_vals: Array = zone_vals[z]["gate"]
			if gate_vals.is_empty():
				continue
			var idle_min: Array = []
			for v: float in zone_vals[z]["idle_max"]:
				idle_min.append(v / 60.0)
			print("   %-9s arrive median %s | gate %s | longest nothing-to-buy %s" % [
				z, _fmt(zone_vals[z]["arrive"]), _fmt(gate_vals), _fmt(idle_min)])
		var tier_keys: Array = tier_vals.keys()
		tier_keys.sort()
		for id: Variant in tier_keys:
			print("   tier %-12s opens %s" % [str(id), _fmt(tier_vals[id])])
		for rid: String in ["bloom", "nucleus"]:
			for n: int in MILESTONES:
				var key: String = "%s:%d" % [rid, n]
				if reset_vals.has(key):
					print("   reset %-14s %s" % [key, _fmt(reset_vals[key])])
		var goal_keys: Array = goal_vals.keys()
		goal_keys.sort()
		for gid: Variant in goal_keys:
			print("   goal %-18s reached %s" % [str(gid), _fmt(goal_vals[gid])])
		print("   run done (Quarry loop finished) %s" % _fmt(end_vals))
	print("Done. %s" % ["FAILED: a gate was not reached" if failed else "all gates reached"])
	quit(1 if failed else 0)
