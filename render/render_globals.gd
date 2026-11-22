class_name RenderGlobals
extends RefCounted
## Global shader uniforms used by toon.gdshader. Call ensure() before any toon material compiles.
## Added at runtime, so project.godot needs no edit.

static func ensure() -> void:
	var names := RenderingServer.global_shader_parameter_get_list()
	if not names.has(&"fx_time"):
		RenderingServer.global_shader_parameter_add(&"fx_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	if not names.has(&"fx_wind"):
		RenderingServer.global_shader_parameter_add(&"fx_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
