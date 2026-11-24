class_name BootScreen
extends Control
## Boot scene and the project's main scene. Shows the animated backdrop, logo, the walker walking along a
## progress bar, and rotating tips. The bar is driven by threaded loading of the game's scenes. When loading
## has finished and the screen has been up for its minimum time, it hands over to the title screen (or straight to
## main.tscn with --skip-title) with SceneSwap, using the already loaded resource.
##
## Handoff mode: the title screen sets `handoff` before it leaves for the game. The same screen then opens at the
## title's time of day, loads the chosen slot's zone art (the real stall on Play) and labels that step by name.

const GAME_SCENE: String = "res://main.tscn"
const MEADOW_SCENE: String = "res://world/meadow3d_scene.tscn"
const THEME_PATH: String = "res://theme/plinky_theme.tres"
const WALKER_SHEET_PATH: String = "res://assets/brand/walker-press-sheet-1x.png"
const BODY_FONT: FontFile = preload("res://fonts/spleen-6x12.fnt")
const DISPLAY_FONT: FontFile = preload("res://fonts/PixelifySans.ttf")
const WALKER_SHEET: Texture2D = preload("res://assets/brand/walker-press-sheet-1x.png")

## Shortest time the logo stays up, so a fast load does not flash past. Real progress still drives the bar.
const MIN_SHOW_SECONDS: float = 1.8
## Handoff from the title: the zone is usually warm already, so the screen stays shorter and the bar catches up faster.
const HANDOFF_MIN_SHOW_SECONDS: float = 0.5
const HANDOFF_BAR_SPEED: float = 2.5
## Bar catch-up speed, in full-bar units per second.
const BAR_SPEED: float = 0.9
const TRACK_WIDTH: float = 240.0
## Bar sits 50 texels down the track, so the walker's feet (47 texels into its cell) land on the bar.
const BAR_Y: float = 50.0
const WALKER_CELL: int = 64
const WALKER_FRAME_COUNT: int = 8
## Brand press loop: the walker on its pad, pressing. Stands on the bar's leading edge.
const WALKER_FPS: float = 8.0
## Pad base sits on the bar: the sprite's bottom is WALKER_BASE_Y texels into its 64 texel cell.
const WALKER_BASE_Y: float = 56.0
const TIP_SECONDS: float = 3.4
const TIP_BLANK_SECONDS: float = 0.15
## Time of day the loading screen opens at: sunrise.
const BOOT_PHASE: float = 0.25
const TIPS: Array[String] = [
	"Stand on a pad to press it at your press rate. Hold the mouse on a pad to keep pressing.",
	"Relics drop on every successful press. Equip them in your relic slots.",
	"Relic slots unlock at 5 and 20 rebirths.",
	"Rebirth banks Prestige, a permanent boost to your passive income.",
	"The gate opens after 9 rebirths in the meadow.",
	"Epic and rarer relics flash their pad when they drop.",
	"Divine and Special relics never drop at random.",
]

enum Phase { LOADING, LEAVING, FAILED }

