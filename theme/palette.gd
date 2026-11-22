class_name PlinkyPalette
## Palette tokens. Index roles are identical in every zone (art-bible section 3).
## 0 ink, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper.
const ZONES := {
	"meadow": ["14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9"],
	"quarry": ["1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "b77a7a", "5b3d5c", "f1d9b5"],
	"tidewater": ["0d1420", "13324a", "1f6378", "46a3a0", "9fd4b5", "f7d37a", "e67e6b", "dfeee8"],
	"iris": ["0c0a14", "2a1d4a", "5d3f9c", "a68be0", "f5d46b", "f7f3ea", "bfe6ef", "f0a9c2"],
}
## Semantic roles -> palette index. UI code asks for roles, never raw indices.
const ROLE := {
	"ink": 0, "panel_edge": 3, "panel_title": 4, "text": 7, "text_dim": 3,
	"accent": 5, "good": 4, "warn": 6, "bar_fill": 3, "bar_full": 4, "bar_empty": 2, "bar_timer": 6,
}
static func color(zone: String, index: int) -> Color:
	return Color.html("#" + ZONES[zone][index])
static func role(zone: String, name: String) -> Color:
	return color(zone, ROLE[name])
