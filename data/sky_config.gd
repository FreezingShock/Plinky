class_name SkyConfig
extends Resource
## Day/night cycle and weather tunables. Single file: content/config/sky.tres.
## These are look and pacing values for the meadow sky, not economy numbers.

## Real seconds for one full day (midnight to midnight).
@export var day_seconds: float = 720.0
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
@export var rain_drops: int = 3000

## Wind. Calm is the steady breeze, gusts ride above it, rain adds a little.
@export var wind_calm: float = 0.2
@export var wind_rain_boost: float = 0.3
@export var gust_period_a: float = 23.0
@export var gust_period_b: float = 37.0
## Longest lean of a treetop at full wind, in texels.
@export var sway_max_texels: float = 3.0
