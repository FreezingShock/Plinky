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
