extends SceneTree
## Away-play check: what an away player gains in 2 hours offline, against the same 2 hours played actively.
## A greedy player (the push mode of tools/sim_run.gd: top affordable pad first, leave each zone at its gate, no resets,
## no gifts, no attributes, no relic equips) plays to a checkpoint. From that same point two branches run:
##   active  the player keeps pressing for AWAY_SECONDS at the "active" press rate in sim_profiles.tres
##   away    the player is offline for AWAY_SECONDS: Sim.apply_offline, the same call the game makes on return
## Gains are tallied per stat (press rewards by the pad's reward stat, passive income, bonuses). Each stat is compared
## as away / active. Values are medians over the seeds. Currencies are never added together.
## Run: godot --headless --path . --script tools/sim_away.gd [-- seeds]
## Changes no balance. The chart and the decision it feeds: docs/balance.md section 16.
## Caveat: the away branch stays in the zone it was in at the checkpoint (offline does not move the player), while the
## active branch can cross gates into the next zone. The zone mix therefore differs between the two branches.

const DT: float = 0.25
const AWAY_SECONDS: float = 7200.0
const CHECKPOINTS: Array[float] = [5.0, 15.0, 30.0, 60.0]   ## minutes of active play before the 2-hour stretch
const PROFILES_PATH: String = "res://content/config/sim_profiles.tres"
const ACTIVE_PROFILE: int = 1   ## index of "active" in sim_profiles.tres

var t_now: float = 0.0          ## game seconds, read by the signal handlers
var gains: Dictionary = {}      ## stat id -> float gained during the tallied stretch
var counting: bool = false      ## tallies only the 2-hour stretch, not the lead-in
var sim_ref: Sim = null


func _add(id: StringName, v: float) -> void:
	gains[id] = float(gains.get(id, 0.0)) + v


func _on_pressed(button_id: StringName, _world_pos: Vector3, gain: BigNum, _crit: bool) -> void:
	if not counting:
		return
	var b: ButtonDef = sim_ref.button_defs.get(button_id) as ButtonDef
	if b != null:
		_add(b.reward_stat, gain.to_float())


func _on_bonus(_kind: StringName, got: Dictionary) -> void:
	if counting:
		for k: StringName in got:
			_add(k, (got[k] as BigNum).to_float())


func _on_offline(_seconds: float, got: Dictionary) -> void:
	for k: StringName in got:
		_add(k, (got[k] as BigNum).to_float())


func _order(sim: Sim, zone: StringName) -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = sim.buttons_in_zone(zone)
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		var ta: TierDef = sim.tier_of(a.id)
		var tb: TierDef = sim.tier_of(b.id)
		var oa: int = ta.order if ta != null else 0
		var ob: int = tb.order if tb != null else 0
		return oa > ob if oa != ob else a.row_index > b.row_index)
	return buttons


## Plays greedily until `until_s` game seconds. Passive income is tallied per step while counting.
func _play(sim: Sim, until_s: float, interval: float, state: Dictionary) -> void:
	while t_now < until_s and sim.zone_id != &"":
		sim.step(DT)
		t_now += DT
		if counting:
			for s: StatDef in sim.stat_defs.values():
				if s.passive:
					_add(s.id, sim.income_per_second(s.id).to_float() * DT)
		if sim.is_gate_open(sim.zone_id):
			var nxt: StringName = (sim.zone_defs[sim.zone_id] as ZoneDef).next_zone
			if nxt != &"":
				sim.enter_zone(nxt)
		if t_now >= float(state["next_press"]):
			state["next_press"] = float(state["next_press"]) + interval
			for b: ButtonDef in _order(sim, sim.zone_id):
				if sim.try_press(b.id):
					break


## One seeded run: play to `pre_min`, then the 2-hour stretch either active or away. Returns the stretch's gains by stat.
func _run(seed_value: int, pre_min: float, interval: float, away: bool) -> Dictionary:
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
		return {}
	sim.events = SeasonalEvents.new()   # the same season for every branch
	sim.rng.seed = seed_value
	sim.new_game()
	sim_ref = sim
	sim.button_pressed.connect(_on_pressed)
	sim.bonus_gained.connect(_on_bonus)
	sim.offline_gained.connect(_on_offline)
	t_now = 0.0
	gains = {}
	counting = false
	var state: Dictionary = {"next_press": 0.0}
	_play(sim, pre_min * 60.0, interval, state)
	var stretch_end: float = t_now + AWAY_SECONDS
	counting = true
	if away:
		sim.apply_offline(AWAY_SECONDS)   # emits offline_gained, tallied by _on_offline
	else:
		_play(sim, stretch_end, interval, state)
	counting = false
	sim.button_pressed.disconnect(_on_pressed)
	sim.bonus_gained.disconnect(_on_bonus)
	sim.offline_gained.disconnect(_on_offline)
	return gains.duplicate()


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v: Array = values.duplicate()
	v.sort()
	return float(v[v.size() / 2])


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if args.size() > 0 else 3
	var profiles: SimProfiles = load(PROFILES_PATH) as SimProfiles
	if profiles == null:
		push_error("missing " + PROFILES_PATH)
		quit(1)
		return
	var pps: float = profiles.presses_per_second[ACTIVE_PROFILE]
	var interval: float = 1.0 / maxf(pps, 0.001)
	print("Away play vs active play, next %.0f h, active press rate %.2f/s, %d seeds (medians)" % [AWAY_SECONDS / 3600.0, pps, seeds])
	for pre: float in CHECKPOINTS:
		var active_by: Dictionary = {}
		var away_by: Dictionary = {}
		for s: int in seeds:
			var a: Dictionary = _run(s + 1, pre, interval, false)
			var w: Dictionary = _run(s + 1, pre, interval, true)
			for k: StringName in a:
				if not active_by.has(k):
					active_by[k] = []
				(active_by[k] as Array).append(float(a[k]))
			for k: StringName in w:
				if not away_by.has(k):
					away_by[k] = []
				(away_by[k] as Array).append(float(w[k]))
		var keys: Array = active_by.keys()
		for k: StringName in away_by:
			if not keys.has(k):
				keys.append(k)
		keys.sort_custom(func(x: StringName, y: StringName) -> bool:
			return _median(active_by.get(x, [])) > _median(active_by.get(y, [])))
		print("== after %.0f min of play" % pre)
		print("   %-18s %14s %14s %12s" % ["stat", "active 2h", "away 2h", "away/active"])
		for k: StringName in keys:
			var act: float = _median(active_by.get(k, []))
			var aw: float = _median(away_by.get(k, []))
			var ratio: String = "%.3f" % (aw / act) if act > 0.0 else "n/a"
			print("   %-18s %14s %14s %12s" % [str(k), String.num(act, 3), String.num(aw, 3), ratio])
	quit(0)
