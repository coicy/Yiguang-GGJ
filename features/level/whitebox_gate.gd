class_name WhiteboxGate
extends StaticBody2D

signal opened

@onready var collision_shape: CollisionShape2D = %CollisionShape2D

var _closed: bool = true


func bind_switch(switch: Node) -> void:
	if switch != null and switch.has_signal("activated"):
		switch.activated.connect(open)
	if switch != null and switch.has_method(&"is_active") and switch.call(&"is_active"):
		open()


func open() -> void:
	if not _closed:
		return
	_closed = false
	collision_shape.set_deferred("disabled", true)
	opened.emit()
	queue_redraw()


func close() -> void:
	_closed = true
	collision_shape.set_deferred("disabled", false)
	queue_redraw()


func is_closed() -> bool:
	return _closed


func _draw() -> void:
	if _closed:
		draw_rect(Rect2(-16.0, -80.0, 32.0, 160.0), Color("#d84b55"))
	else:
		draw_rect(Rect2(-16.0, -80.0, 32.0, 8.0), Color("#65d46e"))
