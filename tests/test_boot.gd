extends RefCounted
## Boot suite: the threaded loader reports real progress and failures, and the tip list is clean.
## Run through tests/run.gd.

func run(t: SceneTree) -> void:
	# Real files load on the worker threads and reach 1.0.
	var loader := BootLoader.new()
	loader.add("res://theme/plinky_theme.tres", 1.0, "theme")
	loader.add("res://world/meadow3d_scene.tscn", 3.0, "meadow")
	loader.start()
	var guard: int = 0
	while not loader.is_finished() and guard < 5000:
		loader.poll()
		OS.delay_msec(2)
		guard += 1
	t.ok(loader.is_finished(), "threaded loads finish")
	t.ok(not loader.has_failures(), "real files report no failures")
	t.near(loader.poll(), 1.0, 0.0001, "progress is 1.0 once everything has loaded")
	t.ok(loader.resource_for("res://theme/plinky_theme.tres") is Theme, "theme resource is returned")
	t.ok(loader.resource_for("res://world/meadow3d_scene.tscn") is PackedScene, "meadow scene is returned")
	t.eq(loader.current_label(), "Ready", "label reads Ready when finished")

	# A path that keeps failing is retried a bounded number of times, then reported; the retries never hide it.
	var retry := BootLoader.new()
	retry.add("res://does_not_exist/also_missing.tscn", 1.0, "missing")
	retry.start()
	guard = 0
	while not retry.is_finished() and guard < 20000:
		retry.poll()
		OS.delay_msec(1)
		guard += 1
	t.ok(retry.is_finished(), "a failing path still finishes (retries are bounded)")
	t.ok(retry.has_failures(), "a path that fails every retry is reported")
	t.eq(BootLoader.MAX_RETRIES, 2, "retry budget is two re-requests")

	# A missing file is reported as a failure, not hidden behind a full bar.
	var bad := BootLoader.new()
	bad.add("res://does_not_exist/missing.tscn", 1.0, "missing")
	bad.start()
	guard = 0
	while not bad.is_finished() and guard < 5000:
		bad.poll()
		OS.delay_msec(2)
		guard += 1
	t.ok(bad.has_failures(), "missing file is reported as a failure")
	t.eq(bad.failed_paths().size(), 1, "one failed path is listed")
	t.ok(bad.resource_for("res://does_not_exist/missing.tscn") == null, "failed task has no resource")

	# An empty loader is already complete.
	var empty := BootLoader.new()
	t.near(empty.poll(), 1.0, 0.0001, "empty loader reads as complete")

	# Tips are present and carry no banned word.
	t.ok(BootScreen.TIPS.size() >= 5, "at least five tips")
	for tip: String in BootScreen.TIPS:
		t.ok(tip.length() > 0 and tip.length() <= 120, "tip length is sensible: %s" % tip)
		t.ok(tip.to_lower().find("plinko") == -1, "tip avoids the word Plinko")
