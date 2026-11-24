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
## Gift effects that bend the reset itself. keep_effect: how many of the stats in `resets` (after the start stat, in listed
## order) survive a use. pay_effect: +x payout (0.5 = +50%). bonus_effect: added to bonus_per_use for every use.
@export var keep_effect: StringName = &""
@export var pay_effect: StringName = &""
@export var bonus_effect: StringName = &""
## The capstone gift of this reset's tree (an AttributeDef effect id, "" for none). Its total is added to 1.0 to
## multiply every press on the zones this reset lists, so one level doubles them. No other zone's pads pay more.
@export var crown_effect: StringName = &""
## Menu skin: the heading of its section in Upgrades, and the words on its button, tooltip, confirm card and tutorial tip.
## Animation skin (ui/fx/bloom_ritual.gd): the stats whose colours the burst particles use (the zone's ladder), the characters
## of the closing ring of marks, and whether the particles rise like sparks (true) or fall like petals (false).
@export var fx_stats: PackedStringArray = PackedStringArray()
@export var fx_marks: String = ".o*O"
@export var fx_rise: bool = false
@export var menu_title: String = ""
## Plural of display_name in tier headings ("Unlocks After 2 Nuclei"). "" adds an "s".
@export var plural_name: String = ""
## The currency's own tooltip (its HUD row and Upgrades badge): what it is and how it is earned, and what it buys.
@export_multiline var currency_body: String = ""
## One short line over this reset's gifts page in Upgrades: what earns the currency.
@export var gift_blurb: String = ""
@export var button_hint: String = ""
@export_multiline var tip_body: String = ""
@export var resets_text: String = ""
@export var keeps_text: String = ""
@export_multiline var teach_text: String = ""
