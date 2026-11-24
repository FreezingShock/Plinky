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
## Frames the arriving scene draws under the cover before the reveal starts.
const WARM_FRAMES: int = 4
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


## Swap to `next` behind the cover, then reveal it. Returns at once; the swap runs on the host.
static func go(tree: SceneTree, next: PackedScene) -> void:
	host(tree).run(next)


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


## Captures the current frame, swaps to `next` under it, then reveals. A failed capture just swaps.
func run(next: PackedScene) -> void:
	if _busy or next == null:
		return
	_busy = true
	var tree: SceneTree = get_tree()
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
	for i: int in WARM_FRAMES:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	await _reveal(reduce)
	_rect.visible = false
	_mat.set_shader_parameter("snapshot", null)
	held.clear()
	_busy = false


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
