@tool
class_name TriggerButton
extends Area2D
## A one-shot button that activates locally assigned platform or door targets.

signal pressed(button: TriggerButton, actor: Node2D)

@export_category("Layout")
@export var button_size: Vector2 = Vector2(48.0, 16.0):
	set(value):
		button_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_sync()
@export_range(0.0, 32.0, 1.0) var activation_top_margin := 6.0:
	set(value):
		activation_top_margin = maxf(value, 0.0)
		_request_sync()

@export_category("Connections")
@export_node_path("Node") var targets: Array[NodePath] = []:
	set(value):
		targets = value
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
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_request_sync()
@export var stretch_art := false:
	set(value):
		stretch_art = value
		_request_sync()

var _is_pressed := false

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _artwork: Sprite2D = %Artwork


func _ready() -> void:
	_make_collision_shape_unique()
	_sync_layout()
	if not Engine.is_editor_hint() and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func press(actor: Node2D = null) -> bool:
	if _is_pressed:
		return false
	_is_pressed = true
	for target_path: NodePath in targets:
		var target := get_node_or_null(target_path)
		if target != null and target.has_method(&"activate"):
			target.call(&"activate")
	pressed.emit(self, actor)
	queue_redraw()
	return true


func reset_button() -> void:
	_is_pressed = false
	queue_redraw()


func is_pressed() -> bool:
	return _is_pressed


func _on_body_entered(actor: Node2D) -> void:
	if actor.is_in_group(&"player"):
		press(actor)


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
	shape.size = Vector2(button_size.x, button_size.y + activation_top_margin)
	_collision_shape.position = Vector2(button_size.x * 0.5, button_size.y * 0.5 - activation_top_margin * 0.5)
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
			_artwork.scale *= button_size / texture_size
	queue_redraw()


func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]


func _make_collision_shape_unique() -> void:
	if is_instance_valid(_collision_shape) and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate(true)


func _draw() -> void:
	var variant := _selected_variant()
	if (variant == null or variant.texture == null) and art_texture == null:
		var fill := Color("86d96d") if _is_pressed else Color("e0bc43")
		draw_rect(Rect2(Vector2.ZERO, button_size), fill)
		draw_rect(Rect2(Vector2.ZERO, button_size), Color("1c251d"), false, 2.0)
	if Engine.is_editor_hint():
		for target_path: NodePath in targets:
			var target := get_node_or_null(target_path) as Node2D
			if target != null:
				draw_dashed_line(button_size * 0.5, to_local(target.global_position), Color("f3d875"), 8.0, 1.5, true)
