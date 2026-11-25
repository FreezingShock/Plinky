extends RefCounted
## The zone reset confirm (ui/reset_confirm.gd): the hold fills to full in HOLD_TIME and strikes only then, and a menu
## router with a blocker refuses to open other menus while it is up.

func run(t: Object) -> void:
	t.eq(ResetConfirm.fill_for(0.0), 0.0, "an unheld confirm reads empty")
	t.near(ResetConfirm.fill_for(ResetConfirm.HOLD_TIME * 0.5), 0.5, 0.001, "half the hold fills half the bar")
	t.eq(ResetConfirm.fill_for(ResetConfirm.HOLD_TIME * 3.0), 1.0, "the fill stops at full")
	t.ok(not ResetConfirm.strikes(ResetConfirm.HOLD_TIME - 0.01), "a hold just short of full does not strike")
	t.ok(ResetConfirm.strikes(ResetConfirm.HOLD_TIME), "a full hold strikes")
	var router: MenuRouter = MenuRouter.new()
	var opened: Array[StringName] = []
	router.register(&"upgrades", func() -> bool: return false, func() -> void: opened.append(&"upgrades"), func() -> void: pass)
	var blocked: Array[bool] = [true]
	router.blocked = func() -> bool: return blocked[0]
	router.open(&"upgrades")
	t.eq(opened.size(), 0, "no other menu opens while the reset confirm is up")
	blocked[0] = false
	router.open(&"upgrades")
	t.eq(opened, [&"upgrades"], "menus open again once the confirm closes")
