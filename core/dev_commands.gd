class_name DevCommands
extends RefCounted
## Admin and dev commands for the console (ui/dev_console.gd). Pure logic over a Sim: no nodes, no autoloads,
## so tests can drive it. Node-level commands (tp, weather, speed, ...) are added by the console with register().
##   var cmds := DevCommands.new(sim)
##   print(cmds.run("time set noon"))        # Minecraft-style: time set day|night|noon|dawn|dusk|midnight|hh:mm
##   print(cmds.complete("ti"))              # tab suggestions for a half-typed line
## run() always returns a one-or-more line reply and never throws on bad input.
## A command may have a two-word form registered as "name sub" (e.g. "reset speed"); it is matched first.

const MAX_SKIP_SECONDS: float = 7.0 * 86400.0
const MAX_ADD_MINUTES: float = 400.0 * 1440.0
## Help sections, in the order help prints them.
const GROUP_ORDER: Array = ["Time and weather", "Player", "World", "Dev", "Console"]
## Short names typed in place of a full command name.
const ALIASES: Dictionary = {"g": "give", "s": "set", "t": "time", "sea": "season", "w": "weather", "sp": "speed",
	"st": "stats", "h": "help", "?": "help", "cls": "clear", "rb": "rebirth", "z": "zone"}
## Words `time set` takes instead of hh:mm. Sunrise and sunset follow the calendar's daylight fraction.
const TIME_WORDS: Array = ["dawn", "day", "noon", "dusk", "night", "midnight"]
const WEATHER_WORDS: Array = ["clear", "rain", "auto"]
const SEASON_WORDS: Array = ["spring", "summer", "autumn", "winter"]
const RESET_WORDS: Array = ["confirm", "speed", "weather"]
const TP_WORDS: Array = ["gate", "start", "pad", "area", "zone"]
## Replies starting with these read as errors in the console.
const ERROR_OPENERS: Array = ["Unknown", "No ", "Not ", "Save failed"]

var sim: Sim
## Set by commands that replace the whole save. The console reloads the scene when it sees this.
var needs_reload: bool = false
var _meta: Dictionary = {}   # name -> {"usage", "help", "group", "fn": Callable, "args": Callable(typed) -> words}


func _init(p_sim: Sim) -> void:
	sim = p_sim
	_core("help", "help [command]", "list the commands, or explain one", "Console")
	_core("stats", "stats", "list every stat and its value", "Player")
	_core("give", "give <stat> <amount>", "add to a stat. Amounts: 1e12, 5k, 2.5M", "Player", true)
	_core("set", "set <stat> <amount>", "set a stat outright", "Player", true)
	_core("prestige", "prestige <amount>", "set the prestige stat", "Player")
	_core("rebirths", "rebirths <n>", "set the rebirth count (unlocks relic slots)", "Player")
	_core("rebirth", "rebirth", "rebirth now, if allowed", "Player")
	_core("zonereset", "zonereset [id]", "do this zone's reset now, if allowed", "Player")
	_core("relic", "relic <id | all | rarity <tier>> [stacks]", "give relics: one id, every relic, or a whole tier", "Player", true)
	_core("relics", "relics", "list relics and their rarities", "Player")
	_core("attr", "attr <id> <level>", "set an upgrade level", "Player", true)
	_core("god", "god [on | off]", "presses cost nothing", "Player")
	_core("time", "time [set <time> | add <amount>]",
		"show, set or move the time of day. Set: dawn, day, noon, dusk, night, midnight or hh:mm. Add: 30m, 2h, 1d", "Time and weather", true)
	_core("season", "season [set <name>]", "show the date, or jump to the start of a season", "Time and weather", true)
	_core("day", "day <n>", "advance the calendar by n in-game days", "Time and weather")
	_core("skip", "skip <time>", "fast forward income: 90s, 15m, 3h, 2d", "Time and weather")
	_core("zone", "zone <id>", "jump to a zone, opening the gate that leads there", "World", true)
	_core("tiers", "tiers [id]", "open every flower tier, or just one", "World", true)
	_core("reset", "reset confirm", "wipe the save and restart. Also: reset speed, reset weather", "Dev", true)


