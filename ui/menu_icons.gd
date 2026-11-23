class_name MenuIcons
extends RefCounted
## 9x9 one-colour pixel icons for the title menu buttons, drawn texel by texel. Every icon is exactly
## mirror-symmetric left to right, with clean 1:1 and 2:1 diagonals (docs/art-bible.md).

const SIZE: int = 9
const BITS: Dictionary = {
	"play": ["#........", "###......", "#####....", "#######..", "#########", "#######..", "#####....", "###......", "#........"],
	"new": ["...###...", "...###...", "...###...", "#########", "#########", "#########", "...###...", "...###...", "...###..."],
	"saves": ["..#####..", ".#.....#.", "#########", "#.......#", "#########", "#.......#", "#########", ".#.....#.", "..#####.."],
	"settings": ["....#....", ".#.###.#.", "..#####..", ".###.###.", "###...###", ".###.###.", "..#####..", ".#.###.#.", "....#...."],
	"log": ["#########", "#.......#", "#.#####.#", "#.......#", "#.#####.#", "#.......#", "#.#####.#", "#.......#", "#########"],
	"credits": [".##...##.", "####.####", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........."],
	"quit": ["....#....", "..#.#.#..", ".#..#..#.", ".#..#..#.", "#.......#", "#.......#", ".#.....#.", "..#...#..", "...###..."],
	"delete": ["#.......#", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#...#..", ".#.....#.", "#.......#"],
	"back": ["....#....", "...##....", "..###....", ".########", "#########", ".########", "..###....", "...##....", "....#...."],
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
