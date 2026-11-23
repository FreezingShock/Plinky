extends RefCounted
## MenuRouter (one menu open at a time, spam-safe), the animated index window under spam, and the shared CloseX.

func run(t: Object) -> void:
	_router(t)
	_index_spam(t)
	_close_x(t)
	_menu_anim(t)
	_quiet_focus(t)


func _router(t: Object) -> void:
	var state: Dictionary = {&"a": false, &"b": false, &"tab0": false, &"tab1": false}
	var r := MenuRouter.new()
	for k: StringName in [&"a", &"b"]:
		r.register(k, func() -> bool: return state[k], func() -> void: state[k] = true, func() -> void: state[k] = false)
	# Two tabs of one window: opening one while the other is open flips, it never closes first.
	var closes: Array = [0]
	for k: StringName in [&"tab0", &"tab1"]:
		r.register(k, func() -> bool: return state[k], _open_tab.bind(state, k), _close_tabs.bind(state, closes), &"window")
	r.toggle(&"a")
	t.ok(state[&"a"], "toggle opens a closed menu")
	r.toggle(&"b")
	t.ok(state[&"b"] and not state[&"a"], "opening another menu closes the first")
	r.toggle(&"b")
	t.ok(not state[&"b"], "toggling the open menu closes it")
	r.toggle(&"tab0")
	r.toggle(&"tab1")
	t.ok(state[&"tab1"] and not state[&"tab0"] and closes[0] == 0, "switching tabs flips the window without closing it")
	r.toggle(&"a")
	t.ok(state[&"a"] and not state[&"tab1"], "a different menu closes the whole window")
	t.ok(r.close_all(), "close_all reports that something was open")
	t.ok(r.open_kinds().is_empty() and not r.close_all(), "close_all leaves nothing open and then reports nothing")
	t.ok(not r.has(&"nope") and not r.is_open(&"nope"), "unknown menus are ignored")
	r.toggle(&"nope")

	# Spam: 20 toggles of one menu ends closed, 21 ends open, and never two at once.
	for i in 20:
		r.toggle(&"a")
		t.ok(r.open_kinds().size() <= 1, "never more than one menu open while spamming")
	t.ok(not state[&"a"], "20 toggles of one menu end closed")
	r.toggle(&"a")
	t.ok(state[&"a"], "the 21st toggle opens it")
	# Spam across menus: the last one clicked is the one left open.
	var names: Array[StringName] = [&"a", &"b", &"tab0", &"tab1"]
	for i in 20:
		r.toggle(names[i % 4])
		t.ok(r.open_kinds().size() <= 1, "spamming across menus never stacks them")
	r.open(&"b")
	t.eq(r.open_kinds(), [&"b"] as Array[StringName], "open() leaves exactly that menu open")


func _open_tab(state: Dictionary, k: StringName) -> void:
	state[&"tab0"] = false
	state[&"tab1"] = false
	state[k] = true


func _close_tabs(state: Dictionary, closes: Array) -> void:
	closes[0] += 1
	state[&"tab0"] = false
	state[&"tab1"] = false


func _index_spam(t: Object) -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	t.root.add_child(host)
	var panel := IndexPanel.new()
	host.add_child(panel)
	panel.bind(t.make_sim())
	for i in 20:
		panel.toggle_tab(IndexPanel.Tab.STATS)
		t.ok(not (panel._closing and not panel.visible), "mid-spam the window is never closing while hidden")
	t.ok(not panel.is_open(), "20 quick toggles of the Stats tab end closed")
	panel._finish_close()
	t.ok(not panel.visible, "and it is hidden once the close finishes")
	for i in 21:
		panel.toggle_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(panel.is_open() and panel.tab == IndexPanel.Tab.ATTRIBUTES, "21 quick toggles end open on that tab")
	for i in 20:
		panel.toggle_tab(i % 2)
	t.ok(panel.is_open() and panel.tab == IndexPanel.Tab.ATTRIBUTES, "alternating tabs keeps the window open on the last tab")
	panel.close_panel()
	panel.open_tab(IndexPanel.Tab.STATS)
	t.ok(panel.is_open() and panel.visible and not panel._closing, "re-opening during the close animation recovers cleanly")
	t.ok(panel._t >= 0.0 and panel._t <= 1.0, "wipe progress stays in range")
	host.free()


