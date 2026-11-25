extends RefCounted
## Palette ramps (render/palettes.gd, art-bible s.3): every zone has 8 roles x 4 steps, the anchor colours are step 2,
## the ramp texture is 8x4 with the same colours, and the lit side of each ramp is brighter than its shade.

func run(t: Object) -> void:
	for id: StringName in [Palettes.MEADOW, Palettes.QUARRY, Palettes.TIDEWATER, Palettes.IRIS]:
		var rows: Array = Palettes.ramp_colors(id)
		t.eq(rows.size(), Palettes.STEPS, "%s has %d ramp steps" % [id, Palettes.STEPS])
		var anchors: PackedColorArray = Palettes.colors(id)
		t.eq(anchors.size(), 8, "%s has 8 role anchors" % id)
		var bad_anchor: int = 0
		var bad_order: int = 0
		for role: int in 8:
			if not (rows[2] as PackedColorArray)[role].is_equal_approx(anchors[role]):
				bad_anchor += 1
			var shade: float = luma((rows[0] as PackedColorArray)[role])
			var lit: float = luma((rows[3] as PackedColorArray)[role])
			if lit < shade:
				bad_order += 1
		t.eq(bad_anchor, 0, "%s: step 2 of every role is its anchor colour" % id)
		t.eq(bad_order, 0, "%s: the lit step is never darker than the deepest shade" % id)
		var tex: ImageTexture = Palettes.texture(id)
		t.eq(tex.get_size(), Vector2(8, Palettes.STEPS), "%s ramp texture is 8x%d" % [id, Palettes.STEPS])
		var img: Image = tex.get_image()
		var mismatch: int = 0
		for step: int in Palettes.STEPS:
			for role: int in 8:
				var got: Color = img.get_pixel(role, step)
				var want: Color = (rows[step] as PackedColorArray)[role]
				if not got.is_equal_approx(want):
					mismatch += 1
		t.eq(mismatch, 0, "%s: texel (role, step) matches the ramp" % id)

static func luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
