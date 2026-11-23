class_name AreaIcons
extends RefCounted
## 7x7 one-colour pixel icons for areas (AreaDef.icon), drawn texel by texel in the row's palette colour.

const SIZE: int = 7
const BITS: Dictionary = {
	"grass": ["#..#..#", "#.#.#.#", ".#.#.#.", ".#.#.#.", "..###..", "..###..", "......."],
	"lake": [".......", ".......", ".##.##.", "#..#..#", ".......", ".##.##.", "#..#..#"],
	"flower": [".#.#.#.", "..###..", "...#...", "...#...", ".#.#.#.", "..###..", "...#..."],
	"tree": ["..###..", ".#####.", "#######", ".#####.", "...#...", "...#...", "..###.."],
	"cairn": [".......", "...#...", "..###..", ".#####.", "..###..", ".#####.", "#######"],
	"lantern": ["...#...", "..###..", ".#####.", ".#.#.#.", ".#####.", "..###..", "...#..."],
	"tower": ["#.#.#.#", "#######", ".#####.", ".##.##.", ".#####.", ".##.##.", "#######"],
	"clearing": [".......", "..#.#..", ".#...#.", ".......", ".#...#.", "..#.#..", "......."],
	"stones": [".......", ".#..#..", ".#..#..", ".#.##.#", "##.##.#", "##.##.#", "......."],
	"forge": [".......", "#######", ".#####.", "..###..", "..###..", ".#####.", "#######"],
}


static func has(id: String) -> bool:
	return BITS.has(id)


## Draws icon `id` with its top-left at `at` on canvas item `item`.
static func draw(item: CanvasItem, id: String, at: Vector2, color: Color) -> void:
	var rows: Array = BITS.get(id, []) as Array
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				item.draw_rect(Rect2(at.x + x, at.y + y, 1, 1), color)
