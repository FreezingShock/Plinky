class_name WelcomeCard
extends PanelContainer
## The Welcome Back card: the time away as a gallery. Four sections (Earned, Spent Tending, Pads Tended, Found), each a
## grid of WelcomeTile icons with its amount at the bottom. The card fades and rises in, and each tile pops and counts up
## in turn. Collect finishes any count still running, sparks every tile in order, plays a sound and closes. Esc and the X
## close it without the sparks. The sim has already banked the time away, so closing early loses nothing. The layout and
## the numbers come from WelcomeBack.build(); this node only draws them. Reduce Motion or Reduce Flashing shows every
## amount at once and skips the sparks and the fade.

const COLS: int = 7                 ## tiles across; a row of seven fits the 640x360 frame with the gutter
const GAP: int = 2
const OPEN_TIME: float = 0.2
const CLOSE_TIME: float = 0.2
const SLIDE: float = 6.0            ## texels the card rises (or sinks while it closes)
const POP_TIME: float = 0.12
const COUNT_TIME: float = 0.45      ## one tile's count-up
const REVEAL_SPAN: float = 0.9      ## the stagger across all tiles, however many there are
const TICK_GAP: float = 0.07        ## shortest gap between two ticks
const COLLECT_STEP: float = 0.045   ## time between one tile's sparks and the next
const COLLECT_TAIL: float = 0.3     ## time after the last spark before the card closes
const SPARKS: int = 8               ## particles per tile on collect
const CAP_TEXT: String = "That is the most you can bank offline."

var _body: VBoxContainer
var _away: Label
var _cap: Label
var _tiles: Array[WelcomeTile] = []
var _starts: PackedFloat32Array = PackedFloat32Array()
var _state: StringName = &"closed"   ## closed, opening, open, collecting or closing
var _fade: float = 0.0               ## 0 hidden .. 1 fully shown; drives alpha and the rise
var _clock: float = 0.0
var _next_reveal: int = 0
var _tick_at: float = -1.0
var _queue: Array[WelcomeTile] = []
var _queue_t: float = 0.0
var _tail: float = 0.0
var _best_rarity: StringName = &""
var _collect: PixelButton


