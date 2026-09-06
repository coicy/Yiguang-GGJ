@tool
class_name TerrainPiece
extends StaticBody2D
## A hand-built floor with independent artwork and collision modes.

enum DisplayMode { SPRITE, POLYGON, WHOLE_TEXTURE }
enum CollisionMode { RECTANGLE, POLYGON }
enum PolygonLayout { RECT_FROM_PIECE_SIZE, CUSTOM_POLYGON }

@export_category("Layout")
@export var piece_size: Vector2 = Vector2(192.0, 48.0):
	set(value):
		piece_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_request_sync()

@export_category("Gameplay")
@export var allows_rooting := true
## Only marked, enabled ground may limit the bottom of the camera view.
@export var camera_main_floor: bool = false
@export var one_way_collision := false:
	set(value):
		one_way_collision = value
		_request_sync()

@export_category("Collision")
## Insets are measured from the visual piece rectangle and keep transparent art margins non-solid.
@export_range(0.0, 4096.0, 0.5) var collision_left_inset := 0.0:
	set(value):
		collision_left_inset = maxf(value, 0.0)
		_request_sync()
@export_range(0.0, 4096.0, 0.5) var collision_top_inset := 0.0:
	set(value):
		collision_top_inset = maxf(value, 0.0)
		_request_sync()
@export_range(0.0, 4096.0, 0.5) var collision_right_inset := 0.0:
	set(value):
		collision_right_inset = maxf(value, 0.0)
		_request_sync()
@export_range(0.0, 4096.0, 0.5) var collision_bottom_inset := 0.0:
	set(value):
		collision_bottom_inset = maxf(value, 0.0)
		_request_sync()

@export_category("Modes")
## NinePatchRect art is the default so piece_size extends terrain without stretching pixels.
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

@export_category("Polygon layout")
## Generates a rectangular visual polygon from piece_size, or preserves hand-edited vertices.
@export var polygon_layout: PolygonLayout = PolygonLayout.RECT_FROM_PIECE_SIZE:
	set(value):
		polygon_layout = value
		_request_sync()

@export_category("Artwork")
@export var show_artwork := true:
	set(value):
		show_artwork = value
		_request_sync()
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
@export var tile_art_vertically := true:
	set(value):
		tile_art_vertically = value
		_request_sync()
@export var stretch_art := false:
	set(value):
		stretch_art = value
		_request_sync()
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_request_sync()
## Per-instance phase adjustment for a repeating PolygonArtwork texture.
## Use a negative accumulated width on adjacent pieces to keep a pattern continuous.
@export var polygon_repeat_offset := Vector2.ZERO:
	set(value):
		polygon_repeat_offset = value
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

@onready var _collision_polygon: CollisionPolygon2D = %CollisionPolygon2D
@onready var _terrain_visual: NinePatchRect = %TerrainVisual
@onready var _polygon_artwork: Polygon2D = %PolygonArtwork
@onready var _whole_artwork: Sprite2D = %WholeArtwork
@onready var _left_cap: Sprite2D = %LeftCap
@onready var _right_cap: Sprite2D = %RightCap

var _last_visual_polygon := PackedVector2Array()
var _invalid_polygon_reported := false
var _invalid_root_scale_reported := false
var _is_baking_root_scale := false
var _base_patch_margins := Vector4i()

func _ready() -> void:
	if camera_main_floor:
		add_to_group(&"camera_main_floors")
	_base_patch_margins = Vector4i(
		_terrain_visual.patch_margin_left,
		_terrain_visual.patch_margin_top,
		_terrain_visual.patch_margin_right,
		_terrain_visual.patch_margin_bottom,
	)
	_ensure_polygon_defaults()
	_bake_root_scale_into_piece_size()
	_sync_layout()

func _process(_delta: float) -> void:
	# A NinePatchRect repeats from its size, not from a parent CanvasItem scale.
	# Bake inspector scale on this reusable root into piece_size so visuals and
	# collision both grow without scaling pixels or physics shapes.
	if Engine.is_editor_hint():
		_bake_root_scale_into_piece_size()
	# Native polygon edits write directly to the child. This check only runs in the editor.
	if not Engine.is_editor_hint() or polygon_layout != PolygonLayout.CUSTOM_POLYGON or not collision_follows_visual or display_mode != DisplayMode.POLYGON:
		return
	if _polygon_artwork.polygon != _last_visual_polygon:
		sync_polygons()

func can_root() -> bool:
	return allows_rooting

## Empty means this piece cannot currently provide a camera floor constraint.
func get_camera_floor_rect() -> Rect2:
	if not camera_main_floor or collision_layer == 0 or not is_instance_valid(_collision_polygon):
		return Rect2()
	if _collision_polygon.disabled or _collision_polygon.polygon.size() < 3:
		return Rect2()
	var world_rect := Rect2(_collision_polygon.to_global(_collision_polygon.polygon[0]), Vector2.ZERO)
	for point: Vector2 in _collision_polygon.polygon:
		world_rect = world_rect.expand(_collision_polygon.to_global(point))
	return world_rect

