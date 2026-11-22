class_name Gate
extends Node3D
## Zone gate. Opens when the Sim latches the gate. Walking into an open gate enters the next zone.

@export var zone_id: StringName
@export var radius: float = 1.0

var is_open: bool = false


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		is_open = (gs.get("sim") as Sim).is_gate_open(zone_id)
	if bus != null:
		bus.gate_opened.connect(func(id: StringName) -> void:
			if id == zone_id:
				is_open = true)


func _physics_process(_delta: float) -> void:
	if not is_open:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var gs: Node = get_node_or_null("/root/GameState")
	if player == null or gs == null:
		return
	var p: Vector3 = player.global_position - global_position
	if Vector2(p.x, p.z).length() <= radius:
		var sim: Sim = gs.get("sim")
		var z: ZoneDef = sim.zone_defs.get(zone_id) as ZoneDef
		if z != null and z.next_zone != &"":
			gs.enter_zone(z.next_zone)
