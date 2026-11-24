class_name WalkerPose
extends RefCounted
## Picks the walker's atlas cell and mirror flag from its facing, in 8 directions. Pure logic (no nodes), so
## tests/run.gd can check every facing and cell. The atlas (assets/art/walker/walker_atlas.png, 8 columns of 64 px)
## is drawn by tools/art/gen_walker.py, which lists the same cell numbers. Change both together.
## Five facings are drawn (E, SE, S, NE, N). SW, W and NW are the mirrors of SE, E and NE, drawn with a flip.

const COLS: int = 8
const BASE_E: int = 0          ## side, facing right
const BASE_SE: int = 1         ## three-quarter front, facing down-right
const BASE_S: int = 2          ## front
const BASE_NE: int = 3         ## three-quarter back, facing up-right
const BASE_N: int = 4          ## back
const IDLE: int = 0            ## + base
const BLINK: int = 5           ## front blink
const WALK: int = 6            ## + base * 4 + phase
const SPRINT: int = 26         ## + base * 4 + phase
const PRESS_FRONT: int = 46
const PRESS_SIDE: int = 47
const CROUCH_FRONT: int = 48
const CROUCH_SIDE: int = 49
const SLIDE: int = 50
const JUMP_FRONT_RISE: int = 51
const JUMP_FRONT_FALL: int = 52
const JUMP_SIDE_RISE: int = 53
const JUMP_SIDE_FALL: int = 54
const CELL_COUNT: int = 55
const PHASES: int = 4

## Octant 0 is east, then clockwise on screen (y points down): 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE.
const OCT_BASE: Array[int] = [BASE_E, BASE_SE, BASE_S, BASE_SE, BASE_E, BASE_NE, BASE_N, BASE_NE]
const OCT_FLIP: Array[bool] = [false, false, false, true, true, true, false, false]
const DEFAULT_OCTANT: int = 2  ## south, the way the walker starts


## The octant (0..7) of a move direction, or -1 for no direction (the caller keeps its last facing).
static func octant(dir: Vector2) -> int:
	if dir == Vector2.ZERO:
		return -1
	return posmod(roundi(atan2(dir.y, dir.x) / (PI / 4.0)), 8)


static func base_of(oct: int) -> int:
	return OCT_BASE[posmod(oct, 8)]


static func flip_of(oct: int) -> bool:
	return OCT_FLIP[posmod(oct, 8)]


static func is_side(oct: int) -> bool:
	return base_of(oct) == BASE_E


static func idle(oct: int) -> int:
	return IDLE + base_of(oct)


static func walk(oct: int, phase: int) -> int:
	return WALK + base_of(oct) * PHASES + posmod(phase, PHASES)


static func sprint(oct: int, phase: int) -> int:
	return SPRINT + base_of(oct) * PHASES + posmod(phase, PHASES)


## Atlas cell index to (column, row), as WalkerBody draws it.
@warning_ignore("integer_division")
static func cell_at(index: int) -> Vector2i:
	return Vector2i(index % COLS, index / COLS)
