extends SceneTree
## Draws the walker atlas through WalkerBody, in the engine, for every facing: one column per octant (0 E, 1 SE, 2 S,
## 3 SW, 4 W, 5 NW, 6 N, 7 NE) and one row per pose (idle, walk 1-4, sprint 1-4). Saves a 3x PNG for QA.
## Run: xvfb-run -a godot --path . --script tools/walker_cells_shot.gd   (writes shots/walker/cells_8dir.png)

const SLOT_W: int = 48
const SLOT_H: int = 56
const SCALE: int = 3
const OUT: String = "res://shots/walker/cells_8dir.png"

var _frames: int = 0
var _vp: SubViewport


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(8 * SLOT_W, 9 * SLOT_H)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var colors: PackedColorArray = Palettes.colors(Palettes.MEADOW)
	for oct: int in 8:
		for row: int in 9:
			var index: int = WalkerPose.idle(oct) if row == 0 else (
				WalkerPose.walk(oct, row - 1) if row <= 4 else WalkerPose.sprint(oct, row - 5))
			var body := WalkerBody.new()
			body.position = Vector2(float(oct * SLOT_W + SLOT_W / 2), float(row * SLOT_H + SLOT_H - 6))
			body.cell = WalkerPose.cell_at(index)
			body.flip = WalkerPose.flip_of(oct)
			body.colors = colors
			_vp.add_child(body)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/walker"))
	var img: Image = _vp.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var err: Error = img.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT, " err=", err)
	quit(0 if err == OK else 1)
	return true
