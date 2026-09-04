class_name YiguangWhitebox
extends Node2D
## Playable whitebox generated from Yiguang.json Level_0 (45 x 30, 16 px cells).

signal checkpoint_changed(checkpoint_id: StringName)
signal completion_changed(completed: bool, seconds: float)

const CELL_SIZE := 32
const GRID_WIDTH := 45
const GRID_HEIGHT := 30
const TILE_SOURCE_ID := 0
const DAMAGE_VALUE := 2
const HARD_FLOOR_VALUE := 3
const GRID_ROWS: PackedStringArray = [
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".............................................",
	".....................................11111111",
	".....................................1.......",
	"...............111..1111111111.......1.......",
	"................1....1...............1.......",
	".....................1...............1.......",
	".....................1...............1.......",
	".....1111111..................22...111.......",
	"..111111...22.................22.....1.......",
	"......11...22.................22.....1.......",
	"...........22.................22.....1.......",
	"1111111111111111111111111111111133...1.......",
	"....................1................1.......",
	"....................1................1.......",
	"....................1................1.......",
	"....................1................1.......",
	"....................1................1.......",
	"....................1.........1221...1.......",
	"....................1.........3333...1.......",
	"....................1.....11...22....1.11....",
	"..........................11...........11....",
	"111111111111111111111111111111111133333111111",
]

@export var level_id: StringName = &"yiguang_whitebox"
@export var grid_hazard_scene: PackedScene

@onready var player: Player = %Player
@onready var player_anchor: Marker2D = %PlayerAnchor
@onready var terrain: TileMapLayer = %Terrain
@onready var hazards: Node2D = %Hazards
@onready var start_checkpoint: Checkpoint = %StartCheckpoint
@onready var lower_checkpoint: Checkpoint = %LowerCheckpoint
@onready var upper_checkpoint: Checkpoint = %UpperCheckpoint
@onready var lower_switch: AbilitySwitch = %LowerSwitch
@onready var middle_switch: AbilitySwitch = %MiddleSwitch
@onready var upper_switch: AbilitySwitch = %UpperSwitch
@onready var linked_lift: WhiteboxMovingCube = %LinkedLift
@onready var middle_platform: WhiteboxMovingCube = %MiddlePlatform
@onready var bridge_platform: WhiteboxMovingCube = %BridgePlatform
@onready var top_lift_a: WhiteboxMovingCube = %TopLiftA
@onready var top_lift_b: WhiteboxMovingCube = %TopLiftB
@onready var exit_goal: ExitGoal = %ExitGoal
@onready var camera: Camera2D = %Camera2D
@onready var hud: GameHud = %GameHud
@onready var completion_overlay: CompletionOverlay = %CompletionOverlay

var _checkpoint_id: StringName = &"start"
var _checkpoint_snapshot: Dictionary = {}
var _initial_snapshot: Dictionary = {}
var _elapsed: float = 0.0
var _is_completed: bool = false
func _ready() -> void:
	_build_terrain()
	_create_grid_damage_hazards()
	_connect_authored_hazards()
	_connect_checkpoints()
	_connect_toxin_zones()

	linked_lift.bind_switch(lower_switch)
	middle_platform.bind_switch(middle_switch)
	bridge_platform.bind_switch(middle_switch)
	top_lift_a.bind_switch(upper_switch)
	top_lift_b.bind_switch(upper_switch)
	exit_goal.set_required_switches([lower_switch, middle_switch, upper_switch])
	exit_goal.player_completed.connect(_on_exit_player_completed)
	exit_goal.locked_entered.connect(_on_exit_locked)

	_initial_snapshot = _make_snapshot(&"start", player.global_position)
	_checkpoint_snapshot = _initial_snapshot.duplicate(true)
	player_anchor.global_position = player.global_position
	hud.bind_player(player, self)
	queue_redraw()


