class_name HudGainTally
extends RefCounted
## Pure logic for the HUD gain label beside each statistic: it adds up every gain of a statistic from pad presses and
## bonuses, and tells the view how far that label is in or out. A run starts at a stat's first gain, stays HOLD seconds
## after its last gain, then animates out over OUT seconds. A new gain during the run keeps adding to the same number.

const HOLD: float = 3.0      ## seconds the label stays after the stat's last gain
const OUT: float = 0.4       ## seconds the label takes to animate out once the hold has passed

var _total: Dictionary = {}  ## stat id -> BigNum: the sum of the run's gains
var _start: Dictionary = {}  ## stat id -> clock time of the run's first gain (the label animates in from here)
var _last: Dictionary = {}   ## stat id -> clock time of the run's latest gain
var _crit: Dictionary = {}   ## stat id -> true once any gain in the run was a crit (shows as "!")


## Adds one gain of `stat` at clock time `now`. A gain after a finished run starts a new run from zero.
func add(stat: StringName, gain: BigNum, now: float, crit: bool) -> void:
	if gain.is_zero():
		return
	if not _last.has(stat) or now - float(_last[stat]) >= HOLD + OUT:
		_total[stat] = BigNum.zero()
		_start[stat] = now
		_crit[stat] = false
	_total[stat] = (_total[stat] as BigNum).add(gain)
	_last[stat] = now
	_crit[stat] = bool(_crit.get(stat, false)) or crit


## 0 when the stat has no run, 1 while it is held, and falls to 0 across OUT once the hold has passed.
func alpha(stat: StringName, now: float) -> float:
	if not _last.has(stat):
		return 0.0
	var quiet: float = now - float(_last[stat])
	if quiet < HOLD:
		return 1.0
	return clampf(1.0 - (quiet - HOLD) / OUT, 0.0, 1.0)


## Seconds since the run began, so the view can animate the label in.
func age(stat: StringName, now: float) -> float:
	return maxf(now - float(_start.get(stat, now)), 0.0)


func total_text(stat: StringName) -> String:
	if not _total.has(stat):
		return ""
	return "+" + (_total[stat] as BigNum).format() + ("!" if bool(_crit.get(stat, false)) else "")


## Forgets every run that has animated out, so a stopped stat reads as nothing and the dictionaries stay small.
func prune(now: float) -> void:
	for stat: StringName in _last.keys():
		if _gone(stat, now):
			_last.erase(stat)
			_total.erase(stat)
			_start.erase(stat)
			_crit.erase(stat)


func _gone(stat: StringName, now: float) -> bool:
	return now - float(_last.get(stat, now)) >= HOLD + OUT
