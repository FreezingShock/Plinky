class_name RelicConfig
extends Resource
## Global relic tuning. One file: content/relics/_config.tres.

## Equip slots at the start of a run.
@export var base_slots: int = 3
## Rebirth counts that each unlock one more slot. Length of this list is the number of extra slots.
@export var slot_unlock_rebirths: Array[int] = [5, 20]
## Base chance a press drops a relic, before Luck.
@export var base_drop_chance: float = 0.02
## A press only rolls for a drop if at least this many seconds passed since the last roll.
## Hold-to-press can buy many times a second; this keeps drops tied to play time, not click speed.
@export var roll_interval: float = 1.0
## Guaranteed drop once this many play seconds pass with no drop (bad-luck protection).
@export var pity_seconds: float = 150.0
## The very first relic is guaranteed by this play second, so the system shows itself early.
@export var first_drop_seconds: float = 60.0
## Added drop chance per Luck level (SPEC: +5% relic drop chance, treated as relative).
@export var luck_per_level: float = 0.05

func slots_for(rebirths: int) -> int:
	var n: int = base_slots
	for r in slot_unlock_rebirths:
		if rebirths >= r:
			n += 1
	return n

func drop_chance(luck_level: int) -> float:
	return base_drop_chance * (1.0 + luck_per_level * luck_level)

## Drops of this rarity rank or higher get a toast and a pad flash. 3 = Epic.
@export var flash_min_rank: int = 3

func is_flashy(def: RelicDef) -> bool:
	return def.rarity.rank >= flash_min_rank
