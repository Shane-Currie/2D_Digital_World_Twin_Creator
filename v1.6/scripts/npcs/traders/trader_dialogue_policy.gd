extends RefCounted

## Deterministic helpers recognise clear purchases; nothing here commits a sale.
static func words(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-z0-9 ]")
	return " " + " ".join(regex.sub(value.to_lower(), " ", true).split(" ", false)) + " "

static func matches_item(text: String, item: Dictionary) -> bool:
	for label in [str(item.get("name", "")), str(item.get("item_id", "")).replace("_", " ")]:
		var key := words(label).strip_edges()
		if not key.is_empty() and (text.contains(" " + key + " ") or text.contains(" " + key + "s ")): return true
	return false

static func available(stock: Dictionary, item_id: String) -> Dictionary:
	for item in stock.get("items", []):
		if str(item.item_id) == item_id and int(item.get("stock", 0)) > 0: return item
	return {}

static func stock_reply(stock: Dictionary) -> String:
	var labels: Array[String] = []
	for item in stock.get("items", []):
		if int(item.get("stock", 0)) > 0: labels.append(str(item.name).left(50))
	return "I currently have %s; open Shop for prices and quantities." % ", ".join(labels.slice(0, 5)) if not labels.is_empty() else "I don't have anything in stock right now."

static func classify(text_value: String, stock: Dictionary, catalog: Dictionary = {}) -> Dictionary:
	var text := words(text_value)
	# Questions about ability to buy are still requests, but negation isn't consent.
	var negative := false
	for phrase in [" not ", " no ", " dont ", " don t ", " cancel ", " never ", " stop ", " maybe ", " thinking ", " if ", " bought ", " purchased ", " ordered ", " yesterday ", " already "]: negative = negative or text.contains(phrase)
	var purchase := false
	for phrase in [" buy ", " purchase ", " order ", " can i have ", " could i have ", " may i have ", " can i get ", " could i get ", " ill take ", " i ll take ", " i ll have ", " ill have ", " would like ", " id like ", " i d like ", " give me ", " want ", " need ", " please "]: purchase = purchase or text.contains(phrase)
	var explicit_purchase := text.contains(" buy ") or text.contains(" purchase ") or text.contains(" order ")
	if negative: return {}
	if not explicit_purchase:
		for phrase in [" know ", " tell ", " motto ", " where ", " why ", " who ", " about "]:
			if text.contains(phrase): return {}
	for phrase in [" how much ", " price ", " cost ", " keks "]:
		if text.contains(phrase): return {"handled": true, "reply": stock_reply(stock)}
	var matching: Array = []
	for item in stock.get("items", []):
		if matches_item(text, item): matching.append(item)
	var catalog_matches := 0
	for item in catalog.get("items", []):
		if str(item.id) != "keks" and matches_item(text, {"name": item.display_name, "item_id": item.id}): catalog_matches += 1
	if purchase and catalog_matches > 1: return {"handled": true, "reply": "Please choose one item at a time in Shop."}
	# "One beer" is an implicit order; "do you have beer?" is only a question.
	if matching.size() == 1 and text.strip_edges().split(" ", false).size() <= 4:
		var question := false
		for word in [" do ", " does ", " what ", " have ", " is ", " price ", " how ", " i ", " you ", " we ", " like ", " had ", " was ", " did "]: question = question or text.contains(word)
		if not question: purchase = true
	if purchase and matching.size() == 1:
		var quantity := 1
		var numbers := RegEx.new()
		numbers.compile("\\b([0-9]+)\\b")
		var numeric := numbers.search_all(text)
		if numeric.size() > 1: return {"handled": true, "reply": "Please choose one item and quantity at a time in Shop."}
		if numeric.size() == 1: quantity = int(numeric[0].get_string(1))
		else:
			var counts := {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "a dozen": 12, "a couple": 2}
			for number_word in counts:
				if text.contains(" " + str(number_word) + " "): quantity = int(counts[number_word])
		if quantity < 1 or quantity > 99: return {"handled": true, "reply": "Please choose a quantity from 1 to 99 in Shop."}
		var item: Dictionary = matching[0]
		if quantity > int(item.stock): return {"handled": true, "reply": "I don't have enough stock for that quantity; please check Shop."}
		return {"handled": true, "reply": "Please confirm the %s purchase shown on screen." % str(item.name).left(60), "item_id": str(item.item_id), "quantity": quantity}
	if purchase and matching.size() > 1: return {"handled": true, "reply": "Please choose one item at a time in Shop."}
	if purchase:
		# Never infer a different available item when the requested item is missing.
		for item in catalog.get("items", []):
			if matches_item(text, {"name": item.get("display_name", ""), "item_id": item.get("id", "")}):
				return {"handled": true, "reply": "I don't have that item available; please check Shop for current stock."}
		if explicit_purchase: return {"handled": true, "reply": stock_reply(stock)}
	for phrase in [" in stock ", " stock ", " sell ", " selling ", " menu ", " available ", " for sale "]:
		if text.contains(phrase): return {"handled": true, "reply": stock_reply(stock)}
	return {}

static func validate_reply(reply: String, suggestion: Dictionary, stock: Dictionary, catalog: Dictionary, player_text := "") -> Dictionary:
	if not suggestion.is_empty():
		if not player_text.is_empty():
			var intent := classify(player_text, stock, catalog)
			if str(intent.get("item_id", "")) != str(suggestion.get("item_id", "")) or intent.get("quantity", 0) != suggestion.get("quantity", 0):
				return {"reply": stock_reply(stock), "suggestion": {}}
		var item := available(stock, str(suggestion.get("item_id", "")))
		if item.is_empty() or int(suggestion.get("quantity", 0)) > int(item.get("stock", 0)):
			return {"reply": "That purchase isn't available; please check Shop for current stock.", "suggestion": {}}
		return {"reply": "Please confirm the %s purchase shown on screen." % str(item.name).left(60), "suggestion": suggestion}
	var text := words(reply)
	# Disallow references to catalogue goods that aren't currently offered.
	for item in catalog.get("items", []):
		if str(item.id) == "keks": continue
		if matches_item(text, {"name": item.display_name, "item_id": item.id}) and available(stock, str(item.id)).is_empty():
			return {"reply": stock_reply(stock), "suggestion": {}}
	# Model-generated sale/menu claims are replaced by the authoritative manifest,
	# including invented product names that are not in the creator's catalogue.
	for phrase in [" have ", " sell ", " selling ", " offer ", " serve ", " serving ", " stock ", " buy ", " purchase ", " menu ", " available ", " price ", " keks ", " paid ", " payment ", " order "]:
		if text.contains(phrase): return {"reply": stock_reply(stock), "suggestion": {}}
	return {"reply": reply, "suggestion": {}}
