class_name SaveCodec
extends RefCounted
## Pure save encode/decode, migration, and file IO with .bak fallback. Never throws.

const CURRENT_VERSION: int = 3


static func encode(sim: Sim, now_unix: float) -> String:
	return JSON.stringify({"version": CURRENT_VERSION, "saved_at": now_unix, "game": sim.to_dict()})


## Returns {} when the text is not a usable save.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if not d.has("version") or not (d["version"] is float or d["version"] is int):
		return {}
	d["version"] = int(d["version"])
	if int(d["version"]) > CURRENT_VERSION:
		return {}  # written by a newer build; do not guess
	while int(d["version"]) < CURRENT_VERSION:
		d = _migrate_step(d)
	if not (d.get("game") is Dictionary):
		return {}
	return d


## One step from version N to N+1. Add a branch per new version.
static func _migrate_step(d: Dictionary) -> Dictionary:
	match int(d["version"]):
		1:
			# v2 adds pad mastery. Older saves start every pad at level 0.
			if d.get("game") is Dictionary and not (d["game"] as Dictionary).has("mastery"):
				(d["game"] as Dictionary)["mastery"] = {}
			d["version"] = 2
		2:
			# v3 adds the calendar. Older saves start on the first morning of Spring, Year 1.
			if d.get("game") is Dictionary and not (d["game"] as Dictionary).has("calendar"):
				(d["game"] as Dictionary)["calendar"] = {}
			d["version"] = 3
		_:
			d["version"] = int(d["version"]) + 1
	return d


static func write_file(path: String, text: String) -> bool:
	if FileAccess.file_exists(path):
		var old: String = FileAccess.get_file_as_string(path)
		var bak: FileAccess = FileAccess.open(path + ".bak", FileAccess.WRITE)
		if bak != null and not old.is_empty() and not decode(old).is_empty():
			bak.store_string(old)  # only back up a save that is itself valid
			bak.close()
	# Write a temp file and rename it over the save, so a crash mid-write never leaves a half file.
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Main file, then backup, then {} (caller starts a new game).
static func read_with_fallback(path: String) -> Dictionary:
	for p: String in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var d: Dictionary = decode(FileAccess.get_file_as_string(p))
			if not d.is_empty():
				return d
	return {}


## What a decoded save holds, for the slot list. {exists: false} for an empty dict.
static func summary(data: Dictionary) -> Dictionary:
	if data.is_empty() or not (data.get("game") is Dictionary):
		return {"exists": false, "rebirths": 0, "play_seconds": 0.0, "presses": 0, "saved_at": 0.0}
	var g: Dictionary = data["game"]
	return {
		"exists": true,
		"rebirths": int(g.get("rebirth_count", 0)),
		"play_seconds": float(g.get("play_seconds", 0.0)),
		"presses": int(g.get("press_count", 0)),
		"saved_at": float(data.get("saved_at", 0.0)),
	}
