class_name DebugOverlay
extends CanvasLayer
## Read-only screen overlay showing live player state for feel tuning.
## Toggle visibility with the debug_toggle action (F3).

@export var target: Player

@onready var label: Label = %DebugLabel


func _ready() -> void:
	visible = OS.is_debug_build()
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Player
	if target == null:
		label.text = "No target"
		return
	label.text = "state: %s\nform: %s\nvel: (%.1f, %.1f)\nfloor: %s\ncoyote: %.3f\nbuffer: %.3f" % [
		target.current_state(),
		target.current_form_id(),
		target.velocity.x,
		target.velocity.y,
		target.is_grounded(),
		target.movement.coyote_remaining(),
		target.movement.jump_buffer_remaining(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