func sync_polygons() -> bool:
	if not is_instance_valid(_polygon_artwork) or not _is_valid_polygon(_polygon_artwork.polygon):
		if not _invalid_polygon_reported:
			push_warning("%s needs a simple, non-self-intersecting polygon with at least three vertices." % name)
			_invalid_polygon_reported = true
		if is_instance_valid(_polygon_artwork):
			_last_visual_polygon = _polygon_artwork.polygon
		return false
	_invalid_polygon_reported = false
	if collision_follows_visual:
		_collision_polygon.polygon = _polygon_artwork.polygon
	_last_visual_polygon = _polygon_artwork.polygon
	_sync_collision_mode()
	return true

func _request_sync() -> void:
	if is_inside_tree():
		call_deferred("_sync_layout")
		update_configuration_warnings()

func _bake_root_scale_into_piece_size() -> void:
	# Whole-texture mode intentionally keeps root scale so the material and
	# StaticBody2D collision transform are scaled together.
	if display_mode == DisplayMode.WHOLE_TEXTURE or _is_baking_root_scale or scale.is_equal_approx(Vector2.ONE):
		return
	# Mirroring carries directional meaning and cannot be converted to a positive size.
	# Leave it intact instead of silently changing the piece orientation.
	if scale.x <= 0.0 or scale.y <= 0.0:
		if not _invalid_root_scale_reported:
			push_warning("%s only bakes positive root scale into piece_size; use a positive Scale for terrain resizing." % name)
			_invalid_root_scale_reported = true
		return
	_invalid_root_scale_reported = false
	_is_baking_root_scale = true
	piece_size *= scale
	scale = Vector2.ONE
	_is_baking_root_scale = false

func _sync_layout() -> void:
	if not is_instance_valid(_collision_polygon):
		return
	_sync_visual_polygon_layout()
	_apply_artwork()
	if collision_mode == CollisionMode.RECTANGLE:
		_collision_polygon.polygon = _collision_rectangle_polygon()
		_sync_collision_mode()
	elif collision_follows_visual:
		sync_polygons()
	else:
		_sync_collision_mode()
	queue_redraw()

func _sync_visual_polygon_layout() -> void:
	if polygon_layout == PolygonLayout.RECT_FROM_PIECE_SIZE:
		_polygon_artwork.polygon = _rectangle_polygon()

func _apply_artwork() -> void:
	var variant := _selected_variant()
	var texture := variant.texture if variant != null and variant.texture != null else art_texture
	var offset := art_offset + (variant.offset if variant != null else Vector2.ZERO)
	var art_scale := variant.scale if variant != null else Vector2.ONE
	var should_stretch := stretch_art or (variant != null and variant.fit_mode == LevelSpriteVariant.FitMode.FIT_COMPONENT)
	var safe_visual_scale := Vector2(maxf(absf(art_scale.x * art_scale_multiplier), 0.01), maxf(absf(art_scale.y * art_scale_multiplier), 0.01))
	var whole_texture := display_mode == DisplayMode.WHOLE_TEXTURE
	_whole_artwork.texture = texture if whole_texture else null
	_whole_artwork.position = offset
	_whole_artwork.scale = safe_visual_scale
	_whole_artwork.rotation = deg_to_rad(art_rotation_degrees)
	_whole_artwork.visible = show_artwork and whole_texture and texture != null
	var visual_size := piece_size / safe_visual_scale
	_terrain_visual.texture = texture
	_terrain_visual.position = offset
	_fit_nine_patch_margins(visual_size)
	_terrain_visual.size = visual_size
	_terrain_visual.scale = safe_visual_scale
	_terrain_visual.rotation = deg_to_rad(art_rotation_degrees)
	_terrain_visual.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH if should_stretch else NinePatchRect.AXIS_STRETCH_MODE_TILE
	_terrain_visual.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH if should_stretch or not tile_art_vertically else NinePatchRect.AXIS_STRETCH_MODE_TILE
	_terrain_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_visual.visible = show_artwork and display_mode == DisplayMode.SPRITE and texture != null
	_polygon_artwork.texture = texture
	var polygon_offset := variant.polygon_texture_offset if variant != null else Vector2.ZERO
	var polygon_scale := variant.polygon_texture_scale if variant != null else Vector2.ONE
	var polygon_rotation_degrees := variant.polygon_texture_rotation if variant != null else 0.0
	# Polygon2D scales texture coordinates, so invert the visual scale used by Sprite2D.
	# This makes an art_scale_multiplier of 0.5 draw half-size tiles instead of cropping one full-size tile.
	_polygon_artwork.texture_offset = polygon_offset + art_offset + polygon_repeat_offset
	_polygon_artwork.texture_scale = polygon_scale / safe_visual_scale
	_polygon_artwork.texture_rotation = deg_to_rad(polygon_rotation_degrees + art_rotation_degrees)
	_polygon_artwork.texture_repeat = variant.polygon_texture_repeat if variant != null else CanvasItem.TEXTURE_REPEAT_ENABLED
	_polygon_artwork.visible = show_artwork and display_mode == DisplayMode.POLYGON and texture != null
	_apply_caps(variant, art_scale * art_scale_multiplier)

