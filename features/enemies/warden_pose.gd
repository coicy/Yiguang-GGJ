class_name WardenPose
extends RefCounted
## Right-facing floor-space pose. Weapon contact and rendering sample the same timeline.
var hip := Vector2(0, -35)
var torso: float = -0.04
var head: float = 0.04
var hand := Vector2(24, -48)
var blade: float = 0.75
var shield := Vector2(-18, -53)
var shield_angle: float = -0.18
var back_foot := Vector2(-18, 0)
var front_foot := Vector2(19, 0)
var squash: float = 0.0

func blade_tip(length: float) -> Vector2:
	return hand + Vector2.from_angle(blade) * length

func blended(other: WardenPose, weight: float) -> WardenPose:
	var pose := WardenPose.new()
	pose.hip = hip.lerp(other.hip, weight)
	pose.torso = lerpf(torso, other.torso, weight)
	pose.head = lerpf(head, other.head, weight)
	pose.hand = hand.lerp(other.hand, weight)
	pose.blade = lerpf(blade, other.blade, weight)
	pose.shield = shield.lerp(other.shield, weight)
	pose.shield_angle = lerpf(shield_angle, other.shield_angle, weight)
	pose.back_foot = back_foot.lerp(other.back_foot, weight)
	pose.front_foot = front_foot.lerp(other.front_foot, weight)
	pose.squash = lerpf(squash, other.squash, weight)
	return pose

static func sample(enemy: CombatEnemy, clock: float, sample_time: float = -1.0) -> WardenPose:
	var pose := WardenPose.new()
	var ai := enemy.warden_behavior
	if ai == null: return pose
	var t := enemy.elapsed if sample_time < 0.0 else sample_time
	var move := ai.current_move()
	match enemy.state:
		&"windup":
			var start := strike_pose(&"slash", ai.tuning.slash.duration, ai.tuning.slash) if enemy.attack_kind == &"backswing" else WardenPose.new()
			pose = start.blended(loaded_pose(enemy.attack_kind), smoothstep(0.0, move.windup * 0.78, t))
			# The final fifth holds the silhouette; no late retargeting or hidden windup cuts.
			if enemy.attack_kind == &"charge":
				pose.back_foot.x -= sin(t * 28.0) * 2.0
		&"strike":
			pose = strike_pose(enemy.attack_kind, t, move)
		&"recover":
			var finish := ai.recovery_pose if ai.recovery_pose != null else strike_pose(enemy.attack_kind, move.duration, move)
			pose = finish.blended(WardenPose.new(), smoothstep(0.05, ai.recovery_duration, t))
			pose.hip.y += sin(clampf(t / ai.recovery_duration, 0.0, 1.0) * PI) * 2.0
		&"notice", &"overload":
			var duration := ai.tuning.phase_notice_duration if enemy.state == &"overload" else ai.tuning.notice_duration
			var brace := sin(clampf(t / duration, 0.0, 1.0) * PI)
			pose.hip.y += brace * 5.0
			pose.torso -= brace * 0.12
			pose.head -= brace * 0.1
			pose.hand += Vector2(5, -12) * brace
			pose.blade -= brace * 0.65
			pose.shield += Vector2(-5, -3) * brace
			pose.back_foot.x -= brace * 5.0
			pose.front_foot.x += brace * 5.0
		&"turn":
			var pivot := sin(clampf(t / ai.tuning.turn_duration, 0.0, 1.0) * PI)
			pose.hip.y += pivot * 4.0
			pose.torso = pivot * 0.1
			pose.head = -pivot * 0.18
			pose.front_foot.y = -pivot * 4.0
			pose.hand += Vector2(-5, 4) * pivot
			pose.shield.y += pivot * 3.0
		&"stun":
			var p := clampf(t / ai.stun_duration, 0.0, 1.0)
			var recoil := (1.0 - smoothstep(0.55, 1.0, p))
			var hit := ai.hit_direction * enemy.facing
			pose.hip += Vector2(hit * 8, 11) * recoil
			pose.torso = hit * 0.24 * recoil
			pose.head = -hit * 0.18 * recoil
			pose.hand += Vector2(hit * 17, 12) * recoil
			pose.blade += 0.25 * recoil
			pose.shield += Vector2(-10, 15) * recoil
			pose.shield_angle -= 0.45 * recoil
			pose.back_foot.x -= 7.0 * recoil
			pose.front_foot.x += 8.0 * recoil
			pose.squash = 0.04 * recoil
			if ai.reaction == &"parry":
				pose.hand = pose.hand.lerp(Vector2(-6, -85), recoil)
				pose.blade = lerpf(pose.blade, -1.3, recoil)
				pose.torso = -0.34 * recoil
				pose.front_foot.y = -4.0 * recoil * (1.0 - smoothstep(0.1, 0.22, t))
				if ai.parry_pose != null:
					var opened := pose
					pose = ai.parry_pose.blended(opened, smoothstep(0.0, 0.08, t))
					pose.hand = ai.parry_pose.hand.lerp(opened.hand, smoothstep(0.0, 0.045, t))
					pose.blade = lerpf(ai.parry_pose.blade, opened.blade, smoothstep(0.0, 0.045, t))
			elif ai.reaction == &"wall":
				pose.hip.x = -9.0 * recoil
				pose.torso = 0.23 * recoil
				pose.head = 0.15 * recoil
				pose.shield = Vector2(2, -45)
		&"dead":
			# Knees give way, the core folds, the blade lands, then the body settles.
			var fall := smoothstep(0.0, enemy.definition.death_duration * 0.7, t)
			pose.hip = Vector2(10, -35 + fall * 27)
			pose.torso = fall * 0.65
			pose.head = fall * 0.28
			pose.hand = Vector2(24, -48).lerp(Vector2(39, -7), fall)
			pose.blade = lerpf(0.75, 0.05, fall)
			pose.shield = Vector2(-18, -53).lerp(Vector2(-25, -9), fall)
			pose.shield_angle = -fall * 0.85
			pose.back_foot.x -= fall * 9
			pose.front_foot.x += fall * 12
		_:
			var breath := sin(clock * 2.5)
			pose.hip.y += breath * 0.6
			pose.head += sin(clock * 2.5 - 0.4) * 0.012
			pose.hand.y += sin(clock * 2.5 - 0.8) * 0.8
			pose.shield.y += sin(clock * 2.5 - 0.6) * 0.5
	# Armored hits still visibly travel through core, head, shoulders and stance.
	if ai.reaction_left > 0.0 and enemy.state not in [&"dead", &"stun"]:
		var age := ai.reaction_duration - ai.reaction_left
		var recoil := sin(clampf(age / ai.reaction_duration, 0, 1) * PI) * (1.7 if ai.reaction == &"heavy" else 1.0)
		var hit := ai.hit_direction * enemy.facing
		pose.hip += Vector2(hit * 2.5, 1.4) * recoil
		pose.torso += hit * 0.075 * recoil
		pose.head -= hit * 0.11 * recoil
		pose.shield += Vector2(hit * 3, 2) * recoil
		pose.back_foot.x -= recoil * 2.0
		pose.front_foot.x += recoil * 2.0
		# Hands remain tied to the authored attack contact during active frames.
		if enemy.state != &"strike":
			pose.hand += Vector2(hit * 3, 1) * recoil
			pose.blade -= hit * 0.06 * recoil
	return pose

