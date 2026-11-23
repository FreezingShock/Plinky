class_name BannerQueue
extends RefCounted
## Pure logic behind the popup banners (ui/banner.gd): spec normalising, the queue with dedupe, and the timeline that
## makes text type in from the centre, hold, and collapse back to it. No nodes, no clock: callers pass time in.

const DEFAULT_DURATION: float = 2.6
const MIN_DURATION: float = 0.5
const MAX_DURATION: float = 10.0
const MAX_PENDING: int = 4
## A banner with the same key as one shown this recently is dropped (walking back and forth over a district edge).
const REPEAT_WINDOW: float = 6.0
const CHARS_PER_SECOND: float = 48.0
const STAGGER: float = 0.12

var current: Dictionary = {}
var pending: Array[Dictionary] = []
var _last_key: String = ""
var _last_time: float = -1000.0


## Fills defaults and clamps. Spec keys: title, lines, icon (area icon id), color (Color or null), duration, key,
## interrupt (drop everything and show now).
static func normalize(spec: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	for l: Variant in spec.get("lines", []) as Array:
		var s: String = str(l)
		if s != "":
			lines.append(s)
	var title: String = str(spec.get("title", ""))
	var key: String = str(spec.get("key", ""))
	if key == "":
		key = title + "|" + "|".join(lines)
	return {
		"title": title,
		"lines": lines,
		"icon": str(spec.get("icon", "")),
		"color": spec.get("color", null),
		"duration": clampf(float(spec.get("duration", DEFAULT_DURATION)), MIN_DURATION, MAX_DURATION),
		"key": key,
		"interrupt": bool(spec.get("interrupt", false)),
	}


## Queues a banner. Returns false when it was dropped: empty, a duplicate of the current or a waiting one, or a repeat
## of the banner that just finished. `interrupt` clears the queue first and tells the caller to end the current banner
## (see `take_interrupt`).
func push(spec: Dictionary, now: float) -> bool:
	var s: Dictionary = normalize(spec)
	if s["title"] == "" and (s["lines"] as Array).is_empty():
		return false
	var key: String = s["key"]
	if s["interrupt"]:
		pending.clear()
		pending.append(s)
		return true
	if not current.is_empty() and current["key"] == key:
		return false
	if key == _last_key and now - _last_time < REPEAT_WINDOW:
		return false
	for p: Dictionary in pending:
		if p["key"] == key:
			return false
	if pending.size() >= MAX_PENDING:
		pending.remove_at(0)
	pending.append(s)
	return true


## True when the head of the queue wants the current banner gone now.
func wants_interrupt() -> bool:
	return not pending.is_empty() and bool(pending[0]["interrupt"]) and not current.is_empty()


## Moves the next waiting banner to `current` and returns it, or an empty dictionary.
func next() -> Dictionary:
	if pending.is_empty():
		current = {}
		return current
	current = pending.pop_front()
	return current


## Marks the current banner finished at time `now` (so a repeat inside REPEAT_WINDOW is dropped).
func finish(now: float) -> void:
	if not current.is_empty():
		_last_key = current["key"]
		_last_time = now
	current = {}


func clear() -> void:
	pending.clear()
	current = {}


func is_idle() -> bool:
	return current.is_empty() and pending.is_empty()


# ---- timeline

## {in, hold, out, stagger} in seconds for a banner whose longest line has `max_chars` characters. `snap` (reduced
## motion) gives no typing and no collapse, only the hold.
static func timeline(max_chars: int, duration: float, snap: bool) -> Dictionary:
	if snap:
		return {"in": 0.0, "hold": duration, "out": 0.0, "stagger": 0.0}
	var t_in: float = clampf(float(max_chars) / CHARS_PER_SECOND, 0.25, 0.9)
	return {"in": t_in, "hold": duration, "out": t_in * 0.6, "stagger": STAGGER}


static func total_time(line_count: int, tl: Dictionary) -> float:
	return tl["stagger"] * maxf(line_count - 1, 0) + tl["in"] + tl["hold"] + tl["out"]


## When the hold ends and the collapse begins.
static func out_start(line_count: int, tl: Dictionary) -> float:
	return tl["stagger"] * maxf(line_count - 1, 0) + tl["in"] + tl["hold"]


## How much of line `index` is typed at time `t`, 0 to 1. Lines start one stagger after each other and collapse together.
static func line_progress(t: float, index: int, line_count: int, tl: Dictionary) -> float:
	var in_end: float = tl["stagger"] * maxf(line_count - 1, 0) + tl["in"]
	if t < in_end:
		return clampf((t - tl["stagger"] * index) / maxf(tl["in"], 0.0001), 0.0, 1.0)
	var start: float = in_end + tl["hold"]
	if t < start:
		return 1.0
	return 1.0 - clampf((t - start) / maxf(tl["out"], 0.0001), 0.0, 1.0)


# ---- centre-out typing

## How many of `n` characters show at progress `p`.
static func visible_count(n: int, p: float) -> int:
	return clampi(roundi(float(n) * clampf(p, 0.0, 1.0)), 0, n)


## Index of the first visible character: the visible run is centred in the text.
static func window_start(n: int, k: int) -> int:
	return (n - k) >> 1


## The centred slice of `text` that shows at progress `p`.
static func slice(text: String, p: float) -> String:
	var k: int = visible_count(text.length(), p)
	return text.substr(window_start(text.length(), k), k)
