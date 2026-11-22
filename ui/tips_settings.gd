class_name TipsSettings
extends RefCounted
## Whether tips are on. Kept in its own file so it survives a new game, and a player who skipped
## the tutorial is not taught again. Per-save progress (seen tips, unlocked systems) lives in the save.

const PATH: String = "user://tips.cfg"
const SECTION: String = "tips"

static var enabled: bool = true
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		enabled = bool(cfg.get_value(SECTION, "enabled", true))


static func set_enabled(on: bool) -> void:
	enabled = on
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "enabled", on)
	cfg.save(PATH)
