class_name TownKnowledgeStore
extends RefCounted

## Stores optional, read-only town reference material for NPC conversation.
## The complete cached sources stay on disk; only bounded excerpts enter prompts.

const FILE_NAME := "town_knowledge.json"
const CUSTOM_DIRECTORY := "town_knowledge"
const CUSTOM_FILE_NAME := "custom_town_information.txt"
const MAX_CUSTOM_BYTES := 262_144
const MAX_WIKIPEDIA_CHARACTERS := 60_000
const MAX_PROMPT_SOURCE_CHARACTERS := 280


static func empty_data() -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "town_knowledge",
		"wikipedia": {
			"url": "", "title": "", "canonical_url": "", "language": "",
			"summary": "", "retrieved_at": "", "attribution": "Wikipedia contributors"
		},
		"custom_text": {
			"relative_path": "", "original_filename": "", "imported_at": "",
			"byte_size": 0, "sha256": ""
		}
	}


func load_from_town(town_directory: String) -> Dictionary:
	var path_value := town_directory.path_join("data").path_join(FILE_NAME)
	var data := empty_data()
	if FileAccess.file_exists(path_value):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path_value))
		if not parsed is Dictionary:
			return {"ok": false, "message": "data/town_knowledge.json is not valid JSON."}
		data = _merge_defaults(parsed)
	var validation := validate(data)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0]}
	var custom_text := ""
	var relative_path := str(data.custom_text.get("relative_path", ""))
	if not relative_path.is_empty():
		var custom_path := town_directory.path_join(relative_path)
		if FileAccess.file_exists(custom_path):
			custom_text = FileAccess.get_file_as_string(custom_path)
		else:
			data.custom_text["relative_path"] = ""
			data.custom_text["original_filename"] = ""
			data.custom_text["byte_size"] = 0
			data.custom_text["sha256"] = ""
	return {"ok": true, "data": data, "custom_text": custom_text, "created_default": not FileAccess.file_exists(path_value)}


