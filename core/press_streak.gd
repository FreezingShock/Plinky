class_name PressStreak
extends RefCounted
## The press chain behind the popup tiers. Every press that lands within `popup_streak_gap` seconds of the last one
## extends the chain; a longer pause breaks it. The score is the chain length, boosted by the Momentum stage, and each
## threshold in GameConfig.popup_tier_thresholds is one tier (Plain, Gold, Ice, Rainbow, Chroma, Galaxy).
## Pure data: no nodes, no clock of its own (the caller passes seconds), so tests drive it directly.
## Presentation only. Tiers never change income.

var count: int = 0
var tier: int = 0
var score: float = 0.0
var rose: bool = false      ## the last feed() crossed into a higher tier
var _last: float = -1.0e9


## Tier for a score: how many thresholds it has reached.
static func tier_for(value: float, thresholds: PackedFloat32Array) -> int:
	var t: int = 0
	for th: float in thresholds:
		if value >= th:
			t += 1
	return t


## Score for a chain length at a Momentum stage (0 = Idle).
static func score_for(chain: int, momentum_stage: int, weight: float) -> float:
	return float(chain) * (1.0 + float(maxi(momentum_stage, 0)) * weight)


## One press. `now` is seconds on any steady clock. Returns the tier after this press; `rose` says if it went up.
func feed(now: float, momentum_stage: int, cfg: GameConfig) -> int:
	if now - _last > cfg.popup_streak_gap:
		count = 0
		tier = 0
	_last = now
	count += 1
	score = score_for(count, momentum_stage, cfg.popup_momentum_weight)
	var t: int = tier_for(score, cfg.popup_tier_thresholds)
	rose = t > tier
	tier = maxi(tier, t)   # a Momentum drop mid-chain never lowers the tier already earned
	return tier


## Call every frame. Returns the tier that was lost if the chain just ran out, else -1.
func expire(now: float, cfg: GameConfig) -> int:
	if count > 0 and now - _last > cfg.popup_streak_gap:
		var lost: int = tier
		reset()
		return lost
	return -1


## Seconds of chain left before it breaks (0 when there is none).
func time_left(now: float, cfg: GameConfig) -> float:
	return maxf(0.0, cfg.popup_streak_gap - (now - _last)) if count > 0 else 0.0


func reset() -> void:
	count = 0
	tier = 0
	score = 0.0
	rose = false
	_last = -1.0e9
