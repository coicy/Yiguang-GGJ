@tool
class_name TerrainSkin
extends Node2D
## (0, 0) is the walk plane. All art stays within span/depth, with no collision.
## Heights are aspect-preserving limits; shallow pieces crop the section below.

@export var profile: TerrainSurface:
	set(value):
		if profile != null and profile.changed.is_connected(_on_profile_changed):
			profile.changed.disconnect(_on_profile_changed)
		profile = value
		if profile != null and not profile.changed.is_connected(_on_profile_changed):
			profile.changed.connect(_on_profile_changed)
		queue_redraw()
@export var span: float = 192.0:
	set(value):
		span = maxf(value, 1.0)
		queue_redraw()
@export var depth: float = 120.0:
	set(value):
		depth = maxf(value, 1.0)
		queue_redraw()
@export var pattern_offset: int = 0:
	set(value):
		pattern_offset = value
		queue_redraw()

func _ready() -> void:
	if material == null:
		material = preload("res://features/level/terrain/terrain_cutout.tres")

func _on_profile_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if profile == null:
		return
	var surface_y := minf(profile.surface_height * 0.35, depth)
	if profile.fill_foundation and depth > surface_y:
		draw_rect(Rect2(0.0, surface_y, span, depth - surface_y), profile.foundation_color)
	if profile.support_texture != null:
		_draw_supports(surface_y)
	if profile.body_texture != null:
		_draw_body(surface_y)
	if not profile.surfaces.is_empty():
		_draw_surfaces()
	# Thin material lip follows the actual collision plane, without leafy overhang.
	draw_line(Vector2.ZERO, Vector2(span, 0.0), profile.top_edge, 0.8, true)

func _natural_size(texture: Texture2D, bounds: Vector2) -> Vector2:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ONE
	return source_size * minf(bounds.x / source_size.x, bounds.y / source_size.y)

func _draw_supports(y: float) -> void:
	var count := maxi(1, floori(span / profile.support_spacing))
	var size := _natural_size(profile.support_texture, profile.support_size)
	# A shallow ledge cannot show a meaningful bracket; a severed root fragment
	# would imply a false gap underneath its otherwise solid walking surface.
	if depth - y < size.y * 0.65:
		return
	for index in range(count):
		var center_x := (float(index) + 0.5) * span / float(count)
		_draw_clipped(profile.support_texture, Rect2(center_x - size.x * 0.5, y, size.x, size.y), Rect2(Vector2.ZERO, profile.support_texture.get_size()), profile.support_tint)

func _draw_body(y: float) -> void:
	var texture := profile.body_texture
	var maximum_size := _natural_size(texture, Vector2(profile.body_width, profile.body_height))
	var count := maxi(1, ceili(span / maximum_size.x))
	var width := span / float(count)
	var height := width * texture.get_height() / float(texture.get_width())
	for index in range(count):
		_draw_clipped(texture, Rect2(float(index) * width, y, width, height), Rect2(Vector2.ZERO, texture.get_size()), profile.body_tint)

func _draw_surfaces() -> void:
	var textures: Array[Texture2D] = []
	var maximum_width := profile.surface_width
	for texture: Texture2D in profile.surfaces:
		if texture == null:
			continue
		textures.append(texture)
		maximum_width = minf(maximum_width, _natural_size(texture, Vector2(profile.surface_width, profile.surface_height)).x)
	if textures.is_empty():
		return
	# Distribute complete panels across the span. Uniform scaling keeps finite end
	# caps intact and prevents a final sliver, half opening or half log.
	var count := maxi(1, ceili(span / maximum_width))
	var width := span / float(count)
	for index in range(count):
		var texture := textures[posmod(index + pattern_offset, textures.size())]
		var height := width * texture.get_height() / float(texture.get_width())
		_draw_clipped(texture, Rect2(float(index) * width, 0.0, width, height), Rect2(Vector2.ZERO, texture.get_size()), profile.surface_tint)

func _draw_clipped(texture: Texture2D, destination: Rect2, source: Rect2, tint: Color) -> void:
	var visible_rect := destination.intersection(Rect2(0.0, 0.0, span, depth))
	if not visible_rect.has_area():
		return
	var ratio := source.size / destination.size
	var visible_source := Rect2(source.position + (visible_rect.position - destination.position) * ratio, visible_rect.size * ratio)
	draw_texture_rect_region(texture, visible_rect, visible_source, tint)
