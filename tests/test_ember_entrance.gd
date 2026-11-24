extends RefCounted
## The Ember Quarry cave entrance (assets/art/zone1b/larkmoor/entrance/entrance.json): every file exists, the walk lane
## through the gate stays clear of decor, and the neon sign is data the glow node can read.

const DIR: String = "res://assets/art/zone1b/larkmoor/"
const LANE_LEFT: float = 1510.0    # the walk lane through the gate (texels); lantern heads may overhang the sand path edge
const LANE_RIGHT: float = 1534.0
const GATE_Y: float = 534.0


func run(t: Object) -> void:
	var path: String = DIR + "entrance/entrance.json"
	t.ok(FileAccess.file_exists(path), "entrance.json exists")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var sprites: Array = data.get("sprites", []) as Array
	t.ok(sprites.size() >= 12, "the entrance has a cave, rails, dirt, lanterns and several decor sprites")
	var kinds: Dictionary = {}
	for s: Dictionary in sprites:
		kinds[String(s.kind)] = true
		t.ok(ResourceLoader.exists(DIR + String(s.file)), "%s exists" % s.file)
		if String(s.kind) == "ember_prop" or String(s.kind) == "lantern":
			# decor and lanterns stand beside the lane, never in it (the gateway at y 534 is the walk-in point)
			var x0: float = float(s.x)
			var x1: float = x0 + float(s.w)
			var foot_y: float = float(s.foot[1])
			if foot_y > 520.0 and foot_y < GATE_Y + 60.0:
				t.ok(x1 < LANE_LEFT or x0 > LANE_RIGHT, "%s keeps off the walk lane" % s.file)
	t.ok(kinds.has("ember_flat") and kinds.has("ember_prop") and kinds.has("lantern"), "flat, prop and lantern kinds are all present")
	var sign: Dictionary = data.get("sign", {}) as Dictionary
	t.ok(ResourceLoader.exists(DIR + String(sign.get("on", ""))), "the lit sign texture exists")
	t.ok(ResourceLoader.exists(DIR + String(sign.get("dim", ""))), "the dim sign texture (flicker frame) exists")
	t.ok((data.get("glints", []) as Array).size() >= 8, "there are ember glints")
