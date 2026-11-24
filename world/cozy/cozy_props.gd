class_name CozyProps
extends RefCounted
## Builds the cozy layer under the meadow's y-sorted prop parent (MeadowScene.spawn_occluders calls spawn). Every item
## comes from assets/art/zone1/cozy/cozy.json. Plain props are sprites with the meadow's rim light and a cast shadow.
## Wheat and the water wheel step through their frames in CozyAnimator, and a swing hangs from its frame and swings.
## A campfire, a cottage's chimney and a fountain get CozyFx effects, and their warm glows are light pools on SkyCycle.
## The brook and the firefly swarms are drawn on the same parent. Positions and sizes are the manifest's, so the
## layout is changed by rerunning tools/art/place_cozy.py, not by editing this file.

## Anchors inside the sprite sheets, in texels of each PNG (see tools/art/gen_cozy.py).
const SWING_SEAT: String = "swing_seat.png"
const SWING_PIVOT: Vector2 = Vector2(6.0, 0.0)       # the seat's rope tops, centre
const SWING_HANG: Vector2 = Vector2(16.0, 3.0)       # where the seat hangs from the frame's top bar
const CAMPFIRE_LOGS: Vector2 = Vector2(10.0, 5.0)    # the logs' centre in campfire_ring.png
const COTTAGE_CHIMNEY: Vector2 = Vector2(28.0, 3.0)  # the chimney's top in cottage.png
const COTTAGE_WINDOWS: Array[Vector2] = [Vector2(11.5, 24.5), Vector2(27.5, 24.5)]
const FOUNTAIN_PILLAR: Vector2 = Vector2(13.5, 2.0)  # the column's top in fountain_basin.png
const WHEAT_RATE: float = 0.5                        # gust frames per life step: a wave a little over a second long
const WHEEL_RATE: float = 0.5                        # spoke frames per life step


static func spawn(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial, anchors: Array,
		manifest: Dictionary = {}) -> void:
	var data: Dictionary = manifest if not manifest.is_empty() else CozyLayout.load_manifest()
	if data.is_empty():
		push_warning("cozy: no manifest at %s" % CozyLayout.MANIFEST)
		return
	var anim := CozyAnimator.new()
	anim.name = "CozyAnimator"
	parent.add_child(anim)
	var cfg: SkyConfig = sky.light_config() if sky != null else null
	var grass: Array = []
	var n: int = 0
	for it: Variant in CozyLayout.items(data):
		var item: Dictionary = it as Dictionary
		var kind: String = str(item.get("kind", ""))
		if not CozyLayout.is_known(kind):
			push_warning("cozy: unknown kind %s" % kind)
			continue
		var tex: Texture2D = load(CozyLayout.DIR + str(item.get("file", ""))) as Texture2D
		if tex == null:
			push_warning("cozy: missing sprite for %s" % kind)
			continue
		var foot: Vector2 = CozyLayout.foot_of(item)
		var origin := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
		var sp := Sprite2D.new()
		sp.name = "Cozy%d_%s" % [n, kind.trim_prefix("cozy_")]
		n += 1
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.position = foot
		sp.offset = origin - foot
		if rim != null:
			sp.material = rim
		parent.add_child(sp)
		if kind == CozyLayout.WHEAT_KIND:
			anim.add_sheet(sp, CozyLayout.WHEAT_FRAMES, CozyLayout.WHEAT_FRAME_W, CozyLayout.WHEAT_FRAME_H,
				int(item.get("phase", 0)), WHEAT_RATE)
			grass.append(foot + Vector2(0.0, -8.0))
			continue
		if kind == CozyLayout.WHEEL_KIND:
			anim.add_sheet(sp, CozyLayout.WHEEL_FRAMES, CozyLayout.WHEEL_FRAME_W, CozyLayout.WHEEL_FRAME_H, 0, WHEEL_RATE)
			continue
		if shadows != null:
			shadows.add_caster(sp, "", Vector2(float(item.get("w", 0)), float(item.get("h", 0))))
		_decorate(kind, sp, origin, foot, anim, sky, cfg, rim, float(item.get("x", 0)))
	var brooks: Array = CozyLayout.brooks(data)
	if not brooks.is_empty():
		var brook: CozyBrook = CozyBrook.make(brooks)
		brook.name = "CozyBrook"
		parent.add_child(brook)
	var water: Array = []
	for a: Variant in anchors:
		if a is Dictionary and str((a as Dictionary).get("kind", "")) == "water":
			water.append(a)
	var swarm: CozySwarm = CozySwarm.make(CozySwarm.centres_for(water, grass))
	swarm.name = "CozySwarm"
	parent.add_child(swarm)


## Extra behaviour for a few kinds. Effects are children of the sprite, so they draw on top of it.
static func _decorate(kind: String, sp: Sprite2D, origin: Vector2, foot: Vector2, anim: CozyAnimator,
		sky: SkyCycle, cfg: SkyConfig, rim: ShaderMaterial, phase_seed: float) -> void:
	match kind:
		"cozy_swing_frame":
			var seat := Sprite2D.new()
			seat.name = "Seat"
			seat.texture = load(CozyLayout.DIR + SWING_SEAT) as Texture2D
			seat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			seat.centered = false
			seat.offset = -SWING_PIVOT
			seat.position = origin + SWING_HANG - foot
			if rim != null:
				seat.material = rim
			sp.add_child(seat)
			anim.add_swing(seat, phase_seed * 0.37)
		"cozy_campfire_ring":
			sp.add_child(CozyFx.make(CozyFx.Mode.FLAME, origin + CAMPFIRE_LOGS - foot))
			if sky != null and cfg != null:
				sky.add_light(origin + CAMPFIRE_LOGS, cfg.pool_shrine_radius * 0.8, 0.9)
		"cozy_cottage":
			sp.add_child(CozyFx.make(CozyFx.Mode.SMOKE, origin + COTTAGE_CHIMNEY - foot))
			if sky != null and cfg != null:
				for w: Vector2 in COTTAGE_WINDOWS:
					sky.add_light(origin + w, cfg.pool_pad_radius * 1.4, 0.55)
		"cozy_fountain_basin":
			sp.add_child(CozyFx.make(CozyFx.Mode.JETS, origin + FOUNTAIN_PILLAR - foot))
		_:
			pass
