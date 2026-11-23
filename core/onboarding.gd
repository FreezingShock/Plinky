class_name Onboarding
extends RefCounted
## The first ten minutes: which HUD systems are visible yet, and which tip to show next.
## Pure logic over a Sim, no nodes. Unlocks and seen tips are kept in sim.ui_flags, so they save with the game.
## Thresholds are in content/config/onboarding.tres. Pacing notes are in docs/onboarding.md.

signal feature_unlocked(feature: StringName)
## Fires once per save, when the onboarding gate opens: the tutorial is done and the way on is open.
signal completed

const F_DEWDROP: StringName = &"dewdrop"                ## Dewdrops row, the Pads list, the clock and the stat menus
const F_CLOVER_ROW: StringName = &"clover_row"          ## Clover Leaves row and the gate panel
const F_REBIRTH_BUTTON: StringName = &"rebirth_button"  ## the Rebirth action in the bottom bar
const F_UPGRADES: StringName = &"upgrades"              ## Prestige row and the Upgrades button
const F_RELICS: StringName = &"relics"                  ## Relics button and the equipped bar
const FEATURES: Array[StringName] = [F_DEWDROP, F_CLOVER_ROW, F_REBIRTH_BUTTON, F_UPGRADES, F_RELICS]

## Tips in priority order. urgent tips answer something that just happened, so they skip the normal gap.
const TIPS: Array[Dictionary] = [
	{"id": &"welcome", "title": "Welcome", "urgent": false},
	{"id": &"first_press", "title": "Dewdrops", "urgent": true},
	{"id": &"critter", "title": "Golden critter", "urgent": true},
	{"id": &"gate_open", "title": "Gate open", "urgent": true},
	{"id": &"rebirth_button", "title": "Rebirth", "urgent": true},
	{"id": &"bloom", "title": "Bloom", "urgent": true},
	{"id": &"upgrades", "title": "Upgrades", "urgent": true},
	{"id": &"relic", "title": "Relic found", "urgent": true},
	{"id": &"clover_row", "title": "Clover pads", "urgent": false},
	{"id": &"walk", "title": "Momentum", "urgent": false},
	{"id": &"streak", "title": "Streaks", "urgent": false},
]

## Play time above which a save with no ui_flags counts as one from before onboarding.
const OLD_SAVE_SECONDS: float = 20.0

var sim: Sim
var cfg: OnboardingConfig
## Off means no tips and every system visible (the "skip tutorial" state).
var tips_enabled: bool = true
var _last_tip_at: float = -1000.0  # sim.play_seconds when the last tip was shown


func _init(p_sim: Sim, p_cfg: OnboardingConfig = null) -> void:
	sim = p_sim
	cfg = p_cfg if p_cfg != null else OnboardingConfig.new()


## Load the pacing resource, or the defaults when it is missing.
static func load_config(path: String = "res://content/config/onboarding.tres") -> OnboardingConfig:
	var res: OnboardingConfig = load(path) as OnboardingConfig
	return res if res != null else OnboardingConfig.new()


# ---------------------------------------------------------------- unlocks

func _bag(key: String) -> Dictionary:
	var d: Variant = sim.ui_flags.get(key)
	if d is Dictionary:
		return d
	var fresh: Dictionary = {}
	sim.ui_flags[key] = fresh
	return fresh


func _latched(feature: StringName) -> bool:
	return _bag("unlocked").has(String(feature))


## Whether the HUD should show this system. Everything shows when tips are off.
func is_unlocked(feature: StringName) -> bool:
	return not tips_enabled or _latched(feature)


func _condition(feature: StringName) -> bool:
	var rebirthed: bool = sim.rebirth_count >= 1
	match feature:
		F_DEWDROP:
			return sim.press_count >= 1 or rebirthed
		F_CLOVER_ROW:
			return rebirthed or sim.can_rebirth() or sim.get_stat(&"dewdrop").to_float() >= cfg.clover_reveal_dewdrops
		F_REBIRTH_BUTTON:
			return rebirthed or sim.can_rebirth()
		F_UPGRADES:
			return rebirthed or not sim.prestige_available().is_zero() or sim.bloom_count >= 1 or sim.can_bloom()
		F_RELICS:
			return sim.relic_drops >= 1 or not sim.relics.owned.is_empty()
	return false


## True once the onboarding gate has opened. Latched in the save.
func is_complete() -> bool:
	return bool(sim.ui_flags.get("complete", false))


## Latch any system whose condition now holds. Cheap; call a few times a second.
func update() -> void:
	if not is_complete() and not sim.gates_open.is_empty():
		sim.ui_flags["complete"] = true
		completed.emit()
	if not sim.ui_flags.has("seen"):
		# A save from before onboarding: the player knows the game, so no tips for them. A new game that
		# pressed a pad before its first update has only seconds of play, so it still gets its tips.
		if (sim.press_count > 0 or sim.rebirth_count > 0) and sim.play_seconds >= OLD_SAVE_SECONDS:
			for t: Dictionary in TIPS:
				_bag("seen")[String(t["id"])] = true
		_bag("seen")
	var unlocked: Dictionary = _bag("unlocked")
	for f: StringName in FEATURES:
		if not unlocked.has(String(f)) and _condition(f):
			unlocked[String(f)] = true
			feature_unlocked.emit(f)


