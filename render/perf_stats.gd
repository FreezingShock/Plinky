class_name PerfStats
extends RefCounted
## Rolling frame-time samples and the engine's own counters. Used by the F3 overlay (ui/perf_overlay.gd) and
## the benchmark (tools/bench.gd). No nodes, so it runs in headless tests.
## Budget: 60 fps on integrated graphics at 1080p, which is 16.67 ms a frame (docs/perf.md).

const BUDGET_MS: float = 1000.0 / 60.0

var capacity: int
var _ms: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _count: int = 0


func _init(window: int = 240) -> void:
	capacity = maxi(window, 1)
	_ms.resize(capacity)


## Record one frame, in milliseconds.
func push(frame_ms: float) -> void:
	_ms[_next] = frame_ms
	_next = (_next + 1) % capacity
	_count = mini(_count + 1, capacity)


func count() -> int:
	return _count


func clear() -> void:
	_next = 0
	_count = 0


## avg, p50, p95, p99, max (ms), fps (from avg) and over_budget (share of frames above BUDGET_MS, 0..1).
func summary() -> Dictionary:
	if _count == 0:
		return {"frames": 0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "fps": 0.0, "over_budget": 0.0}
	var sorted: PackedFloat32Array = _ms.slice(0, _count) if _count < capacity else _ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over: int = 0
	for v: float in sorted:
		total += v
		if v > BUDGET_MS * 1.05:  # 5% slack so vsync jitter is not counted as a miss
			over += 1
	var avg: float = total / float(_count)
	return {
		"frames": _count, "avg": avg, "p50": _at(sorted, 0.50), "p95": _at(sorted, 0.95),
		"p99": _at(sorted, 0.99), "max": sorted[_count - 1],
		"fps": 1000.0 / avg if avg > 0.0 else 0.0, "over_budget": float(over) / float(_count),
	}


static func _at(sorted: PackedFloat32Array, q: float) -> float:
	return sorted[clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)]


## Engine counters for this frame. Draw calls and objects are 0 under --headless (no renderer).
static func counters() -> Dictionary:
	return {
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"script_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"pipelines": pipeline_compiles(),
	}


## Total render pipelines the driver has compiled so far (canvas, mesh, surface, draw, specialization). A frame where
## this rises is a shader or pipeline compile stall; a hitch where it stays flat is something else.
static func pipeline_compiles() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
