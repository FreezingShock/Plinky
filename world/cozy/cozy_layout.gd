class_name CozyLayout
extends RefCounted
## The cozy props' manifest (assets/art/zone1/cozy/cozy.json, written by tools/art/place_cozy.py from the sprites
## made by tools/art/gen_cozy.py). Pure data: no nodes and no autoloads, so tests can run it in --script mode.

const MANIFEST: String = "res://assets/art/zone1/cozy/cozy.json"
const DIR: String = "res://assets/art/zone1/cozy/"
const FRAME_W: int = 640
const FRAME_H: int = 360

## Sheets with frames. Each frame is a fixed size, laid side by side in one PNG.
const WHEAT_KIND: String = "cozy_wheat"
const WHEAT_FRAME_W: int = 48
const WHEAT_FRAME_H: int = 16
const WHEAT_FRAMES: int = 8
const WHEEL_KIND: String = "cozy_wheel"
const WHEEL_FRAME_W: int = 18
const WHEEL_FRAME_H: int = 18
const WHEEL_FRAMES: int = 4

## Plain props: a sprite with a cast shadow, plus whatever behaviour CozyProps gives them (swing, flame, smoke, jets, lights).
const STATIC_KINDS: PackedStringArray = [
	"cozy_bench", "cozy_blanket", "cozy_fence", "cozy_signpost", "cozy_stone", "cozy_well",
	"cozy_cottage", "cozy_swing_frame", "cozy_campfire_ring", "cozy_fountain_basin",
]


static func load_manifest(path: String = MANIFEST) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


static func items(manifest: Dictionary) -> Array:
	var out: Array = []
	for v: Variant in manifest.get("items", []) as Array:
		if v is Dictionary:
			out.append(v)
	return out


static func brooks(manifest: Dictionary) -> Array:
	var out: Array = []
	for v: Variant in manifest.get("brooks", []) as Array:
		if v is Dictionary:
			out.append(v)
	return out


static func is_known(kind: String) -> bool:
	return kind == WHEAT_KIND or kind == WHEEL_KIND or STATIC_KINDS.has(kind)


## The footprint of an item in frame texels, as a Rect2.
static func rect_of(item: Dictionary) -> Rect2:
	return Rect2(float(item.get("x", 0)), float(item.get("y", 0)), float(item.get("w", 0)), float(item.get("h", 0)))


## Foot of an item (where it stands on the ground): the y-sort position of its sprite.
static func foot_of(item: Dictionary) -> Vector2:
	var f: Array = item.get("foot", []) as Array
	if f.size() != 2:
		return rect_of(item).get_center()
	return Vector2(float(f[0]), float(f[1]))


static func in_frame(r: Rect2) -> bool:
	return r.position.x >= 0.0 and r.position.y >= 0.0 \
		and r.end.x <= float(FRAME_W) and r.end.y <= float(FRAME_H)
