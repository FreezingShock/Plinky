class_name Goals
extends RefCounted
## Pure logic for mid-game goals: a chain of milestones between resets, each with a small permanent press bonus.
## No nodes, no autoloads. Sim owns one, feeds it counters (Sim.check_goals) and saves it with to_dict().
## A reached goal is kept in `log` for good, so resets never take it back. The bonus is `mult()`, which Sim.press_gain
## multiplies in. Every value here is a float multiplier; stat values stay BigNum.

var defs: Dictionary = {}          ## StringName -> GoalDef
var sorted: Array[GoalDef] = []    ## chain order
var log: Array[StringName] = []    ## reached goal ids, oldest first
var _have: Dictionary = {}         ## id -> true, mirrors log


func _init(p_defs: Array = []) -> void:
	for d: Variant in p_defs:
		var def: GoalDef = d as GoalDef
		if def != null:
			defs[def.id] = def
			sorted.append(def)
	sorted.sort_custom(func(a: GoalDef, b: GoalDef) -> bool: return a.order < b.order)


func clear() -> void:
	log.clear()
	_have.clear()


func is_reached(id: StringName) -> bool:
	return _have.has(id)


func reached_count() -> int:
	return log.size()


func total() -> int:
	return sorted.size()


static func value_of(d: GoalDef, counters: Dictionary) -> float:
	return float(counters.get(d.counter, 0.0))


## 0 to 1 towards the target; 1 once reached.
func progress(d: GoalDef, counters: Dictionary) -> float:
	if is_reached(d.id):
		return 1.0
	return clampf(value_of(d, counters) / maxf(d.target, 0.000001), 0.0, 1.0)


## Marks every goal whose counter has reached its target. Returns the ids reached just now, in chain order.
func check(counters: Dictionary) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for d: GoalDef in sorted:
		if not _have.has(d.id) and value_of(d, counters) >= d.target:
			_have[d.id] = true
			log.append(d.id)
			fresh.append(d.id)
	return fresh


## The first goal in the chain not yet reached, or null when the chain is done.
func next_goal() -> GoalDef:
	for d: GoalDef in sorted:
		if not _have.has(d.id):
			return d
	return null


## Press multiplier from every reached goal: 1 plus the sum of their rewards.
func mult() -> float:
	var m: float = 1.0
	for id: StringName in log:
		var d: GoalDef = defs.get(id) as GoalDef
		if d != null:
			m += d.reward
	return m


func to_dict() -> Dictionary:
	return {"log": log.map(func(i: StringName) -> String: return String(i))}


## Loads a dict from to_dict(). Unknown ids are dropped, repeats ignored. Never throws.
func from_dict(d: Variant) -> void:
	clear()
	if not (d is Dictionary):
		return
	var l: Variant = (d as Dictionary).get("log", [])
	if l is Array:
		for k: Variant in (l as Array):
			var id: StringName = StringName(str(k))
			if defs.has(id) and not _have.has(id):
				_have[id] = true
				log.append(id)
