extends SceneTree

const AbilityControllerScript = preload("res://features/abilities/ability_controller.gd")
const HUMANOID_FORM = preload("res://features/forms/humanoid.tres")
const MATURE_FORM = preload("res://features/forms/mature.tres")

var _requested_ability: StringName = &""


func _init() -> void:
	assert(_action_has_physical_key(&"ability_primary", KEY_Q))
	assert(_action_has_mouse_button(&"attack"))
	assert(_action_has_physical_key(&"move_up", KEY_W))
	assert(_action_has_physical_key(&"move_down", KEY_S))
	assert(_action_has_physical_key(&"absorb_resource", KEY_E))

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


func _action_has_physical_key(action: StringName, physical_keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == physical_keycode:
			return true
	return false


func _action_has_mouse_button(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			return true
	return false
