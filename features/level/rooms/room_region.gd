class_name RoomRegion
extends Node2D
## Authored view/HUD region. Coordinates are local to this node, without physics
## collision or Area overlap delays; the level resolves spawn and retry directly.
@export var room_id: StringName = &""
@export var room_name: String = "01 / 培养室"
@export_multiline var objective: String = "穿过根洞，按住 E 吸收营养"
@export var region_size: Vector2 = Vector2(390.0, 420.0)
@export var camera_center: Vector2 = Vector2(234.0, 233.0)
@export_range(0.5, 4.0, 0.05) var camera_zoom: float = 2.5
@export var selection_priority: int = 0

func contains_point(world_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, region_size).has_point(to_local(world_position))

func get_camera_center() -> Vector2:
	return to_global(camera_center)
