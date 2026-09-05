@tool
class_name VineWhipVisual
extends Node2D
## A visual-only plant rig with a hand-pinned elastic chain. CombatController owns damage.
## hand_transform is in this node's parent coordinates, after the body pose update.
@export var humanoid_profile: VineWhipProfile
@export var mature_profile: VineWhipProfile
@export var trail_enabled: bool = true
@export_group("Editor animation preview")
@export_enum("humanoid", "mature") var preview_form: String = "humanoid"
@export var preview_reach: float = 60.0
@export var preview_height: float = 36.0
## Authored by the ten AnimationPlayer clips; phase boundaries are 0 / 1 / 2 / 3.
@export var extension: float = 0.18
@export var sweep: float = -0.3
@export var leaf_flutter: float = 0.0
@export var silhouette_alpha: float = 1.0
@export var behind_body: bool = false
var sampled_phase: float = 0.0
var sampled_animation: StringName = &""
var tip_position := Vector2.ZERO
var parry_contact_position := Vector2.ZERO
@onready var skeleton: Skeleton2D = %Skeleton2D
@onready var stem: Polygon2D = %Stem
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var sheath: Sprite2D = %Sheath
@onready var tip: Sprite2D = %Tip
@onready var leaves: Array[Sprite2D] = [%LeafA, %LeafB, %LeafC, %LeafD]
@onready var nodes: Array[Sprite2D] = [%NodeA, %NodeB, %NodeC]
var _bones: Array[Bone2D] = []
var _profile: VineWhipProfile
var _last_elapsed: float = -1.0
var _trail_shapes: Array[PackedVector2Array] = []
const MOTION_SCRIPT = preload("res://features/combat/visuals/vine_whip_motion.gd")
var _motion = MOTION_SCRIPT.new()
var _segment_length: float = 0.0
const JOINT_COUNT: int = 10
const REST_STEP: float = 10.0

func _ready() -> void:
	var bone: Bone2D = %Root
	for index in range(JOINT_COUNT):
		_bones.append(bone)
		if index < JOINT_COUNT - 1:
			bone = bone.get_node(NodePath("Segment%02d" % (index + 1))) as Bone2D
	for profile: VineWhipProfile in [humanoid_profile, mature_profile]:
		if profile != null and profile.animation_library != null and not animation_player.has_animation_library(profile.form_id):
			animation_player.add_animation_library(profile.form_id, profile.animation_library)
	_apply_profile(humanoid_profile)
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		clear_attack()

func _process(_delta: float) -> void:
	# AnimationPlayer keyframes remain directly editable in the independent scene.
	# Only the editor preview runs here; gameplay uses sample_combat exclusively.
	if not Engine.is_editor_hint() or _bones.is_empty():
		return
	var profile := mature_profile if preview_form == "mature" else humanoid_profile
	if profile != _profile:
		_apply_profile(profile)
	if _profile != null:
		_apply_rig(Vector2(preview_reach, sweep * preview_height), 0.0)
		modulate.a = silhouette_alpha

