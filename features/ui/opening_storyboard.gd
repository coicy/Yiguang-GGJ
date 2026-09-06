class_name OpeningStoryboard
extends Control
## Click-paced introduction; the application owns gameplay pause and resume.

signal finished()

@export var slides: Array[Texture2D] = []
@export_range(0.0, 2.0) var fade_duration: float = 0.3

@onready var artwork: TextureRect = %Artwork
@onready var progress: Label = %Progress
@onready var skip_button: Button = %SkipButton

var slide_index: int = 0
var _active: bool = false
var _fade: Tween


func _ready() -> void:
	skip_button.pressed.connect(skip)
	# Also supports a standalone current-scene launch.
	if visible:
		play()


func play() -> void:
	_active = true
	slide_index = 0
	show()
	if slides.is_empty():
		skip()
		return
	_show_slide()


func advance() -> void:
	if not _active:
		return
	if _fade != null and _fade.is_running():
		_fade.kill()
		artwork.modulate.a = 1.0
		return
	if slide_index + 1 >= slides.size():
		skip()
		return
	slide_index += 1
	_show_slide()


func skip() -> void:
	if not _active:
		return
	_active = false
	if _fade != null:
		_fade.kill()
	hide()
	finished.emit()


func _show_slide() -> void:
	if _fade != null:
		_fade.kill()
	artwork.texture = slides[slide_index]
	artwork.modulate.a = 0.0
	progress.text = "%d / %d    %s" % [slide_index + 1, slides.size(),
		"点击进入游戏" if slide_index == slides.size() - 1 else "点击继续"]
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(artwork, "modulate:a", 1.0, fade_duration)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		advance()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		advance()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()
