class_name GuiGuard
extends RefCounted
## Tells whether a click landed on the GUI, so the world can ignore it (tap-to-move and its walk ring).
## Godot only routes a click to _unhandled_input when no Control stopped it, and a Control whose mouse_filter
## is PASS or IGNORE lets the click through. A panel's background often uses one of those, so clicks inside an
## open menu, the HUD or a tooltip would reach the world. This checks the visible Controls' rectangles instead.
##
## Counted: any visible Control under the point whose mouse_filter is STOP or PASS, and any Panel or PanelContainer
## (whatever its filter, because menu backgrounds are often IGNORE). Not counted: IGNORE containers and labels that
## are not panels (the pixel view, the HUD root, floating numbers), and full-screen layout roots that are not panels.

## `view` is the screen size used to spot full-screen layout roots; left empty it is read from a Window root.
static func covers(tree_root: Node, pos: Vector2, view: Vector2 = Vector2.ZERO) -> bool:
	if tree_root == null:
		return false
	if view == Vector2.ZERO and tree_root is Window:
		view = (tree_root as Window).get_visible_rect().size
	return _scan(tree_root, pos, view)


static func _scan(node: Node, pos: Vector2, view: Vector2) -> bool:
	for child: Node in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue   # a hidden branch takes no clicks, so skip its children too
		if child is Control and _counts(child as Control, pos, view):
			return true
		if _scan(child, pos, view):
			return true
	return false


static func _counts(c: Control, pos: Vector2, view: Vector2) -> bool:
	var rect: Rect2 = c.get_global_rect()
	if not rect.has_point(pos):
		return false
	var panel: bool = c is Panel or c is PanelContainer
	if not panel:
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
		if view != Vector2.ZERO and rect.size.x >= view.x - 1.0 and rect.size.y >= view.y - 1.0:
			return false   # a full-screen layout root must not swallow every click
	return true