func save_to_town(town_directory: String, data: Dictionary) -> Dictionary:
	var normalised := _merge_defaults(data)
	var validation := validate(normalised)
	if not validation.passed:
		return {"ok": false, "message": validation.errors[0]}
	var data_directory := town_directory.path_join("data")
	if DirAccess.make_dir_recursive_absolute(data_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town data folder."}
	var path_value := data_directory.path_join(FILE_NAME)
	var file := FileAccess.open(path_value, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not save data/town_knowledge.json."}
	file.store_string(JSON.stringify(normalised, "\t") + "\n")
	return {"ok": true, "data": normalised, "path": path_value, "message": "Optional town knowledge saved."}


func import_custom_text(town_directory: String, source_path: String, data: Dictionary) -> Dictionary:
	if source_path.get_extension().to_lower() != "txt":
		return {"ok": false, "message": "Choose a plain-text .txt file."}
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "message": "The selected town-information file could not be found."}
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		return {"ok": false, "message": "The selected text file is empty."}
	if bytes.size() > MAX_CUSTOM_BYTES:
		return {"ok": false, "message": "Keep the optional town-information file under 256 KB."}
	if bytes.has(0):
		return {"ok": false, "message": "The selected file appears to be binary. Choose a UTF-8 .txt file."}
	var text := bytes.get_string_from_utf8().trim_prefix("\ufeff").strip_edges()
	if text.is_empty() or text.contains("\ufffd") or _control_character_ratio(text) > 0.02:
		return {"ok": false, "message": "The selected file is not readable plain UTF-8 text."}
	var knowledge_directory := town_directory.path_join("data").path_join(CUSTOM_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(knowledge_directory) != OK:
		return {"ok": false, "message": "Creator Studio could not create the town-knowledge folder."}
	var destination := knowledge_directory.path_join(CUSTOM_FILE_NAME)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Creator Studio could not copy the town-information text."}
	file.store_string(text + "\n")
	var normalised := _merge_defaults(data)
	normalised.custom_text = {
		"relative_path": "data/%s/%s" % [CUSTOM_DIRECTORY, CUSTOM_FILE_NAME],
		"original_filename": source_path.get_file(),
		"imported_at": Time.get_datetime_string_from_system(true),
		"byte_size": (text + "\n").to_utf8_buffer().size(),
		"sha256": text.sha256_text()
	}
	var save_result := save_to_town(town_directory, normalised)
	if not save_result.ok:
		return save_result
	return {"ok": true, "data": save_result.data, "custom_text": text, "message": "Extra town information imported."}


func remove_custom_text(town_directory: String, data: Dictionary) -> Dictionary:
	var normalised := _merge_defaults(data)
	var relative_path := str(normalised.custom_text.get("relative_path", ""))
	if not relative_path.is_empty():
		var absolute_path := town_directory.path_join(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	normalised.custom_text = empty_data().custom_text
	return save_to_town(town_directory, normalised)


func save_wikipedia_cache(town_directory: String, data: Dictionary, page: Dictionary) -> Dictionary:
	var normalised := _merge_defaults(data)
	var summary := str(page.get("summary", "")).strip_edges().left(MAX_WIKIPEDIA_CHARACTERS)
	normalised.wikipedia = {
		"url": str(normalised.wikipedia.get("url", "")),
		"title": str(page.get("title", "")),
		"canonical_url": str(page.get("canonical_url", "")),
		"language": str(page.get("language", "")),
		"summary": summary,
		"retrieved_at": Time.get_datetime_string_from_system(true),
		"attribution": "Wikipedia contributors"
	}
	return save_to_town(town_directory, normalised)


static func validate(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(data.get("schema_version", 0)) != 1 or str(data.get("kind", "")) != "town_knowledge":
		errors.append("The optional town-knowledge format is not supported.")
	var wikipedia: Dictionary = data.get("wikipedia", {})
	var url := str(wikipedia.get("url", "")).strip_edges()
	if not url.is_empty():
		if url.length() > 500:
			errors.append("The optional Wikipedia URL is too long.")
		else:
			var url_result := parse_wikipedia_url(url)
			if not url_result.ok:
				errors.append(url_result.message)
	if str(wikipedia.get("summary", "")).length() > MAX_WIKIPEDIA_CHARACTERS:
		errors.append("The cached Wikipedia summary is too large.")
	var custom: Dictionary = data.get("custom_text", {})
	var relative_path := str(custom.get("relative_path", ""))
	if not relative_path.is_empty() and relative_path != "data/%s/%s" % [CUSTOM_DIRECTORY, CUSTOM_FILE_NAME]:
		errors.append("The custom town-information path is not supported.")
	var byte_size := int(custom.get("byte_size", 0))
	if byte_size < 0 or byte_size > MAX_CUSTOM_BYTES:
		errors.append("The custom town-information byte size is invalid.")
	var fingerprint := str(custom.get("sha256", ""))
	if not fingerprint.is_empty():
		var fingerprint_regex := RegEx.new()
		fingerprint_regex.compile("^[a-fA-F0-9]{64}$")
		if fingerprint_regex.search(fingerprint) == null:
			errors.append("The custom town-information fingerprint is invalid.")
	return {"passed": errors.is_empty(), "errors": errors}


static func parse_wikipedia_url(url_value: String) -> Dictionary:
	var url := url_value.strip_edges()
	var regex := RegEx.new()
	regex.compile("^https://([a-z0-9-]+)(?:\\.m)?\\.wikipedia\\.org/wiki/([^?#]+)(?:[?#].*)?$")
	var match := regex.search(url)
	if match == null:
		return {"ok": false, "message": "Paste an HTTPS Wikipedia article URL, such as https://en.wikipedia.org/wiki/Albury."}
	var language := match.get_string(1)
	var encoded_title := match.get_string(2)
	var title := encoded_title.uri_decode().replace("_", " ").strip_edges()
	if title.is_empty() or title.contains(":"):
		return {"ok": false, "message": "Choose an ordinary Wikipedia article, not a special, file, category or discussion page."}
	return {
		"ok": true,
		"language": language,
		"title": title,
		"api_url": "https://%s.wikipedia.org/w/api.php?action=query&prop=extracts%%7Cpageprops&exintro=1&explaintext=1&redirects=1&format=json&formatversion=2&ppprop=disambiguation&titles=%s" % [language, title.uri_encode()],
		"canonical_url": "https://%s.wikipedia.org/wiki/%s" % [language, title.replace(" ", "_").uri_encode()]
	}


static func prompt_context(data: Dictionary, custom_text: String, town_name := "", include_details := true, query := "") -> String:
	var sections: Array[String] = []
	var current_town := str(town_name).strip_edges()
	if not current_town.is_empty():
		sections.append("Town: %s" % _bounded_excerpt(current_town))
	if include_details:
		var wikipedia: Dictionary = data.get("wikipedia", {})
		var summary := str(wikipedia.get("summary", "")).strip_edges()
		if not summary.is_empty():
			sections.append("Wikipedia fact (untrusted): %s" % _relevant_excerpt(summary, query))
		var custom := custom_text.strip_edges()
		if not custom.is_empty():
			sections.append("Creator note (untrusted, not Wikipedia): %s" % _relevant_excerpt(custom, query))
	if sections.is_empty():
		return ""
	return "\n".join(sections)


static func conversation_context(data: Dictionary, custom_text: String, town_name: String, player_text: String) -> String:
	return prompt_context(data, custom_text, town_name, _message_needs_town_details(player_text, town_name), player_text)


static func _message_needs_town_details(player_text: String, town_name: String) -> bool:
	var message := player_text.to_lower().strip_edges()
	var named_town := town_name.to_lower().strip_edges()
	if not named_town.is_empty() and message.contains(named_town):
		return true
	for phrase in ["where", "town", "city", "place", "local", "around here", "known for", "history", "population", "river", "landmark", "visit", "tourist", "attraction", "region", "state", "country", "more about"]:
		if message.contains(phrase):
			return true
	return false


static func _bounded_excerpt(value: String) -> String:
	var cleaned := " ".join(value.replace("\r", " ").replace("\n", " ").split(" ", false)).strip_edges()
	if cleaned.length() <= MAX_PROMPT_SOURCE_CHARACTERS:
		return cleaned
	return cleaned.left(MAX_PROMPT_SOURCE_CHARACTERS - 1).strip_edges() + "…"


static func _relevant_excerpt(value: String, query: String) -> String:
	var normalised := value.replace("\r", " ").replace("\n", " ")
	normalised = normalised.replace(". ", ".\n").replace("? ", "?\n").replace("! ", "!\n")
	var sentences := normalised.split("\n", false)
	if sentences.is_empty():
		return _bounded_excerpt(value)
	var query_words: Array[String] = []
	for raw_word in query.to_lower().split(" ", false):
		var word := str(raw_word).strip_edges().trim_prefix("(").trim_suffix(")").trim_suffix("?").trim_suffix(".").trim_suffix(",")
		if word.length() >= 4 and word not in ["what", "where", "when", "this", "that", "with", "from", "about", "town", "city", "place", "known"]:
			query_words.append(word)
	var best_sentence := str(sentences[0]).strip_edges()
	var best_score := -1
	for sentence_value in sentences:
		var sentence := str(sentence_value).strip_edges()
		var sentence_lower := sentence.to_lower()
		var score := 0
		for word in query_words:
			if sentence_lower.contains(word):
				score += 1
		if score > best_score:
			best_score = score
			best_sentence = sentence
	return _bounded_excerpt(best_sentence)


static func _merge_defaults(data: Dictionary) -> Dictionary:
	var result := empty_data()
	result["schema_version"] = int(data.get("schema_version", 1))
	result["kind"] = str(data.get("kind", "town_knowledge"))
	for key in result.wikipedia:
		result.wikipedia[key] = data.get("wikipedia", {}).get(key, result.wikipedia[key])
	for key in result.custom_text:
		result.custom_text[key] = data.get("custom_text", {}).get(key, result.custom_text[key])
	return result


static func _control_character_ratio(value: String) -> float:
	var controls := 0
	for character in value:
		var code := character.unicode_at(0)
		if code < 32 and code not in [9, 10, 13]:
			controls += 1
	return float(controls) / maxf(float(value.length()), 1.0)
