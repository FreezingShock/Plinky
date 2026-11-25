class_name SceneSwap
extends CanvasLayer
## Scene changes with no flat frame. The screen being left is captured as it last drew and covers the window. The
## next scene is swapped in underneath while it is covered, so its load and first draw happen out of sight, and it
## gets WARM_FRAMES of drawing (first-use shader compiles finish there). Then the cover sweeps away to reveal it
## (scene_reveal.gdshader). Under Reduce Motion the cover cross-fades instead. The host sits under the root window,
## so it survives the scene change it covers.

const SHADER: Shader = preload("res://boot/scene_reveal.gdshader")
const REVEAL_SECONDS: float = 0.8
const FADE_SECONDS: float = 0.35
## Frames the arriving scene draws under the cover before the reveal starts. At least WARM_FRAMES, then until two frames in
## a row cost about the same (its first-use work is done), capped at WARM_MAX_FRAMES. A slow machine warms longer.
const WARM_FRAMES: int = 4
const WARM_MAX_FRAMES: int = 40
const SETTLE_RATIO: float = 0.2
## The group the arriving game joins while its entry occluders build (main.gd), and the cap on how long a swap waits.
const ENTRY_BUILDING_GROUP: StringName = &"entry_building"
const ENTRY_HOLD_MAX_FRAMES: int = 240
const HOST_NAME: String = "SceneSwap"
## Palette index of the sun-coloured lead line (the tagline colour on the loading screen).
const ACCENT_INDEX: int = 5

## Scenes loaded for the next screen. Held here so ResourceLoader's cache keeps them until the arriving scene uses
## them. Cleared once the reveal finishes.
static var held: Array[Resource] = []

static var _host: SceneSwap = null

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy: bool = false


## True while a swap is covering or revealing a screen. A second swap started now is dropped, so callers wait for this.
static func is_busy() -> bool:
	return _host != null and is_instance_valid(_host) and _host._busy


## The one host for the game, added under the root window the first time it is needed.
static func host(tree: SceneTree) -> SceneSwap:
	if _host == null or not is_instance_valid(_host):
		_host = SceneSwap.new()
		_host.name = HOST_NAME
		_host.layer = 90
		tree.root.add_child(_host)
	return _host


## Swap to `next` behind the cover, then reveal it. Returns at once; the swap runs on the host. With `same_backdrop`, the
## two screens draw the same backdrop, so only the foreground changes: a plain swap with no cover and no sweep.
static func go(tree: SceneTree, next: PackedScene, same_backdrop: bool = false) -> void:
	host(tree).run(next, same_backdrop)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("canvas_texels", Vector2(640.0, 360.0))
	_mat.set_shader_parameter("accent", Palettes.colors(Palettes.MEADOW)[ACCENT_INDEX])
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade", 1.0)
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks do not reach the leaving screen mid-swap
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## Captures the current frame, swaps to `next` under it, then reveals. A failed capture just swaps. A request that arrives
## while another swap is still running waits for it, so it is never dropped (a dropped Play left the title stuck).
func run(next: PackedScene, same_backdrop: bool = false) -> void:
	if next == null:
		return
	var tree: SceneTree = get_tree()
	while _busy:
		await tree.process_frame
	_busy = true
	if same_backdrop:
		tree.change_scene_to_packed(next)
		await tree.scene_changed
		_busy = false
		return
	var reduce: bool = TitleBackground.still()
	await RenderingServer.frame_post_draw
	var img: Image = tree.root.get_texture().get_image()
	if img != null:
		_mat.set_shader_parameter("snapshot", ImageTexture.create_from_image(img))
		_mat.set_shader_parameter("progress", 0.0)
		_mat.set_shader_parameter("fade", 1.0)
		_rect.visible = true
	tree.change_scene_to_packed(next)
	await tree.scene_changed
	await _warm(tree)
	await _hold_for_entry(tree)
	await _reveal(reduce)
	_rect.visible = false
	_mat.set_shader_parameter("snapshot", null)
	held.clear()
	_busy = false


## Holds the reveal while the arriving game is still building its entry occluders over frames (main.gd joins the
## ENTRY_BUILDING group). Capped, so a build that never ends cannot hold the swap.
func _hold_for_entry(tree: SceneTree) -> void:
	for i: int in ENTRY_HOLD_MAX_FRAMES:
		if tree.get_first_node_in_group(ENTRY_BUILDING_GROUP) == null:
			return
		await tree.process_frame


## Lets the arriving scene draw under the cover until it settles (see WARM_FRAMES).
func _warm(tree: SceneTree) -> void:
	var prev: int = Time.get_ticks_usec()
	var last_dt: float = -1.0
	for i: int in WARM_MAX_FRAMES:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = float(now - prev)
		prev = now
		if i + 1 >= WARM_FRAMES and last_dt > 0.0 and absf(dt - last_dt) <= last_dt * SETTLE_RATIO:
			break
		last_dt = dt
	await RenderingServer.frame_post_draw


func _reveal(reduce: bool) -> void:
	var tw: Tween = create_tween()
	if reduce:
		tw.tween_method(_set_fade, 1.0, 0.0, FADE_SECONDS)
	else:
		tw.tween_method(_set_progress, 0.0, 1.0, REVEAL_SECONDS)
	await tw.finished


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


func _set_fade(v: float) -> void:
	_mat.set_shader_parameter("fade", v)
