class_name SettingsRegistry
extends RefCounted
## Every setting the menu shows, as data. The menu (ui/display_panel.gd) draws whatever is registered here,
## so a new setting is one register() call and no panel code.
##
## A setting is a Dictionary:
##   id       StringName   unique
##   tab      String       one of TAB_ORDER, or a new name (new tabs are added after the known ones)
##   label    String
##   kind     Kind         TOGGLE, CHOICE, SLIDER, ACTION or KEY
##   hint     String       optional, shown under the menu while the row is hovered or changed
##   get      Callable()   -> current value        (omit for stored settings, see below)
##   set      Callable(v)  -> void                 (omit for stored settings)
##   options  Callable()   -> Array of [value, label]   (CHOICE)
##   min, max, step        (SLIDER; value is a float, default 0 to 1)
##   format   Callable(v)  -> String               (SLIDER label; default is a percent)
##   run      Callable()   -> String, the message to show      (ACTION)
##   confirm  bool         (ACTION) needs a second press
##   visible  Callable()   -> bool                 (optional; false hides the row)
##
## Stored settings: give `default` and leave out get/set, and the value is kept in user://settings.cfg under
## [game], loaded at startup. Add `apply` (Callable(value)) to push the value into the game. register_stored() does this.
## Example, from another system:
##   SettingsRegistry.register_stored(&"momentum_meter", "Gameplay", "Momentum meter", SettingsRegistry.Kind.TOGGLE, true,
##       func(v: Variant) -> void: MomentumMeter.enabled = bool(v))

enum Kind { TOGGLE, CHOICE, SLIDER, ACTION, KEY }

const TAB_ORDER: PackedStringArray = ["Audio", "Display", "Gameplay", "Access", "Controls", "Data"]
const SECTION: String = "game"

static var _defs: Array[Dictionary] = []
static var _stored: Dictionary = {}     # id -> value, for stored settings
static var _builtins_done: bool = false
static var _loaded: bool = false


# ---------------------------------------------------------------- registration

static func register(def: Dictionary) -> void:
	_ensure()
	_add(def)


static func register_stored(id: StringName, tab: String, label: String, kind: Kind, default: Variant, apply: Callable = Callable(), extra: Dictionary = {}) -> void:
	_ensure()
	var d: Dictionary = extra.duplicate()
	d["id"] = id
	d["tab"] = tab
	d["label"] = label
	d["kind"] = kind
	d["default"] = default
	if apply.is_valid():
		d["apply"] = apply
	_add(d)


static func _add(def: Dictionary) -> void:
	for i in _defs.size():
		if _defs[i]["id"] == def["id"]:
			_defs[i] = def   # re-registering replaces, so a later PR can adjust an earlier row
			return
	_defs.append(def)


static func tabs() -> PackedStringArray:
	_ensure()
	var seen: Dictionary = {}
	for d in _defs:
		seen[String(d["tab"])] = true
	var out: PackedStringArray = PackedStringArray()
	for t in TAB_ORDER:
		if seen.has(t):
			out.append(t)
	for t: String in seen:
		if not out.has(t):
			out.append(t)
	return out


## The rows of a tab that are visible right now.
static func entries(tab: String) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for d in _defs:
		if String(d["tab"]) != tab:
			continue
		var vis: Variant = d.get("visible")
		if vis is Callable and (vis as Callable).is_valid() and not bool((vis as Callable).call()):
			continue
		out.append(d)
	return out


static func find(id: StringName) -> Dictionary:
	_ensure()
	for d in _defs:
		if d["id"] == id:
			return d
	return {}


# ---------------------------------------------------------------- values

static func value(id: StringName) -> Variant:
	_ensure()
	var d: Dictionary = find(id)
	if d.is_empty():
		return null
	var g: Variant = d.get("get")
	if g is Callable and (g as Callable).is_valid():
		return (g as Callable).call()
	return _stored.get(id, d.get("default"))


static func set_value(id: StringName, v: Variant) -> void:
	_ensure()
	var d: Dictionary = find(id)
	if d.is_empty():
		return
	var s: Variant = d.get("set")
	if s is Callable and (s as Callable).is_valid():
		(s as Callable).call(v)
		return
	_stored[id] = v
	_save_stored()
	var ap: Variant = d.get("apply")
	if ap is Callable and (ap as Callable).is_valid():
		(ap as Callable).call(v)