var _phase: Phase = Phase.LOADING
var _loader: BootLoader
var _elapsed: float = 0.0
var _shown: float = 0.0
var _bg: TitleBackground
var _motes: BootMotes
var _track: Control
var _walker: TextureRect
var _walker_tex: AtlasTexture
var _walk_t: float = 0.0
var _bar: BootProgressBar
var _status: Label
## Set by the title screen before it hands over, then read and cleared on _ready: {zone_path, zone_name, phase}.
static var handoff: Dictionary = {}
var _handoff: Dictionary = {}
var _min_show: float = MIN_SHOW_SECONDS
var _bar_speed: float = BAR_SPEED
var _tip_label: Label
var _tip_index: int = 0
var _tip_timer: float = 0.0
var _tip_blank: float = 0.0
var _pal: PackedColorArray
var _version: VersionLink
var _log: PanelOverlay


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The loading screen fills any window like the title does. Main turns this off again.
	DisplaySettings.set_pregame_fill(get_window(), true)
	GardenArt.prepare()   # the flower atlas is planned now and baked a slice a frame while the loading screen runs (_process)
	_pal = Palettes.colors(Palettes.MEADOW)

	_handoff = handoff
	handoff = {}
	_bg = TitleBackground.new()
	add_child(_bg)
	_motes = BootMotes.new()
	add_child(_motes)
	_build_column()
	RelicStyle.set_palette(_pal)
	_log = PanelOverlay.host(self, UpdateLogPanel.new(), _pal[0], load(THEME_PATH) as Theme)

	# Threaded loads. Weights are rough file sizes. Each task reports its own progress, so the bar is honest.
	_loader = BootLoader.new()
	if _handoff.is_empty():
		# The loading screen opens at sunrise, then runs through the day like the title does.
		_bg.set_phase_now(BOOT_PHASE)
		_loader.add(MEADOW_SCENE, 0.40, "Waking the meadow")
		_loader.add(GAME_SCENE, 0.25, "Gathering the pads")
		_loader.add(THEME_PATH, 0.10, "Mixing the palette")
		_loader.add(WALKER_SHEET_PATH, 0.10, "Shaping the walker")
		_loader.add("res://fonts/PixelifySans.ttf", 0.075, "Setting the type")
		_loader.add("res://fonts/spleen-6x12.fnt", 0.075, "Setting the type")
	else:
		# Opens at the title's time of day so the swap reads as one continuous picture.
		_bg.set_phase_now(float(_handoff["phase"]))
		_min_show = HANDOFF_MIN_SHOW_SECONDS
		_bar_speed = HANDOFF_BAR_SPEED
		_loader.add(String(_handoff["zone_path"]), 0.80, zone_task_label(String(_handoff["zone_name"])))
		_loader.add(GAME_SCENE, 0.20, "Gathering the pads")
	_loader.start()
	_audio(&"start_loading")

	_tip_index = randi() % TIPS.size()
	_tip_label.text = TIPS[_tip_index]
	_place_walker(0.0)


## The version number opens the Update Log over the loading screen.
func _open_log() -> void:
	_log.toggle()


## Centred column: logo, tagline, walker track, percent, status, then the tip card at the bottom.
func _build_column() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16.0
	column.offset_right = -16.0
	column.offset_top = 16.0
	column.offset_bottom = -16.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var title := Label.new()
	title.text = "PLINKY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", _pal[7])
	title.add_theme_color_override("font_outline_color", _pal[0])
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var tagline := Label.new()
	tagline.text = TitleScreen.TAGLINE
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_override("font", BODY_FONT)
	tagline.add_theme_color_override("font_color", _pal[5])
	tagline.add_theme_color_override("font_outline_color", _pal[0])
	tagline.add_theme_constant_override("outline_size", 1)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tagline)

	_track = Control.new()
	_track.custom_minimum_size = Vector2(TRACK_WIDTH, BAR_Y + BootProgressBar.BAR_HEIGHT)
	_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_track)

	_bar = BootProgressBar.new()
	_bar.position = Vector2(0.0, BAR_Y)
	_track.add_child(_bar)

	_walker_tex = AtlasTexture.new()
	_walker_tex.atlas = WALKER_SHEET
	_walker_tex.region = Rect2(0, 0, WALKER_CELL, WALKER_CELL)
	_walker = TextureRect.new()
	_walker.texture = _walker_tex
	_walker.size = Vector2(WALKER_CELL, WALKER_CELL)
	_walker.stretch_mode = TextureRect.STRETCH_KEEP
	_walker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_walker)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", BODY_FONT)
	_status.add_theme_color_override("font_color", _pal[7])
	_status.add_theme_color_override("font_outline_color", _pal[0])
	_status.add_theme_constant_override("outline_size", 1)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status)

	_version = VersionLink.new()
	_version.rest_color = _pal[7]
	_version.accent_color = _pal[5]
	_version.outline_color = _pal[0]
	_version.pressed.connect(_open_log)
	add_child(_version)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(flex)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440.0, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _card_style())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(card)

	var card_body := VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 2)
	card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_body)

	var caption := Label.new()
	caption.text = "TIP"
	caption.add_theme_font_override("font", BODY_FONT)
	caption.add_theme_color_override("font_color", _pal[5])
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(caption)

	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_override("font", BODY_FONT)
	_tip_label.add_theme_color_override("font_color", _pal[7])
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(_tip_label)


## Ink card with a one-texel panel edge, no rounding and no anti-aliasing (docs/theme.md section 4).
func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _pal[0]
	sb.border_color = _pal[3]
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8.0)
	sb.anti_aliasing = false
	return sb


