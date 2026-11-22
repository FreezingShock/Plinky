extends Control
## Demo / screenshot scene script. Attach to a Control (full rect) in an empty scene; PixelViewport sizes itself from its parent. Builds a 12x12 zone on a plinth,
## a tree, a pad, and a walker. Space = press ripple, 1/2/3 = zone palettes, I = invert, A = ASCII.

const T := 1.41421356   # world size of a 32x16 iso tile

var pv: PixelViewport
var walker: MeshInstance3D
var fx: Node
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv = PixelViewport.new()
	add_child(pv)
	await get_tree().process_frame
	_build(pv.world_root)
	fx = get_node_or_null("/root/Fx")
	if fx:
		fx.bind(pv)
	pv.camera.target = walker

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build(root: Node3D) -> void:
	var plinth := BoxMesh.new()
	plinth.size = Vector3(12.0 * T, 0.72, 12.0 * T)
	_mesh(root, plinth, Vector3(0, -0.37, 0), ToonMaterial.make(6, 2))
	var tile := BoxMesh.new()
	tile.size = Vector3(T, 0.02, T)
	for x in 12:
		for z in 12:
			var p := Vector3((x - 5.5) * T, 0.0, (z - 5.5) * T)
			_mesh(root, tile, p, ToonMaterial.make(4 if (x + z) % 2 == 0 else 3, ToonMaterial.GROUND_ID))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.01
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.09
	trunk.height = 0.8
	var crown := SphereMesh.new()
	crown.radius = 0.55
	crown.height = 1.1
	var tp := Vector3(-3.0, 0.0, -2.0)
	_mesh(root, disc, tp + Vector3(0, 0.02, 0), ToonMaterial.shadow(3))
	_mesh(root, trunk, tp + Vector3(0, 0.4, 0), ToonMaterial.make(6, 3))
	_mesh(root, crown, tp + Vector3(0, 1.2, 0), ToonMaterial.make(3, 4, 1.0))
	var pad := BoxMesh.new()
	pad.size = Vector3(1.2, 0.16, 1.2)
	_mesh(root, pad, Vector3(1.5, 0.08, 1.0), ToonMaterial.make(5, 5))
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 0.7
	walker = _mesh(root, cap, Vector3(0, 0.35, 0), ToonMaterial.make(5, 6))

func _process(delta: float) -> void:
	_t += delta
	if walker:
		walker.position = Vector3(cos(_t * 0.5) * 3.0, 0.35, sin(_t * 0.5) * 3.0)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed) or fx == null:
		return
	var m := pv.post_material
	match (e as InputEventKey).keycode:
		KEY_SPACE: fx.spawn_ripple(walker.position)
		KEY_1: fx.set_palette_now(Palettes.MEADOW)
		KEY_2: fx.set_zone_palette(Palettes.QUARRY); create_tween().tween_method(func(v: float) -> void: m.set_shader_parameter("shift", v), 0.0, 1.0, 1.5)
		KEY_3: fx.set_palette_now(Palettes.IRIS)
		KEY_I: m.set_shader_parameter("invert", 1.0 - float(m.get_shader_parameter("invert") if m.get_shader_parameter("invert") != null else 0.0))
		KEY_A: m.set_shader_parameter("ascii", 1.0 - float(m.get_shader_parameter("ascii")))
