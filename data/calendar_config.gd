class_name CalendarConfig
extends Resource
## Calendar and season look. Single file: content/config/calendar.tres. Real seconds per in-game day live in
## content/config/sky.tres (day_seconds), so there is one clock. Arrays are indexed by season: 0 spring,
## 1 summer, 2 autumn, 3 winter. These are look and pacing values, not economy numbers.

@export var days_per_month: int = 5
@export var months_per_season: int = 2
## Where a new game starts, in days since Day 1 00:00. 0.3 is 07:12 on the first morning.
@export var start_elapsed_days: float = 0.3
## The look crossfades into the next season over the last this-many days of a season.
@export var blend_days: float = 1.0

@export var season_ids: PackedStringArray = PackedStringArray(["spring", "summer", "autumn", "winter"])
@export var season_names: PackedStringArray = PackedStringArray(["Bloomtide", "Sunreach", "Amberfall", "Hushfrost"])
@export var season_blurbs: PackedStringArray = PackedStringArray([])
## Two per season, in order.
@export var month_names: PackedStringArray = PackedStringArray([])
## Accent colour of each season, for the clock and the arrival banner.
@export var season_colors: PackedColorArray = PackedColorArray()

# ---- outdoor look: recolour amounts are dithered per texel, so a blend is a slow scatter, never a pop
## Ground grass: target colour, a second scattered tone, and how much of the green is recoloured (0..1).
@export var ground_col: PackedColorArray = PackedColorArray()
@export var ground_col2: PackedColorArray = PackedColorArray()
@export var ground_amt: PackedFloat32Array = PackedFloat32Array()
## Tree and bush foliage.
@export var prop_col: PackedColorArray = PackedColorArray()
@export var prop_col2: PackedColorArray = PackedColorArray()
@export var prop_amt: PackedFloat32Array = PackedFloat32Array()
## Snow cover, 0..1, on the ground and on props.
@export var ground_snow: PackedFloat32Array = PackedFloat32Array()
@export var prop_snow: PackedFloat32Array = PackedFloat32Array()
## Multiplied into the sky grade tint, and the colour and share the haze moves toward.
@export var grade_tint: PackedColorArray = PackedColorArray()
@export var haze_col: PackedColorArray = PackedColorArray()
@export var haze_mix: PackedFloat32Array = PackedFloat32Array()
## Scales ground fog and mist.
@export var fog_mult: PackedFloat32Array = PackedFloat32Array()
## Particles drawn at full season weight over the sky box: petals, pollen, leaves, snow.
@export var particle_counts: PackedInt32Array = PackedInt32Array([90, 50, 110, 260])
@export var petal_colors: PackedColorArray = PackedColorArray()
## Snow fall speed in texels per second, and the leaf fall speed.
@export var snow_speed: float = 22.0
@export var leaf_speed: float = 17.0
@export var petal_speed: float = 14.0