func sample_combat(combat: CombatController, form_id: StringName, hand_transform: Transform2D) -> void:
	if combat != null and combat.state in [&"parry", &"parry_success"] and form_id != &"sprout":
		_sample_parry(combat, form_id, hand_transform)
		return
	if combat == null or combat.state not in [&"attack", &"attack_landing"] or combat.attack == null or form_id == &"sprout":
		clear_attack()
		return
	var definition := combat.attack
	var is_landing := combat.state == &"attack_landing"
	# Preserve the exact airborne curve at contact; landing owns a separate short clock.
	var source_elapsed := combat.landing_from_elapsed if is_landing else combat.elapsed
	var sample_time := source_elapsed / maxf(combat.time_scale_for_form(), 0.001)
	var landing_progress := combat.landing_progress() if is_landing else 0.0
	var profile := mature_profile if form_id == &"mature" else humanoid_profile
	if profile == null:
		clear_attack()
		return
	if profile != _profile:
		clear_attack()
		_apply_profile(profile)
	var animation_name := StringName("%s/%s" % [profile.form_id, definition.id])
	if not animation_player.has_animation(animation_name):
		clear_attack()
		return
	if sampled_animation != animation_name or source_elapsed < _last_elapsed:
		_motion.clear()
		_trail_shapes.clear()
		sampled_animation = animation_name
		animation_player.play(animation_name)
		animation_player.pause()
		_last_elapsed = -1.0
	sampled_phase = phase_for_time(sample_time, definition.windup, definition.active, definition.recovery)
	animation_player.seek(sampled_phase, true)
	if is_landing:
		# Seek restores the authored properties on every sample, so held/frozen frames
		# never accumulate this retraction or restart the attack from its first key.
		extension *= 1.0 - smoothstep(0.0, 1.0, landing_progress)
		silhouette_alpha *= 1.0 - smoothstep(0.25, 1.0, landing_progress)
	visible = sample_time < definition.duration() and (not is_landing or landing_progress < 1.0)
	position = hand_transform.origin
	rotation = 0.0
	scale = Vector2(combat.facing, 1.0)
	modulate.a = silhouette_alpha
	z_index = -1 if behind_body else 2
	var attack_center := Vector2(0.0, -14.0 if definition.id == &"air" else -22.0)
	var target := Vector2(combat.facing * definition.reach * combat.reach_scale(), attack_center.y + definition.height * sweep)
	var aimed := Vector2((target.x - position.x) * combat.facing, target.y - position.y)
	var hand_direction := Vector2(hand_transform.x.x * combat.facing, hand_transform.x.y).normalized()
	_apply_rig(aimed, hand_direction.angle())
	# Reserve the visible curl itself inside the same forward boundary as damage.
	# The final bone is its attachment, not the farthest visible plant pixel.
	for correction in range(2):
		var curl_extent := maxf(0.0, _tip_boundary_point().x - to_local(tip.global_position).x)
		_apply_rig(aimed - Vector2(curl_extent, 0.0), hand_direction.angle())
	var targets := _hand_linked_targets(hand_direction)
	var world_direction := global_transform.basis_xform(hand_direction).normalized()
	var motion_clock := source_elapsed + (combat.elapsed if is_landing else 0.0)
	var chain: PackedVector2Array = _motion.sample(targets, world_direction, _segment_length, motion_clock, _profile)
	_apply_chain(chain)
	tip_position = transform * _tip_boundary_point()
	# Use the node transform rather than frame time: repeated hit-stop/pause samples are identical.
	if not is_landing and sampled_phase >= 1.0 and sampled_phase < 2.0 and trail_enabled:
		if not is_equal_approx(source_elapsed, _last_elapsed):
			_record_trail()
	else:
		_trail_shapes.clear()
	_last_elapsed = source_elapsed
	queue_redraw()

static func phase_for_time(time: float, windup: float, active: float, recovery: float) -> float:
	if time < windup:
		return clampf(time / maxf(windup, 0.001), 0.0, 1.0)
	if time < windup + active:
		return 1.0 + (time - windup) / maxf(active, 0.001)
	return 2.0 + clampf((time - windup - active) / maxf(recovery, 0.001), 0.0, 1.0)

func clear_attack() -> void:
	visible = false
	_motion.clear()
	_segment_length = 0.0
	_trail_shapes.clear()
	sampled_animation = &""
	sampled_phase = 0.0
	_last_elapsed = -1.0
	tip_position = Vector2.ZERO
	parry_contact_position = Vector2.ZERO
	if is_instance_valid(animation_player):
		animation_player.stop()
	queue_redraw()

func _apply_profile(profile: VineWhipProfile) -> void:
	_profile = profile
	if profile == null:
		return
	var stem_atlas := profile.stem_texture as AtlasTexture
	stem.texture = stem_atlas.atlas if stem_atlas != null else profile.stem_texture
	stem.material = profile.texture_material
	stem.color = profile.stem_tint if profile.stem_texture != null else Color("749c39")
	_build_stem_mesh()
	_set_sprite(sheath, profile.sheath_texture, profile.sheath_size, profile.sheath_pivot)
	_set_sprite(tip, profile.tip_texture, profile.tip_size, profile.tip_pivot)
	for index in range(leaves.size()):
		var use_a := index % 2 == 0
		_set_sprite(leaves[index], profile.leaf_a_texture if use_a else profile.leaf_b_texture, profile.leaf_a_size if use_a else profile.leaf_b_size, profile.leaf_a_pivot if use_a else profile.leaf_b_pivot)
		leaves[index].visible = index < profile.leaf_count
	for node: Sprite2D in nodes:
		_set_sprite(node, profile.node_texture, profile.node_size, Vector2(0.5, 0.5))

