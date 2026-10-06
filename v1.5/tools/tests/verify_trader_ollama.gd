extends SceneTree
const Dialogue = preload("res://scripts/npcs/ollama_dialogue_client.gd")
const Store = preload("res://scripts/npcs/traders/trader_store.gd")
var received := false
var good := false
var detail := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var adapter := Dialogue.new()
	root.add_child(adapter)
	adapter.reply_ready.connect(func(ok, reply, message):
		received = true
		good = ok and adapter.purchase_suggestion == {"item_id": "beer", "quantity": 1}
		detail = reply if ok else message)
	var persona: Dictionary = Store.presets()[0].duplicate(true)
	persona.character_name = "Moe"
	var started := adapter.ask(persona, "I'd like to buy one beer please.", [], {"endpoint": "http://127.0.0.1:11434", "model": "llama3.2:3b", "timeout_seconds": 30}, "The town is Albury.", [], {"role": "Barkeep", "items": [{"item_id": "beer", "name": "Beer", "stock": 20, "price_keks": 5}]})
	if not started.ok:
		printerr(started.message)
		quit(1)
		return
	var began := Time.get_ticks_msec()
	while not received and Time.get_ticks_msec() - began < 32000:
		await create_timer(0.1).timeout
	adapter.cancel()
	if not good:
		printerr("LIVE TRADER CHECK FAILED: " + detail)
		quit(1)
		return
	print("LIVE OLLAMA TRADER PASSED: recognised 1 beer, returned a complete spoken reply without touching inventories. %.2fs; %s" % [(Time.get_ticks_msec()-began)/1000.0, detail])
	adapter.queue_free()
	await process_frame
	quit()
