class_name PrunerPose
extends RefCounted
## Right-facing floor-space key poses. Hips lead; chest, arms and blades follow.
var hips := Vector2(0, -24)
var pitch: float = -0.04
var twist: float = 0.0
var hand := Vector2(23, -35)
var tool_angle: float = 0.04
var closure: float = 0.0
var shield := Vector2(15, -32)
var shield_angle: float = -0.12
var rear_foot := Vector2(-10, 0)
var front_foot := Vector2(10, 0)
var toe: float = 0.0
var head: float = 0.0

func blended(other: PrunerPose, weight: float) -> PrunerPose:
	var pose := PrunerPose.new()
	pose.hips = hips.lerp(other.hips, weight)
	pose.pitch = lerpf(pitch, other.pitch, weight)
	pose.twist = lerpf(twist, other.twist, weight)
	pose.hand = hand.lerp(other.hand, weight)
	pose.tool_angle = lerpf(tool_angle, other.tool_angle, weight)
	pose.closure = lerpf(closure, other.closure, weight)
	pose.shield = shield.lerp(other.shield, weight)
	pose.shield_angle = lerpf(shield_angle, other.shield_angle, weight)
	pose.rear_foot = rear_foot.lerp(other.rear_foot, weight)
	pose.front_foot = front_foot.lerp(other.front_foot, weight)
	pose.toe = lerpf(toe, other.toe, weight)
	pose.head = lerpf(head, other.head, weight)
	return pose

static func loaded(kind: StringName) -> PrunerPose:
	var p := PrunerPose.new()
	p.hips = Vector2(-4, -21)
	p.pitch = -0.17
	p.twist = -0.15
	p.hand = Vector2(5, -38)
	p.tool_angle = -0.28
	p.closure = -0.28
	p.shield = Vector2(9, -29)
	p.shield_angle = 0.15
	p.rear_foot = Vector2(-15, 0)
	p.front_foot = Vector2(13, 0)
	p.toe = -0.08
	p.head = 0.12
	if kind == &"lunge":
		p.hips = Vector2(-7, -20)
		p.pitch = 0.08
		p.hand = Vector2(4, -30)
		p.tool_angle = -0.02
		p.rear_foot.x = -18
		p.front_foot = Vector2(12, -3)
		p.shield = Vector2(13, -27)
	elif kind == &"slam":
		p.hips = Vector2(-2, -25)
		p.pitch = -0.28
		p.hand = Vector2(2, -52)
		p.tool_angle = -1.55
		p.closure = 0.72
		p.shield = Vector2(-5, -30)
		p.shield_angle = 0.42
		p.rear_foot.x = -16
		p.front_foot.x = 16
	return p

static func released(kind: StringName) -> PrunerPose:
	var p := PrunerPose.new()
	p.hips = Vector2(5, -22)
	p.pitch = 0.2
	p.twist = 0.15
	p.hand = Vector2(28, -28)
	p.tool_angle = 0.04
	p.closure = 1.0
	p.shield = Vector2(0, -32)
	p.shield_angle = -0.34
	p.rear_foot = Vector2(-14, -2)
	p.front_foot = Vector2(19, 0)
	p.toe = 0.28
	p.head = -0.15
	if kind == &"lunge":
		p.hips = Vector2(6, -20)
		p.pitch = 0.28
		p.hand = Vector2(33, -27)
		p.rear_foot = Vector2(-21, -3)
		p.front_foot = Vector2(22, 0)
		p.shield = Vector2(3, -26)
	elif kind == &"slam":
		p.hips = Vector2(4, -18)
		p.pitch = 0.42
		p.hand = Vector2(24, -17)
		p.tool_angle = 0.67
		p.shield = Vector2(-6, -24)
		p.shield_angle = -0.55
		p.rear_foot = Vector2(-16, 0)
		p.front_foot = Vector2(20, 0)
		p.toe = 0.05
	return p

