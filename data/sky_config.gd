class_name SkyConfig
extends Resource
## Day/night cycle and weather tunables. Single file: content/config/sky.tres.
## These are look and pacing values for the meadow sky, not economy numbers.

## Real seconds for one full day (midnight to midnight).
@export var day_seconds: float = 720.0
## Share of the day the sun is up. 0.5 is an even split; 0.6 is three minutes of day and two of night on a five minute day.
@export var daylight_fraction: float = 0.5
## Where in the day a new session starts: 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset.
@export var start_phase: float = 0.32
## How dark midnight gets, 0..1. Density of the dithered shade layer, so 1.0 would shade every texel.
@export var night_strength: float = 0.8
## How strong the warm sunrise and sunset band is, 0..1.
@export var dusk_strength: float = 0.4

## Rain comes from two slow sine waves added together. Rain falls while the sum is above the threshold.
@export var rain_period_a: float = 173.0
@export var rain_period_b: float = 271.0
@export var rain_phase_a: float = 4.0
@export var rain_phase_b: float = 0.5
@export var rain_threshold: float = 0.55
## Cap on rain intensity, 0..1. Keeps it light.
@export var rain_max: float = 0.6
## Rain drops at full intensity over the 860x500 sky box.
@export var rain_drops: int = 900

## Wind. Calm is the steady breeze, gusts ride above it, rain adds a little.
@export var wind_calm: float = 0.2
@export var wind_rain_boost: float = 0.3
@export var gust_period_a: float = 23.0
@export var gust_period_b: float = 37.0
## Longest lean of a treetop at full wind, in texels.
@export var sway_max_texels: float = 3.0

@export_group("Colour grading")
## Multiply tint by time of day, sampled along a 0..1 day ramp (0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset).
@export var grade_tint: Gradient
## How many texels of the grade are tinted (Bayer density) by time of day. Same ramp.
@export var grade_amount: Gradient
## Haze and mist colour by time of day.
@export var haze_color: Gradient
## God ray colour by time of day.
@export var ray_color: Gradient

@export_group("Golden light")
## How high the sun gets before the golden look is down to its floor (elevation 0..1), and how much of it is kept at noon.
@export var golden_reach: float = 0.95
@export var golden_floor: float = 0.35
## Full-frame saturation and contrast added at full golden light (light_grade.gdshader), and the share kept at night.
@export var golden_sat: float = 0.16
@export var golden_contrast: float = 0.1
@export var night_sat: float = 0.1
## High sun (elevation above about 0.7): exposure drop, extra contrast and saturation, so noon is not bleached.
@export var noon_exposure: float = 0.12
@export var noon_contrast: float = 0.16
@export var noon_sat: float = 0.1

@export_group("Shadows")
## Cast shadow length in object heights at noon, with the sun low, and under the moon.
@export var shadow_len_noon: float = 0.22
@export var shadow_len_low: float = 1.05
@export var shadow_len_moon: float = 0.45
## Darkness of the moon shadow, 0..1 (sun shadows are always full).
@export var shadow_moon: float = 0.35
## Dither density at the foot of a shadow and at its tip (soft edge that thins with distance).
@export var shadow_density_foot: float = 0.85
@export var shadow_density_tip: float = 0.25

@export_group("Light pools and rim")
## Pool radius and strength multipliers for each light kind.
@export var pool_shrine_radius: float = 34.0
@export var pool_gate_radius: float = 26.0
@export var pool_walker_radius: float = 22.0
@export var pool_pad_radius: float = 16.0
## How much the light pools clear of night shade, 0..1.
@export var pool_strength: float = 0.9
## 1 texel edge light on the sun side of trees, bushes and rocks, 0..1.
@export var rim_strength: float = 0.85

## Night shade scale, 0..1 (full night = 0.8 reaches the solid tint). Kept apart from night_strength so the model stays smooth.
@export var night_shade: float = 0.8

@export_group("Atmosphere")
## Vignette: how much of the frame edge is darkened, 0..1 (0 = off).
@export var vignette_strength: float = 0.35
## Ground relight (ground_light.gdshader): N.L strength, terrain cast shadows, occlusion, far fog. 0 = baked look.
@export var ground_relight: float = 2.2
@export var ground_shadow: float = 1.2
@export var ground_ao: float = 0.5
@export var ground_fog: float = 0.45
## Full-frame light pass (light_grade.gdshader): sun-side lift and away-side shade across the whole frame, 0..1.
@export var light_side: float = 0.6
## Highlight-warm / shadow-cool split by luminance, 0..1.
@export var light_split: float = 0.3
## How much brighter a lit texel gets, 0..1.
@export var light_lift: float = 0.06
## Drifting fog over the land (ground_fog.gdshader), 0..1. Scaled by the mist curve: thickest at dawn and dusk and in rain.
@export var fog_ground: float = 0.4
## Share of the camera movement the far backdrop (sky and mountains) follows, 0 = fixed to the ground.
@export var parallax_far: float = 0.1
## Horizon haze density over the far mountains, 0..1.
@export var haze_strength: float = 0.6
## Drifting mist over the water, 0..1.
@export var mist_strength: float = 0.5
## God rays at dawn and dusk, 0..1.
@export var ray_strength: float = 0.5
## Seconds for mist to drift across the view.
@export var mist_drift_seconds: float = 90.0

@export_group("Ember Quarry light")
## Overall lava glow over the quarry (quarry_glow shader). Each source is scaled by its own strength below.
@export var lava_glow: float = 0.4
## Extra glow at full night, as a share of lava_glow. The glow rises when the sky goes dark.
@export var lava_night_boost: float = 1.0
## Falloff radius in texels: a lava pool (also its light pool in the shade), a lava seam tile, a vent, a brazier, a lamp.
@export var lava_pool_radius: float = 60.0
@export var lava_tile_radius: float = 22.0
@export var vent_radius: float = 26.0
@export var brazier_radius: float = 30.0
@export var lamp_radius: float = 22.0
## Strength per source kind (lava pools are 1.0, seam tiles 0.5).
@export var vent_glow: float = 0.45
@export var brazier_glow: float = 0.9
@export var lamp_glow: float = 0.7
## How far each kind dips when it flickers, 0..1. All zero under Reduce Motion or Reduce Flashing.
@export var flicker_lava: float = 0.1
@export var flicker_vent: float = 0.18
@export var flicker_brazier: float = 0.35
@export var flicker_lamp: float = 0.25
## Quarry haze density, 0..1 (quarry_haze shader).
@export var quarry_haze: float = 0.3
## Light shaft strength from the top of the quarry, 0..1.
@export var shaft_strength: float = 0.12
## Heat shimmer over the lava, in screen texels at full heat.
@export var shimmer_amount: float = 1.0
