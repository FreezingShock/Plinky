class_name FarLayer
extends Sprite2D
## The far backdrop (sky and mountains) as its own sprite behind the ground, drawn wider than the scene so it can slide.
## It follows the camera by a small share (`parallax_far` in content/config/sky.tres), so it moves a little slower than
## the ground in front of it: depth without leaving the pixel grid (the offset is rounded to whole texels).
## The water band and everything below the horizon stay in the ground art, so the shoreline never slips.

var base: Vector2 = Vector2.ZERO        # where the sprite sits when the camera is at the scene centre
var rest_center: Vector2 = Vector2(320.0, 180.0)   # the scene point at the screen centre when there is no shift
var k: float = 0.1


func _ready() -> void:
	name = "FarLayer"
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = base
	var cfg: SkyConfig = load("res://content/config/sky.tres") as SkyConfig
	if cfg != null:
		k = cfg.parallax_far


func _process(_delta: float) -> void:
	var host: Node2D = get_parent() as Node2D
	if host == null or k == 0.0:
		return
	var xf: Transform2D = host.get_global_transform_with_canvas()
	var sc: float = maxf(xf.x.length(), 0.001)
	var cam: Vector2 = (get_viewport_rect().size * 0.5 - xf.origin) / sc   # scene point at the screen centre
	position = base + ((cam - rest_center) * k).round()
