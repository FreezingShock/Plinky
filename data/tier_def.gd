class_name TierDef
extends Resource
## One flower tier: a row of three pads that all pay the same stat. A tier opens when the last pad of the tier below it
## (same zone, lower `order`) has been pressed once. Files: content/tiers/*.tres. Pads join a tier through ButtonDef.row.

@export var id: StringName
@export var display_name: String
## Position in the whole ladder, 1 (Sprout) to 6 (Starbloom). Within a zone the lowest order is open from the start.
@export var order: int = 1
@export var zone: StringName
## The stat every pad in this row pays.
@export var stat: StringName
## Rarity id (content/rarities): the tier's colour, the pad's ring, and the colour of the flower on the plate.
@export var rarity: StringName = &"common"
@export_multiline var blurb: String = ""
