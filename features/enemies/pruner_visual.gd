class_name PrunerVisual
extends EnemyVisual
## Existing atlas articulated at its painted joints. No baked full-body rotations.
var _chest: Node2D
var _neck: Polygon2D
var _tool: Node2D
var _top_blade: Polygon2D
var _bottom_blade: Polygon2D
var _shield: Polygon2D
var _weapon_arm: Polygon2D
var _shield_arm: Polygon2D
var _uppers: Array[Polygon2D] = []
var _lowers: Array[Polygon2D] = []
var _boots: Array[Polygon2D] = []
var _feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _knees: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _hips: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _pose := PrunerPose.new()
var _from_pose := PrunerPose.new()
var _last_state: StringName = &""
var _blend_elapsed: float = 1.0
var _stride: float = 0.0
var _last_position := Vector2.ZERO
var _gait_weight: float = 0.0
var _strike_world_x: float = 0.0

func configure(enemy: CombatEnemy) -> void:
	actor = enemy
	_rig = Node2D.new()
	_rig.name = "PrunerRig"
	add_child(_rig)
	for i: int in range(2):
		_uppers.append(_piece(PackedVector2Array([Vector2(174,638),Vector2(296,638),Vector2(294,695),Vector2(393,720),Vector2(470,811),Vector2(438,893),Vector2(328,902),Vector2(269,819),Vector2(171,753)]), Vector2(220,727), _rig))
		_lowers.append(_piece(PackedVector2Array([Vector2(341,811),Vector2(433,825),Vector2(456,915),Vector2(375,1061),Vector2(289,1127),Vector2(218,1113),Vector2(238,1019),Vector2(299,900)]), Vector2(355,856), _rig))
		_boots.append(_piece(PackedVector2Array([Vector2(235,1067),Vector2(302,1058),Vector2(394,1081),Vector2(441,1121),Vector2(511,1150),Vector2(518,1204),Vector2(201,1204),Vector2(193,1169)]), Vector2(264,1091), _rig))
		for limb: Polygon2D in [_uppers[i], _lowers[i], _boots[i]]:
			limb.z_index = -2 if i == 0 else -1
			limb.modulate = Color("#8f9680") if i == 0 else Color.WHITE
	_chest = Node2D.new()
	_chest.name = "Chest"
	_rig.add_child(_chest)
	var torso := _piece(PackedVector2Array([Vector2(10,8),Vector2(243,8),Vector2(244,137),Vector2(367,141),Vector2(367,8),Vector2(616,8),Vector2(616,612),Vector2(10,612)]), Vector2(306,522), _chest)
	torso.scale = Vector2.ONE * 0.059
	_neck = _piece(PackedVector2Array([Vector2(248,57),Vector2(366,57),Vector2(377,145),Vector2(248,146)]),Vector2(306,145),_chest)
	_neck.position = Vector2(0,-22.3)
	_neck.scale = Vector2.ONE * 0.059
	_weapon_arm = _piece(PackedVector2Array([Vector2(638,81),Vector2(800,81),Vector2(869,158),Vector2(919,265),Vector2(937,360),Vector2(849,402),Vector2(745,314),Vector2(651,241)]),Vector2(686,207),_rig)
	_weapon_arm.z_index = -1
	_shield_arm = _piece(PackedVector2Array([Vector2(638,120),Vector2(749,126),Vector2(874,255),Vector2(917,330),Vector2(850,379),Vector2(742,299),Vector2(653,225)]),Vector2(686,207),_rig)
	_shield_arm.z_index = 1
	_tool = Node2D.new()
	_tool.name = "Shears"
	_tool.z_index = 3
	_rig.add_child(_tool)
	_top_blade = _piece(PackedVector2Array([Vector2(899,282),Vector2(961,259),Vector2(1020,233),Vector2(1137,183),Vector2(1203,146),Vector2(1245,113),Vector2(1240,219),Vector2(1193,286),Vector2(1091,335),Vector2(967,365),Vector2(895,380),Vector2(860,345)]),Vector2(900,340),_tool)
	_bottom_blade = _piece(PackedVector2Array([Vector2(874,320),Vector2(938,326),Vector2(985,371),Vector2(1104,373),Vector2(1184,345),Vector2(1245,312),Vector2(1242,354),Vector2(1189,429),Vector2(1106,480),Vector2(1002,486),Vector2(914,441),Vector2(847,390)]),Vector2(900,340),_tool)
	_bottom_blade.z_index = -1
	var spindle := PackedVector2Array()
	for i: int in range(28):
		spindle.append(Vector2(900,340) + Vector2.from_angle(i * TAU / 28.0) * 61.0)
	_piece(spindle, Vector2(900,340), _tool)
	_tool.scale = Vector2.ONE * 0.063
	_shield = _piece(PackedVector2Array([Vector2(640,634),Vector2(1245,634),Vector2(1245,1245),Vector2(640,1245)]),Vector2(880,856),_rig)
	_shield.scale = Vector2.ONE * 0.051
	_shield.z_index = 2
	_last_position = actor.global_position
	_process(0.0)

