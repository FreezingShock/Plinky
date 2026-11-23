extends SceneTree
## godot --headless --path . --script tests/run.gd   (run `godot --headless --path . --import` once first
## so class_name scripts are registered). Exit code 0 = pass.

var checks: int = 0
var failures: int = 0
var _context: String = ""

const SUITES: Array[String] = [
	"res://tests/test_bignum.gd",
	"res://tests/test_format.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_save.gd",
	"res://tests/test_relics.gd",
	"res://tests/test_relight.gd",
	"res://tests/test_boot.gd",
	"res://tests/test_version.gd",
	"res://tests/test_life.gd",
	"res://tests/test_world_life.gd",
	"res://tests/test_sky.gd",
	"res://tests/test_lighting.gd",
	"res://tests/test_walk.gd",
	"res://tests/test_pad_input.gd",
	"res://tests/test_pad_plate.gd",
	"res://tests/test_focus_rows.gd",
	"res://tests/test_zone2.gd",
	"res://tests/test_quarry_ladder.gd",
	"res://tests/test_tiers.gd",
	"res://tests/test_onboarding.gd",
	"res://tests/test_roll.gd",
	"res://tests/test_feedback.gd",
	"res://tests/test_sites.gd",
	"res://tests/test_perf.gd",
	"res://tests/test_settings.gd",
	"res://tests/test_access.gd",
	"res://tests/test_dev_commands.gd",
	"res://tests/test_upgrades.gd",
	"res://tests/test_rebirth_points.gd",
	"res://tests/test_bloom.gd",
	"res://tests/test_script_loads.gd",
	"res://tests/test_window.gd",
	"res://tests/test_switch_queue.gd",
	"res://tests/test_window_place.gd",
	"res://tests/test_camera_polish.gd",
	"res://tests/test_walker_motion.gd",
	"res://tests/test_larkmoor.gd",
	"res://tests/test_quarry.gd",
	"res://tests/test_hud_click.gd",
	"res://tests/test_zone_menu.gd",
	"res://tests/test_hud_layout.gd",
	"res://tests/test_stat_index.gd",
	"res://tests/test_index_panel.gd",
	"res://tests/test_stat_sources.gd",
	"res://tests/test_tooltips.gd",
	"res://tests/test_mastery.gd",
	"res://tests/test_expand_chip.gd",
	"res://tests/test_menus.gd",
	"res://tests/test_calendar.gd",
	"res://tests/test_gallery.gd",
	"res://tests/test_history.gd",
	"res://tests/test_title.gd",
	"res://tests/test_title_scene.gd",
	"res://tests/test_world_anchor.gd",
	"res://tests/test_press_popups.gd",
	"res://tests/test_ambient.gd",
]


func _init() -> void:
	for path in SUITES:
		_context = path.get_file()
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			ok(false, "suite failed to load or compile")  # a broken suite must not pass silently
			continue
		var suite: RefCounted = script.new()
		suite.run(self)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL [%s] %s" % [_context, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	ok(actual == expected, "%s (got %s, expected %s)" % [msg, str(actual), str(expected)])


func near(actual: float, expected: float, rel: float, msg: String) -> void:
	var tol: float = maxf(absf(expected) * rel, 1e-9)
	ok(absf(actual - expected) <= tol, "%s (got %s, expected %s)" % [msg, str(actual), str(expected)])


## A fresh Sim with real content loaded.
func make_sim() -> Sim:
	var sim := Sim.new()
	ok(ContentLoader.load_into(sim), "content loads and validates")
	sim.new_game()
	return sim
