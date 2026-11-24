class_name TitleScreen
extends Control
## The title screen, between the boot screen and the game. A layered dusk meadow (title_background.gdshader plus
## TitleScenery: mountains, lake, mill, cottage, trees, fireflies, birds) with the hooded walker on its pad on the right,
## and on the left the logo and a framed menu: Continue (or Play), New Game, Saves, Settings, Update Log, Credits,
## Quit, each with a pixel icon. The version number bottom right opens the Update Log. Boot hands over the already
## loaded game scene through `game_scene`, so Play is instant. Quit to title from the pause menu comes back here too.
##
## Dev and test launches skip this screen: pass `-- --skip-title` after the engine arguments, or set the
## environment variable PLINKY_SKIP_TITLE. The CI smoke test and every tool that boots the real project use it.

const GAME_SCENE: String = "res://main.tscn"
const TITLE_SCENE: String = "res://boot/title_screen.tscn"
const BOOT_SCENE: String = "res://boot/boot.tscn"
const THEME_PATH: String = "res://theme/plinky_theme.tres"
const SKIP_ARG: String = "--skip-title"
const SKIP_ENV: String = "PLINKY_SKIP_TITLE"
const SAVE_PATH: String = SaveSlots.BASE_PATH
const BODY_FONT: FontFile = preload("res://fonts/spleen-6x12.fnt")
const DISPLAY_FONT: FontFile = preload("res://fonts/PixelifySans.ttf")
const WALKER_SHEET: Texture2D = preload("res://assets/brand/walker-press-sheet-1x.png")
const WALKER_CELL: int = 64
const WALKER_FRAME_COUNT: int = 8
const WALKER_FPS: float = 8.0
## Where the walker's feet stand on the meadow (texels), and how far down its cell they are.
const WALKER_FEET: Vector2 = Vector2(470.0, 294.0)
const WALKER_BASE_Y: float = 47.0
const MENU_X: float = 26.0
## Shared with the loading screen, so both read the same.
const TAGLINE: String = "+ Press. Walk. Bloom. +"
const CHIP_Y: float = 340.0

## Set by the boot screen (or loaded on demand) so Play does not wait on disk.
static var game_scene: PackedScene

var _bg: TitleBackground
var _scenery: TitleScenery
var _walker: TextureRect
var _walker_tex: AtlasTexture
var _walk_t: float = 0.0
var _starting: bool = false
var _settings_host: Control
var _settings: DisplayPanel
var _saves_overlay: PanelOverlay
var _saves: SlotPanel
var _credits_overlay: PanelOverlay
var _log_overlay: PanelOverlay
var _play: MenuTextButton
var _new_game: MenuTextButton
var _menu_buttons: Array[MenuTextButton] = []
var _version: VersionLink
var _pal: PackedColorArray
var _logo: Label
var _tagline: Label
var _chip: MenuTextButton
## Time of day the screen last themed itself for; the accents only change when the name does.
var _themed_for: String = ""


## True when this launch should go straight into the game (dev and test launches).
static func skip_requested() -> bool:
	return OS.get_cmdline_user_args().has(SKIP_ARG) or OS.has_environment(SKIP_ENV)


## The game scene, from boot's handover or from disk.
static func game_packed() -> PackedScene:
	if game_scene == null:
		game_scene = load(GAME_SCENE) as PackedScene
	return game_scene


## Play reads "Continue" when there is a save to continue (in any slot).
static func play_label() -> String:
	return "Continue" if SaveSlots.any_save() else "Play"


## Leave the game for the title screen (the pause menu's Quit to title), swapped with no flat frame.
static func go_to_title(tree: SceneTree) -> void:
	SceneSwap.go(tree, load(TITLE_SCENE) as PackedScene)


