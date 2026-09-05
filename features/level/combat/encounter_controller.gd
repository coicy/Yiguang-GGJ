class_name EncounterController
extends Node2D
signal encounter_started(encounter: EncounterController)
signal encounter_completed(encounter: EncounterController)
signal enemy_spawned(enemy: CombatEnemy)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
@export var encounter_id: StringName = &"beetle_intro"
@export var display_name: String = "苔藓步道"
@export var objective: String = "击败污染甲虫"
@export var arena_size := Vector2(560.0, 260.0)
@export var camera_zoom: float = 2.1
@export var waves: Array[PackedStringArray] = []
const ENEMIES := {
	"beetle": preload("res://features/enemies/beetle.tscn"),
	"spore": preload("res://features/enemies/spore.tscn"),
	"pruner": preload("res://features/enemies/pruner.tscn"),
	"warden": preload("res://features/enemies/warden.tscn"),
}
var player: Player
var active: bool = false
var completed: bool = false
var wave_index: int = -1
var enemies: Array[CombatEnemy] = []
var projectiles: Array[SporeProjectile] = []
var _gates: Array[StaticBody2D] = []
var _wave_delay: float = -1.0
func _ready() -> void:
	for side in [0.0, arena_size.x]:
		var gate := StaticBody2D.new()
		gate.collision_layer = 1
		gate.collision_mask = 0
		gate.position = Vector2(side, -arena_size.y * 0.5)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12.0, arena_size.y)
		collision.shape = shape
		gate.add_child(collision)
		add_child(gate)
		_gates.append(gate)
	_set_gates(false, true)
func can_trigger() -> bool:
	if player == null or active or completed or player.combat.health.current <= 0:
		return false
	var point := to_local(player.global_position)
	return point.x >= 52.0 and point.x < arena_size.x - 20.0 and point.y > -110.0 and point.y < 20.0 and player.current_form_id() != &"sprout"
func begin() -> void:
	if active or completed:
		return
	active = true
	_set_gates(true, true)
	wave_index = -1
	encounter_started.emit(self)
	_next_wave()
func _physics_process(delta: float) -> void:
	if not active:
		return
	if _wave_delay >= 0.0:
		_wave_delay -= delta
		if _wave_delay < 0.0:
			_next_wave()
func _next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		active = false
		completed = true
		_clear_projectiles()
		_set_gates(false, false)
		encounter_completed.emit(self)
		return
	var composition: PackedStringArray = waves[wave_index]
	for index in range(composition.size()):
		var enemy := (ENEMIES[String(composition[index])] as PackedScene).instantiate() as CombatEnemy
		enemy.position = Vector2(arena_size.x * (0.48 + index * 0.17), 0.0)
		enemy.target = player
		enemy.bounds = Rect2(global_position + Vector2(0.0, -arena_size.y), arena_size)
		enemy.awake = true
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.feedback_requested.connect(func(kind: StringName, point: Vector2, strength: float) -> void: feedback_requested.emit(kind, point, strength))
		enemy.projectile_requested.connect(_spawn_projectile)
		add_child(enemy)
		enemies.append(enemy)
		enemy_spawned.emit(enemy)
func _on_enemy_defeated(enemy: CombatEnemy) -> void:
	enemies.erase(enemy)
	if enemies.is_empty() and active:
		_wave_delay = 0.8
func _spawn_projectile(enemy: CombatEnemy, point: Vector2, direction: Vector2, wave: bool) -> void:
	if not active:
		return
	var projectile := SporeProjectile.new()
	projectile.position = to_local(point)
	projectile.direction = direction
	projectile.shooter = weakref(enemy)
	projectile.shockwave = wave
	projectile.speed = 210.0 if wave else 155.0
	projectile.feedback_requested.connect(func(kind: StringName, hit: Vector2, strength: float) -> void: feedback_requested.emit(kind, hit, strength))
	add_child(projectile)
	projectiles.append(projectile)
	projectile.tree_exiting.connect(func() -> void: projectiles.erase(projectile))
func reset_encounter() -> void:
	active = false
	_wave_delay = -1.0
	wave_index = -1
	for enemy: CombatEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	# Also remove defeated bodies whose death animation has not finished.
	for node: Node in get_children():
		if node is CombatEnemy and not node.is_queued_for_deletion():
			node.queue_free()
	_clear_projectiles()
	_set_gates(false, not completed)
func _clear_projectiles() -> void:
	for projectile: SporeProjectile in projectiles.duplicate():
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
func _set_gates(left_closed: bool, right_closed: bool) -> void:
	if _gates.size() < 2:
		return
	(_gates[0].get_child(0) as CollisionShape2D).set_deferred("disabled", not left_closed)
	(_gates[1].get_child(0) as CollisionShape2D).set_deferred("disabled", not right_closed)
	queue_redraw()
func _draw() -> void:
	for side in [0.0, arena_size.x]:
		var closed: bool = not completed and (side > 0.0 or active)
		var tint := Color("#d7ba71") if closed else Color("#6f9c75")
		draw_line(Vector2(side,-arena_size.y),Vector2(side,0),Color("#294c41"),5.0)
		draw_circle(Vector2(side,-arena_size.y+12),4.0,tint)
		if closed:
			for offset in range(0,int(arena_size.y),24):
				draw_line(Vector2(side-5,-offset),Vector2(side+5,-offset-16),Color(tint,0.65),2.0,true)
func camera_center() -> Vector2:
	return global_position + Vector2(arena_size.x * 0.5, -80.0)
func checkpoint_position() -> Vector2:
	return global_position + Vector2(-80.0 if encounter_id == &"warden" else 72.0, -2.0)
