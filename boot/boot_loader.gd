class_name BootLoader
extends RefCounted
## Threaded loader for the boot screen. Each task is one resource path with a weight.
## Overall progress is the weighted sum of what ResourceLoader reports for each task, so the bar
## moves while the files stream in. Nothing is faked: a task only counts once the thread says so.
## Loaded resources stay in ResourceLoader's cache, so the game's own load() calls return instantly.

class LoadTask:
	var path: String = ""
	var label: String = ""
	var weight: float = 1.0
	var progress: float = 0.0
	var done: bool = false
	var resource: Resource = null
	## Threaded retries already made for this path (see MAX_RETRIES).
	var retries: int = 0


const MAX_RETRIES: int = 2

var _tasks: Array[LoadTask] = []
var _started: bool = false
var _failed: PackedStringArray = PackedStringArray()


func add(path: String, weight: float, label: String) -> void:
	var task := LoadTask.new()
	task.path = path
	task.weight = weight
	task.label = label
	_tasks.append(task)


func start() -> void:
	if _started:
		return
	_started = true
	for task: LoadTask in _tasks:
		var err: Error = ResourceLoader.load_threaded_request(task.path)
		if err != OK:
			_mark_failed(task)


## Call once per frame. Returns overall progress in 0..1 (1.0 when there is nothing to load).
func poll() -> float:
	var total: float = 0.0
	var weight_sum: float = 0.0
	for task: LoadTask in _tasks:
		weight_sum += task.weight
		if not task.done:
			var progress: Array = []
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(task.path, progress)
			if progress.size() > 0:
				task.progress = clampf(float(progress[0]), 0.0, 1.0)
			match status:
				ResourceLoader.THREAD_LOAD_LOADED:
					task.resource = ResourceLoader.load_threaded_get(task.path)
					task.progress = 1.0
					task.done = true
				ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					_retry_or_fail(task)
		total += task.weight * task.progress
	if weight_sum <= 0.0:
		return 1.0
	return total / weight_sum


func is_finished() -> bool:
	for task: LoadTask in _tasks:
		if not task.done:
			return false
	return true


func has_failures() -> bool:
	return _failed.size() > 0


func failed_paths() -> PackedStringArray:
	return _failed


## Label of the first task still loading, or "Ready" once everything has finished.
func current_label() -> String:
	for task: LoadTask in _tasks:
		if not task.done:
			return task.label
	return "Ready"


func resource_for(path: String) -> Resource:
	for task: LoadTask in _tasks:
		if task.path == path:
			return task.resource
	return null


## A worker load can fail on a race with another worker's compile of a shared script (PC boot logged a Parse Error for
## main.tscn's script, and the scene loaded later on the main thread). Re-request the path a bounded number of times, so
## a transient failure costs one more worker load, not a failed boot. A missing or corrupt file still fails, after the retries.
func _retry_or_fail(task: LoadTask) -> void:
	if task.retries >= MAX_RETRIES:
		_mark_failed(task)
		return
	task.retries += 1
	push_warning("Boot: retrying %s (attempt %d of %d)" % [task.path, task.retries + 1, MAX_RETRIES + 1])
	ResourceLoader.load_threaded_get(task.path)   # clears the failed entry so the request starts again
	if ResourceLoader.load_threaded_request(task.path) != OK:
		_mark_failed(task)


func _mark_failed(task: LoadTask) -> void:
	task.done = true
	task.progress = 1.0
	if not _failed.has(task.path):
		_failed.append(task.path)
		push_error("Boot: could not load %s" % task.path)