## The Save autoload, looked up by path so this script also compiles in the headless test runner (which has no autoloads).
func _save() -> Node:
	return get_node_or_null("/root/Save")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme: Theme = load(THEME_PATH) as Theme
	theme = ui_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	CrispFont.apply(DISPLAY_FONT)
	_pal = Palettes.colors(Palettes.MEADOW)
	RelicStyle.set_palette(_pal)
	PadInput.ensure()   # registers plinky_back and the menu pad actions, which only Main did before
	SettingsRegistry.apply_all()
	# Nothing autosaves on the title, so browsing or deleting slots never writes a new save.
	var save: Node = _save()
	if save != null:
		save.set("paused", true)
	_bg = TitleBackground.new()
	add_child(_bg)
	_scenery = TitleScenery.new()
	add_child(_scenery)
	add_child(BootMotes.new())
	_build_walker()
	_build_column()
	_build_version()
	_build_time_chip()
	_build_panels(ui_theme)
	_refresh_menu()
	_refresh_theme()
	# Arrivals come through SceneSwap, which reveals this screen from a captured frame, so it opens fully drawn.
	_play.grab_focus()


func _build_walker() -> void:
	_walker_tex = AtlasTexture.new()
	_walker_tex.atlas = WALKER_SHEET
	_walker_tex.region = Rect2(0, 0, WALKER_CELL, WALKER_CELL)
	_walker = TextureRect.new()
	_walker.texture = _walker_tex
	_walker.size = Vector2(WALKER_CELL, WALKER_CELL)
	_walker.position = Vector2(WALKER_FEET.x - float(WALKER_CELL) * 0.5, WALKER_FEET.y - WALKER_BASE_Y)
	_walker.stretch_mode = TextureRect.STRETCH_KEEP
	_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_walker)


