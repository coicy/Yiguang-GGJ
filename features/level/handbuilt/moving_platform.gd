@tool
class_name MovingPlatform
extends Node2D
## A manually placed, physics-synchronised platform with one explicit destination.

signal motion_started(platform: MovingPlatform)
signal motion_completed(platform: MovingPlatform)

@export_category("Layout")
@export var platform_size: Vector2 = Vector2(128.0, 24.0):
	set(value):
		platform_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_sync()
@export var destination_offset := Vector2(192.0, 0.0):
	set(value):
		destination_offset = value
		_request_sync()

@export_category("Movement")
@export_range(0.05, 30.0, 0.05) var travel_duration := 1.25
@export var starts_activated := false

@export_category("Event Bus")
@export var activation_event: StringName = &""

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
@export var placeholder_color := Color("567f64"):
	set(value):
		placeholder_color = value
		queue_redraw()

var _elapsed := 0.0
var _is_moving := false
var _is_activated := false

@onready var _body: AnimatableBody2D = %Body
@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _artwork: Sprite2D = %Artwork
@onready var _destination: Marker2D = %Destination


func _ready() -> void:
	_make_collision_shape_unique()
	_sync_layout()
	if not Engine.is_editor_hint() and starts_activated:
		activate()


func receive_level_event(event_id: StringName) -> void:
	if activation_event != &"" and event_id == activation_event:
		activate()


func activate() -> bool:
	if Engine.is_editor_hint() or _is_activated or _is_moving:
		return false
	_is_activated = true
	_is_moving = true
	_elapsed = 0.0
	motion_started.emit(self)
	return true


func reset_platform() -> void:
	_is_activated = false
	_is_moving = false
	_elapsed = 0.0
	if is_instance_valid(_body):
		_body.position = Vector2.ZERO
	queue_redraw()


func is_activated() -> bool:
	return _is_activated


func is_moving() -> bool:
	return _is_moving


func has_completed_motion() -> bool:
	return _is_activated and not _is_moving


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _is_moving:
		return
	_elapsed = minf(_elapsed + delta, travel_duration)
	var progress := _elapsed / travel_duration
	var eased := _smooth_step(progress)
	_body.position = destination_offset * eased
	queue_redraw()
	if progress >= 1.0:
		_is_moving = false
		motion_completed.emit(self)


func _request_sync() -> void:
	if is_inside_tree():
		call_deferred("_sync_layout")


func _sync_layout() -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_collision_shape) or not is_instance_valid(_artwork) or not is_instance_valid(_destination):
		return
	var shape := _collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	shape.size = platform_size
	_collision_shape.position = platform_size * 0.5
	_destination.position = destination_offset
	var variant := _selected_variant()
	var texture := variant.texture if variant != null and variant.texture != null else art_texture
	var offset := art_offset + (variant.offset if variant != null else Vector2.ZERO)
	var art_scale := variant.scale if variant != null else Vector2.ONE
	var should_stretch := stretch_art or (variant != null and variant.fit_mode == LevelSpriteVariant.FitMode.FIT_COMPONENT)
	_artwork.texture = texture
	_artwork.position = offset
	_artwork.centered = false
	_artwork.visible = texture != null
	_artwork.scale = art_scale
	if texture != null and should_stretch:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			_artwork.scale *= platform_size / texture_size
	queue_redraw()


func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _smooth_step(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_dashed_line(Vector2.ZERO, destination_offset, Color("85d9ff"), 10.0, 1.5, true)
		draw_circle(destination_offset, 7.0, Color(0.25, 0.78, 1.0, 0.35))
		return
	var variant := _selected_variant()
	if (variant == null or variant.texture == null) and art_texture == null and is_instance_valid(_body):
		draw_rect(Rect2(_body.position, platform_size), placeholder_color)
		draw_rect(Rect2(_body.position, platform_size), Color("d5f0cf"), false, 2.0)
