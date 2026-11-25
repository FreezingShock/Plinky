class_name PlinkyTheme
## Recolours plinky_theme.tres for a zone. Call on zone entry (instant) or each frame of the
## 1.5 s palette shift with a blended `colors` dictionary.
##
## Every colour and style change is made with the theme's change signals held back, and the theme announces one change at
## the end. Without that, each of the ~25 writes told every Control that uses the theme to restyle itself, which on zone
## entry cost about 130 ms of the swap frame (the Larkmoor swap in tools/larkmoor_entry_probe.gd).
static func apply(theme: Theme, zone: String) -> void:
	var c := func(r: String) -> Color: return PlinkyPalette.role(zone, r)
	theme.set_block_signals(true)
	for t in ["Label", "Button", "CheckBox"]:
		theme.set_color("font_color", t, c.call("text"))
	theme.set_color("font_disabled_color", "Button", c.call("text_dim"))
	theme.set_color("font_hover_color", "Button", c.call("accent"))
	theme.set_color("font_pressed_color", "Button", c.call("ink"))
	theme.set_color("font_outline_color", "Label", c.call("ink"))
	for s in [["Panel", "panel"], ["Button", "normal"], ["Button", "hover"], ["Button", "pressed"], ["Button", "disabled"], ["Button", "focus"], ["ProgressBar", "background"], ["ProgressBar", "fill"]]:
		var sb := theme.get_stylebox(s[1], s[0]) as StyleBoxFlat
		if sb == null: continue
		sb.set_block_signals(true)
		match s[0] + "/" + s[1]:
			"Panel/panel", "Button/normal", "Button/disabled": sb.bg_color = c.call("ink"); sb.border_color = c.call("panel_edge") if s[1] != "disabled" else c.call("bar_empty")
			"Button/hover": sb.bg_color = c.call("ink"); sb.border_color = c.call("accent")
			"Button/pressed": sb.bg_color = c.call("accent"); sb.border_color = c.call("accent")
			"Button/focus": sb.border_color = c.call("text")
			"ProgressBar/background": sb.bg_color = c.call("bar_empty")
			"ProgressBar/fill": sb.bg_color = c.call("bar_fill")
		sb.set_block_signals(false)
	theme.set_block_signals(false)
	theme.emit_changed()
