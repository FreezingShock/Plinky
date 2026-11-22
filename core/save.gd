extends Node
## Autoload. Autosave, load on start, offline progress.
## Saves: every autosave_seconds, on zone change, on rebirth, on quit.

const SAVE_PATH: String = "user://save.json"

var _since_save: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus: Node = get_node("/root/EventBus")
	bus.zone_entered.connect(func(_z: StringName) -> void: save_game())
	bus.rebirth_done.connect(func(_p: BigNum) -> void: save_game())
	load_game()


func _process(delta: float) -> void:
	_since_save += delta
	var sim: Sim = get_node("/root/GameState").sim
	if _since_save >= sim.config.autosave_seconds:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> bool:
	_since_save = 0.0
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
	sim.apply_offline(elapsed)
	get_node("/root/EventBus").game_loaded.emit()
	return true
