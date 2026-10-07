extends RefCounted

## In-session data/form undo. No imports, source files or whole map copies.
const LIMIT := 30
var current: Dictionary = {}
var previous: Array[Dictionary] = []

func reset(snapshot: Dictionary) -> void:
	current = snapshot.duplicate(true)
	previous.clear()

func record(snapshot: Dictionary) -> void:
	if snapshot == current: return
	previous.append(current)
	if previous.size() > LIMIT: previous.pop_front()
	current = snapshot.duplicate(true)

func undo() -> Dictionary:
	if previous.is_empty(): return {}
	current = previous.pop_back()
	return current.duplicate(true)

static func form_values(root: Node) -> Dictionary:
	var values: Dictionary = {}
	_collect(root, root, values)
	return values

static func _collect(node: Node, root: Node, values: Dictionary) -> void:
	var value: Variant = null
	if node is SpinBox: value = node.value
	elif node is LineEdit and not node.get_parent() is SpinBox: value = node.text
	elif node is TextEdit and node.editable: value = node.text
	elif node is OptionButton: value = node.selected
	elif node is BaseButton and node.toggle_mode: value = node.button_pressed
	if value != null: values[str(root.get_path_to(node))] = value
	for child in node.get_children(): _collect(child, root, values)

static func restore_form(root: Node, values: Dictionary) -> void:
	for path in values:
		var node := root.get_node_or_null(NodePath(path))
		if node is SpinBox: node.set_value_no_signal(float(values[path]))
		elif node is LineEdit: node.set_text(str(values[path]))
		elif node is TextEdit: node.text = str(values[path])
		elif node is OptionButton and int(values[path]) >= 0 and int(values[path]) < node.item_count: node.select(int(values[path]))
		elif node is BaseButton: node.set_pressed_no_signal(bool(values[path]))
