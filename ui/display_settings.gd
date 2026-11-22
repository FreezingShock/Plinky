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
const SETTINGS_VERSION: int = 2  # 2: Fit is the default, and older Pixel defaults are reset once
const BASE: Vector2i = Vector2i(640, 360)
const BLEED_ART: Vector2i = Vector2i(840, 480)  # meadow backdrop bleed, placements3d.json "bleed" (PR #4)
const MIN_PIXEL_SCALE: int = 2

## True now that the 3D meadow (PR #4) provides the 840x480 backdrop bleed. Set false to letterbox Wide view at 640x360.
static var bleed_ready: bool = true
static var scale_mode: int = Scale.FIT
static var fullscreen: bool = false
## Window size the player picked in the menu. ZERO means free: the window is whatever size it was dragged to.
static var resolution: Vector2i = Vector2i.ZERO
## Monitor index, or -1 to stay on whichever one the window is on.
static var screen: int = -1
static var vsync: bool = true
## 0 = unlimited.
static var fps_cap: int = 0
static var _loaded: bool = false
static var _ignore_resize_until_ms: int = 0

## Window sizes offered in the menu, besides the monitor's own size. Sizes that don't fit on the monitor are hidden.
const COMMON_SIZES: Array[Vector2i] = [
	Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
]
const FPS_CAPS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	scale_mode = clampi(int(cfg.get_value(SECTION, "scale", Scale.FIT)), Scale.PIXEL, Scale.WIDE)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", false))
	resolution = Vector2i(int(cfg.get_value(SECTION, "res_w", 0)), int(cfg.get_value(SECTION, "res_h", 0)))
	if resolution.x < BASE.x or resolution.y < BASE.y:
		resolution = Vector2i.ZERO
	screen = int(cfg.get_value(SECTION, "screen", -1))
	vsync = bool(cfg.get_value(SECTION, "vsync", true))
	fps_cap = maxi(0, int(cfg.get_value(SECTION, "fps_cap", 0)))
	# Saves before version 2 stored Pixel perfect, which was the old default. Reset that once to Fit, so a stale
	# Pixel setting can't leave the view stepping in whole multiples. Pixel perfect is still there in the panel.
	if int(cfg.get_value(SECTION, "version", 1)) < SETTINGS_VERSION:
		scale_mode = Scale.FIT
		save_settings()


static func save_settings() -> void:
	# SettingsFile loads the file first, so the game and keys sections survive this write.
	SettingsFile.write(SECTION, {
		"version": SETTINGS_VERSION, "scale": scale_mode, "fullscreen": fullscreen,
		"res_w": resolution.x, "res_h": resolution.y, "screen": screen, "vsync": vsync, "fps_cap": fps_cap,
	})


## The size Godot scales from: 640x360, or the bleed in Wide view. Wide view picks the largest whole-number
## scale at which the whole bleed fits, so a 1080p window shows 840x480 at 2x rather than 840x360 at 3x.
static func base_size() -> Vector2i:
	return bleed_size() if scale_mode == Scale.WIDE else BASE


## Largest whole-number scale at which the window can show the base size.
static func integer_scale(win: Window) -> int:
	var base: Vector2i = base_size()
	return maxi(1, mini(win.size.x / base.x, win.size.y / base.y))


## True when a whole-number scale is in use (Pixel perfect or Wide view, not below MIN_PIXEL_SCALE).
static func pixel_active(win: Window) -> bool:
	return scale_mode == Scale.PIXEL and integer_scale(win) >= MIN_PIXEL_SCALE


## The view size the frame may fill: 640x360, or the 840x480 bleed once its art is in.
static func bleed_size() -> Vector2i:
	return BLEED_ART if bleed_ready else BASE


## Push the saved settings to the window. Safe to call on every resize.
static func apply(win: Window) -> void:
	load_settings()
	win.min_size = BASE
	# A maximized window counts as windowed. Without this, every size_changed snapped a maximized window back to its old size.
	var mode_ok: bool
	if fullscreen:
		mode_ok = win.mode == Window.MODE_FULLSCREEN
	else:
		mode_ok = win.mode == Window.MODE_WINDOWED or win.mode == Window.MODE_MAXIMIZED
	if not mode_ok:
		win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	var base: Vector2i = base_size()
	# The base canvas must scale with the window, so the root is never left in the disabled content scale mode.
	if win.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if win.content_scale_size != base:
		win.content_scale_size = base
	# Always letterbox the base size. In Wide view the base is the bleed, so the whole bleed is shown,
	# centred by Godot, with black beyond it. EXPAND gave an off-centre frame on ultrawide.
	var aspect: int = Window.CONTENT_SCALE_ASPECT_KEEP
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
	# Leaving fullscreen: go back to the size the player picked, not whatever the OS remembers.
	if not on and resolution != Vector2i.ZERO:
		_ignore_resize_until_ms = Time.get_ticks_msec() + 800
		win.set_deferred("size", resolution)