static func _load_stored() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg: ConfigFile = SettingsFile.read()
	if cfg.has_section(SECTION):
		for k in cfg.get_section_keys(SECTION):
			_stored[StringName(k)] = cfg.get_value(SECTION, k)


static func _save_stored() -> void:
	var d: Dictionary = {}
	for id: StringName in _stored:
		d[String(id)] = _stored[id]
	SettingsFile.write(SECTION, d)


## Push every stored value into the game. Call once at startup after the autoloads exist.
static func apply_all() -> void:
	_ensure()
	for d in _defs:
		var ap: Variant = d.get("apply")
		if ap is Callable and (ap as Callable).is_valid() and not (d.get("get") is Callable):
			(ap as Callable).call(value(d["id"]))


# ---------------------------------------------------------------- built-in settings

static func _ensure() -> void:
	if _builtins_done:
		return
	_builtins_done = true
	_load_stored()
	_register_audio()
	_register_display()
	_register_gameplay()
	_register_access()
	_register_controls()
	_register_data()


static func _root() -> Window:
	var ml: MainLoop = Engine.get_main_loop()
	return (ml as SceneTree).root if ml is SceneTree else null


static func _autoload(node_name: String) -> Node:
	var win: Window = _root()
	return win.get_node_or_null(node_name) if win != null else null


static func _pct(v: Variant) -> String:
	return "%d%%" % roundi(float(v) * 100.0)


# ---- audio
static func _vol_get(bus: StringName) -> Variant:
	var a: Node = _autoload("Audio")
	return a.call("get_volume", bus) if a != null else 1.0


static func _vol_set(v: Variant, bus: StringName) -> void:
	var a: Node = _autoload("Audio")
	if a != null:
		a.call("set_volume", bus, float(v))


static func _mute_get() -> Variant:
	var a: Node = _autoload("Audio")
	return bool(a.call("is_muted")) if a != null else false


static func _mute_set(v: Variant) -> void:
	var a: Node = _autoload("Audio")
	if a != null:
		a.call("set_muted", bool(v))


static func _device_options() -> Array:
	var out: Array = []
	for dev in AudioServer.get_output_device_list():
		out.append([dev, String(dev)])
	return out


static func _device_apply(v: Variant) -> void:
	var want: String = String(v)
	AudioServer.output_device = want if AudioServer.get_output_device_list().has(want) else "Default"


static func _click_limit_apply(_v: Variant) -> void:
	var a: Node = _autoload("Audio")
	if a != null:
		a.call("set_click_limit", bool(value(&"click_limit")), int(value(&"click_limit_count")))


static func _register_audio() -> void:
	for row: Array in [[&"vol_master", "Master", &"Master"], [&"vol_music", "Music", &"Music"],
			[&"vol_sfx", "Effects", &"SFX"], [&"vol_ui", "Interface", &"UI"], [&"vol_amb", "Ambience", &"Ambience"]]:
		_add({
			"id": row[0], "tab": "Audio", "label": row[1], "kind": Kind.SLIDER, "min": 0.0, "max": 1.0, "step": 0.05,
			"get": _vol_get.bind(row[2]), "set": _vol_set.bind(row[2]), "format": _pct,
		})
	register_stored(&"click_limit", "Audio", "Quiet pad clicks", Kind.TOGGLE, true, _click_limit_apply,
		{"hint": "Stops the pad click after a few presses in a row while you stand on a pad or hold it. Stepping off starts it again."})
	register_stored(&"click_limit_count", "Audio", "Clicks before quiet", Kind.SLIDER, 5.0, _click_limit_apply,
		{"min": 1.0, "max": 10.0, "step": 1.0, "format": func(v: Variant) -> String: return "%d" % roundi(float(v)),
		"hint": "How many presses play the click (1 to 10) before it goes quiet. Needs Quiet pad clicks on."})
	_add({"id": &"muted", "tab": "Audio", "label": "Mute all", "kind": Kind.TOGGLE, "get": _mute_get, "set": _mute_set})
	_add({
		"id": &"audio_device", "tab": "Audio", "label": "Output device", "kind": Kind.CHOICE, "default": "Default",
		"hint": "Where sound plays. Plug a device in and reopen this tab to see it.",
		"options": _device_options, "apply": _device_apply,
	})


