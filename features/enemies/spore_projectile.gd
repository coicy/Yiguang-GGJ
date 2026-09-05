class_name SporeProjectile
extends CharacterBody2D
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
var direction := Vector2.RIGHT
var reflected: bool = false
var shockwave: bool = false
var speed: float = 155.0
var life: float = 4.0
var shooter: WeakRef
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	node.shape = shape
	add_child(node)
func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var motion := direction * speed * delta
	var steps := maxi(1, ceili(motion.length() / 7.0))
	for step in range(steps):
		var collision := move_and_collide(motion / steps)
		if collision != null:
			if not shockwave: feedback_requested.emit(&"spore_burst", global_position, 0.0)
			queue_free()
			return
		var mask := CombatQuery.ENEMY_HURT if reflected else CombatQuery.PLAYER_HURT
		for hurt: Hurtbox in CombatQuery.targets(self, global_position, Vector2(14.0, 16.0), mask):
			if not CombatQuery.clear_path(self, global_position, hurt.world_center()):
				continue
			var request := DamageRequest.new()
			request.source = self
			request.origin = global_position - direction * 8.0
			request.amount = 2 if reflected else 1
			request.poise_damage = 25.0 if reflected else 10.0
			request.parryable = not shockwave
			request.knockback = Vector2(signf(direction.x) * 150.0, -70.0)
			var result := hurt.deliver(request)
			if result == DamageRequest.Result.PARRIED:
				return
			if result != DamageRequest.Result.IGNORED:
				if not shockwave: feedback_requested.emit(&"spore_burst", global_position, 0.0)
				if reflected:
					feedback_requested.emit(&"hit", global_position, 1.0)
				queue_free()
				return
	queue_redraw()
func receive_parry(_actor: Node2D) -> void:
	feedback_requested.emit(&"spore_reflect", global_position, 0.0)
	reflected = true
	var source: Object = shooter.get_ref() if shooter != null else null
	direction = -direction
	if source is Node2D:
		direction = ((source as Node2D).global_position + Vector2(0.0, -22.0) - global_position).normalized()
	speed = 260.0
	life = 3.0
	queue_redraw()
func _draw() -> void:
	var tint := Color("#f3edaa") if reflected else Color("#c38fda")
	if shockwave:
		tint = Color("#ef9970")
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 7), Vector2(-5, -10), Vector2(0, 1), Vector2(5, -8), Vector2(12, 7)]), tint)
	else:
		# A fixed tail marks the straight flight axis; it never orbits the projectile.
		draw_set_transform(Vector2.ZERO, direction.angle())
		draw_colored_polygon(PackedVector2Array([Vector2(-24, 0), Vector2(-5, -3.5), Vector2(-5, 3.5)]), Color(tint, 0.28))
		draw_line(Vector2(-17, 0), Vector2(-5, 0), Color(tint, 0.75), 2.0, true)
		draw_circle(Vector2.ZERO, 6.0, Color("#412e57"))
		draw_circle(Vector2.ZERO, 4.5, tint)
		draw_circle(Vector2(2, -1), 1.5, Color("#f9e2ef"))
		draw_set_transform(Vector2.ZERO)
