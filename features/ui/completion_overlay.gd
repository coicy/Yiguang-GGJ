class_name CompletionOverlay
extends Control

signal restart_requested

var _audio_pending: bool = false

@onready var result_label: Label = %ResultLabel
@onready var restart_button: Button = %RestartButton
@onready var victory_audio: AudioStreamPlayer = %VictoryAudio


func _ready() -> void:
	restart_button.pressed.connect(_request_restart)


func show_completion(seconds: float, deaths: int = 0) -> void:
	if visible:
		return
	visible = true
	result_label.text = "用时 %.1f 秒   ·   重试 %d 次" % [seconds, deaths]
	restart_button.grab_focus()
	if not _audio_pending:
		_audio_pending = true
		_play_victory.call_deferred()


func hide_completion() -> void:
	visible = false
	victory_audio.stop()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_request_restart()


func _request_restart() -> void:
	restart_requested.emit()


func _exit_tree() -> void:
	if is_instance_valid(victory_audio):
		victory_audio.stop()


func _play_victory() -> void:
	_audio_pending = false
	if visible and is_inside_tree():
		victory_audio.play()
