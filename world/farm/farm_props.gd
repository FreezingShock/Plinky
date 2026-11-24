class_name FarmProps
extends RefCounted
## The Larkmoor farm district (Thistle Rise): two wheat fields that sway in gusts and part around the walker, a barn,
## a shed, a scarecrow, hay bales, a cart, crates and wobbly fence runs. The layout comes from
## assets/art/zone1b/farm/farm.json (tools/art/place_farm.py); the sprites from tools/art/gen_farm.py.
## Plain props are sprites at their foot with the meadow's rim light and a cast shadow. Fields are animated sheets
## on the same life-step clock as the cozy wheat (the gust), and FarmWheat parts them around the walker. The gust
## frames stand still under Reduce Motion, and so does the parting.

const MANIFEST: String = "res://assets/art/zone1b/farm/farm.json"
const DIR: String = "res://assets/art/zone1b/farm/"
const FIELD_PREFIX: String = "farm_field"
const FIELD_FRAMES: int = 8
const FIELD_FRAME_W: int = 96        # default; each field item carries its own frame_w
const FIELD_FRAME_H: int = 44          # the row sheets are 44 texels tall: rows stack from far to near
const FIELD_RATE: float = 0.5        # gust frames per life step, as the cozy wheat


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## True when a farm item of this kind is a wheat field (an animated sheet that parts around the walker).
static func is_field(kind: String) -> bool:
	return kind.begins_with(FIELD_PREFIX)


## True when a farm item of this kind casts a drop shadow. Fields are ground cover and do not.
static func casts_shadow(kind: String) -> bool:
	return not is_field(kind)


## Adds the farm under `parent`, which must be the y-sorted prop parent. Pass `manifest` to test with other data.
static func spawn(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial,
		manifest: Dictionary = {}) -> void:
	var data: Dictionary = manifest if not manifest.is_empty() else load_manifest()
	if data.is_empty():
		push_warning("farm: no manifest at %s" % MANIFEST)
		return
	var anim := CozyAnimator.new()
	anim.name = "FarmAnimator"
	parent.add_child(anim)
	var wheat := FarmWheat.new()
	wheat.name = "FarmWheat"
	parent.add_child(wheat)
	var n: int = 0
	for it: Variant in data.get("items", []) as Array:
		var item: Dictionary = it as Dictionary
		var kind: String = str(item.get("kind", ""))
		var tex: Texture2D = load(DIR + str(item.get("file", ""))) as Texture2D
		if tex == null:
			push_warning("farm: missing sprite for %s" % kind)
			continue
		var fa: Array = item.get("foot", []) as Array
		var foot := Vector2(float(fa[0]), float(fa[1]))
		var origin := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
		var sp := Sprite2D.new()
		sp.name = "Farm%d_%s" % [n, kind.trim_prefix("farm_")]
		n += 1
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.position = foot
		sp.offset = origin - foot
		if is_field(kind):
			var frame_w: int = int(item.get("frame_w", FIELD_FRAME_W))
			var wm: ShaderMaterial = FarmWheat.make_material(frame_w)
			sp.material = wm
			wheat.add_material(wm)
		elif rim != null:
			sp.material = rim
		parent.add_child(sp)
		if is_field(kind):
			anim.add_sheet(sp, FIELD_FRAMES, int(item.get("frame_w", FIELD_FRAME_W)), FIELD_FRAME_H,
					int(item.get("phase", 0)), FIELD_RATE)
			continue
		if shadows != null and casts_shadow(kind):
			shadows.add_caster(sp, "", Vector2(float(item.get("w", 0)), float(item.get("h", 0))))
	var runs: Array = data.get("fences", []) as Array
	if not runs.is_empty():
		var fences: FarmFences = FarmFences.make(runs)
		fences.name = "FarmFences"
		parent.add_child(fences)
	var channels: Array = data.get("brooks", []) as Array
	if not channels.is_empty():
		var channel: CozyBrook = CozyBrook.make(channels)
		channel.name = "FarmChannel"
		parent.add_child(channel)