static func sample(enemy: CombatEnemy, clock: float) -> PrunerPose:
	var p := PrunerPose.new()
	var behavior := enemy.pruner_behavior
	if behavior == null:
		return p
	var t := enemy.elapsed
	var move := behavior.current_move()
	p.hips.y += sin(clock * 2.3) * 0.4
	p.pitch += sin(clock * 2.3 - 0.6) * 0.018
	p.hand.y += sin(clock * 2.3 - 1.1) * 0.5
	p.shield.y += sin(clock * 2.3 - 0.3) * 0.35
	p.head = sin(clock * 1.7) * 0.035
	if enemy.state == &"recover" and behavior.parry_recovery_pose != null:
		return behavior.parry_recovery_pose.blended(p, smoothstep(0.0, behavior.recovery_duration, t))
	match enemy.state:
		&"notice":
			var lift := sin(clampf(t / behavior.tuning.notice_duration, 0, 1) * PI)
			p.hips.y -= lift * 1.8
			p.pitch -= lift * 0.09
			p.hand.y -= lift * 2.0
			p.shield.x += lift * 3.0
			p.front_foot.x += lift * 2.0
		&"turn":
			var pivot := sin(clampf(t / behavior.tuning.turn_duration, 0, 1) * PI)
			p.hips.y += pivot * 2.3
			p.twist = pivot * 0.12
			p.hand.x -= pivot * 7.0
			p.shield.x -= pivot * 4.0
			p.front_foot.y -= pivot * 3.0
		&"windup":
			var target := loaded(enemy.attack_kind)
			p = p.blended(target, smoothstep(0, move.windup * 0.84, t))
			# Foot pressure and hips settle first; blade opening follows shoulder draw.
			p.hips = Vector2(0, -24).lerp(target.hips, smoothstep(0, move.windup * 0.6, t))
			p.closure = lerpf(0.0, target.closure, smoothstep(move.windup * 0.2, move.windup * 0.9, t))
		&"strike":
			var start := loaded(enemy.attack_kind)
			var finish := released(enemy.attack_kind)
			p = start.blended(finish, smoothstep(0, move.active_start, t))
			p.hips = start.hips.lerp(finish.hips, smoothstep(0, move.active_start * 0.65, t))
			p.hand = start.hand.lerp(finish.hand, smoothstep(move.active_start * 0.18, move.active_start, t))
			p.tool_angle = lerpf(start.tool_angle, finish.tool_angle, smoothstep(move.active_start * 0.25, move.active_start, t))
			p.closure = lerpf(start.closure, finish.closure, smoothstep(move.active_start * 0.65, move.active_start, t))
			# The follow-through holds its silhouette through the final active frame.
			var settle := smoothstep(move.active_end, move.duration, t)
			p.hips.y += sin(settle * PI) * 1.2
			p.hand.x -= settle * 2.0
		&"recover":
			var start := released(enemy.attack_kind)
			start.hand.x -= 2.0
			p = start.blended(p, smoothstep(0.08, behavior.recovery_duration, t))
			p.closure = lerpf(1.0, 0.0, smoothstep(behavior.recovery_duration * 0.35, behavior.recovery_duration, t))
		&"guard_bump":
			var bump := sin(clampf(t / behavior.tuning.block_duration, 0, 1) * PI)
			p.hips += Vector2(-2.5, 2.0) * bump
			p.pitch -= 0.13 * bump
			p.shield += Vector2(-5, 1) * bump
			p.shield_angle -= 0.25 * bump
			p.hand += Vector2(-2, -2) * bump
			p.front_foot.x += 3.0 * bump
			p.toe = bump * 0.12
		&"stun":
			var recoil := (1.0 - smoothstep(0.07, behavior.stun_duration, t))
			if behavior.reaction == &"parry":
				recoil = 1.0 - smoothstep(behavior.stun_duration * 0.6, behavior.stun_duration, t)
			var strength := 1.0 if behavior.reaction == &"light" else 1.7
			var hit := behavior.hit_direction * enemy.facing
			p.hips += Vector2(hit * 4.0, 3.0) * recoil * strength
			p.pitch = hit * 0.22 * recoil * strength
			p.hand += Vector2(hit * 7.0, -4.0) * recoil * strength
			p.tool_angle -= hit * 0.3 * recoil
			p.shield += Vector2(hit * 4.0, 4.0) * recoil
			p.shield_angle = -hit * 0.35 * recoil
			p.rear_foot += Vector2(-4, -2) * recoil * strength
			p.front_foot += Vector2(5, -3) * recoil * strength
			p.head = -hit * 0.18 * recoil
			if behavior.reaction == &"break":
				p.hips.y += 4.0 * recoil
				p.shield += Vector2(-11, 9) * recoil
				p.shield_angle -= 0.8 * recoil
				p.hand.y += 6.0 * recoil
			elif behavior.reaction == &"parry":
				p.hand += Vector2(-7, -13) * recoil
				p.tool_angle -= 0.85 * recoil
				p.closure = -0.5 * recoil
				p.shield.x -= 6.0 * recoil
				p.pitch = -0.38 * recoil
				p.rear_foot.y = 0.0
				p.front_foot.y *= 1.0 - smoothstep(0.08, 0.2, t)
				if behavior.parry_pose != null:
					var opened := p
					p = behavior.parry_pose.blended(opened, smoothstep(0.0, 0.075, t))
					p.hand = behavior.parry_pose.hand.lerp(opened.hand, smoothstep(0.0, 0.04, t))
					p.tool_angle = lerpf(behavior.parry_pose.tool_angle, opened.tool_angle, smoothstep(0.0, 0.04, t))
			elif behavior.reaction == &"wall":
				p.hips.y += 3.0 * recoil
				p.hand.x -= 8.0 * recoil
				p.pitch = 0.25 * recoil
		&"dead":
			var fall := smoothstep(0.0, 0.72, t)
			var hit := behavior.hit_direction * enemy.facing
			p.hips += Vector2(hit * 12, 17) * fall
			p.pitch = hit * 1.1 * fall
			p.hand = p.hand.lerp(Vector2(hit * 28, -6), fall)
			p.tool_angle = hit * 0.7 * fall
			p.shield = p.shield.lerp(Vector2(-8, -3), fall)
			p.shield_angle = -1.2 * fall
			p.rear_foot = p.rear_foot.lerp(Vector2(-18, 0), fall)
			p.front_foot = p.front_foot.lerp(Vector2(21, 0), fall)
			p.head = hit * 0.4 * fall
	return p
