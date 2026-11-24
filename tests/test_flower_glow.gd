extends RefCounted
## The flower-field glow (world/flower_glow.gd): flowers of one statistic that stand close form one field, far fields are
## separate, each field gets a core layer and a spill layer, and the night level only moves the alpha.


func run(t: Object) -> void:
	# Two dewdrop fields far apart, and one clover flower on its own: three fields, each with a core and a spill layer.
	var flowers: Array = [[100, 100, 0, 1], [110, 104, 0, 2], [120, 98, 0, 3], [400, 300, 0, 0], [405, 310, 0, 1], [700, 500, 1, 2]]
	var glow := FlowerGlow.new()
	glow.setup(flowers)
	t.eq(glow.field_count(), 6 if FlowerGlow.SPILL_RADIUS > 0.0 else 3, "each field is one core layer, plus one spill layer when the spill is on")
	glow.set_night(0.0)
	t.eq(glow.modulate.a, FlowerGlow.DAY_ALPHA, "by day the glow sits at its day strength")
	glow.set_night(1.0)
	t.ok(glow.modulate.a > 0.0, "the glow is on at night")
	t.ok(glow.modulate.a <= 1.0, "the glow never passes full strength")
	glow.free()
