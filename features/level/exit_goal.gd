class_name ExitGoal
extends Area2D

signal locked_entered(player: Player)
signal player_completed(player: Player)

var _required_switches: Array[Node] = []
var _completed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func set_required_switches(switches: Array) -> void:
	_required_switches.clear()
	for switch: Variant in switches:
		if switch is Node:
			_required_switches.append(switch)
	queue_redraw()


func try_complete(player: Player) -> bool:
	if player == null or _completed:
		return false
	if not is_unlocked():
		locked_entered.emit(player)
		return false
	_completed = true
	player_completed.emit(player)
	queue_redraw()
	return true


func is_unlocked() -> bool:
	for switch: Node in _required_switches:
		if not is_instance_valid(switch) or not switch.has_method(&"is_active") or not switch.call(&"is_active"):
			return false
	return true


func reset_completion() -> void:
	_completed = false
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		try_complete(body)


func _draw() -> void:
	var color := Color("#55e690") if is_unlocked() else Color("#666d78")
	draw_rect(Rect2(-28.0, -72.0, 56.0, 72.0), color)
	draw_rect(Rect2(-18.0, -62.0, 36.0, 62.0), Color("#1e2936"))