func _set_sprite(sprite: Sprite2D, texture: Texture2D, size: Vector2, pivot: Vector2) -> void:
	sprite.texture = texture
	sprite.material = _profile.texture_material
	sprite.centered = false
	if texture == null:
		return
	var source_size := texture.get_size()
	sprite.offset = -source_size * pivot
	sprite.scale = size / source_size

func _build_stem_mesh() -> void:
	# Three rows per bone span give a continuous skinned ribbon with fixed-width leaves.
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []
	var weights: Array[PackedFloat32Array] = []
	var rows: int = (JOINT_COUNT - 1) * 3 + 1
	var source_size := _profile.stem_texture.get_size() if _profile.stem_texture != null else Vector2(256.0, 32.0)
	var uv_origin := Vector2.ZERO
	var atlas := _profile.stem_texture as AtlasTexture
	if atlas != null:
		uv_origin = atlas.region.position
		source_size = atlas.region.size
	for bone_index in range(JOINT_COUNT):
		var influence := PackedFloat32Array()
		influence.resize(rows * 2)
		weights.append(influence)
	for row in range(rows):
		var t := float(row) / float(rows - 1)
		var width := lerpf(_profile.root_width, _profile.tip_width, pow(t, 0.8)) * 0.5
		vertices.append(Vector2(t * REST_STEP * (JOINT_COUNT - 1), -width))
		vertices.append(Vector2(t * REST_STEP * (JOINT_COUNT - 1), width))
		uvs.append(uv_origin + Vector2(t * source_size.x, 0.0))
		uvs.append(uv_origin + Vector2(t * source_size.x, source_size.y))
		var along := t * float(JOINT_COUNT - 1)
		var first := mini(int(floor(along)), JOINT_COUNT - 1)
		var second := mini(first + 1, JOINT_COUNT - 1)
		var blend := along - first
		for side in range(2):
			weights[first][row * 2 + side] += 1.0 - blend
			weights[second][row * 2 + side] += blend
		if row < rows - 1:
			polygons.append(PackedInt32Array([row * 2, row * 2 + 1, row * 2 + 3, row * 2 + 2]))
	stem.polygon = vertices
	stem.uv = uvs
	stem.polygons = polygons
	stem.clear_bones()
	for index in range(JOINT_COUNT):
		stem.add_bone(skeleton.get_path_to(_bones[index]), weights[index])

func _apply_rig(aimed: Vector2, hand_angle: float) -> void:
	# Bone angles come from AnimationPlayer. Only joint spacing changes to match reach;
	# no ancestor is stretched, so the attached leaves retain their natural proportions.
	var chord := Vector2.ZERO
	var angle: float = 0.0
	for index in range(JOINT_COUNT - 1):
		angle += _bones[index].rotation
		chord += Vector2.from_angle(angle) * REST_STEP
	var reach_vector := aimed * extension
	var length_ratio := reach_vector.length() / maxf(chord.length(), 1.0)
	for index in range(1, JOINT_COUNT):
		_bones[index].position = Vector2(REST_STEP * length_ratio, 0.0)
	var target_rotation := reach_vector.angle() - chord.angle()
	var hand_follow := _profile.hand_rotation_follow * (1.0 - smoothstep(0.25, 0.85, extension))
	skeleton.rotation = lerp_angle(target_rotation, hand_angle - _bones[0].rotation, hand_follow)
	for index in range(leaves.size()):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		leaves[index].rotation = side * (0.74 + leaf_flutter * (0.16 + index * 0.07))
	# Sheath follows the actual wrist, independently of the sweeping vine body.
	sheath.rotation = hand_angle

