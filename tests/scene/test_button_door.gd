extends SceneTree

const DOOR_SCENE: PackedScene = preload("res://features/level/whitebox_door.tscn")
const BUTTON_SCENE: PackedScene = preload("res://features/level/whitebox_button.tscn")
const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/json_whitebox_level.tscn")
const B1 := "0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d"
const C1 := "14f1b660-96d0-11f1-ba31-2fb3210b8ae8"
const DOOR := "e1e9a7b0-96d0-11f1-be70-0dbca0ba9a32"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_contact_slide_and_collision()
	await _test_rotation_and_local_direction()
	await _test_main_level_and_reload()
	print("PASS: real player contact, door collision, slide/rotation, latch, B1/C1 and reload")
	await process_frame
	await create_timer(0.1).timeout
	quit()


func _test_contact_slide_and_collision() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var door := DOOR_SCENE.instantiate() as WhiteboxDoor
	door.position = Vector2(320.0, 200.0)
	door.cube_size = Vector2(32.0, 64.0)
	door.open_offset = Vector2(0.0, -96.0)
	stage.add_child(door)
	var button := BUTTON_SCENE.instantiate() as WhiteboxButton
	button.position = Vector2(100.0, 200.0)
	stage.add_child(button)
	var press_count: Array[int] = [0]
	var opened_count: Array[int] = [0]
	button.pressed.connect(func(_button: WhiteboxButton, _actor: Node2D) -> void:
		press_count[0] += 1
		assert(door.open())
	)
	door.opened.connect(func() -> void: opened_count[0] += 1)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(32.0, 200.0)
	stage.add_child(player)
	player.set_physics_process(false)
	await _frames(4)
	assert(not button.is_pressed() and not door.is_open())
	assert(_ray_hits(door, Vector2(300.0, 232.0), Vector2(372.0, 232.0)))

	# A non-player on the same collision layer must not operate the button.
	var other := CharacterBody2D.new()
	other.collision_layer = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8.0, 8.0)
	collision.shape = shape
	other.add_child(collision)
	other.position = button.position + Vector2(8.0, 8.0)
	stage.add_child(other)
	await _frames(4)
	assert(not button.is_pressed() and not door.is_moving())
	other.queue_free()

	player.position = button.position + Vector2(8.0, 12.0)
	await _frames(4)
	assert(button.is_pressed() and door.is_moving(), "Actual Area2D overlap must start the door.")
	assert(press_count[0] == 1)
	assert(not door.open(), "A second command must not add another movement.")
	assert(door.collision_layer == 1 and not (door.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	await _wait_for_motion(door)
	assert(door.is_open() and opened_count[0] == 1)
	assert(door.position.is_equal_approx(Vector2(320.0, 104.0)))
	assert(not _ray_hits(door, Vector2(300.0, 232.0), Vector2(372.0, 232.0)), "The original passage must be clear.")
	assert(_ray_hits(door, Vector2(300.0, 136.0), Vector2(372.0, 136.0)), "Collision must follow the visible door.")
	player.position = Vector2(32.0, 200.0)
	await _frames(4)
	player.position = button.position + Vector2(8.0, 12.0)
	await _frames(4)
	assert(press_count[0] == 1 and opened_count[0] == 1 and not door.is_moving())
	assert(door.position.is_equal_approx(Vector2(320.0, 104.0)))
	stage.queue_free()
	await _frames(2)


func _test_rotation_and_local_direction() -> void:
	var stage := Node2D.new()
	stage.position = Vector2(500.0, 200.0)
	stage.rotation = 0.25
	root.add_child(stage)
	for degrees: float in [90.0, -90.0]:
		var door := DOOR_SCENE.instantiate() as WhiteboxDoor
		door.position = Vector2(40.0, 60.0)
		door.cube_size = Vector2(16.0, 64.0)
		door.opening_mode = WhiteboxDoor.OpeningMode.ROTATE
		door.hinge_offset = Vector2(0.0, 64.0)
		door.opening_degrees = degrees
		stage.add_child(door)
		await _frames(2)
		var pivot := door.to_global(door.hinge_offset)
		var start_rotation := door.global_rotation
		assert(door.open())
		for _step: int in range(240):
			await physics_frame
			assert(door.to_global(door.hinge_offset).distance_to(pivot) < 0.02, "The hinge must stay fixed throughout rotation.")
			if not door.is_moving():
				break
		await _frames(2)
		assert(door.is_open() and not door.is_moving())
		assert(is_equal_approx(angle_difference(start_rotation, door.global_rotation), deg_to_rad(degrees)))
		assert(not door.open())
		door.queue_free()
		await _frames(2)
	var sliding_door := DOOR_SCENE.instantiate() as WhiteboxDoor
	sliding_door.open_offset = Vector2(64.0, 0.0)
	stage.add_child(sliding_door)
	await _frames(2)
	var target := sliding_door.to_global(sliding_door.open_offset)
	assert(sliding_door.open())
	await _wait_for_motion(sliding_door)
	assert(sliding_door.global_position.is_equal_approx(target), "Slide direction must respect the placed scene transform.")
	stage.queue_free()
	await _frames(2)


func _test_main_level_and_reload() -> void:
	for _run_index: int in range(2):
		var level := LEVEL_SCENE.instantiate() as JsonWhiteboxLevel
		root.add_child(level)
		var player := level.get_node("Player") as Player
		player.set_physics_process(false)
		var door := level.get_entity(DOOR) as WhiteboxDoor
		var button := level.get_entity(B1) as WhiteboxButton
		await _frames(4)
		assert(not door.is_open() and not button.is_pressed())
		assert(door.get_world_rect().is_equal_approx(Rect2(624.0, 432.0, 32.0, 32.0)))
		var probe := PhysicsRayQueryParameters2D.create(Vector2(610.0, 448.0), Vector2(670.0, 448.0), 1)
		assert(not door.get_world_2d().direct_space_state.intersect_ray(probe).is_empty())
		player.global_position = button.global_position + Vector2(8.0, 12.0)
		await _frames(4)
		assert(button.is_pressed() and door.is_moving())
		assert((level.get_entity(C1) as MoveableCube).is_moving(), "B1 must still control its original platform.")
		await _wait_for_motion(door)
		assert(door.is_open())
		assert(door.get_world_2d().direct_space_state.intersect_ray(probe).is_empty(), "No static ground may remain inside the opened doorway.")
		assert(level.get_data_issues().is_empty())
		level.queue_free()
		await _frames(3)


func _ray_hits(door: WhiteboxDoor, start: Vector2, finish: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(start, finish, 1)
	var hit := door.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == door


func _wait_for_motion(door: WhiteboxDoor) -> void:
	for _step: int in range(360):
		if not door.is_moving():
			await _frames(2)
			return
		await physics_frame
	assert(false, "Door did not finish within six seconds.")


func _frames(count: int) -> void:
	for _step: int in range(count):
		await physics_frame
