extends Node
## Autoload. Autosave, load on start, offline progress.
## Saves: every autosave_seconds, on zone change, on rebirth, on quit.

const SAVE_PATH: String = SaveSlots.BASE_PATH

## Active save slot, 1 to SLOT_COUNT. Slot 1 is the original user://save.json, so existing saves keep working.
var slot: int = 1
## True on the title screen: nothing autosaves there, so browsing or deleting slots never writes a new save.
var paused: bool = false

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
	bus.reset_done.connect(func(_id: StringName, _n: int) -> void: save_game())
	slot = SaveSlots.read_active_slot()
	load_game()


func _process(delta: float) -> void:
	_since_save += delta
	if paused:
		return
	var sim: Sim = get_node("/root/GameState").sim
	var every: float = autosave_override if autosave_override > 0.0 else sim.config.autosave_seconds
	if _since_save >= every:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game() -> bool:
	_since_save = 0.0
	if not enabled or paused:
		return false
	var sim: Sim = get_node("/root/GameState").sim
	var ok: bool = SaveCodec.write_file(SaveSlots.path_for(slot), SaveCodec.encode(sim, Time.get_unix_time_from_system()))
	if ok:
		get_node("/root/EventBus").game_saved.emit()
	else:
		push_warning("Save: could not write " + SaveSlots.path_for(slot))
		get_node("/root/EventBus").save_failed.emit()
	return ok


func load_game() -> bool:
	var sim: Sim = get_node("/root/GameState").sim
	var data: Dictionary = SaveCodec.read_with_fallback(SaveSlots.path_for(slot))
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


## Make `n` the active slot and load it (a new game when it is empty). Remembers the choice for the next launch.
func select_slot(n: int) -> void:
	slot = clampi(n, 1, SaveSlots.SLOT_COUNT)
	SaveSlots.write_active_slot(slot)
	var sim: Sim = get_node("/root/GameState").sim
	sim.new_game()
	_offline_report = {}
	load_game()


## Start a new game in slot `n`, replacing whatever it held. Written when the game starts (paused is off by then).
func new_game_in_slot(n: int) -> void:
	delete_slot(n)
	select_slot(n)


## Remove a slot's files. A deleted active slot becomes a new game in memory (nothing is written while paused).
func delete_slot(n: int) -> void:
	SaveSlots.delete_files(n)
	if n == slot:
		var sim: Sim = get_node("/root/GameState").sim
		sim.new_game()
		_offline_report = {}
