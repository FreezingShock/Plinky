extends Node
## Autoload "Juice" (Fx is the renderer's). Gameplay calls one function; this fans out to every effect.
##   Juice.press(pad, world_pos, amount, big, held, pulse_from, pulse_order)   Juice.milestone()   Juice.zone_enter()
## Presses draw through PressPopups (one pooled node) and chain into streak tiers (PressStreak).
## Big presses are punchy by design: hitstop + shake (Nathan, 22 Nov).

@export var shake: ScreenShake
@export var transitions: Transitions
var fx_root: Node
var _overlay: CanvasLayer

## Popups go in a screen-space layer: crisp, unscaled by world zoom, always above the grass.
func _popup_parent() -> Node:
	if not is_instance_valid(_overlay):
		_overlay = CanvasLayer.new()
		_overlay.layer = 5
		fx_root.get_tree().current_scene.add_child(_overlay)
	# Borrow the theme from the nearest Control ancestor of the world (Main), once.
	if PopupNumber.ui_theme == null:
		var n: Node = fx_root
		while n != null and not (n is Control and (n as Control).theme != null):
			n = n.get_parent()
		if n != null:
			PopupNumber.ui_theme = (n as Control).theme
			CrispFont.theme_font(PopupNumber.ui_theme, &"PopupLabel")   # popup glyphs: no grey AA, whole pixels
	return _overlay

## World (texel) position -> screen position, including camera zoom and pan. Whole texels.
func _to_screen(world_pos: Vector2) -> Vector2:
	return ((fx_root as CanvasItem).get_global_transform_with_canvas() * world_pos).round()

const PARTICLE_COLORS: Array[Color] = [Color("f2e6a0"), Color("c2784e")]
## Where a press popup sits above the pad's screen position (centre, baseline), in pixels.
const POPUP_LIFT: Vector2 = Vector2(0.0, -18.0)

## The press chain behind the popup tiers (Plain, Gold, Ice, Rainbow, Chroma, Galaxy). See core/press_streak.gd.
var streak: PressStreak = PressStreak.new()
var _popups: PressPopups
var _last_anchor: Vector2 = Vector2.ZERO
var last_tier: int = 0   ## the streak tier of the latest pad press: the HUD gain labels take its colour, as the world numbers do


func _ready() -> void:
	EventBus.game_loaded.connect(streak.reset)
	EventBus.rebirth_done.connect(func(_p: BigNum) -> void: streak.reset())
	EventBus.attribute_bought.connect(_on_attribute_bought)


func _process(_delta: float) -> void:
	if streak.count <= 0:
		return
	var sim: Sim = GameState.sim as Sim
	if sim == null:
		return
	var lost: int = streak.expire(Time.get_ticks_msec() / 1000.0, sim.config)
	if lost >= 1 and _popups != null:
		_popups.fizzle(_last_anchor, lost)
		Audio.streak_lost(lost)


func _popup_field() -> PressPopups:
	if not is_instance_valid(_popups):
		_popup_parent()   # borrows the theme for the popup font
		_popups = PressPopups.new()
		_popups.world = fx_root as CanvasItem
		# A child of Main (z 95): above the world, below the HUD, so no menu or panel is ever covered by a popup.
		fx_root.get_parent().add_child(_popups)
	return _popups


func tier_name(tier: int) -> String:
	var sim: Sim = GameState.sim as Sim
	var names: PackedStringArray = sim.config.popup_tier_names if sim != null else PackedStringArray()
	return names[tier] if tier >= 0 and tier < names.size() else ""


