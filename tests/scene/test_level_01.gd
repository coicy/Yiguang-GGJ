extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")
const LAYER_NAMES: Array[String] = [
	"Background",
	"Geometry",
	"Areas",
	"Checkpoints",
	"Actors",
	"Foreground",
	"Effects",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node2D
	root.add_child(level)
	await physics_frame

	for layer_name: String in LAYER_NAMES:
		assert(level.get_node_or_null(layer_name) != null, "Missing level layer: %s" % layer_name)
	var canvas_modulate := level.get_node("CanvasModulate") as CanvasModulate
	assert(canvas_modulate != null)
	assert(canvas_modulate.color.is_equal_approx(Color(0.2, 0.24, 0.28, 1.0)))
	assert(level.get_node_or_null("Geometry/Terrain") != null)
	assert(level.get_node_or_null("Geometry/Mechanisms") != null)
	var flower_decorations := level.get_node("FlowerDecorations") as Node2D
	assert(flower_decorations != null)
	assert(flower_decorations.get_child_count() == 4, "The level should have several glowing flower decorations.")
	for child: Node in flower_decorations.get_children():
		var flower_light := child.get_node("FlowerLight") as PointLight2D
		assert(flower_light != null)
		assert(flower_light.shadow_enabled)

	var floor_piece := level.get_node("Geometry/Terrain/StartFloor") as TerrainPiece
	assert(floor_piece != null, "The baseline level needs one terrain floor piece.")
	assert(floor_piece.piece_size.is_equal_approx(Vector2(1344.0, 40.0)))
	assert(is_equal_approx(floor_piece.art_scale_multiplier, 0.4))
	var terrain_visual := floor_piece.get_node("TerrainVisual") as NinePatchRect
	assert(terrain_visual.scale.is_equal_approx(Vector2(0.4, 0.4)))
	assert(terrain_visual.size.is_equal_approx(Vector2(3360.0, 100.0)))
	assert(floor_piece.get_node_or_null("CollisionShape2D") == null)
	var collision := floor_piece.get_node("CollisionPolygon2D") as CollisionPolygon2D
	assert(collision.polygon == PackedVector2Array([Vector2(0.0, 6.5), Vector2(1344.0, 6.5), Vector2(1344.0, 40.0), Vector2(0.0, 40.0)]))
	assert(not collision.disabled)

	var bounds := level.get_node("CameraBounds") as CameraBounds
	assert(bounds.get_world_rect().is_equal_approx(Rect2(-414.0, 190.0, 1500.0, 500.0)))
	var spawn_icon := level.get_node("SpawnPoint/BrokenTankIcon") as Sprite2D
	assert(spawn_icon != null, "The current spawn point must display the broken tank icon.")
	assert(spawn_icon.texture != null)
	assert(spawn_icon.texture.resource_path == "res://assets/runtime/scenery/_0014_培养罐.png")
	assert(spawn_icon.position.is_equal_approx(Vector2(-1.0, -15.0)))
	assert(spawn_icon.scale.is_equal_approx(Vector2(0.07, 0.07)))
	assert(spawn_icon.z_index == -1)

	var grow_drug := level.get_node("Areas/GrowDrug") as NutritionTank
	var grow_sprite := grow_drug.get_node("TankSprite") as Sprite2D
	assert(grow_sprite.texture.resource_path == "res://assets/runtime/scenery/grow_tank.png")
	var grow_collision := grow_drug.get_node("CollisionShape2D") as CollisionShape2D
	assert((grow_collision.shape as RectangleShape2D).size.is_equal_approx(Vector2(48.0, 48.0)))
	var ungrow_drug := level.get_node("Areas/UnGrowDrug") as ToxinResource
	var ungrow_sprite := ungrow_drug.get_node("TankSprite") as Sprite2D
	assert(ungrow_sprite.texture.resource_path == "res://assets/runtime/scenery/ungrow_tank.png")
	assert(ungrow_sprite.modulate.is_equal_approx(Color.WHITE))
	assert(ungrow_sprite.visible and ungrow_sprite.z_index == grow_sprite.z_index)
	assert(ungrow_sprite.position.is_equal_approx(grow_sprite.position))
	assert(ungrow_sprite.scale.is_equal_approx(grow_sprite.scale))
	assert(ungrow_sprite.texture.get_size() == Vector2(243.0, 809.0))
	var ungrow_collision := ungrow_drug.get_node("CollisionShape2D") as CollisionShape2D
	assert((ungrow_collision.shape as RectangleShape2D).size.is_equal_approx(Vector2(48.0, 48.0)))
	assert(ungrow_drug.collision_layer == grow_drug.collision_layer)
	assert(ungrow_drug.collision_mask == grow_drug.collision_mask)

	var player := level.get_node("Actors/Player") as Player
	var flower_light := player.get_node("Visuals/FlowerLight") as PointLight2D
	assert(flower_light != null, "The player flower needs a local 2D light in the dark level.")
	assert(flower_light.position.is_equal_approx(Vector2(0.0, -34.0)))
	assert(flower_light.energy > 1.0)
	assert(flower_light.shadow_enabled)
	var camera := player.get_node("Camera2D") as Camera2D
	assert(camera.limit_smoothed)
	assert(camera.limit_left == -414 and camera.limit_top == 190)
	assert(camera.limit_right == 1086 and camera.limit_bottom == 690)
	var phantom := level.get_node("PhantomCamera2D") as PhantomCamera2D
	assert(phantom != null)
	assert(phantom.follow_mode == PhantomCamera2D.FollowMode.FRAMED)
	assert(phantom.zoom.is_equal_approx(Vector2(3.0, 3.0)))
	assert(is_equal_approx(phantom.dead_zone_width, 0.6))
	assert(is_equal_approx(phantom.dead_zone_height, 0.52))

	level.queue_free()
	quit()