# ---- display
static func _res_options() -> Array:
	var win: Window = _root()
	if win == null:
		return [[Vector2i.ZERO, "Free"]]
	var out: Array = [[Vector2i.ZERO, "Free (now %dx%d)" % [win.size.x, win.size.y]]]
	for sz in DisplaySettings.resolution_options(win):
		out.append([sz, DisplaySettings.resolution_label(sz, win)])
	return out


static func _res_set(v: Variant) -> void:
	var sz: Vector2i = v
	if sz == Vector2i.ZERO:
		DisplaySettings.set_free_size()
	else:
		DisplaySettings.set_resolution(_root(), sz)


static func _monitor_options() -> Array:
	var out: Array = []
	for i in DisplaySettings.screen_count():
		var sz: Vector2i = DisplayServer.screen_get_size(i)
		out.append([i, "Monitor %d (%dx%d)" % [i + 1, sz.x, sz.y]])
	return out


static func _fps_options() -> Array:
	var out: Array = []
	for n in DisplaySettings.FPS_CAPS:
		out.append([n, "Unlimited" if n == 0 else "%d fps" % n])
	return out


static func _register_display() -> void:
	_add({
		"id": &"window_mode", "tab": "Display", "label": "Window", "kind": Kind.CHOICE, "hint": "F11 also toggles fullscreen.",
		"options": func() -> Array: return [[false, "Windowed"], [true, "Fullscreen"]],
		"get": func() -> Variant: return DisplaySettings.fullscreen,
		"set": func(v: Variant) -> void: DisplaySettings.set_fullscreen(_root(), bool(v)),
	})
	_add({
		"id": &"native_frame", "tab": "Display", "label": "Window frame", "kind": Kind.CHOICE,
		"hint": "Plinky frame is the game's own title bar. System frame uses the operating system's border.",
		"options": func() -> Array: return [[false, "Plinky frame"], [true, "System frame"]],
		"get": func() -> Variant: return DisplaySettings.native_frame,
		"set": func(v: Variant) -> void: DisplaySettings.set_native_frame(_root(), bool(v)),
	})
	_add({
		"id": &"graphics_quality", "tab": "Display", "label": "Graphics quality", "kind": Kind.CHOICE,
		"hint": "Low draws fewer fireflies and particles and animates the grass and air more slowly. The look is the same.",
		"options": func() -> Array: return [[GraphicsQuality.Level.LOW, "Low"], [GraphicsQuality.Level.MEDIUM, "Medium"], [GraphicsQuality.Level.HIGH, "High"]],
		"get": func() -> Variant: GraphicsQuality.load_settings(); return GraphicsQuality.level,
		"set": func(v: Variant) -> void: GraphicsQuality.set_level(int(v)),
	})
	_add({
		"id": &"scale_mode", "tab": "Display", "label": "Scaling", "kind": Kind.CHOICE,
		"hint": "Fit fills any window size. Pixel perfect keeps whole-number texels. Wide shows more meadow.",
		"options": func() -> Array: return [[DisplaySettings.Scale.PIXEL, "Pixel perfect"], [DisplaySettings.Scale.FIT, "Fit window"], [DisplaySettings.Scale.WIDE, "Wide view"]],
		"get": func() -> Variant: return DisplaySettings.scale_mode,
		"set": func(v: Variant) -> void: DisplaySettings.set_scale_mode(_root(), int(v)),
	})
	_add({
		"id": &"resolution", "tab": "Display", "label": "Window size", "kind": Kind.CHOICE,
		"hint": "Pick a size, or drag the window edge for any size. Fit scaling follows either way.",
		"options": _res_options, "get": func() -> Variant: return DisplaySettings.resolution, "set": _res_set,
	})
	_add({
		"id": &"monitor", "tab": "Display", "label": "Monitor", "kind": Kind.CHOICE,
		"visible": func() -> bool: return DisplaySettings.screen_count() > 1,
		"options": _monitor_options,
		"get": func() -> Variant: return DisplaySettings.active_screen(_root()),
		"set": func(v: Variant) -> void: DisplaySettings.set_screen(_root(), int(v)),
	})
	_add({
		"id": &"vsync", "tab": "Display", "label": "VSync", "kind": Kind.TOGGLE,
		"hint": "Matches the monitor's refresh. Turn off for the lowest input delay.",
		"get": func() -> Variant: return DisplaySettings.vsync,
		"set": func(v: Variant) -> void: DisplaySettings.set_vsync(bool(v)),
	})
	_add({
		"id": &"fps_cap", "tab": "Display", "label": "Frame rate cap", "kind": Kind.CHOICE,
		"options": _fps_options, "get": func() -> Variant: return DisplaySettings.fps_cap,
		"set": func(v: Variant) -> void: DisplaySettings.set_fps_cap(int(v)),
	})


