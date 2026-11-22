extends RefCounted

func run(t: Object) -> void:
	var path: String = "user://test_feedback.txt"
	DirAccess.remove_absolute(path)
	t.eq(FeedbackLog.read_all(path), "", "no file reads as empty")
	t.ok(not FeedbackLog.append("   ", "ctx", path), "blank note is rejected")
	t.ok(not FileAccess.file_exists(path), "blank note writes nothing")
	t.ok(FeedbackLog.append("Pads feel slow", "v0 | zone1", path), "first note saves")
	t.ok(FeedbackLog.append("Gate is great", "v0 | zone1", path), "second note appends")
	t.eq(FeedbackLog.entry_count(path), 2, "two entries counted")
	var text: String = FeedbackLog.read_all(path)
	t.ok(text.contains("Pads feel slow") and text.contains("Gate is great"), "both notes are kept")
	t.ok(text.find("Pads") < text.find("Gate"), "newest is last")
	t.ok(text.contains("v0 | zone1"), "context is stamped")
	var long: String = "x".repeat(5000)
	t.ok(FeedbackLog.format_entry(long, "c", "s").length() < FeedbackLog.MAX_NOTE_CHARS + 60, "long notes are capped")
	DirAccess.remove_absolute(path)
