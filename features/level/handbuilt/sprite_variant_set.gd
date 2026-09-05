@tool
class_name SpriteVariantSet
extends Resource
## A shared Inspector asset containing all visual variants for one component family.

@export var display_name := ""
@export var variants: Array[LevelSpriteVariant] = []