# ---- gameplay
static func _autosave_apply(v: Variant) -> void:
	var s: Node = _autoload("Save")
	if s != null:
		s.set("autosave_override", float(v))


static func _register_gameplay() -> void:
	_add({
		"id": &"number_style", "tab": "Gameplay", "label": "Number format", "kind": Kind.CHOICE, "default": NumberFormat.Style.SUFFIX,
		"hint": "Letters (1.5M), scientific (1.5e6) or engineering (steps of three). Counters change on their next update.",
		"options": func() -> Array: return [[NumberFormat.Style.SUFFIX, "Letters (1.5M)"], [NumberFormat.Style.SCIENTIFIC, "Scientific (1.5e6)"], [NumberFormat.Style.ENGINEERING, "Engineering (15e5)"]],
		"apply": func(v: Variant) -> void: NumberFormat.style = int(v),
	})
	_add({
		"id": &"momentum_meter", "tab": "Gameplay", "label": "Momentum meter", "kind": Kind.TOGGLE,
		"hint": "The bar above the bottom bar that shows walking income bonus.",
		"get": func() -> Variant: return DisplaySettings.momentum_meter,
		"set": func(v: Variant) -> void: DisplaySettings.set_momentum_meter(bool(v)),
	})
	_add({
		"id": &"autosave", "tab": "Gameplay", "label": "Autosave", "kind": Kind.CHOICE, "default": 0,
		"hint": "It also saves on rebirth, zone change and quit.",
		"options": func() -> Array: return [[0, "Default"], [15, "Every 15 s"], [30, "Every 30 s"], [60, "Every minute"], [120, "Every 2 minutes"]],
		"apply": _autosave_apply,
	})


# ---- accessibility
static func _register_access() -> void:
	_add({
		"id": &"color_mode", "tab": "Access", "label": "Colour-safe colours", "kind": Kind.CHOICE, "default": AccessOptions.MODE_OFF,
		"hint": "Swaps rarity, buy and stat colours for ones that stay apart with colour blindness. Names and tags never depend on colour.",
		"options": func() -> Array: return [[AccessOptions.MODE_OFF, "Off"], [AccessOptions.MODE_RED_GREEN, "Red-green safe"], [AccessOptions.MODE_BLUE_YELLOW, "Blue-yellow safe"]],
		"apply": func(v: Variant) -> void: AccessOptions.set_color_mode(String(v)),
	})
	_add({
		"id": &"large_text", "tab": "Access", "label": "Large tooltip text", "kind": Kind.TOGGLE, "default": false,
		"hint": "Tooltips use Pixelify Sans at a larger size. Menus keep their fixed pixel layout.",
		"apply": func(v: Variant) -> void: AccessOptions.set_large_text(bool(v)),
	})
	_add({
		"id": &"subtitles", "tab": "Access", "label": "Sound subtitles", "kind": Kind.TOGGLE, "default": false,
		"hint": "Shows a short caption for sounds that matter: critical presses, relic chimes, gates, birdsong, waves and footsteps.",
		"apply": func(v: Variant) -> void: AccessOptions.subtitles = bool(v),
	})
	_add({
		"id": &"chip_labels", "tab": "Access", "label": "Bottom bar labels", "kind": Kind.CHOICE, "default": "hover",
		"hint": "On hover: a label floats above the button. Always: labels sit in the buttons. Never: icons only.",
		"options": func() -> Array: return [["hover", "On hover"], ["always", "Always"], ["never", "Never"]],
		"apply": func(v: Variant) -> void: ExpandChip.label_mode = String(v),
	})
	_add({
		"id": &"reduce_flashing", "tab": "Access", "label": "Reduce flashing", "kind": Kind.TOGGLE, "default": false,
		"hint": "Softens screen flashes and the rarity pad flash.",
		"apply": func(v: Variant) -> void: FxConfig.reduce_flashing = bool(v),
	})
	_add({
		"id": &"reduce_shake", "tab": "Access", "label": "Reduce screen shake", "kind": Kind.TOGGLE, "default": false,
		"apply": func(v: Variant) -> void: FxConfig.reduce_shake = bool(v),
	})
	_add({
		"id": &"reduce_screen_fx", "tab": "Access", "label": "Reduce screen effects", "kind": Kind.TOGGLE, "default": false,
		"hint": "Turns off the edge shade and the full-frame light pass. Ground, shadows and night still show.",
		"apply": func(v: Variant) -> void: FxConfig.reduce_screen_fx = bool(v),
	})
	_add({
		"id": &"calm_camera", "tab": "Access", "label": "Calm camera", "kind": Kind.TOGGLE, "default": false,
		"hint": "No look-ahead, no crit punch, no idle drift. The camera still follows.",
		"apply": func(v: Variant) -> void: WorldCamera.calm = bool(v),
	})
	_add({
		"id": &"reduce_meadow_motion", "tab": "Access", "label": "Still meadow", "kind": Kind.TOGGLE, "default": false,
		"hint": "Freezes grass sway, pollen, butterflies and firefly drift.",
		"apply": func(v: Variant) -> void: MeadowLife.reduce_motion = bool(v),
	})


