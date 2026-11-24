extends SceneTree
## Loading probe: starts the boot screen as the game does, waits for the title, presses Play (which goes through the loading
## screen into the game) and prints every frame over --slow=<ms> with its phase and PerfStats laps. Summary: time to the
## title, time from Play to the game being on screen, and the worst frames of each phase.
##
## godot --headless --path . --script tools/loading_probe.gd -- --slow=40

var slow_ms: float = 40.0
var _phase: String = "boot"
var _frame: int = 0


func _init() -> void:
	await process_frame
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--slow="):
			slow_ms = float(a.trim_prefix("--slow="))
	PerfStats.tracing = true
	var boot: Node = (load("res://boot/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	current_scene = boot
	var t_start: int = Time.get_ticks_usec()
	var t_title: int = 0
	var t_play: int = 0
	var t_game: int = 0
	var worst: Dictionary = {}
	var last: int = Time.get_ticks_usec()
	var title: Node = null
	var settled: int = 0
	while _frame < 6000:
		var n0: int = PerfStats.trace.size()
		await process_frame
		_frame += 1
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		worst[_phase] = maxf(float(worst.get(_phase, 0.0)), ms)
		if ms >= slow_ms:
			var laps: Array[String] = []
			for j: int in range(n0, PerfStats.trace.size()):
				laps.append(PerfStats.trace[j])
			print("SLOW [%s] frame %d: %.1f ms laps=%s" % [_phase, _frame, ms, str(laps)])
		if _phase == "boot":
			title = _find_title()
			if title != null:
				t_title = Time.get_ticks_usec()
				print("TIME to title: %.0f ms" % [float(t_title - t_start) / 1000.0])
				_phase = "title"
				settled = 0
		elif _phase == "title":
			settled += 1
			if settled == 6:
				t_play = Time.get_ticks_usec()
				print("nodes before play: %d" % root.find_children("*", "", true, false).size())
				title.call("_on_play")
				_phase = "loading"
		elif _phase == "loading":
			if _game_on_screen():
				settled = 0
				_phase = "reveal"
		elif _phase == "reveal":
			if not SceneSwap.is_busy():
				t_game = Time.get_ticks_usec()
				break
	if t_game > 0:
		print("TIME play to game (incl. loading screen and reveal): %.0f ms" % [float(t_game - t_play) / 1000.0])
	for p: String in worst.keys():
		print("worst frame in %s: %.1f ms" % [p, float(worst[p])])
	quit(0 if t_game > 0 else 1)


func _find_title() -> Node:
	for n: Node in root.find_children("*", "", true, false):
		if n is TitleScreen:
			return n
	return null


## The game is on screen once its Main node exists and the loading screen (BootScreen) has gone.
func _game_on_screen() -> bool:
	if root.find_child("Main", true, false) == null:
		return false
	for n: Node in root.find_children("*", "", true, false):
		if n is BootScreen:
			return false
	return true