## Left column: logo, tagline, then the framed menu.
func _build_column() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(MENU_X, 22.0)
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_logo = _label("PLINKY", DISPLAY_FONT, 48, _pal[7], 4)
	# A chunky drop shadow in ink, so the logo sits on any part of the sky.
	_logo.add_theme_color_override("font_shadow_color", _pal[0])
	_logo.add_theme_constant_override("shadow_offset_x", 0)
	_logo.add_theme_constant_override("shadow_offset_y", 4)
	_logo.add_theme_constant_override("shadow_outline_size", 4)
	column.add_child(_logo)
	_tagline = _label(TAGLINE, BODY_FONT, -1, _pal[5], 1)
	_tagline.add_theme_color_override("font_shadow_color", _pal[0])
	_tagline.add_theme_constant_override("shadow_offset_x", 1)
	_tagline.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(_tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(1.0, 8.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", AsciiBox.panel())
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	frame.add_child(stack)

	_play = _button("Continue", "play", _pal[4], _on_play)
	_new_game = _button("New Game", "new", _pal[5], _on_new_game)
	var saves: MenuTextButton = _button("Saves", "saves", _pal[5], _open_saves)
	var settings: MenuTextButton = _button("Settings", "settings", _pal[5], _open_settings)
	var log_btn: MenuTextButton = _button("Update Log", "log", _pal[5], _open_log)
	var credits: MenuTextButton = _button("Credits", "credits", _pal[5], _open_credits)
	var quit: MenuTextButton = _button("Quit", "quit", _pal[5], _on_quit)
	for b: MenuTextButton in [_play, _new_game, saves, settings, log_btn, credits, quit]:
		stack.add_child(b)
		_menu_buttons.append(b)
	# Give every button the width of the widest, so the frame is even and the whole row is clickable.
	var widest: float = 0.0
	for b: MenuTextButton in _menu_buttons:
		widest = maxf(widest, b.custom_minimum_size.x)
	for b: MenuTextButton in _menu_buttons:
		b.custom_minimum_size.x = widest
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## The time chip: names the time of day on screen, and a click runs the sky forward to the next one.
func _build_time_chip() -> void:
	_chip = _button("", "", _pal[5], _on_time_chip)
	_chip.position = Vector2(MENU_X, CHIP_Y)
	add_child(_chip)


func _on_time_chip() -> void:
	_bg.skip_to_next()


## Re-colour the logo, tagline, chip and menu accents for the time of day on screen. Runs every frame but only
## writes when the time of day changes name.
func _refresh_theme() -> void:
	var now_name: String = _bg.time_name()
	if now_name == _themed_for:
		return
	_themed_for = now_name
	var ink: Color = _bg.role(0)
	var paper: Color = _bg.role(7)
	var accent: Color = _bg.role(5)
	_logo.add_theme_color_override("font_color", paper)
	_logo.add_theme_color_override("font_outline_color", ink)
	_logo.add_theme_color_override("font_shadow_color", ink)
	_tagline.add_theme_color_override("font_color", accent)
	_tagline.add_theme_color_override("font_outline_color", ink)
	_chip.label = now_name
	_chip.rest_color = paper
	_chip.accent_color = accent
	for b: MenuTextButton in _menu_buttons:
		b.accent_color = accent


func _build_version() -> void:
	_version = VersionLink.new()
	_version.rest_color = _pal[7]
	_version.accent_color = _pal[5]
	_version.outline_color = _pal[0]
	_version.pressed.connect(_open_log)
	add_child(_version)


func _label(text: String, font: Font, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", _pal[0])
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, icon: String, accent: Color, on_press: Callable) -> MenuTextButton:
	var b := MenuTextButton.new()
	b.label = text
	b.icon_id = icon
	b.pad_y = 3.0
	b.rest_color = _pal[7]
	b.accent_color = accent
	b.pressed.connect(on_press)
	return b


## Settings is the same panel the game uses; Saves, Credits and the Update Log sit in scrimmed overlays.
func _build_panels(ui_theme: Theme) -> void:
	_settings_host = Control.new()
	_settings_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_settings_host)
	_settings = DisplayPanel.new()
	_settings_host.add_child(_settings)
	_settings.bind(get_window())
	CloseX.attach(_settings, _settings.close)

	_saves = SlotPanel.new()
	_saves.slot_chosen.connect(_on_slot_chosen)
	_saves.slot_deleted.connect(_on_slot_deleted)
	_saves_overlay = PanelOverlay.host(self, _saves, _pal[0], ui_theme)
	_credits_overlay = PanelOverlay.host(self, CreditsPanel.new(), _pal[0], ui_theme)
	_log_overlay = PanelOverlay.host(self, UpdateLogPanel.new(), _pal[0], ui_theme)
	for o: PanelOverlay in [_saves_overlay, _credits_overlay, _log_overlay]:
		o.closed.connect(_on_overlay_closed)


## Continue and New Game follow what is on disk: no saves means one button, Play.
func _refresh_menu() -> void:
	var has_save: bool = SaveSlots.any_save()
	_play.label = "Continue" if has_save else "Play"
	_new_game.visible = has_save
	_saves.active_slot = SaveSlots.continue_slot() if has_save else 1


func _close_overlays() -> void:
	_settings.close()
	for o: PanelOverlay in [_saves_overlay, _credits_overlay, _log_overlay]:
		o.close()


func _open_settings() -> void:
	_close_overlays()
	_settings.open()


func _open_saves() -> void:
	_close_overlays()
	_saves.set_hint("")
	_saves_overlay.open()


func _open_credits() -> void:
	_close_overlays()
	_credits_overlay.open()


func _open_log() -> void:
	if _log_overlay.is_open():
		_log_overlay.close()
		return
	_close_overlays()
	_log_overlay.open()


func settings_open() -> bool:
	return _settings != null and _settings.visible


## True while any panel is over the title.
func overlay_open() -> bool:
	return settings_open() or _saves_overlay.is_open() or _credits_overlay.is_open() or _log_overlay.is_open()


func _on_overlay_closed() -> void:
	_refresh_menu()
	if not overlay_open():
		_play.grab_focus()


func _on_play() -> void:
	var n: int = SaveSlots.continue_slot()
	_begin(1 if n == 0 else n, n == 0)


## New Game starts in the first empty slot; with every slot full it opens Saves so the player picks what to replace.
func _on_new_game() -> void:
	var n: int = SaveSlots.first_empty_slot()
	if n == 0:
		_close_overlays()
		_saves.set_hint("All slots are full. Delete one, then Start a new game in it.")
		_saves_overlay.open()
		return
	_begin(n, true)


func _on_slot_chosen(n: int) -> void:
	_begin(n, not bool(SaveSlots.slot_summary(n)["exists"]))


func _on_slot_deleted(n: int) -> void:
	var save: Node = _save()
	if save != null:
		save.call("delete_slot", n)
	else:
		SaveSlots.delete_files(n)
	_refresh_menu()


## Load (or start) slot `n`, then fade into the game.
func _begin(n: int, fresh: bool) -> void:
	if _starting:
		return
	var game: PackedScene = game_packed()
	if game == null:
		push_error("Title: %s did not load" % GAME_SCENE)
		return
	_starting = true
	_close_overlays()
	var save: Node = _save()
	if save != null:
		if fresh:
			save.call("new_game_in_slot", n)
		else:
			save.call("select_slot", n)
		save.set("paused", false)
		save.call("save_game")  # a new slot gets its file now, so it shows up in Saves straight away
	# Play goes through the loading screen. It opens at this time of day and loads the slot's zone art with real progress.
	BootScreen.handoff = _handoff_for()
	# The loading screen draws the same title backdrop at the same time of day, so the hand-off is a foreground swap only.
	SceneSwap.go(get_tree(), load(BOOT_SCENE) as PackedScene, true)


## What the loading screen needs for the slot just opened: the zone scene it will show, its name, the time of day the
## title is showing. Falls back to the meadow when no zone is known yet.
func _handoff_for() -> Dictionary:
	var zone_path: String = BootScreen.MEADOW_SCENE
	var zone_name: String = "Meadow"
	var state: Node = get_node_or_null("/root/GameState")
	var sim: Sim = state.get("sim") as Sim if state != null else null
	if sim != null:
		var zone: ZoneDef = sim.zone_defs.get(sim.zone_id) as ZoneDef
		if zone != null:
			zone_name = zone.display_name
			if zone.scene_path != "":
				zone_path = zone.scene_path
	return {"zone_path": zone_path, "zone_name": zone_name, "phase": _bg.phase()}


func _on_quit() -> void:
	get_tree().quit()


## Esc closes the settings panel first (the overlays close themselves); with nothing open it does nothing.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"plinky_back") and settings_open():
		_settings.close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_walk_t += delta
	var frame: int = int(_walk_t * WALKER_FPS) % WALKER_FRAME_COUNT
	_walker_tex.region = Rect2(frame * WALKER_CELL, 0, WALKER_CELL, WALKER_CELL)
	_refresh_theme()
	# The scenery takes the time of day's tint and life: fireflies by night, birds by day.
	var mood: Dictionary = _bg.mood()
	var tint: Color = mood.get("tint", Color.WHITE)
	_scenery.set_mood(tint, float(mood.get("shade", 0.0)), TitleMood.night_amount(_bg.sky, _bg.clock), TitleMood.day_amount(_bg.sky, _bg.clock))
	_walker.modulate = Color.WHITE.lerp(tint, 0.5)
	# Both scenes share one smoothed parallax, so the walker and the layers move as a set.
	_scenery.parallax = _bg.parallax
	_walker.position = Vector2(WALKER_FEET.x - float(WALKER_CELL) * 0.5, WALKER_FEET.y - WALKER_BASE_Y) + TitleScenery.layer_shift(_bg.parallax, TitleScenery.NEAR_K)
