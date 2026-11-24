extends SceneTree
## Captures every pre-game screen (loading, title, Settings, Saves, Credits) and then the in-game scene at one window
## size, with a numeric check of each shot. Writes PNGs to shots/pregame/.
##
## Reliability (why this is not just a grab after a few frames):
##   - It waits until the OS window has the requested size, and the root has taken it, before anything is drawn.
##   - Each shot waits for the paint, then rejects a grab that is blank, white or the wrong size, and retries.
##   - Each shot prints the measured letterbox bars at all four edges (the share of near-black edge pixels).
##     A pre-game shot should read 0% on every edge. The game reads bars on non-16:9 windows.
##   - A shot that never passes prints FAIL and the run exits with code 2, so a bad capture cannot pass silently.
##
## Run one process per size (Xvfb does not apply runtime window resizes):
##   godot --path . --resolution 1616x1039 --script tools/pregame_size_shots.gd -- 1616 1039 1 1
## User args: width, height, bleed flag (1 = 840x480 bleed art on), scale mode (0 Pixel, 1 Fit, 2 Wide; default 1).
## Needs a real window (not --headless). Under Xvfb use xvfb-run.

const SETTLE_FRAMES: int = 14
const SIZE_WAIT_FRAMES: int = 240
const SHOT_ATTEMPTS: int = 8
const TITLE_SCENE: String = "res://boot/title_screen.tscn"
const BOOT_SCENE: String = "res://boot/boot.tscn"
const GAME_SCENE: String = "res://main.tscn"
## Share of pixels on an edge that may be near-black before the edge counts as a bar.
const BAR_BLACK: float = 0.01

var _out_dir: String = ""
var _failed: bool = false


func _init() -> void:
	_out_dir = ProjectSettings.globalize_path("res://shots/pregame")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Autoloads are registered only after the first frame.
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var w: int = args[0].to_int() if args.size() > 0 else 1280
	var h: int = args[1].to_int() if args.size() > 1 else 720
	var bleed: int = args[2].to_int() if args.size() > 2 else 1
	var mode: int = args[3].to_int() if args.size() > 3 else DisplaySettings.Scale.FIT
	DisplaySettings.bleed_ready = bleed == 1
	DisplaySettings.set_scale_mode(root, mode)
	DisplaySettings.set_fullscreen(root, false)
	DisplaySettings.apply(root)
	var want := Vector2i(w, h)
	await _wait_for_size(want)
	await _capture_all(want, mode)
	quit(2 if _failed else 0)


## Wait until the OS window and the root both have the requested size. Logs a FAIL if they never agree.
func _wait_for_size(want: Vector2i) -> void:
	for i in SIZE_WAIT_FRAMES:
		await process_frame
		if DisplayServer.window_get_size() == want and root.size == want:
			await _settle()
			print("size ok ", want)
			return
	_failed = true
	print("FAIL size window=", DisplayServer.window_get_size(), " root=", root.size, " wanted=", want)


func _capture_all(want: Vector2i, mode: int) -> void:
	var tag: String = "%dx%d_%s" % [want.x, want.y, ["pixel", "fit", "wide"][mode]]
	print("info ", tag, " screen_scale=", DisplayServer.screen_get_scale(0), " root.size=", root.size, " visible=", root.get_visible_rect().size, " final=", root.get_final_transform().x.x, " aspect=", root.content_scale_aspect)
	# Loading screen, then the title and its panels.
	var boot: Node = (load(BOOT_SCENE) as PackedScene).instantiate()
	root.add_child(boot)
	await _settle()
	await _save("%s/%s_loading.png" % [_out_dir, tag], want)
	boot.queue_free()
	await _settle()
	var title: Node = (load(TITLE_SCENE) as PackedScene).instantiate()
	root.add_child(title)
	await _settle()
	await _save("%s/%s_title.png" % [_out_dir, tag], want)
	title.call("_open_settings")
	await _settle()
	await _save("%s/%s_settings.png" % [_out_dir, tag], want)
	title.call("_close_overlays")
	await _settle()
	title.call("_open_saves")
	await _settle()
	await _save("%s/%s_saves.png" % [_out_dir, tag], want)
	title.call("_close_overlays")
	await _settle()
	title.call("_open_credits")
	await _settle()
	await _save("%s/%s_credits.png" % [_out_dir, tag], want)
	title.call("_close_overlays")
	await _settle()
	title.queue_free()
	await _settle()
	# The game last: it turns the pre-game fill off, which would letterbox any title screen opened after it.
	var game: Node = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(game)
	await _settle()
	await _save("%s/%s_game.png" % [_out_dir, tag], want)
	game.queue_free()
	await _settle()


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


## Grab the window's pixels, check the grab, and retry until it passes or the attempts run out.
func _save(path: String, want: Vector2i) -> void:
	for attempt in SHOT_ATTEMPTS:
		await _settle()
		await RenderingServer.frame_post_draw
		var win_pos: Vector2i = DisplayServer.window_get_position()
		var win_size: Vector2i = DisplayServer.window_get_size()
		if win_size != want:
			print("retry ", path, " window size ", win_size, " != ", want)
			continue
		var screen: Image = DisplayServer.screen_get_image(0)
		if screen == null or screen.is_empty():
			print("retry ", path, " no screen grab")
			continue
		var img: Image = screen.get_region(Rect2i(win_pos, win_size))
		var state: String = _grab_state(img)
		if state != "ok":
			print("retry ", path, " grab is ", state, " (attempt ", attempt + 1, ")")
			continue
		img.save_png(path)
		print("save ", path, " size=", img.get_size(), " bars ", _bars(img))
		return
	_failed = true
	print("FAIL ", path, " no clean grab after ", SHOT_ATTEMPTS, " attempts")


## "ok", or why the grab is not usable: blank (fully transparent), white (the bare X background before the first paint).
func _grab_state(img: Image) -> String:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w == 0 or h == 0:
		return "empty"
	var blank: int = 0
	var white: int = 0
	var n: int = 0
	for gy in 24:
		for gx in 24:
			var px: Color = img.get_pixel(clampi(w * gx / 23, 0, w - 1), clampi(h * gy / 23, 0, h - 1))
			n += 1
			if px.a <= 0.0:
				blank += 1
			elif minf(px.r, minf(px.g, px.b)) > 0.95:
				white += 1
	if blank > n / 2:
		return "blank"
	if white > n / 2:
		return "white"
	return "ok"


## The share of each edge's pixels that are near-black, as "left/right/top/bottom" percentages.
func _bars(img: Image) -> String:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var left: float = _edge_black(img, 0, true, h)
	var right: float = _edge_black(img, w - 1, true, h)
	var top: float = _edge_black(img, 0, false, w)
	var bottom: float = _edge_black(img, h - 1, false, w)
	return "L%d%% R%d%% T%d%% B%d%%" % [roundi(left * 100.0), roundi(right * 100.0), roundi(top * 100.0), roundi(bottom * 100.0)]


## Share of near-black pixels along one edge line. vertical: the column x; otherwise the row y.
func _edge_black(img: Image, at: int, vertical: bool, length: int) -> float:
	var black: int = 0
	for i in length:
		var px: Color = img.get_pixel(at, i) if vertical else img.get_pixel(i, at)
		if maxf(px.r, maxf(px.g, px.b)) < BAR_BLACK:
			black += 1
	return float(black) / float(maxi(1, length))