## Looked up by path so the script still compiles in the headless test runner, which has no autoloads.
func _audio(method: StringName) -> void:
	var a: Node = get_node_or_null("/root/Audio")
	if a != null:
		a.call(method)


func _process(delta: float) -> void:
	_elapsed += delta
	_animate_walker(delta)
	_animate_tips(delta)
	if _phase == Phase.LOADING:
		_update_loading(delta)
	# The flower atlas bakes a slice a frame until it exists. Once the loader is done, a bigger slice finishes it, and the
	# leave waits for it (below), so the game never bakes the rest on its first frame.
	GardenArt.prepare_slice(GardenArt.BAKE_CATCHUP_MS if _loader.is_finished() else GardenArt.BAKE_SLICE_MS)


func _update_loading(delta: float) -> void:
	var real: float = _loader.poll()
	if _loader.has_failures():
		_phase = Phase.FAILED
		_status.text = "Could not load %s. Check the console." % _loader.failed_paths()[0]
		_status.add_theme_color_override("font_color", _pal[5])
		return
	# The bar eases toward the real value so it never jumps, and it never runs ahead of the loader.
	_shown = move_toward(_shown, real, _bar_speed * delta)
	_bar.value = _shown
	_place_walker(_shown)
	if not _loader.is_finished():
		_status.text = status_line(_loader.current_label(), _shown)
	else:
		_status.text = status_line("Opening the gate", _shown)
	# Stays put while the Update Log is open, so reading it is never cut short.
	# Also waits while a swap is still revealing this screen, so the leave is never dropped mid-reveal.
	if _loader.is_finished() and _shown >= 0.999 and _elapsed >= _min_show and not _log.is_open() and not SceneSwap.is_busy() and GardenArt.is_ready():
		_start_leave()


## The loading line: what is loading, then the percent, e.g. "Loading Larkmoor art... 62%". Plain ASCII dots, because the
## body font (Spleen) has no ellipsis glyph.
static func status_line(label: String, fraction: float) -> String:
	return "%s... %d%%" % [label, roundi(clampf(fraction, 0.0, 1.0) * 100.0)]


## Loader label for a zone's scene: "Loading Larkmoor art".
static func zone_task_label(zone_name: String) -> String:
	return "Loading %s art" % zone_name


## The walker's pad sits on the bar's leading edge.
func _place_walker(fraction: float) -> void:
	var fill_x: float = 1.0 + floorf((TRACK_WIDTH - 2.0) * fraction)
	_walker.position = Vector2(fill_x - WALKER_CELL * 0.5, BAR_Y - WALKER_BASE_Y)


func _start_leave() -> void:
	_phase = Phase.LEAVING
	_audio(&"stop_loading")
	var game: PackedScene = _loader.resource_for(GAME_SCENE) as PackedScene
	if game == null:
		_phase = Phase.FAILED
		push_error("Boot: %s did not load as a PackedScene" % GAME_SCENE)
		return
	TitleScreen.game_scene = game
	var next: PackedScene = game
	if _handoff.is_empty():
		# Dev and test launches (--skip-title) go straight into the game; everyone else lands on the title screen.
		if not TitleScreen.skip_requested():
			next = load(TitleScreen.TITLE_SCENE) as PackedScene
	else:
		# Keep the zone art alive until the game has used it (SceneSwap clears the list after the reveal).
		var zone: Resource = _loader.resource_for(String(_handoff["zone_path"]))
		if zone != null:
			SceneSwap.held.append(zone)
		SceneSwap.held.append(game)
	SceneSwap.go(get_tree(), next)


func _animate_walker(delta: float) -> void:
	_walk_t += delta
	var frame: int = int(_walk_t * WALKER_FPS) % WALKER_FRAME_COUNT
	_walker_tex.region = Rect2(frame * WALKER_CELL, 0, WALKER_CELL, WALKER_CELL)


## Tips change on a pixel blink (hidden for a moment), not a soft alpha fade, to match the art bible.
func _animate_tips(delta: float) -> void:
	if _tip_blank > 0.0:
		_tip_blank -= delta
		if _tip_blank <= 0.0:
			_tip_label.visible = true
			_tip_label.text = TIPS[_tip_index]
		return
	_tip_timer += delta
	if _tip_timer >= TIP_SECONDS:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip_label.visible = false
		_tip_blank = TIP_BLANK_SECONDS
