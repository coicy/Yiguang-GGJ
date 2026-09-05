class_name BeetlePose
extends RefCounted
## Local, right-facing pose. Feet stay in floor space while the thorax articulates.
var body := Vector2.ZERO
var pitch: float = 0.0
var head: float = 0.0
var shell: float = 0.0
var squash: float = 0.0
var spread: float = 0.0
var front_lift: float = 0.0
var curl: float = 0.0

func blended(other: BeetlePose, weight: float) -> BeetlePose:
	var result := BeetlePose.new()
	result.body = body.lerp(other.body, weight)
	result.pitch = lerpf(pitch, other.pitch, weight)
	result.head = lerpf(head, other.head, weight)
	result.shell = lerpf(shell, other.shell, weight)
	result.squash = lerpf(squash, other.squash, weight)
	result.spread = lerpf(spread, other.spread, weight)
	result.front_lift = lerpf(front_lift, other.front_lift, weight)
	result.curl = lerpf(curl, other.curl, weight)
	return result

static func sample(enemy: CombatEnemy, clock: float) -> BeetlePose:
	var pose := BeetlePose.new()
	var behavior := enemy.beetle_behavior
	var t := enemy.elapsed
	var breath := sin(clock * 2.7)
	pose.body.y = breath * 0.35
	pose.head = sin(clock * 2.7 - 0.6) * 0.025
	pose.shell = sin(clock * 2.7 - 1.1) * 0.012
	if behavior == null:
		return pose
	if enemy.state == &"recover" and behavior.parry_recovery_pose != null:
		return behavior.parry_recovery_pose.blended(pose, smoothstep(0.0, behavior.recovery_duration, t))
	match enemy.state:
		&"notice":
			var lift := sin(clampf(t / behavior.tuning.notice_duration, 0.0, 1.0) * PI)
			pose.body.y = -lift * 2.0
			pose.pitch = -lift * 0.06
			pose.head = -lift * 0.22
			pose.front_lift = lift * 2.0
		&"turn":
			var pivot := sin(clampf(t / behavior.tuning.turn_duration, 0.0, 1.0) * PI)
			pose.body.y = pivot * 2.0
			pose.head = -pivot * 0.12
			pose.spread = pivot * 2.5
		&"windup":
			var p := smoothstep(0.0, behavior.windup_duration() * 0.8, t)
			pose.body = Vector2(-4.0, 3.8) * p
			pose.pitch = 0.1 * p
			pose.head = (0.24 if enemy.attack_kind == &"charge" else 0.46) * p
			pose.shell = -0.1 * p
			pose.squash = 0.085 * p
			pose.spread = 3.5 * p
		&"strike":
			if enemy.attack_kind == &"charge":
				var launch := smoothstep(0.0, behavior.tuning.charge_launch_seconds, t)
				pose.body = Vector2(-4.0, 3.8).lerp(Vector2(2.0, 0.8), launch)
				pose.pitch = lerpf(0.1, 0.04, launch)
				pose.head = lerpf(0.24, -0.14, launch)
				pose.shell = lerpf(-0.1, 0.13, smoothstep(0.025, 0.15, t))
				pose.squash = lerpf(0.085, -0.025, launch)
				pose.spread = lerpf(3.5, 0.0, launch)
			else:
				var release := smoothstep(0.0, 0.085, t)
				var settle := smoothstep(0.13, behavior.tuning.bite_duration, t)
				pose.body = Vector2(-4.0, 3.8).lerp(Vector2(4.0, -3.5), release).lerp(Vector2(2.0, 0.0), settle)
				pose.pitch = lerpf(0.1, -0.2, release) + settle * 0.11
				pose.head = lerpf(0.46, -0.85, release) + settle * 0.36
				pose.shell = -0.1 + smoothstep(0.02, 0.12, t) * 0.3 - settle * 0.12
				pose.front_lift = sin(clampf(t / behavior.tuning.bite_duration, 0.0, 1.0) * PI) * 7.0
				pose.spread = 3.5 - release * 5.0
		&"recover":
			var settle := 1.0 - smoothstep(0.0, behavior.recovery_duration, t)
			pose.body = Vector2(2.0, 2.5) * settle
			pose.pitch = 0.1 * settle
			pose.head = (-0.14 if enemy.attack_kind == &"charge" else -0.36) * settle
			pose.shell = 0.07 * settle
			pose.squash = sin(clampf(t / behavior.recovery_duration, 0.0, 1.0) * PI) * 0.045
			pose.spread = 5.0 * settle
		&"stun":
			var strength := 1.0 if behavior.reaction == &"light" else 1.7
			var local_hit := behavior.hit_direction * enemy.facing
			var recoil := sin(clampf(t / behavior.stun_duration, 0.0, 1.0) * PI * 0.75 + 0.55) * (1.0 - smoothstep(0.1, behavior.stun_duration, t))
			if behavior.reaction == &"parry":
				recoil = 1.0 - smoothstep(behavior.stun_duration * 0.6, behavior.stun_duration, t)
			pose.body = Vector2(local_hit * 3.5, 1.3) * recoil * strength
			pose.pitch = local_hit * 0.15 * recoil * strength
			pose.head = -local_hit * 0.25 * recoil * strength
			pose.shell = local_hit * 0.2 * recoil * strength
			pose.spread = 5.0 * recoil
			pose.squash = 0.06 * recoil
			pose.front_lift = (3.0 if behavior.reaction == &"light" else 7.0) * recoil
			if behavior.reaction == &"wall":
				# Impact drives the face into the thorax before the planted feet catch it.
				pose.body.y = 3.0 * recoil
				pose.head = 0.42 * recoil
				pose.squash = 0.13 * recoil
				pose.front_lift = 0.0
				pose.spread = 7.0 * recoil
			elif behavior.reaction == &"parry":
				# A deflected horn opens the chest and pulls the forelegs off the floor.
				pose.body.y = -3.0 * recoil
				pose.pitch = -0.24 * recoil
				pose.head = -0.58 * recoil
				pose.front_lift = 9.0 * recoil
				if behavior.parry_pose != null:
					var opened := pose
					pose = behavior.parry_pose.blended(opened, smoothstep(0.0, 0.065, t))
					pose.head = lerpf(behavior.parry_pose.head, opened.head, smoothstep(0.0, 0.035, t))
		&"dead":
			var fall := smoothstep(0.0, 0.55, t)
			pose.body = Vector2(behavior.hit_direction * enemy.facing * fall * 8.0, -sin(fall * PI) * 10.0 + fall * 7.0)
			pose.pitch = behavior.hit_direction * enemy.facing * fall * 1.7
			pose.head = 0.5 * fall
			pose.shell = 0.14 * sin(fall * PI)
			pose.curl = fall
	return pose
