extends SceneTree
## Plays the meadow to the Larkmoor gate, then Blooms again and again and prints each cycle: minutes to the first Bloom
## payout, Seeds paid, gifts bought. Same greedy strategy as tools/sim.gd (no walking, no relics, no attributes).
## Run: godot --headless --path . --script tools/sim_bloom.gd [-- seeds_to_wait_for [cycles]]
## seeds_to_wait_for (default 2): Bloom once the payout reaches this many Seeds. Higher = longer, fatter cycles.

const DT: float = 0.25
const MAX_SECONDS: float = 12.0 * 3600.0
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


func _buy_gifts(sim: Sim) -> int:
	var n: int = 0
	var again: bool = true
	while again:
		again = false
		for id: StringName in GIFT_ORDER:   # cheapest-first rotation keeps the gifts level with each other
			if sim.buy_attribute(id):
				n += 1
				again = true
	return n


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var want: int = int(args[0]) if args.size() > 0 else 2
	var cycles: int = int(args[1]) if args.size() > 1 else 12
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
		if sim.can_bloom() and sim.bloom_gain_preview() >= want:
			var paid: int = sim.bloom_gain_preview()
			var mult: float = sim.pad_yield_mult()
			sim.try_bloom()
			done += 1
			seeds_total += paid
			gifts += _buy_gifts(sim)
			print("Bloom %2d at %6.1f min (cycle %5.1f min): +%d Seeds (total %d), %d gifts, pad reward x%.2f" % [done, t / 60.0, (t - started) / 60.0, paid, seeds_total, gifts, mult])
			started = t
	print("%d Blooms in %.1f min%s" % [done, t / 60.0, "" if done >= cycles else " (NOT all reached)"])
	quit(0 if done >= cycles else 1)
