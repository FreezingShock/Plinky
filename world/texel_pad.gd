class_name TexelPad
extends Node2D
## A pressable pad anchored on the baked meadow art. Standing on it presses at the player's press rate.
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
var hold: HoldPress
## Set by main each frame: the mouse is over this pad and not over the HUD.
var hovered: bool = false
## 0..1 of the cost you hold (see _refresh_progress). Drives the gauge and the Far / Close / Ready look.
var progress: float = 0.0

## Buy state colours are fixed hex (like rarity colours): green = you can buy, red = you can't. Not palette-tinted, so they read in every zone.
## Secondary colour = the stat this pad raises. Unknown stats fall back to paper.
const STAT_COLORS: Dictionary = {
	&"mult": Color("55aaff"), &"reb": Color("c77dff"), &"slag": Color("ffaa00"),
}
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
var _timer: float = 0.0
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
	hold = HoldPress.new()
	add_child(hold)
	hold.tick.connect(_press)
	hold.released.connect(func() -> void:
		holding = false
		left.emit())


func _physics_process(delta: float) -> void:
	var sim: Sim = _sim()
	var d: Vector2 = walker.position - position
	var inside: bool = (d.x * d.x) / (HALF.x * HALF.x) + (d.y * d.y) / (HALF.y * HALF.y) <= 1.0
	if inside and bool(walker.get("airborne")):
		inside = false   # a jump clears the plate; landing on it presses at once
	if inside and not standing:
		_timer = 0.0  # first press is immediate on arrival
	if standing and not inside:
		left.emit()
	standing = inside
	affordable = sim.can_afford(button_id)
	_progress_t -= delta
	if _progress_t <= 0.0:
		_progress_t = 0.2
		_refresh_progress(sim)
	_punch_t = maxf(_punch_t - delta / PUNCH_TIME, 0.0)
	_lvl_t = maxf(_lvl_t - delta / LEVEL_TIME, 0.0)
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta / 0.2, 0.0)
		queue_redraw()
	if _ring_t < 1.0:
		_ring_t = minf(_ring_t + delta / RING_TIME, 1.0)
	if inside:
		_timer -= delta
		if _timer <= 0.0:
			_press()
			_timer = sim.press_interval()
	var sig: int = _signature()
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _press() -> void:
	_gs().try_press(button_id, Vector3(global_position.x, global_position.y, 0.0))


## Click a pad to press it; hold to repeat (HoldPress speeds up while held).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if hit((get_parent() as Node2D).get_local_mouse_position()):
			holding = true
			hold.begin()
			_press()
			get_viewport().set_input_as_handled()
	elif holding:
		hold.end()


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
		| _level_step() << 24 | int(glow != null and glow.flash_t > 0.0) << 17 | (glow.color_index if glow != null else 0) << 18)


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
	# Ink silhouette (rule 6: one outline in palette 0) around the whole slab.
	for k in range(0, th + 1):
		_rows(0, top + k, hx + 1, hy + 1, ink, ink)
	# Side faces: lit left in earth, shaded right in shadow (rule 1: warm only where light hits).
	for k in range(1, th + 1):
		_rows(0, top + k, hx, hy, palette[6], palette[1])
	# Top face.
	var face: Color = palette[6]
	var face_r: Color = palette[6]
	if st == PadState.FAR:
		face = palette[2]
		face_r = palette[2]
	_rows(0, top, hx, hy, face, face_r)
	if st != PadState.FAR:
		_lit_rim(top, hx, hy, palette[5])
	elif hovered:
		_lit_rim(top, hx, hy, palette[3])
	# Rim: brighter as the walker approaches or the mouse hovers.
	var near: int = nearness()
	var rim: Color = StatStyle.cant().darkened(0.3) if st != PadState.READY else StatStyle.gain()
	if near >= 2:
		rim = rim.lerp(Color.WHITE, 0.4)
	if hovered:
		rim = palette[7]
	_outline(1.0, top, rim)
	# Inset: green when buyable, red when not, with a green gauge filling as you earn the cost. Each pad has its own motif.
	var ihx: int = 10
	var ihy: int = 5
	var buy: Color = StatStyle.gain()
	if st == PadState.READY:
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
		_dashed_diamond(0.86, top, rarity.tint())  # dashed, so Uncommon green never reads as the buy-state green
		if rarity.rank >= 4:
			for c: Vector2i in [Vector2i(-hx + 4, 0), Vector2i(hx - 4, 0), Vector2i(0, -hy + 2), Vector2i(0, hy - 2)]:
				draw_rect(Rect2(c.x, top + c.y, 1, 1), Color.WHITE)
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
