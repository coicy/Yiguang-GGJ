class_name EnemyVisual
extends Node2D
## Cutout rig. Each part rotates around its painted joint, not the atlas cell center.
var actor: CombatEnemy
var flash_left: float = 0.0
var _parts: Array[Sprite2D] = []
var _base_positions: Array[Vector2] = []
var _base_scales: Array[Vector2] = []
var _rig: Node2D
var _time: float = 0.0

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	if _rig != null:
		_rig.queue_free()
	_parts.clear()
	_base_positions.clear()
	_base_scales.clear()
	_rig = Node2D.new()
	add_child(_rig)
	if actor.definition.atlas == null:
		return
	var size := actor.definition.body_size
	match actor.definition.kind:
		EnemyDefinition.Kind.BEETLE:
			_part(2, Vector2(-13, -14), 16, Vector2(0.38, 0.08))
			_part(2, Vector2(-3, -13), 15, Vector2(0.38, 0.08))
			_part(2, Vector2(8, -13), 15, Vector2(0.38, 0.08))
			_part(0, Vector2(-5, -17), 35, Vector2(0.5, 0.57))
			_part(1, Vector2(11, -20), 22, Vector2(0.19, 0.48))
			_part(3, Vector2(-7, -23), 29, Vector2(0.53, 0.53))
		EnemyDefinition.Kind.SPORE:
			_part(2, Vector2(0, 0), 27, Vector2(0.5, 0.94))
			_part(2, Vector2.ZERO, 1, Vector2.ZERO)
			_part(2, Vector2.ZERO, 1, Vector2.ZERO)
			_parts[1].visible = false
			_parts[2].visible = false
			_part(0, Vector2(0, -11), 34, Vector2(0.5, 0.97))
			_part(1, Vector2(4, -31), 23, Vector2(0.1, 0.54))
			_part(3, Vector2(-8, -40), 22, Vector2(0.18, 0.09))
		_:
			var factor := size.y / 50.0
			var is_warden := actor.definition.kind == EnemyDefinition.Kind.WARDEN
			_part(2, Vector2(-7, -25) * factor, 27 * factor, Vector2(0.38, 0.06))
			_part(2, Vector2(6, -25) * factor, 27 * factor, Vector2(0.38, 0.06))
			_part(2, Vector2.ZERO, 1, Vector2.ZERO)
			_parts[2].visible = false
			_part(0, Vector2(0, -21) * factor, (38 if is_warden else 34) * factor, Vector2(0.5, 0.96))
			_part(1, Vector2(11, -42) * factor, (42 if is_warden else 39) * factor, Vector2(0.23, 0.32) if is_warden else Vector2(0.1, 0.32))
			_part(3, Vector2(-10 if is_warden else 9, -38) * factor, 31 * factor, Vector2(0.38, 0.36))
			_parts[4].z_index = 1
			_parts[5].z_index = 2
	for part: Sprite2D in _parts:
		_base_positions.append(part.position)
		_base_scales.append(part.scale)
		part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_parts[0].modulate = Color(0.72, 0.78, 0.73)

func _part(tile: int, joint: Vector2, height: float, pivot: Vector2) -> void:
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	var cell := actor.definition.atlas.get_size() * 0.5
	texture.atlas = actor.definition.atlas
	# Generated atlas divider seams are excluded from every draw.
	texture.region = Rect2(Vector2(tile % 2, tile / 2) * cell + Vector2(7, 7), cell - Vector2(14, 14))
	texture.filter_clip = true
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -texture.region.size * pivot
	sprite.position = joint
	sprite.scale = Vector2.ONE * height / texture.region.size.y
	_rig.add_child(sprite)
	_parts.append(sprite)

