extends RefCounted
## Every game script that can compile in script mode must load. A script with a parse error loads as null or
## cannot be instantiated. Autoloads do not exist under `--script`, so scripts that name one (main.gd, the walker,
## pads, ...) cannot compile here: they are skipped by name, and the CI "Boot smoke test" step loads main.gd for real.

## Folders and files that depend on no autoload, directly or through another script. Scripts that do
## (main.gd, hud, walker, pads, ...) are covered by the CI "Boot smoke test" step instead.
const DIRS: Array[String] = ["res://core", "res://data", "res://ui/settings", "res://theme"]
const FILES: Array[String] = [
	"res://ui/display_panel.gd", "res://ui/dev_console.gd", "res://ui/ascii_box.gd", "res://ui/relic_style.gd",
	"res://ui/display_settings.gd", "res://ui/fx/pixel_button.gd", "res://ui/tip.gd", "res://ui/tip_text.gd", "res://ui/tip_host.gd",
]

const AUTOLOADS: PackedStringArray = ["GameState", "EventBus", "Save", "Fx", "Juice", "Audio"]

func run(t: Object) -> void:
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				_check(t, "%s/%s" % [dir, f])
	for f in FILES:
		_check(t, f)


func _uses_autoload(path: String) -> bool:
	var src: String = FileAccess.get_file_as_string(path)
	for a in AUTOLOADS:
		var re := RegEx.new()
		re.compile("(^|[^A-Za-z0-9_\"/.])" + a + "\\.")
		if re.search(src) != null:
			return true
	return false


func _check(t: Object, path: String) -> void:
	if _uses_autoload(path):
		return
	var s: Resource = load(path)
	t.ok(s is GDScript, "%s loads as a script" % path)
	if s is GDScript:
		t.ok((s as GDScript).can_instantiate(), "%s compiles (can instantiate)" % path)
