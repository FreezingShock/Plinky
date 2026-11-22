class_name PixelViewport
extends Control
## 642x362 SubViewport shown at a whole-number scale with nearest filtering, letterboxed.
## Add 3D content to `world_root`. The post ColorRect (`post`) is the node UI Transitions drives:
## it exposes the uniforms `shift`, `invert`, `ascii`. Set `screen_shake` to apply its whole-texel offset.

const BASE := Vector2i(640, 360)
const VIEW := Vector2i(642, 362)
const POST_SHADER: Shader = preload("res://render/shaders/post_dither.gdshader")

@export var camera: IsoCamera
@export var screen_shake: ScreenShake
@export var start_palette: StringName = Palettes.MEADOW

var viewport: SubViewport
var world_root: Node3D
var post: ColorRect
var post_material: ShaderMaterial
var scale_factor: int = 1
var _clip: Control

func _init() -> void:
	RenderGlobals.ensure()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # world input is read via _unhandled_input; a STOP control here would eat every click
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	viewport = SubViewport.new()
	viewport.size = VIEW
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.use_debanding = false
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	viewport.add_child(world_root)
	if camera == null:
		camera = IsoCamera.new()
	viewport.add_child(camera)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	post = ColorRect.new()
	post.size = Vector2(VIEW)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = POST_SHADER
	post_material.set_shader_parameter("world", viewport.get_texture())
	post_material.set_shader_parameter("palette_a", Palettes.texture(start_palette))
	post_material.set_shader_parameter("palette_b", Palettes.texture(start_palette))
	post.material = post_material
	_clip.add_child(post)
	_layout()

func _process(_delta: float) -> void:
	_layout()

## Position in the 642x362 texel space of a world point (for ripples and popups).
func world_to_texel(pos: Vector3) -> Vector2:
	return camera.unproject_position(pos)

func _layout() -> void:
	scale_factor = maxi(1, mini(int(size.x) / BASE.x, int(size.y) / BASE.y))
	# The post fills the whole frame, not just a 640x360 box in the middle, so the backdrop colour,
	# the bleed around the view, and the Transitions effects (invert, shift, ascii) reach every edge.
	# At 640x360 this is exactly the old layout; a bigger frame stretches the 640 body over it.
	_clip.size = size
	_clip.position = Vector2.ZERO
	var shake := screen_shake.offset if screen_shake else Vector2.ZERO
	var fill: Vector2 = size / Vector2(BASE)
	post.scale = fill
	post.position = (camera.frac_shift + shake - Vector2.ONE) * fill
	post_material.set_shader_parameter("dither_origin", Vector2i(camera.snap_texels.x, -camera.snap_texels.y))
