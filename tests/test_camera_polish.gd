extends RefCounted
## Camera polish: look-ahead, drift and the Reduce motion switch.

func run(t: Object) -> void:
	var reach: float = WorldCamera.LOOK_AHEAD
	t.eq(WorldCamera.look_ahead_goal(Vector2(2, 0), 0.016, true, reach), Vector2(reach, 0), "lean along the walk direction")
	t.eq(WorldCamera.look_ahead_goal(Vector2(2, 0), 0.016, false, reach), Vector2.ZERO, "no lean when standing")
	t.eq(WorldCamera.look_ahead_goal(Vector2.ZERO, 0.016, true, reach), Vector2.ZERO, "no lean without a step")
	t.eq(WorldCamera.drift_offset(5.0, 0.0), Vector2.ZERO, "drift is zero before it fades in")
	var worst: float = 0.0
	for i in range(0, 600):
		var d: Vector2 = WorldCamera.drift_offset(float(i), 1.0)
		worst = maxf(worst, maxf(absf(d.x), absf(d.y)))
	t.ok(worst <= WorldCamera.DRIFT_AMPLITUDE.x + 0.001, "drift stays within its amplitude")
	t.ok(WorldCamera.LOOK_AHEAD <= 16.0 and WorldCamera.PUNCH_TEXELS <= 3.0, "motion constants stay subtle")
	var was: bool = DisplaySettings.reduce_motion
	DisplaySettings.reduce_motion = true
	DisplaySettings._push_motion()
	t.ok(FxConfig.reduce_shake and MeadowLife.reduce_motion, "reduce motion switches shake and meadow life too")
	DisplaySettings.reduce_motion = was
	DisplaySettings._push_motion()

	# Scripts this change touches must compile (a parse error here would otherwise only show when the game starts).
	for path: String in ["res://ui/display_panel.gd", "res://ui/display_settings.gd", "res://render/world_camera.gd"]:
		var sc: GDScript = load(path) as GDScript
		t.ok(sc != null and sc.can_instantiate(), "%s compiles" % path)
	# The settings panel builds, Reduce motion row included.
	var panel: DisplayPanel = DisplayPanel.new()
	panel.bind(t.root)
	t.ok(panel._motion_btn != null, "settings panel builds with a Reduce motion row")
	panel.free()
