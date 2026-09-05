class_name WalkTestActor
extends CharacterBody2D
## Minimal physics actor used only by the audio test scene.

signal footstep_requested(cue: StringName)

@export var move_speed: float = 220.0
@export var gravity: float = 1200.0
@export var footstep_interval: float = 0.32

var _step_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var move_direction := Input.get_axis(&"move_left", &"move_right")
	velocity.x = move_toward(velocity.x, move_direction * move_speed, 1400.0 * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if is_on_floor() and absf(velocity.x) > 20.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = footstep_interval
			footstep_requested.emit(&"step_grass")
	else:
		_step_timer = 0.0

