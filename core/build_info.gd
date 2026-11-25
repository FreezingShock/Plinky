class_name BuildInfo
extends RefCounted
## Single source of truth for the game version (docs/versioning.md). Shown on the boot screen and the Update Log, stamped on feedback notes. Keep in step with the
## export presets' file_version / short_version and the release tag.

const VERSION: String = "0.106.25"

const CHANGELOG_PATH: String = "res://CHANGELOG.md"


## Display form, e.g. "v0.5.0".
static func string() -> String:
	return "v" + VERSION


## Parse CHANGELOG.md text into entries, newest first: {version, date, notes: Array[String]}.
## The Unreleased section is skipped. Notes are the "- " lines with the dash removed.
static func parse_changelog(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var re := RegEx.new()
	re.compile("^## (\\d+\\.\\d+\\.\\d+)(?: - (\\d{4}-\\d{2}-\\d{2}))?")
	var cur: Dictionary = {}
	for line in text.split("\n"):
		var m: RegExMatch = re.search(line)
		if m != null:
			cur = {"version": m.get_string(1), "date": m.get_string(2), "notes": [] as Array[String]}
			out.append(cur)
		elif line.begins_with("## "):
			cur = {}
		elif not cur.is_empty() and line.begins_with("- "):
			(cur["notes"] as Array[String]).append(line.substr(2).strip_edges())
	return out


## The shipped changelog, for the Update Log tile. Empty if the file is missing from the export.
static func changelog() -> Array[Dictionary]:
	var f: FileAccess = FileAccess.open(CHANGELOG_PATH, FileAccess.READ)
	if f == null:
		return []
	return parse_changelog(f.get_as_text())
