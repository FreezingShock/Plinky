class_name RelicSlot
extends Control
## One 20x20 relic cell: rarity frame, icon, stack count. Used for equip slots and inventory cells.
## States: relic set (filled), relic null and not locked (empty equip slot), locked (future slot).

signal hovered(slot: RelicSlot)
signal unhovered(slot: RelicSlot)
signal pressed(slot: RelicSlot)

const SIZE: int = 20

var relic: RelicDef
var stacks: int = 0
var equipped_mark: bool = false   ## small pip: this relic is in an equip slot
var locked_text: String = ""      ## non-empty means locked; shown in tooltip
var highlight: bool = false       ## swap target pulse

var _hover: bool = false
var _pop_t: float = -1.0          ## seconds since pop(); negative = idle

func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw(); hovered.emit(self))
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw(); unhovered.emit(self))
	focus_entered.connect(func() -> void: hovered.emit(self))
	focus_exited.connect(func() -> void: unhovered.emit(self))

func setup(p_relic: RelicDef, p_stacks: int = 0, p_equipped: bool = false) -> void:
	relic = p_relic; stacks = p_stacks; equipped_mark = p_equipped
	queue_redraw()

func set_highlight(on: bool) -> void:
	highlight = on
	queue_redraw()

## A relic just landed here (equipped or swapped in): a hop with overshoot and a ring that widens in whole pixels.
func pop() -> void:
	if FxConfig.reduce_shake or relic == null:
		return
	_pop_t = 0.0
	queue_redraw()


func _process(d: float) -> void:
	if has_focus():
		queue_redraw()   # marching dots
	if _pop_t >= 0.0:
		_pop_t += d
		if _pop_t >= FxConfig.RELIC_POP_TIME:
			_pop_t = -1.0
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
	elif e.is_action_pressed("ui_accept"):
		pressed.emit(self)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	if relic == null:
		# Empty or locked: ink box with a dashed edge.
		draw_rect(r, RelicStyle.ink)
		var c: Color = RelicStyle.edge if locked_text == "" else RelicStyle.dim
		for x in range(1, SIZE - 1, 2):
			draw_rect(Rect2(x, 0, 1, 1), c); draw_rect(Rect2(x, SIZE - 1, 1, 1), c)
		for y in range(1, SIZE - 1, 2):
			draw_rect(Rect2(0, y, 1, 1), c); draw_rect(Rect2(SIZE - 1, y, 1, 1), c)
		if locked_text != "":
			# 5x6 padlock
			var o := Vector2(7, 6)
			draw_rect(Rect2(o + Vector2(1, 0), Vector2(3, 1)), c)
			draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, 2)), c)
			draw_rect(Rect2(o + Vector2(4, 1), Vector2(1, 2)), c)
			draw_rect(Rect2(o + Vector2(0, 3), Vector2(5, 4)), c)
		else:
			draw_rect(Rect2(9, 6, 2, 8), c); draw_rect(Rect2(6, 9, 8, 2), c)
	else:
		var hop := Vector2.ZERO
		if _pop_t >= 0.0:
			var k: int = clampi(int(_pop_t / FxConfig.RELIC_POP_TIME * FxConfig.RELIC_HOP.size()), 0, FxConfig.RELIC_HOP.size() - 1)
			hop = Vector2(0, -FxConfig.RELIC_HOP[k])
			# Ring in the rarity colour, one pixel wider each step; lighter under Reduce flashing.
			var grow: int = 1 + int(_pop_t / FxConfig.RELIC_POP_TIME * 4.0)
			if not FxConfig.reduce_flashing:
				var ring: Color = RelicStyle.text
				ring.a = 1.0 - _pop_t / FxConfig.RELIC_POP_TIME
				PadInput.draw_focus_ring(self, r.grow(grow), ring)
		draw_texture(relic.rarity.frame, hop)
		draw_texture(relic.icon, hop + Vector2(2, 2))
		if stacks > 1:
			var s: String = "x%d" % stacks if stacks < 100 else "99+"
			var f: Font = get_theme_default_font()
			var fs: int = 8
			var sz: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var pos := Vector2(SIZE - sz.x - 1, SIZE - 2)
			draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, RelicStyle.ink)
			draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RelicStyle.text)
		if equipped_mark:
			draw_rect(Rect2(0, 0, 5, 5), RelicStyle.ink)
			draw_rect(Rect2(1, 1, 3, 3), RelicStyle.accent)
	if highlight:
		draw_rect(r.grow(1), RelicStyle.accent, false)
	if has_focus():
		PadInput.draw_focus_ring(self, r.grow(2), RelicStyle.accent)
	elif _hover:
		draw_rect(r.grow(2), RelicStyle.accent, false)
