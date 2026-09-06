class_name Main
extends Node2D
## Lifecycle container for the currently selected game run.

const LEVEL_ID := &"level_main"

@onready var start_screen: StartScreen = %StartScreen
@onready var opening_storyboard: OpeningStoryboard = %OpeningStoryboard

var _run_started: bool = false


func _ready() -> void:
	# Keep the level subtree pausable; only the menu CanvasLayer runs while paused.
	RunState.reset()
	RunState.current_level_id = LEVEL_ID
	start_screen.start_requested.connect(_on_start_requested)
	start_screen.exit_requested.connect(_on_exit_requested)
	opening_storyboard.finished.connect(_begin_run)
	get_tree().paused = true


func _on_start_requested() -> void:
	if _run_started:
		return
	_run_started = true
	start_screen.set_start_enabled(false)

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.bind_node(self)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(start_screen, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_show_intro)


func _show_intro() -> void:
	start_screen.hide()
	opening_storyboard.play()


func _begin_run() -> void:
	start_screen.hide()
	# Consume the final story click before gameplay can read input again.
	await get_tree().process_frame
	get_tree().paused = false
	_emit_run_started()


func _emit_run_started() -> void:
	GlobalSignalBus.run_started.emit()
	GlobalSignalBus.level_started.emit(LEVEL_ID)


func _on_exit_requested() -> void:
	if _run_started:
		return
	get_tree().quit()