func _process(delta: float) -> void:
	if not _is_completed:
		_elapsed += delta
	camera.global_position = player.global_position + Vector2(180.0, -140.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart_level()


func get_player() -> Player:
	return player


func get_checkpoint_position() -> Vector2:
	return player_anchor.global_position


func elapsed_time() -> float:
	return _elapsed


func is_completed() -> bool:
	return _is_completed


func respawn_player() -> void:
	_restore_snapshot(_checkpoint_snapshot)


func restart_level() -> void:
	_is_completed = false
	_elapsed = 0.0
	_checkpoint_id = &"start"
	start_checkpoint.reset_activation()
	lower_checkpoint.reset_activation()
	upper_checkpoint.reset_activation()
	exit_goal.reset_completion()
	_checkpoint_snapshot = _initial_snapshot.duplicate(true)
	_restore_snapshot(_checkpoint_snapshot)
	completion_overlay.hide_completion()
	completion_changed.emit(false, 0.0)
	checkpoint_changed.emit(_checkpoint_id)


func _build_terrain() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 2)

	var image := Image.create_empty(CELL_SIZE * 3, CELL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Color("#11ff00"))
	image.fill_rect(Rect2i(CELL_SIZE, 0, CELL_SIZE, CELL_SIZE), Color("#be4a2f"))
	image.fill_rect(Rect2i(CELL_SIZE * 2, 0, CELL_SIZE, CELL_SIZE), Color("#a5a5a5"))

	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_source(atlas, TILE_SOURCE_ID)
	for tile_index: int in 3:
		var atlas_coordinates := Vector2i(tile_index, 0)
		atlas.create_tile(atlas_coordinates)
		var tile_data := atlas.get_tile_data(atlas_coordinates, 0)
		if tile_index == DAMAGE_VALUE - 1:
			continue
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(
			0,
			0,
			PackedVector2Array([
				Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5),
				Vector2(CELL_SIZE * 0.5, -CELL_SIZE * 0.5),
				Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5),
				Vector2(-CELL_SIZE * 0.5, CELL_SIZE * 0.5),
			])
		)
	terrain.tile_set = tile_set

	for y: int in GRID_HEIGHT:
		for x: int in GRID_WIDTH:
			var value := _grid_value(x, y)
			if value > 0 and not _is_moving_ground_cell(x, y):
				terrain.set_cell(Vector2i(x, y), TILE_SOURCE_ID, Vector2i(value - 1, 0))


func _create_grid_damage_hazards() -> void:
	if grid_hazard_scene == null:
		return
	for y: int in GRID_HEIGHT:
		for x: int in GRID_WIDTH:
			if _grid_value(x, y) != DAMAGE_VALUE:
				continue
			var hazard := grid_hazard_scene.instantiate() as Hazard
			if hazard == null:
				continue
			hazard.position = Vector2((x + 0.5) * CELL_SIZE, (y + 0.5) * CELL_SIZE)
			hazard.visual_size = Vector2(CELL_SIZE, CELL_SIZE)
			hazard.visual_label = ""
			hazard.show_whitebox_visual = true
			hazard.add_to_group(&"yiguang_hazard")
			var shape_node := hazard.get_node("CollisionShape2D") as CollisionShape2D
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0)
			shape_node.shape = rectangle
			hazard.actor_killed.connect(_on_actor_killed)
			hazards.add_child(hazard)


func _connect_authored_hazards() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"yiguang_hazard"):
		if not is_ancestor_of(node) or not node is Hazard:
			continue
		var hazard := node as Hazard
		if not hazard.actor_killed.is_connected(_on_actor_killed):
			hazard.actor_killed.connect(_on_actor_killed)


func _connect_checkpoints() -> void:
	start_checkpoint.actor_checkpoint_reached.connect(_on_checkpoint_reached.bind(&"start"))
	lower_checkpoint.actor_checkpoint_reached.connect(_on_checkpoint_reached.bind(&"lower"))
	upper_checkpoint.actor_checkpoint_reached.connect(_on_checkpoint_reached.bind(&"upper"))


