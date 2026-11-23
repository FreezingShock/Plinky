class_name DevCommands
extends RefCounted
## Admin and dev commands for the console (ui/dev_console.gd). Pure logic over a Sim: no nodes, no autoloads,
## so tests can drive it. Node-level commands (teleport, speed, ...) are added by the console with register().
##   var cmds := DevCommands.new(sim)
##   print(cmds.run("give cash 1e12"))
## run() always returns a one-or-more line reply and never throws on bad input.

const MAX_SKIP_SECONDS: float = 7.0 * 86400.0

var sim: Sim
## Set by commands that replace the whole save. The console reloads the scene when it sees this.
var needs_reload: bool = false
var _extra: Dictionary = {}   # name -> {"fn": Callable(PackedStringArray) -> String, "help": String}


func _init(p_sim: Sim) -> void:
	sim = p_sim


## Add a command from outside core. fn takes the arguments (PackedStringArray) and returns the reply text.
func register(cmd_name: String, help: String, fn: Callable) -> void:
	_extra[cmd_name] = {"fn": fn, "help": help}


func help_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([
		"give <stat> <amount>      add to a stat (1e12, 5k, 2.5M all work)",
		"set <stat> <amount>       set a stat",
		"stats                     list every stat",
		"prestige <amount>         set the prestige stat",
		"rebirths <n>              set the rebirth count (unlocks relic slots)",
		"rebirth                   do a rebirth now if allowed",
		"relic <id> [stacks]       give a relic; 'relic all' or 'relic rarity <tier>' gives a set",
		"relics                    list relics and rarities",
		"zone <id>                 jump to a zone (opens the gate that leads there)",
		"attr <id> <level>         set an upgrade level",
		"skip <time>               fast forward income (90s, 15m, 3h, 2d)",
		"season [name|0-3]         show the calendar, or jump to the start of a season (spring, summer, autumn, winter)",
		"day <n>                   advance the calendar by n in-game days",
		"tiers [id]                open every flower tier, or just the one named",
		"god [on|off]              presses cost nothing",
		"reset confirm             wipe the save and restart",
	])
	for k: String in _extra:
		out.append("%-26s%s" % [k, String((_extra[k] as Dictionary)["help"])])
	return out


func run(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1)
	if _extra.has(cmd):
		return String(((_extra[cmd] as Dictionary)["fn"] as Callable).call(args))
	match cmd:
		"help", "?":
			return "\n".join(help_lines())
		"stats":
			return _stats()
		"give":
			return _give(args, true)
		"set":
			return _give(args, false)
		"prestige":
			return _prestige(args)
		"rebirths":
			return _rebirths(args)
		"rebirth":
			return "Rebirth done." if sim.try_rebirth() else "Not enough yet to rebirth."
		"relic":
			return _relic(args)
		"relics":
			return _relics()
		"zone":
			return _zone(args)
		"attr":
			return _attr(args)
		"skip":
			return _skip(args)
		"season":
			return _season(args)
		"day":
			return _day(args)
		"tiers":
			return _tiers(args)
		"god":
			return _god(args)
		"reset":
			return _reset(args)
	return "Unknown command '%s'. Type help." % cmd


func _season(args: PackedStringArray) -> String:
	var cal: GameCalendar = sim.calendar
	if args.is_empty():
		var n: Dictionary = cal.now()
		return "Year %d, %s (%s), %s %d, %s" % [n["year"], n["season_name"], n["season_id"], n["month_name"], n["day"], n["clock_text"]]
	var want: String = args[0].to_lower()
	var idx: int = -1
	for i in GameCalendar.SEASONS:
		if want == String(cal.config.season_ids[i]).to_lower() or want == cal.season_name(i).to_lower() or want == str(i):
			idx = i
	if idx < 0:
		return "Unknown season '%s'. Try spring, summer, autumn or winter." % args[0]
	cal.jump_to_season(idx)
	return "Jumped to %s, %s." % [cal.season_name(idx), cal.now()["clock_text"]]


