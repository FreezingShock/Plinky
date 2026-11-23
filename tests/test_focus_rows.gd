extends RefCounted
## Settings rows are wired for Up/Down so the pad can walk a long tab (DisplayPanel.link_rows).

func run(t: Object) -> void:
	var root := Control.new()
	var above := Button.new()
	var below := Button.new()
	root.add_child(above)
	var rows: Array = []
	for i in 30:
		var box := HBoxContainer.new()
		root.add_child(box)
		var ctl: Array[Control] = []
		for j in 1 + i % 3:
			var b := Button.new()
			box.add_child(b)
			ctl.append(b)
		rows.append(ctl)
	root.add_child(below)
	DisplayPanel.link_rows(rows, above, below)
	var cur: Control = (rows[0] as Array)[0]
	t.ok(cur.get_node(cur.focus_neighbor_top) == above, "first row goes up to the tab")
	var visited: int = 1
	while cur.get_node(cur.focus_neighbor_bottom) != below and visited < 100:
		cur = cur.get_node(cur.focus_neighbor_bottom)
		visited += 1
	t.eq(visited, 30, "Down walks every one of 30 rows")
	var last: Control = (rows[29] as Array)[-1]
	t.ok(last.get_node(last.focus_neighbor_bottom) == below, "last row goes down to Close")
	var wide: Control = (rows[2] as Array)[2]
	t.ok(wide.get_node(wide.focus_neighbor_top) == (rows[1] as Array)[0], "every control in a row shares the row links")
	root.free()
