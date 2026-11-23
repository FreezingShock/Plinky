class_name ContentLoader
extends RefCounted
## Loads every .tres under content/ into a Sim. Nothing is registered by hand.


static func load_into(sim: Sim, root: String = "res://content") -> bool:
	var cfg: GameConfig = load(root.path_join("config/game.tres")) as GameConfig
	if cfg == null:
		push_error("ContentLoader: missing config/game.tres under " + root)
		return false
	sim.config = cfg
	sim.stat_defs = _collect(root.path_join("stats"), "StatDef")
	sim.button_defs = _collect(root.path_join("buttons"), "ButtonDef")
	sim.zone_defs = _collect(root.path_join("zones"), "ZoneDef")
	sim.attribute_defs = _collect(root.path_join("attributes"), "AttributeDef")
	sim.area_defs = _collect(root.path_join("areas"), "AreaDef")
	var rcfg: RelicConfig = load(root.path_join("relics/_config.tres")) as RelicConfig
	if rcfg == null:
		push_error("ContentLoader: missing relics/_config.tres")
		return false
	var rdefs: Array[RelicDef] = []
	for r: Resource in _collect(root.path_join("relics"), "RelicDef").values():
		rdefs.append(r as RelicDef)
	sim.relics = RelicInventory.new(rcfg, rdefs)
	var errors: PackedStringArray = sim.validate()
	for err in errors:
		push_error("ContentLoader: " + err)
	return errors.is_empty()


static func _collect(dir: String, kind: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	var files: PackedStringArray = d.get_files()
	files.sort()
	for f in files:
		var name: String = f.trim_suffix(".remap")  # exported builds remap .tres
		if not name.ends_with(".tres") or name.begins_with("_"):
			continue
		var res: Resource = load(dir.path_join(name))
		if res == null:
			push_error("ContentLoader: could not load " + dir.path_join(name))
			continue
		var id: StringName = res.get("id")
		if id == &"":
			push_error("ContentLoader: " + name + " has no id")
			continue
		out[id] = res
	return out
