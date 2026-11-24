extends RefCounted
## Sealed caches suite: price growth, the per-reset cap, the rarity pool and roll, the empty pool, and the Sim path
## (reset gate, currency spend, save round-trip). Run through tests/run.gd.

func run(t: SceneTree) -> void:
	var bloom: SealedPullDef = load("res://content/sealed/bloom_cache.tres") as SealedPullDef
	var nucleus: SealedPullDef = load("res://content/sealed/nucleus_cache.tres") as SealedPullDef
	t.ok(bloom != null and nucleus != null, "both caches load from content/sealed")
	if bloom == null or nucleus == null:
		return

	# Price and cap on a bare SealedPulls (no sim).
	var sp := SealedPulls.new()
	sp.set_defs([bloom, nucleus])
	t.ok(sp.ordered().size() == 2 and sp.ordered()[0].id == &"bloom_cache", "caches are listed in id order")
	t.ok(sp.cost(bloom).to_float() == 40.0, "first pull costs the base 40")
	sp.record(bloom)
	t.ok(sp.cost(bloom).to_float() == 60.0, "second pull costs 40 x 1.5 = 60")
	sp.record(bloom)
	t.ok(sp.cost(bloom).to_float() == 90.0, "third pull costs 90")
	t.ok(sp.cost(nucleus).to_float() == 40.0, "a cache's price only counts its own reset's pulls")
	sp.record(bloom); sp.record(bloom); sp.record(bloom)
	t.ok(sp.remaining(bloom) == 0, "five pulls use up the reset's cap")
	t.ok(sp.cost(bloom).to_float() == 303.0, "the price keeps climbing past the cap: floor(40 x 1.5^5) = 303")
	sp.on_reset(&"bloom")
	t.ok(sp.remaining(bloom) == 5 and sp.cost(bloom).to_float() == 40.0, "a reset restores the cap and the base price")
	t.ok(sp.remaining(nucleus) == 5, "a Bloom does not touch the Nucleus cache")

	# Rarity pool and roll on real relic content.
	var cfg: RelicConfig = load("res://content/relics/_config.tres") as RelicConfig
	var defs: Array[RelicDef] = []
	for f in DirAccess.open("res://content/relics").get_files():
		var name: String = f.trim_suffix(".remap")
		if name.begins_with("_") or not name.ends_with(".tres"):
			continue
		defs.append(load("res://content/relics/" + name) as RelicDef)
	var inv := RelicInventory.new(cfg, defs)
	var pool: Array[RelicDef] = sp.pool(inv, bloom.min_rank)
	t.ok(not pool.is_empty(), "the Rare-and-up pool is not empty")
	var low_or_zero: int = 0
	for d: RelicDef in pool:
		if d.rarity.rank < bloom.min_rank or d.rarity.weight <= 0.0:
			low_or_zero += 1
	t.ok(low_or_zero == 0, "the pool has no Common, Uncommon, Divine or Special relic")

	var shares: Dictionary = sp.odds(inv, bloom.min_rank)
	var total: float = 0.0
	for k: Variant in shares:
		total += float(shares[k])
	t.ok(absf(total - 1.0) < 0.0001, "odds add up to 1, got %f" % total)
	t.ok(shares.has(&"rare") and shares.has(&"mythic"), "odds list Rare and Mythic")

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var seen: Dictionary = {}
	var bad: int = 0
	var rare_hits: int = 0
	var rolls: int = 4000
	for i in rolls:
		var id: StringName = sp.roll(rng, inv, bloom.min_rank)
		if id == &"" or not inv.defs.has(id):
			bad += 1
			continue
		seen[id] = true
		if inv.defs[id].rarity.rank < bloom.min_rank:
			bad += 1
		if inv.defs[id].rarity.id == &"rare":
			rare_hits += 1
	t.ok(bad == 0, "every roll is a valid Rare-or-better relic (%d bad)" % bad)
	# Rare weight 9 of 14.9 total is about 60 percent. Loose band so a seed change cannot flake it.
	var rare_share: float = float(rare_hits) / float(rolls)
	t.ok(rare_share > 0.52 and rare_share < 0.68, "rare share near 60 percent, got %.3f" % rare_share)
	t.ok(seen.size() > 6, "rolls reach many different relics, got %d" % seen.size())

	# Same seed, same result: rolls are deterministic.
	var r1 := RandomNumberGenerator.new(); r1.seed = 99
	var r2 := RandomNumberGenerator.new(); r2.seed = 99
	t.ok(sp.roll(r1, inv, bloom.min_rank) == sp.roll(r2, inv, bloom.min_rank), "same seed gives the same relic")

	# An empty pool rolls nothing (Special never rolls, so min rank 7 leaves no relics).
	t.ok(sp.roll(rng, inv, 7) == &"", "an empty pool rolls nothing")

	# Save round trip on the bare object.
	sp.record(nucleus)
	var back := SealedPulls.new()
	back.set_defs([bloom, nucleus])
	back.from_dict(sp.to_dict())
	t.ok(back.pulls_this_reset(nucleus) == 1 and back.pulls_this_reset(bloom) == 0, "pull counts survive to_dict and from_dict")

	# Sim path: the reset gate, the currency spend, the grant and the save.
	var sim := Sim.new()
	t.ok(ContentLoader.load_into(sim), "content loads into a sim for the sealed path")
	sim.new_game()
	t.ok(sim.try_sealed_pull(&"bloom_cache") == &"", "no pull before the Bloom has been used")
	sim.reset_counts[&"bloom"] = 1
	sim.dev_set_stat(&"seeds", BigNum.from_float(1000.0))
	var got: StringName = sim.try_sealed_pull(&"bloom_cache")
	t.ok(got != &"" and sim.relics.stacks_of(got) >= 1, "a pull grants the relic it rolls")
	t.ok(is_equal_approx(sim.get_stat(&"seeds").to_float(), 960.0), "the first pull spends 40 Seeds")
	var got2: StringName = sim.try_sealed_pull(&"bloom_cache")
	t.ok(got2 != &"" and is_equal_approx(sim.get_stat(&"seeds").to_float(), 900.0), "the second pull spends 60 more")
	sim.dev_set_stat(&"seeds", BigNum.from_float(10.0))
	t.ok(sim.try_sealed_pull(&"bloom_cache") == &"", "a short Seeds balance buys nothing")
	t.ok(is_equal_approx(sim.get_stat(&"seeds").to_float(), 10.0), "and spends nothing")
	t.ok(sim.try_sealed_pull(&"no_such_cache") == &"", "an unknown cache buys nothing")

	var saved: Dictionary = sim.to_dict()
	var loaded := Sim.new()
	ContentLoader.load_into(loaded)
	loaded.from_dict(saved)
	t.ok(loaded.sealed.pulls_this_reset(bloom) == 2, "two pulls this reset survive a save")
	t.ok(loaded.sealed.cost(bloom).to_float() == 90.0, "and the next price follows them")
