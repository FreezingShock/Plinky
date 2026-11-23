class_name Keybinds
extends RefCounted
## Rebindable keys. Code asks Keybinds.matches(&"settings", event) instead of comparing a keycode, so the
## Controls tab can change them. Saved in user://settings.cfg, section "keys". Esc is fixed (it always closes).
## A binding is a keycode, optionally OR-ed with KEY_MASK_SHIFT / CTRL / ALT / META (so "Shift+C" is one int). A
## modifier key on its own (Shift, Ctrl) is a valid binding too. Old saves hold plain keycodes and still work.
## Add an action by adding a row to ACTIONS: [id, label, default keycode].

const SECTION: String = "keys"
const MOD_KEYS: Array[int] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const MOD_MASKS: int = KEY_MASK_SHIFT | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_META
const ACTIONS: Array = [
	[&"settings", "Settings", KEY_F10],
	[&"fullscreen", "Fullscreen", KEY_F11],
	[&"relics", "Relics", KEY_R],
	[&"upgrades", "Upgrades", KEY_TAB],
	[&"stats", "Stats", KEY_I],
	[&"attributes", "Attributes", KEY_O],
	[&"menu", "Menu", KEY_M],
	[&"recenter", "Recentre camera", KEY_HOME],
	[&"jump", "Jump", KEY_SPACE],
	[&"crouch", "Crouch / slide", KEY_C],
	[&"sprint", "Sprint (hold)", KEY_SHIFT],
	[&"sprint_lock", "Sprint lock", KEY_CTRL],
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
	# A clash is most often an old save (Recentre used to default to C, now Crouch does): put the earlier action back
	# on its default first, and only reset everything if that does not clear it.
	for pass_i: int in 2:
		var seen: Dictionary = {}
		var clash: bool = false
		for row: Array in ACTIONS:
			var k: int = int(_keys[row[0]])
			if seen.has(k):
				clash = true
				if pass_i == 0:
					var first: StringName = seen[k]
					for r2: Array in ACTIONS:
						if r2[0] == first:
							_keys[first] = int(r2[2])
				else:
					for r3: Array in ACTIONS:
						_keys[r3[0]] = int(r3[2])
				break
			seen[k] = row[0]
		if not clash:
			return


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


static func is_modifier(keycode: int) -> bool:
	return keycode in MOD_KEYS


## The binding an event stands for: its key plus any held modifiers, or just the key when it is a modifier itself.
static func code_of(k: InputEventKey) -> int:
	var key: int = int(k.keycode)
	if is_modifier(key):
		return key
	var code: int = key
	if k.shift_pressed:
		code |= KEY_MASK_SHIFT
	if k.ctrl_pressed:
		code |= KEY_MASK_CTRL
	if k.alt_pressed:
		code |= KEY_MASK_ALT
	if k.meta_pressed:
		code |= KEY_MASK_META
	return code


## True if a binding made of `key` and the `mods` mask is satisfied by these held modifiers (extra ones are fine).
static func _mods_ok(mods: int, shift: bool, ctrl: bool, alt: bool, meta: bool) -> bool:
	return ((mods & KEY_MASK_SHIFT) == 0 or shift) and ((mods & KEY_MASK_CTRL) == 0 or ctrl) \
		and ((mods & KEY_MASK_ALT) == 0 or alt) and ((mods & KEY_MASK_META) == 0 or meta)


static func matches(action: StringName, event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	var bound: int = key_for(action)
	return int(k.keycode) == (bound & KEY_CODE_MASK) \
		and _mods_ok(bound & MOD_MASKS, k.shift_pressed, k.ctrl_pressed, k.alt_pressed, k.meta_pressed)


## True while the action's key (and any modifiers in its binding) is held. For per-frame polling.
static func held(action: StringName) -> bool:
	var bound: int = key_for(action)
	var key: int = bound & KEY_CODE_MASK
	if key == KEY_NONE or not Input.is_key_pressed(key as Key):
		return false
	return _mods_ok(bound & MOD_MASKS, Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL),
		Input.is_key_pressed(KEY_ALT), Input.is_key_pressed(KEY_META))


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
