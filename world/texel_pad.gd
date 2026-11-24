class_name TexelPad
extends Node2D
## A pressable pad anchored on the baked meadow art. Standing on it, or holding the mouse on it, presses at the player's press rate.
## The art already shows the pad; this adds the live ring and the press logic. Cost and reward show in PadTooltip on hover.

const HALF: Vector2 = Vector2(14.0, 7.0)  # pad half extents in texels (2:1 diamond)

var button_id: StringName
var walker: Node2D  # a TexelWalker; typed loosely so this script compiles under --script
var glow: PadGlow
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var standing: bool = false
var affordable: bool = false
## True while the mouse is held down on this pad (hold-to-press). Read by main for Juice.
var holding: bool = false
## One press clock for both ways of pressing (a walker standing on the pad, or the mouse held on it), so they run at the same rate.
var _press_clock := PadPressTimer.new()
## Set by main each frame: the mouse is over this pad and not over the HUD.
var hovered: bool = false
## 0..1 of the cost you hold (see _refresh_progress). Drives the gauge and the Far / Close / Ready look.
var progress: float = 0.0

## Buy state colours are fixed hex (like rarity colours): green = you can buy, red = you can't. Not palette-tinted, so they read in every zone.
## Secondary colour = the stat this pad raises. Unknown stats fall back to paper.
const STAT_COLORS: Dictionary = {
	&"dewdrop": Color("e4f1ff"), &"clover": Color("6be86b"), &"thistle": Color("7f9bff"),
	&"heather": Color("c27cff"), &"foxglove": Color("ffb62e"), &"starbloom": Color("ff7bff"),
	&"cinder": Color("d6cfc4"), &"reb": Color("c77dff"), &"slag": Color("5fb0e0"), &"ironore": Color("5fb26a"),
	&"ingot": Color("a07ee0"), &"alloy": Color("e8b43a"), &"emberheart": Color("ff5aa0"),
}
## One standing flower per tier, 13 texels wide, drawn bottom-up from the plate centre: # petal (stat colour), d shaded
## petal, c bright heart, g stem and leaf. Each has its own silhouette so the six tiers read apart at 1x.
const FLOWERS: Dictionary = {
	&"sprout": ["......c......", ".....ccc.....", "....ccWcc....", ".....ccc.....", "......g......", "..gg..g..gg..", ".gggg.g.gggg.", ".ggggggggggg.", "..ggg.g.ggg..", "......g......"],
	&"clover": ["..###...###..", ".#####.#####.", ".##d##.##d##.", "..###.c.###..", "...d.#g#.d...", "..###.g.###..", ".#####g#####.", ".##d##g##d##.", "..###.g.###..", "......g......"],
	&"thistle": ["#..#..#..#..#", ".#.#.#.#.#.#.", "..###ccc###..", "..d#######d..", "..d#######d..", "...ddd#ddd...", "..g..ggg..g..", ".gg...g...gg.", "..ggg.g.ggg..", "......g......"],
	&"heather": ["......#......", ".....#d#.....", "....#d.d#....", ".....#d#.....", "...#d.g.d#...", "..#d#.g.#d#..", "...d..g..d...", "..#d#.g.#d#..", ".....ggg.....", "......g......"],
	&"foxglove": ["......#......", ".....###.....", ".....#c#.....", "....#####....", "....#d.d#....", "...#######...", "...#d...d#...", "..#########..", "..#d.ggg.d#..", "....g.g.g...."],
	&"starbloom": ["......#......", ".....###.....", "....#####....", "#############", ".###########.", "..####c####..", "...#######...", "..###...###..", ".###..g..###.", "......g......"],
}
## The Ember Quarry rows stand on their plate as small isometric voxel objects (tools/art/gen_quarry_ladder.py), three flicker
## frames each. Tier id -> art name.
## Larkmoor rows with their own tiers (so their unlocks stay apart from the meadow) that stand on a meadow flower.
const FLOWER_OF: Dictionary = {&"lark_sprout": &"sprout", &"lark_clover": &"clover"}
const FORGE_ART: Dictionary = {&"cinder": "cinder", &"ore": "ore", &"slagrow": "slag", &"ingot": "ingot", &"alloy": "alloy", &"emberheart": "ember"}
const FORGE_DIR: String = "res://assets/art/zone2/ladder/"
const FLICKER_MS: int = 260
static var _forge_tex: Dictionary = {}   # "name_f" -> Texture2D
## Pad 2's side sprouts (x, y from the plate base, kind): a small bloom on a stem.
const BUD: Array[Vector3i] = [Vector3i(0, -4, 0), Vector3i(-1, -3, 0), Vector3i(1, -3, 0), Vector3i(0, -3, 2), Vector3i(0, -2, 3), Vector3i(0, -1, 3), Vector3i(-1, -1, 3), Vector3i(1, -2, 3)]
const LEAF: Color = Color("3d9a45")
const BLOOM_TIME: float = 0.9   # the rise when this pad's tier opens
var tier_row: StringName = &""
## The flower this pad stands on (FLOWERS key). The Larkmoor Sprout and Clover rows are their own tiers, so they draw the meadow flowers.
var flower_row: StringName = &""
var locked: bool = false
## Cost chip under a locked row's first pad: the pad's cost and its stat icon, so a closed row shows what it takes before it is pressed.
const LOCK_FONT: Font = preload("res://fonts/spleen-5x8.fnt")
const LOCK_SIZE: int = 8          # the font's native size: one glyph texel per screen texel (16 doubled it and filled the chip with ink)
const LOCK_ICON: int = 8          # the stat icon's staged size, the same 8 px as the text
const LOCK_GAP: int = 2           # texels between the icon and the cost digits
const LOCK_DIGIT_GAP: int = 1     # texels between one digit and the next
const LOCK_TOP: int = -6          # the chip's top edge, in pad-local texels: centred on the top face (origin)
const CHIP_CREAM: Color = Color("f6efd9")
var _lock_cost: String = ""       # the cost text, e.g. "300"; empty when this pad carries no chip
var _lock_icon: Texture2D = null  # the cost stat's 8 px icon, or null when the stat has none
## Clover pads get a gold rim (not the grass green Sprout and Clover share), so the two rows read apart on the lake shore.
const CLOVER_TRIM: Color = Color("f2c14e")
var _trim: Color = Color(0.0, 0.0, 0.0, 0.0)
var _bloom_t: float = 0.0   # 1 -> 0 after the tier opens: the flower rises and bursts into petals
var rarity: RarityDef
var emblem_bits: int = 0  # 15 bits: the unique pattern for this pad
var stat_color: Color = Color("f6efd9")

