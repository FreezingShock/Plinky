extends SceneTree
## Larkmoor view-streaming probe: pans the camera away from the walker and checks that every chunk on screen is loaded.
## For each zoom and pan offset it reports the frames until the screen is fully covered (pop-in window), the chunks on
## screen that are still missing in any frame of the pan (worst_missing, must be 0), the loaded prop count and the node count.
##
## godot --headless --path . --script tools/larkmoor_view_probe.gd   (windowed runs are the ones to compare: no --headless)
## Headless: node counts and chunk coverage are real, frame times are not (see larkmoor_stream_bench.gd).

const SETTLE_FRAMES: int = 90
const PANS: Array[Vector2] = [Vector2(0, 0), Vector2(900, 0), Vector2(-900, 0), Vector2(0, 600), Vector2(700, -500)]
const ZOOMS: Array[int] = [1, 2, 4]

var _main: Node = null


func _init() -> void:
	await process_frame
	PerfStats.tracing = false
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	_main = main
	root.add_child(main)
	current_scene = main
	root.get_node("Save").set("enabled", false)
	var sim: Sim = main.get("sim") as Sim
	sim.new_game()
	await _frames(90)
	for z: ZoneDef in sim.zone_defs.values():
		if z.next_zone == &"larkmoor":
			sim.gates_open[z.id] = true
	if sim.zone_id != &"larkmoor" and not sim.enter_zone(&"larkmoor"):
		printerr("view probe: could not enter Larkmoor")
		quit(1)
		return
	await _frames(180)
	var cam: WorldCamera = main.get("camera") as WorldCamera
	var scene: Node = null
	for c: Node in (main.get("world") as Node).get_children():
		if c.has_method("loaded_prop_count"):
			scene = c
	if scene == null:
		printerr("view probe: no Larkmoor scene under world")
		quit(1)
		return
	# The texture warm pass is off in headless (world/larkmoor_scene.gd _drain_warm), so pan pop-in here runs higher than a
	# windowed run: the windowed PC run of this pan showed 3 pop-in frames where headless shows about 10.
	if DisplayServer.get_name() == "headless":
		print("NOTE headless: the texture warm pass is off, so pop-in counts run high. Windowed PC runs of the zoom 1 (700,-500) pan show about 3 frames.")
	print("zoom  pan              popin_frames  worst_missing  loaded_props  max_nodes")
	for zoom: int in ZOOMS:
		cam.zoom_step(zoom - cam.zoom_level, cam.frame * 0.5)
		for pan: Vector2 in PANS:
			# every frame of the pan is checked: a frame with an on-screen chunk not yet loaded is a pop-in frame
			var popin_frames: int = 0
			var worst_missing: int = 0
			var max_nodes: int = 0
			for i: int in SETTLE_FRAMES:
				cam.hold_pan(pan)
				await process_frame
				var missing: int = _missing_on_screen(scene)
				if missing > 0:
					popin_frames += 1
				worst_missing = maxi(worst_missing, missing)
				max_nodes = maxi(max_nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			print("%4d  %-16s %13d  %12d  %12d  %5d  view=%s walker=%s cam_pan=%s" % [zoom, str(pan), popin_frames, worst_missing, int(scene.call("loaded_prop_count")), max_nodes, str(scene.get("_view")), str((main.get("walker") as Node2D).position), str(cam.pan)])
		cam.pan = Vector2.ZERO
		await _frames(30)
	quit(0)


## Chunks on screen (the view rect, no margin) that are not loaded. Empty view means outside the tree: counted as 0.
func _missing_on_screen(scene: Node) -> int:
	var view: Rect2i = scene.get("_view") as Rect2i
	var loaded: Dictionary = scene.get("_loaded") as Dictionary
	var n: int = 0
	for y: int in range(view.position.y, view.end.y):
		for x: int in range(view.position.x, view.end.x):
			if not loaded.has(Vector2i(x, y)):
				n += 1
	return n


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
