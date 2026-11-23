extends RefCounted
## Sprint, jump, crouch and slide (world/walker_motion.gd), the row-drawing maths in WalkerBody, and the camera and
## shadow helpers that react to them. All pure logic, so it runs headless.

const DT: float = 1.0 / 60.0


func _run_for(m: WalkerMotion, seconds: float, moving: bool, sprint: bool, crouch: bool, jump: bool) -> void:
	for i: int in int(seconds / DT):
		m.tick(DT, moving, sprint, crouch, jump)


func run(t: Object) -> void:
	var m := WalkerMotion.new()
	t.near(m.speed_mult(), 1.0, 0.001, "starts at walking speed")
	t.eq(m.sprint_state(), 0, "not sprinting at first")

	# Sprint: Shift held ramps to the sprint multiplier, release eases back.
	_run_for(m, 1.5, true, true, false, false)
	t.near(m.speed_mult(), m.cfg.sprint_mult, 0.02, "holding Shift sprints")
	t.eq(m.sprint_state(), 1, "Shift reads as HELD")
	_run_for(m, 1.5, true, false, false, false)
	t.near(m.speed_mult(), 1.0, 0.02, "letting go of Shift walks again")
	t.eq(m.sprint_state(), 0, "released reads as off")

	# Ctrl lock keeps sprinting with no key held, and toggles off.
	m.toggle_sprint_lock()
	_run_for(m, 1.5, true, false, false, false)
	t.near(m.speed_mult(), m.cfg.sprint_mult, 0.02, "locked sprint runs without Shift")
	t.eq(m.sprint_state(), 2, "locked reads as ENABLED")
	_run_for(m, 0.5, false, false, false, false)
	t.near(m.speed_mult(), 1.0, 0.1, "standing still drops the factor")
	m.toggle_sprint_lock()
	t.eq(m.sprint_state(), 0, "Ctrl again unlocks")
	_run_for(m, 1.0, true, false, false, false)

	# Crouch: slower, and it is not a slide when walking.
	_run_for(m, 1.0, true, false, true, false)
	t.ok(not m.sliding(), "crouching at walk speed does not slide")
	t.ok(m.crouching(), "C held on the ground crouches")
	t.near(m.speed_mult(), m.cfg.crouch_mult, 0.05, "crouch walks slower")
	_run_for(m, 1.0, true, false, false, false)
	t.ok(not m.crouching(), "letting go of C stands up")

	# Slide: C pressed while sprinting.
	_run_for(m, 1.5, true, true, false, false)
	var slid: bool = false
	var first_speed: float = 0.0
	for i: int in 3:
		m.tick(DT, true, true, true, false)
		if m.just_slid:
			slid = true
			first_speed = m.speed_mult()
	t.ok(slid, "C while sprinting slides")
	t.ok(m.sliding(), "the slide is running")
	t.ok(first_speed >= m.cfg.slide_mult_start - 0.05, "a slide opens with a burst")
	_run_for(m, m.cfg.slide_time * 0.8, true, true, true, false)
	t.ok(m.speed_mult() < first_speed - 0.5, "the slide eases down")
	_run_for(m, m.cfg.slide_time, true, true, true, false)
	t.ok(not m.sliding(), "the slide ends")
	_run_for(m, 1.0, true, false, false, false)

	# Jump: height, airtime, one landing event.
	var j := WalkerMotion.new()
	_run_for(j, 0.3, false, false, false, false)
	j.queue_jump()
	var peak: float = 0.0
	var jumps: int = 0
	var lands: int = 0
	var frames: int = 0
	while frames < 120:
		j.tick(DT, false, false, false, true)
		peak = maxf(peak, j.z)
		jumps += int(j.just_jumped)
		lands += int(j.just_landed)
		frames += 1
		if lands > 0:
			break
	t.eq(jumps, 1, "one jump per press")
	t.eq(lands, 1, "one landing")
	t.ok(j.grounded and j.z == 0.0, "back on the ground")
	t.near(peak, WalkerMotion.peak_height(), 0.12, "a held jump reaches its peak height")
	t.ok(peak >= 12.0 and peak <= 24.0, "a jump is readable but not huge (%.1f texels)" % peak)
	t.ok(frames * DT >= 0.35 and frames * DT <= 0.8, "airtime is about half a second")

	# Letting go early makes a short hop.
	var s := WalkerMotion.new()
	s.queue_jump()
	var short_peak: float = 0.0
	for i: int in 90:
		s.tick(DT, false, false, false, i < 3)
		short_peak = maxf(short_peak, s.z)
	t.ok(short_peak < peak * 0.7, "tapping jump hops lower than holding it")

	# A jump speeds you up, and chained hops stack to a cap.
	var b := WalkerMotion.new()
	_run_for(b, 1.0, true, true, false, false)
	var before: float = b.speed_mult()
	b.queue_jump()
	_run_for(b, 0.3, true, true, false, true)
	t.ok(b.speed_mult() > before + 0.05, "jumping adds speed")
	t.ok(b.boost <= b.cfg.jump_boost_max + 0.001, "the boost is capped")
	for i: int in 6:
		b.queue_jump()
		_run_for(b, 0.7, true, true, false, true)
	t.ok(b.boost <= b.cfg.jump_boost_max + 0.001, "chained hops stay under the cap")
	_run_for(b, 3.0, true, true, false, false)
	t.ok(b.boost < 0.05, "the boost fades on the ground")

	# Jump buffer: pressing just before touchdown chains straight into the next jump.
	var c := WalkerMotion.new()
	c.queue_jump()
	var rejumped: bool = false
	var landed_once: bool = false
	for i: int in 200:
		c.tick(DT, false, false, false, true)
		if not landed_once and not c.grounded and c.vz < 0.0 and c.z < 3.0:
			c.queue_jump()
		if c.just_landed:
			landed_once = true
		if landed_once and c.just_jumped:
			rejumped = true
			break
	t.ok(rejumped, "a jump pressed just before landing hops again")

	# WalkerBody row maths.
	t.eq(WalkerBody.src_height(0, 1.0), 0, "feet row maps to feet row")
	t.eq(WalkerBody.src_height(10, 1.0), 10, "unscaled rows map one to one")
	t.eq(WalkerBody.src_height(10, 0.5), 20, "a squashed sprite skips source rows")
	t.eq(WalkerBody.src_height(100, 1.0), WalkerBody.SPRITE_H - 1, "source rows are clamped")
	t.eq(WalkerBody.lean_shift(0, 40, 3.0), 0, "the feet never lean")
	t.eq(WalkerBody.lean_shift(40, 40, 3.0), 3, "the top leans the full amount")
	t.ok(WalkerBody.lean_shift(20, 40, 3.0) <= WalkerBody.lean_shift(30, 40, 3.0), "lean grows with height")
	t.eq(WalkerBody.row_width(1.0) % 2, 0, "row width is even")
	t.ok(WalkerBody.row_width(1.1) >= WalkerBody.row_width(0.9), "wider scale never draws narrower")

	# Shadow and camera helpers.
	t.near(WalkerMotion.shadow_scale(0.0), 1.0, 0.001, "shadow is full size on the ground")
	t.near(WalkerMotion.shadow_scale(40.0), 0.55, 0.001, "shadow shrinks high in a jump")
	t.ok(WalkerMotion.shadow_scale(8.0) < 1.0, "shadow starts shrinking at once")
	var lift: float = 0.0
	var worst: float = 0.0
	for i: int in 120:
		lift = WorldCamera.lift_follow_step(lift, 8.0, DT)
		worst = maxf(worst, lift)
	t.ok(worst <= 8.0 + 0.001, "the camera's rise never overshoots")
	t.ok(lift > 7.0, "the camera's rise reaches its goal within 2 s")
	t.near(WorldCamera.look_reach(1.0), WorldCamera.LOOK_AHEAD, 0.001, "walking leans the normal distance")
	t.ok(WorldCamera.look_reach(1.55) > WorldCamera.LOOK_AHEAD * 1.4, "sprinting leans further ahead")
	t.ok(WorldCamera.follow_rate(1.55) > WorldCamera.FOLLOW_RATE, "the view follows tighter at speed")

	# HUD label text.
	t.eq(WalkerMotion.sprint_text(0), "", "no label when not sprinting")
	t.eq(WalkerMotion.sprint_text(1), "SPRINTING HELD", "Shift label")
	t.eq(WalkerMotion.sprint_text(2), "SPRINTING ENABLED", "Ctrl lock label")

	# Keys: Crouch took C, so Recentre moved to Home, and an old save with Recentre on C heals itself.
	Keybinds.reset_all()
	t.eq(Keybinds.key_for(&"recenter"), KEY_HOME, "recentre defaults to Home")
	t.eq(Keybinds.key_for(&"crouch"), KEY_C, "crouch defaults to C")
	t.eq(Keybinds.key_for(&"jump"), KEY_SPACE, "jump defaults to Space")
	Keybinds._keys[&"recenter"] = KEY_C
	Keybinds._keys[&"settings"] = KEY_F9
	Keybinds._dedupe()
	t.eq(Keybinds.key_for(&"recenter"), KEY_HOME, "an old Recentre-on-C save falls back to Home")
	t.eq(Keybinds.key_for(&"crouch"), KEY_C, "crouch keeps C")
	t.eq(Keybinds.key_for(&"settings"), KEY_F9, "unrelated rebinds survive")
	Keybinds.reset_all()
