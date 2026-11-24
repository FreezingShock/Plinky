extends RefCounted
## A panel brought to the front must keep its close X after it, or the panel swallows the X's clicks.


func run(t: Object) -> void:
	var root := Control.new()
	var panel := Control.new()
	root.add_child(panel)
	var x: CloseX = CloseX.attach(panel, func() -> void: pass)
	var other := Control.new()
	root.add_child(other)
	panel.visible = true
	MenuAnim.bring_front(panel)
	t.ok(x.get_index() > panel.get_index(), "the close X stays after its panel once the panel is brought to the front")
	t.eq(panel.get_index(), root.get_child_count() - 2, "the panel is second to last, just under its X")
	root.free()
