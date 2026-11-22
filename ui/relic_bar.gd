class_name RelicBar
extends HBoxContainer
## HUD strip: the equipped relics, icons with rarity frames. Hover for the tooltip.

var inventory: RelicInventory
var _tip: RelicTooltip

func _init() -> void:
	add_theme_constant_override("separation", 2)
	_tip = RelicTooltip.new()

func _ready() -> void:
	add_child(_tip)
	_tip.top_level = true

func bind(inv: RelicInventory) -> void:
	inventory = inv
	inv.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for c in get_children():
		if c != _tip:
			remove_child(c)
			c.queue_free()
	_tip.hide_tip()
	for id in inventory.equipped:
		var s := RelicSlot.new()
		s.setup(inventory.defs[id], inventory.stacks_of(id))
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		s.hovered.connect(func(sl: RelicSlot) -> void:
			_tip.show_relic(sl.relic, inventory.stacks_of(sl.relic.id), true, "", Rect2(sl.global_position, sl.size)))
		s.unhovered.connect(func(_sl: RelicSlot) -> void: _tip.hide_tip())
		add_child(s)
