extends RefCounted
## The perf caches and pools: a zone's tier list is built once and rebuilt when the tier data is replaced, and a finished
## ParticleBurst goes back to the pool and is reused instead of adding nodes (docs/perf.md, pooled effects).


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var first: Array[TierDef] = sim.tiers_in_zone(&"larkmoor")
	var again: Array[TierDef] = sim.tiers_in_zone(&"larkmoor")
	t.ok(not first.is_empty(), "Larkmoor has its flower tiers")
	t.ok(first == again and first.size() == again.size(), "the cached tier list is the same list on every call")
	var ordered: bool = true
	for i in range(1, first.size()):
		ordered = ordered and first[i - 1].order < first[i].order
	t.ok(ordered, "tiers come lowest order first")

	var keep: Dictionary = sim.tier_defs
	sim.tier_defs = {}
	t.eq(sim.tiers_in_zone(&"larkmoor").size(), 0, "replacing the tier data drops the cached lists")
	sim.tier_defs = keep
	t.eq(sim.tiers_in_zone(&"larkmoor").size(), first.size(), "restoring the tier data restores the list")

	# --script runs have no main loop yet, so the bursts are played by hand here: no tree, no frames.
	ParticleBurst._live = 0   # bursts left alive by earlier suites must not use up the live cap
	var parent := Node.new()
	var colours: Array[Color] = [Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0)]
	for i in 3:
		ParticleBurst.spawn(parent, Vector2(10.0 * i, 0.0), colours, 4)
	t.eq(parent.get_child_count(), 3, "three bursts spawned into the parent")
	for c: Node in parent.get_children():
		(c as ParticleBurst)._process(10.0)   # every particle past its life: the burst finishes
	t.ok(not (parent.get_child(0) as ParticleBurst).visible, "a finished burst hides")
	ParticleBurst.spawn(parent, Vector2.ZERO, colours, 4)
	ParticleBurst.spawn(parent, Vector2.ZERO, colours, 4)
	t.eq(parent.get_child_count(), 3, "new bursts reuse the pooled ones instead of adding nodes")
	var shown: int = 0
	for c: Node in parent.get_children():
		shown += 1 if (c as ParticleBurst).visible else 0
	t.eq(shown, 2, "the two reused bursts show again, the third stays hidden")
	parent.free()   # frees the bursts with it
