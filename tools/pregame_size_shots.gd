extends SceneTree
## Captures every pre-game screen (loading, title, Settings, Saves, Credits, Update Log) at several window sizes.
## Writes PNGs to shots/pregame/. Needs a real window (not --headless); under Xvfb use xvfb-run.
## Run: godot --path . --import (once), then, for each size (fresh process each time):
##      godot --path . --resolution 2560x1080 --script tools/pregame_size_shots.gd -- 2560 1080 1
## User args: width, height, bleed flag (1 = 840x480 bleed art on), scale mode (0 Pixel, 1 Fit, 2 Wide; default 1).

const _UNUSED_SIZES: Array = [
	[800, 600, 1],
	[1024, 768, 0],
	[1280, 720, 1],
	[1920, 1080, 1],
	[2560, 1080, 1],
	[1600, 1000, 1],
	[3440, 1440, 1],
	[1280, 1024, 0],
]
const SETTLE_FRAMES: int = 14
const TITLE_SCENE: String = "res://boot/title_screen.tscn"
const BOOT_SCENE: String = "res://boot/boot.tscn"

var _out_dir: String = ""


func _init() -> void:
	_out_dir = ProjectSettings.globalize_path("res://shots/pregame")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Autoloads are registered only after the first frame.
	await process_frame
	# Run once per size with --resolution WxH (Xvfb does not apply runtime window resizes), then `-- W H bleed`.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var w: int = args[0].to_int() if args.size() > 0 else 1280
	var h: int = args[1].to_int() if args.size() > 1 else 720
	var bleed: int = args[2].to_int() if args.size() > 2 else 1
	var mode: int = args[3].to_int() if args.size() > 3 else DisplaySettings.Scale.FIT
	DisplaySettings.bleed_ready = bleed == 1
	DisplaySettings.set_scale_mode(root, mode)
	DisplaySettings.set_fullscreen(root, false)
	await _capture_size(w, h, bleed)
	quit(0)


func _capture_size(w: int, h: int, bleed: int) -> void:
	DisplaySettings.apply(root)
	await _settle()
	var real: Vector2i = DisplayServer.window_get_size()
	var tag: String = "%dx%d" % [real.x, real.y]
	print("info ", tag, " root.size=", root.size, " visible=", root.get_visible_rect().size, " final=", root.get_final_transform().x.x, " stretch=", root.content_scale_stretch, " aspect=", root.content_scale_aspect, " mode=", root.content_scale_mode)
	# Loading screen (boot), then the title with its menus open.
	var boot: Node = (load(BOOT_SCENE) as PackedScene).instantiate()
	root.add_child(boot)
	await _settle()
	await _save("%s/%s_loading.png" % [_out_dir, tag])
	boot.queue_free()
	await _settle()
	var title: Node = (load(TITLE_SCENE) as PackedScene).instantiate()
	root.add_child(title)
	await _settle()
	await _save("%s/%s_title.png" % [_out_dir, tag])
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _settle()
	await _save("%s/%s_game.png" % [_out_dir, tag])
	game.queue_free()
	await _settle()
	title.call("_open_settings")
	await _settle()
	await _save("%s/%s_settings.png" % [_out_dir, tag])
	title.call("_close_overlays")
	await _settle()
	title.call("_open_saves")
	await _settle()
	await _save("%s/%s_saves.png" % [_out_dir, tag])
	title.call("_close_overlays")
	await _settle()
	title.call("_open_credits")
	await _settle()
	await _save("%s/%s_credits.png" % [_out_dir, tag])
	title.call("_close_overlays")
	await _settle()
	title.queue_free()
	await _settle()


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


## Crop the window's pixels out of the screen grab (same method as tools/size_shots.gd).
func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var win_size: Vector2i = DisplayServer.window_get_size()
	var img: Image = null
	var screen: Image = DisplayServer.screen_get_image(0)
	if screen != null and not screen.is_empty():
		img = screen.get_region(Rect2i(win_pos, win_size))
	if img == null or img.is_empty():
		img = root.get_texture().get_image()
		print("WARN ", path, " window grab blank; saved the base canvas instead")
	print("save ", path, " size=", img.get_size(), " err=", img.save_png(path))
