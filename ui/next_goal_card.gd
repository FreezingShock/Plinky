class_name NextGoalCard
extends PanelContainer
## The Next Goal ribbon, bottom right, just left of the Menu chip: the first mid-game goal not yet reached, as one slim
## line (its name, the press bonus it pays) with a progress line along the bottom. Hover shows the description and the
## progress. Hud places it and hides it once every goal is reached (Hud._sync_goal_card). Read only: it shows Sim.goals.
## Shown from the first Dewdrops unlock, like the stat strip, so a new player is not handed a second list.

const WIDTH: float = 132.0
const BAR_H: float = 2.0
const REFRESH: float = 0.25
const REACHED_TITLE: String = "All Goals Reached"

var sim: Sim
var _name: Label
var _reward: Label
var _bar: NextGoalBar
var _clock: float = 0.0


func _init() -> void:
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 5.0, 2.0))
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	_name = Label.new()
	_name.add_theme_color_override("font_color", RelicStyle.accent)
	_name.clip_text = true
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.custom_minimum_size = Vector2(0.0, 0.0)
	row.add_child(_name)
	_reward = Label.new()
	_reward.add_theme_color_override("font_color", RelicStyle.good)
	row.add_child(_reward)
	_bar = NextGoalBar.new()
	_bar.custom_minimum_size = Vector2(WIDTH - 12.0, BAR_H)
	v.add_child(_bar)
	Tip.bind(self, func() -> Variant: return _tip())


func bind(p_sim: Sim) -> void:
	sim = p_sim
	refresh()


func _process(delta: float) -> void:
	if sim == null or not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= REFRESH:
		_clock = 0.0
		refresh()


func refresh() -> void:
	if sim == null:
		return
	var v: Dictionary = view_for(sim.goals, sim.achievement_counters())
	_name.text = str(v["name"])
	_reward.text = "+%d%%" % roundi(float(v["reward_pct"]))
	_bar.progress = float(v["progress"])
	_bar.queue_redraw()


func _tip() -> Variant:
	if sim == null:
		return ""
	var v: Dictionary = view_for(sim.goals, sim.achievement_counters())
	if bool(v["done"]):
		return {"title": REACHED_TITLE, "body": "Every goal is reached. Each one added its press bonus for good.",
			"hint": "Total press bonus: +%d%%." % roundi(float(v["bonus"]) * 100.0)}
	return {"title": str(v["name"]), "body": str(v["description"]),
		"hint": "Progress %s. Total press bonus +%d%%." % [str(v["progress_text"]), roundi(float(v["bonus"]) * 100.0)]}


## Pure: whether the card has a goal to show. False once every goal is reached, and then Hud hides the card for good.
static func shown_for(goals: Goals) -> bool:
	return goals.next_goal() != null


## Pure: what the card shows. Keys: done, name, description, progress 0..1, progress_text ("3 / 10"), detail (progress
## plus the reward, as one line), reward_pct (this goal's own bonus in percent), bonus (sum of reached rewards), and reward.
static func view_for(goals: Goals, counters: Dictionary) -> Dictionary:
	var bonus: float = goals.mult() - 1.0
	var d: GoalDef = goals.next_goal()
	if d == null:
		return {"done": true, "name": REACHED_TITLE, "description": "", "progress": 1.0, "progress_text": "",
			"detail": "%d of %d reached" % [goals.reached_count(), goals.total()], "bonus": bonus, "reward": 0.0, "reward_pct": 0.0}
	var value: float = Goals.value_of(d, counters)
	var progress_text: String = LedgerPanel.progress_text(value, d.target)
	return {"done": false, "name": d.display_name, "description": d.description,
		"progress": goals.progress(d, counters), "progress_text": progress_text,
		"detail": "%s  +%d%%" % [progress_text, roundi(d.reward * 100.0)],
		"bonus": bonus, "reward": d.reward, "reward_pct": d.reward * 100.0}


## Pure: the banner for a goal just reached. Lines name the goal and its bonus.
static func announcement(d: GoalDef) -> Dictionary:
	return {"key": "goal_%s" % d.id, "title": "Goal Reached", "lines": [d.display_name, "+%d%% to every press" % roundi(d.reward * 100.0)],
		"color": RelicStyle.accent, "duration": 2.6}


## A goal was just reached: refresh the card and return the banner spec for Hud to show (empty if unknown).
## Banner is an autoload, so the card never names it.
func goal_reached(id: StringName) -> Dictionary:
	refresh()
	if sim == null:
		return {}
	var d: GoalDef = sim.goals.defs.get(id) as GoalDef
	return announcement(d) if d != null else {}


## The progress track: a dim line with a bright fill. Drawn here, so it is one node with no textures.
class NextGoalBar extends Control:
	var progress: float = 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), RelicStyle.dim.darkened(0.5))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(progress, 0.0, 1.0), size.y)), RelicStyle.good)
