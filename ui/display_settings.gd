class_name DisplaySettings
extends RefCounted
## Window scale and window mode.
## Pixel perfect: whole-number scale, letterboxed (the spec default).
## Fit: fills the window at any size, texels may differ by one pixel.
## Wide view: whole-number scale, and the view widens or heightens out to the bleed size (see bleed_size),
## so the meadow backdrop shows past 640x360 on wide and tall windows.
## Windowed or fullscreen (F11). Saved to user://settings.cfg.
## Below MIN_PIXEL_SCALE, the whole-number scales fall back to Fit, so the view is never a 1x island.

enum Scale { PIXEL, FIT, WIDE }

const PATH: String = "user://settings.cfg"
const SECTION: String = "display"
const BASE: Vector2i = Vector2i(640, 360)
const BLEED_ART: Vector2i = Vector2i(840, 480)  # meadow backdrop bleed, placements3d.json "bleed" (PR #4)
const MIN_PIXEL_SCALE: int = 2

## Stays false until the 840x480 backdrop is in the scene. Until then Wide view letterboxes at 640x360.
static var bleed_ready: bool = false
static var scale_mode: int = Scale.PIXEL
static var fullscreen: bool = false
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	scale_mode = clampi(int(cfg.get_value(SECTION, "scale", Scale.PIXEL)), Scale.PIXEL, Scale.WIDE)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", false))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "scale", scale_mode)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(PATH)


## Largest whole-number scale at which the window can show the 640x360 view.
static func integer_scale(win: Window) -> int:
	return maxi(1, mini(win.size.x / BASE.x, win.size.y / BASE.y))


## True when a whole-number scale is in use (Pixel perfect or Wide view, not below MIN_PIXEL_SCALE).
static func pixel_active(win: Window) -> bool:
	return scale_mode != Scale.FIT and integer_scale(win) >= MIN_PIXEL_SCALE


## The view size the frame may fill: 640x360, or the 840x480 bleed once its art is in.
static func bleed_size() -> Vector2i:
	return BLEED_ART if bleed_ready else BASE


## Push the saved settings to the window. Safe to call on every resize.
static func apply(win: Window) -> void:
	load_settings()
	win.min_size = BASE
	var want: Window.Mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if win.mode != want:
		win.mode = want
	var aspect: int = Window.CONTENT_SCALE_ASPECT_EXPAND if scale_mode == Scale.WIDE else Window.CONTENT_SCALE_ASPECT_KEEP
	if win.content_scale_aspect != aspect:
		win.content_scale_aspect = aspect
	var stretch: int = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_active(win) else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if win.content_scale_stretch != stretch:
		win.content_scale_stretch = stretch
	RenderingServer.set_default_clear_color(Color.BLACK)


static func set_scale_mode(win: Window, mode: int) -> void:
	load_settings()
	scale_mode = clampi(mode, Scale.PIXEL, Scale.WIDE)
	save_settings()
	apply(win)


static func set_fullscreen(win: Window, on: bool) -> void:
	load_settings()
	fullscreen = on
	save_settings()
	apply(win)


static func toggle_fullscreen(win: Window) -> void:
	load_settings()
	set_fullscreen(win, not fullscreen)