func _day(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_float() or args[0].to_float() <= 0.0:
		return "Usage: day <n>  (in-game days, e.g. 2 or 0.5)"
	sim.calendar.skip_days(minf(args[0].to_float(), 400.0))
	var n: Dictionary = sim.calendar.now()
	return "Now %s, %s %d, %s." % [n["season_name"], n["month_name"], n["day"], n["clock_text"]]


# ---------------------------------------------------------------- parsing

## "1e12", "2.5e300", "5k", "3.2M", "750". Returns null when the text is not a number.
static func parse_amount(text: String) -> Variant:
	var t: String = text.strip_edges()
	if t.is_empty():
		return null
	var low: String = t.to_lower()
	var e_at: int = low.find("e")
	if e_at > 0 and low.substr(0, e_at).is_valid_float() and low.substr(e_at + 1).is_valid_int():
		return BigNum.make(low.substr(0, e_at).to_float(), low.substr(e_at + 1).to_int())
	if low.is_valid_float():
		return BigNum.from_float(low.to_float())
	# Suffix form: the longest trailing letters are looked up against the formatter's names.
	var i: int = low.length()
	while i > 0 and not "0123456789.".contains(low[i - 1]):
		i -= 1
	var head: String = low.substr(0, i)
	var tail: String = low.substr(i)
	if head.is_valid_float() and not tail.is_empty():
		for g in range(1, 200):
			if NumberFormat.suffix_for(g).to_lower() == tail:
				return BigNum.make(head.to_float(), g * 3)
	return null


## "90", "90s", "15m", "3h", "2d" -> seconds. -1 when unreadable.
static func parse_duration(text: String) -> float:
	var t: String = text.strip_edges().to_lower()
	if t.is_empty():
		return -1.0
	var unit: float = 1.0
	match t[t.length() - 1]:
		"s":
			t = t.left(-1)
		"m":
			unit = 60.0
			t = t.left(-1)
		"h":
			unit = 3600.0
			t = t.left(-1)
		"d":
			unit = 86400.0
			t = t.left(-1)
	return t.to_float() * unit if t.is_valid_float() else -1.0


# ---------------------------------------------------------------- commands

func _stat_id(word: String) -> StringName:
	var id := StringName(word.to_lower())
	return id if sim.stat_defs.has(id) else &""


func _stats() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for id: StringName in sim.stat_defs:
		lines.append("%s = %s" % [id, sim.get_stat(id).format()])
	return "\n".join(lines)


func _give(args: PackedStringArray, add: bool) -> String:
	if args.size() < 2:
		return "Usage: %s <stat> <amount>. Stats: %s" % ["give" if add else "set", ", ".join(_stat_names())]
	var id: StringName = _stat_id(args[0])
	if id == &"":
		return "No stat '%s'. Stats: %s" % [args[0], ", ".join(_stat_names())]
	var amt: Variant = parse_amount(args[1])
	if amt == null:
		return "'%s' is not a number." % args[1]
	var v: BigNum = (amt as BigNum)
	if add:
		v = sim.get_stat(id).add(v)
	sim.dev_set_stat(id, v)
	return "%s = %s" % [id, sim.get_stat(id).format()]


func _stat_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: StringName in sim.stat_defs:
		out.append(String(id))
	return out


func _prestige(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: prestige <amount>"
	return _give(PackedStringArray([String(sim.config.prestige_stat), args[0]]), false)


func _rebirths(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int() or args[0].to_int() < 0:
		return "Usage: rebirths <n>"
	sim.rebirth_count = args[0].to_int()
	sim.relics.set_rebirths(sim.rebirth_count)
	return "Rebirths = %d, relic slots = %d" % [sim.rebirth_count, sim.relics.slot_count()]


func _relics() -> String:
	var rows: Array[RelicDef] = []
	for d: RelicDef in sim.relics.defs.values():
		rows.append(d)
	rows.sort_custom(func(a: RelicDef, b: RelicDef) -> bool: return a.rarity.rank < b.rarity.rank or (a.rarity.rank == b.rarity.rank and String(a.id) < String(b.id)))
	var lines: PackedStringArray = PackedStringArray()
	for d in rows:
		lines.append("%s  [%s]  owned %d" % [d.id, d.rarity.id, sim.relics.stacks_of(d.id)])
	return "\n".join(lines)


func _relic(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: relic <id> [stacks] | relic all [stacks] | relic rarity <tier> [stacks]"
	var ids: Array[StringName] = []
	var n: int = 1
	if args[0].to_lower() == "rarity":
		if args.size() < 2:
			return "Usage: relic rarity <tier> [stacks]"
		var tier := StringName(args[1].to_lower())
		for d: RelicDef in sim.relics.defs.values():
			if d.rarity.id == tier:
				ids.append(d.id)
		if ids.is_empty():
			return "No relics of rarity '%s'." % args[1]
		if args.size() > 2 and args[2].is_valid_int():
			n = args[2].to_int()
	elif args[0].to_lower() == "all":
		for id: StringName in sim.relics.defs:
			ids.append(id)
		if args.size() > 1 and args[1].is_valid_int():
			n = args[1].to_int()
	else:
		var id := StringName(args[0].to_lower())
		if not sim.relics.defs.has(id):
			return "No relic '%s'. Type relics for the list." % args[0]
		ids.append(id)
		if args.size() > 1 and args[1].is_valid_int():
			n = args[1].to_int()
	n = clampi(n, 1, 999)
	for id in ids:
		sim.relics.add_relic(id, n)
	return "Gave %d stack(s) each of %d relic(s)." % [n, ids.size()]


func _zone(args: PackedStringArray) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for id: StringName in sim.zone_defs:
		ids.append(String(id))
	if args.is_empty():
		return "Usage: zone <id>. Zones: %s (now in %s)" % [", ".join(ids), sim.zone_id]
	if not sim.zone_defs.has(StringName(args[0].to_lower())):
		return "No zone '%s'. Zones: %s" % [args[0], ", ".join(ids)]
	sim.dev_force_zone(StringName(args[0].to_lower()))
	return "In zone %s." % sim.zone_id


func _tiers(args: PackedStringArray) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for id: StringName in sim.tier_defs:
		ids.append(String(id))
	if not args.is_empty() and not sim.tier_defs.has(StringName(args[0].to_lower())):
		return "No tier '%s'. Tiers: %s" % [args[0], ", ".join(ids)]
	sim.dev_open_tiers(StringName(args[0].to_lower()) if not args.is_empty() else &"")
	return "Opened %s." % (args[0].to_lower() if not args.is_empty() else "every tier")


func _attr(args: PackedStringArray) -> String:
	if args.size() < 2 or not args[1].is_valid_int():
		return "Usage: attr <id> <level>. Upgrades: %s" % ", ".join(_attr_names())
	var id := StringName(args[0].to_lower())
	var a: AttributeDef = sim.attribute_defs.get(id) as AttributeDef
	if a == null:
		return "No upgrade '%s'. Upgrades: %s" % [args[0], ", ".join(_attr_names())]
	sim.attr_levels[id] = clampi(args[1].to_int(), 0, a.cap)
	sim.attribute_bought.emit(id, sim.attr_level(id))
	return "%s level %d of %d." % [id, sim.attr_level(id), a.cap]


func _attr_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: StringName in sim.attribute_defs:
		out.append(String(id))
	return out


func _skip(args: PackedStringArray) -> String:
	var secs: float = parse_duration(args[0]) if not args.is_empty() else -1.0
	if secs <= 0.0:
		return "Usage: skip <time>, like 90s, 15m, 3h, 2d."
	secs = minf(secs, MAX_SKIP_SECONDS)
	var chunk: float = maxf(1.0, secs / 3000.0)
	var left: float = secs
	while left > 0.0:
		var dt: float = minf(chunk, left)
		sim.step(dt)
		left -= dt
	return "Skipped %s." % _span(secs)


static func _span(secs: float) -> String:
	if secs >= 86400.0:
		return "%.1f days" % (secs / 86400.0)
	if secs >= 3600.0:
		return "%.1f hours" % (secs / 3600.0)
	if secs >= 60.0:
		return "%.1f minutes" % (secs / 60.0)
	return "%d seconds" % int(secs)


func _god(args: PackedStringArray) -> String:
	if not args.is_empty() and args[0].to_lower() in ["on", "1", "true"]:
		sim.god_mode = true
	elif not args.is_empty() and args[0].to_lower() in ["off", "0", "false"]:
		sim.god_mode = false
	else:
		sim.god_mode = not sim.god_mode
	return "God mode %s." % ("on: presses are free" if sim.god_mode else "off")


func _reset(args: PackedStringArray) -> String:
	if args.is_empty() or args[0].to_lower() != "confirm":
		return "This wipes your save. Type 'reset confirm' to do it."
	sim.new_game()
	needs_reload = true
	return "Save reset."
