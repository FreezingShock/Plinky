class_name RelicInventory
extends RefCounted
## Pure logic for owned and equipped relics. No nodes, no scenes, no autoloads.
## GameState owns one instance, forwards its signals to EventBus, and saves it with to_dict().
##
## Model: you OWN stacks of each relic. You EQUIP relic types into a limited number of slots.
## An equipped relic type applies ALL of its owned stacks. Unequipped relics do nothing.

signal changed
signal relic_gained(relic_id: StringName, stacks: int)
signal relic_equipped(relic_id: StringName)
signal relic_unequipped(relic_id: StringName)

var config: RelicConfig
var defs: Dictionary = {}         ## StringName -> RelicDef
var owned: Dictionary = {}        ## StringName -> int stacks
var equipped: Array[StringName] = []  ## equipped relic ids, in slot order, no empties
var rebirths: int = 0

func _init(p_config: RelicConfig, p_defs: Array[RelicDef]) -> void:
	config = p_config
	for d in p_defs:
		defs[d.id] = d

func slot_count() -> int:
	return config.slots_for(rebirths)

func free_slots() -> int:
	return slot_count() - equipped.size()

func stacks_of(id: StringName) -> int:
	return owned.get(id, 0)

## Lowercase rarity id (&"epic") for a relic, or &"" if unknown. Feed this to Juice.relic_drop().
func rarity_of(id: StringName) -> StringName:
	return defs[id].rarity.id if defs.has(id) else &""

func is_equipped(id: StringName) -> bool:
	return equipped.has(id)

func add_relic(id: StringName, stacks: int = 1) -> void:
	if not defs.has(id) or stacks <= 0:
		return
	owned[id] = stacks_of(id) + stacks
	relic_gained.emit(id, owned[id])
	changed.emit()

## Equip into the first free slot. False if not owned, already equipped, or no free slot.
func equip(id: StringName) -> bool:
	if stacks_of(id) <= 0 or is_equipped(id) or free_slots() <= 0:
		return false
	equipped.append(id)
	relic_equipped.emit(id)
	changed.emit()
	return true

func unequip(id: StringName) -> bool:
	if not is_equipped(id):
		return false
	equipped.erase(id)
	relic_unequipped.emit(id)
	changed.emit()
	return true

## Put `new_id` into the slot that holds `old_id`. Free, instant, no cost.
func swap(old_id: StringName, new_id: StringName) -> bool:
	var i: int = equipped.find(old_id)
	if i < 0 or stacks_of(new_id) <= 0 or is_equipped(new_id):
		return false
	equipped[i] = new_id
	relic_unequipped.emit(old_id)
	relic_equipped.emit(new_id)
	changed.emit()
	return true

## Total effect of every equipped relic of one kind. Linear stacking sums; chances combine as 1-(1-a)(1-b).
func total_effect(effect: RelicDef.Effect) -> float:
	return _total_for(equipped, effect)

func _total_for(list: Array[StringName], effect: RelicDef.Effect) -> float:
	var total: float = 0.0
	var miss: float = 1.0
	var chance_like: bool = effect in [RelicDef.Effect.DOUBLE_CHANCE, RelicDef.Effect.PULSE_CHANCE,
			RelicDef.Effect.CRIT_CHANCE, RelicDef.Effect.PRESS_REFUND]
	for id in list:
		var d: RelicDef = defs[id]
		if d.effect != effect:
			continue
		var v: float = d.value_for(stacks_of(id))
		total += v
		miss *= 1.0 - v
	return 1.0 - miss if chance_like else total

## Every effect kind with a non-zero total from the equipped relics, as [{effect, total}], in enum order.
func active_bonuses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: int in RelicDef.Effect.values():
		var v: float = total_effect(e as RelicDef.Effect)
		if v > 0.0:
			out.append({"effect": e, "total": v})
	return out

## What equipping `id` would change, as [{effect, before, after}] for the effects that differ.
## With `replacing` set, that relic leaves its slot first (the swap case); otherwise `id` takes a free slot.
## Pure preview: nothing is equipped and no signal fires.
func preview_change(id: StringName, replacing: StringName = &"") -> Array[Dictionary]:
	var after: Array[StringName] = equipped.duplicate()
	if replacing != &"" and after.has(replacing):
		after[after.find(replacing)] = id
	elif not after.has(id):
		after.append(id)
	var kinds: Array[int] = []
	for rid: StringName in [id, replacing]:
		if defs.has(rid):
			var k: int = int((defs[rid] as RelicDef).effect)
			if not kinds.has(k):
				kinds.append(k)
	var out: Array[Dictionary] = []
	for k in kinds:
		var before_v: float = _total_for(equipped, k as RelicDef.Effect)
		var after_v: float = _total_for(after, k as RelicDef.Effect)
		if not is_equal_approx(before_v, after_v):
			out.append({"effect": k, "before": before_v, "after": after_v})
	return out

## Multiplier for formulas: 1 + total_effect.
func multiplier(effect: RelicDef.Effect) -> float:
	return 1.0 + total_effect(effect)

