extends SceneTree

const BUTTON_SCENE: PackedScene = preload("res://features/level/whitebox_button.tscn")
const CUBE_SCENE: PackedScene = preload("res://features/level/moveable_cube.tscn")
const DAMAGE_MACHINE_SCENE: PackedScene = preload("res://features/level/damage_machine.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var button := BUTTON_SCENE.instantiate() as Area2D
	root.add_child(button)
	var press_count := [0]
	button.pressed.connect(func(_button: Area2D, _actor: Node2D) -> void: press_count[0] += 1)
	assert(bool(button.call(&"press")))
	assert(bool(button.call(&"is_pressed")))
	for _attempt: int in range(5):
		assert(not bool(button.call(&"press")), "A latched button must ignore repeated presses.")
	assert(press_count[0] == 1)
	button.call(&"reset_button")
	assert(not bool(button.call(&"is_pressed")))
	assert(bool(button.call(&"press")), "A restarted level must allow the button to trigger again.")

	var cube := CUBE_SCENE.instantiate() as Node2D
	cube.set(&"cube_size", Vector2(32.0, 64.0))
	cube.set(&"motion_speed", 720.0)
	cube.global_position = Vector2(480.0, 240.0)
	root.add_child(cube)
	await physics_frame
	assert(bool(cube.call(&"rotate_clockwise_about", Vector2(512.0, 304.0))))
	while bool(cube.call(&"is_moving")):
		await physics_frame
	assert(cube.global_position.is_equal_approx(Vector2(576.0, 272.0)))
	assert(is_equal_approx(cube.global_rotation, PI * 0.5))

	var platform := CUBE_SCENE.instantiate() as Node2D
	platform.set(&"cube_size", Vector2(128.0, 16.0))
	platform.set(&"motion_speed", 240.0)
	platform.global_position = Vector2(0.0, 100.0)
	root.add_child(platform)
	var rider := preload("res://features/player/player.tscn").instantiate() as Player
	rider.global_position = Vector2(64.0, 100.0)
	root.add_child(rider)
	for _step: int in range(12):
		await physics_frame
	assert(rider.is_on_floor(), "The player must stand on an AnimatableBody2D cube.")
	var rider_start_y := rider.global_position.y
	assert(bool(platform.call(&"move_top_left_to", Vector2(0.0, 148.0))))
	while bool(platform.call(&"is_moving")):
		await physics_frame
	assert(rider.global_position.y > rider_start_y + 20.0, "A rider must follow the moving cube instead of being left inside it.")
	assert(rider.is_on_floor(), "The rider must remain grounded after the cube stops.")

	var machine := DAMAGE_MACHINE_SCENE.instantiate() as Area2D
	machine.set(&"travel_distance", 8.0)
	machine.set(&"travel_speed", 64.0)
	root.add_child(machine)
	await physics_frame
	for _step: int in range(12):
		await physics_frame
	assert(machine.global_position.x <= 8.0 and machine.global_position.x >= -8.0)
	var killed_count := [0]
	machine.actor_killed.connect(func(_actor: Node2D) -> void: killed_count[0] += 1)
	var victim := Node2D.new()
	root.add_child(victim)
	machine.body_entered.emit(victim)
	assert(killed_count[0] == 1, "DamageMachine must kill on its first valid overlap.")

	victim.queue_free()
	machine.queue_free()
	rider.queue_free()
	platform.queue_free()
	cube.queue_free()
	button.queue_free()
	quit()