enum PadState { FAR, CLOSE, READY }
const THICK: int = 3                 # slab thickness in texels at rest
const FAR_BELOW: float = 0.1         # under this share of the cost the pad looks inert (stone, no gauge)
const PUNCH_TIME: float = 0.16       # sink recovers in whole-texel steps over this long
const LEVEL_TIME: float = 0.8
const RING_TIME: float = 0.3         # the ripple that leaves the pad on a press
const NEAR_TEXELS: float = 40.0      # the approach cue starts this far from the pad (vertical doubled)
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

signal left  ## the walker stepped off, or the mouse was released
var _punch_t: float = 0.0   # 1 -> 0 after a press
var _lvl_t: float = 0.0     # 1 -> 0 after a mastery level-up
var _ring_t: float = 1.0    # 0 -> 1 ripple; 1 = idle
var _punch_extra: int = 0   # 0 or 1 extra texel of sink for crits and high streak tiers
var _shake_t: float = 0.0   # 1 -> 0: the pad itself shakes sideways one texel (instead of the camera)
var _ring_tint: Color = Color(0.0, 0.0, 0.0, 0.0)   # streak tier colour for the ripple; alpha 0 = the plain palette ripple
var _progress_t: float = 0.0
var _sig: int = -1          # what was last drawn; redraw only when it changes


## The GameState autoload, looked up by path so this script also compiles under --script (tests have no autoloads).
func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")


func _sim() -> Sim:
	var g: Node = _gs()
	return g.get("sim") as Sim if g != null else null


