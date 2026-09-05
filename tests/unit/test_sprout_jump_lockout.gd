extends SceneTree

const MovementControllerScript = preload("res://features/player/movement_controller.gd")
const SPROUT: FormDefinition = preload("res://features/forms/sprout.tres")
const HUMANOID: FormDefinition = preload("res://features/forms/humanoid.tres")


func _init() -> void:
	var body := CharacterBody2D.new()
	var movement := MovementControllerScript.new() as MovementController
	movement.setup(body, SPROUT)

	movement.request_jump()
	assert(is_zero_approx(movement.jump_buffer_remaining()), "Sprout form must discard jump input.")
	movement._perform_jump()
	assert(is_zero_approx(body.velocity.y), "Sprout form must never receive jump velocity.")

	movement.set_form(HUMANOID)
	movement.request_jump()
	assert(movement.jump_buffer_remaining() > 0.0, "Humanoid form must retain jump buffering.")
	movement._perform_jump()
	assert(is_equal_approx(body.velocity.y, HUMANOID.jump_force), "Humanoid jump force must remain available.")

	movement.request_jump()
	movement.set_form(SPROUT)
	assert(is_zero_approx(movement.jump_buffer_remaining()), "Switching to sprout must clear a pending jump.")

	movement.free()
	body.free()
	quit()