func _init() -> void:
	visible = false
	z_index = 160
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Welcome Back"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x_gap := Control.new()   # room for the close X the HUD attaches in the corner
	x_gap.custom_minimum_size = Vector2(CloseX.HEADER_GAP, 1.0)
	head.add_child(x_gap)
	_away = Label.new()
	_away.add_theme_color_override("font_color", StatStyle.PAPER)
	v.add_child(_away)
	# The body is always as wide as seven tiles, so the card never changes width between visits.
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	_body.custom_minimum_size.x = COLS * WelcomeTile.W + (COLS - 1) * GAP
	v.add_child(_body)
	_cap = Label.new()
	_cap.text = CAP_TEXT
	_cap.add_theme_color_override("font_color", RelicStyle.dim)
	_cap.visible = false
	v.add_child(_cap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var collect := PixelButton.new()
	collect.text = "Collect"
	collect.pressed.connect(_on_collect)
	row.add_child(collect)
	_collect = collect


## Shows the card for a WelcomeBack.build() result. Each tile's amount counts up in order.
func open(data: Dictionary) -> void:
	Tip.hide_all()
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_tiles.clear()
	_starts = PackedFloat32Array()
	_queue.clear()
	_best_rarity = StringName(data.get("best_rarity", &""))
	_away.text = str(data["away_text"])
	_cap.visible = bool(data["capped"])
	var total: int = int(data["tiles"])
	var step: float = REVEAL_SPAN / float(maxi(1, total - 1))
	var index: int = 0
	for sec_v: Variant in data["sections"]:
		var sec: Dictionary = sec_v as Dictionary
		var head := Label.new()
		head.text = str(sec["title"])
		head.add_theme_color_override("font_color", RelicStyle.accent)
		_body.add_child(head)
		var tiles: Array = sec["tiles"]
		var grid := GridContainer.new()
		grid.columns = mini(COLS, tiles.size())
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		_body.add_child(grid)
		for d_v: Variant in tiles:
			var t: WelcomeTile = _make_tile(d_v as Dictionary)
			grid.add_child(t)
			_tiles.append(t)
			_starts.append(float(index) * step)
			index += 1
	reset_size()
	visible = true
	_next_reveal = 0
	_clock = 0.0
	_tick_at = -1.0
	if _calm():
		_state = &"open"
		_fade = 1.0
		_finish_counts()
	else:
		_state = &"opening"
		_fade = 0.0
		for t: WelcomeTile in _tiles:
			t.modulate.a = 0.0
	modulate.a = _fade
	Tip.grab_quiet(_collect)


func is_open() -> bool:
	return visible and _state != &"closing"


## Keeps the card centred in the HUD frame, rising a little while it opens and sinking while it closes.
func place(frame: Vector2) -> void:
	var p: Vector2 = ((frame - size) * 0.5).floor()
	p.y = minf(p.y, roundf(frame.y * 0.3))
	p.y += roundf((1.0 - _fade) * SLIDE)
	if position != p:
		position = p


## Closes the card without the collect sparks (Esc and the X). The time away is already banked.
func dismiss() -> void:
	if not visible or _state == &"closing":
		return
	_begin_close()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	match _state:
		&"opening":
			_fade = minf(1.0, _fade + delta / OPEN_TIME)
			_animate()
			if _clock >= REVEAL_SPAN + COUNT_TIME:
				_state = &"open"
				_finish_counts()
		&"collecting":
			_step_collect(delta)
		&"closing":
			_fade = maxf(0.0, _fade - delta / CLOSE_TIME)
			if _fade <= 0.0:
				visible = false
				_state = &"closed"
	modulate.a = _fade


## One step of the open: each tile pops in at its start, then counts up over COUNT_TIME.
func _animate() -> void:
	while _next_reveal < _tiles.size() and _clock >= _starts[_next_reveal]:
		_tick()
		_next_reveal += 1
	for i: int in _tiles.size():
		var t: WelcomeTile = _tiles[i]
		var local: float = _clock - _starts[i]
		if local < 0.0:
			t.modulate.a = 0.0
			continue
		var pop: float = minf(1.0, local / POP_TIME)
		var count: float = minf(1.0, local / COUNT_TIME)
		count = 1.0 - pow(1.0 - count, 3.0)   # ease out: fast start, settles on the number
		t.modulate.a = pop
		t.show_amount(count, roundi((1.0 - pop) * 2.0))


## Every amount shown in full, with no pop left: the end state of the open, and what Reduce Motion gets at once.
func _finish_counts() -> void:
	for t: WelcomeTile in _tiles:
		t.modulate.a = 1.0
		t.show_amount(1.0, 0)


func _on_collect() -> void:
	if _state != &"opening" and _state != &"open":
		return
	_finish_counts()
	if _best_rarity != &"":
		Audio.relic(_best_rarity)
	else:
		Audio.play(&"tier_up_2", 1.0, -6.0)
	if _calm():
		_begin_close()
		return
	_queue.assign(_tiles)
	_queue_t = 0.0
	_tail = COLLECT_TAIL
	_state = &"collecting"


## Sparks every tile in turn, then waits a moment and closes. A ParticleBurst is spawned on the card so it fades with it.
func _step_collect(delta: float) -> void:
	_queue_t -= delta
	while _queue_t <= 0.0 and not _queue.is_empty():
		var t: WelcomeTile = _queue.pop_front()
		var centre: Vector2 = to_local(t.get_global_rect().get_center())
		var colours: Array[Color] = [t.outline, RelicStyle.accent]
		ParticleBurst.spawn(self, centre, colours, SPARKS)
		_tick()
		_queue_t += COLLECT_STEP
	if _queue.is_empty():
		_tail -= delta
		if _tail <= 0.0:
			_begin_close()


func _begin_close() -> void:
	Tip.hide_all()
	if _calm():
		visible = false
		_fade = 0.0
		_state = &"closed"
		return
	_state = &"closing"


## A count-up or spark tick, held to one per TICK_GAP so a big return never machine-guns the sound.
func _tick() -> void:
	if _clock - _tick_at < TICK_GAP and _tick_at >= 0.0:
		return
	_tick_at = _clock
	Audio.popup_tick()


func _make_tile(d: Dictionary) -> WelcomeTile:
	var rarity: StringName = StringName(d["rarity"])
	var rd: RarityDef = WelcomeBack.rarity_def(rarity)
	var edge: Color = rd.tint() if rd != null else RelicStyle.edge
	var kind: StringName = StringName(d["kind"])
	var amount_color: Color = RelicStyle.text
	if kind == &"gain":
		amount_color = StatStyle.gain()
	elif kind == &"spent":
		amount_color = StatStyle.cant()
	var t := WelcomeTile.new()
	t.setup(IconSet.get_icon(str(d["icon"]), 16), edge, amount_color, d["amount"] as BigNum, str(d["prefix"]), str(d["text"]))
	var title_color: Color = edge if kind == &"found" else StatStyle.color(StringName(d["icon"]))
	Tip.bind(t, _spec(d, edge, title_color))
	return t


## The shared Tip for one tile: the name in its stat colour, the rarity tag, then the exact amount and the rates or the
## mastery detail. The frame takes the rarity colour.
func _spec(d: Dictionary, edge: Color, title_color: Color) -> Dictionary:
	var lines: Array = [[Tip.tag(str(d["rarity_name"]), edge)]]
	for l_v: Variant in d["lines"]:
		lines.append([Tip.seg(str(l_v), RelicStyle.text)])
	return {"title": str(d["name"]), "title_color": title_color, "color": edge, "lines": lines}


func _calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_motion or FxConfig.reduce_flashing