func _ready() -> void:
	position = position.round()  # anchors are fractional; a plate drawn between texels would not sit on the world's grid
	emblem_bits = absi(String(button_id).hash()) & 0x7FFF
	rarity = load("res://content/rarities/%s.tres" % _sim().pad_rarity(button_id)) as RarityDef
	var b: ButtonDef = _sim().button_defs.get(button_id) as ButtonDef
	if b != null:
		stat_color = AccessOptions.tint(STAT_COLORS.get(b.reward_stat, stat_color) as Color)
		tier_row = b.row
		flower_row = FLOWER_OF.get(tier_row, tier_row) as StringName
		if b.row_index == 0:
			# A button's cost depends only on its definition, so the chip text is fixed for the pad's life.
			_lock_cost = Formulas.button_cost(b).format()
			_lock_icon = IconSet.get_icon(String(b.cost_stat), LOCK_ICON)
		if tier_row == &"lark_clover":
			_trim = CLOVER_TRIM
			stat_color = CLOVER_TRIM   # gems and pip take the Clover gold, not the Clover reward green
	if b != null and _sim().has_signal(&"tier_opened"):
		_sim().tier_opened.connect(_on_tier_opened)


func _on_tier_opened(tier_id: StringName) -> void:
	if tier_id == tier_row:
		_bloom_t = 1.0


func _physics_process(delta: float) -> void:
	var sim: Sim = _sim()
	var d: Vector2 = walker.position - position
	var inside: bool = (d.x * d.x) / (HALF.x * HALF.x) + (d.y * d.y) / (HALF.y * HALF.y) <= 1.0
	if inside and bool(walker.get("airborne")):
		inside = false   # a jump clears the plate; landing on it presses at once
	if inside and not standing and not holding:
		_press_clock.arm()  # first press is immediate on arrival
	if standing and not inside:
		left.emit()
	standing = inside
	affordable = sim.can_afford(button_id)
	locked = sim.is_pad_locked(button_id)
	_progress_t -= delta
	if _progress_t <= 0.0:
		_progress_t = 0.2
		_refresh_progress(sim)
	_punch_t = maxf(_punch_t - delta / PUNCH_TIME, 0.0)
	_lvl_t = maxf(_lvl_t - delta / LEVEL_TIME, 0.0)
	_bloom_t = maxf(_bloom_t - delta / BLOOM_TIME, 0.0)
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta / 0.2, 0.0)
		queue_redraw()
	if _ring_t < 1.0:
		_ring_t = minf(_ring_t + delta / RING_TIME, 1.0)
	if _press_clock.step(delta, inside or holding, sim.press_interval()):
		_press()
	var sig: int = _signature()
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _press() -> void:
	_gs().try_press(button_id, Vector3(global_position.x, global_position.y, 0.0))


## Click a pad to press it; hold to keep pressing at the same rate a standing walker gets (Sim.press_interval).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if GuiGuard.covers(get_tree().root, event.position):
			return   # a click on any GUI (panel, HUD, tooltip) never presses a pad under it
		if hit((get_parent() as Node2D).get_local_mouse_position()):
			holding = true
			_press()
			_press_clock.start(_sim().press_interval())
			get_viewport().set_input_as_handled()
	elif holding:
		hold_release()


## Mouse released on a held pad: the stacked popup holds, then floats off, and the walker-style left signal fires.
func hold_release() -> void:
	holding = false
	PressPopups.release_runs()
	left.emit()


## True if a point in this pad's parent space is over the pad (slightly generous, for hover and clicks).
func hit(p: Vector2, slack: float = 1.3) -> bool:
	var d: Vector2 = p - position
	var h: Vector2 = HALF * slack
	return (d.x * d.x) / (h.x * h.x) + (d.y * d.y) / (h.y * h.y) <= 1.0


## Called by Juice on every press. Restarts the sink and ripple, so spam-pressing never stacks tweens or drifts the pad.
## tint (alpha above 0) recolours the ripple with the press streak tier's colour.
## power (0 to 2) is how hard the press lands: 1 sinks one texel deeper, and any power shakes the pad itself.
func punch(tint: Color = Color(0.0, 0.0, 0.0, 0.0), power: int = 0) -> void:
	_punch_t = 1.0
	_ring_t = 0.0
	_ring_tint = tint
	_punch_extra = 1 if power >= 1 else 0
	_shake_t = float(power) * 0.5 if not (FxConfig.reduce_shake or FxConfig.reduce_flashing) else 0.0


