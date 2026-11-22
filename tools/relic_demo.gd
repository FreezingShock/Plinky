extends Control
## Demo and screenshot harness for the relic UI.
## godot --path . res://tools/relic_demo.tscn            (interactive)
## godot --path . res://tools/relic_demo.tscn -- --shot out.png [--hover N]   (saves a PNG and quits)

func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 12
	theme = th
	var bg := ColorRect.new()
	bg.color = Color("#1f3b35")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cfg: RelicConfig = load("res://content/relics/_config.tres")
	var defs: Array[RelicDef] = []
	for f in DirAccess.get_files_at("res://content/relics"):
		if f.ends_with(".tres") and not f.begins_with("_"):
			defs.append(load("res://content/relics/" + f))
	# Demo-only: one extra entry per missing rarity so every frame shows. Not shipped content.
	for rid in [&"divine", &"special"]:
		var d: RelicDef = (load("res://content/relics/r_pulse.tres") as RelicDef).duplicate()
		d.id = StringName("demo_" + String(rid))
		d.display_name = "Demo " + String(rid).capitalize()
		d.rarity = load("res://content/rarities/%s.tres" % rid)
		d.max_stacks = 0
		defs.append(d)
	var inv := RelicInventory.new(cfg, defs)
	inv.set_rebirths(5)
	var stacks := {&"r_cash": 7, &"r_rate": 3, &"r_mult": 2, &"r_crit": 1, &"r_double": 4, &"r_pulse": 1, &"demo_divine": 1, &"demo_special": 1}
	for id in stacks:
		inv.add_relic(id, stacks[id])
	for id in [&"r_double", &"r_cash", &"r_mult"]:
		inv.equip(id)

	var panel := RelicPanel.new()
	panel.position = Vector2(16, 16)
	add_child(panel)
	panel.bind(inv)
	var bar := RelicBar.new()
	bar.position = Vector2(560, 12)
	add_child(bar)
	bar.bind(inv)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--shot")
	if i >= 0:
		var hover: int = int(args[args.find("--hover") + 1]) if args.has("--hover") else -1
		await get_tree().process_frame
		await get_tree().process_frame
		if args.has("--full"):
			inv.set_rebirths(5)
			inv.equip(&"r_pulse")
			for c in panel._grid.get_children():
				if (c as RelicSlot).relic.id == &"r_crit":
					panel._on_pressed(c, false)
			await get_tree().process_frame
		if hover >= 0:
			var grid_slots: Array = panel._grid.get_children()
			(grid_slots[hover] as RelicSlot).hovered.emit(grid_slots[hover])
			(grid_slots[hover] as RelicSlot)._hover = true
			(grid_slots[hover] as RelicSlot).queue_redraw()
		for k in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(args[i + 1])
		get_tree().quit()
