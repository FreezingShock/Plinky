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


## Rows in the settings menu (Gameplay tab). Called once from main.gd after GameState exists.
static func register_rows() -> void:
	SettingsRegistry.register({
		"id": &"tips", "tab": "Gameplay", "label": "Tips", "kind": SettingsRegistry.Kind.TOGGLE,
		"hint": "Tip cards that explain each system as it appears. Off also shows every system at once.",
		"get": Callable(TipsSettings, "_get_tips"),
		"set": Callable(TipsSettings, "_set_tips"),
	})
	SettingsRegistry.register({
		"id": &"replay_tips", "tab": "Gameplay", "label": "Replay tips", "kind": SettingsRegistry.Kind.ACTION,
		"run": Callable(TipsSettings, "_replay_tips"),
	})


static func _get_tips() -> bool:
	return GameState.onboarding.tips_enabled


static func _set_tips(v: Variant) -> void:
	GameState.onboarding.tips_enabled = bool(v)
	set_enabled(bool(v))


static func _replay_tips() -> String:
	GameState.onboarding.replay_tips()
	set_enabled(true)
	return "Tips will play again."
