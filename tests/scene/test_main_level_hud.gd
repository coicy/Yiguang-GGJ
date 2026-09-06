extends SceneTree
## Regression coverage for the production hand-built level and its read-only HUD.

const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"
const LEVEL_PATH := "LevelHost/LevelMain/Level01"
const OBJECTIVE_TEXT := "爬到最高处即可通关"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var level: Node = main.get_node(LEVEL_PATH)
	var player := level.get_node("Actors/Player") as Player
	var hud := level.get_node_or_null("Interface/MainLevelHud") as MainLevelHud
	assert(hud != null and hud.visible, "The default main entry must display its HUD.")
	player.set_physics_process(false)
	await _start_run(main)
	_assert_mouse_passthrough(hud)
	_assert_no_legacy_objective(hud)
	_assert_objective(hud)
	assert("R" in hud.controls_label.text, "The HUD must explain restarting the main level.")
	assert("E" in hud.controls_label.text, "The HUD must explain resource absorption.")
	assert(hud.form_label.text.contains("幼芽"))
	assert(hud.ability_hint.text.contains("不可跳跃"))

	# Change resources through their public API, as real gameplay does.
	assert(player.absorb_nutrition(20.0))
	assert(is_equal_approx(hud.growth_bar.value, player.resources.growth_progress))
	assert(hud.growth_label.text.contains("20"))
	assert(player.form_controller.restore_form(&"humanoid"))
	assert(hud.form_label.text.contains("人形"))
	assert(hud.ability_hint.text.contains("扎根"))
	assert(hud.controls_label.text.contains("跳跃"))
	assert(player.form_controller.restore_form(&"mature"))
	assert(hud.form_label.text.contains("成熟"))
	assert(hud.ability_hint.text.contains("藤蔓"))
	assert(hud.ability_hint.text.contains("滑翔"))
	await _assert_top_hint_layout(player)
	assert(is_equal_approx(hud.growth_bar.value, hud.growth_bar.max_value),
		"A fully grown form with zero threshold must display a full growth bar.")
	player.resources.restore({"stability": 22.0})
	assert(is_equal_approx(hud.stability_bar.value, 22.0))
	assert(hud.stability_label.text.contains("22"))
	player.abilities.feedback_requested.emit("测试能力反馈")
	assert(hud.context_label.text.contains("测试能力反馈"))
	_assert_objective(hud)

	# Exercise the actual lifecycle callbacks, not the HUD setters.
	var deaths_before := int(level.call(&"death_count"))
	level.call(&"_on_actor_killed", player)
	assert(int(level.call(&"death_count")) == deaths_before + 1)
	assert(hud.deaths_label.text.contains(str(deaths_before + 1)))
	level.call(&"_on_checkpoint_reached", player, player.global_position + Vector2(32.0, 0.0))
	assert(hud.context_label.text.contains("检查点"))
	_assert_objective(hud)
	var seconds_before := float(level.call(&"elapsed_time"))
	var clock_before := hud.time_label.text
	await create_timer(1.1).timeout
	assert(float(level.call(&"elapsed_time")) > seconds_before + 1.0)
	assert(hud.time_label.text != clock_before, "The visible clock must advance during a run.")

	# A second production scene starts a fresh run and supplies a new player.
	var next_main: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(next_main)
	var next_level: Node = next_main.get_node(LEVEL_PATH)
	var next_player := next_level.get_node("Actors/Player") as Player
	var next_hud := next_level.get_node("Interface/MainLevelHud") as MainLevelHud
	next_player.set_physics_process(false)
	await _start_run(next_main)
	assert(int(next_level.call(&"death_count")) == 0)
	assert(float(next_level.call(&"elapsed_time")) < 1.0)
	assert(next_hud.deaths_label.text.contains("0"))
	assert(next_hud.time_label.text.contains("00:00"))
	assert(next_hud.form_label.text.contains("幼芽"))
	_assert_objective(next_hud)

	hud.bind_player(next_player)
	var bound_form_text := hud.form_label.text
	var bound_growth_value := hud.growth_bar.value
	var bound_stability_value := hud.stability_bar.value
	assert(player.form_controller.restore_form(&"humanoid"))
	player.resources.restore({"growth": 37.0, "stability": 8.0})
	player.abilities.feedback_requested.emit("旧玩家反馈不应显示")
	assert(hud.form_label.text == bound_form_text)
	assert(is_equal_approx(hud.growth_bar.value, bound_growth_value))
	assert(is_equal_approx(hud.stability_bar.value, bound_stability_value))
	assert(not hud.context_label.text.contains("旧玩家反馈"),
		"Rebinding must disconnect old player feedback and resource signals.")
	assert(next_player.form_controller.restore_form(&"mature"))
	assert(hud.form_label.text.contains("成熟"), "Rebound HUD must follow the new player.")
	_assert_objective(hud)

	main.queue_free()
	next_main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("PASS: main HUD wiring, persistent objective, responsive layout, forms, growth, stability, feedback, retries, checkpoint, clock, reset, rebinding and mouse passthrough")
	quit()


