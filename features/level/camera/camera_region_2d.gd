@tool
class_name CameraRegion2D
extends Node2D
## Authored room membership and display limits. The rectangle is not collision.

@export var region_id: StringName
@export var priority: int = 0
@export var activation_rect := Rect2(-224, -106, 448, 213)
@export var horizontal_limits := Vector2(-224, 224)
@export var horizontal_guard_rect: Rect2
@export var center_horizontal: bool = false
@export var floor_paths: Array[NodePath] = []
@export var transition_floor_path: NodePath
@export_range(32.0, 320.0, 1.0) var transition_height: float = 160.0
@export var drop_connection: bool = false

var _floors: Array[TerrainPiece] = []
var _transition_floor: TerrainPiece


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"camera_regions")
	for path: NodePath in floor_paths:
		var floor_piece := get_node_or_null(path) as TerrainPiece
		if floor_piece != null:
			_floors.append(floor_piece)
	if not transition_floor_path.is_empty():
		_transition_floor = get_node_or_null(transition_floor_path) as TerrainPiece


func contains_feet(feet: Vector2) -> bool:
	return activation_rect.has_point(to_local(feet))


func get_world_rect() -> Rect2:
	return global_transform * activation_rect


func get_horizontal_limits() -> Vector2:
	var left: float = to_global(Vector2(horizontal_limits.x, 0)).x
	var right: float = to_global(Vector2(horizontal_limits.y, 0)).x
	return Vector2(minf(left, right), maxf(left, right))


func guards_horizontal(feet: Vector2) -> bool:
	return horizontal_guard_rect.has_area() and horizontal_guard_rect.has_point(to_local(feet))


func get_floor(feet: Vector2) -> TerrainPiece:
	var fallback: TerrainPiece
	for floor_piece: TerrainPiece in _floors:
		var rect: Rect2 = floor_piece.get_camera_floor_rect()
		if not rect.has_area():
			continue
		fallback = floor_piece
		if feet.x >= rect.position.x and feet.x <= rect.end.x:
			return floor_piece
	return fallback


func get_transition_floor() -> TerrainPiece:
	return _transition_floor if is_instance_valid(_transition_floor) else null


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	else:
		set_process(false)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.25, 0.8, 0.65, 0.65)
	if drop_connection:
		color = Color(1.0, 0.55, 0.2, 0.7)
	elif center_horizontal:
		color = Color(0.7, 0.45, 1.0, 0.65)
	draw_rect(activation_rect, Color(color, 0.05), true)
	draw_rect(activation_rect, color, false, 1.5)
