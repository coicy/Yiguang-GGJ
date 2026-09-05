@tool
class_name HazardArea
extends Area2D
## A resizable death volume for hand-built spikes, pits, and hostile scenery.

signal actor_killed(actor: Node2D)

@export var area_size: Vector2 = Vector2(96.0, 32.0):
	set(value):
		area_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_sync()
@export var preview_color := Color(0.74, 0.16, 0.21, 0.7):
	set(value):
		preview_color = value
		queue_redraw()

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
@export var stretch_art := false:
	set(value):
		stretch_art = value
		_request_sync()
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_request_sync()
@export_range(0.01, 8.0, 0.01) var art_scale_multiplier: float = 1.0:
	set(value):
		art_scale_multiplier = maxf(value, 0.01)
		_request_sync()

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _artwork: Sprite2D = %Artwork


func _ready() -> void:
	add_to_group(&"handbuilt_hazards")
	_make_collision_shape_unique()
	_sync_layout()
	if not Engine.is_editor_hint() and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _request_sync() -> void:
	if is_inside_tree():
		call_deferred("_sync_layout")


func _sync_layout() -> void:
	if not is_instance_valid(_collision_shape) or not is_instance_valid(_artwork):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = area_size
	_collision_shape.position = area_size * 0.5
	var variant := _selected_variant()
	var texture := variant.texture if variant != null and variant.texture != null else art_texture
	var offset := art_offset + (variant.offset if variant != null else Vector2.ZERO)
	var art_scale := variant.scale if variant != null else Vector2.ONE
	var should_stretch := stretch_art or (variant != null and variant.fit_mode == LevelSpriteVariant.FitMode.FIT_COMPONENT)
	_artwork.texture = texture
	_artwork.position = offset
	_artwork.centered = false
	_artwork.visible = texture != null
	_artwork.scale = art_scale * art_scale_multiplier
	if texture != null and should_stretch:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_artwork.scale *= area_size / texture_size
	queue_redraw()


func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _on_body_entered(actor: Node2D) -> void:
	actor_killed.emit(actor)


func _draw() -> void:
	var variant := _selected_variant()
	if (variant != null and variant.texture != null) or art_texture != null:
		return
	draw_rect(Rect2(Vector2.ZERO, area_size), preview_color)
	draw_rect(Rect2(Vector2.ZERO, area_size), Color("ffddd8"), false, 1.5)