static func toggle_fullscreen(win: Window) -> void:
	load_settings()
	set_fullscreen(win, not fullscreen)


# ---------------------------------------------------------------- resolution, monitor, vsync, fps

static func screen_count() -> int:
	return DisplayServer.get_screen_count()


## The monitor the window is on, or the one chosen in the menu.
static func active_screen(win: Window) -> int:
	if screen >= 0 and screen < screen_count():
		return screen
	return clampi(win.current_screen, 0, maxi(0, screen_count() - 1))


## Window sizes that fit the monitor, smallest first, with the monitor's own size last.
static func resolution_options(win: Window) -> Array[Vector2i]:
	var idx: int = active_screen(win)
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(idx).size
	var native: Vector2i = DisplayServer.screen_get_size(idx)
	var out: Array[Vector2i] = []
	for sz in COMMON_SIZES:
		if sz.x <= usable.x and sz.y <= usable.y and sz.x >= BASE.x and sz.y >= BASE.y and sz != native:
			out.append(sz)
	if native.x >= BASE.x and native.y >= BASE.y:
		out.append(native)
	return out


static func resolution_label(sz: Vector2i, win: Window) -> String:
	var native: Vector2i = DisplayServer.screen_get_size(active_screen(win))
	return "%dx%d%s" % [sz.x, sz.y, " (native)" if sz == native else ""]


## Windowed at an exact size, centred on the monitor. Leaves fullscreen if it was on.
static func set_resolution(win: Window, sz: Vector2i) -> void:
	load_settings()
	resolution = Vector2i(maxi(sz.x, BASE.x), maxi(sz.y, BASE.y))
	fullscreen = false
	save_settings()
	_ignore_resize_until_ms = Time.get_ticks_msec() + 800
	apply(win)
	win.size = resolution
	_centre(win)


## Drop the picked size: the window keeps whatever size it has and is free to resize.
static func set_free_size() -> void:
	load_settings()
	resolution = Vector2i.ZERO
	save_settings()


## Call on every window size change. A resize that isn't ours (the player dragged an edge) makes the size free.
static func note_resized(win: Window) -> void:
	if resolution == Vector2i.ZERO or fullscreen or win.mode != Window.MODE_WINDOWED:
		return
	if Time.get_ticks_msec() < _ignore_resize_until_ms:
		return
	if win.size != resolution:
		resolution = Vector2i.ZERO
		save_settings()


static func set_screen(win: Window, idx: int) -> void:
	load_settings()
	if idx < 0 or idx >= screen_count():
		return
	screen = idx
	save_settings()
	_ignore_resize_until_ms = Time.get_ticks_msec() + 800
	win.current_screen = idx
	if not fullscreen:
		if resolution != Vector2i.ZERO:
			var usable: Vector2i = DisplayServer.screen_get_usable_rect(idx).size
			resolution = Vector2i(mini(resolution.x, usable.x), mini(resolution.y, usable.y))
			win.size = resolution
			save_settings()
		_centre(win)


static func _centre(win: Window) -> void:
	var r: Rect2i = DisplayServer.screen_get_usable_rect(active_screen(win))
	win.position = r.position + (r.size - win.size) / 2


static func set_vsync(on: bool) -> void:
	load_settings()
	vsync = on
	save_settings()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)


static func set_fps_cap(n: int) -> void:
	load_settings()
	fps_cap = maxi(0, n)
	save_settings()
	Engine.max_fps = fps_cap


## Everything saved that apply() leaves alone: monitor, size, vsync, fps cap. Call once at startup, after apply().
static func apply_startup(win: Window) -> void:
	load_settings()
	if screen >= 0 and screen < screen_count():
		win.current_screen = screen
	if resolution != Vector2i.ZERO and not fullscreen:
		var usable: Vector2i = DisplayServer.screen_get_usable_rect(active_screen(win)).size
		if resolution.x <= usable.x and resolution.y <= usable.y:
			_ignore_resize_until_ms = Time.get_ticks_msec() + 800
			win.size = resolution
			_centre(win)
		else:
			resolution = Vector2i.ZERO
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap
