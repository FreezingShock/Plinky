extends RefCounted
## The flower-field glow (world/flower_glow.gd): flowers of one statistic that stand close form one field, far fields are
## separate, each field gets a core layer and a spill layer, and the night level only moves the alpha.


func run(t: Object) -> void:
	# Two dewdrop fields far apart, and one clover flower on its own: three fields, each with a core and a spill layer.
	var flowers: Array = [[100, 100, 0, 1], [110, 104, 0, 2], [120, 98, 0, 3], [400, 300, 0, 0], [405, 310, 0, 1], [700, 500, 1, 2]]
	var glow := FlowerGlow.new()
	glow.setup(flowers)
	glow.finish()   # the bakes run on worker threads; finish() waits for them
	t.eq(glow.field_count(), 6 if FlowerGlow.SPILL_RADIUS > 0.0 else 3, "each field is one core layer, plus one spill layer when the spill is on")
	glow.set_night(0.0)
	t.eq(glow.modulate.a, FlowerGlow.DAY_ALPHA, "by day the glow sits at its day strength")
	glow.set_night(1.0)
	t.ok(glow.modulate.a > 0.0, "the glow is on at night")
	t.ok(glow.modulate.a <= 1.0, "the glow never passes full strength")
	# Winter nights are calmer: at full night the winter glow stays under NIGHT_ALPHA x WINTER_SCALE, while other seasons
	# keep the full NIGHT_ALPHA (the breath only dims, so these bounds hold at any moment).
	glow.set_winter(true)
	glow.set_night(1.0)
	t.ok(glow.modulate.a <= FlowerGlow.NIGHT_ALPHA * FlowerGlow.WINTER_SCALE + 0.001, "a winter night is calmer than the other seasons")
	glow.set_winter(false)
	t.ok(glow.modulate.a > FlowerGlow.NIGHT_ALPHA * FlowerGlow.WINTER_SCALE + 0.001, "a summer night keeps the full glow")
	glow.free()
	# the glow is not neon: every statistic's glow hue sits at or under NEON_SAT saturation, and keeps its own hue
	for i in GardenArt.STATS.size():
		var tint: Color = FlowerGlow._tint(i)
		t.ok(tint.s <= FlowerGlow.NEON_SAT + 0.001, "%s glow is softened to %.2f saturation" % [GardenArt.STATS[i], FlowerGlow.NEON_SAT])
