class_name ZoneDef
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## Palette role (4 to 7) for this zone's name and menu row, so Meadow and Larkmoor read apart on one palette.
@export_range(3, 7) var theme_role: int = 4
## Lowest order is the starting zone.
@export var order: int = 0
@export var gate_stat: StringName = &""
@export var gate_threshold: float = 0.0
@export var next_zone: StringName = &""
## Drawn gate arch (TexelGate): "forge" for the Ember Quarry. Empty = the plain pulsing ring.
@export var gate_art: StringName = &""
## Income per second a passive stat of this zone starts from (before its boosts). The name is from when Cash was the only one.
@export var base_cash_per_second: float = 0.25
## The stat whose size sets the pad glow and the "multiplier" read of this zone (the tier-1 resource of its ladder).
@export var boost_stat: StringName = &""
## The first time the walker arrives here, each stat listed in entry_grants gets (value x the entry_source_stat you hold),
## or just the value when entry_source_stat is empty (a flat starter purse).
## It is how the meadow hands its Starbloom Petals over to the Ember Quarry's own Cash and Multiplier. Latched in the save.
@export var entry_source_stat: StringName = &""
## The stat Rebirth banks into Prestige in this zone. Empty = GameConfig.prestige_source_stat (Clover Leaves in the meadow).
@export var prestige_source_stat: StringName = &""
@export var entry_grants: Dictionary = {}
## Base presses per second while standing on a pad.
@export var press_rate: float = 0.5
## Palette name for the render thread (art-bible.md).
@export var palette_id: StringName = &""
## Button ids in the order of the zone scene's pad anchors (Pad0, Pad1, ...).
@export var pad_buttons: PackedStringArray = PackedStringArray()
## Zone scene (Node2D with Anchors and spawn_occluders). Empty = the meadow scene.
@export_file("*.tscn") var scene_path: String = ""
## Walkable mask for the zone scene (same 840x480 frame as its ground). Empty = the meadow mask.
@export_file("*.png") var walk_mask_path: String = ""
## Heat (see docs/zone2.md). heat_cap 0 means the zone has no Heat.
@export var heat_cap: float = 0.0
@export var heat_charge_per_second: float = 0.0   ## gained per second the walker stands on a vent
@export var heat_decay_per_second: float = 0.0
@export var heat_hot_at: float = 5.0              ## at or above this, presses are Hot
@export var heat_hot_mult: float = 1.0            ## reward multiplier for a Hot press

## Open-air zones get the arrival banner with season and time; indoor or themed ones do not.
@export var outdoor: bool = true
