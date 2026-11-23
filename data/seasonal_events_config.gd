class_name SeasonalEventsConfig
extends Resource
## One light event per season, driven by the calendar. Single file: content/config/seasonal_events.tres.
## Arrays are indexed by season: 0 spring, 1 summer, 2 autumn, 3 winter. Every multiplier is 1.0 for "no effect".
## Deliberately small: no event changes pace by more than a few percent over a year (docs/decisions.md).

@export var event_names: PackedStringArray = PackedStringArray(["Petal Shower", "Long Light", "Seed Fall", "Frost Pads"])
## One plain line shown in the arrival banner and the clock tooltip.
@export var event_blurbs: PackedStringArray = PackedStringArray([])
## Spring: the golden critter's wait between visits is multiplied by this (lower = more visits).
@export var critter_interval_mult: PackedFloat32Array = PackedFloat32Array([0.7, 1.0, 1.0, 1.0])
## Summer: passive income multiplier, applied only while the sun is up.
@export var day_income_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.08, 1.0, 1.0])
## Autumn: the relic drop roll interval is multiplied by this (lower = more rolls).
@export var relic_roll_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.75, 1.0])
## Winter: momentum decay per second is multiplied by this (lower = momentum lasts longer).
@export var momentum_decay_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 0.5])
