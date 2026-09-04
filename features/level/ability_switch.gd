class_name AbilitySwitch
extends Area2D
## Latching switch that accepts exactly one physical ability contract.

enum Mode {
	LEG_EXTENSION,
	SPROUT_BODY,
}

signal activated

@export var mode: Mode = Mode.LEG_EXTENSION
@export var visual_size: Vector2 = Vector2(44.0, 24.0)

var _active: bool = false


func _ready() -> void:
	area_entered.connect(try_activate_area)
	body_entered.connect(try_activate_body)
	queue_redraw()


func try_activate_area(area: Area2D) -> bool:
	if _active or mode != Mode.LEG_EXTENSION or area == null or not area.is_in_group("leg_extension"):
		return false
	_activate()
	return true


func try_activate_body(body: Node2D) -> bool:
	if _active or mode != Mode.SPROUT_BODY or body == null or not body.has_method(&"current_form_id"):
		return false
	if body.call(&"current_form_id") != &"sprout":
		return false
	_activate()
	return true


func activate_for_test() -> void:
	_activate()


func is_active() -> bool:
	return _active


func restore_active(active: bool) -> void:
	_active = active
	queue_redraw()


func _activate() -> void:
	if _active:
		return
	_active = true
	activated.emit()
	queue_redraw()


func _draw() -> void:
	var color := Color("#5aff73") if _active else Color("#ffca3a")
	draw_rect(Rect2(-visual_size * 0.5, visual_size), color)
	var label := "F" if mode == Mode.LEG_EXTENSION else "S"
	draw_string(ThemeDB.fallback_font, Vector2(-5.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#232323"))
