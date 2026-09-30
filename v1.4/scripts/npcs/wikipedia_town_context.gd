class_name WikipediaTownContext
extends Node

## Read-only Wikipedia client for one creator-supplied article URL.

signal completed(ok: bool, page: Dictionary, message: String)

const TownKnowledgeStoreScript = preload("res://scripts/npcs/town_knowledge_store.gd")

var request: HTTPRequest
var source: Dictionary = {}
var loading := false


func _ready() -> void:
	request = HTTPRequest.new()
	# Keep the optional lookup noticeably bounded. A slow or offline source must
	# not hold the player before the existing local-model warm-up indefinitely.
	request.timeout = 12.0
	add_child(request)
	request.request_completed.connect(_on_request_completed)


func fetch(url: String) -> Dictionary:
	if loading:
		return {"ok": false, "message": "Wikipedia town information is already loading."}
	source = TownKnowledgeStoreScript.parse_wikipedia_url(url)
	if not source.ok:
		return source
	loading = true
	var error := request.request(
		str(source.api_url),
		["Accept: application/json", "User-Agent: 2D-Digital-World-Twin-Creator/1.4 (https://www.shanescomputing.com.au/2D_Digital_World_Twin_Creator.html)"],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		loading = false
		return {"ok": false, "message": "Wikipedia could not be contacted."}
	return {"ok": true, "message": "Refreshing optional Wikipedia town information…"}


func cancel() -> void:
	if loading and request != null:
		request.cancel_request()
	loading = false


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		completed.emit(false, {}, "Wikipedia was unavailable. Cached town information will be used when possible.")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var page_result := parse_api_response(parsed, source)
	completed.emit(bool(page_result.ok), page_result.get("page", {}), str(page_result.get("message", "")))


static func parse_api_response(parsed, source_data: Dictionary) -> Dictionary:
	if not parsed is Dictionary:
		return {"ok": false, "message": "Wikipedia returned unreadable town information."}
	var pages = parsed.get("query", {}).get("pages", [])
	if not pages is Array or pages.is_empty() or not pages[0] is Dictionary:
		return {"ok": false, "message": "Wikipedia could not find that article."}
	var page: Dictionary = pages[0]
	if bool(page.get("missing", false)) or int(page.get("pageid", 0)) <= 0:
		return {"ok": false, "message": "Wikipedia could not find that article."}
	if page.get("pageprops", {}) is Dictionary and page.get("pageprops", {}).has("disambiguation"):
		return {"ok": false, "message": "That URL is a Wikipedia disambiguation page. Paste the specific town article instead."}
	var summary := str(page.get("extract", "")).strip_edges()
	if summary.is_empty():
		return {"ok": false, "message": "That Wikipedia article does not contain a readable town summary."}
	var title := str(page.get("title", source_data.get("title", "Town")))
	var language := str(source_data.get("language", "en"))
	return {
		"ok": true,
		"message": "Wikipedia town summary refreshed.",
		"page": {
			"title": title,
			"language": language,
			"canonical_url": "https://%s.wikipedia.org/wiki/%s" % [language, title.replace(" ", "_").uri_encode()],
			"summary": summary
		}
	}
