extends Node
## Autoload. Autosave, load on start, offline progress.
## Saves: every autosave_seconds, on zone change, on rebirth, on quit.

const SAVE_PATH: String = "user://save.json"

var _since_save: float = 0.0
## 0 = use the content config's autosave interval. Set from the settings menu (Gameplay > Autosave).
var autosave_override: float = 0.0
## False while tools/bench.gd runs, so a benchmark never overwrites the player's save.
var enabled: bool = true
## Offline report from the load in _ready(). That runs before any UI exists, so the signal is missed;
## the HUD reads this once when it is built (see take_offline_report()).
var _offline_report: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus: Node = get_node("/root/EventBus")
	bus.zone_entered.connect(func(_z: StringName) -> void: save_game())
	bus.rebirth_done.connect(func(_p: BigNum) -> void: save_game())
	load_game()


func _process(delta: float) -> void:
	_since_save += delta
	var sim: Sim = get_node("/root/GameState").sim
	var every: float = autosave_override if autosave_override > 0.0 else sim.config.autosave_seconds
	if _since_save >= every:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game() -> bool:
	_since_save = 0.0
	if not enabled:
		return false
	var sim: Sim = get_node("/root/GameState").sim
	var ok: bool = SaveCodec.write_file(SAVE_PATH, SaveCodec.encode(sim, Time.get_unix_time_from_system()))
	if ok:
		get_node("/root/EventBus").game_saved.emit()
	else:
		push_warning("Save: could not write " + SAVE_PATH)
	return ok


func load_game() -> bool:
	var sim: Sim = get_node("/root/GameState").sim
	var data: Dictionary = SaveCodec.read_with_fallback(SAVE_PATH)
	if data.is_empty():
		return false
	sim.from_dict(data["game"])
	var elapsed: float = Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0))
	var bus: Node = get_node("/root/EventBus")
	var capture := func(secs: float, gains: Dictionary) -> void: _offline_report = {"seconds": secs, "gains": gains}
	sim.offline_gained.connect(capture)
	sim.apply_offline(elapsed)
	sim.offline_gained.disconnect(capture)
	bus.game_loaded.emit()
	return true


## The offline report from startup, once; {} if there is none or it was already taken.
func take_offline_report() -> Dictionary:
	var r: Dictionary = _offline_report
	_offline_report = {}
	return r


## The save as one line of text, for the clipboard.
func export_string() -> String:
	var sim: Sim = get_node("/root/GameState").sim
	return SaveCodec.encode(sim, Time.get_unix_time_from_system())


## Replace the current game with pasted save text. False (and nothing changed) if the text is not a usable save.
func import_string(text: String) -> bool:
	var data: Dictionary = SaveCodec.decode(text.strip_edges())
	if data.is_empty():
		return false
	var sim: Sim = get_node("/root/GameState").sim
	sim.from_dict(data["game"])
	save_game()
	return true


## Wipe the game back to a new one and write it.
func reset_game() -> void:
	var sim: Sim = get_node("/root/GameState").sim
	sim.new_game()
	save_game()