## One pad press. pulse_from is the world position of the pad whose relic pulse caused it (Vector2.INF when the player
## pressed it); pulse_order counts the neighbours that pulse has hit, so the echoes ripple outward one after another.
func press(pad: CanvasItem, pos: Vector2, amount: float, big := false, held := false, pulse_from := Vector2.INF, pulse_order := 0) -> void:
	var sim: Sim = GameState.sim as Sim
	var now: float = Time.get_ticks_msec() / 1000.0
	var tier: int = streak.feed(now, sim.momentum_tier(), sim.config)
	last_tier = tier
	var rose: bool = streak.rose
	var pulse: bool = pulse_from != Vector2.INF
	var key: StringName = (pad as TexelPad).button_id if pad is TexelPad else StringName(str(pad.get_instance_id()))
	var field: PressPopups = _popup_field()
	var anchor: Vector2 = pos
	_last_anchor = _to_screen(pos) + POPUP_LIFT
	var tint: Color = Color(0.0, 0.0, 0.0, 0.0)
	if tier > 0:
		tint = PopupStyle.accent_color(tier, now * 6.0, PopupStack.zone)
	var delay: float = 0.0
	if pulse:
		var echo: float = sim.config.pulse_echo_delay
		field.link(_to_screen(pulse_from) + POPUP_LIFT * 0.4, _to_screen(pos) + POPUP_LIFT * 0.4, tier, echo * float(pulse_order))
		delay = echo * float(pulse_order) + 0.16
	var cap: Array = _pad_caption(key)
	var stat_name: String = cap[0]
	var stat_col: Color = cap[1]
	field.press(key, anchor, amount, tier, big, held, pulse, delay, stat_name, stat_col)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(pad):
			return
	_pad_feedback(pad, pos, tier, tint, big, pulse)
	if pulse:
		Audio.pulse_echo(pulse_order)
	else:
		Audio.pad_press(big, held, tier)
	if rose:
		_tier_up(field, anchor, tier)
	if big and not pulse and pad is TexelPad:
		var hs := PressSquash.new()
		pad.add_child(hs)
		await hs.hitstop(FxConfig.HITSTOP_MS * 2)  # the node must outlive the freeze or time_scale never resets
		hs.queue_free()


## A press made by a Bloom gift (Dew Sprites, Wildflower): the number floats up quietly and a few pixels pop, with no
## streak, no hitstop and no click ladder. It shares the pad's currency label like every other press.
func auto_press(pad: CanvasItem, pos: Vector2, amount: float) -> void:
	var key: StringName = (pad as TexelPad).button_id if pad is TexelPad else StringName(str(pad.get_instance_id()))
	var cap: Array = _pad_caption(key)
	var stat_name: String = cap[0]
	var stat_col: Color = cap[1]
	_popup_field().press(key, pos, amount, 0, false, false, false, 0.0, stat_name, stat_col)
	var cols: Array[Color] = PARTICLE_COLORS
	if pad is TexelPad:
		cols = Array([(pad as TexelPad).palette[5], (pad as TexelPad).palette[6]], TYPE_COLOR, "", null)
		(pad as TexelPad).punch(Color(0.0, 0.0, 0.0, 0.0), 0)
	ParticleBurst.spawn(fx_root, pos, cols, 4)
	Audio.auto_press()


## Petal Burst gift (cosmetic): every press scatters extra petals in the pad's colours. level 1 to 3.
func petals(pad: CanvasItem, pos: Vector2, level: int) -> void:
	var cols: Array[Color] = PARTICLE_COLORS
	if pad is TexelPad:
		cols = Array([(pad as TexelPad).palette[5], (pad as TexelPad).palette[6], StatStyle.color(&"seeds")], TYPE_COLOR, "", null)
	ParticleBurst.spawn(fx_root, pos, cols, 6 + 4 * clampi(level, 1, 3))


## The pad's own reaction: sink, ripple (tinted by tier), and a burst of pixels in the tier's colours.
func _pad_feedback(pad: CanvasItem, pos: Vector2, tier: int, tint: Color, big: bool, pulse: bool) -> void:
	var cols: Array[Color] = []
	if tier > 0:
		cols = PopupStyle.spark_colors(tier, PopupStack.zone)
	if pad is TexelPad:
		# The pad animates itself (whole-texel sink and ripple), so rapid presses never stack tweens.
		(pad as TexelPad).punch(tint, 0 if pulse else (1 if big else 0) + (1 if tier >= 3 else 0))
		if tier == 0:
			cols = Array([(pad as TexelPad).palette[5], (pad as TexelPad).palette[6]], TYPE_COLOR, "", null)
	else:
		var sq := PressSquash.new()
		pad.add_child(sq)
		sq.play(pad)
		sq.finished.connect(sq.queue_free)
		if cols.is_empty():
			cols = PARTICLE_COLORS
		if big:
			sq.hitstop(FxConfig.HITSTOP_MS * 2)
	var n: int = (randi_range(10, 14) if big else -1)
	if pulse:
		n = 5
	elif tier > 0:
		n = (n if n > 0 else randi_range(FxConfig.PARTICLES_MIN, FxConfig.PARTICLES_MAX)) + 2 * tier
	ParticleBurst.spawn(fx_root, pos, cols, n)


