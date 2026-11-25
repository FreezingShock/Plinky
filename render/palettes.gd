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
		["0b0d11", "102523", "164239", "326548", "4d873e", "7d9659", "767822", "919983"],
		["101218", "18322e", "225a4a", "4a895d", "81b65d", "c0cb80", "a38538", "cdcfb4"],
		["14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9"],
		["17161f", "204232", "2e784c", "64b763", "d2f37c", "fff0a0", "d9844a", "fff7de"],
	],
	&"quarry": [
		["100910", "2e0e27", "561132", "810932", "779016", "71445e", "302239", "8c9569"],
		["160e14", "3e162c", "741f30", "af1a21", "c4ba2c", "9a6173", "47314d", "cac793"],
		["1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "b77a7a", "5b3d5c", "f1d9b5"],
		["1d1216", "531e25", "9b4029", "e96923", "ffb43a", "cd8882", "674160", "ffe4b9"],
	],
	&"tidewater": [
		["060c14", "051d2e", "08394a", "206165", "5c8375", "7e993c", "8f335d", "889491"],
		["09101b", "0b283e", "135065", "338889", "81b29b", "cccf5c", "c15064", "bac8c4"],
		["0d1420", "13324a", "1f6378", "46a3a0", "9fd4b5", "f7d37a", "e67e6b", "dfeee8"],
		["0c1d24", "0f4b53", "19867f", "44b794", "acedba", "ffd671", "ff8a69", "edfff4"],
	],
	&"iris": [
		["05050c", "0f0c2e", "231c61", "524c8b", "769831", "96998f", "708c94", "95608d"],
		["080811", "1c153e", "3f2d83", "7e6ebc", "c5ce4e", "cfcfc3", "9cc0c9", "ca88b1"],
		["0c0a14", "2a1d4a", "5d3f9c", "a68be0", "f5d46b", "f7f3ea", "bfe6ef", "f0a9c2"],
		["100a16", "3c1b53", "823caf", "d292fb", "ffd861", "fffbf0", "c7fff9", "ffacbf"],
	],
}
# END RAMPS
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

static func for_zone(zone_id: StringName) -> StringName:
	return ZONE_MAP.get(zone_id, MEADOW) as StringName