func _start_run(main: Node) -> void:
	var start_screen := main.get_node("Interface/StartScreen") as StartScreen
	var storyboard := main.get_node("Interface/OpeningStoryboard") as OpeningStoryboard
	start_screen.start_requested.emit()
	await create_timer(0.3).timeout
	storyboard.skip()
	await process_frame
	await process_frame
	assert(not paused, "HUD lifecycle checks must run after the real menu and intro flow unpauses gameplay.")


func _assert_objective(hud: MainLevelHud) -> void:
	var objective := hud.get_node("Top/HintColumn/ObjectiveLabel") as Label
	assert(objective.visible and objective.text == OBJECTIVE_TEXT,
		"The objective must remain visible independently of form and feedback messages.")


func _assert_mouse_passthrough(node: Node) -> void:
	if node is Control:
		assert((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"HUD controls must leave mouse input available to player abilities.")
	for child: Node in node.get_children():
		_assert_mouse_passthrough(child)


func _assert_no_legacy_objective(node: Node) -> void:
	if node is Label:
		assert(not (node as Label).text.contains("B1"), "Main HUD must not mention the old JSON objective.")
	for child: Node in node.get_children():
		_assert_no_legacy_objective(child)


func _assert_top_hint_layout(player: Player) -> void:
	for viewport_size: Vector2i in [Vector2i(1344, 640), Vector2i(1000, 600)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var preview: MainLevelHud = load("res://features/ui/main_level_hud.tscn").instantiate()
		viewport.add_child(preview)
		preview.bind_player(player)
		_assert_objective(preview)
		for frame: int in range(4):
			await process_frame
		var hints: Rect2 = (preview.get_node("Top/HintColumn") as Control).get_global_rect()
		var status: Rect2 = (preview.get_node("Top/StatusPanel") as Control).get_global_rect()
		var run: Rect2 = (preview.get_node("Top/RunPanel") as Control).get_global_rect()
		assert(not hints.intersects(status) and not hints.intersects(run),
			"Hints must fit between the status and run panels at both supported sizes.")
		assert(hints.end.y < viewport_size.y * 0.5,
			"Controls and feedback must leave the lower half clear for the player.")
		assert(run.end.x <= viewport_size.x and hints.position.x >= 0.0 and hints.position.y >= 0.0,
			"Wrapping text must not push the HUD outside the viewport.")
		var objective := preview.get_node("Top/HintColumn/ObjectiveLabel") as Label
		assert(objective.get_global_rect().end.y <= preview.context_label.get_global_rect().position.y,
			"The persistent objective must sit above dynamic feedback without overlap.")
		for label: Label in [objective, preview.context_label, preview.controls_label, preview.ability_hint]:
			assert(hints.encloses(label.get_global_rect()), "Hint text must stay in its column.")
		viewport.queue_free()
		await process_frame
