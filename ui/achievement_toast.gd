class_name AchievementToast
extends Control
## The achievement banner: a wide card that unfurls from the middle of the screen, a little above centre, when an
## achievement unlocks. It shows the section's icon, the achievement's name, its section and the title it earns if any,
## with particles, a chime and a small shake in that section's own style (AchievementStyle, AchievementSparks).
## It never sits over a menu. While any menu is open, or the Bloom ritual runs, unlocks wait in the queue, and a banner
## already up when that starts closes and goes back to the front. Reduce motion shows it whole, with no unfurl, particles
## or shake; Reduce flashing drops the dither ink. Add to the HUD and call bind() once. Pure presentation.

enum Phase { IDLE, OPEN, HOLD, CLOSE }

## Above every menu panel (the HUD sits at 100) and below tip cards and modals (150), so a banner never hides behind a menu.
const TOAST_Z: int = 130
const WIDTH: float = 380.0          ## the card's full width in texels: a wide banner
const CENTRE_Y: float = 0.38        ## the banner's centre as a fraction of the HUD height: a bit above the middle
const OPEN_TIME: float = 0.36
const HOLD_TIME: float = 2.4
const CLOSE_TIME: float = 0.26
const GAP: float = 0.2
const MAX_QUEUE: int = 6
const UNFURL_STEPS: int = 8         ## the unfurl moves in whole steps, like the dither wipes, never a smooth scale
const SLIVER: float = 0.08          ## the fraction of the width still showing at the start and end of the unfurl
const PLAIN_SHAKE: float = 0.1
const TITLE_SHAKE: float = 0.22
const ICON_PX: int = 32             ## the 16 texel category icon shown at 2x so it stays crisp

## Injected by Main, so this node never names an autoload.
var enabled: Callable = Callable()      ## tutorial gate: false holds unlocks back
var menu_open: Callable = Callable()    ## true while any menu is open
var play_sfx: Callable = Callable()     ## (name: StringName, pitch: float, db: float)
var shake: Callable = Callable()        ## (amount: float): Juice's screen shake

var _card: PanelContainer
var _icon: TextureRect
var _kicker: Label
var _name: Label
var _sub: Label
var _cover: DitherReveal
var _queue: Array[AchievementDef] = []
var _phase: int = Phase.IDLE
var _cur: AchievementDef = null
var _t: float = 0.0                  ## seconds into the current phase (negative during the gap)
var _show: float = 0.0               ## how far open the banner is, 0 to 1
var _from: float = 0.0               ## the show value a close starts from
var _requeue: bool = false           ## the banner was cut short by a menu or ritual: show it again later
var _card_h: float = 0.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOAST_Z
	clip_contents = true   # the unfurl reveals the card from its middle
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", AsciiBox.panel())
	add_child(_card)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(h)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_kicker = _label(v)
	_kicker.add_theme_font_override("font", StatStyle.tag_font())
	_kicker.add_theme_font_size_override("font_size", StatStyle.TAG_SIZE)
	_name = _label(v)
	_name.theme_type_variation = &"TitleLabel"
	_sub = _label(v)
	# Balances the icon, so the text sits in the middle of the wide card.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(ICON_PX, 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)
	_cover = DitherReveal.new()
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)


func _label(parent: Node) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long description wraps inside the card, never widens it
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Listens to the Sim directly so the banner works in tests and tools.
func bind(sim: Sim) -> void:
	sim.achievement_unlocked.connect(func(id: StringName) -> void:
		var d: AchievementDef = sim.achievements.defs.get(id) as AchievementDef
		if d != null and (not enabled.is_valid() or bool(enabled.call())):
			enqueue(d))


func enqueue(d: AchievementDef) -> void:
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append(d)
	if _phase == Phase.IDLE and (_t >= 0.0 or not is_inside_tree()) and not _blocked():
		_begin(_queue.pop_front())


func queued() -> int:
	return _queue.size()


## The banner waits while a menu is open or the Bloom ritual runs. Those are the only things it must never sit over.
func _blocked() -> bool:
	return FxConfig.bloom_running or (menu_open.is_valid() and bool(menu_open.call()))


## Reduce motion: no unfurl, particles or shake. The banner shows whole for its hold, then goes.
func _calm() -> bool:
	return FxConfig.reduce_motion or MeadowLife.reduce_motion


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.IDLE:
			if _t >= 0.0 and not _queue.is_empty() and not _blocked():
				_begin(_queue.pop_front())
		Phase.OPEN:
			if _blocked():
				_close(true)
			else:
				_paint(clampf(_t / OPEN_TIME, 0.0, 1.0))
				if _t >= OPEN_TIME:
					_enter(Phase.HOLD)
					_paint(1.0)
		Phase.HOLD:
			if _blocked():
				_close(true)
			elif _t >= HOLD_TIME:
				_close(false)
		Phase.CLOSE:
			var k: float = clampf(_t / CLOSE_TIME, 0.0, 1.0)
			_paint(_from * (1.0 - k))
			if k >= 1.0:
				_finish()
	if visible:
		_layout()


