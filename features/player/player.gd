class_name Player
extends CharacterBody2D
## Composition root: reads input and wires child components together.

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


func _physics_process(delta: float) -> void:
	resources.tick(delta)
	var leg_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	abilities.set_leg_extension_direction(leg_direction)
	abilities.tick(delta)
	visuals.set_leg_direction(abilities.get_leg_extension_direction())
	visuals.set_leg_path(abilities.get_leg_path())
	var move_dir := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")

	if Input.is_action_just_pressed("jump"):
		movement.request_jump()
	if Input.is_action_just_released("jump"):
		movement.release_jump()

	state_machine.tick(delta, move_dir, jump_held)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_primary"):
		abilities.toggle_primary()


func _on_form_changed(form_id: StringName) -> void:
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
	return Input.is_action_pressed("absorb_resource")


func absorb_nutrition(amount: float) -> bool:
	return resources.absorb_nutrition(amount)


func absorb_toxin(amount: float) -> bool:
	return resources.absorb_toxin(amount)


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


func _apply_form_shape(form: FormDefinition) -> void:
	if form == null:
		return
	_apply_collision_shape(form.collision_size)


func _apply_collision_shape(size: Vector2) -> void:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	shape.size = size
	collision_shape.position = Vector2(0.0, -size.y * 0.5)


func _can_fit_form(target: FormDefinition) -> bool:
	if target == null or not is_inside_tree():
		return false
	return _can_fit_shape(target.collision_size)


func _can_fit_shape(size: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var probe := RectangleShape2D.new()
	probe.size = Vector2(
		maxf(4.0, size.x - 2.0),
		maxf(4.0, size.y - 4.0)
	)
	growth_cast.shape = probe
	growth_cast.position = Vector2(0.0, -size.y * 0.5 - 2.0)
	growth_cast.force_shapecast_update()
	return not growth_cast.is_colliding()