## A new streak tier: no text and no camera shake (Nathan): just a ring, a burst and the chime. The pad itself presses harder.
func _tier_up(field: PressPopups, anchor: Vector2, tier: int) -> void:
	var at: Vector2 = _to_screen(anchor) + POPUP_LIFT
	field.burst(at, tier, 1.6 + 0.25 * float(tier))
	field.ring(at + Vector2(0.0, -6.0), tier, 30.0 + 8.0 * float(tier))
	Audio.tier_up(tier)


## A streak or critter payout (Sunlight) lands on the same per-currency label as presses, so it never sits beside one.
func bonus_popup(pos: Vector2, amount: float) -> void:
	var cap: Array = _stat_caption(&"sunlight")
	var stat_name: String = cap[0]
	var stat_col: Color = cap[1]
	_popup_field().press(&"bonus", pos, amount, 1, false, false, false, 0.0, stat_name, stat_col)


## The reward caption of a pad's button: its stat's display name and colour. Empty when the pad has no reward stat.
func _pad_caption(key: StringName) -> Array:
	var sim: Sim = GameState.sim as Sim
	if sim == null:
		return ["", Color.WHITE]
	var def: ButtonDef = sim.button_defs.get(key) as ButtonDef
	if def == null:
		return ["", Color.WHITE]
	return _stat_caption(def.reward_stat)


## A stat's display name and colour as a [name, colour] pair. Empty when the stat is unknown.
func _stat_caption(stat_id: StringName) -> Array:
	var sim: Sim = GameState.sim as Sim
	if sim == null or not sim.stat_defs.has(stat_id):
		return ["", Color.WHITE]
	return [(sim.stat_defs[stat_id] as StatDef).display_name, StatStyle.color(stat_id)]


## Mastery level-up: ring flash on the plate and a big "LV n" popup above it.
func level_up(pad: TexelPad, pos: Vector2, level: int) -> void:
	pad.level_flash()
	_popup_field().label(&"level", pos, "LV %d" % level, 1, false, 0.0, 16.0)
	if shake: shake.add(0.2)
	Audio.relic(&"rare")


func milestone() -> void:
	if transitions: await transitions.invert_flash()
	if shake: shake.add(0.8)


## A capstone gift was bought (its one level): the biggest moment a gift gets. Only the crown a reset lists gets it.
func _on_attribute_bought(attr_id: StringName, level: int) -> void:
	var sim: Sim = GameState.sim as Sim
	if sim == null or level != 1:
		return
	var a: AttributeDef = sim.attribute_defs.get(attr_id) as AttributeDef
	if a == null or not _is_crown(sim, a):
		return
	capstone(a)


static func _is_crown(sim: Sim, a: AttributeDef) -> bool:
	for r: ZoneResetDef in sim.reset_defs.values():
		if r.crown_effect == a.effect:
			return true
	return false


## A banner names the crown in its zone's colour, the screen takes the milestone flash and shake, and the divine chime
## plays. The flash and shake are calm under Reduce Flashing and Reduce Shake (the milestone and ScreenShake check them);
## the banner is already gentle under Reduce Motion.
func capstone(a: AttributeDef) -> void:
	Banner.announce({"key": "crown_%s" % a.id, "title": a.display_name, "lines": [a.blurb],
		"color": StatStyle.color(a.effect), "duration": 3.2})
	Audio.relic(&"divine")
	milestone()

## A momentum stage was crossed. Rising stages thump a little harder the higher they are; Surge also pings.
func momentum_tier(tier: int, rising: bool) -> void:
	if not rising:
		return
	if shake: shake.add(0.06 + 0.05 * float(tier))
	if tier >= 4:
		Audio.relic(&"rare")


func zone_enter() -> void:
	if transitions: await transitions.zone_shift()

## Wire to EventBus.relic_gained via a resolver that maps relic_id -> rarity id
## (the relic system owns that data), e.g.
##   EventBus.relic_gained.connect(func(id, _s): Juice.relic_drop(pad_glow, RelicDB.rarity_of(id)))
func relic_drop(glow: PadGlow, rarity: StringName) -> void:
	Audio.relic(rarity)
	if glow.flash_rarity(rarity) and shake and rarity in [&"mythic", &"divine", &"special"]:
		shake.add(0.2)
