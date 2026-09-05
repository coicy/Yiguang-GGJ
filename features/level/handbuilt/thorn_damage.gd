@tool
class_name ThornDamage
extends Area2D
## A reusable contact-damage component for thorn scenery.
##
## The artwork and collision polygon share the same local transform. Set the
## root Scale to resize the complete thorn, including its collision.

signal actor_hurt(actor: Node2D, damage: float)
signal actor_killed(actor: Node2D)

@export_category("Damage")
@export_range(0.0, 999.0, 0.1) var damage_amount: float = 1.0
@export var kill_on_contact := true

@export_category("Artwork")
@export var sprite_variants: SpriteVariantSet:
	set(value):
		sprite_variants = value
		_request_sync()
@export_range(0, 255, 1) var variant_index := 0:
	set(value):
		variant_index = max(value, 0)
		_request_sync()
@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		_request_sync()
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_request_sync()
@export_range(0.01, 8.0, 0.01) var art_scale_multiplier: float = 0.4:
	set(value):
		art_scale_multiplier = maxf(value, 0.01)
		_request_sync()

@export_category("Collision")
## Normalized points in the selected texture's rectangle. The same scale is
## applied to Artwork and CollisionPolygon2D so the collision follows the art.
@export var collision_points := PackedVector2Array([
	Vector2(0.03, 0.55),
	Vector2(0.15, 0.42),
	Vector2(0.29, 0.45),
	Vector2(0.43, 0.32),
	Vector2(0.58, 0.42),
	Vector2(0.72, 0.31),
	Vector2(0.97, 0.49),
	Vector2(0.97, 0.94),
	Vector2(0.03, 0.94),
]):
	set(value):
		collision_points = value
		_request_sync()
@export var preview_color := Color(0.76, 0.18, 0.23, 0.7):
	set(value):
		preview_color = value
		queue_redraw()

@onready var _collision_polygon: CollisionPolygon2D = %CollisionPolygon2D
@onready var _artwork: Sprite2D = %Artwork


func _ready() -> void:
	add_to_group(&"handbuilt_hazards")
	_sync_layout()
	if not Engine.is_editor_hint() and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _request_sync() -> void:
	if is_inside_tree():
		call_deferred("_sync_layout")


func _sync_layout() -> void:
	if not is_instance_valid(_collision_polygon) or not is_instance_valid(_artwork):
		return
	var variant := _selected_variant()
	var texture := variant.texture if variant != null and variant.texture != null else art_texture
	var offset := art_offset + (variant.offset if variant != null else Vector2.ZERO)
	var visual_scale := (variant.scale if variant != null else Vector2.ONE) * art_scale_multiplier
	_artwork.texture = texture
	_artwork.centered = false
	_artwork.position = offset
	_artwork.scale = visual_scale
	_artwork.visible = texture != null
	_collision_polygon.position = offset
	_collision_polygon.polygon = _collision_points_in_texture_space(texture)
	if texture == null or collision_points.size() < 3:
		_collision_polygon.disabled = true
	else:
		_collision_polygon.disabled = false
		_collision_polygon.scale = visual_scale
	queue_redraw()


func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]


func _collision_points_in_texture_space(texture: Texture2D) -> PackedVector2Array:
	if texture == null:
		return collision_points
	var texture_size := texture.get_size()
	var scaled_points := PackedVector2Array()
	for point: Vector2 in collision_points:
		scaled_points.append(Vector2(point.x * texture_size.x, point.y * texture_size.y))
	return scaled_points


func _on_body_entered(actor: Node2D) -> void:
	actor_hurt.emit(actor, damage_amount)
	if kill_on_contact:
		actor_killed.emit(actor)


func _draw() -> void:
	var variant := _selected_variant()
	if (variant != null and variant.texture != null) or art_texture != null:
		return
	draw_colored_polygon(collision_points, preview_color)
	draw_polyline(collision_points, Color("ffddd8"), 1.5, true)
