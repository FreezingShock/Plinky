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
	"res://tests/test_boot.gd",
	"res://tests/test_life.gd",
	"res://tests/test_sky.gd",
	"res://tests/test_lighting.gd",
	"res://tests/test_walk.gd",
	"res://tests/test_feedback.gd",
	"res://tests/test_sites.gd",
]


func _init() -> void:
	for path in SUITES:
		_context = path.get_file()
		var suite: RefCounted = (load(path) as GDScript).new()
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
