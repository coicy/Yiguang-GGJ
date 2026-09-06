class_name Player
extends CharacterBody2D
## Composition root: reads input and wires child components together.

signal resource_absorbed(kind: StringName, amount: float)

var _absorption_locked: bool = false
@onready var audio: PlayerAudio = %PlayerAudio

@onready var state_machine: StateMachine = %StateMachine
@onready var movement: MovementController = %Movement
@onready var form_controller: FormController = %FormController
@onready var visuals: PlayerVisuals = %Visuals
@onready var resources: ResourceController = %Resources
@onready var abilities: AbilityController = %Abilities
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var growth_cast: ShapeCast2D = %GrowthCast
@onready var leg_area: Area2D = %LegExtension
@onready var leg_collision_shape: CollisionShape2D = %LegCollisionShape


func _ready() -> void:
	resources.setup(form_controller)
	movement.setup(self, form_controller.get_current(), resources)
	state_machine.setup(self, movement, form_controller)
	abilities.setup(self, movement, form_controller, leg_area, leg_collision_shape)
	form_controller.set_switch_validator(_can_fit_form)
	_apply_form_shape(form_controller.get_current())
	visuals.set_form(form_controller.get_current())
	visuals.set_state(state_machine.current_state)
	form_controller.form_changed.connect(_on_form_changed)
	state_machine.state_changed.connect(_on_state_changed)
	abilities.ability_state_changed.connect(_on_ability_state_changed)
	add_to_group("player")
	audio.setup(self)


func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed("absorb_resource"):
		_absorption_locked = false
	resources.tick(delta)
	if Input.is_action_just_pressed(&"absorb_resource"):
		abilities.request_vine_climb()
	var leg_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	abilities.set_leg_extension_direction(leg_direction)
	abilities.tick(delta)
	var move_dir := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")

	if Input.is_action_just_pressed("jump"):
		movement.request_jump()
	if Input.is_action_just_released("jump"):
		movement.release_jump()

	state_machine.tick(delta, move_dir, jump_held)
	abilities.post_movement_update()
	visuals.set_motion(velocity)
	visuals.set_grounded(is_on_floor())
	visuals.set_leg_direction(abilities.get_leg_extension_direction())
	visuals.set_leg_path(abilities.get_leg_path())


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouse
	if mouse_event != null:
		var canvas_transform := get_viewport().get_canvas_transform()
		abilities.set_vine_aim_global_position(canvas_transform.affine_inverse() * mouse_event.position)
	if event.is_action_released("absorb_resource"):
		_absorption_locked = false
	if event.is_action_pressed("ability_primary"):
		abilities.toggle_primary()
	if event.is_action_pressed("absorb_resource") and not event.is_echo():
		abilities.request_vine_climb()


func _on_form_changed(form_id: StringName) -> void:
	_absorption_locked = Input.is_action_pressed("absorb_resource")
	cancel_actions()
	_apply_form_shape(form_controller.get_current())
	movement.set_form(form_controller.get_current())
	visuals.set_form(form_controller.get_current())
	visuals.set_state(state_machine.current_state)
	var signal_bus := get_node_or_null("/root/GlobalSignalBus")
	if signal_bus != null:
		signal_bus.player_form_changed.emit(form_id)


func _on_state_changed(previous: StringName, current: StringName) -> void:
	visuals.set_state(current)


func _on_ability_state_changed(_label: StringName) -> void:
	visuals.set_ability_state(abilities.is_rooted(), abilities.is_leg_extended(), abilities.is_vine_attached())
	visuals.set_vine_anchor(abilities.get_vine_anchor())
	visuals.set_leg_direction(abilities.get_leg_extension_direction())


func current_state() -> StringName:
	return state_machine.current_state


func current_form_id() -> StringName:
	return form_controller.get_current().id


func is_grounded() -> bool:
	return is_on_floor()


## Read after player physics: accepted control, never passive momentum.
func get_camera_intent() -> Vector2:
	var ability_intent: Vector2 = abilities.get_camera_intent()
	return ability_intent if not ability_intent.is_zero_approx() else movement.get_camera_intent()


## World bounds of the body only, including the current form and child transform.
func get_camera_body_rect() -> Rect2:
	if collision_shape == null or collision_shape.shape == null:
		return Rect2(global_position, Vector2.ZERO)
	return collision_shape.global_transform * collision_shape.shape.get_rect()


func can_root_here() -> bool:
	if not is_on_floor():
		return false
	for collision_index: int in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision == null or collision.get_normal().dot(Vector2.UP) < 0.7:
			continue
		var collider := collision.get_collider()
		if collider != null and collider.has_method(&"can_root"):
			return bool(collider.call(&"can_root"))
	return true


func is_absorbing_resource() -> bool:
	if not Input.is_action_pressed("absorb_resource"):
		_absorption_locked = false
		return false
	return not _absorption_locked


func requires_absorption_release() -> bool:
	return _absorption_locked and Input.is_action_pressed("absorb_resource")


func absorb_nutrition(amount: float) -> bool:
	var absorbed := resources.absorb_nutrition(amount)
	if absorbed:
		resource_absorbed.emit(&"nutrition", amount)
	return absorbed


func absorb_toxin(amount: float) -> bool:
	var absorbed := resources.absorb_toxin(amount)
	if absorbed:
		resource_absorbed.emit(&"toxin", amount)
	return absorbed


func enter_toxin(source: Object) -> void:
	resources.enter_toxin(source)


func exit_toxin(source: Object) -> void:
	resources.exit_toxin(source)


func apply_wind(force: float, delta: float) -> void:
	movement.apply_wind(force, delta)


func capture_state() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"form": current_form_id(),
		"resources": resources.snapshot(),
	}


func restore_state(saved: Dictionary) -> void:
	cancel_actions()
	form_controller.restore_form(StringName(saved.get("form", &"sprout")))
	resources.restore(saved.get("resources", {}))
	global_position = saved.get("position", global_position)
	velocity = saved.get("velocity", Vector2.ZERO)


func cancel_actions() -> void:
	abilities.cancel_all()


func play_death_animation() -> bool:
	return visuals.play_death()


func revive_animation() -> void:
	visuals.revive()


func _apply_form_shape(form: FormDefinition) -> void:
	if form == null:
		return
	collision_shape.shape = _create_form_collision_shape(form)
	collision_shape.position = Vector2(0.0, -form.collision_size.y * 0.5) + form.collision_offset


func _create_form_collision_shape(form: FormDefinition, inset: Vector2 = Vector2.ZERO) -> Shape2D:
	var size := Vector2(
		maxf(4.0, form.collision_size.x - inset.x),
		maxf(4.0, form.collision_size.y - inset.y)
	)
	match form.collision_shape_kind:
		FormDefinition.CollisionShapeKind.CIRCLE:
			var circle := CircleShape2D.new()
			circle.radius = minf(size.x, size.y) * 0.5
			return circle
		_:
			var capsule := CapsuleShape2D.new()
			capsule.radius = size.x * 0.5
			capsule.height = maxf(size.y, size.x)
			return capsule


func _can_fit_form(target: FormDefinition) -> bool:
	if target == null or not is_inside_tree():
		return false
	growth_cast.shape = _create_form_collision_shape(target, Vector2(2.0, 4.0))
	growth_cast.position = (
		Vector2(0.0, -target.collision_size.y * 0.5 - 2.0)
		+ target.collision_offset
	)
	growth_cast.force_shapecast_update()
	return not growth_cast.is_colliding()
