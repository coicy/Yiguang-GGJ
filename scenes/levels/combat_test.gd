extends Node2D
## A manually placed combat practice lane; owns only wiring and test lifecycle.

@export_range(100.0, 800.0, 10.0) var activation_distance: float = 480.0

@onready var player: Player = %Player
@onready var enemies: Node2D = %Enemies
@onready var projectiles: Node2D = %Projectiles
@onready var hud: CombatHud = %CombatHud
@onready var feedback: CombatFeedback = %CombatFeedback
@onready var camera: Camera2D = %Camera2D
@onready var platform: TerrainPiece = %LongPlatform

var _dead: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	feedback.camera = camera
	feedback.sounds = %LevelSounds
	player.combat.feedback_requested.connect(feedback.cue)
	player.died.connect(_on_player_died)
	hud.bind_player(player)
	hud.resume_requested.connect(_resume)
	hud.retry_requested.connect(_restart)
	hud.restart_requested.connect(_restart)
	for enemy: CombatEnemy in enemies.get_children():
		enemy.target = player
		enemy.bounds = Rect2(platform.global_position - Vector2(0.0, 600.0), Vector2(platform.piece_size.x, 600.0))
		enemy.feedback_requested.connect(feedback.cue)
		enemy.projectile_requested.connect(_spawn_projectile)
	_update_hud()


func _process(delta: float) -> void:
	if get_tree().paused or _dead:
		return
	_elapsed += delta
	_update_hud()


func _physics_process(_delta: float) -> void:
	if get_tree().paused or _dead:
		return
	for enemy: CombatEnemy in enemies.get_children():
		if not enemy.awake and absf(enemy.global_position.x - player.global_position.x) <= activation_distance:
			enemy.awake = true
			if enemy.definition.kind == EnemyDefinition.Kind.WARDEN:
				hud.set_boss(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"restart"):
		_restart()
	elif event.is_action_pressed(&"pause") and not _dead:
		if get_tree().paused:
			_resume()
		else:
			feedback.clear()
			get_tree().paused = true
			hud.show_pause()
			hud.restart_button.text = "重置测试场景"


func _spawn_projectile(enemy: CombatEnemy, point: Vector2, direction: Vector2, wave: bool) -> void:
	if _dead:
		return
	var projectile := SporeProjectile.new()
	projectile.position = projectiles.to_local(point)
	projectile.direction = direction
	projectile.shooter = weakref(enemy)
	projectile.shockwave = wave
	projectile.speed = 210.0 if wave else 155.0
	projectile.feedback_requested.connect(feedback.cue)
	projectiles.add_child(projectile)


func _update_hud() -> void:
	hud.set_progress("战斗测试 · 长平台", "向右接近怪物开始战斗  ·  R 重置  ·  Esc 暂停", _elapsed, 0)


func _on_player_died() -> void:
	_dead = true
	feedback.clear()
	hud.show_death()
	hud.overlay_title.text = "测试结束"
	hud.overlay_detail.text = "重新测试将恢复生命，并重置全部怪物。也可以按 R。"
	hud.primary_button.text = "重新测试"
	hud.restart_button.hide()
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	hud.hide_overlay()


func _restart() -> void:
	get_tree().paused = false
	feedback.clear()
	get_tree().reload_current_scene()
