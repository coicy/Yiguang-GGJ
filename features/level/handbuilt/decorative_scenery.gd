@tool
class_name DecorativeScenery
extends Node2D
## A visual-only decoration whose art can be swapped per scene instance.

enum LayoutMode {
	SINGLE,
	GRID,
}

@export_category("Sprite source")
@export var sprite_variants: SpriteVariantSet:
	set(value):
		_disconnect_variant_set()
		sprite_variants = value
		_connect_variant_set()
		_request_apply()
@export_range(0, 255, 1) var variant_index := 0:
	set(value):
		variant_index = max(value, 0)
		_request_apply()

@export_category("Artwork")
## Used only by LevelSpriteVariant entries whose fit mode is FIT_COMPONENT.
@export var component_size := Vector2.ZERO:
	set(value):
		component_size = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_request_apply()
@export var flip_h := false:
	set(value):
		flip_h = value
		_request_apply()
@export var flip_v := false:
	set(value):
		flip_v = value
		_request_apply()

@export_category("Auto tiling")
@export var layout_mode: LayoutMode = LayoutMode.SINGLE:
	set(value):
		layout_mode = value
		_request_apply()
## Number of columns and rows. The texture's scaled size is used as the automatic tile step.
@export var tile_count := Vector2i.ONE:
	set(value):
		tile_count = Vector2i(clampi(value.x, 1, 64), clampi(value.y, 1, 64))
		_request_apply()
## Extra empty space added between adjacent tiles after their scaled texture size.
@export var tile_spacing := Vector2.ZERO:
	set(value):
		tile_spacing = value
		_request_apply()

@onready var _artwork: Sprite2D = %Artwork
@onready var _tiled_artwork: MultiMeshInstance2D = %TiledArtwork

var _connected_variant_set: SpriteVariantSet
var _apply_queued := false
var _editor_preview_signature := 0


func _ready() -> void:
	_connect_variant_set()
	set_process(Engine.is_editor_hint())
	_apply_variant()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var current_signature := _calculate_preview_signature()
	if current_signature == _editor_preview_signature:
		return
	_apply_variant()


func _exit_tree() -> void:
	_disconnect_variant_set()


func set_variant(index: int) -> void:
	variant_index = index


func set_variant_set(value: SpriteVariantSet, index: int = 0) -> void:
	sprite_variants = value
	variant_index = index


func get_artwork() -> Sprite2D:
	return _artwork


func get_tiled_artwork() -> MultiMeshInstance2D:
	return _tiled_artwork


func get_preview_tile_count() -> int:
	var variant := _selected_variant()
	if not Engine.is_editor_hint() or layout_mode != LayoutMode.GRID or variant == null or variant.texture == null:
		return 0
	return tile_count.x * tile_count.y


func get_tile_step() -> Vector2:
	var variant := _selected_variant()
	if variant == null or variant.texture == null:
		return Vector2.ZERO
	return Vector2(variant.texture.get_size()) * _artwork_scale(variant).abs() + tile_spacing


func _request_apply() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_artwork) and is_instance_valid(_tiled_artwork):
		_apply_variant()
		return
	if _apply_queued:
		return
	_apply_queued = true
	call_deferred("_apply_variant")


func _apply_variant() -> void:
	_apply_queued = false
	if not is_instance_valid(_artwork) or not is_instance_valid(_tiled_artwork):
		return
	_editor_preview_signature = _calculate_preview_signature()
	var variant := _selected_variant()
	if variant == null or variant.texture == null:
		_artwork.texture = null
		_artwork.visible = false
		_clear_tiled_artwork()
		queue_redraw()
		return

	var artwork_scale := _artwork_scale(variant)
	_artwork.texture = variant.texture
	_artwork.centered = false
	_artwork.position = variant.offset
	_artwork.scale = artwork_scale
	_artwork.flip_h = flip_h
	_artwork.flip_v = flip_v
	_artwork.visible = layout_mode == LayoutMode.SINGLE

	if layout_mode == LayoutMode.GRID:
		if Engine.is_editor_hint():
			_clear_tiled_artwork()
		else:
			_apply_tiled_artwork(variant, artwork_scale)
	else:
		_clear_tiled_artwork()
	queue_redraw()


