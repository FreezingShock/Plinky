class_name ButtonPad
extends Node3D
## A pressable pad. Holds only a button id. Standing on it presses at the player's press rate.
## Visuals (sink, glow, label) are driven by Fx/UI from EventBus and the read helpers below.

@export var button_id: StringName
## Pad half-extent on the ground plane, world units.
@export var radius: float = 0.9

var standing: bool = false
var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if gs == null or player == null:
		return
	var p: Vector3 = player.global_position - global_position
	var inside: bool = Vector2(p.x, p.z).length() <= radius
	if inside and not standing:
		_timer = 0.0  # first press is immediate on arrival
	standing = inside
	if not inside:
		return
	_timer -= delta
	if _timer <= 0.0:
		gs.try_press(button_id, global_position)
		_timer = (gs.get("sim") as Sim).press_interval()


func is_affordable() -> bool:
	var gs: Node = get_node_or_null("/root/GameState")
	return gs != null and gs.can_afford(button_id)


## "cost -> reward" text for the floating label, e.g. "100 Embers -> +8 Cinder".
func label_text() -> String:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return ""
	var sim: Sim = gs.get("sim")
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		return ""
	var cost_name: String = (sim.stat_defs[b.cost_stat] as StatDef).display_name
	var reward_name: String = (sim.stat_defs[b.reward_stat] as StatDef).display_name
	return "%s %s -> +%s %s" % [Formulas.button_cost(b).format(), cost_name, sim.press_gain_preview(button_id).format(), reward_name]
