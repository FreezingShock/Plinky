class_name MenuRouter
extends RefCounted
## One place that decides which menu is open. Every opener (bottom chips, hotkeys, the close X, Esc) goes through
## here, so menus can never end up open together or out of step, however fast they are clicked.
## Menus register three callables. Menus that share a `group` (the Stats and Attributes tabs of one window) never
## close each other; opening one just flips the window over.
## Pure RefCounted: no nodes, so tests can drive it with stubs.

var _menus: Dictionary = {}   # kind -> {"is_open": Callable, "open": Callable, "close": Callable, "group": StringName}
var _order: Array[StringName] = []
## While this returns true, open() does nothing (a zone reset confirm is up). Set by main.gd.
var blocked: Callable = Callable()


func register(kind: StringName, is_open: Callable, open: Callable, close: Callable, group: StringName = &"") -> void:
	if not _menus.has(kind):
		_order.append(kind)
	_menus[kind] = {"is_open": is_open, "open": open, "close": close, "group": group if group != &"" else kind}


func has(kind: StringName) -> bool:
	return _menus.has(kind)


func is_open(kind: StringName) -> bool:
	return _menus.has(kind) and bool((_menus[kind]["is_open"] as Callable).call())


## Click or hotkey: close it if it is open, otherwise open it and close everything else.
func toggle(kind: StringName) -> void:
	if not _menus.has(kind):
		return
	if is_open(kind):
		close(kind)
	else:
		open(kind)


func open(kind: StringName) -> void:
	if not _menus.has(kind):
		return
	if blocked.is_valid() and bool(blocked.call()):
		return
	close_others(kind)
	if not is_open(kind):
		(_menus[kind]["open"] as Callable).call()


func close(kind: StringName) -> void:
	if is_open(kind):
		(_menus[kind]["close"] as Callable).call()


func close_others(kind: StringName) -> void:
	if not _menus.has(kind):
		return
	var g: StringName = _menus[kind]["group"]
	for k: StringName in _order:
		if k != kind and _menus[k]["group"] != g:
			close(k)


## Esc or pad B. Returns true if anything was open.
func close_all() -> bool:
	var any: bool = false
	for k: StringName in _order:
		if is_open(k):
			any = true
			close(k)
	return any


func open_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in _order:
		if is_open(k):
			out.append(k)
	return out