func _connect_toxin_zones() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"yiguang_toxin"):
		if not is_ancestor_of(node) or not node is ToxinZone:
			continue
		var toxin := node as ToxinZone
		toxin.actor_entered.connect(_on_toxin_entered.bind(toxin))
		toxin.actor_exited.connect(_on_toxin_exited.bind(toxin))


func _make_snapshot(id: StringName, spawn_position: Vector2) -> Dictionary:
	var player_state := player.capture_state()
	player_state["position"] = spawn_position
	player_state["velocity"] = Vector2.ZERO
	return {
		"id": id,
		"position": spawn_position,
		"player": player_state,
		"switches": [
			lower_switch.is_active(),
			middle_switch.is_active(),
			upper_switch.is_active(),
		],
	}


func _restore_snapshot(snapshot: Dictionary) -> void:
	var switches: Array = snapshot.get("switches", [false, false, false])
	lower_switch.restore_active(bool(switches[0]))
	middle_switch.restore_active(bool(switches[1]))
	upper_switch.restore_active(bool(switches[2]))
	linked_lift.set_active(lower_switch.is_active(), true)
	middle_platform.set_active(middle_switch.is_active(), true)
	bridge_platform.set_active(middle_switch.is_active(), true)
	top_lift_a.set_active(upper_switch.is_active(), true)
	top_lift_b.set_active(upper_switch.is_active(), true)
	player_anchor.global_position = snapshot.get("position", player_anchor.global_position)
	player.restore_state(snapshot.get("player", {}))


func _grid_value(x: int, y: int) -> int:
	return GRID_ROWS[y].substr(x, 1).to_int()


func _is_moving_ground_cell(x: int, y: int) -> bool:
	# LDtk stores moving entities over their initial IntGrid footprint. Excluding the
	# two solid footprints prevents an invisible static wall after the entity moves.
	return (y == 15 and x >= 35 and x <= 36) or (x == 37 and y >= 11 and y <= 19)


func _on_checkpoint_reached(actor: Node2D, spawn_position: Vector2, id: StringName) -> void:
	if actor != player:
		return
	_checkpoint_id = id
	player_anchor.global_position = spawn_position
	_checkpoint_snapshot = _make_snapshot(id, spawn_position)
	checkpoint_changed.emit(id)


func _on_actor_killed(actor: Node2D) -> void:
	if actor == player:
		respawn_player()


func _on_toxin_entered(actor: Node2D, toxin: ToxinZone) -> void:
	if actor == player:
		player.enter_toxin(toxin)


func _on_toxin_exited(actor: Node2D, toxin: ToxinZone) -> void:
	if actor == player:
		player.exit_toxin(toxin)


func _on_exit_player_completed(completing_player: Player) -> void:
	if completing_player != player or _is_completed:
		return
	_is_completed = true
	player.cancel_actions()
	completion_overlay.show_completion(_elapsed)
	completion_changed.emit(true, _elapsed)
	var signal_bus := get_node_or_null("/root/GlobalSignalBus")
	if signal_bus != null and signal_bus.has_signal(&"level_completed"):
		signal_bus.emit_signal(&"level_completed", level_id)


func _on_exit_locked(_locked_player: Player) -> void:
	hud.show_message("出口锁定：需要激活关卡内三个按钮")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)), Color("#3f424e"))
	for y: int in GRID_HEIGHT:
		for x: int in GRID_WIDTH:
			var value := _grid_value(x, y)
			if value == 0:
				continue
			var color := Color("#11ff00")
			if value == DAMAGE_VALUE:
				color = Color("#be4a2f")
			elif value == HARD_FLOOR_VALUE:
				color = Color("#a5a5a5")
			draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), color)
	for x: int in GRID_WIDTH + 1:
		draw_line(Vector2(x * CELL_SIZE, 0), Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE), Color(1, 1, 1, 0.06), 1.0)
	for y: int in GRID_HEIGHT + 1:
		draw_line(Vector2(0, y * CELL_SIZE), Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE), Color(1, 1, 1, 0.06), 1.0)