func _piece(vertices: PackedVector2Array, pivot: Vector2, host: Node2D) -> Polygon2D:
	var part := Polygon2D.new()
	var local := PackedVector2Array()
	for vertex: Vector2 in vertices:
		local.append(vertex - pivot)
	part.polygon = local
	part.uv = vertices
	part.texture = actor.definition.atlas
	part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	part.antialiased = true
	host.add_child(part)
	return part

func _process(delta: float) -> void:
	if actor == null or actor.pruner_behavior == null:
		return
	_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	modulate = Color(1.65, 1.48, 1.22) if flash_left > 0.0 else Color.WHITE
	var moved := actor.global_position.x - _last_position.x
	_last_position = actor.global_position
	var walking := actor.state in [&"idle", &"patrol"] and actor.is_on_floor()
	_gait_weight = move_toward(_gait_weight, 1.0 if walking and absf(actor.velocity.x) > 2.0 else 0.0, delta * 12.0)
	if walking:
		_stride += moved * actor.facing / 34.0
	if _last_state != actor.state:
		_from_pose = _pose
		_blend_elapsed = 0.0
		_last_state = actor.state
		if actor.state == &"strike":
			_strike_world_x = actor.global_position.x
	_blend_elapsed += delta
	var blend := 0.025 if actor.state in [&"strike", &"stun"] else actor.pruner_behavior.tuning.transition_blend
	_pose = _from_pose.blended(PrunerPose.sample(actor, _time), smoothstep(0, blend, _blend_elapsed))
	_rig.scale = Vector2(actor.facing, 1.0)
	if actor.state == &"turn":
		_rig.scale.x *= 1.0 - sin(clampf(actor.elapsed / actor.pruner_behavior.tuning.turn_duration, 0, 1) * PI) * 0.76
	_chest.position = _pose.hips
	_chest.rotation = _pose.pitch
	_chest.scale = Vector2(1.0 - absf(_pose.twist), 1.0)
	_neck.rotation = _pose.head
	var hand := _pose.hand
	var shield := _pose.shield
	# Counter-swing follows the measured gait rather than a free-running walk clock.
	hand += Vector2(-sin(_stride * TAU) * 1.8, cos(_stride * TAU) * 0.6) * _gait_weight
	shield.x += sin(_stride * TAU) * 1.2 * _gait_weight
	_tool.position = hand
	_tool.rotation = _pose.tool_angle
	_top_blade.rotation = _pose.closure * 0.27
	_bottom_blade.rotation = -_pose.closure * 0.28
	_shield.position = shield
	_shield.rotation = _pose.shield_angle
	_segment(_weapon_arm, _chest.transform * Vector2(8,-19), hand, Vector2(214,133))
	_segment(_shield_arm, _chest.transform * Vector2(-7,-18), shield, Vector2(214,133))
	for i: int in range(2):
		_pose_leg(i)
	_rig.modulate.a = 1.0 - smoothstep(actor.definition.death_duration * 0.75, actor.definition.death_duration, actor.elapsed) if actor.state == &"dead" else 1.0
	queue_redraw()

