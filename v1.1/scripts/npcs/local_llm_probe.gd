class_name LocalLlmProbe
extends Node

## This only checks whether a local model server is available.
## Local models are reserved exclusively for future NPC persona conversations.

signal provider_checked(provider_id: String, available: bool, detail: String)
signal checks_finished

const PROVIDERS := [
	{"id": "ollama", "name": "Ollama", "url": "http://127.0.0.1:11434/api/tags"},
	{"id": "lm_studio", "name": "LM Studio", "url": "http://127.0.0.1:1234/v1/models"},
	{"id": "llama_cpp", "name": "llama.cpp", "url": "http://127.0.0.1:8080/v1/models"}
]

var pending_checks := 0


func check_all() -> void:
	if pending_checks > 0:
		return
	pending_checks = PROVIDERS.size()
	for provider in PROVIDERS:
		var request := HTTPRequest.new()
		request.timeout = 2.0
		add_child(request)
		request.request_completed.connect(_on_request_completed.bind(provider, request))
		var start_error := request.request(provider.url)
		if start_error != OK:
			provider_checked.emit(provider.id, false, "%s could not be contacted." % provider.name)
			request.queue_free()
			_finish_one_check()


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
	provider: Dictionary,
	request: HTTPRequest
) -> void:
	var available := response_code >= 200 and response_code < 300
	var detail := "%s is ready for NPC dialogue." % provider.name if available else "%s was not detected." % provider.name
	provider_checked.emit(provider.id, available, detail)
	request.queue_free()
	_finish_one_check()


func _finish_one_check() -> void:
	pending_checks -= 1
	if pending_checks <= 0:
		pending_checks = 0
		checks_finished.emit()

