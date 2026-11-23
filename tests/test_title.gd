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

	# Tiles are icon-only at rest and never change size when the label opens.
	var tile: GalleryTile = g.tile(&"stats")
	t.eq(tile.label_t, 0.0, "a resting tile shows no label")
	var size_before: Vector2 = tile.custom_minimum_size
	tile.label_t = 1.0
	t.eq(tile.custom_minimum_size, size_before, "an open tile label never shifts layout")
	g.free()


func _collect(n: Node, out: Array[MenuTextButton]) -> void:
	if n is MenuTextButton:
		out.append(n as MenuTextButton)
	for c: Node in n.get_children():
		_collect(c, out)
