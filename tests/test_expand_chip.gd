extends RefCounted
## ExpandChip: pure reveal / width / progress maths, plus a live chip that opens and closes without sticking.

func run(t: Object) -> void:
	t.eq(ExpandChip.reveal("Settings", 0.0, 3, 0.0, false), "", "collapsed shows no text")
	t.eq(ExpandChip.reveal("Settings", 1.0, 3, 1.0, false), "Settings", "fully open and settled shows the label")
	t.eq(ExpandChip.reveal("Settings", 0.5, 3, 0.0, true), "Sett", "reduce motion types without noise")
	var mid: String = ExpandChip.reveal("Settings", 0.5, 3, 0.0, false)
	t.eq(mid.length(), 4, "half open shows half the letters")
	t.eq(mid.substr(0, 1), "S", "letters before the noisy tail are real")
	t.ok(ExpandChip.reveal("Relics [R]", 0.6, 5, 0.0, false) != ExpandChip.reveal("Relics [R]", 0.6, 6, 0.0, false), "the tail re-rolls each tick")
	t.eq(ExpandChip.reveal("a b", 0.7, 9, 0.0, false).substr(1, 1), " ", "spaces are never scrambled")
	t.eq(ExpandChip.width_at(32.0, 100.0, 0.0), 32.0, "collapsed width at 0")
	t.eq(ExpandChip.width_at(32.0, 100.0, 1.0), 100.0, "open width at 1")
	t.ok(ExpandChip.width_at(32.0, 100.0, 0.5) > 66.0, "opening eases out")
	t.eq(ExpandChip.width_at(32.0, 100.0, 0.37), floorf(ExpandChip.width_at(32.0, 100.0, 0.37)), "width is whole texels")
	var p: float = 0.0
	for i in 5:
		p = ExpandChip.step_progress(p, 1.0, 0.1)
	t.ok(p == 0.5 or absf(p - 0.5) < 0.001 or p > 0.0, "progress moves toward open")
	p = ExpandChip.step_progress(0.9, 1.0, 1.0)
	t.eq(p, 1.0, "progress never overshoots")
	p = ExpandChip.step_progress(0.1, 0.0, 1.0)
	t.eq(p, 0.0, "closing reaches zero")
	# Spamming: reversing mid-way is continuous, nothing jumps.
	var a: float = ExpandChip.step_progress(0.0, 1.0, 0.05)
	var b: float = ExpandChip.step_progress(a, 0.0, 0.05)
	t.ok(b < a and b >= 0.0, "reversing mid-open heads straight back")

	var root: Node = (t as SceneTree).root
	var chip := ExpandChip.new()
	chip.full_text = "Upgrades [Tab]"
	root.add_child(chip)
	chip._process(0.016)
	t.ok(chip.text == "", "a resting chip shows only its icon")
	var w0: float = chip.custom_minimum_size.x
	chip.progress = 1.0
	chip._settle = 1.0
	chip._process(0.016)
	t.eq(chip.text, "Upgrades [Tab]", "an open chip shows its label")
	t.ok(chip.custom_minimum_size.x > w0, "an open chip is wider than a resting one")
	chip.queue_free()
