extends RefCounted
## The 8-way walker facing and atlas cell maths (world/walker_pose.gd), and the atlas file it indexes. Pure logic
## apart from loading the atlas texture, so it runs headless.


func run(t: Object) -> void:
	# Octants: 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE (screen y points down).
	t.eq(WalkerPose.octant(Vector2(1, 0)), 0, "east is octant 0")
	t.eq(WalkerPose.octant(Vector2(1, 1)), 1, "down-right is SE")
	t.eq(WalkerPose.octant(Vector2(0, 1)), 2, "down is south")
	t.eq(WalkerPose.octant(Vector2(-1, 1)), 3, "down-left is SW")
	t.eq(WalkerPose.octant(Vector2(-1, 0)), 4, "west is octant 4")
	t.eq(WalkerPose.octant(Vector2(-1, -1)), 5, "up-left is NW")
	t.eq(WalkerPose.octant(Vector2(0, -1)), 6, "up is north")
	t.eq(WalkerPose.octant(Vector2(1, -1)), 7, "up-right is NE")
	t.eq(WalkerPose.octant(Vector2(3, 0.5)), 0, "a shallow move still reads as east")
	t.eq(WalkerPose.octant(Vector2.ZERO), -1, "no direction keeps the last facing")

	# Mirrors: SW, W and NW are the flipped SE, E and NE. The others are not flipped.
	for o: int in 8:
		var want: bool = o == 3 or o == 4 or o == 5
		t.eq(WalkerPose.flip_of(o), want, "octant %d flip" % o)
	t.eq(WalkerPose.base_of(3), WalkerPose.BASE_SE, "SW uses the SE art")
	t.eq(WalkerPose.base_of(4), WalkerPose.BASE_E, "W uses the side art")
	t.eq(WalkerPose.base_of(5), WalkerPose.BASE_NE, "NW uses the NE art")
	t.eq(WalkerPose.base_of(7), WalkerPose.BASE_NE, "NE uses the NE art, unflipped")
	t.ok(WalkerPose.is_side(0) and WalkerPose.is_side(4), "east and west are side poses")
	t.ok(not WalkerPose.is_side(2) and not WalkerPose.is_side(6), "south and north are not side poses")

	# Cell indices stay in the atlas, and each family sits in its own block.
	var seen: Dictionary = {}
	for o: int in 8:
		t.ok(WalkerPose.idle(o) < WalkerPose.BLINK, "idle %d is before the blink cell" % o)
		for p: int in 4:
			var w: int = WalkerPose.walk(o, p)
			var s: int = WalkerPose.sprint(o, p)
			t.ok(w >= WalkerPose.WALK and w < WalkerPose.SPRINT, "walk %d/%d in its block" % [o, p])
			t.ok(s >= WalkerPose.SPRINT and s < WalkerPose.PRESS_FRONT, "sprint %d/%d in its block" % [o, p])
			seen[w] = true
			seen[s] = true
	t.eq(seen.size(), 40, "walk and sprint give 40 distinct cells for the 5 drawn facings")
	t.eq(WalkerPose.walk(2, 4), WalkerPose.walk(2, 0), "the walk phase wraps every four frames")
	t.eq(WalkerPose.walk(0, -1), WalkerPose.walk(0, 3), "a negative phase wraps too")
	t.eq(WalkerPose.JUMP_SIDE_FALL, WalkerPose.CELL_COUNT - 1, "the last cell is the side jump fall")
	t.eq(WalkerPose.cell_at(0), Vector2i(0, 0), "cell 0 is the top left")
	t.eq(WalkerPose.cell_at(9), Vector2i(1, 1), "cells wrap to a new row every 8")
	t.eq(WalkerPose.cell_at(WalkerPose.JUMP_SIDE_FALL), Vector2i(6, 6), "the last cell sits in row 6")

	# The atlas file matches the layout the cells index into: 8 columns by 7 rows of 64 px.
	var atlas: Texture2D = load("res://assets/art/walker/walker_atlas.png") as Texture2D
	t.ok(atlas != null, "the walker atlas loads")
	if atlas != null:
		t.eq(atlas.get_width(), WalkerPose.COLS * 64, "atlas is 8 cells wide")
		t.eq(atlas.get_height(), 7 * 64, "atlas is 7 cells tall")
		t.ok(WalkerPose.CELL_COUNT <= WalkerPose.COLS * 7, "every cell fits in the atlas")
