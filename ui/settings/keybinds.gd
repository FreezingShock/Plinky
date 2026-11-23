class_name Keybinds
extends RefCounted
## Rebindable keys. Code asks Keybinds.matches(&"settings", event) instead of comparing a keycode, so the
## Controls tab can change them. Saved in user://settings.cfg, section "keys". Esc is fixed (it always closes).
## Add an action by adding a row to ACTIONS: [id, label, default keycode].

const SECTION: String = "keys"
const ACTIONS: Array = [
	[&"settings", "Settings", KEY_F10],
	[&"fullscreen", "Fullscreen", KEY_F11],
	[&"relics", "Relics", KEY_R],
	[&"upgrades", "Upgrades", KEY_TAB],
	[&"stats", "Stats", KEY_I],
	[&"attributes", "Attributes", KEY_O],
	[&"menu", "Menu", KEY_M],
	[&"recenter", "Recentre camera", KEY_C],
	[&"console", "Dev console", KEY_QUOTELEFT],
]

static var _keys: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for row: Array in ACTIONS:
		_keys[row[0]] = int(row[2])
	var cfg: ConfigFile = SettingsFile.read() if SettingsFile.persist else ConfigFile.new()
	for row: Array in ACTIONS:
		var k: int = int(cfg.get_value(SECTION, String(row[0]), row[2]))
		if k > 0:
			_keys[row[0]] = k
	_dedupe()


## Two actions on one key would fire together, so a saved clash falls back to defaults.
static func _dedupe() -> void:
	var seen: Dictionary = {}
	for row: Array in ACTIONS:
		var k: int = int(_keys[row[0]])
		if seen.has(k):
			for r2: Array in ACTIONS:
				_keys[r2[0]] = int(r2[2])
			return
		seen[k] = true


static func key_for(action: StringName) -> int:
	_load()
	return int(_keys.get(action, KEY_NONE))


static func key_name(action: StringName) -> String:
	return OS.get_keycode_string(key_for(action) as Key)


static func label_for(action: StringName) -> String:
	for row: Array in ACTIONS:
		if row[0] == action:
			return String(row[1])
	return String(action)


static func matches(action: StringName, event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	return int(k.keycode) == key_for(action)


## Bind `action` to `keycode`. If another action had that key, it takes this action's old key (a swap),
## so nothing is ever left unbound or doubled. Returns the action that was swapped, or &"".
static func set_key(action: StringName, keycode: int) -> StringName:
	_load()
	var swapped: StringName = &""
	var old: int = key_for(action)
	for row: Array in ACTIONS:
		if row[0] != action and int(_keys[row[0]]) == keycode:
			_keys[row[0]] = old
			swapped = row[0]
	_keys[action] = keycode
	_save()
	return swapped


static func reset_all() -> void:
	_loaded = true
	for row: Array in ACTIONS:
		_keys[row[0]] = int(row[2])
	_save()


static func _save() -> void:
	var d: Dictionary = {}
	for row: Array in ACTIONS:
		d[String(row[0])] = int(_keys[row[0]])
	SettingsFile.write(SECTION, d)
