class_name AchievementToast
extends Control
## The achievement banner: a compact card that unfurls from the middle of the screen, above centre, when an achievement
## unlocks. It shows the section's icon, the achievement's name, its section and the title it earns if any, with particles,
## a chime and a small shake in that section's own style (AchievementStyle, AchievementSparks).
## It never sits over a menu. While any menu is open, or the Bloom ritual runs, unlocks wait in the queue, and a banner
## already up when that starts closes and goes back to the front. Reduce motion shows it whole, with no unfurl, particles
## or shake; Reduce flashing drops the dither ink. Add to the HUD and call bind() once. Pure presentation.

enum Phase { IDLE, OPEN, HOLD, CLOSE }

## Above every menu panel (the HUD sits at 100) and below tip cards and modals (150), so a banner never hides behind a menu.
const TOAST_Z: int = 130
const WIDTH_SHARE: float = 0.36     ## the card's width as a share of the HUD width: narrower than the first cut
const MIN_WIDTH: float = 168.0      ## never narrower than this, so the text still fits at very small sizes
const MAX_WIDTH: float = 240.0      ## never wider than this on a large window
const CENTRE_Y: float = 0.3         ## the banner's centre as a fraction of the HUD height: higher than the middle
const FRAME_PAD: Vector2 = Vector2(5.0, 3.0)   ## tighter than the usual panel pad (8x6): less blank space around the text
const CARD_SEPARATION: int = 6
const OPEN_TIME: float = 0.36
const HOLD_TIME: float = 2.4
const CLOSE_TIME: float = 0.26
const GAP: float = 0.2
const MAX_QUEUE: int = 6
const UNFURL_STEPS: int = 8         ## the unfurl moves in whole steps, like the dither wipes, never a smooth scale
const SLIVER: float = 0.08          ## the fraction of the width still showing at the start and end of the unfurl
const PLAIN_SHAKE: float = 0.06
const TITLE_SHAKE: float = 0.14
const ICON_PX: int = 16             ## the category icon at its native 16 texels, so it stays crisp and small

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
var _sparks: Node = null             ## the burst of the banner on screen, freed with it when a menu takes the screen
var _full: float = MIN_WIDTH         ## the card's full width for this HUD size


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOAST_Z
	clip_contents = true   # the unfurl reveals the card from its middle
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _frame(Color(0, 0, 0, 0)))
	add_child(_card)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", CARD_SEPARATION)
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
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_kicker = _label(v, 1)
	_kicker.add_theme_font_override("font", StatStyle.tag_font())
	_kicker.add_theme_font_size_override("font_size", StatStyle.TAG_SIZE)
	_name = _label(v, 2)
	_name.theme_type_variation = &"TitleLabel"
	_sub = _label(v, 2)
	# Balances the icon, so the text sits in the middle of the wide card.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(ICON_PX, 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer)
	_cover = DitherReveal.new()
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)


## A label that wraps to at most `lines` lines and then ends in an ellipsis, so a long line can never make the banner
## taller or wider than planned.
func _label(parent: Node, lines: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## The card's frame: the Ascii panel with a tighter pad than the usual one.
func _frame(col: Color) -> AsciiBox:
	var b := AsciiBox.make(AsciiBox.Kind.PANEL, FRAME_PAD.x, FRAME_PAD.y)
	b.edge_override = col
	return b


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


## True while a toast is on screen or unfurling, so a tip card can wait for it instead of covering it.
func is_showing() -> bool:
	return _phase != Phase.IDLE


func queued() -> int:
	return _queue.size()


## The banner waits while a menu is open or the Bloom ritual runs. Those are the only things it must never sit over.
func _blocked() -> bool:
	return FxConfig.bloom_running or (menu_open.is_valid() and bool(menu_open.call()))


## Reduce motion: no unfurl, particles or shake. The banner shows whole for its hold, then goes.
func _calm() -> bool:
	return FxConfig.still()


func _process(delta: float) -> void:
	_t += delta
	# A menu takes the screen: a banner on it goes at once, sparks and all, and comes back when the menu closes.
	if _phase != Phase.IDLE and menu_open.is_valid() and bool(menu_open.call()):
		_shelve()
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


## Put the banner on the shelf for a menu: hidden at once, no close animation, its sparks freed, and the unlock queued
## again at the front. Ritual holds keep the animated close (_close).
func _shelve() -> void:
	if _sparks != null and is_instance_valid(_sparks):
		_sparks.queue_free()
	_sparks = null
	_requeue = true
	_finish()


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
	_card.add_theme_stylebox_override("panel", _frame(col))
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
	_full = banner_width(get_parent_area_size().x) if is_inside_tree() else MIN_WIDTH
	_card_h = _card.get_combined_minimum_size().y
	_card.size = Vector2(_full, _card_h)
	var w: float = width_for(_show, _full)
	size = Vector2(w, _card_h)
	_card.position = Vector2((w - _full) * 0.5, 0.0)
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
	_sparks = sp
	var n: int = GraphicsQuality.particle_count(AchievementStyle.count_of(shape, titled))
	sp.spawn(shape, colors, n, Vector2(_full * 0.5, _card_h * 0.5))


## Pure: the card's full width for an HUD `area_x` wide. It scales with the window, within MIN_WIDTH and MAX_WIDTH, and
## is whole texels so the card and its centring stay on the pixel grid.
static func banner_width(area_x: float) -> float:
	return roundf(clampf(area_x * WIDTH_SHARE, MIN_WIDTH, MAX_WIDTH))


## Pure: the card width while `openness` of the unfurl is done, out of a `full` wide card. Eases out in whole steps.
static func width_for(openness: float, full: float) -> float:
	var e: float = 1.0 - pow(1.0 - clampf(openness, 0.0, 1.0), 3.0)
	var q: float = floorf(e * float(UNFURL_STEPS)) / float(UNFURL_STEPS)
	return full * lerpf(SLIVER, 1.0, q)


## Pure: the top-left corner that centres a `banner` sized box across `area` at CENTRE_Y, in whole texels.
static func origin_for(area: Vector2, banner: Vector2) -> Vector2:
	return Vector2(roundf((area.x - banner.x) * 0.5), roundf(area.y * CENTRE_Y - banner.y * 0.5))
