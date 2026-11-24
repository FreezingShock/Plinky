class_name SealedArt
extends RefCounted
## Pixel art for sealed caches, painted in code at 16 by 16 so no texture file has to ship. Each cache is one pouch: a dark
## outline, a lit body that shades toward the bottom right, a gathered neck with a cord, and a wax seal in the zone's accent.
## Colours come from one palette per zone (meadow, quarry). Each picture is built once and then reused.

const SIZE: int = 16
const PALETTES: Dictionary = {
	&"meadow": {"outline": Color("1d3322"), "light": Color("c8f0a0"), "body": Color("7fc46a"), "shade": Color("4f9a4a"),
		"dark": Color("2e5d34"), "seal": Color("f2c94c"), "cord": Color("8a6a3a")},
	&"quarry": {"outline": Color("2a1410"), "light": Color("ffb36b"), "body": Color("d9733a"), "shade": Color("a8402a"),
		"dark": Color("5c2418"), "seal": Color("ffe27a"), "cord": Color("6b5a4a")},
}
static var _cache: Dictionary = {}


## The pouch picture for a zone palette, as a 16 by 16 texture. Show it with NEAREST filtering at an integer scale.
static func texture(palette: StringName) -> Texture2D:
	if _cache.has(palette):
		return _cache[palette] as Texture2D
	var key: StringName = palette if PALETTES.has(palette) else &"meadow"
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_paint(img, PALETTES[key] as Dictionary)
	var tex := ImageTexture.create_from_image(img)
	_cache[palette] = tex
	return tex


static func _inside(x: int, y: int) -> bool:
	var dx: float = (float(x) + 0.5 - 7.5) / 6.5
	var dy: float = (float(y) + 0.5 - 9.5) / 5.5
	return dx * dx + dy * dy <= 1.0


static func _paint(img: Image, p: Dictionary) -> void:
	var outline: Color = p["outline"]
	var light: Color = p["light"]
	var body: Color = p["body"]
	var shade: Color = p["shade"]
	var dark: Color = p["dark"]
	var seal: Color = p["seal"]
	var cord: Color = p["cord"]
	# Body: an ellipse with a one-pixel outline, lit from the top left.
	for y in SIZE:
		for x in SIZE:
			if not _inside(x, y):
				continue
			var edge: bool = not (_inside(x - 1, y) and _inside(x + 1, y) and _inside(x, y - 1) and _inside(x, y + 1))
			var c: Color
			if edge:
				c = outline
			elif x + y < 13:
				c = light
			elif x + y < 18:
				c = body
			elif x + y < 22:
				c = shade
			else:
				c = dark
			img.set_pixel(x, y, c)
	# Gathered neck and cord above the body.
	for x in range(6, 10):
		img.set_pixel(x, 1, cord)
		img.set_pixel(x, 2, cord)
	for x in range(6, 10):
		img.set_pixel(x, 3, outline if x == 6 or x == 9 else cord)
	img.set_pixel(7, 0, outline)
	img.set_pixel(8, 0, outline)
	# Wax seal in the middle of the body.
	for y in range(8, 13):
		for x in range(5, 11):
			var dx: float = float(x) - 7.5
			var dy: float = float(y) - 10.5
			if dx * dx + dy * dy <= 4.5:
				img.set_pixel(x, y, seal)
	img.set_pixel(6, 8, Color(1.0, 1.0, 1.0, 0.85))
	# Two sparkles just outside the pouch.
	img.set_pixel(13, 3, seal)
	img.set_pixel(2, 7, light)
