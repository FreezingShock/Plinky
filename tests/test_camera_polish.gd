extends RefCounted
## Camera polish: look-ahead, drift and the Reduce motion switch.

func run(t: Object) -> void:
	var reach: float = WorldCamera.LOOK_AHEAD
	t.eq(WorldCamera.look_ahead_goal(Vector2(2, 0), 0.016, true, reach), Vector2(reach, 0), "lean along the walk direction")
	t.eq(WorldCamera.look_ahead_goal(Vector2(2, 0), 0.016, false, reach), Vector2.ZERO, "no lean when standing")
	t.eq(WorldCamera.look_ahead_goal(Vector2.ZERO, 0.016, true, reach), Vector2.ZERO, "no lean without a step")
	# Lean eases up to its reach without overshooting, and back to zero within 2 s of stopping.
	var lean: Vector2 = Vector2.ZERO
	var peak: float = 0.0
	for i in range(0, 180):
		lean = WorldCamera.lean_step(lean, Vector2(reach, 0), 1.0 / 60.0)
		peak = maxf(peak, lean.x)
	t.ok(peak <= reach + 0.001, "lean never overshoots its reach")
	for i in range(0, 120):
		lean = WorldCamera.lean_step(lean, Vector2.ZERO, 1.0 / 60.0)
	t.ok(lean.length() < 0.5, "lean is back to zero within 2 s of stopping")
	t.eq(WorldCamera.drift_offset(5.0, 0.0), Vector2.ZERO, "drift is zero before it fades in")
	var worst: float = 0.0
	for i in range(0, 600):
		var d: Vector2 = WorldCamera.drift_offset(float(i), 1.0)
		worst = maxf(worst, maxf(absf(d.x), absf(d.y)))
	t.ok(worst <= WorldCamera.DRIFT_AMPLITUDE.x + 0.001, "drift stays within its amplitude")
	t.ok(WorldCamera.LOOK_AHEAD <= 16.0 and WorldCamera.PUNCH_TEXELS <= 3.0, "motion constants stay subtle")
	t.ok(not SettingsRegistry.find(&"calm_camera").is_empty(), "Calm camera is in the Access tab")
	t.ok(not WorldCamera.calm, "calm camera defaults off")

	# Gate arch under the clock chip: the view aims up just enough to clear it, and the walker stays on screen.
	var view: Vector2 = Vector2(640.0, 360.0)
	var chip: Rect2 = Rect2(318.0, 4.0, 82.0, 26.0)
	var arch: Array[Rect2] = [Rect2(294.0, 31.2, 72.0, 68.0)]   # the meadow gate's HIT rect at (330, 93.2)
	var c2: Vector2 = WorldCamera.clear_hud_center(Vector2(330.0, 123.0), 2, view, chip, arch, 129.0)
	t.near(c2.x, 330.0, 0.001, "clearing the chip never moves the view sideways")
	t.near(c2.y, 103.2, 0.01, "at 2x the arch is lifted to just under the chip")
	var top2: float = view.y * 0.5 + (arch[0].position.y - c2.y) * 2.0
	t.ok(top2 >= chip.end.y + WorldCamera.HUD_CLEAR - 0.01, "the arch top clears the chip at 2x")
	var c4: Vector2 = WorldCamera.clear_hud_center(Vector2(330.0, 123.0), 4, view, chip, arch, 129.0)
	t.near(c4.y, 93.0, 0.01, "at 4x the walker outranks the arch: the view stops where the walker stays on screen")
	t.ok(view.y * 0.5 + (129.0 - c4.y) * 4.0 <= view.y - WorldCamera.WALKER_EDGE + 0.01, "the walker stays inside the bottom edge")
	var far: Array[Rect2] = [Rect2(0.0, 31.2, 72.0, 68.0)]
	t.eq(WorldCamera.clear_hud_center(Vector2(330.0, 123.0), 2, view, chip, far, 129.0), Vector2(330.0, 123.0), "no shift when the arch is off the chip")
	t.eq(WorldCamera.clear_hud_center(Vector2(330.0, 123.0), 2, view, Rect2(), arch, 129.0), Vector2(330.0, 123.0), "no shift without a chip")

	# Scripts this change touches must compile (a parse error here would otherwise only show when the game starts).
	for path: String in ["res://ui/display_panel.gd", "res://ui/display_settings.gd", "res://render/world_camera.gd"]:
		var sc: GDScript = load(path) as GDScript
		t.ok(sc != null and sc.can_instantiate(), "%s compiles" % path)
