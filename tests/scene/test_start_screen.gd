extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/app/main.tscn")
const START_SCREEN_SCENE: PackedScene = preload("res://features/ui/start_screen.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var standalone_screen := START_SCREEN_SCENE.instantiate()
	root.add_child(standalone_screen)
	await process_frame
	var standalone_button := standalone_screen.get_node("Content/Columns/InfoPanel/Info/StartButton") as Button
	assert(standalone_button != null)
	assert(standalone_button.has_focus())
	standalone_screen.free()

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	assert(paused)
	var start_screen := main.get_node("Interface/StartScreen") as Control
	assert(start_screen != null)
	assert(start_screen.visible)
	var run_state := root.get_node_or_null("RunState")
	assert(run_state != null)
	assert(run_state.get(&"current_level_id") == &"yiguang_whitebox")

	var start_button := start_screen.get_node("Content/Columns/InfoPanel/Info/StartButton") as Button
	assert(start_button != null)
	assert(start_button.has_focus())
	start_button.pressed.emit()
	await create_timer(0.4, true).timeout

	assert(not paused)
	assert(not start_screen.visible)
	assert(main.get_node("LevelHost/YiguangWhitebox") != null)
	main.free()
	quit()
