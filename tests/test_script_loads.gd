extends RefCounted
## Every game script must parse and load. A script with a parse error loads as null or cannot be instantiated,
## which is how a bad main.gd would otherwise reach the player (the game window just fails to build).

const DIRS: Array[String] = [
	"res://core", "res://data", "res://ui", "res://ui/settings", "res://ui/fx", "res://world",
	"res://render", "res://theme", "res://audio", "res://boot",
]

func run(t: Object) -> void:
	_check(t, "res://main.gd")
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				_check(t, "%s/%s" % [dir, f])
	t.ok(load("res://main.tscn") is PackedScene, "main.tscn loads")


func _check(t: Object, path: String) -> void:
	var s: Resource = load(path)
	t.ok(s is GDScript, "%s loads as a script" % path)
	if s is GDScript:
		t.ok((s as GDScript).can_instantiate(), "%s compiles (can instantiate)" % path)
