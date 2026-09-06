extends SceneTree
## Production completion coverage. Final-button placement is a contact fixture,
## not evidence that the entire level can be traversed from its spawn point.

const LEVEL_SCENE := "res://scenes/levels/Level_main.tscn"
const APP_SCENE := "res://scenes/app/main.tscn"
const UPPER_PATH := "Level02/Geometry/UpperEntities"
const BUTTON_PATH := UPPER_PATH + "/Buttons/Button_59bb7020"
const CUBE_PATH := UPPER_PATH + "/Cubes/Cube_de356dc0"

var _checks: int = 0
var _failures: int = 0
var _local_events: Array[bool] = []
var _global_events: Array[StringName] = []
var _contact_count: int = 0
var _motion_count: int = 0
var _latched_during_press: bool = false
var _checkpoint_events: int = 0
var _toxin_events: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GlobalSignalBus").connect(&"level_completed", _on_global_completion)
	await _test_completion_filters()
	await _test_standalone_completion_and_restart()
	await _test_app_completion_and_restart()
	paused = false
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	await create_timer(0.1, true).timeout
	print("Main completion: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_completion_filters() -> void:
	var scene := await _load_scene(LEVEL_SCENE)
	var level: Variant = _get_level(scene, false)
	if level == null:
		return
	var player := level.get_node("Actors/Player") as Player
	player.set_physics_process(false)
	_watch_level(level)
	var global_before := _global_events.size()
	var target := level.get_node(BUTTON_PATH) as TriggerButton
	var other_buttons: int = 0
	for child: Node in target.get_parent().get_children():
		if child is TriggerButton and child != target:
			(child as TriggerButton).press(player)
			_check(not level.is_completed(), "%s must not finish the level" % child.name)
			other_buttons += 1
	_check(other_buttons > 0, "The production negative case must exercise other buttons")
	# Even a node in the player group cannot impersonate this level's actual player.
	var impostor := Node2D.new()
	level.add_child(impostor)
	impostor.add_to_group(&"player")
	target.pressed.emit(target, impostor)
	target.pressed.emit(target, null)
	await process_frame
	_check(not level.is_completed() and not paused, "Non-player signals must not complete or pause")
	_check(_local_events.is_empty() and _global_events.size() == global_before,
		"Rejected actors and unrelated buttons must emit no completion event")
	impostor.queue_free()


func _test_standalone_completion_and_restart() -> void:
	var scene := await _load_scene(LEVEL_SCENE)
	var level: Variant = _get_level(scene, false)
	if level == null:
		return
	_check(not paused, "F6 Level_main must start without an application menu pause")
	if not await _complete_by_contact(level):
		return
	await _check_completed_run(level)
	var old_scene_id := scene.get_instance_id()
	# Use only keyboard input here: a UI fallback would mask a broken R shortcut.
	_send_restart_key(true)
	_send_restart_key(false)
	await _wait_for_reload(old_scene_id, LEVEL_SCENE)
	var next_level: Variant = _get_level(current_scene, false)
	if next_level != null:
		_check_fresh_run(next_level)
		_check(not paused, "Standalone restart must resume gameplay")


func _test_app_completion_and_restart() -> void:
	var scene := await _load_scene(APP_SCENE)
	var main: Variant = scene
	var level: Variant = _get_level(scene, true)
	if main == null or level == null:
		_check(false, "The default entry must load the production Main application")
		return
	_check(paused and main.start_screen.visible, "F5 must begin at its paused start menu")
	var menu_time: float = level.elapsed_time()
	await create_timer(0.08, true).timeout
	_check(is_equal_approx(menu_time, level.elapsed_time()), "The start menu must freeze the run clock")
	main.start_screen.start_button.pressed.emit()
	await create_timer(0.35, true).timeout
	_check(main.opening_storyboard.visible and paused, "Start must show the paused introduction")
	main.opening_storyboard.skip_button.pressed.emit()
	await process_frame
	await process_frame
	_check(not paused and not main.start_screen.visible, "Skipping the introduction must start gameplay")
	if not await _complete_by_contact(level):
		return
	await _check_completed_run(level)
	var overlay := level.get_node("Interface/CompletionOverlay") as CompletionOverlay
	var old_scene_id := scene.get_instance_id()
	overlay.restart_button.pressed.emit()
	overlay.restart_button.pressed.emit()
	await _wait_for_reload(old_scene_id, APP_SCENE)
	var next_main: Variant = current_scene
	var next_level: Variant = _get_level(current_scene, true)
	if next_main != null and next_level != null:
		_check_fresh_run(next_level)
		_check(paused and next_main.start_screen.visible and not next_main.start_screen.start_button.disabled,
			"Application restart must return to an enabled, paused start menu")


func _complete_by_contact(level: Variant) -> bool:
	_watch_level(level)
	var player := level.get_node("Actors/Player") as Player
	var button := level.get_node(BUTTON_PATH) as TriggerButton
	var cube := level.get_node(CUBE_PATH) as MoveableCube
	var global_before := _global_events.size()
	_contact_count = 0
	_motion_count = 0
	_latched_during_press = false
	button.body_entered.connect(_on_contact.bind(player))
	button.pressed.connect(_on_target_pressed.bind(level))
	cube.motion_started.connect(_on_motion_started)
	_check(not button.is_pressed() and not cube.is_activated(), "A fresh final mechanism must be inactive")
	player.cancel_actions()
	player.velocity = Vector2.ZERO
	# Derive placement from the live button, preserving hand-edited level geometry.
	var button_shape := button.get_node("CollisionShape2D") as CollisionShape2D
	var trigger_rect := button_shape.shape.get_rect()
	player.global_position = button_shape.to_global(Vector2(trigger_rect.get_center().x, trigger_rect.position.y - 32.0))
	player.reset_physics_interpolation()
	_check(not button.overlaps_body(player), "The fixture must begin outside the final trigger")
	for frame: int in range(90):
		await physics_frame
		await process_frame
		if level.is_completed():
			break
	if not _check(level.is_completed(), "A real falling player contact must complete the production level"):
		return false
	await process_frame
	_check(_contact_count == 1 and button.is_pressed(), "Completion must come from the actual body_entered path")
	_check(_latched_during_press, "Completion must latch synchronously in the button signal")
	_check(_local_events == [true], "The local completion signal must fire exactly once")
	_check(_global_events.size() == global_before + 1 and _global_events.back() == &"level_main",
		"The deferred global completion must identify level_main exactly once")
	_check(cube.is_activated() and _motion_count == 1, "The original Cube_de356dc0 activation must survive completion wiring")
	return true


func _check_completed_run(level: Variant) -> void:
	var player := level.get_node("Actors/Player") as Player
	var button := level.get_node(BUTTON_PATH) as TriggerButton
	var overlay := level.get_node("Interface/CompletionOverlay") as CompletionOverlay
	_check(paused and overlay.visible and overlay.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Completion must show a result overlay that still processes while paused")
	_check(player.velocity.is_zero_approx() and not player.abilities.is_rooted() and not player.movement.is_vine_attached(),
		"Completion must cancel motion and active abilities")
	var finish_time: float = level.elapsed_time()
	var finish_deaths: int = level.death_count()
	var finish_position := player.global_position
	var finish_resources := player.resources.snapshot()
	var global_before := _global_events.size()
	var result_text := overlay.result_label.text
	_checkpoint_events = 0
	_toxin_events = 0
	level.checkpoint_registered.connect(_on_checkpoint)
	player.resources.toxin_changed.connect(_on_toxin_changed)
	# Repeat the public source event and lifecycle callbacks to cover same-frame races.
	button.pressed.emit(button, player)
	button.reset_button()
	button.press(player)
	level.call(&"_on_actor_killed", player)
	level.call(&"_on_checkpoint_reached", player, finish_position + Vector2(90.0, 0.0))
	for node: Node in get_nodes_in_group(&"handbuilt_toxin_zones"):
		if node is ToxinZone:
			level.call(&"_on_toxin_zone_entered", player, node)
			level.call(&"_on_toxin_zone_exited", player, node)
			break
	level.call(&"_process", 2.0)
	await create_timer(0.12, true).timeout
	_check(_local_events == [true] and _global_events.size() == global_before and _motion_count == 1,
		"Repeated trigger signals must not emit completion or start its cube again")
	_check(is_equal_approx(level.elapsed_time(), finish_time) and level.death_count() == finish_deaths,
		"Completed run time and death count must remain frozen")
	_check(player.global_position.is_equal_approx(finish_position) and player.resources.snapshot() == finish_resources,
		"Late hazards and poison must not alter the completed player")
	_check(_checkpoint_events == 0 and _toxin_events == 0, "Late checkpoint and poison callbacks must be ignored")
	_check(overlay.result_label.text == result_text and result_text.contains("%.1f" % finish_time),
		"The displayed result must retain the completed run's time")


func _load_scene(path: String) -> Node:
	paused = false
	_check(change_scene_to_file(path) == OK, "Production scene must load: %s" % path)
	await scene_changed
	await process_frame
	return current_scene


func _get_level(scene: Node, app_entry: bool) -> Variant:
	var level: Variant = scene.get_node_or_null("LevelHost/LevelMain/Level01" if app_entry else "Level01")
	if not _check(level != null and level.has_method(&"is_completed"), "The production entry must contain HandbuiltLevel"):
		return null
	_check(level.scene_file_path == "res://scenes/levels/level_01.tscn", "UID resolution must load the authoritative level_01 path")
	_check(level.completion_button_path == NodePath(BUTTON_PATH), "Only the designated upper button may complete Main")
	_check(level.get_node_or_null("Interface/CompletionOverlay") is CompletionOverlay, "The level must contain its completion overlay")
	return level


func _watch_level(level: Variant) -> void:
	_local_events.clear()
	level.completion_changed.connect(_on_local_completion)


func _wait_for_reload(old_id: int, expected_path: String) -> void:
	for frame: int in range(60):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			break
	_check(current_scene != null and current_scene.get_instance_id() != old_id, "Restart must replace the actual current scene")
	if current_scene == null:
		return
	var replacement_id := current_scene.get_instance_id()
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.get_instance_id() == replacement_id,
		"Concurrent restart requests must produce only one replacement scene")
	_check(current_scene.scene_file_path == expected_path, "Restart must preserve the F5 or F6 entry point")


func _check_fresh_run(level: Variant) -> void:
	_check(not level.is_completed() and level.death_count() == 0 and level.elapsed_time() < 0.5,
		"A restarted run must clear completion, deaths and elapsed time")
	_check(not (level.get_node("Interface/CompletionOverlay") as CompletionOverlay).visible,
		"The restarted completion overlay must be hidden")
	_check(not (level.get_node(BUTTON_PATH) as TriggerButton).is_pressed()
		and not (level.get_node(CUBE_PATH) as MoveableCube).is_activated(),
		"The restarted final button and its cube must be reset")


func _send_restart_key(pressed: bool) -> void:
	for binding: InputEvent in InputMap.action_get_events(&"restart"):
		if binding is InputEventKey:
			var event := binding.duplicate() as InputEventKey
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			return
	_check(false, "Restart must have a keyboard binding for the paused overlay")


func _on_global_completion(level_id: StringName) -> void:
	_global_events.append(level_id)


func _on_local_completion(completed: bool) -> void:
	_local_events.append(completed)


func _on_contact(body: Node2D, player: Player) -> void:
	if body == player:
		_contact_count += 1


func _on_target_pressed(_button: TriggerButton, actor: Node2D, level: Variant) -> void:
	if actor == level.get_node("Actors/Player"):
		_latched_during_press = level.is_completed()


func _on_motion_started(_cube: MoveableCube) -> void:
	_motion_count += 1


func _on_checkpoint() -> void:
	_checkpoint_events += 1


func _on_toxin_changed(_active: bool) -> void:
	_toxin_events += 1


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
	return condition