# ---- controls
static func _keys_reset() -> String:
	Keybinds.reset_all()
	return "Keys back to their defaults."


static func _register_controls() -> void:
	for row: Array in Keybinds.ACTIONS:
		_add({
			"id": StringName("key_" + String(row[0])), "tab": "Controls", "label": String(row[1]), "kind": Kind.KEY, "action": row[0],
			"hint": "Click, then press the new key. Esc cancels. A key already in use swaps with that action.",
		})
	_add({"id": &"keys_reset", "tab": "Controls", "label": "Default keys", "kind": Kind.ACTION, "run": _keys_reset})


# ---- data
static func _reload() -> void:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		(ml as SceneTree).reload_current_scene()


static func _export_save() -> String:
	var s: Node = _autoload("Save")
	if s == null:
		return "No save to export."
	var text: String = String(s.call("export_string"))
	DisplayServer.clipboard_set(text)
	return "Save copied to the clipboard (%d characters)." % text.length()


static func _import_save() -> String:
	var s: Node = _autoload("Save")
	if s == null or not bool(s.call("import_string", DisplayServer.clipboard_get())):
		return "The clipboard doesn't hold a usable save. Nothing changed."
	_reload()
	return "Save imported."


static func _open_save_folder() -> String:
	OS.shell_open(ProjectSettings.globalize_path("user://"))
	return "Opened."


static func _reset_save() -> String:
	var s: Node = _autoload("Save")
	if s == null:
		return "Nothing to reset."
	s.call("reset_game")
	_reload()
	return "Save reset."


static func _register_data() -> void:
	_add({
		"id": &"save_export", "tab": "Data", "label": "Export save", "kind": Kind.ACTION,
		"hint": "Copies your save as text. Paste it somewhere safe.", "run": _export_save,
	})
	_add({
		"id": &"save_import", "tab": "Data", "label": "Import save", "kind": Kind.ACTION, "confirm": true,
		"hint": "Replaces your current game with a save you copied. Press twice to confirm.", "run": _import_save,
	})
	_add({"id": &"save_folder", "tab": "Data", "label": "Open save folder", "kind": Kind.ACTION, "run": _open_save_folder})
	_add({
		"id": &"save_reset", "tab": "Data", "label": "Reset save", "kind": Kind.ACTION, "confirm": true,
		"hint": "Wipes all progress and starts over. Settings are kept. Press twice to confirm.", "run": _reset_save,
	})
	_add({
		"id": &"dev_tools", "tab": "Data", "label": "Developer console", "kind": Kind.TOGGLE, "default": false,
		"hint": "Admin commands behind the console key (default `). For testing; they can break a save.",
	})


## True when the dev console may open: a debug build, a --dev launch argument, or the Data tab toggle.
static func dev_tools_enabled() -> bool:
	if OS.is_debug_build() or OS.get_cmdline_args().has("--dev") or OS.get_cmdline_user_args().has("--dev"):
		return true
	return bool(value(&"dev_tools"))
