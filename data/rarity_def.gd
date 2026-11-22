class_name RarityDef
extends Resource
## One relic rarity tier. Content lives in content/rarities/*.tres.
## Colours are fixed (Minecraft colour codes as Hypixel SkyBlock uses them), NOT palette roles,
## so a tier reads the same in every zone.

@export var id: StringName
@export var display_name: String
## Minecraft colour code letter, for docs and debugging.
@export var mc_code: String = "f"
@export var color: Color = Color.WHITE
## Relative drop weight. 0 means never rolled randomly (Special: granted by events or achievements).
@export var weight: float = 1.0
## Order in lists. 0 = Common ... 7 = Special.
@export var rank: int = 0
## 20x20 frame art (art/icons/rarity). A 16x16 icon sits inside at offset (2, 2).
@export var frame: Texture2D

## The tier colour, lightened toward white until it reaches `min_ratio` contrast on `bg`.
## Rare (#5555FF) and Epic (#AA00AA) are too dark for text on the ink panel, so text uses this; frames keep the exact colour.
func readable_color(bg: Color, min_ratio: float = 4.5) -> Color:
	var c: Color = color
	for i in 12:
		if _contrast(c, bg) >= min_ratio:
			return c
		c = c.lerp(Color.WHITE, 0.12)
	return c

static func _lum(c: Color) -> float:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)

static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
