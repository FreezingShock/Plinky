class_name SealedPulls
extends RefCounted
## Pure logic for sealed caches. No nodes, no autoloads. Sim owns one instance (`sim.sealed`).
## Cost, the per-reset count and the rarity roll all live here so they can be tested without a scene.
## The relic pool is read from RelicInventory (defs, stacks, weights), never written.

var defs: Dictionary = {}     ## StringName -> SealedPullDef
var pulls: Dictionary = {}    ## reset id -> pulls made since that reset was last done (int)


func set_defs(list: Array) -> void:
	defs.clear()
	for d: Variant in list:
		var def: SealedPullDef = d as SealedPullDef
		if def != null and def.id != &"":
			defs[def.id] = def


func def_of(cache_id: StringName) -> SealedPullDef:
	return defs.get(cache_id) as SealedPullDef


## Caches in a stable order (by id), so the strip never reorders when content changes.
func ordered() -> Array[SealedPullDef]:
	var keys: Array = defs.keys()
	keys.sort()
	var out: Array[SealedPullDef] = []
	for k: Variant in keys:
		out.append(defs[k] as SealedPullDef)
	return out


func pulls_this_reset(def: SealedPullDef) -> int:
	return int(pulls.get(def.reset_id, 0))


func remaining(def: SealedPullDef) -> int:
	return maxi(0, def.cap_per_reset - pulls_this_reset(def))


## Price of the next pull, in the reset's currency. Floored so it reads as a whole number.
func cost(def: SealedPullDef) -> BigNum:
	return BigNum.from_float(floorf(def.base_cost * pow(def.growth, float(pulls_this_reset(def)))))


## Relics a cache can roll: at or above the cache's minimum rank, with a drop weight, and not already at their stack cap.
func pool(inv: RelicInventory, min_rank: int) -> Array[RelicDef]:
	var out: Array[RelicDef] = []
	for d: RelicDef in inv.defs.values():
		if d.rarity.rank < min_rank or d.rarity.weight <= 0.0:
			continue
		if d.max_stacks > 0 and inv.stacks_of(d.id) >= d.max_stacks:
			continue
		out.append(d)
	return out


## Rolls one relic from the pool. Rarity is picked by weight first, then a relic inside that rarity, the same way
## RelicInventory.roll_drop does. Returns &"" when the pool is empty. `rng` is passed in so this stays deterministic.
func roll(rng: RandomNumberGenerator, inv: RelicInventory, min_rank: int) -> StringName:
	var by_rarity: Dictionary = {}   ## RarityDef -> Array[RelicDef]
	for d: RelicDef in pool(inv, min_rank):
		if not by_rarity.has(d.rarity):
			by_rarity[d.rarity] = []
		(by_rarity[d.rarity] as Array).append(d)
	var total: float = 0.0
	for r: RarityDef in by_rarity:
		total += r.weight
	if total <= 0.0:
		return &""
	var pick: float = rng.randf() * total
	for r: RarityDef in by_rarity:
		pick -= r.weight
		if pick <= 0.0:
			var list: Array = by_rarity[r]
			return (list[rng.randi() % list.size()] as RelicDef).id
	return &""


## Share of the pool's drop weight per rarity, as {rarity id: fraction} summing to 1. The strip shows it in the tooltip.
func odds(inv: RelicInventory, min_rank: int) -> Dictionary:
	var weight: Dictionary = {}
	var total: float = 0.0
	for d: RelicDef in pool(inv, min_rank):
		if not weight.has(d.rarity.id):
			weight[d.rarity.id] = d.rarity.weight
			total += d.rarity.weight
	var out: Dictionary = {}
	for k: Variant in weight:
		out[k] = float(weight[k]) / maxf(total, 0.000001)
	return out


## Counts one pull against the reset that pays for it.
func record(def: SealedPullDef) -> void:
	pulls[def.reset_id] = pulls_this_reset(def) + 1


## A reset was done: its caches start cheap again.
func on_reset(reset_id: StringName) -> void:
	pulls.erase(reset_id)


func clear() -> void:
	pulls.clear()


func to_dict() -> Dictionary:
	var o: Dictionary = {}
	for k: Variant in pulls:
		o[String(k)] = int(pulls[k])
	return {"pulls": o}


func from_dict(d: Dictionary) -> void:
	pulls.clear()
	var raw: Variant = d.get("pulls", {})
	if raw is Dictionary:
		for k: Variant in (raw as Dictionary):
			var n: int = maxi(0, int((raw as Dictionary)[k]))
			if n > 0:
				pulls[StringName(str(k))] = n
