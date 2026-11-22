class_name ToonMaterial
extends RefCounted
## Builders for the shared toon material. Object id 1 is ground; give every other prop its own id
## (or share one id for parts that should not outline each other).

const SHADER: Shader = preload("res://render/shaders/toon.gdshader")
const GROUND_ID := 1

static func make(lit_index: int, object_id: int, wind: float = 0.0, use_vertex_index: bool = false) -> ShaderMaterial:
	RenderGlobals.ensure()
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("lit_index", lit_index)
	m.set_shader_parameter("object_id", object_id)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("use_vertex_index", use_vertex_index)
	return m

## Blob shadow: use on a flat disc (radius 0.28 = 9x4 texels) just above the ground.
## ground_index must match the ground tile under it.
static func shadow(ground_index: int, drop: float = 0.34) -> ShaderMaterial:
	var m := make(ground_index, GROUND_ID)
	m.set_shader_parameter("shadow_drop", drop)
	return m
