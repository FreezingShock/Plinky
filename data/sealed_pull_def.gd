class_name SealedPullDef
extends Resource
## A sealed cache: a late-game sink that is bought with a zone reset's currency and rolls one relic. One file per cache in
## content/sealed/*.tres. Caches are bought with the currency of `reset_id` (Bloom pays Seeds, Nucleus pays Core Shards).
## Cost of the next pull = base_cost x growth ^ (pulls already made since that reset), so the first pull of each reset is
## the cheapest. `cap_per_reset` pulls are allowed per reset, and the count clears when the reset is done again.

@export var id: StringName
@export var display_name: String
## The zone reset whose currency pays for this cache, and whose use unlocks it (it needs one use to be affordable).
@export var reset_id: StringName
@export var base_cost: float = 40.0
@export var growth: float = 1.5
@export var cap_per_reset: int = 5
## Lowest rarity rank that can roll. 2 is Rare, so Common and Uncommon never come out of a cache.
@export var min_rank: int = 2
## Which pixel-art palette the cache is drawn in. "meadow" or "quarry".
@export var palette: StringName = &"meadow"
@export_multiline var blurb: String = ""
