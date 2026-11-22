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
