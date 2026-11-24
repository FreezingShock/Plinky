class_name FarmProps
extends RefCounted
## The Larkmoor farm district (Thistle Rise): organic patches of wheat that gust and part around the walker, a barn, a
## shed, a scarecrow, hay bales, a cart and crates. The layout comes from assets/art/zone1b/farm/farm.json
## (tools/art/place_farm.py); the props from tools/art/gen_farm.py; the wheat sheets from tools/bake_wheat.gd, drawn by
## WheatClump from each clump's seed. Plain props are sprites at their foot with the meadow's rim light and a cast
## shadow. Wheat clumps are sprites at their foot too, so the walker sorts against them by Y, and FarmWheat animates them.

const MANIFEST: String = "res://assets/art/zone1b/farm/farm.json"
const DIR: String = "res://assets/art/zone1b/farm/"
const FIELD_PREFIX: String = "farm_wheat"   # every wheat clump's kind starts with this
const FIELD_FRAME_W: int = 48                 # default for an item without its own width
const FENCE_PREFIX: String = "farm_fence"     # the fence ring: one sprite for the whole ring, low and open


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## True when a farm item of this kind is a wheat clump (an animated sheet that parts around the walker).
static func is_field(kind: String) -> bool:
	return kind.begins_with(FIELD_PREFIX)


## True when a farm item of this kind casts a drop shadow. Wheat is ground cover and does not, and the fence ring is
## low and open (one sprite over its whole box, so a shadow would cover the field).
static func casts_shadow(kind: String) -> bool:
	return not is_field(kind) and not kind.begins_with(FENCE_PREFIX)


## Adds the farm under `parent`, which must be the y-sorted prop parent. Pass `manifest` to test with other data.
static func spawn(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial,
		manifest: Dictionary = {}) -> void:
	var data: Dictionary = manifest if not manifest.is_empty() else load_manifest()
	if data.is_empty():
		push_warning("farm: no manifest at %s" % MANIFEST)
		return
	var wheat := FarmWheat.new()
	wheat.name = "FarmWheat"
	parent.add_child(wheat)
	var n: int = 0
	for it: Variant in data.get("items", []) as Array:
		var item: Dictionary = it as Dictionary
		var kind: String = str(item.get("kind", ""))
		var tex: Texture2D = load(DIR + str(item.get("file", ""))) as Texture2D
		if tex == null:
			push_warning("farm: missing sprite for %s (run tools/bake_wheat.gd)" % kind)
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
			var w: int = int(item.get("w", FIELD_FRAME_W))
			var h: int = int(item.get("h", FIELD_FRAME_W))
			sp.region_enabled = true
			sp.region_rect = Rect2(0.0, 0.0, float(w), float(h))
			parent.add_child(sp)
			var clump: Dictionary = WheatClump.generate(int(item.get("seed", 0)), w, h, int(item.get("stage", 1)))
			wheat.add_clump(sp, clump, int(item.get("phase", 0)))
			continue
		if rim != null:
			sp.material = rim
		parent.add_child(sp)
		if shadows != null and casts_shadow(kind):
			shadows.add_caster(sp, "", Vector2(float(item.get("w", 0)), float(item.get("h", 0))))
	var channels: Array = data.get("brooks", []) as Array
	if not channels.is_empty():
		var channel: CozyBrook = CozyBrook.make(channels)
		channel.name = "FarmChannel"
		parent.add_child(channel)