## Mastery level-up: two gold rings spread from the plate (hard steps, no blending). Quiet under reduce flashing.
func level_flash() -> void:
	_lvl_t = 1.0
	_sig = -1


## -1, 0 or +1 texel sideways while the pad shakes: a hard-stepped buzz, 30 steps a second.
func _shake_step() -> int:
	if _shake_t <= 0.0:
		return 0
	return 1 if int(_shake_t * 30.0) % 2 == 0 else -1


func _level_step() -> int:
	return 0 if _lvl_t <= 0.0 else 1 + int((1.0 - _lvl_t) * 7.0)


func _refresh_progress(sim: Sim) -> void:
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		progress = 0.0
		return
	if affordable:
		progress = 1.0
		return
	var cost: BigNum = Formulas.button_cost(b)
	progress = 1.0 if cost.is_zero() else clampf(sim.get_stat(b.cost_stat).div(cost).to_float(), 0.0, 1.0)


func pad_state() -> PadState:
	if affordable:
		return PadState.READY
	return PadState.FAR if progress < FAR_BELOW else PadState.CLOSE


## Whole texels of sink: 0 at rest, 1 while standing or hovered-and-held, 2 on the punch, stepping back up.
func sink_texels() -> int:
	var s: int = 0
	if standing or holding:
		s = 1
	return mini(maxi(s, ceili(_punch_t * float(FxConfig.PRESS_SINK_TEXELS + _punch_extra))), THICK)


## 0 (far) .. 2 (on the plate): the approach cue brightens the rim as the walker gets close.
func nearness() -> int:
	var d: Vector2 = walker.position - position
	var dist: float = Vector2(d.x, d.y * 2.0).length()
	if standing:
		return 3
	if dist < NEAR_TEXELS * 0.5:
		return 2
	return 1 if dist < NEAR_TEXELS else 0


func _ripple_step() -> int:
	return -1 if _ring_t >= 1.0 else int(_ring_t * 6.0)


func _pulse_step() -> int:
	if FxConfig.reduce_flashing or not affordable:
		return 0
	return floori(float(Time.get_ticks_msec()) / 250.0) % 4


## Everything the picture depends on, packed. _draw runs only when this changes (perf.md rule 1).
func _signature() -> int:
	return (int(pad_state()) | sink_texels() << 2 | int(hovered) << 4 | nearness() << 5 | (_ripple_step() + 1) << 7
		| _pulse_step() << 10 | int(progress * 8.0) << 12 | int(holding) << 16
		| _level_step() << 24 | int(locked) << 26 | int(_bloom_t * 10.0) << 27 | int(glow != null and glow.flash_t > 0.0) << 17 | (glow.color_index if glow != null else 0) << 18
		| _forge_frame() << 32 | _twinkle() << 36)


func _rows(cx: int, cy: int, hx: int, hy: int, left: Color, right: Color) -> void:
	for dy in range(-hy, hy + 1):
		var w: int = roundi(float(hx) * (1.0 - absf(float(dy)) / (float(hy) + 0.5)))
		draw_rect(Rect2(cx - w, cy + dy, w + 1, 1), left)
		if w > 0:
			draw_rect(Rect2(cx + 1, cy + dy, w, 1), right)


## Bayer-dithered highlight on the lit (upper-left) rim of the top face, pinned to world texels.
func _lit_rim(cy: int, hx: int, hy: int, col: Color) -> void:
	var o: Vector2i = Vector2i(position.round())
	for dy in range(-hy, 1):
		var w: int = roundi(float(hx) * (1.0 - absf(float(dy)) / (float(hy) + 0.5)))
		for k in 3:
			var x: int = -w + k
			var thr: int = 12 - k * 5
			if BAYER[((cy + dy + o.y) & 3) * 4 + ((x + o.x) & 3)] < thr:
				draw_rect(Rect2(x, cy + dy, 1, 1), col)


