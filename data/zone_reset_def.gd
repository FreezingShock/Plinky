class_name ZoneResetDef
extends Resource
## A zone's own reset: its "rebirth", with its own currency and its own themed upgrade menu. STANDING RULE (docs/decisions.md):
## every zone gets one. A new zone adds a file under content/resets/, a currency stat, an icon (assets/icons/<currency>.png,
## 8, 16, 24 and 32 px), a colour in StatStyle.COLORS and its gift attributes (AttributeDef.currency = this currency). No script change.
## Files: content/resets/*.tres. The meadow's is Bloom (Seeds).

@export var id: StringName
@export var display_name: String
## Where this reset is the zone's reset: its button shows there, and its menu section opens once it has been used.
@export var zones: PackedStringArray = PackedStringArray()
## Menu order among resets (lower first).
@export var order: int = 0
## The currency stat it pays and the gifts are bought with.
@export var currency: StringName
## The stat the payout is measured on, and the zone whose gate opens the reset. The payout reference is that gate's own
## threshold (so the reset follows the gate when it moves); `ref_fallback` is used when the zone has no threshold.
@export var source_stat: StringName
@export var gate_zone: StringName
@export var ref_fallback: float = 100.0
## Payout = floor(pay_scale * sqrt(source / ref)), and nothing below min_pay.
@export var pay_scale: float = 2.0
@export var min_pay: float = 2.0
## Each use lowers the next payout reference to ref x ref_shrink_per_use ^ uses (never below ref_floor of it), so later
## uses come sooner. 1.0 keeps it fixed.
@export var ref_shrink_per_use: float = 1.0
@export var ref_floor: float = 0.3
## Every use adds this to every pad's reward for good (0.05 = +5%).
@export var bonus_per_use: float = 0.05
## Stat ids a use resets to their start. Everything else (gates, tiers, relics, mastery, other currencies) stays.
@export var resets: PackedStringArray = PackedStringArray()
## After a reset this stat starts at its start value plus the total of this gift effect ("" for none).
@export var start_stat: StringName = &""
@export var start_effect: StringName = &""
## Menu skin: the heading of its section in Upgrades, and the words on its button, tooltip, confirm card and tutorial tip.
@export var menu_title: String = ""
@export var button_hint: String = ""
@export_multiline var tip_body: String = ""
@export var resets_text: String = ""
@export var keeps_text: String = ""
@export_multiline var teach_text: String = ""