func chain_world_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if visible:
		for bone: Bone2D in _bones:
			points.append(bone.global_position)
	return points

func chain_length_limit() -> float:
	return _segment_length * float(JOINT_COUNT - 1)

func _hand_linked_targets(hand_direction: Vector2) -> PackedVector2Array:
	# Retain the authored sweep, but give it a true hand tangent instead of
	# rotating the whole vine toward a fixed tip while the wrist points elsewhere.
	var authored := PackedVector2Array()
	var authored_length: float = 0.0
	for bone: Bone2D in _bones:
		authored.append(to_local(bone.global_position))
	for index in range(1, authored.size()):
		authored_length += authored[index].distance_to(authored[index - 1])
	var endpoint := authored[JOINT_COUNT - 1]
	var end_direction := (endpoint - authored[JOINT_COUNT - 2]).normalized()
	var control_a := hand_direction * authored_length * 0.36
	var control_b := endpoint - end_direction * authored_length * 0.22
	var curve := PackedVector2Array()
	var distances := PackedFloat32Array([0.0])
	for index in range(37):
		var t := float(index) / 36.0
		var inverse := 1.0 - t
		var point := control_a * (3.0 * inverse * inverse * t) + control_b * (3.0 * inverse * t * t) + endpoint * t * t * t
		var sample := t * float(JOINT_COUNT - 1)
		var first := mini(int(sample), JOINT_COUNT - 2)
		var authored_point := authored[first].lerp(authored[first + 1], sample - float(first))
		point += (authored_point - endpoint * t) * sin(PI * t) * 0.5
		curve.append(to_global(point))
		if index > 0:
			distances.append(distances[index - 1] + curve[index].distance_to(curve[index - 1]))
	_segment_length = maxf(0.01, distances[36] / float(JOINT_COUNT - 1))
	var result := PackedVector2Array()
	var cursor: int = 1
	for index in range(JOINT_COUNT):
		var distance := distances[36] * float(index) / float(JOINT_COUNT - 1)
		while cursor < 36 and distances[cursor] < distance:
			cursor += 1
		var span := distances[cursor] - distances[cursor - 1]
		result.append(curve[cursor - 1].lerp(curve[cursor], (distance - distances[cursor - 1]) / maxf(span, 0.00001)))
	return result

func _apply_chain(points: PackedVector2Array) -> void:
	# Put the solved chain back into Bone2D local rotations/spacing. No bone or
	# sprite scales are changed, so mesh, nodes and leaves remain one continuous vine.
	skeleton.rotation = 0.0
	var previous_angle: float = 0.0
	for index in range(JOINT_COUNT):
		var here := to_local(points[index])
		if index == 0:
			_bones[index].position = Vector2.ZERO
		else:
			_bones[index].position = Vector2(here.distance_to(to_local(points[index - 1])), 0.0)
		var angle := (to_local(points[index + 1]) - here).angle() if index < JOINT_COUNT - 1 else previous_angle
		_bones[index].rotation = angle - previous_angle
		previous_angle = angle

func _tip_boundary_point() -> Vector2:
	var furthest := to_local(tip.global_position)
	if tip.texture == null:
		return furthest
	var texture_size := tip.texture.get_size()
	for corner: Vector2 in [Vector2.ZERO, Vector2(texture_size.x, 0.0), texture_size, Vector2(0.0, texture_size.y)]:
		var point := to_local(tip.to_global(corner + tip.offset))
		if point.x > furthest.x:
			furthest = point
	return furthest

func _record_trail() -> void:
	var shape := PackedVector2Array()
	for bone: Bone2D in _bones:
		shape.append(bone.global_position)
	_trail_shapes.push_front(shape)
	if _trail_shapes.size() > 3:
		_trail_shapes.pop_back()

func _draw() -> void:
	if not trail_enabled or _profile == null or sampled_phase < 1.0 or sampled_phase >= 2.0:
		return
	for index in range(1, _trail_shapes.size()):
		var tint := _profile.trail_color
		tint.a *= 1.0 - float(index) / 3.0
		var local_shape := PackedVector2Array()
		for world_point: Vector2 in _trail_shapes[index]:
			local_shape.append(to_local(world_point))
		draw_polyline(local_shape, tint, 1.3, true)

