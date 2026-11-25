class_name WindmillSails
extends Node
## The Larkmoor windmill's sails, turning. The sails are a sprite of their own (kind windmill_sails, foot at the hub),
## and tools/art/gen_windmill_sails.py pre-renders eight frames of the turn about that hub. This node steps the frames
## on the life clock: the wind sets the pace and a slow gust term makes it swell and ease. Under Reduce Motion the
## sails hold their first frame. The frame rules are static so the tests can check them without a scene.

const KIND: String = "windmill_sails"
const MANIFEST: String = "res://assets/art/zone1b/larkmoor/windmill_sails_sheet.json"
const DIR: String = "res://assets/art/zone1b/larkmoor/"
const BASE_RATE: float = 0.35         # frames per life step in a calm breeze: about 11 seconds for a full turn
const WIND_MIN: float = 0.6           # pace multiplier at no wind
const WIND_MAX: float = 1.4           # pace multiplier at full wind
const GUST_MIN: float = 0.8           # the gust term swings the pace between these two
const GUST_MAX: float = 1.2

var _sprite: Sprite2D
var _frames: int = 1
var _frame_w: int = 1
var _frame_h: int = 1
var _acc: float = 0.0                 # frames turned so far, in frames (not wrapped)
var _last_step: int = -1
var _t: float = 0.0


## Gust term in 0..1 for a life step: two slow waves summed, so the pace does not repeat on a short beat.
static func gust01(step: int) -> float:
	var g: float = 0.5 + 0.3 * sin(float(step) * 0.045) + 0.2 * sin(float(step) * 0.13 + 1.1)
	return clampf(g, 0.0, 1.0)


## Frames to turn during one life step, at this wind (0..1) and this step.
static func rate_at(step: int, wind: float) -> float:
	var pace: float = lerpf(WIND_MIN, WIND_MAX, clampf(wind, 0.0, 1.0))
	var gust: float = lerpf(GUST_MIN, GUST_MAX, gust01(step))
	return BASE_RATE * pace * gust


## The frame to show after `acc` frames have turned. The sheet loops because four arms repeat every 90 degrees.
static func frame_for(acc: float, frames: int, still: bool) -> int:
	if still or frames <= 1:
		return 0
	return posmod(int(floorf(acc)), frames)


## The sheet and its offset, or an empty dictionary if the sheet is not in the build.
static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## Turns `sp` into the animated sails and adds this node as its child, so it frees with the sprite when its chunk
## unloads. `manifest` comes from load_manifest(); the sprite's region shows one frame at a time.
static func attach(sp: Sprite2D, manifest: Dictionary) -> WindmillSails:
	var node := WindmillSails.new()
	node.name = "SailTurn"
	node._sprite = sp
	node._frames = int(manifest.get("frames", 1))
	node._frame_w = int(manifest.get("frame", 1))
	node._frame_h = node._frame_w
	sp.region_enabled = true
	sp.region_rect = Rect2(0.0, 0.0, float(node._frame_w), float(node._frame_h))
	sp.add_child(node)
	return node


func _process(delta: float) -> void:
	_t += delta
	var step: int = int(_t / GraphicsQuality.life_step())
	if step != _last_step:
		var still: bool = MeadowLife.reduce_motion
		if not still and _last_step >= 0:
			_acc += rate_at(step, MeadowLife.wind) * float(step - _last_step)
		_last_step = step
		if is_instance_valid(_sprite):
			var f: int = frame_for(_acc, _frames, still)
			_sprite.region_rect = Rect2(float(f * _frame_w), 0.0, float(_frame_w), float(_frame_h))