## Add a command from outside core. fn takes the arguments (PackedStringArray) and returns the reply text.
## args_fn(typed: PackedStringArray) -> PackedStringArray gives tab suggestions for the word after `typed`.
## `usage` defaults to the name; "name sub" registers a two-word command.
func register(cmd_name: String, help: String, fn: Callable, args_fn: Callable = Callable(),
		group: String = "Console", usage: String = "") -> void:
	var name: String = cmd_name.to_lower()
	_meta[name] = {"usage": usage if usage != "" else name, "help": help, "group": group, "fn": fn, "args": args_fn}


func _core(cmd_name: String, usage: String, help: String, group: String, has_args: bool = false) -> void:
	var args_fn: Callable = Callable(self, "_core_args").bind(cmd_name) if has_args else Callable()
	_meta[cmd_name] = {"usage": usage, "help": help, "group": group, "fn": Callable(), "args": args_fn}


## The full command name for a typed word (aliases resolved), lower case.
static func resolve(word: String) -> String:
	var w: String = word.to_lower()
	return String(ALIASES[w]) if ALIASES.has(w) else w


## Lines of help. With a topic, the usage and description of that one command.
func help_lines(topic: String = "") -> PackedStringArray:
	if topic != "":
		var name: String = resolve(topic)
		if not _meta.has(name):
			return PackedStringArray(["No command '%s'. Type help." % topic])
		var m: Dictionary = _meta[name]
		return PackedStringArray(["%s" % m["usage"], "  %s" % m["help"]])
	var out: PackedStringArray = PackedStringArray()
	for group: String in GROUP_ORDER:
		var names: PackedStringArray = PackedStringArray()
		for k: Variant in _meta:
			if String((_meta[k] as Dictionary)["group"]) == group:
				names.append(String(k))
		if names.is_empty():
			continue
		names.sort()
		out.append("-- %s --" % group)
		for n: String in names:
			var m: Dictionary = _meta[n]
			out.append("%-34s%s" % [String(m["usage"]), String(m["help"])])
	var short: PackedStringArray = PackedStringArray()
	for a: Variant in ALIASES:
		short.append("%s = %s" % [a, ALIASES[a]])
	short.sort()
	out.append("Short names: %s. Tab completes; Up and Down recall history." % ", ".join(short))
	return out


## The usage line for a command word (aliases resolved), or "" when there is no such command.
func usage_of(word: String) -> String:
	var name: String = resolve(word)
	return String((_meta[name] as Dictionary)["usage"]) if _meta.has(name) else ""


## How a reply should be coloured: "error", "usage", "warn" or "ok".
static func reply_kind(reply: String) -> StringName:
	if reply.begins_with("Usage") or reply.contains("Usage:"):
		return &"usage"
	if reply.begins_with("This wipes"):
		return &"warn"
	if reply.contains("not a number") or reply.contains("is not a time"):
		return &"error"
	for opener: String in ERROR_OPENERS:
		if reply.begins_with(opener):
			return &"error"
	return &"ok"


## Suggestions for a half-typed line, in the order the console shows them. Commands first, then the words
## the command takes at that position (stat ids, zone ids, season names, ...). Case-insensitive prefix match.
func complete(line: String) -> PackedStringArray:
	var raw: String = line.strip_edges(true, false)
	var trailing: bool = raw.ends_with(" ")
	var parts: PackedStringArray = raw.split(" ", false)
	if parts.is_empty():
		return _command_names()
	if parts.size() == 1 and not trailing:
		return _filter(_command_names(), parts[0].to_lower())
	var cmd: String = resolve(parts[0])
	var typed: PackedStringArray = parts.slice(1) if trailing else parts.slice(1, parts.size() - 1)
	var word: String = "" if trailing else parts[parts.size() - 1]
	if cmd == "help" and typed.is_empty():
		return _filter(_command_names(), word.to_lower())
	return _filter(_candidates(cmd, typed), word.to_lower())


func _command_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in _meta:
		if not String(k).contains(" "):
			out.append(String(k))
	out.sort()
	return out


func _candidates(cmd: String, typed: PackedStringArray) -> PackedStringArray:
	if not _meta.has(cmd):
		return PackedStringArray()
	var args_fn: Callable = (_meta[cmd] as Dictionary)["args"]
	return args_fn.call(typed) if args_fn.is_valid() else PackedStringArray()