func _pose_leg(i: int) -> void:
	var hip := _pose.hips + Vector2(-6 if i == 0 else 6, 0)
	var foot := _pose.rear_foot if i == 0 else _pose.front_foot
	var phase := fposmod(_stride + i * 0.5, 1.0)
	var travel: float
	var lift: float
	if phase < 0.62:
		travel = 10.54 - phase * 34.0
		lift = 0.0
	else:
		var swing := (phase - 0.62) / 0.38
		travel = lerpf(-10.54, 10.54, smoothstep(0, 1, swing))
		lift = sin(swing * PI) * 6.0
	foot += Vector2(travel, -lift) * _gait_weight
	if actor.state == &"strike" and actor.attack_kind == &"lunge":
		# Rear boot pushes against its launch point, then releases into the step.
		var move := actor.pruner_behavior.current_move()
		var push := 1.0 - smoothstep(0.07, move.active_start, actor.elapsed)
		if i == 0:
			foot.x -= (actor.global_position.x - _strike_world_x) * actor.facing * push
		else:
			foot.y -= sin(clampf(actor.elapsed / move.active_start, 0, 1) * PI) * 7.0
	if not actor.is_on_floor() and actor.state == &"stun":
		foot.y -= 3.0
	var ankle := foot + Vector2(0,-3.5)
	var span := ankle - hip
	var distance := clampf(span.length(), 1.0, 28.4)
	var direction := span.normalized() if span.length() > 0.01 else Vector2.DOWN
	var upper := 13.8
	var lower := 15.0
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(0.0, upper * upper - along * along))
	var knee := hip + direction * along + Vector2(direction.y,-direction.x) * bend
	_hips[i] = hip
	_knees[i] = knee
	_feet[i] = foot
	_segment(_uppers[i],hip,knee,Vector2(135,129))
	_segment(_lowers[i],knee,ankle,Vector2(-91,235))
	_boots[i].position = ankle
	_boots[i].scale = Vector2.ONE * 0.035
	_boots[i].rotation = _pose.toe if i == 0 else -_pose.toe * 0.25

func _segment(part: Polygon2D, start: Vector2, end: Vector2, axis: Vector2) -> void:
	var span := end - start
	part.position = start
	part.rotation = span.angle() - axis.angle()
	part.scale = Vector2.ONE * span.length() / axis.length()

func pose_snapshot() -> Dictionary:
	return {"body":_chest.transform,"tool":_tool.transform,"shield":_shield.transform,"feet":_feet.duplicate(),"knees":_knees.duplicate(),"hips":_hips.duplicate(),"blade":_top_blade.rotation}

func _draw() -> void:
	if actor == null or actor.pruner_behavior == null:
		return
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.15))
	draw_circle(Vector2.ZERO,23,Color(0.03,0.055,0.04,0.32 * _rig.modulate.a))
	draw_set_transform(Vector2.ZERO)
	if actor.state == &"dead":
		return
	_draw_status_bars(-65.0)
	if actor.state == &"windup":
		var danger := not actor.pruner_behavior.current_move().parryable
		var tint := Color("#ff9273") if danger else Color("#ffe4a1")
		var point := Vector2(0,-76)
		draw_circle(point,6.5,Color("#243830"))
		if danger:
			draw_line(point-Vector2(3,3),point+Vector2(3,3),tint,2,true)
			draw_line(point+Vector2(-3,3),point+Vector2(3,-3),tint,2,true)
		else:
			draw_line(point+Vector2(0,-4),point+Vector2(0,1),tint,2,true)
			draw_circle(point+Vector2(0,4),1,tint)
		var progress := clampf(actor.elapsed / actor.pruner_behavior.current_move().windup,0,1)
		draw_arc(point,9,-PI*0.5,-PI*0.5+TAU*progress,24,tint,1.3,true)
	if actor.state == &"strike":
		var move := actor.pruner_behavior.current_move()
		if actor.elapsed >= move.active_start * 0.5 and actor.elapsed < move.active_end:
			# Trail follows the moving cutter tips, never substitutes for the weapon.
			var points := PackedVector2Array()
			for i: int in range(7):
				var angle := _pose.tool_angle - 0.45 + i * 0.10
				var tip := _pose.hand + Vector2.from_angle(angle) * 22.0
				points.append(Vector2(tip.x * actor.facing, tip.y))
			draw_polyline(points,Color(1,0.87,0.56,0.55),1.2,true)
	if actor.state == &"guard_bump" or (actor.state == &"stun" and actor.pruner_behavior.reaction in [&"break",&"parry",&"wall"]):
		var fade := 1.0 - smoothstep(0,0.2,actor.elapsed)
		for i: int in range(5):
			var direction := Vector2.from_angle(-PI * 0.9 + i * 0.44)
			var point := Vector2(_pose.shield.x * actor.facing,-31) + direction * (6 + actor.elapsed * 35)
			draw_line(point,point+direction*3,Color(1,0.83,0.42,fade),1.1,true)
