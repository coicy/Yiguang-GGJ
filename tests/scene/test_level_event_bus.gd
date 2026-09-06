extends SceneTree

const EVENT_BUS_SCENE: PackedScene = preload("res://features/level/level_event_bus.tscn")
const CUBE_SCENE: PackedScene = preload("res://features/level/moveable_cube.tscn")
const BUTTON_SCENE: PackedScene = preload("res://features/level/handbuilt/trigger_button.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://features/level/handbuilt/moving_platform.tscn")
const DOOR_SCENE: PackedScene = preload("res://features/level/whitebox_door.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")
const MOTION_FRAME_LIMIT: int = 180

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_contact_and_filters()
	await _test_receiver_types()
	await _test_scope_isolation_and_reparenting()
	await _test_nested_scope_lifecycle()
	await _test_bus_replacement_and_reentrancy()
	await _test_main_level_reload()
	if _failures == 0:
		print("PASS: level events, real button contact, receiver filters, fan-out, scope isolation, lifecycle and main-level reload")
	else:
		push_error("Level event bus checks failed: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_contact_and_filters() -> void:
	var stage := _make_stage()
	root.add_child(stage)
	var bus := stage.get_node("LevelEventBus") as LevelEventBus
	var matching := _make_cube(&"lift")
	matching.position = Vector2(240.0, 160.0)
	matching.movement_direction = Vector2.UP
	stage.add_child(matching)
	var unmatched := _make_cube(&"other")
	unmatched.position = Vector2(340.0, 160.0)
	stage.add_child(unmatched)
	var unconfigured := _make_cube(&"")
	unconfigured.position = Vector2(440.0, 160.0)
	stage.add_child(unconfigured)
	var button := _make_button(&"lift")
	button.position = Vector2(80.0, 160.0)
	stage.add_child(button)
	var publications: Array[StringName] = []
	bus.event_published.connect(func(event_id: StringName) -> void: publications.append(event_id))
	var actor := _make_actor()
	actor.position = button.position + Vector2(8.0, 8.0)
	stage.add_child(actor)
	await _frames(4)
	_check(not button.is_pressed() and not matching.is_activated(), "A non-player overlap must not publish a button event.")
	actor.position = Vector2.ZERO
	await _frames(3)
	actor.add_to_group(&"player")
	actor.position = button.position + Vector2(8.0, 8.0)
	await _frames(4)
	_check(button.is_pressed() and matching.is_activated(), "A real player-group overlap must activate the matching receiver.")
	_check(not unmatched.is_activated() and not unconfigured.is_activated(), "Different and empty receiver events must remain inactive.")
	_check(publications == [&"lift"], "The first player contact must publish exactly one configured event.")
	await _wait_for_motion(matching)
	_check(matching.position.distance_to(Vector2(240.0, 112.0)) < 0.02, "The event must preserve the cube's configured upward travel.")
	actor.position = Vector2.ZERO
	await _frames(3)
	actor.position = button.position + Vector2(8.0, 8.0)
	await _frames(4)
	_check(publications.size() == 1 and not matching.is_moving(), "Repeated overlap must keep the button and cube one-shot semantics.")
	var late_receiver := _make_cube(&"lift")
	late_receiver.position = Vector2(540.0, 160.0)
	stage.add_child(late_receiver)
	await _frames(2)
	_check(not late_receiver.is_activated(), "New receivers must not replay previous events.")
	var empty_button := _make_button(&"")
	empty_button.position = Vector2(640.0, 160.0)
	stage.add_child(empty_button)
	await _frames(2)
	_check(empty_button.press(), "An unconfigured button may still latch visually.")
	bus.publish(&"")
	_check(publications.size() == 1 and not unconfigured.is_activated(), "Empty events must not be published or activate unconfigured receivers.")
	bus.publish(&"lift")
	_check(late_receiver.is_activated(), "A dynamically added receiver must receive subsequent events.")
	stage.queue_free()
	await _frames(2)


func _test_receiver_types() -> void:
	# Place the bus last so its ready-time scan must discover existing components.
	var stage := Node2D.new()
	var cube := _make_cube(&"all")
	cube.name = "Cube"
	cube.position = Vector2(240.0, 100.0)
	stage.add_child(cube)
	var door := DOOR_SCENE.instantiate() as WhiteboxDoor
	door.activation_event = &"all"
	door.position = Vector2(340.0, 100.0)
	door.open_offset = Vector2(0.0, -32.0)
	door.motion_speed = 720.0
	door.startup_shake_duration = 0.0
	stage.add_child(door)
	var platform := PLATFORM_SCENE.instantiate() as MovingPlatform
	platform.activation_event = &"all"
	platform.position = Vector2(440.0, 100.0)
	platform.destination_offset = Vector2(24.0, 0.0)
	platform.travel_duration = 0.05
	stage.add_child(platform)
	var motion_cube := _make_cube(&"")
	motion_cube.name = "MotionCube"
	motion_cube.position = Vector2(640.0, 100.0)
	stage.add_child(motion_cube)
	var mechanism := MechanismMotion.new()
	mechanism.activation_event = &"all"
	mechanism.targets = [NodePath("../MotionCube")]
	mechanism.destination_offset = Vector2(-24.0, 0.0)
	stage.add_child(mechanism)
	var button := _make_button(&"all")
	stage.add_child(button)
	stage.add_child(EVENT_BUS_SCENE.instantiate())
	root.add_child(stage)
	await _frames(2)
	_check(button.press(), "The shared button must accept its first activation.")
	_check(cube.is_activated() and door.is_activated() and platform.is_activated() and mechanism.is_activated(),
		"One event must activate cubes, inherited doors, moving platforms and mechanism actions together.")
	await _wait_for_motion(cube)
	await _wait_for_motion(door)
	await _wait_for_motion(motion_cube)
	_check(door.is_open() and door.position.distance_to(Vector2(340.0, 68.0)) < 0.02, "A door event must preserve its existing open-offset behavior.")
	_check(platform.has_completed_motion(), "A moving-platform receiver must complete its configured action.")
	_check((platform.get_node("Body") as AnimatableBody2D).position.distance_to(Vector2(24.0, 0.0)) < 0.02,
		"A moving-platform event must reach its configured destination.")
	_check(motion_cube.position.distance_to(Vector2(616.0, 100.0)) < 0.02, "A mechanism event must invoke its locally owned cube command.")
	stage.queue_free()
	await _frames(2)


func _test_scope_isolation_and_reparenting() -> void:
	var stage_a := _make_stage()
	var stage_b := _make_stage()
	stage_b.position = Vector2(2000.0, 0.0)
	root.add_child(stage_a)
	root.add_child(stage_b)
	var bus_a := stage_a.get_node("LevelEventBus") as LevelEventBus
	var bus_b := stage_b.get_node("LevelEventBus") as LevelEventBus
	var cube_a := _make_cube(&"same")
	stage_a.add_child(cube_a)
	var cube_b := _make_cube(&"same")
	stage_b.add_child(cube_b)
	await _frames(2)
	bus_a.publish(&"same")
	_check(cube_a.is_activated() and not cube_b.is_activated(), "Identical event names in separate levels must remain isolated.")
	await _wait_for_motion(cube_a)
	cube_a.reset_platform()
	var branch := Node2D.new()
	var button := _make_button(&"same")
	branch.add_child(button)
	stage_a.add_child(branch)
	await _frames(2)
	branch.reparent(stage_b, false)
	await _frames(2)
	_check(button.press(), "A reparented button must remain usable.")
	_check(not cube_a.is_activated() and cube_b.is_activated(), "Reparenting a sender subtree must reconnect only to its new level.")
	await _wait_for_motion(cube_b)
	cube_b.reset_platform()
	cube_a.reparent(stage_b, false)
	await _frames(2)
	bus_a.publish(&"same")
	_check(not cube_a.is_activated() and not cube_b.is_activated(), "A moved receiver must unsubscribe from its previous level.")
	bus_b.publish(&"same")
	_check(cube_a.is_activated() and cube_b.is_activated(), "A moved receiver must subscribe to its new level.")
	await _wait_for_motion(cube_a)
	await _wait_for_motion(cube_b)
	cube_a.reset_platform()
	cube_b.reset_platform()
	stage_b.remove_child(cube_a)
	branch.remove_child(button)
	await _frames(2)
	_check(not bus_b.event_published.is_connected(cube_a.receive_level_event), "Removing a receiver must remove its signal subscription.")
	button.reset_button()
	button.press()
	_check(not cube_b.is_activated(), "A detached sender must not publish into its former level.")
	cube_a.free()
	button.free()
	branch.queue_free()
	await _frames(2)
	bus_b.publish(&"same")
	_check(cube_b.is_activated(), "Destroyed senders and receivers must not break remaining subscriptions.")
	stage_a.queue_free()
	stage_b.queue_free()
	await _frames(2)


func _test_nested_scope_lifecycle() -> void:
	var stage := _make_stage()
	var outer_cube := _make_cube(&"shared")
	outer_cube.position = Vector2(240.0, 100.0)
	stage.add_child(outer_cube)
	var nested_level := Node2D.new()
	nested_level.position = Vector2(1000.0, 0.0)
	var inner_cube := _make_cube(&"shared")
	nested_level.add_child(inner_cube)
	stage.add_child(nested_level)
	root.add_child(stage)
	await _frames(2)
	var outer_bus := stage.get_node("LevelEventBus") as LevelEventBus
	outer_bus.publish(&"shared")
	_check(outer_cube.is_activated() and inner_cube.is_activated(), "Descendants without their own bus must belong to the outer scope.")
	await _wait_for_motion(outer_cube)
	await _wait_for_motion(inner_cube)
	outer_cube.reset_platform()
	inner_cube.reset_platform()
	var inner_bus := EVENT_BUS_SCENE.instantiate() as LevelEventBus
	nested_level.add_child(inner_bus)
	await _frames(2)
	outer_bus.publish(&"shared")
	_check(outer_cube.is_activated() and not inner_cube.is_activated(), "Adding a nested bus must remove that branch from outer subscriptions.")
	await _wait_for_motion(outer_cube)
	outer_cube.reset_platform()
	inner_bus.publish(&"shared")
	_check(inner_cube.is_activated() and not outer_cube.is_activated(), "A nested event must stay isolated from the outer level despite matching names.")
	await _wait_for_motion(inner_cube)
	inner_cube.reset_platform()
	nested_level.remove_child(inner_bus)
	inner_bus.free()
	await _frames(2)
	outer_bus.publish(&"shared")
	_check(outer_cube.is_activated() and inner_cube.is_activated(), "Removing a nested bus must return its surviving branch to the nearest outer scope.")
	stage.queue_free()
	await _frames(2)


func _test_bus_replacement_and_reentrancy() -> void:
	var stage := _make_stage()
	var button := _make_button(&"lift")
	stage.add_child(button)
	var cube := _make_cube(&"lift")
	cube.position = Vector2(240.0, 100.0)
	stage.add_child(cube)
	root.add_child(stage)
	await _frames(2)
	var bus := stage.get_node("LevelEventBus") as LevelEventBus
	stage.remove_child(bus)
	button.press()
	_check(not cube.is_activated(), "Removing the bus must disconnect its still-live buttons and receivers.")
	stage.add_child(bus)
	await _frames(2)
	button.reset_button()
	button.press()
	_check(cube.is_activated(), "Re-adding the same bus instance must restore its scope and subscriptions.")
	await _wait_for_motion(cube)
	cube.reset_platform()
	stage.remove_child(bus)
	bus.free()
	var replacement := EVENT_BUS_SCENE.instantiate() as LevelEventBus
	stage.add_child(replacement)
	await _frames(2)
	_check(not cube.is_activated(), "A replacement bus must not replay an earlier button press.")
	var publications: Array[int] = [0]
	replacement.event_published.connect(func(event_id: StringName) -> void:
		publications[0] += 1
		if publications[0] < 4:
			replacement.publish(event_id)
	)
	button.reset_button()
	button.press()
	_check(cube.is_activated(), "A replacement bus must discover and reconnect existing components.")
	_check(publications[0] == 1, "Synchronous publication of the same event must not recurse.")
	stage.queue_free()
	await _frames(2)


func _test_main_level_reload() -> void:
	for _reload_index: int in range(2):
		var level := LEVEL_SCENE.instantiate() as Node2D
		root.add_child(level)
		var player := level.get_node_or_null("Actors/Player") as Player
		if player != null:
			player.set_physics_process(false)
		await _frames(2)
		var bus := level.get_node_or_null("LevelEventBus") as LevelEventBus
		_check(bus != null and bus.is_node_ready() and bus.get_parent() == level,
			"Each production level instance must initialize its own event bus independently of its current mechanisms.")
		level.queue_free()
		await _frames(3)


func _make_stage() -> Node2D:
	var stage := Node2D.new()
	stage.add_child(EVENT_BUS_SCENE.instantiate())
	return stage


func _make_cube(event_id: StringName) -> MoveableCube:
	var cube := CUBE_SCENE.instantiate() as MoveableCube
	cube.activation_event = event_id
	cube.startup_shake_duration = 0.0
	cube.motion_speed = 720.0
	cube.move_distance = 48.0
	return cube


func _make_button(event_id: StringName) -> TriggerButton:
	var button := BUTTON_SCENE.instantiate() as TriggerButton
	button.event_id = event_id
	return button


func _make_actor() -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8.0, 8.0)
	collider.shape = shape
	actor.add_child(collider)
	return actor


func _wait_for_motion(cube: MoveableCube) -> void:
	for _step: int in range(MOTION_FRAME_LIMIT):
		if not cube.is_moving():
			await _frames(2)
			return
		await physics_frame
	_check(false, "Motion did not finish within %d physics frames." % MOTION_FRAME_LIMIT)
	cube.stop_at_target()
	await _frames(2)


func _frames(count: int) -> void:
	for _step: int in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