func _process(delta: float) -> void:
	if actor == null:
		return
	_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	modulate = Color(1.7, 1.7, 1.7) if flash_left > 0.0 else Color.WHITE
	if _rig == null:
		return
	_rig.scale.x = actor.facing
	var moving := absf(actor.velocity.x) > 5.0
	var windup := actor.state == &"windup"
	var strike := actor.state == &"strike"
	var dead := actor.state == &"dead"
	var kind := actor.definition.kind
	var windup_seconds := actor.definition.slam_windup if actor.attack_kind == &"slam" else actor.definition.windup
	if actor.attack_kind == &"charge" and kind == EnemyDefinition.Kind.WARDEN:
		windup_seconds = actor.definition.charge_windup
	var anticipation := smoothstep(0, 1, clampf(actor.elapsed / windup_seconds, 0, 1))
	var settle := 1.0 - smoothstep(0, 0.32, actor.elapsed)
	for i in range(_parts.size()):
		var part := _parts[i]
		part.position = _base_positions[i]
		part.scale = _base_scales[i]
		part.rotation = 0.0
		part.modulate.a = 1.0
		if i < 3 and moving and kind != EnemyDefinition.Kind.SPORE:
			var step := sin(_time * (25.0 if strike else 15.0) + i * PI)
			part.rotation = step * (0.16 if kind == EnemyDefinition.Kind.BEETLE else 0.10)
			part.position.y -= maxf(0.0, step) * 1.6
		if i >= 3:
			part.position.y += sin(_time * 3.0) * 0.5
		if kind == EnemyDefinition.Kind.SPORE:
			if i == 3:
				var swell := anticipation * 0.14 if windup else -0.12 * settle if strike else sin(_time * 2.8) * 0.025
				part.scale *= Vector2(1.0 + swell, 1.0 - swell * 0.3)
			if i == 4:
				part.position.x += -anticipation * 2.0 if windup else settle * 5.0 if strike else 0.0
				part.rotation = -0.15 * anticipation if windup else 0.0
		elif windup and i >= 3:
			part.position.x -= anticipation * 2.0
			part.rotation = -anticipation * (0.75 if i == 4 else 0.09)
			if actor.attack_kind == &"slam" and i == 4:
				part.rotation = -anticipation * 1.8
				part.position.y -= anticipation * 11.0
		elif strike and i >= 3:
			if actor.attack_kind == &"charge":
				part.rotation = 0.18 if i == 4 else 0.08
				part.position.x += 3.0
			elif i == 4:
				var swing_time := actor.elapsed
				if kind == EnemyDefinition.Kind.WARDEN and actor.second_phase and swing_time >= actor.definition.second_strike_start:
					swing_time -= actor.definition.second_strike_start
				var swing := smoothstep(0, 0.12, swing_time)
				part.rotation = lerpf(-0.65, 0.85, swing)
				part.position.x += swing * 5.0
				if actor.attack_kind == &"slam":
					part.rotation = lerpf(-1.5, 0.55, swing)
					part.position.y += swing * 16.0
		elif actor.state == &"recover" and i >= 3:
			part.rotation = settle * (0.22 if i == 4 else 0.05)
		if actor.state == &"stun" and i >= 3:
			part.rotation = -0.12 * settle
			part.position.x += sin(_time * 45.0) * 0.65 * settle
		if dead:
			part.position += Vector2((i - 2.5) * actor.elapsed * 20.0, actor.elapsed * actor.elapsed * 60.0)
			part.rotation = (i - 2.5) * actor.elapsed
			part.modulate.a = maxf(0.0, 1.0 - actor.elapsed / 0.65)
	queue_redraw()
func _draw() -> void:
	if actor == null or actor.state == &"dead":
		return
	var size := actor.definition.body_size
	if _parts.is_empty():
		draw_circle(Vector2(0,-size.y * 0.5), size.y * 0.48, actor.definition.tint)
		draw_arc(Vector2(0,-size.y * 0.5), size.y * 0.48, 0, TAU, 24, Color("#172d26"), 2.0, true)
	if actor.health.current < actor.health.maximum and actor.definition.kind != EnemyDefinition.Kind.WARDEN:
		draw_rect(Rect2(-18,-size.y-15,36,3),Color("#233a36"))
		draw_rect(Rect2(-18,-size.y-15,36.0*actor.health.current/actor.health.maximum,3),Color("#ddd99b"))
	if actor.state == &"windup":
		var danger := actor.attack_kind == &"slam"
		var tint := Color("#ff9273") if danger else Color("#ffe9aa")
		var point := Vector2(0, -size.y-24)
		draw_circle(point, 6.5, Color("#243830"))
		if danger:
			draw_line(point-Vector2(3,3),point+Vector2(3,3),tint,2.0)
			draw_line(point+Vector2(-3,3),point+Vector2(3,-3),tint,2.0)
		else:
			draw_line(point+Vector2(0,-4),point+Vector2(0,1),tint,2.0)
			draw_circle(point+Vector2(0,4),1.0,tint)
		var progress := clampf(actor.elapsed / (actor.definition.slam_windup if danger else actor.definition.charge_windup if actor.attack_kind == &"charge" and actor.definition.kind == EnemyDefinition.Kind.WARDEN else actor.definition.windup),0,1)
		draw_arc(point,9,-PI/2,-PI/2+TAU*progress,24,tint,1.4,true)
	if actor.state == &"strike" and actor.attack_kind == &"slash" and actor.definition.kind in [EnemyDefinition.Kind.PRUNER, EnemyDefinition.Kind.WARDEN]:
		var elapsed := actor.elapsed
		if actor.second_phase and elapsed >= actor.definition.second_strike_start:
			elapsed -= actor.definition.second_strike_start
		if elapsed > 0.19:
			return
		var radius := 89.0 if actor.definition.kind == EnemyDefinition.Kind.WARDEN else 59.0
		var arc_height := 24.0 if actor.definition.kind == EnemyDefinition.Kind.WARDEN else 17.0
		var points := PackedVector2Array()
		for i in range(15):
			var angle := lerpf(-1.0, 1.0, i / 14.0)
			points.append(Vector2(cos(angle) * actor.facing * radius, sin(angle) * arc_height) + Vector2(0, -24))
		draw_polyline(points, Color(1.0, 0.89, 0.64, (1.0 - elapsed / actor.definition.strike_duration) * 0.65), 2.0, true)


func _draw_status_bars(top: float) -> void:
	if not actor.awake and actor.health.current == actor.health.maximum:
		return
	draw_rect(Rect2(-18, top, 36, 3), Color("#233a36"))
	draw_rect(Rect2(-18, top, 36.0 * actor.health.current / actor.health.maximum, 3), Color("#ddd99b"))
	if actor.poise.maximum <= 0.0:
		return
	var bar := Rect2(-18, top + 6, 36, 3)
	draw_rect(bar, Color("#233a36"))
	draw_rect(Rect2(bar.position, Vector2(36.0 * actor.poise.current / actor.poise.maximum, 3)), Color("#83bcb4"))
	if actor.poise.broken:
		draw_rect(bar.grow(1), Color("#ffad73"), false, 1.0)