func _draw() -> void:
	draw_set_transform(Vector2(float(_shake_step()), 0.0))
	var st: PadState = pad_state()
	var sink: int = sink_texels()
	var lift: int = 1 if (hovered and sink == 0) else 0
	var th: int = THICK - sink
	var top: int = sink - lift          # y of the top face centre
	var hx: int = int(HALF.x)
	var hy: int = int(HALF.y)
	var ink: Color = palette[0]
	# Ripple on the ground, under the slab.
	var rs: int = _ripple_step()
	if rs >= 0:
		var g: float = 1.0 + 0.45 * float(rs + 1) / 6.0
		var rc: Color = palette[7] if rs < 4 else palette[4]
		if _ring_tint.a > 0.0:
			rc = _ring_tint if rs < 4 else _ring_tint.lightened(0.35)
		_outline(g, 0, rc)
	var ls: int = _level_step()
	if ls > 0:
		for k in 2:
			var g2: float = 1.0 + 0.2 * float(ls) + 0.35 * float(k)
			_outline(g2, 0, palette[7] if ((ls + k) % 2 == 0 and not FxConfig.reduce_flashing) else palette[5])
	if st == PadState.READY and not locked:
		_outline(1.18, 0, StatStyle.gain() if _pulse_step() < 2 else StatStyle.gain().lightened(0.4))   # a green halo on the ground: buyable reads from a distance
	# Ink silhouette (rule 6: one outline in palette 0) around the whole slab.
	for k in range(0, th + 1):
		_rows(0, top + k, hx + 1, hy + 1, ink, ink)
	# Side faces: lit left in earth, shaded right in shadow (rule 1: warm only where light hits).
	for k in range(1, th + 1):
		_rows(0, top + k, hx, hy, palette[1] if locked else palette[6], ink if locked else palette[1])
	# Top face.
	var face: Color = palette[6]
	var face_r: Color = palette[6]
	if st == PadState.FAR or locked:
		face = ink.lerp(palette[1], 0.45) if locked else palette[2]
		face_r = face
	_rows(0, top, hx, hy, face, face_r)
	if st != PadState.FAR:
		_lit_rim(top, hx, hy, _trim if _trim.a > 0.0 else palette[5])
	elif hovered:
		_lit_rim(top, hx, hy, palette[3])
	# Rim: brighter as the walker approaches or the mouse hovers.
	var near: int = nearness()
	var rim: Color = StatStyle.cant().darkened(0.3) if st != PadState.READY else StatStyle.gain()
	if _trim.a > 0.0 and st != PadState.READY:
		rim = _trim   # a buyable Clover pad keeps the buy-state green
	if near >= 2:
		rim = rim.lerp(Color.WHITE, 0.4)
	if hovered:
		rim = palette[7]
	_outline(1.0, top, rim)
	# Inset: green when buyable, red when not, with a green gauge filling as you earn the cost. Each pad has its own motif.
	var ihx: int = 10
	var ihy: int = 5
	var buy: Color = StatStyle.gain()
	if locked:
		var dull: Color = ink.lerp(palette[1], 0.25)
		_rows(0, top, ihx, ihy, dull, dull)
	elif st == PadState.READY:
		if glow != null and glow.flash_t > 0.0:
			buy = glow.pad_color(palette)   # relic drop flash
		if _pulse_step() == 0 and not FxConfig.reduce_flashing:
			buy = buy.lerp(Color.WHITE, 0.35)
		if sink >= 2 or standing:
			buy = Color.WHITE
		_rows(0, top, ihx, ihy, buy, buy)
	else:
		var red: Color = StatStyle.cant().darkened(0.45) if st == PadState.FAR else StatStyle.cant()
		_rows(0, top, ihx, ihy, red, red)
		if st == PadState.CLOSE:
			var cut: int = top + ihy - roundi(progress * float(ihy * 2 + 1))
			for dy in range(-ihy, ihy + 1):
				if top + dy < cut:
					continue
				var w: int = roundi(float(ihx) * (1.0 - absf(float(dy)) / (float(ihy) + 0.5)))
				draw_rect(Rect2(-w, top + dy, w * 2 + 1, 1), StatStyle.gain().darkened(0.2))
	# Rarity frame: a second ring just inside the rim in the tier colour (Common has none). Legendary adds corner studs.
	if rarity != null and rarity.rank > 0:
		_dashed_diamond(0.86, top, _trim if _trim.a > 0.0 else rarity.tint())  # dashed, so Uncommon green never reads as the buy-state green
		if rarity.rank >= 4:
			for c: Vector2i in [Vector2i(-hx + 4, 0), Vector2i(hx - 4, 0), Vector2i(0, -hy + 2), Vector2i(0, hy - 2)]:
				draw_rect(Rect2(c.x, top + c.y, 1, 1), Color.WHITE)
	if FORGE_ART.has(tier_row):
		_draw_forge(top, ink)
	elif FLOWERS.has(flower_row):
		_draw_flowers(top, ink)
	else:
		_draw_emblem(top, ink)
	# Stat colour: a gem on each corner of the plate plus a centre pip.
	for g: Vector2i in [Vector2i(-hx + 2, 0), Vector2i(hx - 2, 0), Vector2i(0, -hy + 1), Vector2i(0, hy - 1)]:
		draw_rect(Rect2(g.x - 1, top + g.y, 3 if g.y == 0 else 3, 1), stat_color)
	# Shape cue for colour-blind players: a tick when buyable, an X when not.
	var glyph: Array[Vector2i] = []
	if st == PadState.READY:
		glyph.assign([Vector2i(-2, 0), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(1, -1), Vector2i(2, -2)])
	else:
		glyph.assign([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, 1)])
	for q: Vector2i in glyph:
		draw_rect(Rect2(q.x, top + q.y, 1, 1), ink)
	_outline(0.6, top, ink)
	if standing:
		_outline(0.38, top, palette[7])
	# A locked row's first pad shows its cost and stat icon beside the plate, on the right, not under it: the walker
	# stands on the plate and would cover a chip under its feet. 8 px icon and digits on a cream chip with an ink border.
	# Whole texels throughout, so the chip stays crisp at 1x.
	if shows_lock_chip(locked, _lock_cost):
		var has_icon: bool = _lock_icon != null
		var box: Rect2 = lock_chip_box(_lock_cost, has_icon)
		draw_rect(box, ink)                   # ink border
		draw_rect(box.grow(-1.0), CHIP_CREAM) # cream interior: 10 rows, the 8-row content leaves one cream row above and below
		var x: float = box.position.x + 3.0   # the content starts 2 cream texels in from the border
		var base: float = box.position.y + 9.0  # glyph rows are base - 7 .. base, i.e. box.y + 2 .. box.y + 9, the icon's rows too
		if has_icon:
			draw_texture(_lock_icon, Vector2(x, box.position.y + 2.0))
			x += float(LOCK_ICON + LOCK_GAP)
		# One glyph at a time, one texel apart: the 5 px font has no spacing of its own, so "300" ran together at 1x.
		for i in _lock_cost.length():
			var ch: String = _lock_cost.substr(i, 1)
			draw_string(LOCK_FONT, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOCK_SIZE, ink)
			x += LOCK_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOCK_SIZE).x + float(LOCK_DIGIT_GAP)


