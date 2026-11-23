class_name PadPointerShape
extends RefCounted
## Geometry of the first-pad arrow, kept apart from PadPointer so tests can load it without the autoloads.

const BOB_PX: float = 3.0
const ARROW_H: float = 7.0   ## rows of the arrow, tip at the bottom
const PAD_HALF_HEIGHT: float = 7.0  ## TexelPad.HALF.y, copied so this file needs no autoloads
const TIP_GAP: float = 9.0   ## texels from the pad centre up to the arrow tip at rest (the pad is 14 wide, 7 tall each way)


## Y of the arrow tip relative to the pad centre, for a bob of 0 to BOB_PX texels (up is negative).
static func tip_y(bob: float) -> float:
	return -TIP_GAP - bob
