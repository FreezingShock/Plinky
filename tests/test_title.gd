extends RefCounted
## Title screen, its skip flag, the pause menu footer, the animated text buttons and the icon-only gallery tiles.

func run(t: Object) -> void:
	# Skip flag: the env var works anywhere (the CI smoke test uses the --skip-title user arg).
	t.ok(TitleScreen.SKIP_ARG == "--skip-title", "the skip flag is --skip-title")
	OS.unset_environment(TitleScreen.SKIP_ENV)
	if not OS.get_cmdline_user_args().has(TitleScreen.SKIP_ARG):
		t.ok(not TitleScreen.skip_requested(), "no flag, no skip")
	OS.set_environment(TitleScreen.SKIP_ENV, "1")
	t.ok(TitleScreen.skip_requested(), "the env var skips the title")
	OS.unset_environment(TitleScreen.SKIP_ENV)
	t.ok(["Play", "Continue"].has(TitleScreen.play_label()), "the main button reads Play or Continue")
	t.ok(ResourceLoader.exists(TitleScreen.TITLE_SCENE) and ResourceLoader.exists(TitleScreen.GAME_SCENE), "title and game scenes exist")

	# Text button maths.
	t.eq(MenuTextButton.nudge_px(0.0), 0, "a resting text button is not nudged")
	t.eq(MenuTextButton.nudge_px(1.0), MenuTextButton.NUDGE, "a hovered one nudges fully")
	t.eq(MenuTextButton.nudge_px(5.0), MenuTextButton.NUDGE, "nudge is clamped")
	t.eq(MenuTextButton.underline_px(100.0, 0.5), 50, "the underline sweeps out in whole texels")
	t.eq(MenuTextButton.underline_px(100.0, 0.0), 0, "no underline at rest")
	t.ok(MenuTextButton.ARROW_GAP >= 3, "the > marker keeps a gap before the first letter")
	t.ok(CrispFont.apply(MenuTextButton.FONT).antialiasing == TextServer.FONT_ANTIALIASING_NONE, "Pixelify Sans renders without grey anti-aliasing")

	var root: Node = (t as SceneTree).root
	var b := MenuTextButton.new()
	b.label = "Resume"
	root.add_child(b)
	var w0: float = b.custom_minimum_size.x
	b.accent_color = Color.RED
	b._process(0.05)
	t.ok(b.t == 0.0, "an unhovered button stays at rest")
	b.t = 1.0
	b.queue_redraw()
	t.eq(b.custom_minimum_size.x, w0, "hover never changes a text button's size")
	b.free()

	run_tip_card(t)

	# Gallery: icon tiles stay, text actions are separate, and each fires its signal.
	var g := GalleryMenu.new()
	root.add_child(g)
	t.ok(g.resume_button() != null, "the menu has a Close menu button")
	var seen: Array = []
	g.resume_requested.connect(func() -> void: seen.append("resume"))
	g.quit_to_title_requested.connect(func() -> void: seen.append("title"))
	g.quit_game_requested.connect(func() -> void: seen.append("quit"))
	var actions: Array[MenuTextButton] = []
	_collect(g, actions)
	t.eq(actions.size(), 3, "Close menu, Quit to title and Quit game")
	for a: MenuTextButton in actions:
		a.pressed.emit()
	t.eq(seen, ["resume", "title", "quit"], "each action emits its own signal")

	# Every tile carries its name, and the hover sweep never changes its size.
	var tile: GalleryTile = g.tile(&"stats")
	t.eq(tile.label, "Stats", "a resting tile shows its name")
	var size_before: Vector2 = tile.custom_minimum_size
	tile.sweep_t = 0.5
	t.eq(tile.custom_minimum_size, size_before, "the hover sweep never shifts layout")
	t.eq(tile.bob_px(), 0, "a resting tile does not bob")
	g.free()


func _collect(n: Node, out: Array[MenuTextButton]) -> void:
	if n is MenuTextButton:
		out.append(n as MenuTextButton)
	for c: Node in n.get_children():
		_collect(c, out)


func run_tip_card(t: Object) -> void:
	var c := TipCard.new()
	c.show_tip("Welcome", "Press a pad.", 10.0)
	t.ok(c.visible and c.is_showing(), "a tip shows")
	c.held = true
	t.ok(not c.visible and c.is_showing(), "an open menu hides the tip but keeps it alive")
	c._process(5.0)
	t.eq(c._left, 10.0, "the tip's timer waits while hidden")
	c.held = false
	t.ok(c.visible, "the tip returns when the menu closes")
	c.dismiss()
	c.held = false
	t.ok(not c.visible and not c.is_showing(), "a dismissed tip stays gone")
	c.free()
