class_name LocalLlmStartupLoader
extends Node

## Loads an already-installed Ollama model and warms the shared town prompt used
## by every saved persona. Persona records are already loaded by the runtime;
## keeping their variable notes after this shared prefix lets every character
## reuse the same model-side prompt cache.

signal completed(ok: bool, detail: String, load_seconds: float)

const CHAT_URL := "http://127.0.0.1:11434/api/chat"
const OllamaDialogueClientScript = preload("res://scripts/npcs/ollama_dialogue_client.gd")

var request: HTTPRequest
var loading := false
var provider_data: Dictionary = {}
var warmup_prompts: Array[String] = []
var warmup_index := 0
var started_msec := 0


func _ready() -> void:
	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_request_completed)


func preload_model(provider: Dictionary, town_context := "", personas: Array = []) -> Dictionary:
	if loading:
		return {"ok": false, "message": "The local model is already loading."}
	if str(provider.get("endpoint", "")) != "http://127.0.0.1:11434":
		return {"ok": false, "message": "Only the local Ollama address is allowed."}
	var model := str(provider.get("model", "")).strip_edges()
	if model.is_empty():
		return {"ok": false, "message": "No Ollama model has been selected."}
	provider_data = provider.duplicate(true)
	warmup_prompts.clear()
	warmup_prompts.append(OllamaDialogueClientScript.catalog_system_prompt(personas, str(town_context)))
	warmup_index = 0
	started_msec = Time.get_ticks_msec()
	loading = true
	var start_result := _request_current_prompt()
	if not start_result.ok:
		loading = false
		return start_result
	return {"ok": true, "message": "Loading %s, town knowledge and persona library…" % model}


func _request_current_prompt() -> Dictionary:
	var model := str(provider_data.get("model", "")).strip_edges()
	request.timeout = clampf(float(provider_data.get("timeout_seconds", 90.0)), 5.0, 90.0)
	var payload := {
		"model": model,
		"messages": [
			{"role": "system", "content": warmup_prompts[warmup_index]},
			{"role": "user", "content": "Say OK."}
		],
		"stream": false,
		"think": false,
		"keep_alive": "2h",
		"options": {"temperature": 0.0, "num_ctx": 1024, "num_predict": 1}
	}
	var error := request.request(CHAT_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		return {"ok": false, "message": "Ollama could not be contacted."}
	return {"ok": true}


func cancel() -> void:
	if loading and request != null:
		request.cancel_request()
	loading = false
	warmup_prompts.clear()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		loading = false
		completed.emit(false, "Ollama could not load the selected model (connection result %d, HTTP %d)." % [result, response_code], 0.0)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not bool(parsed.get("done", false)):
		loading = false
		completed.emit(false, "Ollama returned an unreadable model-loading response.", 0.0)
		return
	warmup_index += 1
	if warmup_index < warmup_prompts.size():
		var next_result := _request_current_prompt()
		if not next_result.ok:
			loading = false
			completed.emit(false, next_result.message, 0.0)
		return
	loading = false
	var startup_seconds := float(Time.get_ticks_msec() - started_msec) / 1000.0
	completed.emit(true, "%d persona prompts ready." % warmup_prompts.size(), startup_seconds)
