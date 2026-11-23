class_name SettingsFile
extends RefCounted
## user://settings.cfg, shared by every settings section (display, game, keys). Writers load the file first and
## change only their own section, so one section's save never wipes another's.

const PATH: String = "user://settings.cfg"
## Tests turn this off so they never touch the real settings file.
static var persist: bool = true


static func read() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # a missing or unreadable file just leaves it empty
	return cfg


## Set every key in `values` under `section` and write the file.
static func write(section: String, values: Dictionary) -> void:
	if not persist:
		return
	var cfg: ConfigFile = read()
	for k: Variant in values:
		cfg.set_value(section, String(k), values[k])
	cfg.save(PATH)
