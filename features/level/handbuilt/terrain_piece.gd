@tool
class_name TerrainPiece
extends StaticBody2D
## A hand-built floor with independent artwork and collision modes.

enum DisplayMode { SPRITE, POLYGON }
enum CollisionMode { RECTANGLE, POLYGON }

@export_category("Layout")
@export var piece_size: Vector2 = Vector2(192.0, 48.0):
	set(value):
		piece_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_sync()

@export_category("Gameplay")
@export var allows_rooting := true
@export var one_way_collision := false:
	set(value):
		one_way_collision = value
		_request_sync()

@export_category("Modes")
@export var display_mode: DisplayMode = DisplayMode.SPRITE:
	set(value):
		display_mode = value
		_request_sync()
@export var collision_mode: CollisionMode = CollisionMode.RECTANGLE:
	set(value):
		collision_mode = value
		_request_sync()
@export var collision_follows_visual := true:
	set(value):
		collision_follows_visual = value
		_request_sync()

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
@export_range(0.01, 8.0, 0.01) var art_scale_multiplier := 1.0:
	set(value):
		art_scale_multiplier = maxf(value, 0.01)
		_request_sync()
@export_range(-360.0, 360.0, 1.0) var art_rotation_degrees := 0.0:
	set(value):
		art_rotation_degrees = value
		_request_sync()
@export var placeholder_color := Color("31543b"):
	set(value):
		placeholder_color = value
		queue_redraw()

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _collision_polygon: CollisionPolygon2D = %CollisionPolygon2D
@onready var _artwork: Sprite2D = %Artwork
@onready var _polygon_artwork: Polygon2D = %PolygonArtwork

var _last_visual_polygon := PackedVector2Array()

func _ready() -> void:
	_make_collision_shape_unique()
	_ensure_polygon_defaults()
	_sync_layout()

func _process(_delta: float) -> void:
	# Native polygon edits write directly to the child. This check only runs in the editor.
	if not Engine.is_editor_hint() or not collision_follows_visual or display_mode != DisplayMode.POLYGON:
		return
	if _polygon_artwork.polygon != _last_visual_polygon:
		sync_polygons()

func can_root() -> bool:
	return allows_rooting

func sync_polygons() -> bool:
	if not is_instance_valid(_polygon_artwork) or not _is_valid_polygon(_polygon_artwork.polygon):
		push_warning("%s needs a simple polygon with at least three vertices." % name)
		return false
	if collision_follows_visual:
		_collision_polygon.polygon = _polygon_artwork.polygon
	_last_visual_polygon = _polygon_artwork.polygon
	_sync_collision_mode()
	return true

func _request_sync() -> void:
	if is_inside_tree():
		call_deferred("_sync_layout")

func _sync_layout() -> void:
	if not is_instance_valid(_collision_shape) or not is_instance_valid(_collision_polygon):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = piece_size
	_collision_shape.position = piece_size * 0.5
	_apply_artwork()
	_sync_collision_mode()
	queue_redraw()

func _apply_artwork() -> void:
	var variant := _selected_variant()
	var texture := variant.texture if variant != null and variant.texture != null else art_texture
	var offset := art_offset + (variant.offset if variant != null else Vector2.ZERO)
	var art_scale := variant.scale if variant != null else Vector2.ONE
	var should_stretch := stretch_art or (variant != null and variant.fit_mode == LevelSpriteVariant.FitMode.FIT_COMPONENT)
	_artwork.texture = texture
	_artwork.position = offset
	_artwork.centered = false
	_artwork.visible = display_mode == DisplayMode.SPRITE and texture != null
	_artwork.scale = art_scale * art_scale_multiplier
	_artwork.rotation = deg_to_rad(art_rotation_degrees)
	if texture != null and should_stretch:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_artwork.scale *= piece_size / texture_size
	_polygon_artwork.texture = texture
	_polygon_artwork.texture_offset = variant.get(&"polygon_texture_offset") if variant != null else Vector2.ZERO
	_polygon_artwork.texture_scale = variant.get(&"polygon_texture_scale") if variant != null else Vector2.ONE
	_polygon_artwork.texture_rotation = variant.get(&"polygon_texture_rotation") if variant != null else 0.0
	_polygon_artwork.texture_repeat = variant.get(&"polygon_texture_repeat") if variant != null else CanvasItem.TEXTURE_REPEAT_ENABLED
	_polygon_artwork.visible = display_mode == DisplayMode.POLYGON and texture != null

func _sync_collision_mode() -> void:
	var use_polygon := collision_mode == CollisionMode.POLYGON and _is_valid_polygon(_collision_polygon.polygon)
	_collision_shape.disabled = use_polygon
	_collision_polygon.disabled = not use_polygon
	_collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	_collision_polygon.one_way_collision = one_way_collision

func _ensure_polygon_defaults() -> void:
	var rectangle := PackedVector2Array([Vector2.ZERO, Vector2(piece_size.x, 0.0), piece_size, Vector2(0.0, piece_size.y)])
	if _polygon_artwork.polygon.size() < 3:
		_polygon_artwork.polygon = rectangle
	if _collision_polygon.polygon.size() < 3:
		_collision_polygon.polygon = rectangle
	_last_visual_polygon = _polygon_artwork.polygon

func _selected_variant() -> LevelSpriteVariant:
	return sprite_variants.get_variant(variant_index) if sprite_variants != null else null

func _is_valid_polygon(points: PackedVector2Array) -> bool:
	return points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty()

func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)

func _draw() -> void:
	var variant := _selected_variant()
	if (variant != null and variant.texture != null) or art_texture != null:
		return
	draw_rect(Rect2(Vector2.ZERO, piece_size), placeholder_color)
	draw_rect(Rect2(Vector2.ZERO, piece_size), Color("d5f0cf"), false, 2.0)
