extends SceneTree
## Menu input and the production entry's pause-to-play lifecycle.

const MENU_SCENE: PackedScene = preload("res://features/ui/start_screen.tscn")

var _start_requests: int = 0
var _exit_requests: int = 0
var _run_events: int = 0
var _level_events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	menu.connect(&"start_requested", func() -> void: _start_requests += 1)
	menu.connect(&"exit_requested", func() -> void: _exit_requests += 1)
	var start := menu.get_node("%StartButton") as Button
	var exit_button := menu.get_node("%ExitButton") as Button
	paused = true
	await process_frame
	assert(menu.can_process() and start.can_process(), "Standalone menu must accept input while paused.")
	assert(start.has_focus(), "Keyboard navigation must initially focus Start.")
	exit_button.pressed.emit()
	assert(_exit_requests == 1, "Exit must request an application-owned transition.")
	start.pressed.emit()
	start.pressed.emit()
	assert(_start_requests == 1 and start.disabled, "Repeated Start activation must be ignored.")
	menu.queue_free()
	paused = false
	await process_frame

	var bus := root.get_node("GlobalSignalBus")
	bus.connect(&"run_started", func() -> void: _run_events += 1)
	bus.connect(&"level_started", func(id: StringName) -> void: _level_events.append(id))
	var main_scene := load("res://scenes/app/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var level := main.get_node("LevelHost/LevelMain/Level01")
	var player := level.get_node("Actors/Player")
	var overlay := main.get_node("Interface") as CanvasLayer
	menu = main.get_node("Interface/StartScreen") as Control
	start = menu.get_node("%StartButton") as Button
	assert(paused and menu.visible and menu.can_process())
	assert(not player.can_process(), "Player processing must stop behind the start screen.")
	for canvas: Node in level.find_children("*", "CanvasLayer", true, false):
		assert(overlay.layer > (canvas as CanvasLayer).layer, "Menu must cover any production HUD.")
	assert(_run_events == 0 and _level_events.is_empty(), "Opening the menu must not begin a run.")
	var elapsed_before := float(level.call(&"elapsed_time"))
	await create_timer(0.15).timeout
	assert(is_equal_approx(float(level.call(&"elapsed_time")), elapsed_before),
		"Level time must remain frozen while waiting for Start.")
	start.pressed.emit()
	start.pressed.emit()
	assert(paused, "The level must stay paused during the menu fade.")
	await create_timer(0.4).timeout
	var storyboard := main.get_node("%OpeningStoryboard") as Control
	assert(paused and not menu.visible and storyboard.visible and storyboard.can_process(),
		"Start must enter the paused opening storyboard after its fade.")
	assert(not player.can_process() and _run_events == 0 and _level_events.is_empty(),
		"The storyboard must not begin gameplay or lifecycle events.")
	assert(is_equal_approx(float(level.call(&"elapsed_time")), elapsed_before),
		"Level time must remain frozen throughout the opening.")
	storyboard.call(&"skip")
	await process_frame
	await process_frame
	assert(not paused and not menu.visible and player.can_process(),
		"Finishing the storyboard must resume the production level.")
	assert(_run_events == 1 and _level_events == [&"level_main"],
		"Start must emit exactly one run and one authoritative level event.")
	var resumed_time := float(level.call(&"elapsed_time"))
	await create_timer(0.15).timeout
	assert(float(level.call(&"elapsed_time")) > resumed_time, "The gameplay clock must resume.")
	start.pressed.emit()
	await process_frame
	assert(_run_events == 1 and _level_events.size() == 1)
	main.queue_free()
	await process_frame
	print("PASS: menu signals, duplicate protection, paused storyboard, frozen timer and single run lifecycle")
	quit()
