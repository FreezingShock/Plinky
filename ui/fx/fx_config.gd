class_name FxConfig
## Juice constants from art-bible section 4 and 5. Tune here, nowhere else.
const PRESS_SINK_TEXELS := 2
const HITSTOP_MS := 40
const PARTICLES_MIN := 6
const PARTICLES_MAX := 12
const POPUP_LIFE := 0.8
const POPUP_RISE_TEXELS := 18.0
const COUNTER_TICK_TIME := 0.35
## Rolling counters: time constant of the ease (s), snap distance (relative), and the gain size that earns a float.
const ROLL_TIME := 0.16
const ROLL_SNAP := 0.002
const ROLL_HZ := 30.0
const BIG_GAIN_RATIO := 0.15
const BIG_GAIN_FLASH := 0.35
const SMALL_GAIN_FLASH := 0.12
const SHAKE_DECAY := 6.0
const SHAKE_MAX_TEXELS := 3.0
const FLASH_FRAMES := 3
const ZONE_SHIFT_TIME := 1.5
const MAX_RIPPLES := 8
const SHIMMER_FPS := 10.0
## Palette indices (roles are identical in every zone).
const PAL_INK := 0
const PAL_ACCENT := 5
const PAL_EARTH := 6
const PAL_PAPER := 7
## Set by the settings screen (M4). Respected by every effect below.
static var reduce_flashing := false
static var reduce_shake := false
## Turns off the screen-wide light passes (edge shade, full-frame light grade).
static var reduce_screen_fx := false

## Snap a position to whole texels so FX never sit between world pixels.
static func snap(v: Vector2) -> Vector2:
	return v.round()