func _artwork_scale(variant: LevelSpriteVariant) -> Vector2:
	var artwork_scale := variant.scale
	if variant.fit_mode != LevelSpriteVariant.FitMode.FIT_COMPONENT or component_size.is_zero_approx():
		return artwork_scale
	var texture_size := variant.texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		artwork_scale *= component_size / texture_size
	return artwork_scale


func _apply_tiled_artwork(variant: LevelSpriteVariant, artwork_scale: Vector2) -> void:
	var texture_size := Vector2(variant.texture.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_clear_tiled_artwork()
		return

	var instance_scale := artwork_scale * Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0)
	var occupied_size := texture_size * artwork_scale.abs()
	var tile_step := get_tile_step()
	var quad := QuadMesh.new()
	quad.size = texture_size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = quad
	multimesh.instance_count = tile_count.x * tile_count.y

	var instance_index := 0
	for row in range(tile_count.y):
		for column in range(tile_count.x):
			var cell_origin := Vector2(column * tile_step.x, row * tile_step.y)
			var center := cell_origin + occupied_size * 0.5
			var instance_transform := Transform2D.IDENTITY.scaled(instance_scale)
			instance_transform.origin = center
			multimesh.set_instance_transform_2d(instance_index, instance_transform)
			instance_index += 1

	_tiled_artwork.position = variant.offset
	_tiled_artwork.texture = variant.texture
	_tiled_artwork.multimesh = multimesh
	_tiled_artwork.visible = true


func _clear_tiled_artwork() -> void:
	_tiled_artwork.visible = false
	_tiled_artwork.texture = null
	_tiled_artwork.multimesh = null


func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]


func _calculate_preview_signature() -> int:
	var variant := _selected_variant()
	if variant == null:
		return hash([sprite_variants, variant_index, component_size, flip_h, flip_v, layout_mode, tile_count, tile_spacing])
	return hash([
		sprite_variants,
		variant_index,
		variant.texture,
		variant.offset,
		variant.scale,
		variant.fit_mode,
		component_size,
		flip_h,
		flip_v,
		layout_mode,
		tile_count,
		tile_spacing,
	])


func _connect_variant_set() -> void:
	if not is_inside_tree() or sprite_variants == null or _connected_variant_set == sprite_variants:
		return
	_connected_variant_set = sprite_variants
	if not _connected_variant_set.changed.is_connected(_on_variant_set_changed):
		_connected_variant_set.changed.connect(_on_variant_set_changed)


func _disconnect_variant_set() -> void:
	if _connected_variant_set != null and _connected_variant_set.changed.is_connected(_on_variant_set_changed):
		_connected_variant_set.changed.disconnect(_on_variant_set_changed)
	_connected_variant_set = null


func _on_variant_set_changed() -> void:
	_request_apply()


func _draw() -> void:
	if not Engine.is_editor_hint() or layout_mode != LayoutMode.GRID:
		return
	var variant := _selected_variant()
	if variant == null or variant.texture == null:
		return
	var texture_size := Vector2(variant.texture.get_size())
	var artwork_scale := _artwork_scale(variant)
	var occupied_size := texture_size * artwork_scale.abs()
	var signed_scale := artwork_scale * Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0)
	var tile_step := get_tile_step()
	for row in range(tile_count.y):
		for column in range(tile_count.x):
			var cell_origin := Vector2(column * tile_step.x, row * tile_step.y)
			var center := variant.offset + cell_origin + occupied_size * 0.5
			draw_set_transform(center, 0.0, signed_scale)
			draw_texture(variant.texture, -texture_size * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
