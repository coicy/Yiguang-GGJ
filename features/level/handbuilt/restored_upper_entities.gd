extends Node2D
## Scene-owned wiring for the hand-built upper section; no runtime JSON loading.

## Keys are button paths, values are arrays of the locally adapted cube paths.
@export var button_connections: Dictionary = {}
## Keys are ring paths, values are the supporting cube paths.
@export var attachment_connections: Dictionary = {}
## Only these attached rings wait for the supporting cube to arrive before use.
@export var hidden_until_arrival: Array[NodePath] = []


func _ready() -> void:
	for button_path: NodePath in button_connections:
		var button: TriggerButton = get_node(button_path) as TriggerButton
		var target_paths: Array = button_connections[button_path] as Array
		button.pressed.connect(_on_button_pressed.bind(target_paths))
	for ring_path: NodePath in attachment_connections:
		var ring: VineAnchor = get_node(ring_path) as VineAnchor
		var cube: MoveableCube = get_node(attachment_connections[ring_path]) as MoveableCube
		cube.bind_bottom_attachment(ring)
		if hidden_until_arrival.has(ring_path):
			ring.set_available(false)
		if not cube.motion_completed.is_connected(_on_attachment_motion_completed):
			cube.motion_completed.connect(_on_attachment_motion_completed)


func _on_button_pressed(_button: TriggerButton, _actor: Node2D, target_paths: Array) -> void:
	for target_path: NodePath in target_paths:
		var cube: MoveableCube = get_node(target_path) as MoveableCube
		cube.activate()


func _on_attachment_motion_completed(cube: MoveableCube) -> void:
	for child: Node in cube.get_children():
		if child is VineAnchor:
			(child as VineAnchor).set_available(true)
