class_name ExitGoal
extends Area2D

signal locked_entered(player: Player)
signal player_completed(player: Player)

const DOOR_TEXTURE: Texture2D = preload("res://assets/runtime/ui/exit_door.png")

@export var goal_size: Vector2 = Vector2(56.0, 72.0)

var _unlocked: bool = true
var _last_unlocked: bool = false
var _required_switches: Array[Node] = []
var _completed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var collision := $CollisionShape2D as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = goal_size
	collision.shape = shape
	collision.position = Vector2(0.0, -goal_size.y * 0.5)
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
	if not _unlocked:
		return false
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


func set_unlocked(value: bool) -> void:
	_unlocked = value
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var available := is_unlocked()
	if available != _last_unlocked:
		_last_unlocked = available
		queue_redraw()
	# Opening the door while the player is already here must not require re-entry.
	if available and not _completed:
		for body: Node2D in get_overlapping_bodies():
			if body is Player:
				try_complete(body)


func _draw() -> void:
	var available := is_unlocked()
	var tint := Color.WHITE if available else Color(0.45, 0.45, 0.5)
	var rect := Rect2(Vector2(-goal_size.x * 0.5, -goal_size.y), goal_size)
	if available:
		draw_rect(rect.grow(3.0), Color(0.5, 0.95, 0.55, 0.2))
	draw_texture_rect(DOOR_TEXTURE, rect, false, tint)
	var label := "出口" if available else "出口锁定"
	draw_string(ThemeDB.fallback_font, Vector2(-24.0, -goal_size.y - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#f5d28d"))
