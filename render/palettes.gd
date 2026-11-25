class_name Palettes
extends RefCounted
## The four palettes from art-bible section 3: 8 roles per zone, each role a 4-step hue-shifted ramp (32 colours).
## Index roles are identical in every zone: 0 ink, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper.
## Steps: 0 deepest shade, 1 shade, 2 the anchor (DATA, what colors() returns), 3 lit highlight.
## The post shader reads a role and a step: step = light band + 1, so the three light bands draw steps 1 to 3.

const MEADOW := &"meadow"
const QUARRY := &"quarry"
const TIDEWATER := &"tidewater"
const IRIS := &"iris"

## The 8 role anchors per zone (art-bible s.3). colors() returns these; they are step 2 of each ramp.
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
# BEGIN RAMPS
const RAMP: Dictionary = {
	&"meadow": [
		["0f1116", "162e2b", "205345", "457f57", "78a956", "b2bd76", "975834", "bec0a7"],
		["12141a", "1b3631", "286250", "549664", "9bc86a", "dedf8f", "b26b42", "e2e0c6"],
		["14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9"],
		["17151e", "1f402e", "2e7444", "66b061", "ceea79", "ffefa2", "d27b4a", "fff7df"],
	],
	&"quarry": [
		["140d13", "3a1529", "6c1d2d", "a2181f", "b6ad29", "8f5a6b", "422d48", "bcb889"],
		["180f15", "441b2b", "7f2629", "bf3824", "d6b238", "a86d77", "513755", "ded0a4"],
		["1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "b77a7a", "5b3d5c", "f1d9b5"],
		["1c1215", "501e23", "95422a", "e16a25", "fcb33c", "c6877e", "633f5a", "ffe5ba"],
	],
	&"tidewater": [
		["090f19", "0b263a", "114a5e", "2f7e7f", "78a590", "bdc155", "b34a5d", "adbab6"],
		["0b121d", "0f2d44", "18596e", "3c9695", "90c3a8", "e3d46a", "d45d5e", "ccdbd6"],
		["0d1420", "13324a", "1f6378", "46a3a0", "9fd4b5", "f7d37a", "e67e6b", "dfeee8"],
		["0c1f23", "105050", "1a8270", "44b086", "a7e5b0", "ffd774", "f88c69", "eefff3"],
	],
	&"iris": [
		["080710", "1a133a", "3a2a7a", "7566af", "b6bf49", "c1c1b6", "91b2ba", "bb7ea4"],
		["0a0912", "231944", "4d3690", "917cce", "e1d65c", "e3e1d7", "aed3dc", "dd98ba"],
		["0c0a14", "2a1d4a", "5d3f9c", "a68be0", "f5d46b", "f7f3ea", "bfe6ef", "f0a9c2"],
		["110a16", "3f1b50", "893ca8", "d48ff2", "ffd964", "fffbf1", "c8fff4", "ffaebc"],
	],
}
# END RAMPS
# BEGIN GRASS
const GRASS: Dictionary = {
	&"warm": ["7a7f45", "919654", "9ea35f", "aab061"],
	&"cool": ["457b7f", "549196", "5f9ea3", "61aab0"],
}
# END GRASS
const STEPS := 4
static var _cache: Dictionary = {}

static func colors(id: StringName) -> PackedColorArray:
	var out := PackedColorArray()
	for hex: String in DATA.get(id, DATA[MEADOW]):
		out.append(Color.html("#" + hex))
	return out

## The 4 steps of each role, row-major: `ramp_colors(id)[step][role]`.
static func ramp_colors(id: StringName) -> Array:
	var rows: Array = RAMP.get(id, RAMP[MEADOW])
	var out: Array = []
	for row: Array in rows:
		var cols := PackedColorArray()
		for hex: String in row:
			cols.append(Color.html("#" + hex))
		out.append(cols)
	return out

## 8x4 texture (x = role, y = step), nearest-sampled by the post shader.
static func texture(id: StringName) -> ImageTexture:
	if _cache.has(id):
		return _cache[id] as ImageTexture
	var img := Image.create(8, STEPS, false, Image.FORMAT_RGBA8)
	var rows := ramp_colors(id)
	for step in STEPS:
		for role in 8:
			img.set_pixel(role, step, rows[step][role])
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

## Warm and cool grass variants (4 steps, dark to light), for warm and cool grass patches. Generated like RAMP.
static func grass_variant(name: StringName) -> PackedColorArray:
	var out := PackedColorArray()
	for hex: String in GRASS.get(name, GRASS[&"warm"]):
		out.append(Color.html("#" + hex))
	return out

static func for_zone(zone_id: StringName) -> StringName:
	return ZONE_MAP.get(zone_id, MEADOW) as StringName