static func _filter(words: PackedStringArray, prefix: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for w: String in words:
		if w.to_lower().begins_with(prefix):
			out.append(w)
	return out


func _core_args(typed: PackedStringArray, cmd: String) -> PackedStringArray:
	var first: String = typed[0].to_lower() if not typed.is_empty() else ""
	var none: PackedStringArray = PackedStringArray()
	match cmd:
		"give", "set":
			return _stat_names() if typed.is_empty() else none
		"zone":
			return _keys(sim.zone_defs) if typed.is_empty() else none
		"tiers":
			return _keys(sim.tier_defs) if typed.is_empty() else none
		"attr":
			return _attr_names() if typed.is_empty() else none
		"relic":
			if typed.is_empty():
				var words: PackedStringArray = _keys(sim.relics.defs)
				words.append("all")
				words.append("rarity")
				return words
			return _rarity_names() if first == "rarity" and typed.size() == 1 else none
		"time":
			if typed.is_empty():
				return PackedStringArray(["set", "add"] + TIME_WORDS)
			return PackedStringArray(TIME_WORDS) if first == "set" and typed.size() == 1 else none
		"season":
			if typed.is_empty():
				return PackedStringArray(["set"] + SEASON_WORDS)
			return PackedStringArray(SEASON_WORDS) if first == "set" and typed.size() == 1 else none
		"reset":
			return PackedStringArray(RESET_WORDS) if typed.is_empty() else none
	return none


# ---------------------------------------------------------------- running

func run(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd: String = resolve(parts[0])
	var args: PackedStringArray = parts.slice(1)
	if not args.is_empty() and _meta.has(cmd + " " + args[0].to_lower()):
		cmd = cmd + " " + args[0].to_lower()
		args = args.slice(1)
	var fn: Callable = (_meta.get(cmd, {}) as Dictionary).get("fn", Callable())
	if fn.is_valid():
		return String(fn.call(args))
	match cmd:
		"help":
			return "\n".join(help_lines(args[0] if not args.is_empty() else ""))
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
		"zonereset", "bloom":
			return _zone_reset(cmd, args)
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
		"time":
			return _time(args)
		"tiers":
			return _tiers(args)
		"god":
			return _god(args)
		"reset":
			return _reset(args)
	return "Unknown command '%s'. Type help." % parts[0]


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


## In-game amounts for `time add`: "30" or "30m" minutes, "2h" hours, "1d" days. -1 when unreadable.
static func parse_game_minutes(text: String) -> float:
	var t: String = text.strip_edges().to_lower()
	var unit: float = 1.0
	if t.ends_with("d"):
		unit = 1440.0
		t = t.left(-1)
	elif t.ends_with("h"):
		unit = 60.0
		t = t.left(-1)
	elif t.ends_with("m"):
		t = t.left(-1)
	return t.to_float() * unit if t.is_valid_float() else -1.0


## A time of day as a fraction (0 midnight .. 1). Accepts the time words or "hh:mm" (24-hour). -1 when unreadable.
## Sunrise and sunset come from the calendar's daylight fraction, so the words stay right for any day length.
static func time_fraction(text: String, daylight: float = 0.6) -> float:
	var t: String = text.strip_edges().to_lower()
	var d: float = clampf(daylight, 0.2, 0.8)
	var rise: float = (1.0 - d) * 0.5
	var sunset: float = rise + d
	match t:
		"midnight":
			return 0.0
		"dawn":
			return rise
		"day":
			return (rise + 0.5) * 0.5
		"noon":
			return 0.5
		"dusk":
			return sunset
		"night":
			return fposmod((sunset + 1.0) * 0.5, 1.0)
	if t.contains(":"):
		var bits: PackedStringArray = t.split(":")
		if bits.size() == 2 and bits[0].is_valid_int() and bits[1].is_valid_int():
			var h: int = bits[0].to_int()
			var m: int = bits[1].to_int()
			if h >= 0 and h < 24 and m >= 0 and m < 60:
				return float(h * 60 + m) / 1440.0
	return -1.0


## 0 clear, 1 rain, -1 auto (the sky's own weather). -2 when the word is not a weather.
static func weather_level(word: String) -> float:
	match word.strip_edges().to_lower():
		"auto", "":
			return -1.0
		"clear":
			return 0.0
		"rain":
			return 1.0
	return -2.0


# ---------------------------------------------------------------- commands

func _stat_names() -> PackedStringArray:
	return _keys(sim.stat_defs)


func _attr_names() -> PackedStringArray:
	return _keys(sim.attribute_defs)


func _rarity_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: RelicDef in sim.relics.defs.values():
		if not out.has(String(d.rarity.id)):
			out.append(String(d.rarity.id))
	out.sort()
	return out


static func _keys(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in d:
		out.append(String(k))
	return out


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


func _zone_reset(cmd: String, args: PackedStringArray) -> String:
	var rid: StringName = &"bloom"
	if cmd != "bloom":
		var here: ZoneResetDef = sim.reset_for_zone()
		rid = StringName(args[0]) if args.size() > 0 else (here.id if here != null else &"")
	var rd: ZoneResetDef = sim.reset_defs.get(rid) as ZoneResetDef
	if rd == null:
		var known: PackedStringArray = PackedStringArray()
		for k: StringName in sim.reset_defs:
			known.append(String(k))
		return "No reset here. Known: %s" % ", ".join(known)
	if sim.try_reset(rd.id):
		return "%s done." % rd.display_name
	return "Not enough yet for %s." % rd.display_name


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
	var ids: PackedStringArray = _keys(sim.zone_defs)
	if args.is_empty():
		return "Usage: zone <id>. Zones: %s (now in %s)" % [", ".join(ids), sim.zone_id]
	if not sim.zone_defs.has(StringName(args[0].to_lower())):
		return "No zone '%s'. Zones: %s" % [args[0], ", ".join(ids)]
	sim.dev_force_zone(StringName(args[0].to_lower()))
	return "In zone %s." % sim.zone_id


func _tiers(args: PackedStringArray) -> String:
	var ids: PackedStringArray = _keys(sim.tier_defs)
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


func _clock_line() -> String:
	var n: Dictionary = sim.calendar.now()
	return "%s, %s %d, %s (%s)" % [n["season_name"], n["month_name"], n["day"], n["clock_text"],
		"sun up" if n["is_day"] else "sun down"]


func _time(args: PackedStringArray) -> String:
	var cal: GameCalendar = sim.calendar
	if args.is_empty() or args[0].to_lower() == "query":
		return "It is %s." % _clock_line()
	var verb: String = args[0].to_lower()
	if verb == "add":
		if args.size() < 2:
			return "Usage: time add <amount>, like 30m, 2h or 1d (in-game time)."
		var mins: float = parse_game_minutes(args[1])
		if mins <= 0.0:
			return "'%s' is not an amount of time. Try 30m, 2h or 1d." % args[1]
		cal.skip_days(minf(mins, MAX_ADD_MINUTES) / 1440.0)
		return "Time is now %s." % _clock_line()
	var word: String = args[1] if verb == "set" and args.size() >= 2 else verb
	if verb == "set" and args.size() < 2:
		return "Usage: time set <dawn | day | noon | dusk | night | midnight | hh:mm>"
	var f: float = time_fraction(word, cal.daylight_fraction)
	if f < 0.0:
		if verb == "set":
			return "'%s' is not a time. Try day, night, noon or 18:30." % word
		return "Usage: time [set <time> | add <amount>]"
	cal.set_day_fraction(f)
	return "Time is now %s." % _clock_line()


func _season(args: PackedStringArray) -> String:
	var rest: PackedStringArray = args.slice(1) if not args.is_empty() and args[0].to_lower() == "set" else args
	var cal: GameCalendar = sim.calendar
	if rest.is_empty():
		var n: Dictionary = cal.now()
		return "Year %d, %s (%s), %s %d, %s" % [n["year"], n["season_name"], n["season_id"], n["month_name"], n["day"], n["clock_text"]]
	var want: String = rest[0].to_lower()
	var idx: int = -1
	for i in GameCalendar.SEASONS:
		if want == String(cal.config.season_ids[i]).to_lower() or want == cal.season_name(i).to_lower() or want == str(i):
			idx = i
	if idx < 0:
		return "Unknown season '%s'. Try spring, summer, autumn or winter." % rest[0]
	cal.jump_to_season(idx)
	return "Jumped to %s, %s." % [cal.season_name(idx), cal.now()["clock_text"]]


func _day(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_float() or args[0].to_float() <= 0.0:
		return "Usage: day <n>  (in-game days, e.g. 2 or 0.5)"
	sim.calendar.skip_days(minf(args[0].to_float(), 400.0))
	var n: Dictionary = sim.calendar.now()
	return "Now %s, %s %d, %s." % [n["season_name"], n["month_name"], n["day"], n["clock_text"]]


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
