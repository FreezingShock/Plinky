extends RefCounted
## Seasonal butterflies and fireflies (world/meadow_life.gd), the quarry's cinder footsteps and its ember layer.

func _w(a: float, b: float, c: float, d: float) -> Array[float]:
	var w: Array[float] = [a, b, c, d]
	return w


func run(t: Object) -> void:
	var keep_season: Array[float] = MeadowLife.season.duplicate()
	var keep: Array[float] = [MeadowLife.night, MeadowLife.low_sun, MeadowLife.rain]
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 0.0
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	t.near(MeadowLife.butterfly_share(), 1.0, 1e-6, "summer noon: every butterfly is out")
	t.near(MeadowLife.firefly_season_share(), 1.0, 1e-6, "summer: every firefly is out at dusk")
	MeadowLife.season = _w(0.0, 0.0, 1.0, 0.0)
	var autumn: float = MeadowLife.butterfly_share()
	t.ok(autumn > 0.0 and autumn < 0.5, "autumn: only a few butterflies (%.2f)" % autumn)
	MeadowLife.season = _w(0.0, 0.0, 0.0, 1.0)
	t.eq(MeadowLife.butterfly_share(), 0.0, "winter: no butterflies")
	t.eq(MeadowLife.firefly_season_share(), 0.0, "winter: no fireflies")
	MeadowLife.season = _w(0.0, 1.0, 0.0, 0.0)
	MeadowLife.night = 1.0
	t.eq(MeadowLife.butterfly_share(), 0.0, "night: butterflies are asleep")
	MeadowLife.night = 0.0
	MeadowLife.rain = 1.0
	t.eq(MeadowLife.butterfly_share(), 0.0, "heavy rain: butterflies stay down")
	MeadowLife.rain = 0.0
	MeadowLife.season = _w(0.5, 0.5, 0.0, 0.0)
	var mix: float = MeadowLife.butterfly_share()
	t.ok(mix > 0.8 and mix < 1.0, "a spring-summer mix sits between the two (%.2f)" % mix)
	MeadowLife.season = keep_season
	MeadowLife.night = keep[0]
	MeadowLife.low_sun = keep[1]
	MeadowLife.rain = keep[2]

	# Cinder: the quarry floor is loose rock, its pale road is packed dust, pads and gate are wood.
	for i in 4:
		t.ok(ResourceLoader.exists("res://assets/audio/sfx/step_cinder_%d.ogg" % i), "step_cinder_%d exists" % i)
	MeadowSites.use("res://assets/art/zone2/quarry/placements3d.json", "res://assets/art/zone2/quarry/ground.png", Vector2i(100, 60))
	t.eq(MeadowSites.surface_at(Vector2(150.0, 160.0)), MeadowSites.CINDER, "quarry floor is cinder")
	t.eq(MeadowSites.surface_at(Vector2(319.0, 220.0)), MeadowSites.SAND, "the quarry road is packed dust")
	t.eq(MeadowSites.surface_at(Vector2(414.0, 296.0)), MeadowSites.WOOD, "a quarry pad is wood")
	t.eq(MeadowSites.surface_at(Vector2(-500.0, -500.0)), MeadowSites.CINDER, "off the quarry map falls back to cinder")
	MeadowSites.use("", "", MeadowSites.MEADOW_OFFSET)
	t.eq(MeadowSites.surface_at(Vector2(175.0, 175.0)), MeadowSites.GRASS, "back in the meadow the floor is grass again")

	# The quarry scene tells main.gd which ground to look up, and builds the ember layer from its vents.
	var q: Node2D = load("res://world/quarry_scene.tscn").instantiate() as Node2D
	t.ok(String(q.get("ground_path")).contains("zone2"), "the quarry scene names its own ground for surface lookups")
	var anchors := Node2D.new()
	for i in 3:
		var m := Marker2D.new()
		m.name = "Vent%d" % i
		m.position = Vector2(100.0 + 50.0 * float(i), 80.0)
		anchors.add_child(m)
	var emb := LifeEmbers.new()
	emb.setup(anchors)
	t.eq(emb.vents.size(), 3, "the ember layer reads every Vent anchor")
	emb.free()
	anchors.free()
	q.free()
