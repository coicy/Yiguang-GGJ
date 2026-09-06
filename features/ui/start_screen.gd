class_name StartScreen
extends Control
## Presentation-only start screen. Main owns the run transition.

signal start_requested
signal exit_requested

@onready var start_button: Button = %StartButton
@onready var exit_button: Button = %ExitButton

var _start_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	start_button.grab_focus()


func set_start_enabled(enabled: bool) -> void:
	_start_enabled = enabled
	start_button.disabled = not enabled


func _on_start_pressed() -> void:
	if not _start_enabled:
		return
	_start_enabled = false
	start_button.disabled = true
	start_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()
