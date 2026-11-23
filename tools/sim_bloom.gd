extends SceneTree
## Plays the meadow to the Larkmoor gate, then Blooms again and again and prints each cycle: minutes to the first Bloom
## payout, Seeds paid, gifts bought. Same greedy strategy as tools/sim.gd (no walking, no relics, no attributes).
## Run: godot --headless --path . --script tools/sim_bloom.gd [-- seeds_to_wait_for [cycles]]
## Exits 1 unless it reaches the Blooms asked for (default 5) and the last cycle is shorter than the first.
## seeds_to_wait_for (default 2): Bloom once the payout reaches this many Seeds. Higher = longer, fatter cycles.

const DT: float = 0.25
const MAX_SECONDS: float = 12.0 * 3600.0
const MIN_CYCLES: int = 5   ## the run must reach at least this many Blooms, each cycle ending sooner than the first
const GIFT_ORDER: Array[StringName] = [&"bloom_head_start", &"bloom_soil", &"bloom_wide", &"bloom_dusk"]


func _order(sim: Sim) -> Array[ButtonDef]:
	var buttons: Array[ButtonDef] = []
	for z: StringName in [&"zone1", &"larkmoor"]:
		buttons.append_array(sim.buttons_in_zone(z))
	buttons.sort_custom(func(a: ButtonDef, b: ButtonDef) -> bool:
		var ta: TierDef = sim.tier_of(a.id)
		var tb: TierDef = sim.tier_of(b.id)
		var oa: int = ta.order if ta != null else 0
		var ob: int = tb.order if tb != null else 0
		return oa > ob if oa != ob else a.row_index > b.row_index)
	return buttons


## Buys the cheapest affordable gift again and again, so the gifts level together (every gift the sim has: Sprites and
## Wildflower included, which then press for the greedy player).
func _buy_gifts(sim: Sim) -> int:
	var n: int = 0
	while true:
		var best: StringName = &""
		var best_cost: float = INF
		for a: AttributeDef in sim.attribute_defs.values():
			if a.currency != &"seeds" or sim.attr_level(a.id) >= a.cap or not sim.attr_unlocked(a.id):
				continue
			var c: float = sim.attribute_cost(a.id).to_float()
			if c < best_cost and sim.get_stat(&"seeds").to_float() >= c:
				best = a.id
				best_cost = c
		if best == &"" or not sim.buy_attribute(best):
			break
		n += 1
	return n


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var want: int = int(args[0]) if args.size() > 0 else 2
	var cycles: int = int(args[1]) if args.size() > 1 else MIN_CYCLES
	var sim := Sim.new()
	if not ContentLoader.load_into(sim):
		push_error("content failed to load")
		quit(1)
		return
	sim.new_game()
	var t: float = 0.0
	var started: float = 0.0
	var next_press: float = 0.0
	var buttons: Array[ButtonDef] = _order(sim)
	var done: int = 0
	var cycle_len: Array[float] = []
	var gifts: int = 0
	var seeds_total: int = 0
	sim.enter_zone(&"zone1")
	while t < MAX_SECONDS and done < cycles:
		sim.step(DT)
		t += DT
		if sim.zone_id == &"zone1" and sim.is_gate_open(&"zone1"):
			sim.enter_zone(&"larkmoor")
		if t >= next_press:
			next_press += sim.press_interval()
			for b: ButtonDef in buttons:
				if sim.zone_id == b.zone and sim.try_press(b.id):
					break
		if sim.can_reset(&"bloom") and sim.reset_gain(&"bloom") >= want:
			var paid: int = sim.reset_gain(&"bloom")
			var mult: float = sim.pad_yield_mult()
			sim.try_reset(&"bloom")
			cycle_len.append(t - started)
			done += 1
			seeds_total += paid
			gifts += _buy_gifts(sim)
			print("Bloom %2d at %6.1f min (cycle %5.1f min): +%d Seeds (total %d), %d gifts, pad reward x%.2f" % [done, t / 60.0, (t - started) / 60.0, paid, seeds_total, gifts, mult])
			started = t
	print("%d Blooms in %.1f min%s" % [done, t / 60.0, "" if done >= cycles else " (NOT all reached)"])
	var faster: bool = cycle_len.size() >= 2 and cycle_len[cycle_len.size() - 1] < cycle_len[0]
	print("later Blooms come %s (first cycle %.1f min, last %.1f min)" % ["sooner" if faster else "NOT sooner", cycle_len[0] / 60.0 if not cycle_len.is_empty() else 0.0, cycle_len[cycle_len.size() - 1] / 60.0 if not cycle_len.is_empty() else 0.0])
	quit(0 if done >= cycles and faster else 1)
