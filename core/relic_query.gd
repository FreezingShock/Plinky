class_name RelicQuery
extends RefCounted
## Sort and filter for the Relics collection. Pure logic: reads a RelicInventory, touches no nodes.
## The panel owns one and cycles its three settings from the toolbar buttons.

enum Sort { RARITY, NAME, STACKS, EQUIPPED }
enum Scope { ALL, EQUIPPED, UNEQUIPPED }


var sort: Sort = Sort.RARITY
var scope: Scope = Scope.ALL
## Only this rarity rank, or -1 for every rarity.
var rarity_rank: int = -1


## Steps through the rarities the player owns, then back to all. Falls back to all if the current one is gone.
func cycle_rarity(inv: RelicInventory) -> void:
	var ranks: Array[int] = owned_ranks(inv)
	if rarity_rank < 0:
		rarity_rank = ranks[0] if not ranks.is_empty() else -1
		return
	var i: int = ranks.find(rarity_rank)
	rarity_rank = ranks[i + 1] if i >= 0 and i + 1 < ranks.size() else -1

func rarity_name(inv: RelicInventory) -> String:
	for d: RelicDef in inv.defs.values():
		if d.rarity.rank == rarity_rank:
			return d.rarity.display_name
	return "All"

func is_default() -> bool:
	return sort == Sort.RARITY and scope == Scope.ALL and rarity_rank < 0

func reset() -> void:
	sort = Sort.RARITY
	scope = Scope.ALL
	rarity_rank = -1

## Rarity ranks present in the collection, high to low.
static func owned_ranks(inv: RelicInventory) -> Array[int]:
	var out: Array[int] = []
	for id in inv.owned:
		var r: int = (inv.defs[id] as RelicDef).rarity.rank
		if not out.has(r):
			out.append(r)
	out.sort_custom(func(a: int, b: int) -> bool: return a > b)
	return out

func apply(inv: RelicInventory) -> Array[RelicDef]:
	var out: Array[RelicDef] = []
	for id in inv.owned:
		var d: RelicDef = inv.defs[id]
		if rarity_rank >= 0 and d.rarity.rank != rarity_rank:
			continue
		var eq: bool = inv.is_equipped(id)
		if (scope == Scope.EQUIPPED and not eq) or (scope == Scope.UNEQUIPPED and eq):
			continue
		out.append(d)
	out.sort_custom(func(a: RelicDef, b: RelicDef) -> bool: return _before(inv, a, b))
	return out

func _before(inv: RelicInventory, a: RelicDef, b: RelicDef) -> bool:
	match sort:
		Sort.NAME:
			return a.display_name < b.display_name
		Sort.STACKS:
			var sa: int = inv.stacks_of(a.id)
			var sb: int = inv.stacks_of(b.id)
			if sa != sb:
				return sa > sb
		Sort.EQUIPPED:
			var ea: bool = inv.is_equipped(a.id)
			if ea != inv.is_equipped(b.id):
				return ea
	if a.rarity.rank != b.rarity.rank:
		return a.rarity.rank > b.rarity.rank
	return a.display_name < b.display_name
