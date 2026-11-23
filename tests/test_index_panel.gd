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
	# detail page: opens on a card, lists sources, and Esc steps back before it closes
	FxConfig.reduce_flashing = true   # pages swap at once, no tween needed in a headless run
	panel.open_detail(&"crit_chance")
	t.ok(panel.detail_open() and panel.detail_id == &"crit_chance", "a card opens its detail page")
	t.ok(panel._d_sources.get_child_count() > 0, "the detail page lists sources")
	t.ok(panel.back_or_close() and not panel.detail_open() and panel.is_open(), "back returns to the gallery, still open")
	t.ok(panel.back_or_close() and not panel.is_open(), "back again closes the window")
	# buying from the Attributes detail page goes through the buyer callable and updates the page
	var bought: Array[StringName] = []
	panel.buyer = func(id: StringName) -> bool:
		bought.append(id)
		return true
	panel.open_tab(IndexPanel.Tab.ATTRIBUTES)
	panel.open_detail(&"luck")
	panel._on_buy()
	t.ok(bought == [&"luck"], "the buy button buys the attribute on show")
	FxConfig.reduce_flashing = false
	panel.toggle_tab(IndexPanel.Tab.STATS)
	panel.toggle_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(panel.is_open() and panel.tab == IndexPanel.Tab.ATTRIBUTES, "toggling the other tab switches")
	panel.toggle_tab(IndexPanel.Tab.ATTRIBUTES)
	t.ok(not panel.is_open(), "toggling the open tab closes it")
	host.free()   # frees the panel and its overlay together
