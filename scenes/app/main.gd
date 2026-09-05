class_name Main
extends Node2D
## Lifecycle container for the currently selected game run.

const LEVEL_ID := &"yiguang_whitebox"

@onready var start_screen: Control = %StartScreen

var _run_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.call(&"reset")
		run_state.set(&"current_level_id", LEVEL_ID)
	start_screen.connect(&"start_requested", _on_start_requested)
	get_tree().paused = true


func _on_start_requested() -> void:
	if _run_started:
		return
	_run_started = true
	start_screen.call(&"set_start_enabled", false)

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.bind_node(self)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(start_screen, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_begin_run)


func _begin_run() -> void:
	start_screen.hide()
	get_tree().paused = false
	_emit_run_started()


func _emit_run_started() -> void:
	var signal_bus := get_node_or_null("/root/GlobalSignalBus")
	if signal_bus != null:
		if signal_bus.has_signal(&"run_started"):
			signal_bus.emit_signal(&"run_started")
		if signal_bus.has_signal(&"level_started"):
			signal_bus.emit_signal(&"level_started", LEVEL_ID)
