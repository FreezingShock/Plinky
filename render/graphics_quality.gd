class_name GraphicsQuality
extends RefCounted
## Graphics quality: Low, Medium or High. One static setting that the cost-scaled systems read each time they
## step (world life density and step rate, particle counts, culling margin). It never touches palettes,
## dither, outlines or colours, so every level has the same look; the lower ones show fewer and slower
## ambient details. No autoload references, so it loads in headless tests.
##
## Settings thread: call GraphicsQuality.set_level(Level.LOW / MEDIUM / HIGH) and show GraphicsQuality.LABELS.
## Saved to user://graphics.cfg (its own file, so display settings saves never overwrite it).
## Launch override for benchmarks: `-- --quality=low` (see from_args and tools/bench.gd).

enum Level { LOW, MEDIUM, HIGH }

const LABELS: Array[String] = ["Low", "Medium", "High"]
const SECTION: String = "graphics"

## One entry per Level (LOW, MEDIUM, HIGH).
const LIFE_DENSITY: Array[float] = [0.4, 0.7, 1.0]          # share of fireflies and pollen drawn
const LIFE_STEP: Array[float] = [1.0 / 8.0, 1.0 / 10.0, 1.0 / 12.0]  # seconds per LifeAir redraw
const SWAY_STEP: Array[float] = [1.0 / 4.0, 1.0 / 5.0, 1.0 / 6.0]    # seconds per LifeGround redraw
const SWAY_STRIDE: Array[int] = [2, 1, 1]                   # draw every Nth grass tip
const PARTICLE_SCALE: Array[float] = [0.5, 0.75, 1.0]       # share of each burst's particles
const SHADOW_STEPS: Array[int] = [6, 9, 12]                 # ground relight height-march taps (ground_light.gdshader)
const SHADOW_STRIDE: Array[float] = [2.0, 1.34, 1.0]        # march stride multiplier, so fewer taps still reach as far
const AO_TAPS: Array[int] = [2, 4, 4]                       # ground occlusion taps
const SCREEN_GRADE: Array[bool] = [false, true, true]      # the full-frame light grade reads the screen texture (a back-buffer copy)
const RAIN_RINGS_MIST: Array[bool] = [false, true, true]   # splash rings and dawn ground mist (ground_light.gdshader taps); first to go on Low
const CULL_MARGIN: float = 24.0                             # texels beyond the view still drawn, so edges never pop

static var path: String = "user://graphics.cfg"
static var level: int = Level.HIGH
static var _loaded: bool = false


## Level for "low", "med", "medium", "high" (any case) or "0", "1", "2". -1 if it is none of those.
static func parse(text: String) -> int:
	match text.strip_edges().to_lower():
		"low", "0":
			return Level.LOW
		"med", "medium", "1":
			return Level.MEDIUM
		"high", "2":
			return Level.HIGH
	return -1


static func label() -> String:
	return LABELS[level]


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	level = clampi(int(cfg.get_value(SECTION, "level", Level.HIGH)), Level.LOW, Level.HIGH)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "level", level)
	cfg.save(path)


## Set and (by default) save the level. Out-of-range values clamp.
static func set_level(new_level: int, save: bool = true) -> void:
	_loaded = true
	level = clampi(new_level, Level.LOW, Level.HIGH)
	if save:
		save_settings()


## Applies `--quality=low|medium|high` from the arguments, without saving. Returns true if one was found.
static func from_args(args: PackedStringArray) -> bool:
	for a: String in args:
		if a.begins_with("--quality="):
			var parsed: int = parse(a.trim_prefix("--quality="))
			if parsed >= 0:
				set_level(parsed, false)
				return true
	return false


static func life_density() -> float:
	load_settings()
	return LIFE_DENSITY[level]


static func life_step() -> float:
	load_settings()
	return LIFE_STEP[level]


static func sway_step() -> float:
	load_settings()
	return SWAY_STEP[level]


static func sway_stride() -> int:
	load_settings()
	return SWAY_STRIDE[level]


## Ground relight cost knobs: the shader's `march_steps`, the stride multiplier and `ao_taps`.
static func shadow_steps() -> int:
	load_settings()
	return SHADOW_STEPS[level]


static func shadow_stride() -> float:
	load_settings()
	return SHADOW_STRIDE[level]


static func ao_taps() -> int:
	load_settings()
	return AO_TAPS[level]


## False on Low: the light grade pass is skipped (it is the only shader that reads the finished screen).
static func screen_grade() -> bool:
	load_settings()
	return SCREEN_GRADE[level]


## False on Low: the splash rings and the dawn ground mist are skipped. The puddles stay.
static func rain_rings_and_mist() -> bool:
	load_settings()
	return RAIN_RINGS_MIST[level]


## `full` scaled by the level's particle share, never below 2 so a burst still reads as a burst.
static func particle_count(full: int) -> int:
	load_settings()
	return maxi(2, roundi(float(full) * PARTICLE_SCALE[level]))


## `full` scaled by the level's life density, never below 1.
static func life_count(full: int) -> int:
	load_settings()
	return maxi(1, roundi(float(full) * LIFE_DENSITY[level]))


## `full` scaled by the life density, and 0 stays 0 (rain can clear the air of fireflies).
static func life_scaled(full: int) -> int:
	load_settings()
	return roundi(float(full) * LIFE_DENSITY[level])


## The part of `node`'s local space that is on screen, grown by CULL_MARGIN. An empty Rect2 (no culling)
## when the node is outside the tree. Cheap enough to call once per redraw, not once per element.
static func visible_local_rect(node: CanvasItem) -> Rect2:
	if not node.is_inside_tree():
		return Rect2()
	# The window in pixels. get_visible_rect() is the base canvas size (640x360), which the viewport transform stretches to
	# the window, so mapping it through the transform covered only the top-left corner of the screen whenever the window was
	# bigger than the base size.
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(node.get_viewport().size))
	return local_rect_of(screen, node.get_viewport_transform(), node.get_global_transform())


## `screen` (window pixels) mapped into a node's local space through the viewport and global transforms, grown by CULL_MARGIN.
static func local_rect_of(screen: Rect2, viewport_transform: Transform2D, global_transform: Transform2D) -> Rect2:
	var to_local: Transform2D = (viewport_transform * global_transform).affine_inverse()
	return (to_local * screen).grow(CULL_MARGIN)
