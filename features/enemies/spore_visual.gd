class_name SporeVisual
extends EnemyVisual
## Root crown -> flexible stalk -> pressure sac -> nozzle/leaf. Art stays attached.
var _crown: Sprite2D
var _body: Node2D
var _neck: Node2D
var _leaf: Sprite2D
var _pose: SporePose = SporePose.new()
var _from_pose: SporePose = SporePose.new()
var _last_state: StringName = &""
var _blend_elapsed: float = 1.0

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	_rig = Node2D.new()
	_rig.name = "SporeRig"
	add_child(_rig)
	_crown = _sprite(Rect2(8, 640, 672, 600), Vector2(325, 560), _rig)
	_crown.scale = Vector2.ONE * 0.040
	_body = Node2D.new()
	_body.name = "PressureSac"
	_rig.add_child(_body)
	var sac: Sprite2D = _sprite(Rect2(8, 8, 612, 680), Vector2(290, 636), _body)
	sac.scale = Vector2.ONE * 0.058
	_leaf = _sprite(Rect2(692, 700, 537, 526), Vector2(40, 46), _body)
	_leaf.position = Vector2(-10, -30)
	_leaf.scale = Vector2.ONE * 0.047
	_neck = Node2D.new()
	_neck.name = "Nozzle"
	_body.add_child(_neck)
	var mouth: Sprite2D = _sprite(Rect2(642, 42, 591, 599), Vector2(46, 296), _neck)
	mouth.scale = Vector2.ONE * 0.046
	_process(0.0)

func _sprite(region: Rect2, pivot: Vector2, host: Node2D) -> Sprite2D:
	var part := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = actor.definition.atlas
	atlas.region = region
	atlas.filter_clip = true
	part.texture = atlas
	part.centered = false
	part.offset = -pivot
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(part)
	return part

func _process(delta: float) -> void:
	if actor == null or actor.spore_behavior == null:
		return
	_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	modulate = Color(1.6, 1.5, 1.5) if flash_left > 0.0 else Color.WHITE
	if actor.state != _last_state:
		_from_pose = _pose
		_blend_elapsed = 0.0
		_last_state = actor.state
	_blend_elapsed += delta
	var next_pose: SporePose = SporePose.sample(actor, _time)
	var blend_seconds: float = 0.035 if actor.state in [&"strike", &"stun"] else 0.09
	_pose = _from_pose.blended(next_pose, smoothstep(0.0, blend_seconds, _blend_elapsed))
	if actor.attack_kind == &"spit" and actor.state in [&"windup", &"strike"]:
		_pose.aim_at(actor.to_local(actor.spore_behavior.aim_point) * Vector2(actor.facing, 1.0))
	_rig.scale = Vector2(actor.facing, 1.0)
	if actor.state == &"turn":
		_rig.scale.x *= 1.0 - sin(clampf(actor.elapsed / actor.spore_behavior.tuning.turn_duration, 0.0, 1.0) * PI) * 0.8
	_body.transform = _pose.body_transform()
	_neck.transform = _pose.neck_transform()
	_leaf.rotation = _pose.leaf
	_crown.scale = Vector2(0.040 + _pose.spread * 0.0015, 0.040 - _pose.squash * 0.008)
	_crown.position = Vector2(0, -_pose.lift)
	_rig.modulate.a = 1.0 - smoothstep(actor.definition.death_duration * 0.74, actor.definition.death_duration, actor.elapsed) if actor.state == &"dead" else 1.0
	queue_redraw()

func pose_snapshot() -> Dictionary:
	return {"body": _body.transform, "nozzle": _neck.transform, "leaf": _leaf.transform, "roots": _crown.transform, "muzzle": _pose.muzzle_local() * Vector2(actor.facing, 1.0), "muzzle_direction": _pose.muzzle_direction_local() * Vector2(actor.facing, 1.0)}

func _draw() -> void:
	if actor == null or actor.spore_behavior == null:
		return
	var alpha: float = _rig.modulate.a
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.17))
	draw_circle(Vector2.ZERO, 25.0, Color(0.03, 0.04, 0.04, 0.32 * alpha))
	draw_set_transform(Vector2.ZERO)
	# Flexible stalk closes the crown/sac joint while the mass shifts above the roots.
	var base: Vector2 = Vector2(0, -9)
	var socket: Vector2 = (Vector2(0, -10) + _pose.body) * Vector2(actor.facing, 1)
	draw_line(base, socket, Color(0.18, 0.25, 0.10, alpha), 9.0, true)
	if actor.state == &"dead":
		return
	_draw_status_bars(-68.0)
	if actor.state == &"windup":
		var point: Vector2 = Vector2(0, -79)
		var tint: Color = Color("#ffe4a1")
		var progress: float = clampf(actor.elapsed / actor.spore_behavior.windup_duration(), 0, 1)
		draw_circle(point, 6.0, Color("#243830"))
		draw_line(point + Vector2(0, -4), point + Vector2(0, 1), tint, 2.0, true)
		draw_circle(point + Vector2(0, 4), 1.0, tint)
		draw_arc(point, 9, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, tint, 1.2, true)
	if actor.state == &"strike" and actor.attack_kind == &"spit":
		var age: float = actor.elapsed - actor.spore_behavior.tuning.spit_release
		if age >= 0.0 and age < 0.18:
			var mouth: Vector2 = _pose.muzzle_local() * Vector2(actor.facing, 1)
			for i: int in range(5):
				var axis: Vector2 = _pose.muzzle_direction_local() * Vector2(actor.facing, 1.0)
				var offset: Vector2 = axis.rotated((i - 2) * 0.16) * age * (55 + i * 7)
				draw_circle(mouth + offset, 1.0 + age * 3, Color(0.85, 0.61, 0.85, (1.0 - age / 0.18) * 0.7))
	elif actor.spore_behavior.attack_active():
		var arc: PackedVector2Array = PackedVector2Array()
		for i: int in range(12):
			var angle: float = lerpf(-0.6, 0.8, i / 11.0)
			arc.append(Vector2(cos(angle) * 55 * actor.facing, -25 + sin(angle) * 21))
		draw_polyline(arc, Color(0.92, 0.78, 0.95, 0.45), 1.8, true)
