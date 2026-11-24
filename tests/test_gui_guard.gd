extends RefCounted
## A click on any GUI must not reach the world: tap-to-move and its walk ring ask GuiGuard first.

func run(t: Object) -> void:
	PadInput.menu_open = false   # other suites may leave a menu flag set
	var view := Vector2(640, 360)   # a fixed screen, so the test does not depend on the window size
	var host := Control.new()       # kept out of the live tree, so suites that leave nodes behind do not interfere
	host.size = view

	var veil := Control.new()   # full-screen PASS layout root: must not block the world
	veil.size = view
	veil.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(veil)

	var panel := Panel.new()   # a menu background: IGNORE filter, but still GUI
	panel.position = Vector2(20, 20)
	panel.size = Vector2(120, 80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(panel)

	var pass_ctl := Control.new()   # a PASS control, e.g. a card that lets clicks through to its parent
	pass_ctl.position = Vector2(200, 20)
	pass_ctl.size = Vector2(40, 40)
	pass_ctl.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(pass_ctl)

	var stop_ctl := Control.new()   # a STOP control, e.g. a button
	stop_ctl.position = Vector2(260, 20)
	stop_ctl.size = Vector2(40, 40)
	stop_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(stop_ctl)

	var label := Control.new()   # an IGNORE label over the world, like a floating number: must not block
	label.position = Vector2(320, 20)
	label.size = Vector2(40, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)

	var hidden := Control.new()   # hidden: takes no clicks
	hidden.position = Vector2(380, 20)
	hidden.size = Vector2(40, 40)
	hidden.mouse_filter = Control.MOUSE_FILTER_STOP
	hidden.visible = false
	host.add_child(hidden)

	t.ok(GuiGuard.covers(host, Vector2(60, 60), view), "a click on a menu panel is GUI, even with an IGNORE filter")
	t.ok(GuiGuard.covers(host, Vector2(220, 40), view), "a click on a PASS control is GUI")
	t.ok(GuiGuard.covers(host, Vector2(280, 40), view), "a click on a STOP control is GUI")
	t.ok(not GuiGuard.covers(host, Vector2(330, 30), view), "an IGNORE label that is not a panel does not block the world")
	t.ok(not GuiGuard.covers(host, Vector2(390, 30), view), "a hidden control does not block the world")
	t.ok(not GuiGuard.covers(host, Vector2(600, 300), view), "empty world space under a full-screen PASS root is not GUI")

	panel.visible = false
	t.ok(not GuiGuard.covers(host, Vector2(60, 60), view), "a closed menu panel stops blocking")

	# A full-screen Panel with no menu open is a faded or layout layer: it must not swallow the world.
	var dim := Panel.new()
	dim.size = view
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(dim)
	PadInput.menu_open = false
	t.ok(not GuiGuard.covers(host, Vector2(600, 300), view), "a full-screen panel with no menu open does not block the world")
	PadInput.menu_open = true
	t.ok(GuiGuard.covers(host, Vector2(600, 300), view), "the same full-screen panel blocks while a menu is open")
	PadInput.menu_open = false
	dim.visible = false

	# A fully transparent control draws nothing, so it does not block, even when it is visible and in front.
	var clear := Panel.new()
	clear.position = Vector2(440, 20)
	clear.size = Vector2(40, 40)
	clear.modulate.a = 0.0
	host.add_child(clear)
	t.ok(not GuiGuard.covers(host, Vector2(450, 30), view), "a fully transparent panel does not block the world")

	host.free()
	t.ok(not GuiGuard.covers(null, Vector2.ZERO), "no tree means no GUI")
