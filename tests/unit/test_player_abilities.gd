extends SceneTree

const AbilityControllerScript = preload("res://features/abilities/ability_controller.gd")
const HUMANOID_FORM = preload("res://features/forms/humanoid.tres")
const MATURE_FORM = preload("res://features/forms/mature.tres")

var _requested_ability: StringName = &""


func _init() -> void:
	var controller := AbilityControllerScript.new()
	controller.setup(HUMANOID_FORM)
	assert(not controller.is_rooted())

	assert(controller.toggle_primary())
	assert(controller.is_rooted())
	controller.set_leg_extension_direction(Vector2.UP)
	assert(controller.get_leg_extension_direction() == Vector2.UP)

	assert(controller.toggle_primary())
	assert(not controller.is_rooted())
	assert(controller.get_leg_extension_direction() == Vector2.ZERO)

	controller.primary_ability_requested.connect(_on_primary_ability_requested)
	controller.setup(MATURE_FORM)
	assert(controller.toggle_primary())
	assert(_requested_ability == &"vine_pull")
	assert(not controller.is_rooted())
	controller.free()
	quit()


func _on_primary_ability_requested(ability_id: StringName) -> void:
	_requested_ability = ability_id
