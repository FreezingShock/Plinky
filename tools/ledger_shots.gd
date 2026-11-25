extends Node
## Captures the gallery menu with its Ledger tile, the Ledger at the top and scrolled, and an unlock toast, to shots/.
## Run: godot --path . tools/ledger_shots.tscn   (needs a window; never writes the real save)

var main: Control
var root: Window



func _shot(name: String) -> void:
	await ShotHelpers.wait(3)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _ready() -> void:
	root = get_tree().root
	Save.enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var sim: Sim = GameState.sim
	sim.press_count = 1500
	sim.run_stats.crits = 12
	sim.run_stats.streaks_done = 3
	sim.run_stats.best_tier = 2
	sim.rebirth_count = 5
	sim.relic_drops = 4
	sim.relics.add_relic(&"r_cash")
	sim.relics.add_relic(&"r_rate")
	sim.relics.add_relic(&"r_crit")
	sim.dev_set_stat(&"dewdrop", BigNum.from_float(300.0))
	sim.play_seconds = 4000.0
	sim.achievements.clear()
	sim.check_achievements()
	await ShotHelpers.wait(20)
	main.menus.open(&"gallery")
	await ShotHelpers.wait(30)
	await _shot("ledger_gallery")
	main.menus.open(&"ledger")
	await ShotHelpers.wait(30)
	await _shot("ledger_top")
	main.ledger_panel._scroll.scroll_vertical = 520
	await ShotHelpers.wait(10)
	await _shot("ledger_mid")
	main.ledger_panel._scroll.scroll_vertical = 100000
	await ShotHelpers.wait(10)
	await _shot("ledger_end")
	main.menus.close(&"ledger")
	await ShotHelpers.wait(30)
	sim.dev_set_stat(&"starbloom", BigNum.from_float(150.0))
	sim.check_achievements()
	await ShotHelpers.wait(30)
	await _shot("ledger_toast")
	get_tree().quit(0)
