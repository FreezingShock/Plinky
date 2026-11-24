extends SceneTree
## Bakes the wheat clump sheets: eight gust frames per clump, drawn by WheatClump from each clump's seed, into
## assets/art/zone1b/farm/wheat/. The clumps are placed by tools/art/place_farm.py; run this after it.
## Run: godot --headless --path . --script tools/bake_wheat.gd   (then --import, so the game sees the new PNGs)


func _init() -> void:
	var data: Dictionary = FarmProps.load_manifest()
	var dir: String = ProjectSettings.globalize_path(FarmProps.DIR + "wheat")
	DirAccess.make_dir_recursive_absolute(dir)
	var n: int = 0
	for it: Variant in data.get("items", []) as Array:
		var item: Dictionary = it as Dictionary
		var kind: String = str(item.get("kind", ""))
		if not FarmProps.is_field(kind):
			continue
		var clump: Dictionary = WheatClump.generate(int(item.seed), int(item.w), int(item.h), int(item.stage))
		var sheet: Image = WheatClump.bake_sheet(clump)
		sheet.save_png(ProjectSettings.globalize_path(FarmProps.DIR + str(item.file)))
		n += 1
	print("baked %d wheat sheets" % n)
	quit(0)
