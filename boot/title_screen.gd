class_name TitleScreen
extends Control
## The title screen, between the boot screen and the game: the animated meadow backdrop, the logo, the walker, and
## three text buttons (Play or Continue, Settings, Quit) with the version in the corner. Boot hands over the
## already loaded game scene through `game_scene`, so Play is instant. Quit to title from the pause menu comes
## back here too.
##
## Dev and test launches skip this screen: pass `-- --skip-title` after the engine arguments, or set the
## environment variable PLINKY_SKIP_TITLE. The CI smoke test and every tool that boots the real project use it.

const GAME_SCENE: String = "res://main.tscn"
const TITLE_SCENE: String = "res://boot/title_screen.tscn"
const THEME_PATH: String = "res://theme/plinky_theme.tres"
const SKIP_ARG: String = "--skip-title"
const SKIP_ENV: String = "PLINKY_SKIP_TITLE"
const SAVE_PATH: String = "user://save.json"
const BODY_FONT: FontFile = preload("res://fonts/spleen-6x12.fnt")
const DISPLAY_FONT: FontFile = preload("res://fonts/PixelifySans.ttf")
const WALKER_SHEET: Texture2D = preload("res://assets/brand/walker-press-sheet-1x.png")
const WALKER_CELL: int = 64
const WALKER_FRAME_COUNT: int = 8
const WALKER_FPS: float = 8.0
const FADE_SECONDS: float = 0.5

## Set by the boot screen (or loaded on demand) so Play does not wait on disk.
static var game_scene: PackedScene

var _bg: BootBackground
var _walker_tex: AtlasTexture
var _walk_t: float = 0.0
var _starting: bool = false
var _settings_host: Control
var _settings: DisplayPanel
var _play: MenuTextButton
var _settings_button: MenuTextButton
var _quit: MenuTextButton
var _pal: PackedColorArray


## True when this launch should go straight into the game (dev and test launches).
static func skip_requested() -> bool:
	return OS.get_cmdline_user_args().has(SKIP_ARG) or OS.has_environment(SKIP_ENV)


## The game scene, from boot's handover or from disk.
static func game_packed() -> PackedScene:
	if game_scene == null:
		game_scene = load(GAME_SCENE) as PackedScene
	return game_scene


## Play reads "Continue" when there is a save to continue.
static func play_label() -> String:
	return "Continue" if FileAccess.file_exists(SAVE_PATH) else "Play"


## Leave the game for the title screen (the pause menu's Quit to title).
static func go_to_title(tree: SceneTree) -> void:
	tree.change_scene_to_file(TITLE_SCENE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load(THEME_PATH) as Theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pal = Palettes.colors(Palettes.MEADOW)
	RelicStyle.set_palette(_pal)
	SettingsRegistry.apply_all()
	_bg = BootBackground.new()
	add_child(_bg)
	add_child(BootMotes.new())
	_build_column()
	_build_settings()
	# Fade in from ink, the mirror of the boot screen's dissolve.
	if not (FxConfig.reduce_flashing or MeadowLife.reduce_motion):
		_bg.set_dissolve(1.0)
		var tween := create_tween()
		tween.tween_method(_bg.set_dissolve, 1.0, 0.0, FADE_SECONDS)
	_play.grab_focus()


func _build_column() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var walker := TextureRect.new()
	_walker_tex = AtlasTexture.new()
	_walker_tex.atlas = WALKER_SHEET
	_walker_tex.region = Rect2(0, 0, WALKER_CELL, WALKER_CELL)
	walker.texture = _walker_tex
	walker.custom_minimum_size = Vector2(WALKER_CELL, WALKER_CELL)
	walker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	walker.stretch_mode = TextureRect.STRETCH_KEEP
	walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(walker)

	column.add_child(_label("PLINKY", DISPLAY_FONT, 48, _pal[7], 4))
	column.add_child(_label("Press. Tally. Rebirth.", BODY_FONT, -1, _pal[5], 1))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(1.0, 10.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	_play = _button(play_label(), _pal[4], _on_play)
	_settings_button = _button("Settings", _pal[5], _open_settings)
	_quit = _button("Quit", _pal[5], _on_quit)
	for b: MenuTextButton in [_play, _settings_button, _quit]:
		column.add_child(b)

	var ver := Label.new()
	ver.text = BuildInfo.string()
	ver.add_theme_font_override("font", BODY_FONT)
	ver.add_theme_color_override("font_color", _pal[3])
	ver.add_theme_color_override("font_outline_color", _pal[0])
	ver.add_theme_constant_override("outline_size", 1)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	add_child(ver)


func _label(text: String, font: Font, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", _pal[0])
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, accent: Color, on_press: Callable) -> MenuTextButton:
	var b := MenuTextButton.new()
	b.label = text
	b.rest_color = _pal[7]
	b.accent_color = accent
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	return b


## The same settings panel the game uses, hosted over the title.
func _build_settings() -> void:
	_settings_host = Control.new()
	_settings_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_settings_host)
	_settings = DisplayPanel.new()
	_settings_host.add_child(_settings)
	_settings.bind(get_window())
	CloseX.attach(_settings, _settings.close)


func _open_settings() -> void:
	_settings.open()


func settings_open() -> bool:
	return _settings != null and _settings.visible


func _on_play() -> void:
	if _starting:
		return
	var game: PackedScene = game_packed()
	if game == null:
		push_error("Title: %s did not load" % GAME_SCENE)
		return
	_starting = true
	_settings.close()
	var tween := create_tween()
	tween.tween_method(_bg.set_dissolve, 0.0, 1.0, FADE_SECONDS)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_packed(game))


func _on_quit() -> void:
	get_tree().quit()


## Esc closes the settings panel first; with nothing open it does nothing (Quit is a button on purpose).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"plinky_back") and settings_open():
		_settings.close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_walk_t += delta
	var frame: int = int(_walk_t * WALKER_FPS) % WALKER_FRAME_COUNT
	_walker_tex.region = Rect2(frame * WALKER_CELL, 0, WALKER_CELL, WALKER_CELL)
