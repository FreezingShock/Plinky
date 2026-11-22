extends RefCounted
## Switch queue suite: spamming window-mode switches never double-runs, never sticks, and ends in the last
## requested mode. Run through tests/run.gd.

func run(t: SceneTree) -> void:
	var q := SwitchQueue.new()
	t.ok(q.request(true), "first request starts")
	t.ok(not q.request(true), "a repeat while busy is queued, not started")
	t.eq(q.finish(true), SwitchQueue.NONE, "a repeat of the same target ends with no extra switch")
	t.ok(not q.busy, "queue is idle once finished")

	t.ok(q.request(true), "start fullscreen")
	t.ok(not q.request(false), "back to windowed while covered is queued")
	t.eq(q.finish(true), 0, "the queued opposite request runs next")
	t.ok(q.busy, "queue stays busy for the follow-up switch")
	t.eq(q.finish(false), SwitchQueue.NONE, "follow-up done, nothing left")

	t.ok(q.request(true), "start again")
	for i in 50:
		q.request(i % 2 == 0)  # spam alternating
	t.eq(q.pending, 0, "spam collapses to the last request")
	t.eq(q.finish(true), 0, "and runs once")
	t.eq(q.finish(false), SwitchQueue.NONE, "then settles")
	t.ok(not q.busy, "never stuck busy after spam")

	t.ok(q.request(false), "start")
	q.request(true)
	q.reset()
	t.ok(not q.busy and q.pending == SwitchQueue.NONE, "reset clears a stuck queue")
	t.ok(q.request(true), "and a new request starts after reset")
