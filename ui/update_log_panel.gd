class_name UpdateLogPanel
extends PanelContainer
## The Update Log: BuildInfo.changelog() (CHANGELOG.md), newest first, in a scrolling themed panel with the version
## in the header. Version headings are accented, notes wrap. No entries shows a short note instead of an empty box.

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


## Pure: flatten BuildInfo.changelog() entries into display rows, newest first:
## [{"kind": "h" | "b", "text": String}]. A heading is "v0.5.0  2026-11-23" (no date when there is none).
static func rows_from(entries: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var head: String = "v%s" % e["version"]
		if String(e["date"]) != "":
			head += "  %s" % e["date"]
		out.append({"kind": "h", "text": head})
		for n: String in e["notes"]:
			out.append({"kind": "b", "text": "- " + n})
	return out


func reload() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var rows: Array[Dictionary] = rows_from(BuildInfo.changelog())
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
