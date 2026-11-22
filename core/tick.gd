class_name Tick
extends RefCounted
## Fixed-step accumulator. Frame time in, whole simulation ticks out.

var _acc: float = 0.0


## Returns how many fixed ticks to run. A backlog beyond max_ticks is dropped (offline gain covers long gaps).
func advance(delta: float, rate: int, max_ticks: int) -> int:
	_acc += delta
	var step: float = 1.0 / float(maxi(rate, 1))
	var n: int = int(_acc / step)
	if n > max_ticks:
		n = max_ticks
		_acc = 0.0
	else:
		_acc -= float(n) * step
	return n
