class_name ZoneAssets
extends RefCounted
## The prop textures of a zone scene, loaded on worker threads during the transition wipe and kept in one cache, so a
## swap under the wipe does not call load() once per prop on the main thread. The Ember Quarry used to do that for its
## 183 sprites, their 183 normal maps and 25 lava tiles inside the swap frame (about 260 ms of stall). A texture shared by
## two props loads once. Static, so it needs no autoload: tests and tools can call it.

## Zone scene -> the placements manifest that lists its props. Zones not listed here load their props as they spawn.
const SCENE_MANIFESTS: Dictionary = {
	"res://world/quarry_scene.tscn": "res://assets/art/zone2/quarry/placements3d.json",
}

## Larkmoor's ground maps are read by its _ready (the sky's normal and height maps): 3040x1840 each, so their load
## on the main thread cost about 160 ms in the swap frame.
const SCENE_TEXTURES: Dictionary = {
	"res://world/larkmoor_scene.tscn": [
		"res://assets/art/zone1b/larkmoor/ground_n.png",
		"res://assets/art/zone1b/larkmoor/ground_h.png",
	],
}
## Zone scenes that build the Foxglove Rise farm (world/farm/farm_props.gd): its wheat clumps are generated on workers
## and its sprites prefetched, so the swap does not generate about 660 clumps or load 660 sheets on the swap frame.
const FARM_SCENES: Array[String] = ["res://world/larkmoor_scene.tscn"]
## The backdrop whose pixels LifeAir reads (water sparkles). Decoded from its lossless source PNG on a worker thread.
const SCENE_BACKDROPS: Dictionary = {
	"res://world/larkmoor_scene.tscn": "res://assets/art/zone1b/larkmoor/ground_fg.png",
}

static var _cache: Dictionary = {}     ## path -> Texture2D, held while its zone is loaded
static var _decodes: Dictionary = {}   ## source path -> Decode, a backdrop decoded on a worker thread
static var _pending: Dictionary = {}   ## path -> true, a threaded load that has been requested and not yet taken


## Asks the loader to start the textures of `scene_path` on worker threads. Safe to call early (the wipe's cover phase).
static func prefetch_scene(scene_path: String) -> void:
	var manifest: String = str(SCENE_MANIFESTS.get(scene_path, ""))
	if manifest != "":
		prefetch(paths_for_manifest(manifest))
	prefetch(PackedStringArray(SCENE_TEXTURES.get(scene_path, []) as Array))
	# The backdrop decode is queued before the farm's clumps, so the scene's _ready never waits behind them on a worker.
	var backdrop: String = str(SCENE_BACKDROPS.get(scene_path, ""))
	if backdrop != "" and not _decodes.has(backdrop):
		var d := Decode.new()
		d.task = WorkerThreadPool.add_task(_decode.bind(d, backdrop))
		_decodes[backdrop] = d
	if FARM_SCENES.has(scene_path):
		prefetch(FarmProps.prepare())


## A backdrop image decoded on a worker thread. `task` is its WorkerThreadPool task; `image` is set by the worker.
class Decode extends RefCounted:
	var task: int = -1
	var image: Image = null


static func _decode(d: Decode, path: String) -> void:
	d.image = Image.load_from_file(path)


## The pixels of a backdrop texture, as Texture2D.get_image() gives them. Uses the worker's decode when it was
## prefetched and matches the texture; otherwise decodes it here.
static func backdrop_image(tex: Texture2D) -> Image:
	var path: String = tex.resource_path
	if _decodes.has(path):
		var d: Decode = _decodes[path] as Decode
		_decodes.erase(path)
		WorkerThreadPool.wait_for_task_completion(d.task)
		if d.image != null and d.image.get_width() == tex.get_width() and d.image.get_height() == tex.get_height():
			return d.image
	return tex.get_image()


static func prefetch(paths: PackedStringArray) -> void:
	for p: String in paths:
		if _cache.has(p) or _pending.has(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_pending[p] = true


## The texture at `path`: the cached one, else the prefetched one (waits for its worker if it is still running), else a
## plain load. Every result is held until release().
static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if _pending.has(path):
		_pending.erase(path)
		tex = ResourceLoader.load_threaded_get(path) as Texture2D
	if tex == null:
		tex = load(path) as Texture2D
	if tex != null:
		_cache[path] = tex
	return tex


## True when `path` can be taken without waiting: cached, never requested, or its worker has finished (or failed, in which
## case texture() falls back to a plain load). Lets a sliced build poll the prefetch instead of blocking on it.
static func ready(path: String) -> bool:
	if _cache.has(path) or not _pending.has(path):
		return true
	var st: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
	return st != ResourceLoader.THREAD_LOAD_IN_PROGRESS


## Drops the textures of the zone that was left. Prefetches still in flight stay queued for the zone being entered.
static func release() -> void:
	_cache.clear()


## Every texture a manifest's props use: the sprite, its normal map (`<name>_n.png`) and the lava tile frames.
static func paths_for_manifest(manifest_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not data is Dictionary:
		return out
	var dir: String = manifest_path.get_base_dir() + "/"
	var seen: Dictionary = {}
	for s: Variant in (data as Dictionary).get("sprites", []) as Array:
		var file: String = str((s as Dictionary).get("file", ""))
		if file == "":
			continue
		for p: String in [dir + file, dir + file.get_basename() + "_n.png"]:
			if not seen.has(p):
				seen[p] = true
				out.append(p)
	for t: Variant in (data as Dictionary).get("lava", []) as Array:
		var lava_file: String = str((t as Dictionary).get("file", ""))
		if lava_file != "" and not seen.has(dir + lava_file):
			seen[dir + lava_file] = true
			out.append(dir + lava_file)
	return out