## Press reward multiplier from ZONE_GAIN relics that name this zone. 1.0 when none do.
func zone_mult(zone_id: StringName) -> float:
	var m: float = 1.0
	for id in equipped:
		var d: RelicDef = defs[id]
		if d.effect == RelicDef.Effect.ZONE_GAIN and d.zone == zone_id:
			m += d.value_for(stacks_of(id))
	return m

## Reward multiplier for press number `index` (1-based, counted over the whole run). Every equipped SURGE relic
## whose period divides the index adds its value.
func surge_mult(index: int) -> float:
	var m: float = 1.0
	for id in equipped:
		var d: RelicDef = defs[id]
		if d.effect == RelicDef.Effect.SURGE and d.period > 0 and index % d.period == 0:
			m += d.value_for(stacks_of(id))
	return m

## Average of surge_mult over a long run: each surge adds its value once per period presses.
func surge_average() -> float:
	var m: float = 1.0
	for id in equipped:
		var d: RelicDef = defs[id]
		if d.effect == RelicDef.Effect.SURGE and d.period > 0:
			m += d.value_for(stacks_of(id)) / float(d.period)
	return m

## Seconds of play that must pass before the next pity drop. PITY_SPEED relics shorten it, never below a tenth.
func pity_due(first_drop: bool) -> float:
	if first_drop:
		return config.first_drop_seconds
	return config.pity_seconds * maxf(0.1, 1.0 - total_effect(RelicDef.Effect.PITY_SPEED))

## How a relic is found, in words, for the gallery: the drop odds from its rarity weight, or the non-drop sources.
## Pure: reads the weights of every relic, so it stays right when content changes.
func acquire_text(id: StringName) -> String:
	if not defs.has(id):
		return ""
	var d: RelicDef = defs[id]
	if d.rarity.weight <= 0.0:
		return "Granted by rebirths or achievements."
	# Total weight counts each rarity once, not once per relic.
	var total: float = 0.0
	var seen: Dictionary = {}
	var count: int = 0
	for o: RelicDef in defs.values():
		if o.rarity.weight <= 0.0:
			continue
		if not seen.has(o.rarity.id):
			seen[o.rarity.id] = true
			total += o.rarity.weight
		if o.rarity.id == d.rarity.id:
			count += 1
	var per: float = d.rarity.weight / float(maxi(count, 1))
	return "Drops from presses, about 1 in %d drops." % roundi(total / per)

## Rarity ranks that have at least one relic, lowest first. The gallery makes one tab per rank.
func tier_ranks() -> Array[int]:
	var out: Array[int] = []
	for d: RelicDef in defs.values():
		if not out.has(d.rarity.rank):
			out.append(d.rarity.rank)
	out.sort()
	return out

## Relics of one rarity rank, sorted by name. Empty when the rank has none.
func defs_of_rank(rank: int) -> Array[RelicDef]:
	var out: Array[RelicDef] = []
	for d: RelicDef in defs.values():
		if d.rarity.rank == rank:
			out.append(d)
	out.sort_custom(func(a: RelicDef, b: RelicDef) -> bool: return a.display_name < b.display_name)
	return out

## Highest rarity rank among equipped relics, or -1 for none. The walker aura colours its pool with it.
func top_equipped_rank() -> int:
	var best: int = -1
	for id in equipped:
		if defs.has(id):
			best = maxi(best, (defs[id] as RelicDef).rarity.rank)
	return best

## Rolls a drop. Returns the relic id, or &"" for no drop. `luck_level` comes from the Luck attribute.
## Rarity is picked by weight first (so Divine stays rare no matter how many relics exist), then a relic within it.
func roll_drop(rng: RandomNumberGenerator, luck_level: int, force: bool = false) -> StringName:
	if not force and rng.randf() >= config.drop_chance(luck_level) * multiplier(RelicDef.Effect.DROP_CHANCE):
		return &""
	var by_rarity: Dictionary = {}  ## RarityDef -> Array[RelicDef]
	for d: RelicDef in defs.values():
		if d.rarity.weight <= 0.0 or (d.max_stacks > 0 and stacks_of(d.id) >= d.max_stacks):
			continue
		if not by_rarity.has(d.rarity):
			by_rarity[d.rarity] = []
		by_rarity[d.rarity].append(d)
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

## Rarity high to low, then name. The default order of the collection.
func sorted_owned() -> Array[RelicDef]:
	return RelicQuery.new().apply(self)

func set_rebirths(n: int) -> void:
	var before: int = slot_count()
	rebirths = n
	# Slots never shrink during a run, but a lowered count must not leave extra equips.
	while equipped.size() > slot_count():
		unequip(equipped[equipped.size() - 1])
	if slot_count() != before:
		changed.emit()

func to_dict() -> Dictionary:
	var o: Dictionary = {}
	for id in owned:
		o[String(id)] = owned[id]
	return {"owned": o, "equipped": equipped.map(func(i: StringName) -> String: return String(i))}

func from_dict(d: Dictionary) -> void:
	owned.clear()
	equipped.clear()
	for k in d.get("owned", {}):
		if defs.has(StringName(k)):
			owned[StringName(k)] = int(d["owned"][k])
	for k in d.get("equipped", []):
		var id := StringName(k)
		if stacks_of(id) > 0 and not equipped.has(id) and equipped.size() < slot_count():
			equipped.append(id)
	changed.emit()
