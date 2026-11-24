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
		SkyCycle.debug_phase = float(ph[1])
		# Pin the HUD clock to the same phase so the label matches the sky and does not drift between runs.
		var cal: GameCalendar = Calendar.core()
		if cal != null:
			cal.set_day_fraction(float(ph[1]))
		await _wait(45)
		get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/golden_%s.png" % String(ph[0])))
		print("shot ", ph[0], " clock ", Calendar.now().get("clock_text", "?"))
	get_tree().quit(0)


func any_match(name: String, keys: Array) -> bool:
	for k: String in keys:
		if name.contains(k):
			return true
	return false
