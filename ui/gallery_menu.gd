class_name GalleryMenu
extends PanelContainer
## The hamburger menu, which is also the Esc / pause menu: a gallery of icon tiles (every tile always shows its name), one per section, with the build version in the header.
## Picking a tile emits `chosen(kind)`; Main routes it through MenuRouter (so the gallery closes and the section
## opens) and the shared CloseX closes this one. Tiles are ordinary focusable buttons, so arrows, d-pad, Enter and
## pad A all work, and Main's menu focus drops focus onto the first tile when it opens.

signal chosen(kind: StringName)
## Footer actions. Main wires them (Resume closes the menu; the quits save first).
signal resume_requested
signal quit_to_title_requested
signal quit_game_requested

const COLUMNS: int = 3
const GAP: int = 4
## kind, label, icon file under assets/icons/big/
const ENTRIES: Array = [
	[&"stats", "Stats", "menu_stats"],
	[&"attributes", "Attributes", "menu_attributes"],
	[&"upgrades", "Upgrades", "menu_upgrades"],
	[&"relics", "Relics", "menu_relics"],
	[&"travel", "Travel", "menu_travel"],
	[&"settings", "Settings", "menu_settings"],
	[&"history", "History", "menu_history"],
	[&"ledger", "Ledger", "menu_ledger"],
	[&"log", "Update Log", "menu_log"],
]

## Section colours, the same fixed stat colours the gallery cards use: Cash gold, Multiplier blue and so on.
const COLORS: Dictionary = {
	&"stats": Color("f2c94c"), &"attributes": Color("55aaff"), &"upgrades": Color("7be08a"), &"relics": Color("c77dff"),
	&"travel": Color("6fd6e8"), &"settings": Color("f6efd9"), &"log": Color("9ee2c0"), &"history": Color("ff9f5a"), &"ledger": Color("f2c94c"),
}

## Set by Main: kind -> true while that section is still locked by the tutorial.
var is_locked: Callable = Callable()
var _tiles: Dictionary = {}   # kind -> GalleryTile
var _clock: float = 0.0
var _resume: MenuTextButton


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
	title.text = "Menu"
	head.add_child(title)
	var ver := Label.new()
	ver.text = version_text()
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_color_override("font_color", RelicStyle.dim)
	head.add_child(ver)
	var x_gap := Control.new()   # room for the close X floating in the corner
	x_gap.custom_minimum_size = Vector2(CloseX.SIZE, 1.0)
	head.add_child(x_gap)
	v.add_child(PanelDivider.new())
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	v.add_child(grid)
	for e: Array in ENTRIES:
		var tile := GalleryTile.new()
		tile.kind = e[0]
		tile.label = e[1]
		tile.accent = COLORS.get(e[0], Color(0, 0, 0, 0)) as Color
		tile.big_icon = load("res://assets/icons/big/%s.png" % e[2]) as Texture2D
		var k: StringName = e[0]
		tile.pressed.connect(func() -> void: chosen.emit(k))
		grid.add_child(tile)
		_tiles[k] = tile
	v.add_child(PanelDivider.new(2))
	# Text actions, kept visually apart from the icon tiles: Resume in the good green, the quits in the accent.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 4)
	v.add_child(actions)
	_resume = _action("Close Menu", RelicStyle.good, func() -> void: resume_requested.emit())
	actions.add_child(_resume)
	actions.add_child(_action("Quit To Title", RelicStyle.accent, func() -> void: quit_to_title_requested.emit()))
	actions.add_child(_action("Quit Game", RelicStyle.accent, func() -> void: quit_game_requested.emit()))
	var hint := Label.new()
	hint.text = "Esc closes the menu."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(hint)


func _action(text: String, accent: Color, on_press: Callable) -> MenuTextButton:
	var b := MenuTextButton.new()
	b.label = text
	b.rest_color = RelicStyle.text
	b.accent_color = accent
	b.pressed.connect(on_press)
	return b


func resume_button() -> MenuTextButton:
	return _resume


static func version_text() -> String:
	return BuildInfo.string()


func tile(kind: StringName) -> GalleryTile:
	return _tiles.get(kind) as GalleryTile


func _process(delta: float) -> void:
	if not visible or not is_locked.is_valid():
		return
	_clock += delta
	if _clock < 0.1:
		return
	_clock = 0.0
	for k: StringName in _tiles:
		(_tiles[k] as GalleryTile).disabled = bool(is_locked.call(k))
