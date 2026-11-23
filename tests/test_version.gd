extends RefCounted
## Version format, export preset match, changelog parsing.

func run(t: Object) -> void:
	var v: String = BuildInfo.VERSION
	var re := RegEx.new()
	re.compile("^\\d+\\.\\d+\\.\\d+$")
	t.ok(re.search(v) != null, "version %s is MAJOR.MINOR.PATCH" % v)
	t.eq(BuildInfo.string(), "v" + v, "string() adds a v")

	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	t.ok(presets.contains('application/version="%s"' % v), "export_presets version matches")
	t.ok(presets.contains('application/short_version="%s"' % v), "export_presets short_version matches")

	var entries: Array[Dictionary] = BuildInfo.changelog()
	t.ok(not entries.is_empty(), "changelog parses")
	if not entries.is_empty():
		t.eq(entries[0]["version"], v, "newest changelog heading is the current version")
		t.ok((entries[0]["notes"] as Array).size() > 0, "newest version has notes")
	var sample: Array[Dictionary] = BuildInfo.parse_changelog("## Unreleased\n- x\n## 1.12.3 - 2026-01-02\n- a\n- b\n## 1.2.0\n- c\n")
	t.eq(sample.size(), 2, "Unreleased is skipped")
	t.eq(sample[0]["version"], "1.12.3", "numbers can pass 9")
	t.eq(sample[0]["notes"], ["a", "b"], "notes parsed")
