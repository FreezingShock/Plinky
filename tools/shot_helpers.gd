class_name ShotHelpers
extends RefCounted
## Helpers shared by the capture, probe and bench tools. Each tool used to copy its own frame wait; this is the one copy.
## Tools run with --script, so this has no autoloads and no nodes.


## Waits `n` rendered frames. Works from any script the main loop runs (a SceneTree script or a Node in the tree).
static func wait(n: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in n:
		await tree.process_frame
