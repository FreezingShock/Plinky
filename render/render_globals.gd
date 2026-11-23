class_name RenderGlobals
extends RefCounted
## Global shader uniforms used by toon.gdshader. Call ensure() before any toon material compiles.
## Added at runtime, so project.godot needs no edit.

static var _added: bool = false

static func ensure() -> void:
	# global_shader_parameter_get_list() is editor-only and errors at runtime, so track our own adds.
	if _added:
		return
	_added = true
	RenderingServer.global_shader_parameter_add(&"fx_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(&"fx_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	RenderingServer.global_shader_parameter_add(&"world_origin", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2.ZERO)
	RenderingServer.global_shader_parameter_add(&"world_scale", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)


## The `world` Node2D's position and scale (WorldCamera). World shaders divide these out of MODEL_MATRIX so their
## dither cells are whole world texels at every zoom and stay put on the ground while the camera moves.
static func set_world(origin: Vector2, scale: float) -> void:
	ensure()
	RenderingServer.global_shader_parameter_set(&"world_origin", origin)
	RenderingServer.global_shader_parameter_set(&"world_scale", maxf(scale, 0.001))
