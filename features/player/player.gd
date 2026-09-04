class_name Player
extends CharacterBody2D
## Composition root: reads input and wires child components together.

@onready var state_machine: StateMachine = %StateMachine
@onready var movement: MovementController = %Movement
@onready var form_controller: FormController = %FormController


func _ready() -> void:
	movement.setup(self, form_controller.get_current())
	state_machine.setup(self, movement, form_controller)
	form_controller.form_changed.connect(_on_form_changed)
	form_controller.form_changed.connect(movement.set_form)


func _physics_process(delta: float) -> void:
	var move_dir := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")

	if Input.is_action_just_pressed("jump"):
		movement.request_jump()
	if Input.is_action_just_released("jump"):
		movement.release_jump()

	state_machine.tick(delta, move_dir, jump_held)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_form"):
		form_controller.cycle_next()


func _on_form_changed(form_id: StringName) -> void:
	GlobalSignalBus.player_form_changed.emit(form_id)


func current_state() -> StringName:
	return state_machine.current_state


func current_form_id() -> StringName:
	return form_controller.get_current().id


func is_grounded() -> bool:
	return is_on_floor()
