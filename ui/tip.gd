class_name Tip
extends RefCounted
## One call to give any Control a themed tooltip. Full API in docs/tooltips.md.
##
##   Tip.bind(button, "Opens the relic screen.")
##   Tip.bind(row, {"title": "Luck", "body": "Better drops.", "hint": "Rebirth to raise it."})
##   Tip.bind(slot, func() -> Variant: return build_spec())   # re-evaluated each time it shows
##
## Minecraft-style: mouse hover shows it on the same frame, with no delay or fade, and it follows the cursor.
## Keyboard or pad focus shows it the same frame too, anchored under the control. It hides on the frame the mouse
## leaves, on click, on hide or on free. No autoload: the host is created on first use under the scene root,
## so no project.godot change is needed.

const HOST_NAME: String = "TipLayer"
const META: StringName = &"_tip_spec"
const BOUND: StringName = &"_tip_bound"
static var _host: TipHost = null
## True after a menu opens and puts focus on its first control: that focus must not pop a tooltip. TipHost clears it
## on the first keyboard or pad navigation input, after which focus tips show as usual. Mouse hover is never affected.
static var focus_muted: bool = false


## Give `c` focus without showing its tooltip (menu open). Keeps keyboard and pad navigation working.
static func grab_quiet(c: Control) -> void:
	focus_muted = true
	hide_all()
	c.grab_focus()


## Attach a tooltip. `spec` is a String (body only), a Dictionary (title, body, hint, color), or a
## Callable returning either. Calling bind again on the same control just replaces the spec.
static func bind(c: Control, spec: Variant) -> void:
	if c == null:
		return
	c.set_meta(META, spec)
	if c.has_meta(BOUND):
		return
	c.set_meta(BOUND, true)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS   # needs to see the mouse; still lets clicks through
	c.mouse_entered.connect(_on_enter.bind(c, false))
	c.focus_entered.connect(_on_enter.bind(c, true))
	c.focus_exited.connect(_on_exit.bind(c))
	c.tree_exiting.connect(_on_exit.bind(c))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(_on_exit.bind(c))
	# No mouse_exited hook: the host watches which control is under the mouse and hides after a short grace.


## Bind the same spec to a container and every Control directly inside it (a row of icon, label and value).
static func bind_all(c: Control, spec: Variant) -> void:
	bind(c, spec)
	for ch: Node in c.get_children():
		if ch is Control:
			bind(ch as Control, spec)


## Change the spec of a bound control (also refreshes it while it is showing).
static func set_spec(c: Control, spec: Variant) -> void:
	bind(c, spec)
	if _host != null and is_instance_valid(_host) and _host.target == c:
		_host.refresh()


static func unbind(c: Control) -> void:
	if c != null and c.has_meta(META):
		c.remove_meta(META)
		_on_exit(c)


## Show a tooltip for something that is not a Control (a pad in the world). `at` is in screen texels.
## Call every frame while the cursor is over it; it follows `at`. hide_free() when it leaves.
## With `exact` the panel's top-left is placed at `at` (still clamped on screen) instead of beside a cursor.
static func show_free(tree: SceneTree, spec: Variant, at: Vector2, exact: bool = false) -> void:
	var h: TipHost = host(tree)
	h.show_free(spec, at, exact)


## Show beside a rect (a slot) instead of at the cursor. It tries right, left, below, then above, and takes the
## first spot that is on screen and clear of every visible Control in the "tip_avoid" group (HUD panels).
static func show_beside(tree: SceneTree, spec: Variant, anchor: Rect2) -> void:
	var h: TipHost = host(tree)
	h.show_free(spec, anchor.position, true)
	h.set_beside(anchor)


## `tree` may be null (a tooltip owner already out of the tree); the shown host is hidden anyway.
static func hide_free(_tree: SceneTree) -> void:
	if _host != null and is_instance_valid(_host):
		_host.hide_free()


## True while the tooltip panel is on screen. Tip cards use it to step aside so the two never overlap.
static func is_showing() -> bool:
	return _host != null and is_instance_valid(_host) and _host.visible


static func hide_all() -> void:
	if _host != null and is_instance_valid(_host):
		_host.dismiss()


static func host(tree: SceneTree) -> TipHost:
	if _host != null and is_instance_valid(_host):
		return _host   # may still be waiting to enter the tree; never make a second one
	var layer := CanvasLayer.new()
	layer.name = HOST_NAME
	layer.layer = 120
	_host = TipHost.new()
	layer.add_child(_host)
	tree.root.add_child.call_deferred(layer)
	return _host


## A segment of a rich line: text in a colour, or an inline 16 px stat icon (a file name under assets/icons).
static func seg(text: String, c: Color = Color(0, 0, 0, 0)) -> Dictionary:
	return {"t": text, "c": c}


## An all-caps tag in the bold display face (rarity + type, e.g. UNCOMMON PAD).
static func tag(text: String, c: Color = Color(0, 0, 0, 0)) -> Dictionary:
	return {"t": text.to_upper(), "c": c, "tag": true}


static func icon(name: String) -> Dictionary:
	return {"icon": name}


## Turn a spec into {title, title_color, icon, body, lines, hint, hint_color, color, empty}.
## `lines` is an Array of rich lines; a line is an Array of segments (String, seg(), or icon()).
## A null or blank spec comes back with empty = true and shows nothing.
static func normalize(spec: Variant) -> Dictionary:
	if spec is Callable:
		spec = (spec as Callable).call()
	var d: Dictionary = {"title": "", "title_color": Color(0, 0, 0, 0), "icon": "", "body": "", "lines": [],
		"hint": "", "hint_color": Color(0, 0, 0, 0), "color": Color(0, 0, 0, 0)}
	if spec is Dictionary:
		for k: Variant in (spec as Dictionary):
			d[str(k)] = (spec as Dictionary)[k]
	elif spec != null:
		d["body"] = str(spec)
	d["empty"] = str(d["title"]) == "" and str(d["body"]) == "" and str(d["hint"]) == "" and (d["lines"] as Array).is_empty()
	return d


static func _on_enter(c: Control, by_focus: bool) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not c.has_meta(META):
		return
	if by_focus and focus_muted:
		return
	host(c.get_tree()).request(c, by_focus)


static func _on_exit(c: Control) -> void:
	if _host != null and is_instance_valid(_host):
		_host.on_exit(c)
