class_name SaveSlots
extends RefCounted
## Pure save-slot file helpers: which file a slot uses, what a slot holds, and removing one. The Save autoload owns
## the active slot and the loading; this is what the title screen's Saves list reads. Slot 1 is the original
## user://save.json, so saves from before slots existed are slot 1.

const SLOT_COUNT: int = 3
const SLOT_FILE: String = "user://slot.txt"
const BASE_PATH: String = "user://save.json"


## File for a slot. Slot 1 keeps the original name.
static func path_for(n: int) -> String:
	return BASE_PATH if n <= 1 else "user://save_%d.json" % n


## The slot used last, from user://slot.txt (1 when missing or out of range).
static func read_active_slot() -> int:
	if not FileAccess.file_exists(SLOT_FILE):
		return 1
	return clampi(FileAccess.get_file_as_string(SLOT_FILE).strip_edges().to_int(), 1, SLOT_COUNT)


## What a slot holds, for the Saves list: {exists, rebirths, play_seconds, presses, saved_at}.
static func slot_summary(n: int) -> Dictionary:
	return SaveCodec.summary(SaveCodec.read_with_fallback(path_for(n)))


## True when any slot holds a usable save.
static func any_save() -> bool:
	for n in range(1, SLOT_COUNT + 1):
		if bool(slot_summary(n)["exists"]):
			return true
	return false


## First slot with no save, or 0 when all are full.
static func first_empty_slot() -> int:
	for n in range(1, SLOT_COUNT + 1):
		if not bool(slot_summary(n)["exists"]):
			return n
	return 0


## The slot Continue should load: the active one if it holds a save, else the most recently saved slot, else 0.
static func continue_slot() -> int:
	var active: int = read_active_slot()
	if bool(slot_summary(active)["exists"]):
		return active
	var best: int = 0
	var best_at: float = -1.0
	for n in range(1, SLOT_COUNT + 1):
		var s: Dictionary = slot_summary(n)
		if bool(s["exists"]) and float(s["saved_at"]) > best_at:
			best = n
			best_at = float(s["saved_at"])
	return best


## Remove a slot's files (the save, its backup and any half-written temp file).
static func delete_files(n: int) -> void:
	var base: String = ProjectSettings.globalize_path(path_for(n))
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(base + suffix):
			DirAccess.remove_absolute(base + suffix)


## Remember the active slot for the next launch.
static func write_active_slot(n: int) -> void:
	var f: FileAccess = FileAccess.open(SLOT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(str(clampi(n, 1, SLOT_COUNT)))
		f.close()
