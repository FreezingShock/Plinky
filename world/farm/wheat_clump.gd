class_name WheatClump
extends RefCounted
## One clump of wheat: a rounded tuft of stalks, each stalk shaded on its own (a dark root, a golden body, a darker side
## on some, a lit head), over a dithered contact shadow. A clump is generated from a seed, so tools/bake_wheat.gd and the
## game draw the same stalks. Each gust frame bends the tips, and when the walker is near, each stalk leans away from
## it: the lean falls off with distance and grows towards the tip, so the root stays put. Pixels are drawn one by one,
## so the stalks stay crisp at the game's nearest-filtered scale.

const FRAMES: int = 8
const STAGE_SPROUT: int = 0          # young green shoots
const STAGE_GOLD: int = 1            # ripe, golden
const STAGE_BROWN: int = 2           # late, brown and dry

# The meadow palette roles (gen_cozy.py): INK, SHADE, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER.
const C_INK: int = 0
const C_SHADE: int = 1
const C_DEEP: int = 2
const C_BASE: int = 3
const C_LIGHT: int = 4
const C_ACCENT: int = 5
const C_EARTH: int = 6
const C_PAPER: int = 7
const PAL: Array[Color] = [
	Color(20.0 / 255.0, 22.0 / 255.0, 28.0 / 255.0, 1.0),
	Color(31.0 / 255.0, 59.0 / 255.0, 53.0 / 255.0, 1.0),
	Color(47.0 / 255.0, 107.0 / 255.0, 85.0 / 255.0, 1.0),
	Color(95.0 / 255.0, 163.0 / 255.0, 106.0 / 255.0, 1.0),
	Color(183.0 / 255.0, 217.0 / 255.0, 120.0 / 255.0, 1.0),
	Color(242.0 / 255.0, 230.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(194.0 / 255.0, 120.0 / 255.0, 78.0 / 255.0, 1.0),
	Color(246.0 / 255.0, 239.0 / 255.0, 217.0 / 255.0, 1.0),
]
const ROOT_BAND: float = 0.28        # the lowest share of a stalk is its dark root
const HEAD_START: float = 0.80       # the top share of a stalk is its head
const SIDE_MARGIN: float = 5.0      # stalk bases stay this far in from the sheet edge: sway and lean add about 3 texels more
const SIDE_LIGHT: float = 3.0        # softens the sideways direction for stalks right beside the walker
const SILHOUETTE_HALF: float = 9.0   # stalks within this many texels of the walker's column, and in front of him, are cut
const SILHOUETTE_TOP: float = 14.0   # ... so their tips stop this many texels above his feet and his outline stays clear


## A clump of about w x h texels, rooted on a band near its bottom edge. Deterministic for a seed.
static func generate(seed_value: int, w: int, h: int, stage: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx: float = w * 0.5
	var band_y: float = h - 5.0
	var rx: float = w * 0.47 - SIDE_MARGIN
	var ry: float = maxf(h * 0.16, 2.0)
	var count: int = int(w * 2.4) if stage != STAGE_SPROUT else int(w * 1.4)
	var max_h: float = h - 8.0
	var stalks: Array = []
	var tries: int = 0
	while stalks.size() < count and tries < count * 6:
		tries += 1
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf())
		var bx: float = cx + rx * r * cos(a)
		var by: float = band_y + ry * r * sin(a)
		var depth: float = clampf((by - (band_y - ry)) / (2.0 * ry), 0.0, 1.0)   # 0 at the back, 1 at the front
		var tall: float = (0.6 + 0.4 * rng.randf()) * (0.84 + 0.16 * depth)
		if stage == STAGE_SPROUT:
			tall *= 0.45 + 0.25 * rng.randf()
		stalks.append({
			"bx": bx, "by": by,
			"h": max_h * tall,
			"lean": rng.randf_range(-1.4, 1.4),
			"head": stage != STAGE_SPROUT and rng.randf() < 0.85,
			"tone": rng.randi() % 3,
			"side": rng.randf() < 0.5,
			"sway": rng.randf_range(0.6, 1.8),
			"phase": rng.randf() * TAU,
			"part": rng.randf_range(0.75, 1.25),
		})
	stalks.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.by) < float(q.by))
	# Contact shadow: a dithered ellipse under the clump, so it sits on the ground rather than floating.
	var shadow := PackedInt32Array()
	var mass := PackedInt32Array()
	var sx: float = rx * 1.0
	var sy: float = ry * 1.5
	for y: int in range(h):
		for x: int in range(w):
			var fx: float = x + 0.5
			var fy: float = y + 0.5
			var ex: float = (fx - cx) / sx
			var ey: float = (fy - (band_y + 1.0)) / sy
			if ex * ex + ey * ey <= 1.0 and (x + y) % 2 == 0:
				shadow.append(y * w + x)
			# The root mass: a dithered dark body under the stalks, so the clump has thickness, not just spikes.
			var mx: float = (fx - cx) / (rx * 0.92)
			var my: float = (fy - (band_y - ry * 0.2)) / (ry * 1.9 + h * 0.1)
			if mx * mx + my * my <= 1.0 and fy > h * 0.62:
				mass.append(y * w + x)
	return {"w": w, "h": h, "stage": stage, "stalks": stalks, "shadow": shadow, "mass": mass}


