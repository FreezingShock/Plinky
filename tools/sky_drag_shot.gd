extends SceneTree
## Captures the draggable sun and moon on the title backdrop: resting, hovered, held mid-glide, held at an end, after a
## release, and the moon at night. Drives the real input path (warped pointer, mouse press and release), so the grab,
## the spring and the lift are the ones the player gets. Writes PNGs to shots/sky_drag/.
## Needs a real window, not --headless. Under Xvfb: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --script tools/sky_drag_shot.gd

const TITLE_SCENE: String = "res://boot/title_screen.tscn"
const SETTLE_FRAMES: int = 24
const GLIDE_FRAMES: int = 36

var _out_dir: String = ""


func _init() -> void:
	_out_dir = ProjectSettings.globalize_path("res://shots/sky_drag")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Autoloads are registered only after the first frame.
	await process_frame
	await _run()
	quit(0)


func _run() -> void:
	var title: TitleScreen = (load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen
	root.add_child(title)
	await _frames(SETTLE_FRAMES)
	var bg: TitleBackground = title._bg
	await _shot("1_golden_rest")

	# The sun at golden hour: hover, grab, drag toward the sunrise end and hold, then let go.
	var sun_at: Vector2 = bg.body_art()
	await _hover(bg, sun_at)
	await _shot("2_golden_hover")
	await _grab_and_drag(bg, sun_at, Vector2(300.0, 150.0), "3_sun_glide", "4_sun_held_sunrise")
	await _release(bg, "5_sun_released")

	# Drag the sun back past noon toward sunset, then release so the cycle carries on from there.
	var after: Vector2 = bg.body_art()
	await _grab_and_drag(bg, after, Vector2(500.0, 120.0), "6_sun_glide_back", "7_sun_held_sunset")
	await _release(bg, "8_sun_sunset_released")

	# Night: the moon rides its own half of the arc, so the same drag scrubs night.
	bg.set_phase_now(0.95)
	await _frames(SETTLE_FRAMES)
	await _shot("9_moon_rest")
	var moon_at: Vector2 = bg.body_art()
	await _hover(bg, moon_at)
	await _grab_and_drag(bg, moon_at, Vector2(360.0, 110.0), "10_moon_glide", "11_moon_held_late_night")
	await _release(bg, "12_moon_released")
	title.queue_free()


## Viewport position of an art point on the backdrop. Mouse events take these.
func _screen(bg: TitleBackground, art: Vector2) -> Vector2:
	return bg.get_global_transform_with_canvas() * (art + bg._art_origin())


## Window pixel position of an art point. The warp takes window pixels, and the stretched viewport is smaller than the window.
func _window_pos(bg: TitleBackground, art: Vector2) -> Vector2:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	return _screen(bg, art) * scale


func _hover(bg: TitleBackground, art: Vector2) -> void:
	Input.warp_mouse(_window_pos(bg, art + Vector2(6.0, -4.0)))
	await _frames(SETTLE_FRAMES)


## Press on the body, drag it along a path to the target over GLIDE_FRAMES, then hold. Shots: mid-glide and held.
func _grab_and_drag(bg: TitleBackground, from: Vector2, to: Vector2, glide_tag: String, held_tag: String) -> void:
	Input.warp_mouse(_window_pos(bg, from))
	await _frames(2)
	_mouse_button(_screen(bg, from), true)
	await _frames(2)
	var end_art: Vector2 = to
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_out_dir, glide_tag])
	for i in GLIDE_FRAMES:
		var f: float = float(i + 1) / float(GLIDE_FRAMES)
		var ease: float = f * f * (3.0 - 2.0 * f)
		Input.warp_mouse(_window_pos(bg, from.lerp(end_art, ease)))
		await process_frame
		# Every glide frame is kept, so the GIF shows the spring's lag and overshoot.
		await _shot("%s/%s_%02d" % [glide_tag, glide_tag, i])
		if i == GLIDE_FRAMES / 3:
			await _shot(glide_tag)
	await _frames(SETTLE_FRAMES * 2)
	await _shot(held_tag)


func _release(bg: TitleBackground, tag: String) -> void:
	var at: Vector2 = bg.get_local_mouse_position()
	_mouse_button(bg.get_global_transform_with_canvas() * at, false)
	await _frames(20)
	await _shot(tag)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out_dir, tag])
