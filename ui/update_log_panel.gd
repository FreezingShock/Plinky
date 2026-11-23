class_name UpdateLogPanel
extends PanelContainer
## The Update Log: CHANGELOG.md from the project root, shown in a scrolling themed panel with the version in the
## title. Headings ("## ...") are accented, bullets ("- ...") wrap, everything else is body text.
## No file or an empty one shows a short note instead of an empty box.

const PATH: String = "res://CHANGELOG.md"
const WIDTH: float = 330.0
const HEIGHT: float = 170.0

var _list: VBoxContainer


func _init() -> void:
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Update Log"
	head.add_child(title)
	var ver := Label.new()
	ver.text = GalleryMenu.version_text()
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_color_override("font_color", RelicStyle.dim)
	head.add_child(ver)
	var x_gap := Control.new()
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	v.add_child(PanelDivider.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	visibility_changed.connect(func() -> void:
		if visible:
			reload())


## Pure: split a changelog into [{"kind": "h" | "b" | "p", "text": String}], dropping blank lines and the top title.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line == "" or line.begins_with("# "):
			continue
		if line.begins_with("## ") or line.begins_with("### "):
			out.append({"kind": "h", "text": line.lstrip("#").strip_edges()})
		elif line.begins_with("- ") or line.begins_with("* "):
			out.append({"kind": "b", "text": "- " + line.substr(2).strip_edges()})
		else:
			out.append({"kind": "p", "text": line})
	return out


func reload() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var text: String = FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else ""
	var rows: Array[Dictionary] = parse(text)
	if rows.is_empty():
		rows.append({"kind": "p", "text": "No update log yet."})
	for r: Dictionary in rows:
		var l := Label.new()
		l.text = String(r["text"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH - 12.0
		l.focus_mode = Control.FOCUS_ALL   # keyboard and pad can scroll through it
		if r["kind"] == "h":
			l.add_theme_color_override("font_color", RelicStyle.accent)
		elif r["kind"] == "b":
			l.add_theme_color_override("font_color", RelicStyle.text)
		else:
			l.add_theme_color_override("font_color", RelicStyle.dim)
		_list.add_child(l)
