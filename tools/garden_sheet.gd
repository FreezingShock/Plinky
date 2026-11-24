extends SceneTree
## Contact sheets of the garden flowers, one PNG per season: each row is a statistic in three head states (open, shut at night,
## dew at dawn), each column a variant (four small flowers, two shrubs, six field flowers), all at 4x with nearest filtering.
## Pure GardenArt, so it runs with --script (no autoloads).
## Run: godot --headless --path . --script tools/garden_sheet.gd -- out=<dir>/garden_sheet   (writes <prefix>_<season>.png)
## With no display, wrap it in xvfb-run. Look at the PNGs.

const SCALE: int = 4
const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]
const VARIANTS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16]   # four small, two shrubs, six field flowers


func _init() -> void:
	var prefix: String = "user://garden_sheet"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			prefix = a.substr(4)
	# one cell size for every sprite, so the rows line up
	var cw: int = 0
	var ch: int = 0
	for stat: StringName in GardenArt.STATS:
		for v in VARIANTS:
			var s: Vector2i = GardenArt.frame(stat, v, 0, GardenArt.SEASON_SUMMER).get_size()
			cw = maxi(cw, s.x)
			ch = maxi(ch, s.y)
	cw += 2
	ch += 2
	var rows: int = GardenArt.STATS.size() * 3
	for season in 4:
		var sheet := Image.create(cw * VARIANTS.size() * SCALE, ch * rows * SCALE, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("1d3b2e"))
		var row: int = 0
		for stat: StringName in GardenArt.STATS:
			for state in 3:
				for i in VARIANTS.size():
					var img: Image = GardenArt.frame(stat, VARIANTS[i], 0, season, state == 1, state == 2).get_image()
					img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
					var at := Vector2i(i * cw * SCALE + SCALE, row * ch * SCALE + (ch - 1) * SCALE - img.get_height() + SCALE)
					sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
				row += 1
		var path: String = "%s_%s.png" % [prefix, SEASON_NAMES[season]]
		var err: int = sheet.save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)
		print("garden sheet ", path, " ", sheet.get_width(), "x", sheet.get_height(), " err ", err)
	quit(0)
