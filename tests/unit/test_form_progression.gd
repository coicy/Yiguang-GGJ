extends SceneTree

const FormControllerScript = preload("res://features/forms/form_controller.gd")
const SPROUT: FormDefinition = preload("res://features/forms/sprout.tres")
const HUMANOID: FormDefinition = preload("res://features/forms/humanoid.tres")
const MATURE: FormDefinition = preload("res://features/forms/mature.tres")


func _init() -> void:
	var controller := FormControllerScript.new()
	controller.forms = [SPROUT, HUMANOID, MATURE]
	controller.default_form_id = &"sprout"
	controller._ready()

	assert(controller.get_current().id == &"sprout")
	assert(controller.peek_withered_form() == null)
	assert(controller.peek_grown_form().id == &"humanoid")
	assert(controller.grow())
	assert(controller.get_current().id == &"humanoid")
	assert(controller.grow())
	assert(controller.get_current().id == &"mature")
	assert(not controller.grow())
	assert(controller.get_current().id == &"mature")
	assert(controller.wither())
	assert(controller.get_current().id == &"humanoid")
	assert(controller.restore_form(&"sprout"))
	assert(controller.get_current().id == &"sprout")

	controller.set_switch_validator(func(_target: FormDefinition) -> bool: return false)
	assert(not controller.grow())
	assert(controller.get_current().id == &"sprout")
	assert(controller.restore_form(&"humanoid"))
	assert(controller.get_current().id == &"humanoid")

	assert(SPROUT.collision_size == Vector2(16.0, 16.0))
	assert(SPROUT.growth_threshold == 100.0)
	assert(HUMANOID.can_root and HUMANOID.can_extend_legs)
	assert(HUMANOID.growth_threshold == 120.0)
	assert(MATURE.can_use_vine and MATURE.can_glide)
	assert(MATURE.growth_threshold == 0.0)

	controller.free()
	quit()
