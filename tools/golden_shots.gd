extends Node
## Time-of-day capture: starts the real game (Larkmoor by default, `meadow` for zone 1), pins the season to spring
## and the sky to each phase in PHASES with SkyCycle.debug_phase, and saves PNGs to shots/golden_<name>.png.
## Run: godot --path . tools/golden_shots.tscn [-- meadow] [-- season=N]   (shots/ is gitignored)
## The label is the clock time on the calendar (3 min day: sunrise 04:48, noon 12:00, sunset 19:12). The phases map to
## clock times through SkyModel.clock_of_phase (daylight 0.6): 0.69 is 17:28, where the sun is still 0.37 up and the
## golden look is at full strength (QA's golden); 0.73 is 18:37, the sun still a little above the horizon (QA's sunset).
const PHASES: Array = [
	["0448_sunrise", 0.25], ["0614_early", 0.30], ["0808_morning", 0.366], ["0959_late_morning", 0.43],
	["1200_noon", 0.5], ["1418_afternoon", 0.58], ["1728_golden", 0.69], ["1837_sunset", 0.73],
	["2010_dusk", 0.80], ["2205_night", 0.90], ["0000_midnight", 0.0],
]

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sim: Sim = GameState.sim
	# gate=shut captures the gate closed (rec 9); default is open. Tips are off unless tips=on, so panels do not cover the frame.
	sim.gates_open[&"zone1"] = not ("gate=shut" in args)
	sim.zone_id = &"zone1" if "meadow" in args else &"larkmoor"
	GameState.onboarding.tips_enabled = "tips=on" in args
	SkyCycle.debug_season = 0
	var only: Array = []
	for a: String in args:
		if a.begins_with("season="):
			SkyCycle.debug_season = int(a.substr(7))
		if a.begins_with("phases="):
			only = a.substr(7).split(",")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	for ph: Array in PHASES:
		if not only.is_empty() and not any_match(String(ph[0]), only):
			continue
		# The pin is a sun phase. SkyCycle moves the calendar clock to match it, so the HUD label agrees with the sky.
		SkyCycle.debug_phase = float(ph[1])
		await _wait(45)
		get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/golden_%s.png" % String(ph[0])))
		print("shot ", ph[0], " clock ", Calendar.now().get("clock_text", "?"))
	get_tree().quit(0)


func any_match(name: String, keys: Array) -> bool:
	for k: String in keys:
		if name.contains(k):
			return true
	return false
