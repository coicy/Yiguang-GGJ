extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/json_whitebox_level.tscn")
const B1 := "0f859c40-96d0-11f1-9ec0-a7f50fdb1f9d"
const DOOR := "e1e9a7b0-96d0-11f1-be70-0dbca0ba9a32"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(change_scene_to_packed(LEVEL_SCENE) == OK)
	await scene_changed
	await _frames(6)
	var level := _level()
	var player := level.get_node("Player") as Player
	var hud := level.get_node("Interface/GameHud") as GameHud
	var exit_goal := level.get_node("ExitGoal") as ExitGoal
	player.set_physics_process(false)
	assert(hud.visible and hud.form_label.text == "幼芽期")
	assert("E" in hud.controls_label.text, "Sprouts need the absorption instruction too.")
	assert("跳跃" not in hud.controls_label.text and "不可跳跃" in hud.ability_hint.text)
	_assert_mouse_passthrough(hud)
	assert(hud.objective_icon.texture.resource_path.ends_with("lever_off.png"))
	assert(not exit_goal.is_unlocked() and not level.is_completed())
	assert(not (level.get_node("Interface/CompletionOverlay") as Control).visible)

	player.global_position = Vector2(400.0, -80.0)
	player.resources.absorb_nutrition(20.0)
	assert(is_equal_approx(hud.growth_bar.value, player.resources.growth_progress))
	Input.action_press(&"absorb_resource")
	player.form_controller.restore_form(&"humanoid")
	await _frames(3)
	assert(hud.form_label.text == "人形期" and "WASD" in hud.ability_hint.text)
	assert("松开 E" in hud.context_label.text)
	Input.action_release(&"absorb_resource")
	player.form_controller.restore_form(&"mature")
	await _frames(3)
	assert(hud.form_label.text == "成熟期" and "滑翔" in hud.ability_hint.text and "E 上环" in hud.ability_hint.text)
	assert("已成熟" in hud.growth_label.text and is_equal_approx(hud.growth_bar.value, hud.growth_bar.max_value))
	player.resources.stability = 22.0
	player.resources.values_changed.emit(0.0, 0.0, 22.0)
	assert(is_equal_approx(hud.stability_bar.value, 22.0))
	player.form_controller.restore_form(&"sprout")
	level.call(&"_respawn_player")
	await _frames(3)
	assert(level.death_count() == 1 and "1" in hud.deaths_label.text)

	# Locked arrival cannot win. This is a real Area2D overlap, not a manual signal.
	player.global_position = exit_goal.global_position
	await _frames(4)
	assert(not level.is_completed() and "尚未开启" in hud.context_label.text)
	var completed_count: Array[int] = [0]
	level.completion_changed.connect(func(done: bool, _seconds: float) -> void:
		if done:
			completed_count[0] += 1
	)
	var button := level.get_entity(B1) as WhiteboxButton
	player.global_position = button.global_position + Vector2(8.0, 12.0)
	await _frames(4)
	assert(button.is_pressed() and not exit_goal.is_unlocked())
	assert(not level.is_completed(), "Touching B1 alone cannot win.")
	# Arrive before the animation finishes: unlocking must recheck occupied exits.
	player.global_position = exit_goal.global_position
	await _wait_for_completion(level)
	assert(completed_count[0] == 1)
	assert(not exit_goal.try_complete(player))
	var overlay := level.get_node("Interface/CompletionOverlay") as CompletionOverlay
	assert(overlay.visible and "重试 1" in overlay.result_label.text)
	assert(overlay.victory_audio.stream.resource_path.ends_with("win.wav"))
	assert(hud.objective_icon.texture.resource_path.ends_with("lever_on.png"))
	var finished_time := level.elapsed_time()
	var finished_position := player.global_position
	var finished_growth := player.resources.growth_progress
	Input.action_press(&"move_right")
	Input.action_press(&"absorb_resource")
	await create_timer(0.25).timeout
	Input.action_release(&"move_right")
	Input.action_release(&"absorb_resource")
	assert(is_equal_approx(level.elapsed_time(), finished_time))
	assert(player.global_position.is_equal_approx(finished_position))
	assert(is_equal_approx(player.resources.growth_progress, finished_growth))
	assert(completed_count[0] == 1)

	# Exercise a real GUI click while the gameplay branch is frozen.
	var old_level: WeakRef = weakref(level)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = overlay.restart_button.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	root.push_input(click, true)
	await _frames(8)
	assert(old_level.get_ref() == null, "The restart button must reload the scene.")
	level = _level()
	_assert_reset(level)

	# The R shortcut must also work from the victory overlay.
	player = level.get_node("Player") as Player
	player.set_physics_process(false)
	exit_goal = level.get_node("ExitGoal") as ExitGoal
	player.global_position = exit_goal.global_position
	assert((level.get_entity(DOOR) as WhiteboxDoor).open())
	await _wait_for_completion(level)
	old_level = weakref(level)
	var key := InputMap.action_get_events(&"restart")[0].duplicate() as InputEventKey
	key.pressed = true
	root.push_input(key, true)
	await _frames(8)
	key.pressed = false
	root.push_input(key, true)
	assert(old_level.get_ref() == null)
	_assert_reset(_level())
	print("PASS: HUD states, assets, locked/occupied exits, one-shot win, frozen gameplay, mouse and R restart")
	current_scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit()


func _assert_reset(level: JsonWhiteboxLevel) -> void:
	assert(not level.is_completed() and level.death_count() == 0 and level.elapsed_time() < 1.0)
	assert((level.get_node("Player") as Player).current_form_id() == &"sprout")
	assert(not (level.get_entity(B1) as WhiteboxButton).is_pressed())
	assert(not (level.get_entity(DOOR) as WhiteboxDoor).is_open())
	assert(not (level.get_node("ExitGoal") as ExitGoal).is_unlocked())
	assert(not (level.get_node("Interface/CompletionOverlay") as Control).visible)
	assert(level.process_mode != Node.PROCESS_MODE_DISABLED)


func _assert_mouse_passthrough(node: Node) -> void:
	if node is Control:
		assert((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for child: Node in node.get_children():
		_assert_mouse_passthrough(child)


func _wait_for_completion(level: JsonWhiteboxLevel) -> void:
	for _step: int in range(240):
		await physics_frame
		if level.is_completed():
			await _frames(3)
			return
	assert(false, "Unlocked exit did not complete within four seconds.")


func _level() -> JsonWhiteboxLevel:
	return current_scene as JsonWhiteboxLevel


func _frames(count: int) -> void:
	for _step: int in range(count):
		await physics_frame
