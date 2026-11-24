extends Node
## Gifts menu shots: the Upgrades panel on the Bloom (meadow) tab and the Nucleus (quarry) tab, plus the Seeds row tooltip.
## Run: xvfb-run -a godot --path . tools/gifts_shot.tscn -- [tag]   (tag names the PNGs; default "gifts")

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(4)
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _run(zone: StringName, tag: String) -> void:
	var sim: Sim = GameState.sim
	sim.zone_id = zone
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	main.menus.open(&"upgrades")
	await _wait(12)
	await _shot("%s_upgrades_%s" % [tag, String(zone)])
	# Keyboard and pad: with a card focused, Right and the shoulder button step the tabs.
	var card: Control = null
	for c: Variant in main.hud._attr_rows.values():
		if (c as Control).is_visible_in_tree():
			card = c as Control
			break
	var tab_before: StringName = main.hud._upg_tab
	if card != null:
		card.grab_focus()
		await _wait(2)
		var key := InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.physical_keycode = KEY_RIGHT
		key.pressed = true
		main.hud._input(key)
		await _wait(2)
		print("keyboard right from a card ", String(tab_before), " -> ", String(main.hud._upg_tab))
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_LEFT_SHOULDER
		pad.pressed = true
		main.hud._input(pad)
		await _wait(2)
		print("pad left shoulder ", String(main.hud._upg_tab))
		main.hud._select_upgrade_tab(tab_before)
	# Layout check: the panel keeps one size across tabs, and a zone currency's row opens its own tab.
	var panel: Control = main.hud._upgrades_panel
	var before: Vector2 = panel.size
	main.hud._select_upgrade_tab(&"shards" if zone == &"zone1" else &"seeds")
	await _wait(6)
	print("panel size ", String(zone), " before ", before, " after tab ", panel.size)
	main.hud._select_upgrade_tab(&"seeds" if zone == &"zone1" else &"shards")
	await _wait(6)
	print("panel size ", String(zone), " back ", panel.size)
	await _shot("%s_upgrades_tab_%s" % [tag, String(zone)])
	main.menus.close_all()
	await _wait(12)
	# The zone currency's row tooltip, beside its row.
	var sid: StringName = &"seeds" if zone == &"zone1" else &"shards"
	var row: Control = main.hud._row_boxes.get(sid) as Control
	# A click on the row opens Upgrades on this currency's tab, whichever tab was open before.
	main.hud.open_gifts(sid)
	await _wait(8)
	print("row click ", String(sid), " visible ", main.hud._upgrades_panel.visible, " tab ", String(main.hud._upg_tab))
	# The other zone's row, from here: each currency must open its own tab from any zone.
	var other: StringName = &"shards" if sid == &"seeds" else &"seeds"
	main.menus.close_all()
	await _wait(10)
	main.hud.open_gifts(other)
	await _wait(8)
	print("cross-zone row click ", String(other), " from ", String(zone), " tab ", String(main.hud._upg_tab))
	main.menus.close_all()
	await _wait(10)
	if row != null:
		Tip.hide_all()
		main.walker.stop()
		main.walker.position += Vector2(0.0, 900.0)   # step the walker off the gate, so its passage tip does not take the host
		await _wait(8)
		Tip.show_beside(get_tree(), row.get_meta(&"_tip_spec"), row.get_global_rect())
		await _wait(2)
		Tip.show_beside(get_tree(), row.get_meta(&"_tip_spec"), row.get_global_rect())
		await _shot("%s_tip_%s" % [tag, String(sid)])
		Tip.hide_all()
		await _wait(4)
	main.queue_free()
	await _wait(5)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var tag: String = "gifts"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.gates_open[&"zone2"] = true
	sim.dev_open_tiers()
	sim.reset_counts[&"bloom"] = 2
	sim.reset_counts[&"nucleus"] = 1
	sim.stats[&"seeds"] = BigNum.from_float(11970.0)
	sim.stats[&"shards"] = BigNum.from_float(6.85)
	await _run(&"zone1", tag)
	await _run(&"zone2", tag)
	get_tree().quit(0)