func _close_x(t: Object) -> void:
	t.eq(CloseX.anchor(Vector2(100, 50)), Vector2(100.0 - CloseX.SIZE - CloseX.INSET.x, CloseX.INSET.y), "the X sits in the top right corner")
	t.eq(CloseX.reach(0.0, 0.0), 0, "a new X has no arms yet")
	t.eq(CloseX.reach(1.0, 0.0), CloseX.ARM, "a grown X has its full arms")
	t.eq(CloseX.reach(1.0, 1.0), CloseX.ARM + 1, "hover reaches one texel further")
	t.eq(CloseX.reach(0.5, 1.0), CloseX.reach(0.5, 0.0), "hover pop waits until the X has grown")
	var stage := Control.new()
	stage.size = Vector2(640, 360)
	t.root.add_child(stage)
	var host := PanelContainer.new()
	host.custom_minimum_size = Vector2(120, 60)
	host.position = Vector2(50, 40)
	stage.add_child(host)
	host.size = Vector2(120, 60)
	var x: CloseX = CloseX.attach(host, func() -> void: host.hide())
	x._ready()   # scripts run from _init, before the tree is up, so _ready has not fired yet
	t.ok(x.get_parent() == stage, "the X is a sibling of the panel, so the panel layout never resizes it")
	t.ok(x.size.x >= 9.0 and x.size.y >= 9.0, "the X rect is at least 9x9 (got %s)" % x.size)
	t.eq(x.position, host.position + CloseX.anchor(host.size), "the X sits in the panel's top right corner")
	t.ok(x.mouse_filter == Control.MOUSE_FILTER_STOP and x.visible, "the X takes the mouse and is shown with its panel")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = x.size * 0.5
	click.pressed = true
	x._gui_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	x._gui_input(up)
	t.ok(not host.visible, "clicking the centre of the X closes the panel")
	host.show()
	x._process(0.016)
	t.ok(x.visible and x.position == host.position + CloseX.anchor(host.size), "the X comes back with its panel")
	host.size = Vector2(200, 80)
	x._process(0.016)
	t.eq(x.position, host.position + CloseX.anchor(host.size), "the X follows a resized panel")
	x.grow = 1.0
	t.ok(x.size.x >= 9.0, "a grown X keeps its size")
	var hits: Array = [0]
	x._on_close = func() -> void: hits[0] += 1
	for i in 20:
		x.press()
	t.eq(hits[0], 20, "every press closes (spam safe, no state of its own)")
	host.hide()
	host.show()
	t.ok(x.grow == 0.0 or CloseX.calm(), "the arms regrow each time the panel opens")
	x._process(0.5)
	t.ok(x.grow >= 1.0, "and finish growing")
	stage.free()


## The shared open/close wipe. Without a scene tree it is instant, so the state transitions can be checked directly.
func _menu_anim(t: Object) -> void:
	var p := PanelContainer.new()
	p.visible = false
	var a: MenuAnim = MenuAnim.attach(p)
	var rev: DitherReveal = a.reveal
	t.ok(not a.is_open(), "a fresh animated menu is closed")
	a.open()
	t.ok(p.visible and a.is_open() and a.t == 1.0, "open shows the panel fully")
	t.eq(p.get_meta(&"menu_slide", -1.0), 0.0, "an open menu has no slide offset")
	a.close()
	t.ok(not p.visible and not a.is_open() and a.t == 0.0, "close hides the panel and resets the wipe")
	for i in 10:
		a.open()
		a.close()
	t.ok(not p.visible and not a.closing, "spamming open and close never sticks")
	p.visible = true
	p.visible = false
	t.ok(a.t == 0.0 and not a.reveal.visible, "hiding the panel from outside clears the wipe")
	p.free()
	rev.free()


## Menu-open focus must not pop a tooltip; hover still does, and navigating re-enables focus tips.
func _quiet_focus(t: Object) -> void:
	Tip.focus_muted = false
	var b := Button.new()
	Tip._on_enter(b, true)   # not in the tree and not bound: must not crash
	Tip.focus_muted = true
	var ev := InputEventAction.new()
	ev.action = &"ui_down"
	ev.pressed = true
	var h: TipHost = TipHost.new()
	h._input(ev)
	t.ok(not Tip.focus_muted, "the first navigation input un-mutes focus tooltips")
	Tip.focus_muted = false
	h.free()
	b.free()
