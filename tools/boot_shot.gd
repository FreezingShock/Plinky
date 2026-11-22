extends SceneTree
## Captures the boot screen after N frames, then quits. Needs a window (run under xvfb-run).
## Run: godot --path . --script tools/boot_shot.gd -- out.png frames

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://boot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 60
	var packed: PackedScene = load("res://boot/boot.tscn") as PackedScene
	root.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	print("save ", out, " err=", img.save_png(out), " size=", img.get_size())
	quit(0)
