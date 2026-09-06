class_name LevelEventBus
extends Node
## Routes named events between descendants of one level. It owns no gameplay state.

signal event_published(event_id: StringName)

const REQUEST_SIGNAL: StringName = &"level_event_requested"
const RECEIVE_METHOD: StringName = &"receive_level_event"

var _scope: Node
var _publishers: Array[Node] = []
var _receivers: Array[Node] = []
var _dispatching: Dictionary[StringName, bool] = {}


func _ready() -> void:
	# A standalone F6 launch stays inside this component rather than scanning Autoloads.
	var level_root: Node = get_parent()
	bind_scope(self if level_root == get_tree().root else level_root)


func bind_scope(level_root: Node) -> void:
	_clear_bindings()
	_scope = level_root
	if not is_inside_tree() or not is_instance_valid(_scope):
		return
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
		get_tree().node_removed.connect(_on_node_removed)
	_register_subtree(_scope)


func publish(event_id: StringName) -> void:
	if event_id == &"" or not is_inside_tree() or _dispatching.has(event_id):
		return
	# Prevent a synchronous feedback loop from recursively publishing the same event.
	_dispatching[event_id] = true
	event_published.emit(event_id)
	_dispatching.erase(event_id)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
		get_tree().node_removed.disconnect(_on_node_removed)
	_clear_bindings()
	_scope = null
	_dispatching.clear()
	# Reparenting/reinserting the same bus must rebuild its scene-local connections.
	request_ready()


func _register_subtree(node: Node) -> void:
	_register_node(node)
	for child: Node in node.get_children():
		_register_subtree(child)


func _register_node(node: Node) -> void:
	if not _belongs_to_scope(node):
		return
	if node.has_signal(REQUEST_SIGNAL) and not _publishers.has(node):
		var request := Signal(node, REQUEST_SIGNAL)
		if not request.is_connected(publish):
			request.connect(publish)
		_publishers.append(node)
	if node.has_method(RECEIVE_METHOD) and not _receivers.has(node):
		var receiver := Callable(node, RECEIVE_METHOD)
		if not event_published.is_connected(receiver):
			event_published.connect(receiver)
		_receivers.append(node)


func _unregister_node(node: Node) -> void:
	if is_instance_valid(node):
		if _publishers.has(node):
			var request := Signal(node, REQUEST_SIGNAL)
			if request.is_connected(publish):
				request.disconnect(publish)
		if _receivers.has(node):
			var receiver := Callable(node, RECEIVE_METHOD)
			if event_published.is_connected(receiver):
				event_published.disconnect(receiver)
	_publishers.erase(node)
	_receivers.erase(node)


func _clear_bindings() -> void:
	for node: Node in _publishers.duplicate():
		_unregister_node(node)
	for node: Node in _receivers.duplicate():
		_unregister_node(node)


func _refresh_bindings() -> void:
	if not is_inside_tree() or not is_instance_valid(_scope) or not _scope.is_inside_tree():
		return
	_clear_bindings()
	_register_subtree(_scope)


func _belongs_to_scope(node: Node) -> bool:
	if not is_instance_valid(_scope) or not node.is_inside_tree():
		return false
	var ancestor: Node = node
	while ancestor != null:
		if ancestor == _scope:
			return true
		# Nested levels keep their own event scope, even when event names match.
		for child: Node in ancestor.get_children():
			if child is LevelEventBus and child != self and child.is_inside_tree():
				return false
		ancestor = ancestor.get_parent()
	return false


func _on_node_added(node: Node) -> void:
	if node is LevelEventBus and node != self and is_instance_valid(_scope) and _scope.is_ancestor_of(node):
		# A new nested scope may take over nodes that were previously in this scope.
		_refresh_bindings()
	else:
		_register_node(node)


func _on_node_removed(node: Node) -> void:
	_unregister_node(node)
	if node is LevelEventBus and node != self:
		# Finish removal before taking over a branch whose nested bus was deleted.
		_refresh_bindings.call_deferred()
