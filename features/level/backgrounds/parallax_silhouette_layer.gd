class_name ParallaxSilhouetteLayer
extends Node2D
## Draws one repeatable, decorative layer for the hand-built level backdrop.

@export_enum("sky", "far_canopy", "mid_structure", "near_foliage") var layer_style := "sky"
@export var tile_width := 1344.0
@export var tile_height := 640.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match layer_style:
		"sky":
			_draw_sky()
		"far_canopy":
			_draw_far_canopy()
		"mid_structure":
			_draw_mid_structure()
		"near_foliage":
			_draw_near_foliage()


func _draw_sky() -> void:
	draw_rect(
		Rect2(-tile_width, -tile_height, tile_width * 3.0, tile_height * 3.0),
		Color("527883"),
	)
	draw_circle(Vector2(tile_width * 0.62, 112.0), 138.0, Color(0.75, 0.91, 0.76, 0.10))
	draw_circle(Vector2(tile_width * 0.62, 112.0), 82.0, Color(0.86, 0.97, 0.78, 0.08))
	for star in _stars():
		draw_circle(star.position, star.radius, Color(0.85, 0.98, 0.82, star.alpha))
	for y_offset in [256.0, 392.0, 522.0]:
		draw_line(
			Vector2(-tile_width, y_offset),
			Vector2(tile_width * 2.0, y_offset),
			Color(0.74, 0.94, 0.79, 0.045),
			2.0,
		)


func _draw_far_canopy() -> void:
	var base_y := 472.0
	var peaks := PackedVector2Array([
		Vector2(-96.0, base_y), Vector2(-96.0, 356.0), Vector2(48.0, 332.0),
		Vector2(154.0, 382.0), Vector2(274.0, 302.0), Vector2(402.0, 362.0),
		Vector2(552.0, 288.0), Vector2(684.0, 348.0), Vector2(828.0, 315.0),
		Vector2(976.0, 374.0), Vector2(1134.0, 296.0), Vector2(1280.0, 362.0),
		Vector2(1440.0, 326.0), Vector2(1440.0, base_y),
	])
	draw_colored_polygon(peaks, Color("315c5f"))
	for x_offset in [-32.0, 140.0, 318.0, 494.0, 706.0, 886.0, 1084.0, 1264.0]:
		_draw_distant_tree(Vector2(x_offset, base_y))


func _draw_mid_structure() -> void:
	var structure_color := Color("244951")
	var highlight_color := Color(0.48, 0.78, 0.69, 0.18)
	for x_offset in [-120.0, 260.0, 640.0, 1020.0]:
		draw_line(Vector2(x_offset, 500.0), Vector2(x_offset + 88.0, 172.0), structure_color, 18.0)
		draw_line(Vector2(x_offset + 176.0, 500.0), Vector2(x_offset + 88.0, 172.0), structure_color, 18.0)
		draw_arc(Vector2(x_offset + 88.0, 334.0), 163.0, PI, TAU, 20, structure_color, 18.0)
		draw_arc(Vector2(x_offset + 88.0, 334.0), 135.0, PI, TAU, 20, highlight_color, 2.0)
	for y_offset in [258.0, 430.0]:
		draw_line(Vector2(-tile_width, y_offset), Vector2(tile_width * 2.0, y_offset), structure_color, 12.0)
		draw_line(Vector2(-tile_width, y_offset - 5.0), Vector2(tile_width * 2.0, y_offset - 5.0), highlight_color, 2.0)


func _draw_near_foliage() -> void:
	var floor_color := Color("173c43")
	draw_rect(Rect2(-tile_width, 482.0, tile_width * 3.0, 240.0), floor_color)
	for x_offset in [-72.0, 112.0, 288.0, 476.0, 664.0, 842.0, 1022.0, 1208.0, 1396.0]:
		_draw_leaf_cluster(Vector2(x_offset, 506.0))
	for x_offset in [32.0, 366.0, 732.0, 1096.0]:
		draw_line(Vector2(x_offset, 506.0), Vector2(x_offset + 32.0, 350.0), Color("1c4850"), 9.0)
		draw_circle(Vector2(x_offset + 32.0, 350.0), 18.0, Color("285961"))


func _draw_distant_tree(root_position: Vector2) -> void:
	var trunk_color := Color("2a5155")
	var canopy_color := Color("28565a")
	draw_line(root_position, root_position + Vector2(8.0, -188.0), trunk_color, 14.0)
	draw_circle(root_position + Vector2(-22.0, -194.0), 45.0, canopy_color)
	draw_circle(root_position + Vector2(29.0, -220.0), 52.0, canopy_color)
	draw_circle(root_position + Vector2(65.0, -177.0), 42.0, canopy_color)


func _draw_leaf_cluster(root_position: Vector2) -> void:
	var leaf_color := Color("1e4d51")
	var accent_color := Color(0.31, 0.69, 0.58, 0.16)
	var leaves := [
		PackedVector2Array([root_position, root_position + Vector2(-94.0, -114.0), root_position + Vector2(-22.0, -72.0)]),
		PackedVector2Array([root_position, root_position + Vector2(-24.0, -155.0), root_position + Vector2(20.0, -76.0)]),
		PackedVector2Array([root_position, root_position + Vector2(104.0, -119.0), root_position + Vector2(34.0, -67.0)]),
	]
	for leaf in leaves:
		draw_colored_polygon(leaf, leaf_color)
		draw_polyline(leaf, accent_color, 2.0, true)


func _stars() -> Array[Dictionary]:
	return [
		{"position": Vector2(88.0, 86.0), "radius": 2.0, "alpha": 0.44},
		{"position": Vector2(214.0, 164.0), "radius": 1.5, "alpha": 0.31},
		{"position": Vector2(404.0, 62.0), "radius": 2.5, "alpha": 0.37},
		{"position": Vector2(824.0, 194.0), "radius": 1.5, "alpha": 0.36},
		{"position": Vector2(1048.0, 86.0), "radius": 2.0, "alpha": 0.42},
		{"position": Vector2(1234.0, 218.0), "radius": 1.5, "alpha": 0.29},
	]
