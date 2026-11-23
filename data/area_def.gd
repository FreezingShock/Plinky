class_name AreaDef
extends Resource
## A named sub-area of a zone (a Larkmoor district, a clearing in the Meadow). Pure display and grouping data for the
## zone menu: pads still belong to the zone, an area only says which of them it lists. Files: content/areas/*.tres.

@export var id: StringName
@export var zone: StringName
@export var display_name: String
## Lowest order lists first inside its zone.
@export var order: int = 0
## One ASCII character shown before the name (Spleen has no icons). Keeps areas apart when colours are close.
@export var glyph: String = "*"
## Palette role (0 to 7, art-bible section 3) the area's text and bar use. Roles 3 to 7 read on the ink background.
@export_range(0, 7) var theme_role: int = 4
@export_multiline var blurb: String = ""
## Button ids listed in this area.
@export var pad_buttons: PackedStringArray = PackedStringArray()
