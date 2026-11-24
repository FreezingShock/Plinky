extends Node
## Frame capture for the title -> loading -> game handoff. Runs boot.tscn as a real game would, presses Play on the
## title, and saves every drawn frame as a PNG, logging the scene events against frame numbers. Set
## TRANSITION_REDUCE=1 to run with Reduce Motion on (the cross-fade path).
## Run: godot --path . tools/transition_frames.tscn      Output: $TRANSITION_OUT (default /tmp/transition_frames)

const MAX_FRAMES: int = 900
const TITLE_SETTLE_SECONDS: float = 1.5
const GAME_HOLD_SECONDS: float = 1.5

var _out: String = ""
var _frames: int = 0
var _elapsed: float = 0.0
var _state: String = "boot"
var _state_t: float = 0.0
var _log: FileAccess
var _last_scene_name: String = ""
var _times: FileAccess


func _ready() -> void:
	# The scene this is attached to is replaced by the swap. So the first run copies this node under the root window,
	# where it survives, and the copy does the driving.
	if not has_meta("driver"):
		var driver := Node.new()
		driver.set_script(get_script())
		driver.set_meta("driver", true)
		get_tree().root.add_child.call_deferred(driver)
		return
	var env_out: String = OS.get_environment("TRANSITION_OUT")
	_out = env_out if env_out != "" else "/tmp/transition_frames"
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out + "/events.txt", FileAccess.WRITE)
	_times = FileAccess.open(_out + "/times.csv", FileAccess.WRITE)
	_times.store_line("frame,delta_ms,scene")
	if OS.get_environment("TRANSITION_REDUCE") == "1":
		FxConfig.reduce_flashing = true
		MeadowLife.reduce_motion = true
		_event("reduce motion ON")
	RenderingServer.frame_post_draw.connect(_grab)
	get_tree().change_scene_to_file.call_deferred("res://boot/boot.tscn")
	_event("start")


func _event(name: String) -> void:
	var line: String = "EVENT %s frame=%d t=%.2f" % [name, _frames, _elapsed]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _process(delta: float) -> void:
	_elapsed += delta
	_state_t += delta
	if _times != null:
		_times.store_line("%d,%.2f,%s" % [_frames, delta * 1000.0, _last_scene_name])
	var scene: Node = get_tree().current_scene
	var scene_name: String = scene.scene_file_path if scene != null else ""
	if scene_name != _last_scene_name and scene_name != "":
		_event("scene %s" % scene_name)
		_last_scene_name = scene_name
	if _state == "boot" and scene is TitleScreen:
		_state = "title"
		_state_t = 0.0
	elif _state == "title" and _state_t >= TITLE_SETTLE_SECONDS:
		_event("press play")
		(scene as TitleScreen)._on_play()
		_state = "swapping"
		_state_t = 0.0
	elif _state == "swapping" and scene_name == "res://main.tscn":
		_state = "game"
		_state_t = 0.0
	elif _state == "game" and _state_t >= GAME_HOLD_SECONDS:
		_event("done")
		_log.close()
		_times.close()
		get_tree().quit(0)
	if _frames >= MAX_FRAMES:
		_event("frame cap reached")
		get_tree().quit(2)


func _grab() -> void:
	if _frames >= MAX_FRAMES:
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	img.save_png("%s/f%04d.png" % [_out, _frames])
	_frames += 1
