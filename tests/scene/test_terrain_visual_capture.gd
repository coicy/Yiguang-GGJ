extends SceneTree
## Captures production TerrainSkin and AtlasTextures; this is not a playable test map.
const SKIN: PackedScene = preload("res://features/level/terrain/terrain_skin.tscn")
const CUTOUT: Material = preload("res://features/level/terrain/terrain_cutout.tres")
const PROFILES: PackedStringArray = ["nursery", "moss", "spore", "workshop", "canopy", "courtyard", "core"]
const PARTS: PackedStringArray = ["drain", "catwalk", "culvert", "pipe", "buttress", "core_plinth", "root_soil", "fungal_log", "seedling_tray", "broken_planter"]
var checks: int = 0
var failures: int = 0
var light_energy: float = -1.0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280, 880)
	root.content_scale_size = root.size
	RenderingServer.set_default_clear_color(Color("#243831"))
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "profiles_a"
	if mode.begins_with("lit_"):
		light_energy = 1.8 if mode == "lit_day_1p8" else 0.3
	_check_resources()
	if mode == "parts":
		_capture_parts()
	else:
		_capture_profiles(4 if mode == "profiles_b" else 0)
	await create_timer(0.10).timeout
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://build/qa/terrain-visuals")
	DirAccess.make_dir_recursive_absolute(directory)
	var output := directory.path_join("terrain_%s.webp" % mode)
	var picture := root.get_texture().get_image()
	picture.resize(1024, 704, Image.INTERPOLATE_LANCZOS)
	var error := picture.save_webp(output)
	_expect(error == OK, "capture saved")
	print("TERRAIN_VISUAL_CAPTURE ", output)
	print("TERRAIN_RESOURCE_CHECKS ", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
func _check_resources() -> void:
	for id in PARTS:
		var texture := load("res://assets/runtime/terrain/parts/%s.tres" % id) as AtlasTexture
		_expect(texture != null, "%s loads" % id)
		if texture != null:
			_expect(texture.region.has_area() and Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "%s stays within atlas" % id)
	var buttress := load("res://assets/runtime/terrain/parts/buttress.tres") as AtlasTexture
	var plinth := load("res://assets/runtime/terrain/parts/core_plinth.tres") as AtlasTexture
	_expect(not buttress.region.intersects(plinth.region), "buttress excludes adjacent plinth")
	for id in PROFILES:
		var surface := load("res://features/level/terrain/data/%s.tres" % id) as TerrainSurface
		_expect(surface != null and not surface.surfaces.is_empty(), "%s surface available" % id)
func _capture_profiles(first: int) -> void:
	for index in range(first, mini(first + 4, PROFILES.size())):
		var local := index - first
		var origin := Vector2(50 + (local % 2) * 640, 72 + (local / 2) * 440)
		var surface := load("res://features/level/terrain/data/%s.tres" % PROFILES[index]) as TerrainSurface
		_label(origin + Vector2(0, -47), PROFILES[index].to_upper() + " / span 420 / depth 150", 22)
		var skin := SKIN.instantiate() as TerrainSkin
		skin.position = origin
		skin.profile = surface
		skin.span = 420.0
		skin.depth = 150.0
		skin.scale = Vector2.ONE * 1.28
		skin.pattern_offset = index
		root.add_child(skin)
		if light_energy >= 0.0:
			_add_flower_light(origin + Vector2(268.8, -43.52))
		var short_skin := SKIN.instantiate() as TerrainSkin
		short_skin.position = origin + Vector2(0, 255)
		short_skin.profile = surface
		short_skin.span = 90.0
		short_skin.depth = 28.0
		short_skin.scale = Vector2.ONE * 1.8
		root.add_child(short_skin)
		_label(origin + Vector2(190, 255), "SHORT LEDGE / 90 x 28
Original proportions; crop below", 16)
func _capture_parts() -> void:
	for index in range(PARTS.size()):
		var column := index % 5
		var row := index / 5
		var origin := Vector2(column * 256, row * 440)
		var background := ColorRect.new()
		background.position = origin + Vector2(10, 10)
		background.size = Vector2(236, 416)
		background.color = Color("#758077") if index % 2 == 0 else Color("#182c29")
		root.add_child(background)
		_label(origin + Vector2(19, 28), PARTS[index], 19)
		var texture := load("res://assets/runtime/terrain/parts/%s.tres" % PARTS[index]) as AtlasTexture
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.material = CUTOUT
		sprite.scale = Vector2.ONE * minf(212.0 / texture.get_width(), 300.0 / texture.get_height())
		sprite.position = origin + Vector2(128, 230)
		root.add_child(sprite)
		_label(origin + Vector2(19, 387), "%d x %d / alpha 0.85" % [texture.get_width(), texture.get_height()], 14)
func _add_flower_light(at: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var radial := GradientTexture2D.new()
	radial.gradient = gradient
	radial.width = 256
	radial.height = 256
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = radial
	light.position = at
	light.texture_scale = 1.05 * 1.28
	light.energy = light_energy
	light.color = Color(1.0, 0.78, 0.38, 1.0)
	root.add_child(light)

func _label(at: Vector2, value: String, font_size: int) -> void:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
