class_name DisplaySettings
extends RefCounted
## Window scale and window mode.
## Scale: Pixel perfect (whole-number scale, the spec default) or Fit (fills the window at any size).
## Mode: windowed or fullscreen (F11). Saved to user://settings.cfg.
## Below MIN_PIXEL_SCALE, Pixel perfect would show the 640x360 view as a small island in a larger window,
## so it falls back to Fit until the window is big enough for a 2x whole-number scale.

enum Scale { PIXEL, FIT }

const PATH: String = "user://settings.cfg"
const SECTION: String = "display"
const BASE: Vector2i = Vector2i(640, 360)
const MIN_PIXEL_SCALE: int = 2

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
	scale_mode = clampi(int(cfg.get_value(SECTION, "scale", Scale.PIXEL)), Scale.PIXEL, Scale.FIT)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", false))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "scale", scale_mode)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(PATH)


## Largest whole-number scale at which the window can show the 640x360 view.
static func integer_scale(win: Window) -> int:
	return maxi(1, mini(win.size.x / BASE.x, win.size.y / BASE.y))


## True when Pixel perfect is actually in use (it falls back to Fit below MIN_PIXEL_SCALE).
static func pixel_active(win: Window) -> bool:
	return scale_mode == Scale.PIXEL and integer_scale(win) >= MIN_PIXEL_SCALE


## Push the saved settings to the window. Safe to call on every resize.
static func apply(win: Window) -> void:
	load_settings()
	win.min_size = BASE
	var want: Window.Mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if win.mode != want:
		win.mode = want
	var stretch: Window.ContentScaleStretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_active(win) else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if win.content_scale_stretch != stretch:
		win.content_scale_stretch = stretch


static func set_scale_mode(win: Window, mode: int) -> void:
	load_settings()
	scale_mode = clampi(mode, Scale.PIXEL, Scale.FIT)
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
