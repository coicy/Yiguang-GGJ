extends SceneTree

const WIDTH: int = 2048
const HEIGHT: int = 1152
const SCALE: float = 1520.0 / 2048.0
var canvas: Image

func _init() -> void:
	canvas = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.32, 0.43, 0.42))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/rooms/core/geometry_guide.json"))
	# Quiet rear vessel and backing walls. These are visual, never collision.
	for y: int in range(290, 720):
		for x: int in range(852, 1197):
			var relative: Vector2 = Vector2(float(x - 1024) / 172.0, float(y - 505) / 215.0)
			if relative.length_squared() <= 1.0:
				canvas.set_pixel(x, y, Color(0.41, 0.55, 0.50))
	canvas.fill_rect(Rect2i(990, 180, 66, 125), Color(0.28, 0.37, 0.34))
	var roof: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(WIDTH, 0)])
	var edge: Array = data.roofEdgeWorld.duplicate()
	edge.reverse()
	for p: Array in edge:
		roof.append(Vector2((float(p[0]) - 7040.0) / SCALE, (float(p[1]) + 215.0) / SCALE))
	fill_polygon(roof, Color(0.08, 0.105, 0.10))
	var floor_px: int = roundi((400.0 + 215.0) / SCALE)
	canvas.fill_rect(Rect2i(0, floor_px, WIDTH, HEIGHT - floor_px), Color(0.07, 0.09, 0.08))
	canvas.fill_rect(Rect2i(0, floor_px, WIDTH, 4), Color(0.48, 0.53, 0.44))
	var result: Error = canvas.save_png("res://assets/source/rooms/core/collision_guide.png")
	print("CORE_GUIDE ", result, " ", WIDTH, "x", HEIGHT, " floor pixel=", floor_px)
	quit(int(result))

func fill_polygon(polygon: PackedVector2Array, color: Color) -> void:
	for y: int in range(HEIGHT):
		var intersections: Array[float] = []
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(a.x + (float(y) - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for i: int in range(0, intersections.size() - 1, 2):
			var left: int = maxi(0, ceili(intersections[i]))
			var right: int = mini(WIDTH, ceili(intersections[i + 1]))
			if right > left:
				canvas.fill_rect(Rect2i(left, y, right - left, 1), color)