## Whether a pad draws its cost chip: only a locked row's first pad carries a cost, and only when the font loaded.
static func shows_lock_chip(is_locked: bool, cost: String) -> bool:
	return is_locked and cost != "" and LOCK_FONT != null


## Width of the digits with one texel between each glyph (no gap after the last one).
static func chip_text_width(text: String) -> float:
	var w: float = 0.0
	for i in text.length():
		w += LOCK_FONT.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, LOCK_SIZE).x
	return w + float(LOCK_DIGIT_GAP * maxi(text.length() - 1, 0))


## The cost chip's box in pad-local texels: 12 rows, beside the plate's right end and centred on its top face.
## 3 texels of chip either side of the icon and digits (1 border, 2 cream).
static func lock_chip_box(cost: String, has_icon: bool) -> Rect2:
	var content: float = chip_text_width(cost) + (float(LOCK_ICON + LOCK_GAP) if has_icon else 0.0)
	return Rect2(HALF.x + 4.0, float(LOCK_TOP), content + 6.0, 12.0)


## 0..2: the glint step over a pad 3 flower bed (0 under Reduce motion). Part of the redraw signature.
func _twinkle() -> int:
	if not FLOWERS.has(flower_row) or MeadowLife.reduce_motion or locked:
		return 0
	return (Time.get_ticks_msec() / 400) % 3