# ---------------------------------------------------------------- tips

func is_seen(tip: StringName) -> bool:
	return _bag("seen").has(String(tip))


## Call when a tip card goes up. It is not offered again.
func tip_shown(tip: StringName) -> void:
	_bag("seen")[String(tip)] = true
	_last_tip_at = sim.play_seconds


## Forget which tips were seen, so they all play again. Unlocked systems stay unlocked.
func replay_tips() -> void:
	sim.ui_flags["seen"] = {}
	_last_tip_at = -1000.0
	tips_enabled = true


func _tip_ready(tip: StringName) -> bool:
	match tip:
		&"welcome":
			return sim.press_count == 0 and sim.rebirth_count == 0
		&"first_press":
			return _latched(F_DEWDROP)
		&"walk":
			return sim.press_count >= 1 and sim.play_seconds >= cfg.walk_tip_seconds
		&"streak":
			return sim.press_count >= cfg.streak_tip_presses
		&"clover_row":
			return _latched(F_CLOVER_ROW)
		&"relic":
			return _latched(F_RELICS)
		&"critter":
			return sim.critter_active and sim.press_count >= 1
		&"rebirth_button":
			return _latched(F_REBIRTH_BUTTON) and sim.rebirth_here()   # the meadow runs on Bloom; this tip waits for Zone 2
		&"gate_open":
			var z: ZoneDef = sim.current_zone()
			return z != null and z.next_zone != &"" and sim.is_gate_open(z.id)
		&"bloom":
			return sim.can_bloom()
		&"upgrades":
			return _latched(F_UPGRADES) and sim.rebirth_here()
	return false


## The tip to show now, or &"" for none. Does not mark it shown; call tip_shown() when the card goes up.
func next_tip() -> StringName:
	if not tips_enabled:
		return &""
	var since: float = sim.play_seconds - _last_tip_at
	for t: Dictionary in TIPS:
		var id: StringName = t["id"]
		if is_seen(id) or not _tip_ready(id):
			continue
		if bool(t["urgent"]):
			if since < cfg.urgent_gap_seconds:
				continue
		elif sim.play_seconds < cfg.first_tip_delay or since < cfg.tip_gap_seconds:
			continue
		return id
	return &""


func is_urgent(tip: StringName) -> bool:
	for t: Dictionary in TIPS:
		if t["id"] == tip:
			return bool(t["urgent"])
	return false


func tip_title(tip: StringName) -> String:
	for t: Dictionary in TIPS:
		if t["id"] == tip:
			return String(t["title"])
	return ""


func tip_text(tip: StringName) -> String:
	var z: ZoneDef = sim.current_zone()
	match tip:
		&"welcome":
			var p1: ButtonDef = sim.button_defs.get(&"sprout_1") as ButtonDef
			var cost: String = Formulas.button_cost(p1).format() if p1 != null else "some"
			return "Click the ground to walk. Stand on a pad, or hold click on it, to press it. You have %s Sunlight, enough for Sprout 1. Try it." % cost
		&"first_press":
			return "Dewdrops make your Sunlight flow faster, and Sunlight also trickles in on its own. The Pads list shows each cost. A * means you can buy it now."
		&"walk":
			return "Walking charges momentum, up to +%d%% income while you keep moving. Standing still lets it drain." % int(roundf(sim.config.momentum_max_bonus * 100.0))
		&"streak":
			return "Streak bonus: press a row's pads in order, 1 then 2 then 3, each within %d seconds of the last." % int(sim.config.streak_window)
		&"clover_row":
			var need: int = int(z.gate_threshold) if z != null else 0
			return "Clover pads cost Dewdrops and pay Clover Leaves. Collect %d Clover Leaves to open the gate to the next zone." % need
		&"relic":
			return "A relic dropped! Open Relics [R] to equip it. Equipped relics boost your run."
		&"critter":
			return "A golden critter! Click it before it leaves for a big Cash payout."
		&"rebirth_button":
			var src: StatDef = sim.stat_defs.get(sim.prestige_source()) as StatDef
			var src_name: String = src.display_name if src != null else "stats"
			var resets: String = "Cash, Multiplier and the forge pads" if sim.zone_id == &"zone2" else "Sunlight, flowers and pads"
			return "You can Rebirth now. It resets your %s and banks your %s as Prestige, a permanent income boost. An open gate stays open. Pushing past %d %s pays more." % [resets, src_name, int(sim.config.prestige_push_threshold), src_name]
		&"gate_open":
			var nz: ZoneDef = sim.zone_defs.get(z.next_zone) as ZoneDef if z != null else null
			return "The gate is open. Walk to it to enter %s." % (nz.display_name if nz != null else "the next zone")
		&"bloom":
			return "The meadow can Bloom now. It resets your flowers and pays Seeds, and every pad pays %d%% more for good. Spend Seeds on Bloom gifts in Upgrades [Tab]. Open gates stay open." % int(roundf(sim.config.bloom_reward_per_bloom * 100.0))
		&"upgrades":
			return "Prestige is yours to spend. Open Upgrades [Tab] for permanent boosts."
	return ""
