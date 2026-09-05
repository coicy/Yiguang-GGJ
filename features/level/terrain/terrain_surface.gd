@tool
class_name TerrainSurface
extends Resource
## Shared visual data. Runtime drawing never changes this resource or collision.

@export var material_id: StringName = &"stone":
	set(value):
		material_id = value
		emit_changed()
@export var surfaces: Array[Texture2D] = []:
	set(value):
		surfaces = value
		emit_changed()
@export var surface_height: float = 18.0:
	set(value):
		surface_height = maxf(value, 1.0)
		emit_changed()
@export var surface_width: float = 120.0:
	set(value):
		surface_width = maxf(value, 1.0)
		emit_changed()
@export var surface_tint: Color = Color.WHITE:
	set(value):
		surface_tint = value
		emit_changed()
@export var body_texture: Texture2D = null:
	set(value):
		body_texture = value
		emit_changed()
@export var body_tint: Color = Color.WHITE:
	set(value):
		body_tint = value
		emit_changed()
@export var body_height: float = 85.0:
	set(value):
		body_height = maxf(value, 1.0)
		emit_changed()
@export var body_width: float = 190.0:
	set(value):
		body_width = maxf(value, 1.0)
		emit_changed()
@export var foundation_color: Color = Color("#26382f"):
	set(value):
		foundation_color = value
		emit_changed()
@export var fill_foundation: bool = true:
	set(value):
		fill_foundation = value
		emit_changed()
@export var support_texture: Texture2D = null:
	set(value):
		support_texture = value
		emit_changed()
@export var support_size: Vector2 = Vector2(90.0, 100.0):
	set(value):
		support_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		emit_changed()
@export var support_spacing: float = 180.0:
	set(value):
		support_spacing = maxf(value, 1.0)
		emit_changed()
@export var support_tint: Color = Color(0.72, 0.76, 0.69, 1.0):
	set(value):
		support_tint = value
		emit_changed()
@export var top_edge: Color = Color("#899678"):
	set(value):
		top_edge = value
		emit_changed()
@export var joint_color: Color = Color(0.10, 0.17, 0.14, 0.5):
	set(value):
		joint_color = value
		emit_changed()
