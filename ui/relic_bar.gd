class_name RelicBar
extends HBoxContainer
## HUD strip: the equipped relics, icons with rarity frames. Hover for the tooltip.

var inventory: RelicInventory
func _init() -> void:
	add_theme_constant_override("separation", 2)

func bind(inv: RelicInventory) -> void:
	inventory = inv
	inv.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	Tip.hide_all()
	for id in inventory.equipped:
		var s := RelicSlot.new()
		s.setup(inventory.defs[id], inventory.stacks_of(id))
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		Tip.bind(s, func() -> Variant: return TipText.relic(s.relic, inventory.stacks_of(s.relic.id), true, ""))
		add_child(s)
