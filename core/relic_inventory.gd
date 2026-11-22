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

## Stacks that currently count (all owned stacks if equipped, else 0).
func active_stacks(id: StringName) -> int:
	return stacks_of(id) if is_equipped(id) else 0

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
	var total: float = 0.0
	var miss: float = 1.0
	var chance_like: bool = effect == RelicDef.Effect.DOUBLE_CHANCE or effect == RelicDef.Effect.PULSE_CHANCE
	for id in equipped:
		var d: RelicDef = defs[id]
		if d.effect != effect:
			continue
		var v: float = d.value_for(stacks_of(id))
		total += v
		miss *= 1.0 - v
	return 1.0 - miss if chance_like else total

## Multiplier for formulas: 1 + total_effect.
func multiplier(effect: RelicDef.Effect) -> float:
	return 1.0 + total_effect(effect)

## Rolls a drop. Returns the relic id, or &"" for no drop. `luck_level` comes from the Luck attribute.
## Rarity is picked by weight first (so Divine stays rare no matter how many relics exist), then a relic within it.
func roll_drop(rng: RandomNumberGenerator, luck_level: int) -> StringName:
	if rng.randf() >= config.drop_chance(luck_level):
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

## Rarity high to low, then name. For the inventory grid.
func sorted_owned() -> Array[RelicDef]:
	var out: Array[RelicDef] = []
	for id in owned:
		out.append(defs[id])
	out.sort_custom(func(a: RelicDef, b: RelicDef) -> bool:
		if a.rarity.rank != b.rarity.rank:
			return a.rarity.rank > b.rarity.rank
		return a.display_name < b.display_name)
	return out

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