## 0..2: which flicker frame the forge object is on (always 0 under Reduce motion). Part of the redraw signature.
func _forge_frame() -> int:
	if not FORGE_ART.has(tier_row) or MeadowLife.reduce_motion or locked:
		return 0
	return (Time.get_ticks_msec() / FLICKER_MS) % 3


## stage 1..3: pad 1 is the plain version, pad 2 adds to it, pad 3 is the grand one.
static func forge_texture(art: String, stage: int, frame: int) -> Texture2D:
	var key: String = "%s_%d_%d" % [art, stage, frame]
	if not _forge_tex.has(key):
		_forge_tex[key] = load("%s%s_s%d_game_f%d.png" % [FORGE_DIR, art, stage, frame]) as Texture2D
	return _forge_tex[key] as Texture2D


## A forge row's object, bottom-centre on the plate. Locked: a flat dark silhouette. Opening: it rises out of the plate
## row by row and throws the same ring of sparks as a flower.
func _draw_forge(top: int, _ink: Color) -> void:
	var stage: int = 3
	var sd: ButtonDef = _sim().button_defs.get(button_id) as ButtonDef
	if sd != null:
		stage = clampi(sd.row_index + 1, 1, 3)
	var tex: Texture2D = forge_texture(String(FORGE_ART[tier_row]), stage, _forge_frame())
	if tex == null:
		return
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	var shown: int = h
	if _bloom_t > 0.0:
		shown = maxi(1, ceili(float(h) * (1.0 - _bloom_t)))
	var tint: Color = Color(0.2, 0.16, 0.2) if locked else Color.WHITE
	var y: int = top + 1 - shown
	draw_texture_rect_region(tex, Rect2(-w / 2, y, w, shown), Rect2(0, h - shown, w, shown), tint)
	if _bloom_t > 0.0 and _bloom_t < 0.7:
		var r: float = (0.7 - _bloom_t) / 0.7
		for i in 10:
			var ang: float = float(i) / 10.0 * TAU
			var q: Vector2 = Vector2(cos(ang) * 14.0, sin(ang) * 7.0) * r
			draw_rect(Rect2(roundf(q.x), roundf(top - 4 + q.y), 1, 1), Color.WHITE if i % 2 == 0 else stat_color)
	var pips: int = 1
	var bd: ButtonDef = _sim().button_defs.get(button_id) as ButtonDef
	if bd != null:
		pips = bd.row_index + 1
	for i in pips:
		draw_rect(Rect2(i * 2 - (pips - 1), top + 4, 1, 1), _ink if locked else stat_color)


