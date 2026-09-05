class_name AbilitySwitch
extends Area2D
## Latching switch that accepts exactly one physical ability contract.

enum Mode {
	LEG_EXTENSION,
	SPROUT_BODY,
}

signal activated

@export var mode: Mode = Mode.LEG_EXTENSION
@export var low_profile: bool = false

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
	if low_profile:
		_draw_floor_pedal()
		return
	var outline := Color("#26382b")
	var copper := Color("#826749")
	var copper_light := Color("#b49a69")
	var leaf_color := Color("#b4ea83") if _active else Color("#78936b")
	var plate_color := Color("#436848") if _active else Color("#3c4940")
	var drop := 2.0 if _active else 0.0
	# A shallow cast-bronze housing, seated at the same contact plane as the trigger.
	var base := PackedVector2Array([Vector2(-23, 5), Vector2(-19, 11), Vector2(19, 11), Vector2(23, 5), Vector2(18, -6), Vector2(-18, -6)])
	draw_colored_polygon(base, copper)
	draw_polyline(base + PackedVector2Array([base[0]]), outline, 2.0, true)
	draw_line(Vector2(-18, 8), Vector2(18, 8), Color("#594d39"), 2.0, true)
	var plate := PackedVector2Array([Vector2(-19, -7 + drop), Vector2(-14, -12 + drop), Vector2(14, -12 + drop), Vector2(19, -7 + drop), Vector2(15, 5 + drop), Vector2(-15, 5 + drop)])
	draw_colored_polygon(plate, plate_color)
	draw_polyline(plate + PackedVector2Array([plate[0]]), copper_light, 1.7, true)
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(side * 17, 4), 1.6, outline)
		draw_line(Vector2(side * 17 - 0.6, 3.4), Vector2(side * 17 + 0.6, 4.6), copper_light, 0.7, true)
	if mode == Mode.SPROUT_BODY:
		var center := Vector2(0, -2 + drop)
		draw_line(center + Vector2(0, 5), center + Vector2(0, -4), leaf_color, 1.6, true)
		draw_colored_polygon(PackedVector2Array([center, center + Vector2(-7, -1), center + Vector2(-8, -6), center + Vector2(-3, -6), center + Vector2(0, -2)]), leaf_color)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -1), center + Vector2(3, -7), center + Vector2(8, -8), center + Vector2(7, -3), center + Vector2(2, -1)]), leaf_color)
	else:
		# A jointed plant foot explains the physical ability without a stale key label.
		var ankle := Vector2(-2, -2 + drop)
		draw_polyline(PackedVector2Array([ankle + Vector2(-3, -7), ankle + Vector2(2, -4), ankle, ankle + Vector2(-2, 5), ankle + Vector2(7, 5)]), leaf_color, 2.4, true)
		draw_line(ankle + Vector2(1, -4), ankle + Vector2(7, -7), leaf_color, 1.5, true)
		draw_circle(ankle, 2.0, copper_light)
	if _active:
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * 11, 1 + drop), 1.4, Color("#d5ffc4"))


func _draw_floor_pedal() -> void:
	var top := 10.0 if _active else 7.0
	var base := PackedVector2Array([Vector2(-23,10),Vector2(-18,13),Vector2(18,13),Vector2(23,10),Vector2(18,5),Vector2(-18,5)])
	draw_colored_polygon(base,Color("#273832"))
	draw_polyline(base + PackedVector2Array([base[0]]),Color("#77694d"),1.2,true)
	draw_line(Vector2(-17,top),Vector2(17,top),Color("#b4b88a") if _active else Color("#8b946e"),2.0,true)
	for side: float in [-1.0,1.0]:
		draw_circle(Vector2(side*19,10),1.2,Color("#435345"))
	if _active:
		draw_circle(Vector2(0,top-1),1.5,Color("#c8dc9a"))
