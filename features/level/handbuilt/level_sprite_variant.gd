@tool
class_name LevelSpriteVariant
extends Resource
## One reusable sprite option for a hand-built level component.

enum FitMode {
	NATIVE_SIZE,
	FIT_COMPONENT,
}

@export var id: StringName
@export var texture: Texture2D
@export var offset := Vector2.ZERO
@export var scale := Vector2.ONE
@export var fit_mode: FitMode = FitMode.NATIVE_SIZE
@export_category("Polygon texture")
@export var polygon_texture_offset := Vector2.ZERO
@export var polygon_texture_scale := Vector2.ONE
@export_range(-360.0, 360.0, 1.0) var polygon_texture_rotation := 0.0
@export_enum("Default", "Disabled", "Enabled", "Mirror") var polygon_texture_repeat: int = CanvasItem.TEXTURE_REPEAT_ENABLED

@export_category("Terrain caps")
## Optional endpoint art for a repeating TerrainPiece polygon. Offsets are relative to each outer edge.
@export var left_cap_texture: Texture2D
@export var left_cap_offset := Vector2.ZERO
@export var right_cap_texture: Texture2D
@export var right_cap_offset := Vector2.ZERO
