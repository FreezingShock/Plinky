class_name SubtitleBar
extends Control
## Sound subtitles (Settings > Access). Listens to Audio.cue and shows up to three short captions at the top
## centre, each for LIFE seconds. A caption already on screen is only refreshed, so footsteps and birdsong
## do not stack. Nothing shows while the option is off.

const LIFE: float = 2.6
const MAX_LINES: int = 4
const TOP: float = 18.0

var _lines: Array[Dictionary] = []   ## {label: Label, left: float, text: String}
var _box: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 1)
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_box)


func _ready() -> void:
	var audio: Node = get_node_or_null("/root/Audio")
	if audio != null and audio.has_signal(&"cue"):
		audio.connect(&"cue", show_cue)


## Add a caption. Ignored while subtitles are off.
func show_cue(text: String) -> void:
	if not AccessOptions.subtitles or text == "":
		return
	for l in _lines:
		if l["text"] == text:
			l["left"] = LIFE   # same caption again: just keep it up
			return
	if _lines.size() >= MAX_LINES:
		_drop(0)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", RelicStyle.text)
	label.add_theme_color_override("font_outline_color", RelicStyle.ink)
	label.add_theme_constant_override("outline_size", 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var plate := StyleBoxFlat.new()   # ink plate so the text reads on bright ground
	plate.bg_color = RelicStyle.ink
	plate.content_margin_left = 4.0
	plate.content_margin_right = 4.0
	plate.content_margin_top = 1.0
	plate.content_margin_bottom = 1.0
	label.add_theme_stylebox_override("normal", plate)
	_box.add_child(label)
	_lines.append({"label": label, "left": LIFE, "text": text})
	_place()


func _process(delta: float) -> void:
	var i: int = _lines.size() - 1
	while i >= 0:
		_lines[i]["left"] = float(_lines[i]["left"]) - delta
		if float(_lines[i]["left"]) <= 0.0 or not AccessOptions.subtitles:
			_drop(i)
		i -= 1
	if not _lines.is_empty():
		_place()


func _drop(i: int) -> void:
	(_lines[i]["label"] as Label).queue_free()
	_lines.remove_at(i)


## Centred under the window bar, whole texels.
func _place() -> void:
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(640, 360)
	_box.size = Vector2(view.x, 0)
	_box.position = Vector2(0, TOP).round()
