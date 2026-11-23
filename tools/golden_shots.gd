extends Node
## Time-of-day capture: starts the real game (Larkmoor by default, `meadow` for zone 1), pins the season to spring
## and the sky to each phase in PHASES with SkyCycle.debug_phase, and saves PNGs to shots/golden_<name>.png.
## Run: godot --path . tools/golden_shots.tscn [-- meadow] [-- season=N]   (shots/ is gitignored)
## The label is the clock time on the calendar (3 min day: sunrise 04:48, noon 12:00, sunset 19:12).
const PHASES: Array = [
	["0448_sunrise", 0.25], ["0600_early", 0.30], ["0808_morning", 0.366], ["1000_late_morning", 0.43],
	["1200_noon", 0.5], ["1400_afternoon", 0.58], ["1630_golden", 0.66], ["1830_sunset", 0.73],
	["2000_dusk", 0.80], ["2200_night", 0.90], ["0000_midnight", 0.0],
]

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"zone1" if "meadow" in args else &"larkmoor"
	SkyCycle.debug_season = 0
	for a: String in args:
		if a.begins_with("season="):
			SkyCycle.debug_season = int(a.substr(7))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	for ph: Array in PHASES:
		SkyCycle.debug_phase = float(ph[1])
		await _wait(45)
		get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/golden_%s.png" % String(ph[0])))
		print("shot ", ph[0])
	get_tree().quit(0)
