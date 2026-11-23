extends RefCounted
## The index window opens through the same call the I and O keys use, and its dither wipe is on screen one frame later.
## (Hud and Main use the GameState autoload, which --script tests cannot compile, so the key press itself is not driven.)

func run(t: Object) -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	t.root.add_child(host)
	var panel := IndexPanel.new()
	host.add_child(panel)
	panel.bind(t.make_sim())
	t.ok(not panel.is_open(), "starts closed")
	panel.toggle_tab(IndexPanel.Tab.STATS)
	t.ok(panel.is_open(), "toggle opens the Stats tab")
	t.ok(panel.wipe_showing(), "wipe overlay is visible, sized, and above the panel the moment it opens")
	t.ok(panel._reveal.get_parent() == host, "overlay is a sibling of the panel, not under its content")
	t.ok(panel._reveal.size.x >= IndexPanel.WIDTH, "overlay covers the panel width")
	panel.toggle_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(panel.is_open() and panel.tab == IndexPanel.Tab.ATTRIBUTES, "toggling the other tab switches")
	panel.toggle_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(not panel.is_open(), "toggling the open tab closes it")
	host.free()
	panel._reveal.free()