## The colours of one stalk at height `t` (0 at the root, 1 at the tip): root, body, head.
static func _role(stage: int, tone: int, t: float, head: bool) -> int:
	if t < ROOT_BAND:
		return C_INK
	if head and t >= HEAD_START:
		if stage == STAGE_SPROUT:
			return C_LIGHT
		return C_EARTH if stage == STAGE_BROWN or tone == 2 else C_ACCENT
	match stage:
		STAGE_SPROUT:
			return C_LIGHT if tone == 2 else C_BASE
		STAGE_BROWN:
			return C_EARTH if tone < 2 else C_INK
		_:
			return C_EARTH if tone == 0 and t < 0.5 else C_ACCENT


## One gust frame of the clump. `walker` is the walker's position in texels of this clump (origin top-left); `push` is
## the lean at the walker's feet, in texels, and `radius` is how far from the walker the lean reaches. Push 0 is the
## plain frame.
static func rasterize(clump: Dictionary, frame: int, walker: Vector2, push: float, radius: float) -> Image:
	var w: int = int(clump.w)
	var h: int = int(clump.h)
	var stage: int = int(clump.stage)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var shadow_px: PackedInt32Array = clump.shadow
	var shade: Color = PAL[C_INK]
	for i: int in shadow_px.size():
		var idx: int = shadow_px[i]
		img.set_pixel(idx % w, floori(float(idx) / float(w)), shade)
	var mass_px: PackedInt32Array = clump.mass
	var root: Color = PAL[C_INK]
	var deep_ink: Color = PAL[C_EARTH]          # a few dry clods in the root mass
	for i: int in mass_px.size():
		var idx: int = mass_px[i]
		var mx: int = idx % w
		var my: int = floori(float(idx) / float(w))
		img.set_pixel(mx, my, deep_ink if (mx + 2 * my) % 7 == 0 else root)
	var turn: float = TAU * float(frame) / float(FRAMES)
	for s: Dictionary in clump.stalks:
		var bx: float = float(s.bx)
		var by: float = float(s.by)
		var length: float = float(s.h)
		if push > 0.0:
			# Stalks in front of the walker, in his column, are cut so their tips stop below his chest: his outline stays
			# clear of wheat tops (they would cover him).
			var ahead: Vector2 = Vector2(bx, by) - walker
			if ahead.y > 1.0 and absf(ahead.x) < SILHOUETTE_HALF:
				length = minf(length, maxf(3.0, ahead.y + SILHOUETTE_TOP))
		var sway: float = float(s.sway) * sin(turn + float(s.phase))
		var tx: float = bx + float(s.lean) + sway
		var ty: float = by - length
		var fall: float = 0.0
		var side: float = 0.0
		if push > 0.0:
			var d: Vector2 = Vector2(bx, by) - walker
			fall = 1.0 - smoothstep(0.0, radius, d.length())
			side = d.x / (absf(d.x) + SIDE_LIGHT)
		var part: float = push * float(s.part)
		var head: bool = bool(s.head)
		var tone: int = int(s.tone)
		var side_shade: bool = bool(s.side)
		var n: int = int(maxf(absf(tx - bx), absf(ty - by))) + 1
		n = maxi(n, int(length))
		for k: int in range(n + 1):
			var t: float = float(k) / float(n)
			var x: float = lerpf(bx, tx, t)
			var y: float = lerpf(by, ty, t)
			if fall > 0.0:
				var lean_t: float = pow(t, 1.5)
				x += side * fall * part * lean_t
				y += fall * part * 0.3 * lean_t
			var ix: int = int(roundf(x))
			var iy: int = int(roundf(y))
			var col: int = _role(stage, tone, t, head)
			_put(img, ix, iy, col)
			if t >= HEAD_START and head:
				_put(img, ix + 1, iy, C_EARTH if stage == STAGE_GOLD and tone < 2 else col)
			elif side_shade and t >= ROOT_BAND and t < HEAD_START and stage != STAGE_SPROUT:
				_put(img, ix + 1, iy, C_EARTH if stage == STAGE_GOLD else C_INK)
	return img


static func _put(img: Image, x: int, y: int, col: int) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, PAL[col])


## The eight gust frames side by side, as one sheet of FRAMES frames each clump.w texels wide and clump.h tall.
static func bake_sheet(clump: Dictionary) -> Image:
	var w: int = int(clump.w)
	var h: int = int(clump.h)
	var sheet := Image.create(w * FRAMES, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for f: int in range(FRAMES):
		var frame: Image = rasterize(clump, f, Vector2.ZERO, 0.0, 0.0)
		sheet.blit_rect(frame, Rect2i(0, 0, w, h), Vector2i(f * w, 0))
	return sheet
