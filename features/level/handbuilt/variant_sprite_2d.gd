@tool
class_name VariantSprite2D
extends Sprite2D
## A visual-only Sprite2D that applies a reusable SpriteVariantSet entry.

@export var variant_set: SpriteVariantSet:
	set(value):
		variant_set = value
		_request_apply()
@export var variant_index := 0:
	set(value):
		variant_index = max(value, 0)
		_request_apply()
@export var component_size := Vector2.ZERO:
	set(value):
		component_size = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_request_apply()


func _ready() -> void:
	_apply_variant()


func set_component_size(value: Vector2) -> void:
	component_size = value


func _request_apply() -> void:
	if is_inside_tree():
		call_deferred("_apply_variant")


func _apply_variant() -> void:
	var variant := _selected_variant()
	if variant == null or variant.texture == null:
		texture = null
		return
	texture = variant.texture
	centered = false
	position = variant.offset
	scale = variant.scale
	if variant.fit_mode == LevelSpriteVariant.FitMode.FIT_COMPONENT and not component_size.is_zero_approx():
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			scale *= component_size / texture_size


func _selected_variant() -> LevelSpriteVariant:
	if variant_set == null or variant_set.variants.is_empty():
		return null
	return variant_set.variants[clampi(variant_index, 0, variant_set.variants.size() - 1)]
