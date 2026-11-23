class_name FeedbackPanel
extends PanelContainer
## Tester feedback form (F8, or Feedback in the settings panel). Notes save to user://feedback.txt.
## Copy puts the whole file on the clipboard; Open folder shows it. Nothing leaves the machine.

var _sim: Sim
var _edit: TextEdit
var _status: Label


func bind(sim: Sim) -> void:
	_sim = sim
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Feedback"
	v.add_child(title)

	var hint := Label.new()
	hint.custom_minimum_size.x = 300
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.text = "What was fun, confusing or broken? Notes save on this computer only. Copy them and send them to Nathan."
	v.add_child(hint)

	_edit = TextEdit.new()
	_edit.custom_minimum_size = Vector2(300, 90)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.tab_input_mode = false   # Tab moves focus on instead of trapping it
	_edit.placeholder_text = "Type a note..."
	v.add_child(_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	_button(row, "Save note", _on_save)
	_button(row, "Copy all", _on_copy)
	_button(row, "Open folder", _on_open_folder)

	_status = Label.new()
	_status.custom_minimum_size.x = 300
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_status)



func open() -> void:
	_refresh_status("")
	visible = true
	reset_size()
	await get_tree().process_frame
	position = ((get_parent_area_size() - size) * 0.5).floor()
	_edit.grab_focus()


func close() -> void:
	visible = false
	_edit.release_focus()


func context_line() -> String:
	var mins: float = Time.get_ticks_msec() / 60000.0
	return "v%s | %s | %d rebirths | session %.1f min" % [BuildInfo.VERSION, String(_sim.zone_id), _sim.rebirth_count, mins]


func _on_save() -> void:
	if FeedbackLog.append(_edit.text, context_line()):
		_edit.text = ""
		_refresh_status("Saved.")
	else:
		_refresh_status("Nothing saved. Type a note first.")


func _on_copy() -> void:
	var text: String = FeedbackLog.read_all()
	if text.is_empty():
		_refresh_status("No saved notes yet.")
		return
	DisplayServer.clipboard_set(text)
	_refresh_status("Copied %d notes to the clipboard." % FeedbackLog.entry_count())


func _on_open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _refresh_status(prefix: String) -> void:
	var n: int = FeedbackLog.entry_count()
	_status.text = ("%s %d saved." % [prefix, n]).strip_edges()


func _button(parent: Node, label: String, on_press: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.text = label
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
