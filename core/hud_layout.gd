class_name HudLayout
extends RefCounted
## Which stat rows the HUD strip shows, and in what order, per zone. Pure data and rules, no nodes: the strip
## (ui/hud.gd) draws whatever this says, and the Sim saves it with the game.
##
## A zone with no entry is on the Default layout: the zone's own stats in ladder order. The first edit copies that
## into an explicit row list, and from then on the list is the layout. Stats the zone gains later (a future
## ladder, a patch) are appended the first time they show up, so an old layout never hides new content.
## A row can also be a stat from another zone (a pinned extra); `cap_for()` caps the list.

const MAX_ROWS: int = 12   ## the most rows a strip holds, unless the zone's own Default is longer (see cap_for)
const HARD_MAX: int = 16   ## a loaded layout is cut to this, so a damaged save cannot build a huge strip

var _zones: Dictionary = {}   # zone id (String) -> {"rows": Array of String, "seen": Array of String}


## True when the zone has been edited (anything but the Default layout).
func is_custom(zone: StringName) -> bool:
	return _zones.has(String(zone))


## The rows to show in `zone`, top to bottom. `defaults` is the zone's own stat list in ladder order.
func rows(zone: StringName, defaults: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	var key: String = String(zone)
	if not _zones.has(key):
		out.assign(defaults)
		return out
	var e: Dictionary = _zones[key]
	var saved: Array = e["rows"]
	var seen: Array = e["seen"]
	for d: StringName in defaults:
		if not seen.has(String(d)):
			seen.append(String(d))
			saved.append(String(d))
	for v: Variant in saved:
		out.append(StringName(str(v)))
	return out


## Stats that could be added: the zone's own hidden stats first (ladder order), then `pool` (other stats the player has
## met), skipping anything already shown.
func suggestions(zone: StringName, defaults: Array[StringName], pool: Array[StringName]) -> Array[StringName]:
	var shown: Array[StringName] = rows(zone, defaults)
	var out: Array[StringName] = []
	for sid: StringName in defaults + pool:
		if not shown.has(sid) and not out.has(sid):
			out.append(sid)
	return out


## The row limit in a zone: MAX_ROWS, but never below the zone's own Default (the strip must always fit its Default).
static func cap_for(defaults: Array[StringName]) -> int:
	return maxi(MAX_ROWS, defaults.size())


func is_full(zone: StringName, defaults: Array[StringName]) -> bool:
	return rows(zone, defaults).size() >= cap_for(defaults)


## Take a row off the strip. The last row cannot be removed (the strip is never empty). True if it changed.
func hide(zone: StringName, sid: StringName, defaults: Array[StringName]) -> bool:
	var e: Dictionary = _edit(zone, defaults)
	var r: Array = e["rows"]
	if r.size() <= 1 or not r.has(String(sid)):
		return false
	r.erase(String(sid))
	return true


## Put a stat on the strip, at the bottom. False when it is already there, unknown, or the strip is full.
func add(zone: StringName, sid: StringName, defaults: Array[StringName]) -> bool:
	var e: Dictionary = _edit(zone, defaults)
	var r: Array = e["rows"]
	if r.has(String(sid)) or r.size() >= cap_for(defaults) or String(sid) == "":
		return false
	r.append(String(sid))
	return true


## Move a row one place: dir -1 is up, +1 is down. False at either end.
func move(zone: StringName, sid: StringName, dir: int, defaults: Array[StringName]) -> bool:
	var e: Dictionary = _edit(zone, defaults)
	var r: Array = e["rows"]
	var i: int = r.find(String(sid))
	var j: int = i + (1 if dir > 0 else -1)
	if i < 0 or j < 0 or j >= r.size():
		return false
	var tmp: Variant = r[i]
	r[i] = r[j]
	r[j] = tmp
	return true


## Back to the Default layout for one zone.
func reset(zone: StringName) -> void:
	_zones.erase(String(zone))


func reset_all() -> void:
	_zones.clear()


func clear() -> void:
	_zones.clear()


func _edit(zone: StringName, defaults: Array[StringName]) -> Dictionary:
	var key: String = String(zone)
	if not _zones.has(key):
		var r: Array = []
		for d: StringName in defaults:
			r.append(String(d))
		_zones[key] = {"rows": r, "seen": r.duplicate()}
	else:
		rows(zone, defaults)   # picks up any stat the zone gained since the last edit
	return _zones[key] as Dictionary


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _zones:
		var e: Dictionary = _zones[key]
		out[key] = {"rows": (e["rows"] as Array).duplicate(), "seen": (e["seen"] as Array).duplicate()}
	return out


## Load from to_dict() output. `valid` lists the stat ids that exist; anything else is dropped. Never throws:
## a missing or malformed value (every save from before this existed) leaves the Default layout.
func from_dict(d: Variant, valid: Array = []) -> void:
	_zones.clear()
	if not (d is Dictionary):
		return
	for k: Variant in (d as Dictionary):
		var e: Variant = (d as Dictionary)[k]
		if not (e is Dictionary) or not ((e as Dictionary).get("rows") is Array):
			continue
		var rows_out: Array = []
		for v: Variant in ((e as Dictionary)["rows"] as Array):
			var s: String = str(v)
			if s != "" and not rows_out.has(s) and (valid.is_empty() or valid.has(StringName(s))):
				rows_out.append(s)
		if rows_out.is_empty():
			continue
		while rows_out.size() > HARD_MAX:
			rows_out.pop_back()
		var seen_out: Array = rows_out.duplicate()
		var sv: Variant = (e as Dictionary).get("seen")
		if sv is Array:
			for v: Variant in (sv as Array):
				if not seen_out.has(str(v)):
					seen_out.append(str(v))
		_zones[str(k)] = {"rows": rows_out, "seen": seen_out}
