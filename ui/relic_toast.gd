class_name RelicToast
extends PanelContainer
## Rarity-coloured pop-up when a relic drops. Shown only for Epic and above (RelicConfig.flash_min_rank).
## Add to the HUD, bind() once. The pad flash is Fx's job: on EventBus.relic_gained it should flash
## the pressed pad with RarityDef.color (see docs/relics.md).

## Above every menu panel (the HUD sits at 100) and below tip cards and modals (150), so an open Ledger never hides a toast.
const TOAST_Z: int = 130
const LIFETIME: float = 2.4

var _icon: TextureRect
var _name: Label
var _sub: Label
var _tween: Tween

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOAST_Z
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	add_child(h)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_icon)
	var v := VBoxContainer.new()
	h.add_child(v)
	_name = Label.new(); _name.theme_type_variation = &"TitleLabel"; v.add_child(_name)
	_sub = Label.new(); v.add_child(_sub)

func bind(inv: RelicInventory) -> void:
	inv.relic_gained.connect(func(id: StringName, stacks: int) -> void:
		var d: RelicDef = inv.defs[id]
		if inv.config.is_flashy(d):
			show_drop(d, stacks))

func show_drop(d: RelicDef, stacks: int) -> void:
	var c: Color = d.rarity.readable_color(RelicStyle.ink)
	add_theme_stylebox_override("panel", AsciiBox.panel(d.rarity.tint()))
	_icon.texture = d.icon
	_name.text = d.display_name
	_name.add_theme_color_override("font_color", c)
	_sub.text = "%s RELIC%s" % [d.rarity.display_name.to_upper(), "  x%d" % stacks if stacks > 1 else ""]
	_sub.add_theme_font_override("font", StatStyle.tag_font())
	_sub.add_theme_font_size_override("font_size", StatStyle.TAG_SIZE)
	_sub.add_theme_color_override("font_color", c)
	reset_size()
	visible = true
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(LIFETIME - 0.4)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func() -> void: visible = false)
