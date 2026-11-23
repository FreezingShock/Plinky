class_name PadGlow
extends Node
## Pad glow that drifts colour as the multiplier climbs, so progress shows in
## the world, not just the HUD. Colours are PALETTE INDICES (art-bible section 3),
## so every zone re-tints it for free. Set .multiplier; read current_color().

const STEPS := [
	{"at": 1.0, "idx": 3},
	{"at": 5.0, "idx": 4},
	{"at": 25.0, "idx": 5},
	{"at": 100.0, "idx": 6},
	{"at": 1000.0, "idx": 7},
]
signal color_changed(index: int)

## Relic drop flash: Epic and above flash the pressed pad in the rarity colour.
## Fixed hex (not palette indices) because rarity colours are the same in every zone.
const RARITY_FLASH := {
	&"epic": Color("AA00AA"), &"legendary": Color("FFAA00"), &"mythic": Color("FF55FF"),
	&"divine": Color("55FFFF"), &"special": Color("FF5555"),
}
const FLASH_TIME := 0.45
var flash_color := Color.WHITE
var flash_t := 0.0   # 1 -> 0; 0 means no flash

## Call with the dropped relic's rarity id (lowercase). Common to Rare do nothing.
## Returns true if a flash started. Respects reduce-flashing.
func flash_rarity(rarity: StringName) -> bool:
	if FxConfig.reduce_flashing or not RARITY_FLASH.has(rarity):
		return false
	flash_color = AccessOptions.tint(RARITY_FLASH[rarity] as Color)
	flash_t = 1.0
	return true

## Colour to draw the pad with this frame. Alternates flash colour and base every
## 2 frames-worth of time (hard steps, no blending) until it ends.
func pad_color(palette: PackedColorArray) -> Color:
	var base := current_color(palette)
	if flash_t <= 0.0:
		return base
	return flash_color if int(flash_t * 8.0) % 2 == 1 or flash_t > 0.75 else base

func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t = maxf(flash_t - delta / FLASH_TIME, 0.0)

var multiplier := 1.0:
	set(v):
		multiplier = maxf(v, 1.0)
		_update()
var color_index := 3
var next_index := 3
var blend := 0.0
var glow_strength := 0.2  # 0..1, drives ring size and brightness

func _update() -> void:
	var lo := 0
	for i in STEPS.size():
		if multiplier >= STEPS[i].at:
			lo = i
	var hi := mini(lo + 1, STEPS.size() - 1)
	blend = 0.0 if hi == lo else clampf(log(multiplier / STEPS[lo].at) / log(STEPS[hi].at / STEPS[lo].at), 0.0, 1.0)
	next_index = STEPS[hi].idx
	glow_strength = clampf(0.2 + 0.8 * log(multiplier) / log(1000.0), 0.2, 1.0)
	var new_idx: int = STEPS[lo].idx
	if new_idx != color_index:
		color_index = new_idx
		color_changed.emit(color_index)

## palette = the active zone's 8 colours. Blend is stepped to 8 levels (pixel feel).
func current_color(palette: PackedColorArray) -> Color:
	return palette[color_index].lerp(palette[next_index], snappedf(blend, 0.125))