func _fit_nine_patch_margins(visual_size: Vector2) -> void:
	# NinePatchRect clamps its rendered size to the sum of opposite patch margins.
	# Shrink margins only for undersized pieces so the rendered bounds still match
	# piece_size and the collision rectangle.
	var horizontal_ratio := _margin_ratio(visual_size.x, _base_patch_margins.x, _base_patch_margins.z)
	var vertical_ratio := _margin_ratio(visual_size.y, _base_patch_margins.y, _base_patch_margins.w)
	_terrain_visual.patch_margin_left = floori(_base_patch_margins.x * horizontal_ratio)
	_terrain_visual.patch_margin_right = floori(_base_patch_margins.z * horizontal_ratio)
	_terrain_visual.patch_margin_top = floori(_base_patch_margins.y * vertical_ratio)
	_terrain_visual.patch_margin_bottom = floori(_base_patch_margins.w * vertical_ratio)

func _margin_ratio(axis_size: float, first_margin: int, second_margin: int) -> float:
	var margin_total := first_margin + second_margin
	if margin_total <= 0:
		return 1.0
	return minf(1.0, axis_size / float(margin_total))

func _apply_caps(variant: LevelSpriteVariant, cap_scale: Vector2) -> void:
	var show_caps := show_artwork and display_mode == DisplayMode.POLYGON and variant != null
	_left_cap.texture = variant.left_cap_texture if show_caps else null
	_left_cap.position = variant.left_cap_offset if show_caps else Vector2.ZERO
	_left_cap.scale = cap_scale
	_left_cap.centered = false
	_left_cap.visible = show_caps and _left_cap.texture != null

	_right_cap.texture = variant.right_cap_texture if show_caps else null
	_right_cap.scale = cap_scale
	_right_cap.centered = false
	if show_caps and _right_cap.texture != null:
		_right_cap.position = Vector2(piece_size.x - _right_cap.texture.get_width() * cap_scale.x, 0.0) + variant.right_cap_offset
	else:
		_right_cap.position = Vector2.ZERO
	_right_cap.visible = show_caps and _right_cap.texture != null

func _sync_collision_mode() -> void:
	var use_polygon := _is_valid_polygon(_collision_polygon.polygon)
	if is_inside_tree():
		_collision_polygon.set_deferred(&"disabled", not use_polygon)
	else:
		_collision_polygon.disabled = not use_polygon
	_collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	_collision_polygon.one_way_collision = one_way_collision and collision_mode == CollisionMode.POLYGON and use_polygon

func _ensure_polygon_defaults() -> void:
	var rectangle := _rectangle_polygon()
	if _polygon_artwork.polygon.size() < 3:
		_polygon_artwork.polygon = rectangle
	if _collision_polygon.polygon.size() < 3:
		_collision_polygon.polygon = rectangle
	_last_visual_polygon = _polygon_artwork.polygon

func _rectangle_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(piece_size.x, 0.0),
		piece_size,
		Vector2(0.0, piece_size.y),
	])

func _collision_rectangle_polygon() -> PackedVector2Array:
	var collision_size := Vector2(
		maxf(piece_size.x - collision_left_inset - collision_right_inset, 1.0),
		maxf(piece_size.y - collision_top_inset - collision_bottom_inset, 1.0)
	)
	var origin := Vector2(collision_left_inset, collision_top_inset)
	return PackedVector2Array([
		origin,
		origin + Vector2(collision_size.x, 0.0),
		origin + collision_size,
		origin + Vector2(0.0, collision_size.y),
	])

func _selected_variant() -> LevelSpriteVariant:
	if sprite_variants == null or sprite_variants.variants.is_empty():
		return null
	return sprite_variants.variants[clampi(variant_index, 0, sprite_variants.variants.size() - 1)]

func _is_valid_polygon(points: PackedVector2Array) -> bool:
	return points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if one_way_collision and collision_mode != CollisionMode.POLYGON:
		warnings.append("one_way_collision only applies when Collision Mode is Polygon.")
	return warnings

func _draw() -> void:
	if not show_artwork:
		return
	var variant := _selected_variant()
	if (variant != null and variant.texture != null) or art_texture != null:
		return
	if display_mode == DisplayMode.POLYGON and _is_valid_polygon(_polygon_artwork.polygon):
		var outline := PackedVector2Array(_polygon_artwork.polygon)
		outline.append(_polygon_artwork.polygon[0])
		draw_colored_polygon(_polygon_artwork.polygon, placeholder_color)
		draw_polyline(outline, Color("d5f0cf"), 2.0, true)
		return
	draw_rect(Rect2(Vector2.ZERO, piece_size), placeholder_color)
	draw_rect(Rect2(Vector2.ZERO, piece_size), Color("d5f0cf"), false, 2.0)