func _enter(p: int) -> void:
	_phase = p
	_t = 0.0


func _close(requeue: bool) -> void:
	_requeue = requeue
	if _calm():
		_finish()
		return
	_from = _show
	_enter(Phase.CLOSE)


func _finish() -> void:
	visible = false
	_cover.set_cover(0.0)
	if _requeue and _cur != null:
		_queue.push_front(_cur)
	_cur = null
	_requeue = false
	_phase = Phase.IDLE
	_t = -GAP


func _begin(d: AchievementDef) -> void:
	_cur = d
	_requeue = false
	var col: Color = LedgerPanel.color_of(d.category)
	var titled: bool = d.title != ""
	_card.add_theme_stylebox_override("panel", AsciiBox.panel(col))
	_icon.texture = LedgerPanel.icon_for(d.category, false)
	_kicker.text = "ACHIEVEMENT · %s" % Achievements.category_name(d.category).to_upper()
	_kicker.add_theme_color_override("font_color", col)
	_name.text = d.display_name
	_name.add_theme_color_override("font_color", col)
	_sub.text = ("Title earned: %s" % d.title) if titled else d.description
	_sub.add_theme_color_override("font_color", RelicStyle.text if titled else RelicStyle.dim)
	var style: Dictionary = AchievementStyle.of(d.category)
	if play_sfx.is_valid():
		play_sfx.call(style["sound"] as StringName, float(style["pitch"]), float(style["db"]))
		if titled:
			play_sfx.call(AchievementStyle.TITLE_SOUND, 1.0, AchievementStyle.TITLE_DB)
	visible = true
	_t = 0.0
	if _calm():
		_enter(Phase.HOLD)
		_paint(1.0)
		return
	_enter(Phase.OPEN)
	_paint(0.0)
	_burst(d, titled)
	if shake.is_valid():
		shake.call(TITLE_SHAKE if titled else PLAIN_SHAKE)


## Sets how far open the banner is (0 closed to 1 whole) and the ink that goes with it. Reduce flashing skips the ink.
func _paint(openness: float) -> void:
	_show = clampf(openness, 0.0, 1.0)
	_cover.set_cover(0.0 if FxConfig.reduce_flashing else 1.0 - _show)
	_layout()


## Measures the card and places the banner: centred across, CENTRE_Y down, clipped to the unfurled width.
func _layout() -> void:
	_card_h = _card.get_combined_minimum_size().y
	_card.size = Vector2(WIDTH, _card_h)
	var w: float = width_for(_show)
	size = Vector2(w, _card_h)
	_card.position = Vector2((w - WIDTH) * 0.5, 0.0)
	if is_inside_tree():
		position = origin_for(get_parent_area_size(), size)


## A burst of particles from the banner's middle, in its section's style. Skipped off-tree (tests and tools).
func _burst(d: AchievementDef, titled: bool) -> void:
	var host: Node = get_parent()
	if host == null or not is_inside_tree():
		return
	var shape: StringName = AchievementStyle.shape_of(d.category)
	var col: Color = LedgerPanel.color_of(d.category)
	var colors: Array[Color] = [col, col.lightened(0.45)]
	var area: Vector2 = get_parent_area_size()
	var sp := AchievementSparks.new()
	sp.position = Vector2(area.x * 0.5, area.y * CENTRE_Y)
	sp.z_index = TOAST_Z
	host.add_child(sp)
	var n: int = GraphicsQuality.particle_count(AchievementStyle.count_of(shape, titled))
	sp.spawn(shape, colors, n, Vector2(WIDTH * 0.5, _card_h * 0.5))


## Pure: the card width while `show` of the unfurl is done. Eases out and moves in whole steps.
static func width_for(openness: float) -> float:
	var e: float = 1.0 - pow(1.0 - clampf(openness, 0.0, 1.0), 3.0)
	var q: float = floorf(e * float(UNFURL_STEPS)) / float(UNFURL_STEPS)
	return WIDTH * lerpf(SLIVER, 1.0, q)


## Pure: the top-left corner that centres a `banner` sized box across `area` at CENTRE_Y, in whole texels.
static func origin_for(area: Vector2, banner: Vector2) -> Vector2:
	return Vector2(roundf((area.x - banner.x) * 0.5), roundf(area.y * CENTRE_Y - banner.y * 0.5))
