class_name BootScreen
extends Control
## Boot scene and the project's main scene. Shows the animated backdrop, logo, the walker walking along a
## progress bar, and rotating tips. The bar is driven by threaded loading of the game's scenes. When loading
## has finished and the screen has been up for MIN_SHOW_SECONDS, it dissolves to main.tscn using the
## already loaded resource.

const GAME_SCENE: String = "res://main.tscn"
const MEADOW_SCENE: String = "res://world/meadow3d_scene.tscn"
const THEME_PATH: String = "res://theme/plinky_theme.tres"
const WALKER_SHEET_PATH: String = "res://assets/brand/walker-press-sheet-1x.png"
const BODY_FONT: FontFile = preload("res://fonts/spleen-6x12.fnt")
const DISPLAY_FONT: FontFile = preload("res://fonts/PixelifySans.ttf")
const WALKER_SHEET: Texture2D = preload("res://assets/brand/walker-press-sheet-1x.png")

## Shortest time the logo stays up, so a fast load does not flash past. Real progress still drives the bar.
const MIN_SHOW_SECONDS: float = 1.8
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
const DISSOLVE_SECONDS: float = 0.6
const TIPS: Array[String] = [
	"Stand on a pad to press it at your press rate. Hold the mouse on a pad to keep pressing.",
	"Relics drop on every successful press. Equip them in your relic slots.",
	"Relic slots unlock at 5 and 20 rebirths.",
	"Rebirths boost Multiplier gain only.",
	"The gate opens after 9 rebirths in the meadow.",
	"Epic and rarer relics flash their pad when they drop.",
	"Divine and Special relics never drop at random.",
]

enum Phase { LOADING, LEAVING, FAILED }

var _phase: Phase = Phase.LOADING
var _loader: BootLoader
var _elapsed: float = 0.0
var _shown: float = 0.0
var _bg: BootBackground
var _motes: BootMotes
var _track: Control
var _walker: TextureRect
var _walker_tex: AtlasTexture
var _walk_t: float = 0.0
var _bar: BootProgressBar
var _percent: Label
var _status: Label
var _tip_label: Label
var _tip_index: int = 0
var _tip_timer: float = 0.0
var _tip_blank: float = 0.0
var _pal: PackedColorArray


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pal = Palettes.colors(Palettes.MEADOW)

	_bg = BootBackground.new()
	add_child(_bg)
	_motes = BootMotes.new()
	add_child(_motes)
	_build_column()

	# Threaded loads. Weights are rough file sizes. Each task reports its own progress, so the bar is honest.
	_loader = BootLoader.new()
	_loader.add(MEADOW_SCENE, 0.40, "Waking the meadow")
	_loader.add(GAME_SCENE, 0.25, "Gathering the pads")
	_loader.add(THEME_PATH, 0.10, "Mixing the palette")
	_loader.add(WALKER_SHEET_PATH, 0.10, "Shaping the walker")
	_loader.add("res://fonts/PixelifySans.ttf", 0.075, "Setting the type")
	_loader.add("res://fonts/spleen-6x12.fnt", 0.075, "Setting the type")
	_loader.start()

	_tip_index = randi() % TIPS.size()
	_tip_label.text = TIPS[_tip_index]
	_place_walker(0.0)


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
	tagline.text = "Press. Tally. Rebirth."
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

	_percent = Label.new()
	_percent.text = "0%"
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.add_theme_font_override("font", BODY_FONT)
	_percent.add_theme_color_override("font_color", _pal[7])
	_percent.add_theme_color_override("font_outline_color", _pal[0])
	_percent.add_theme_constant_override("outline_size", 1)
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_percent)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", BODY_FONT)
	_status.add_theme_color_override("font_color", _pal[7])
	_status.add_theme_color_override("font_outline_color", _pal[0])
	_status.add_theme_constant_override("outline_size", 1)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status)

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


func _process(delta: float) -> void:
	_elapsed += delta
	_animate_walker(delta)
	_animate_tips(delta)
	if _phase == Phase.LOADING:
		_update_loading(delta)


func _update_loading(delta: float) -> void:
	var real: float = _loader.poll()
	if _loader.has_failures():
		_phase = Phase.FAILED
		_status.text = "Could not load %s. Check the console." % _loader.failed_paths()[0]
		_status.add_theme_color_override("font_color", _pal[5])
		return
	# The bar eases toward the real value so it never jumps, and it never runs ahead of the loader.
	_shown = move_toward(_shown, real, BAR_SPEED * delta)
	_bar.value = _shown
	_place_walker(_shown)
	_percent.text = "%d%%" % roundi(_shown * 100.0)
	if not _loader.is_finished():
		_status.text = _loader.current_label()
	elif _shown < 0.999:
		_status.text = "Opening the gate"
	else:
		_status.text = "Ready"
	if _loader.is_finished() and _shown >= 0.999 and _elapsed >= MIN_SHOW_SECONDS:
		_start_leave()


## The walker's pad sits on the bar's leading edge.
func _place_walker(fraction: float) -> void:
	var fill_x: float = 1.0 + floorf((TRACK_WIDTH - 2.0) * fraction)
	_walker.position = Vector2(fill_x - WALKER_CELL * 0.5, BAR_Y - WALKER_BASE_Y)


func _start_leave() -> void:
	_phase = Phase.LEAVING
	var game: PackedScene = _loader.resource_for(GAME_SCENE) as PackedScene
	if game == null:
		_phase = Phase.FAILED
		push_error("Boot: %s did not load as a PackedScene" % GAME_SCENE)
		return
	var tween := create_tween()
	tween.tween_method(_bg.set_dissolve, 0.0, 1.0, DISSOLVE_SECONDS)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_packed(game))


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
