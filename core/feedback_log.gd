class_name FeedbackLog
extends RefCounted
## Tester feedback notes. Pure file I/O, no nodes, no network. Notes append to user://feedback.txt
## as plain text, newest last, so a tester can open the file or paste it into a message.

const PATH: String = "user://feedback.txt"
const MAX_NOTE_CHARS: int = 2000
const SEPARATOR: String = "----"


## Formats one entry. `context` is a short line such as "v0.1.0 | zone1 | 12.5 min | 3 rebirths".
static func format_entry(note: String, context: String, stamp: String) -> String:
	var clean: String = note.strip_edges().left(MAX_NOTE_CHARS)
	return "%s\n[%s] %s\n%s\n" % [SEPARATOR, stamp, context, clean]


## Appends a note. Returns false for an empty note or when the file can't be written.
static func append(note: String, context: String, path: String = PATH) -> bool:
	if note.strip_edges().is_empty():
		return false
	var entry: String = format_entry(note, context, Time.get_datetime_string_from_system(false, true))
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_string(entry)
	f.close()
	return true


static func read_all(path: String = PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


static func entry_count(path: String = PATH) -> int:
	return read_all(path).count(SEPARATOR + "\n")
