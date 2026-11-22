class_name Palettes
extends RefCounted
## The four 8-colour palettes from art-bible section 3. Index roles are identical in every zone:
## 0 ink, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper.

const MEADOW := &"meadow"
const QUARRY := &"quarry"
const TIDEWATER := &"tidewater"
const IRIS := &"iris"

const DATA: Dictionary = {
	&"meadow": ["14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9"],
	&"quarry": ["1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "b77a7a", "5b3d5c", "f1d9b5"],
	&"tidewater": ["0d1420", "13324a", "1f6378", "46a3a0", "9fd4b5", "f7d37a", "e67e6b", "dfeee8"],
	&"iris": ["0c0a14", "2a1d4a", "5d3f9c", "a68be0", "f5d46b", "f7f3ea", "bfe6ef", "f0a9c2"],
}
const ZONE_MAP: Dictionary = {
	&"zone_1": &"meadow", &"zone1": &"meadow", &"meadow": &"meadow",
	&"zone_2": &"quarry", &"zone2": &"quarry", &"quarry": &"quarry",
	&"zone_3": &"tidewater", &"zone3": &"tidewater",
	&"rebirth": &"iris", &"iris": &"iris",
}
static var _cache: Dictionary = {}

static func colors(id: StringName) -> PackedColorArray:
	var out := PackedColorArray()
	for hex: String in DATA.get(id, DATA[MEADOW]):
		out.append(Color.html("#" + hex))
	return out

## 8x1 texture, nearest-sampled by the post shader.
static func texture(id: StringName) -> ImageTexture:
	if _cache.has(id):
		return _cache[id] as ImageTexture
	var img := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	var cols := colors(id)
	for i in 8:
		img.set_pixel(i, 0, cols[i])
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

static func for_zone(zone_id: StringName) -> StringName:
	return ZONE_MAP.get(zone_id, MEADOW) as StringName