func _sample_parry(combat: CombatController, form_id: StringName, hand_transform: Transform2D) -> void:
	var profile := mature_profile if form_id == &"mature" else humanoid_profile
	if profile == null:
		clear_attack()
		return
	var animation_name := StringName("%s/parry" % form_id)
	var total := combat.tuning.parry_start + combat.tuning.parry_window + combat.tuning.parry_recovery
	var caught_time := combat.parry_from_progress * total
	var success := combat.state == &"parry_success"
	var clock := caught_time + combat.elapsed if success else combat.elapsed
	if profile != _profile or sampled_animation != animation_name or clock < _last_elapsed:
		clear_attack()
		_apply_profile(profile)
		sampled_animation = animation_name
	var reach := profile.parry_reach * (1.12 if form_id == &"mature" else 1.0)
	var lift := profile.parry_lift
	var age := caught_time if success else combat.elapsed
	var active_end := combat.tuning.parry_start + combat.tuning.parry_window
	var sweep_progress := smoothstep(combat.tuning.parry_start, active_end, age)
	var reveal := smoothstep(0.0, combat.tuning.parry_start, age)
	var retract := smoothstep(active_end + 0.015, total, age)
	var target := Vector2(reach * 0.68, -12).lerp(Vector2(reach * 0.78, -lift * 0.78), sweep_progress)
	var curl := lerpf(12.0, -8.0, sweep_progress)
	if success:
		# Continue from the caught curve, then drive the weapon out and up in one whip.
		var drive := smoothstep(0.0, 0.065, combat.elapsed)
		var follow := smoothstep(0.065, 0.14, combat.elapsed)
		target = target.lerp(Vector2(reach, -lift * 0.67), drive).lerp(Vector2(18, -lift), follow)
		curl = lerpf(curl, -22.0, drive) + follow * 35.0
		retract = smoothstep(0.14, combat.tuning.parry_success_duration, combat.elapsed)
	var hand_direction := Vector2(hand_transform.x.x * combat.facing, hand_transform.x.y).normalized()
	position = hand_transform.origin
	rotation = 0.0
	scale = Vector2(combat.facing, 1.0)
	z_index = 2
	var endpoint := Vector2(target.x - position.x * combat.facing, target.y - position.y)
	endpoint *= reveal * (1.0 - retract)
	var length := maxf(endpoint.length(), 0.01)
	var control_a := hand_direction * length * 0.3
	var control_b := endpoint + Vector2(curl, 14.0) * reveal * (1.0 - retract)
	var targets := PackedVector2Array()
	var arc_length: float = 0.0
	for index: int in range(JOINT_COUNT):
		var p := float(index) / float(JOINT_COUNT - 1)
		var inverse := 1.0 - p
		var local := control_a * (3.0 * inverse * inverse * p) + control_b * (3.0 * inverse * p * p) + endpoint * p * p * p
		targets.append(to_global(local))
		if index > 0:
			arc_length += targets[index].distance_to(targets[index - 1])
	_segment_length = maxf(0.01, arc_length / float(JOINT_COUNT - 1))
	var world_direction := global_transform.basis_xform(hand_direction).normalized()
	var chain: PackedVector2Array = _motion.sample(targets, world_direction, _segment_length, clock, profile)
	_apply_chain(chain)
	sheath.rotation = hand_direction.angle()
	for index: int in range(leaves.size()):
		leaves[index].rotation = (-1.0 if index % 2 == 0 else 1.0) * (0.72 + sin(sweep_progress * PI + index * 0.7) * 0.22)
	visible = reveal > 0.01 and retract < 0.985
	modulate.a = reveal * (1.0 - smoothstep(0.5, 1.0, retract))
	tip_position = transform * _tip_boundary_point()
	parry_contact_position = get_parent().to_local(chain[4])
	sampled_phase = 1.5 if retract < 0.1 else 2.0
	# The solid vine carries the deflection silhouette without luminous afterimages.
	_trail_shapes.clear()
	_last_elapsed = clock
	queue_redraw()
