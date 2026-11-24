extends Node
## Real main scene: the walker taps its way to a pad from a chosen start. Run: godot --path . tools/qa_probe.tscn -- x=2127 y=1039 pad=lark_clover_1
var main: Control
func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _ready() -> void:
	var sx: float = 2127.0
	var sy: float = 1039.0
	var pad_id: StringName = &"lark_clover_1"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("x="): sx = float(a.substr(2))
		elif a.begins_with("y="): sy = float(a.substr(2))
		elif a.begins_with("pad="): pad_id = StringName(a.substr(4))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	sim.dev_open_tiers()
	if "rich" in OS.get_cmdline_user_args():
		for k: StringName in sim.stat_defs:
			sim.stats[k] = BigNum.from_float(1.0e12)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var pad: Node2D = main.pads[pad_id]
	var w: TexelWalker = main.walker
	w.position = Vector2(sx, sy)
	await _wait(20)
	print("start ", w.position, " walkable ", WalkMask.walkable(w.position), " pad ", pad.position)
	w.go_to(pad.position)
	print("target ", w._target, " route ", w._route.size(), " ", w._route)
	var f: int = 0
	var last: Vector2 = w.position
	while w._has_target and f < 3000:
		await get_tree().process_frame
		f += 1
		if f % 60 == 0:
			print("  f", f, " pos ", w.position, " goal ", w._goal(), " route_i ", w._route_i, " replans ", w._replans)
	print("RESULT stopped ", w.position.distance_to(pad.position), " short after ", f, " frames at ", w.position, " target ", w._target)
	get_tree().quit(0)
