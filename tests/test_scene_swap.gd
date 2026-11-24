extends RefCounted
## Scene swap suite: the loading line reads label and percent, the zone label names the art, and the reveal shader
## and host load. Run through tests/run.gd.

func run(t: SceneTree) -> void:
	t.eq(BootScreen.status_line("Loading Larkmoor art", 0.62), "Loading Larkmoor art... 62%", "loading line shows label and percent")
	t.eq(BootScreen.status_line("Waking the meadow", 0.0), "Waking the meadow... 0%", "loading line starts at 0%")
	t.eq(BootScreen.status_line("Opening the gate", 1.4), "Opening the gate... 100%", "loading line clamps above 100%")
	t.eq(BootScreen.status_line("Loading Embers art", -0.2), "Loading Embers art... 0%", "loading line clamps below 0%")
	t.eq(BootScreen.zone_task_label("Larkmoor"), "Loading Larkmoor art", "zone task names the zone's art")
	t.ok(not BootScreen.status_line("x", 0.5).contains("…"), "loading line uses ASCII dots (Spleen has no ellipsis)")

	t.ok(load("res://boot/scene_reveal.gdshader") is Shader, "reveal shader loads")
	t.ok(load("res://boot/scene_swap.gd") is GDScript, "scene swap script loads")
	t.ok(SceneSwap.REVEAL_SECONDS > 0.0 and SceneSwap.FADE_SECONDS > 0.0, "reveal and fade have positive durations")
	t.ok(SceneSwap.WARM_FRAMES >= 1, "arriving scene gets at least one warm frame under the cover")
	t.ok(SceneSwap.WARM_MAX_FRAMES >= SceneSwap.WARM_FRAMES, "warm-up cap is at least the minimum")
	t.ok(SceneSwap.SETTLE_RATIO > 0.0 and SceneSwap.SETTLE_RATIO < 1.0, "settle ratio is a fraction")
	t.ok(ResourceLoader.exists(BootScreen.MEADOW_SCENE), "meadow scene exists for the handoff fallback")
	t.ok(BootScreen.HANDOFF_BAR_SPEED > BootScreen.BAR_SPEED, "handoff bar catches up faster than the boot bar")
	t.ok(BootScreen.HANDOFF_MIN_SHOW_SECONDS < BootScreen.MIN_SHOW_SECONDS, "handoff holds the loading screen for less time")