## The tier flower standing on the plate with a 1 texel ink outline. Locked pads show a small closed bud. When the tier
## opens it rises row by row and throws a ring of petals. One pip per pad position (1..3) sits at the front corner.
func _draw_flowers(top: int, ink: Color) -> void:
	var rows: Array = FLOWERS[flower_row]
	var n: int = rows.size()
	var base: int = top - 1
	var shown: int = 3 if locked else n
	if _bloom_t > 0.0:
		shown = maxi(1, ceili(float(n) * (1.0 - _bloom_t)))
	var cells: Array[Vector3i] = []   # x, y, kind (0 petal 1 shade 2 heart 3 leaf)
	var stage: int = 3
	var sbd: ButtonDef = _sim().button_defs.get(button_id) as ButtonDef
	if sbd != null:
		stage = clampi(sbd.row_index + 1, 1, 3)
	if not locked and _bloom_t <= 0.0 and stage >= 2:
		for side in [-1, 1]:
			if stage == 2:   # pad 2: two small sprouts beside the flower
				for bc: Vector3i in BUD:
					cells.append(Vector3i(bc.x * 1 + side * 9, base + bc.y, bc.z))
			else:            # pad 3: two half-height flowers of the same tier, so the row reads as a bed
				for k in 7:
					var ml: String = rows[k] if k < 4 else rows[n - 7 + k]   # the bloom's top four rows over the stem's last three
					for rx in range(4, 9):
						var mc: String = ml[rx]
						if mc != ".":
							cells.append(Vector3i(rx - 6 + side * 10, base - 6 + k, "#dcgW".find(mc)))
	for k in shown:
		var line: String = rows[n - 1 - k]
		for rx in 13:
			var ch: String = line[rx]
			if ch == ".":
				continue
			if locked and ch != "g":
				ch = "g"
			cells.append(Vector3i(rx - 6, base - k, "#dcgW".find(ch)))
	for c: Vector3i in cells:
		for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			draw_rect(Rect2(c.x + o.x, c.y + o.y, 1, 1), ink)
	for c: Vector3i in cells:
		var col: Color = stat_color
		match c.z:
			1: col = stat_color.darkened(0.35)
			2, 4: col = Color.WHITE
			3: col = palette[3] if locked else LEAF
		draw_rect(Rect2(c.x, c.y, 1, 1), col)
	if _bloom_t > 0.0 and _bloom_t < 0.7:
		var r: float = (0.7 - _bloom_t) / 0.7
		for i in 10:
			var ang: float = float(i) / 10.0 * TAU
			var q: Vector2 = Vector2(cos(ang) * 14.0, sin(ang) * 7.0) * r
			draw_rect(Rect2(roundf(q.x), roundf(top - 4 + q.y), 1, 1), Color.WHITE if i % 2 == 0 else stat_color)
	if stage == 3 and not locked and _bloom_t <= 0.0 and not MeadowLife.reduce_motion:   # twinkling petal glints over the bed
		var tw: int = (Time.get_ticks_msec() / 400) % 3
		for gi in 3:
			var gp: Vector2i = [Vector2i(-9, -13), Vector2i(8, -14), Vector2i(0, -20)][gi]
			if (gi + tw) % 3 == 0:
				draw_rect(Rect2(gp.x, base + gp.y + 3, 1, 1), Color.WHITE)
	var pips: int = 1
	var bd: ButtonDef = _sim().button_defs.get(button_id) as ButtonDef
	if bd != null:
		pips = bd.row_index + 1
	for i in pips:
		draw_rect(Rect2(i * 2 - (pips - 1), top + 4, 1, 1), ink if locked else stat_color)


## Unique 5x5 emblem per pad (mirrored, so it reads as a badge), projected onto the 2:1 plate. The centre stays clear
## for the buy-state tick or X; the spine in the stat colour.
func _draw_emblem(top: int, ink: Color) -> void:
	var bit: int = 0
	for v in 5:
		for u in 5:
			var uu: int = mini(u, v)
			var vv: int = maxi(u, v)
			var idx: int = ((vv * (vv + 1)) >> 1) + uu   # 0..14 over the triangle
			var on: bool = (emblem_bits >> idx) & 1 == 1
			var spine: bool = u == v
			if not on and not spine:
				continue
			var x: int = (u - v) * 2
			var y: int = u + v - 4
			if absi(x) <= 3 and absi(y) <= 1:
				continue
			draw_rect(Rect2(x - 1, top + y, 2, 1), stat_color if spine else ink)


## A 1 texel diamond outline built from whole-texel rects. draw_polyline's diagonals are anti-aliased and finer than
## the world's pixel grid, which made the plate look like a high-res overlay on the chunky scene.
func _outline(scale: float, y: int, col: Color) -> void:
	var rx: float = HALF.x * scale
	var ry: float = HALF.y * scale
	for x in range(-roundi(rx), roundi(rx) + 1):
		var dy: int = roundi(ry * (1.0 - absf(float(x)) / rx))
		draw_rect(Rect2(x, y - dy, 1, 1), col)
		if dy != 0:
			draw_rect(Rect2(x, y + dy, 1, 1), col)


func _dashed_diamond(scale: float, y: int, col: Color) -> void:
	var rx: float = HALF.x * scale
	var ry: float = HALF.y * scale
	for x in range(-int(rx), int(rx) + 1):
		if x % 2 != 0:
			continue
		var dy: int = roundi(ry * (1.0 - absf(float(x)) / rx))
		draw_rect(Rect2(x, y - dy, 1, 1), col)
		if dy != 0:
			draw_rect(Rect2(x, y + dy, 1, 1), col)
