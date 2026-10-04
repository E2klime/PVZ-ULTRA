class_name Loc
extends RefCounted
## Translation of authored content (campaign titles, briefings, jokes, workshop
## text, almanac badges). The English text itself is the message id: whole
## strings are looked up first, then " · " parts, lines and single sentences, so
## long briefings assembled from reusable sentences translate piece by piece.
## Units live in localization/content.csv (see docs/LOCALIZATION.md).

const _SENTENCE_SPLIT := "(?<=[.!?])['\")]?\\s+"
static var _re: RegEx

static func text(s: String) -> String:
	if s == "":
		return s
	var whole := TranslationServer.translate(s)
	if whole != s or _is_english():
		return whole
	if s.contains(" · "):
		var parts := PackedStringArray()
		for part: String in s.split(" · "):
			parts.append(text(part))
		return " · ".join(parts)
	if s.contains("\n"):
		var lines := PackedStringArray()
		for line: String in s.split("\n"):
			lines.append(text(line))
		return "\n".join(lines)
	var sentences := _sentences(s)
	if sentences.size() <= 1:
		return whole
	var out := PackedStringArray()
	for sentence: String in sentences:
		out.append(TranslationServer.translate(sentence))
	return ("" if _is_cjk() else " ").join(out)

## Level title such as "3-07 · Some Title": the numeric prefix is kept as is.
static func title(s: String) -> String:
	var idx := s.find(" · ")
	if idx > 0 and s.substr(0, idx).replace("-", "").is_valid_int():
		return s.substr(0, idx) + " · " + text(s.substr(idx + 3))
	return text(s)

static func _sentences(s: String) -> PackedStringArray:
	if _re == null:
		_re = RegEx.create_from_string(_SENTENCE_SPLIT)
	var out := PackedStringArray()
	var start := 0
	for m: RegExMatch in _re.search_all(s):
		# Keep closing quotes/brackets with the sentence they end.
		var cut := m.get_start() + m.get_string().strip_edges().length()
		out.append(s.substr(start, cut - start))
		start = m.get_end()
	if start < s.length():
		out.append(s.substr(start))
	return out

static func _is_english() -> bool:
	return TranslationServer.get_locale().begins_with("en")

static func _is_cjk() -> bool:
	var l := TranslationServer.get_locale()
	return l.begins_with("zh") or l.begins_with("ja")
