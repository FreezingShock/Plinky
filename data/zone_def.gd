class_name ZoneDef
extends Resource

@export var id: StringName
@export var display_name: String
## Lowest order is the starting zone.
@export var order: int = 0
@export var gate_stat: StringName = &""
@export var gate_threshold: float = 0.0
@export var next_zone: StringName = &""
@export var base_cash_per_second: float = 0.25
## Base presses per second while standing on a pad.
@export var press_rate: float = 0.5
## Palette name for the render thread (art-bible.md).
@export var palette_id: StringName = &""
## Button ids in the order of the zone scene's pad anchors (Pad0, Pad1, ...).
@export var pad_buttons: PackedStringArray = PackedStringArray()