static func loaded_pose(kind: StringName) -> WardenPose:
	var pose := WardenPose.new()
	pose.hip = Vector2(-7, -30)
	pose.torso = -0.18
	pose.head = 0.13
	pose.hand = Vector2(-15, -73)
	pose.blade = -1.45
	pose.shield = Vector2(-22, -51)
	pose.back_foot = Vector2(-25, 0)
	pose.front_foot = Vector2(24, 0)
	pose.squash = 0.035
	match kind:
		&"charge":
			pose.hip = Vector2(-9, -26)
			pose.torso = 0.22
			pose.head = -0.15
			pose.hand = Vector2(-18, -41)
			pose.blade = 0.15
			pose.shield = Vector2(10, -48)
			pose.shield_angle = 0.14
			pose.front_foot = Vector2(29, 0)
		&"slam":
			pose.hip = Vector2(-5, -39)
			pose.torso = -0.17
			pose.head = -0.12
			pose.hand = Vector2(6, -84)
			pose.blade = -1.7
			pose.shield = Vector2(-24, -57)
			pose.shield_angle = -0.48
			pose.front_foot = Vector2(24, -3)
		&"uppercut":
			pose.hip = Vector2(-6, -23)
			pose.torso = 0.14
			pose.head = -0.25
			pose.hand = Vector2(12, -28)
			pose.blade = 0.35
			pose.shield = Vector2(-24, -40)
		&"backswing":
			pose.hip = Vector2(-5, -28)
			pose.torso = 0.12
			pose.hand = Vector2(18, -35)
			pose.blade = 0.95
			pose.shield = Vector2(-21, -43)
	return pose

static func strike_pose(kind: StringName, time: float, move: WardenMove) -> WardenPose:
	var load_pose := loaded_pose(kind)
	var release := WardenPose.new()
	release.hip = Vector2(7, -33)
	release.torso = 0.23
	release.head = -0.15
	release.hand = Vector2(32, -39)
	release.blade = 0.60
	release.shield = Vector2(-22, -44)
	release.shield_angle = -0.38
	release.back_foot = Vector2(-25, -2)
	release.front_foot = Vector2(29, 0)
	match kind:
		&"charge":
			release.hip = Vector2(8, -29)
			release.torso = 0.27
			release.head = -0.2
			release.hand = Vector2(-8, -44)
			release.blade = 0.1
			release.shield = Vector2(18, -49)
			release.shield_angle = 0.15
		&"slam":
			release.hip = Vector2(7, -23)
			release.torso = 0.36
			release.head = 0.08
			release.hand = Vector2(27, -52)
			release.blade = 0.90
			release.shield = Vector2(-23, -36)
			release.back_foot = Vector2(-27, 0)
			release.front_foot = Vector2(31, 0)
			release.squash = 0.06
		&"uppercut":
			release.hip = Vector2(5, -41)
			release.torso = -0.12
			release.head = -0.18
			release.hand = Vector2(26, -67)
			release.blade = -1.5
			release.shield = Vector2(-24, -57)
			release.back_foot = Vector2(-23, -3)
		&"backswing":
			release.hip = Vector2(9, -34)
			release.torso = -0.07
			release.head = 0.04
			release.hand = Vector2(36, -55)
			release.blade = -0.75
	# The hips lead the weapon; the weapon arrives at the opening of active frames.
	var drive := smoothstep(0.0, move.active_start * 0.9, time)
	var swing := smoothstep(move.active_start * 0.25, move.active_start + 0.055, time)
	var pose := load_pose.blended(release, swing)
	pose.hip = load_pose.hip.lerp(release.hip, drive)
	pose.torso = lerpf(load_pose.torso, release.torso, smoothstep(0.015, move.active_start, time))
	pose.shield = load_pose.shield.lerp(release.shield, smoothstep(0.025, move.active_start + 0.09, time))
	var settle := smoothstep(move.active_end, move.duration, time)
	pose.back_foot.y = lerpf(pose.back_foot.y, 0.0, settle)
	pose.hip.y += sin(settle * PI) * 2.0
	return pose
