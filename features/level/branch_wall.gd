@tool
class_name BranchWall
extends StaticBody2D
## A reusable vertical natural wall with visual and collision dimensions kept separate.

const SOURCE_TEXTURE_SIZE := Vector2(571.0, 105.0)
const BASE_WALL_SIZE := Vector2(54.0, 288.0)

## Simplified solid outline for the upright branch artwork at BASE_WALL_SIZE.
## Keep this convex-ish and low-vertex so the player receives stable wall normals.
@export var collision_outline := PackedVector2Array([
	Vector2(-12.0, -144.0),
	Vector2(18.0, -140.0),
	Vector2(25.0, -104.0),
	Vector2(29.0, -60.0),
	Vector2(25.0, -10.0),
	Vector2(21.0, 50.0),
	Vector2(27.0, 105.0),
	Vector2(18.0, 144.0),
	Vector2(-20.0, 144.0),
	Vector2(-26.0, 108.0),
	Vector2(-22.0, 68.0),
	Vector2(-27.0, 14.0),
	Vector2(-20.0, -38.0),
	Vector2(-28.0, -88.0),
	Vector2(-22.0, -124.0),
])

@export_category("Wall Layout")
@export_range(32.0, 2048.0, 1.0, "suffix:px") var wall_height := 288.0:
	set(value):
		wall_height = maxf(value, 32.0)
		_sync_layout()

@export_range(12.0, 512.0, 1.0, "suffix:px") var wall_width := 54.0:
	set(value):
		wall_width = maxf(value, 12.0)
		_sync_layout()

@onready var _wall_sprite: Sprite2D = %WallSprite
@onready var _collision_polygon: CollisionPolygon2D = %CollisionPolygon2D


func _ready() -> void:
	_sync_layout()


func _sync_layout() -> void:
	if not is_instance_valid(_wall_sprite) or not is_instance_valid(_collision_polygon):
		return
	# Rotate only the artwork. The saved collision polygon remains hand-authored.
	_wall_sprite.rotation = PI * 0.5
	_wall_sprite.scale = Vector2(
		wall_height / SOURCE_TEXTURE_SIZE.x,
		wall_width / SOURCE_TEXTURE_SIZE.y,
	)
	if _collision_polygon.polygon.size() < 3:
		_collision_polygon.polygon = collision_outline
