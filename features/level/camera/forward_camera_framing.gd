class_name ForwardCameraFraming
extends Node
## Owns framing and smoothing; only PhantomCameraHost writes the real camera.
## Runs after player physics (0) and before the host (300).

const CameraRegion = preload("res://features/level/camera/camera_region_2d.gd")

@export var regions_enabled: bool = true
@export_range(0.0, 0.5, 0.01, "suffix:s") var region_transition_time: float = 0.12
@export_range(200.0, 1400.0, 10.0) var region_pan_speed: float = 600.0
@export_range(32.0, 192.0, 1.0) var region_approach_distance: float = 96.0
@export_range(0.1, 0.4, 0.01) var rising_top_ratio: float = 0.2

@export_range(0.5, 0.9, 0.01) var front_view_ratio: float = 0.8
@export_range(0.2, 0.7, 0.01) var vertical_player_ratio: float = 0.45
@export_range(0.0, 1.0, 0.01, "suffix:s") var turn_smoothing_time: float = 0.16
@export_range(0.0, 0.5, 0.01, "suffix:s") var turn_confirmation_time: float = 0.1
@export_range(0.0, 0.5, 0.01, "suffix:s") var vertical_smoothing_time: float = 0.05
@export_range(0.5, 0.9, 0.01) var falling_player_max_ratio: float = 0.8
@export_range(0.0, 1.0, 0.05) var intent_dead_zone: float = 0.1
@export_range(0.0, 32.0, 0.5, "suffix:px") var floor_contact_tolerance: float = 2.0
@export_range(0.0, 64.0, 1.0, "suffix:px") var spawn_floor_probe_distance: float = 32.0

@onready var _player: Player = %Player
@onready var _phantom_camera: PhantomCamera2D = %PhantomCamera2D
@onready var _camera: Camera2D = %Camera2D

var _facing: float = 1.0
var _look_direction: float = 1.0
var _pending_direction: float = 0.0
var _pending_time: float = 0.0
var _camera_center := Vector2.ZERO
var _last_player_position := Vector2.ZERO
var _main_floors: Array[TerrainPiece] = []
var _active_main_floor: TerrainPiece
var _initialized: bool = false
var _bounds_warning_reported: bool = false
var _regions: Array[CameraRegion] = []
var _active_region: CameraRegion
var _region_limits := Vector2.ZERO
var _center_weight: float = 0.0
var _region_anchor_x: float = 0.0
var _authored_top: int = -10000000
var _fall_ratio_limit: float = 0.8


func _ready() -> void:
	# The level initializes us after its children and camera limits are ready.
	_phantom_camera.follow_damping = false
	_phantom_camera.lookahead = false
	_phantom_camera.tween_on_load = false


func _physics_process(delta: float) -> void:
	if not _initialized:
		reset_for_respawn()
	var motion: Vector2 = _player.global_position - _last_player_position
	_last_player_position = _player.global_position
	_update_direction(delta)
	var body: Rect2 = _player.get_camera_body_rect()
	var visible_size: Vector2 = _visible_size()
	if regions_enabled and not _regions.is_empty():
		_update_region(body, motion, delta)
		_keep_high_player_visible(body, visible_size)
	else:
		_active_region = null
		_update_main_floor(body, motion)
	var desired: Vector2 = _desired_center(visible_size)
	if regions_enabled and not _regions.is_empty():
		desired = _region_desired_center(desired, visible_size, body, motion)
		var near_floor: bool = is_instance_valid(_active_main_floor) \
			and _active_main_floor.get_camera_floor_rect().position.y - body.end.y < 16.0
		_fall_ratio_limit = 1.0 if near_floor else move_toward(_fall_ratio_limit, falling_player_max_ratio, delta * 2.0)
		_camera_center.x = move_toward(_camera_center.x, desired.x, maxf(region_pan_speed * delta, absf(motion.x)))
		var smooth_y: float = lerpf(_camera_center.y, desired.y, _weight(delta, vertical_smoothing_time))
		_camera_center.y = move_toward(_camera_center.y, smooth_y, maxf(region_pan_speed * delta, absf(motion.y)))
	else:
		_camera_center.x = desired.x
		_camera_center.y = lerpf(_camera_center.y, desired.y, _weight(delta, vertical_smoothing_time))
	_camera_center = _constrain_center(_camera_center, visible_size, body, motion.y > 0.0)
	_publish_center()


func reset_for_respawn(direction: float = 1.0) -> void:
	_facing = -1.0 if direction < 0.0 else 1.0
	_look_direction = _facing
	_pending_direction = 0.0
	_pending_time = 0.0
	_last_player_position = _player.global_position
	if not _initialized:
		_authored_top = _phantom_camera.limit_top
	_main_floors.clear()
	for node: Node in get_tree().get_nodes_in_group(&"camera_main_floors"):
		if node is TerrainPiece and get_parent().is_ancestor_of(node):
			_main_floors.append(node as TerrainPiece)
	_regions.clear()
	for node: Node in get_tree().get_nodes_in_group(&"camera_regions"):
		if node is CameraRegion and get_parent().is_ancestor_of(node):
			_regions.append(node as CameraRegion)
	var body: Rect2 = _player.get_camera_body_rect()
	var visible_size: Vector2 = _visible_size()
	var desired: Vector2 = _desired_center(visible_size)
	if regions_enabled and not _regions.is_empty():
		_update_region(body, Vector2.ZERO, 0.0, true)
		_keep_high_player_visible(body, visible_size)
		desired = _region_desired_center(desired, visible_size, body, Vector2.ZERO)
	else:
		_active_region = null
		_active_main_floor = _find_spawn_floor(body)
	_camera_center = _constrain_center(desired, visible_size, body, false)
	_fall_ratio_limit = 1.0 if is_instance_valid(_active_main_floor) else falling_player_max_ratio
	_publish_center()
	_initialized = true
	_phantom_camera.teleport_position()
	# In Phantom Camera 0.11 teleport updates output but leaves the raw Node2D
	# position behind. FRAMED would otherwise apply the same displacement twice.
	_phantom_camera.global_position = _camera_center


func get_facing_direction() -> float:
	return _facing


func get_active_main_floor() -> TerrainPiece:
	return _active_main_floor if is_instance_valid(_active_main_floor) else null


func get_active_region() -> CameraRegion:
	return _active_region if is_instance_valid(_active_region) else null


func _update_region(body: Rect2, motion: Vector2, delta: float, snap: bool = false) -> void:
	var feet := Vector2(_player.global_position.x, body.end.y)
	var selected: CameraRegion
	for region: CameraRegion in _regions:
		if not region.contains_feet(feet):
			continue
		if region.drop_connection and not _can_drop_through(region, body, motion):
			continue
		if selected == null or region.priority > selected.priority:
			selected = region
	_active_region = selected
	_active_main_floor = selected.get_floor(feet) if selected != null else null
	if is_instance_valid(_active_main_floor):
		# Room membership is independent of past contacts; its floor stops being
		# a display barrier once the body has actually crossed below its surface.
		var rect: Rect2 = _active_main_floor.get_camera_floor_rect()
		if body.end.y > rect.position.y + 0.05:
			_active_main_floor = null
	var limits := Vector2(_phantom_camera.limit_left, _phantom_camera.limit_right)
	var center_target: float = 0.0
	var anchor: float = _player.global_position.x
	if selected != null:
		limits = selected.get_horizontal_limits()
		center_target = 1.0 if selected.center_horizontal else 0.0
		anchor = selected.get_world_rect().get_center().x
	# Begin closing a neighbouring room's edges before reaching its doorway.
	# At faster travel speeds the approach band grows with the transition time.
	var approach: float = maxf(region_approach_distance, _player.velocity.length() * region_transition_time * 3.0)
	for next: CameraRegion in _regions:
		# Do not preview an outer, lower-priority room while still inside a
		# guarded connector: its opening edges can conflict with the real wall.
		if next == selected or next.drop_connection or (selected != null and next.priority <= selected.priority):
			continue
		var area: Rect2 = next.get_world_rect()
		var distance: float = INF
		if feet.x >= area.position.x and feet.x <= area.end.x:
			if motion.y * (area.get_center().y - feet.y) <= 0.0:
				continue
			distance = maxf(area.position.y - feet.y, feet.y - area.end.y)
		elif feet.y >= area.position.y and feet.y <= area.end.y:
			if motion.x * (area.get_center().x - feet.x) <= 0.0:
				continue
			distance = maxf(area.position.x - feet.x, feet.x - area.end.x)
		if distance <= 0.0 or distance >= approach:
			continue
		var influence: float = 1.0 - smoothstep(0.0, approach, distance)
		limits = limits.lerp(next.get_horizontal_limits(), influence)
		center_target = lerpf(center_target, 1.0 if next.center_horizontal else 0.0, influence)
		anchor = lerpf(anchor, area.get_center().x, influence)
	var weight: float = 1.0 if snap else _weight(delta, region_transition_time)
	# Blend display bounds as well as framing, so adjacent rooms do not cause
	# a one-tick pan. Respawn resolves the destination immediately.
	var blended: Vector2 = _region_limits.lerp(limits, weight)
	var budget: float = INF if snap else region_pan_speed * delta
	_region_limits.x = move_toward(_region_limits.x, blended.x, budget)
	_region_limits.y = move_toward(_region_limits.y, blended.y, budget)
	_center_weight = lerpf(_center_weight, center_target, weight)
	_region_anchor_x = move_toward(_region_anchor_x, lerpf(_region_anchor_x, anchor, weight), budget)


func _can_drop_through(region: CameraRegion, body: Rect2, motion: Vector2) -> bool:
	var floor_piece: TerrainPiece = region.get_transition_floor()
	if floor_piece == null:
		return false
	var surface: float = floor_piece.get_camera_floor_rect().position.y
	if body.end.y > surface + 0.05:
		return true
	var opening: Rect2 = region.get_world_rect()
	if motion.y <= 0.0 or _player.is_on_floor() \
			or body.position.x <= opening.position.x or body.end.x >= opening.end.x:
		return false
	# Test real World collision, including the moving cube. A button signal or
	# the authored gap rectangle alone does not mean the opening is passable.
	for x: float in [body.position.x + 1.0, body.get_center().x, body.end.x - 1.0]:
		var query := PhysicsRayQueryParameters2D.create(
			Vector2(x, body.end.y - 0.5), Vector2(x, surface + 4.0), 1, [_player.get_rid()]
		)
		query.hit_from_inside = true
		if not _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _region_desired_center(desired: Vector2, visible_size: Vector2, body: Rect2, motion: Vector2) -> Vector2:
	desired.x = lerpf(desired.x, _region_anchor_x, _center_weight)
	if motion.y < -0.01:
		# A short jump can use the room's headroom; sustained climbing tracks
		# before the body reaches the top/HUD instead of following every bob.
		desired.y = minf(_camera_center.y, body.position.y + visible_size.y * (0.5 - rising_top_ratio))
	# Approach a neighbouring floor before touching it. This also handles
	# entering an upper room from a floating platform instead of its ground.
	for region: CameraRegion in _regions:
		if region.drop_connection:
			continue
		var feet := Vector2(_player.global_position.x, body.end.y)
		var floor_piece: TerrainPiece = region.get_floor(feet)
		if floor_piece == null:
			continue
		var surface: float = floor_piece.get_camera_floor_rect().position.y
		if body.end.y > surface:
			continue
		var area: Rect2 = region.get_world_rect()
		if feet.y < area.position.y or feet.y > area.end.y:
			continue
		var distance: float = maxf(area.position.x - feet.x, feet.x - area.end.x)
		if distance > 0.0 and distance < region_approach_distance:
			var influence: float = 1.0 - smoothstep(0.0, region_approach_distance, distance)
			desired.y = lerpf(desired.y, minf(desired.y, surface - visible_size.y * 0.5), influence)
	if _active_region != null and not _active_region.drop_connection:
		var entry_floor: TerrainPiece = _active_region.get_transition_floor()
		if entry_floor != null and motion.y <= 0.0:
			var surface: float = entry_floor.get_camera_floor_rect().position.y
			var distance: float = maxf(0.0, body.end.y - surface)
			var influence: float = 1.0 - smoothstep(0.0, _active_region.transition_height, distance)
			var entry_center: float = maxf(surface, body.end.y) - visible_size.y * 0.5
			desired.y = lerpf(desired.y, minf(desired.y, entry_center), influence)
	return desired


func _keep_high_player_visible(body: Rect2, visible_size: Vector2) -> void:
	# An edited anchor above the authored world must not lose the player. This
	# changes only the runtime top safety limit; the level's geometry stays put.
	var safety_top: int = mini(_authored_top, floori(body.position.y - visible_size.y * rising_top_ratio))
	if _phantom_camera.limit_top != safety_top:
		_phantom_camera.limit_top = safety_top
		_camera.limit_top = safety_top


func _update_direction(delta: float) -> void:
	var intent: float = _player.get_camera_intent().x
	var direction: float = signf(intent) if absf(intent) > intent_dead_zone else 0.0
	if is_zero_approx(direction) or direction == _facing:
		_pending_direction = 0.0
		_pending_time = 0.0
	else:
		if direction != _pending_direction:
			_pending_direction = direction
			_pending_time = 0.0
		_pending_time += delta
		if _pending_time >= turn_confirmation_time:
			_facing = direction
			_pending_direction = 0.0
			_pending_time = 0.0
	_look_direction = lerpf(_look_direction, _facing, _weight(delta, turn_smoothing_time))


func _update_main_floor(body: Rect2, motion: Vector2) -> void:
	# Only an actual upward supporting collision establishes a new floor.
	if _player.is_on_floor():
		for index: int in range(_player.get_slide_collision_count()):
			var collision: KinematicCollision2D = _player.get_slide_collision(index)
			var floor_piece := collision.get_collider() as TerrainPiece
			if floor_piece == null or not _main_floors.has(floor_piece):
				continue
			var rect: Rect2 = floor_piece.get_camera_floor_rect()
			if rect.has_area() and collision.get_normal().dot(Vector2.UP) >= 0.7 \
					and absf(body.end.y - rect.position.y) <= floor_contact_tolerance:
				_active_main_floor = floor_piece
				return
	if not is_instance_valid(_active_main_floor):
		_active_main_floor = null
		return
	var active_rect: Rect2 = _active_main_floor.get_camera_floor_rect()
	if not active_rect.has_area() or body.end.y > active_rect.position.y + floor_contact_tolerance:
		_active_main_floor = null
		return
	# Keep the floor through an ordinary jump and on floating platforms. A real
	# gap has no support from ANY same-height segment, including Ground13/14.
	if motion.y > 0.0 and not _has_support_at_height(body, active_rect.position.y):
		_active_main_floor = null


func _has_support_at_height(body: Rect2, surface_y: float) -> bool:
	for floor_piece: TerrainPiece in _main_floors:
		if not is_instance_valid(floor_piece):
			continue
		var rect: Rect2 = floor_piece.get_camera_floor_rect()
		if rect.has_area() and absf(rect.position.y - surface_y) <= floor_contact_tolerance \
				and _overlaps_x(body, rect):
			return true
	return false


func _find_spawn_floor(body: Rect2) -> TerrainPiece:
	var nearest: TerrainPiece
	var nearest_distance: float = spawn_floor_probe_distance
	for floor_piece: TerrainPiece in _main_floors:
		if not is_instance_valid(floor_piece):
			continue
		var rect: Rect2 = floor_piece.get_camera_floor_rect()
		if not rect.has_area() or not _overlaps_x(body, rect):
			continue
		var distance: float = rect.position.y - body.end.y
		if distance >= -floor_contact_tolerance and distance <= nearest_distance:
			nearest = floor_piece
			nearest_distance = distance
	return nearest


func _constrain_center(center: Vector2, visible_size: Vector2, body: Rect2, falling: bool) -> Vector2:
	var half: Vector2 = visible_size * 0.5
	var minimum := Vector2(_phantom_camera.limit_left, _phantom_camera.limit_top) + half
	var maximum := Vector2(_phantom_camera.limit_right, _phantom_camera.limit_bottom) - half
	if regions_enabled and not _regions.is_empty():
		# Widen a region around the player on a larger viewport rather than
		# constructing an impossible rectangle narrower than the screen.
		var extra: float = maxf(0.0, visible_size.x - (_region_limits.y - _region_limits.x)) * 0.5
		var left: float = _region_limits.x - extra
		var right: float = _region_limits.y + extra
		minimum.x = maxf(minimum.x, left + half.x)
		maximum.x = minf(maximum.x, right - half.x)
		if _active_region != null and _active_region.guards_horizontal(Vector2(_player.global_position.x, body.end.y)):
			var guard: Vector2 = _active_region.get_horizontal_limits()
			if guard.y - guard.x >= visible_size.x:
				minimum.x = maxf(minimum.x, guard.x + half.x)
				maximum.x = minf(maximum.x, guard.y - half.x)
	if is_instance_valid(_active_main_floor):
		maximum.y = minf(maximum.y, _active_main_floor.get_camera_floor_rect().position.y - half.y)
	# The body constraint is independent of the player origin, which is at its feet.
	var safe_minimum: Vector2 = body.end - half
	var safe_maximum: Vector2 = body.position + half
	for axis: int in range(2):
		if minimum[axis] > maximum[axis]:
			_report_bounds_conflict()
			center[axis] = maximum[axis]
			continue
		var safe_low: float = maxf(minimum[axis], safe_minimum[axis])
		var safe_high: float = minf(maximum[axis], safe_maximum[axis])
		if safe_low <= safe_high:
			if axis == 1 and falling and (regions_enabled or not is_instance_valid(_active_main_floor)):
				var ratio: float = _fall_ratio_limit if regions_enabled else falling_player_max_ratio
				var fall_minimum: float = _player.global_position.y - visible_size.y * (ratio - 0.5)
				# The world edge may relax the 80% fall ratio, never body visibility.
				safe_low = maxf(safe_low, minf(fall_minimum, safe_high))
			center[axis] = clampf(center[axis], safe_low, safe_high)
		else:
			# World edges may relax composition; never chase an out-of-bounds body.
			# Falling into an authored recovery area outside the camera world is
			# expected. A standing body or an in-world body that cannot fit is not.
			var world_rect := Rect2(
				Vector2(_phantom_camera.limit_left, _phantom_camera.limit_top),
				Vector2(_phantom_camera.limit_right - _phantom_camera.limit_left, _phantom_camera.limit_bottom - _phantom_camera.limit_top)
			)
			if _player.is_on_floor() or world_rect.has_point(body.get_center()):
				_report_bounds_conflict()
			center[axis] = clampf(center[axis], minimum[axis], maximum[axis])
	return center


func _report_bounds_conflict() -> void:
	if not _bounds_warning_reported:
		push_warning("CameraBounds must contain the player body and a full viewport above each main floor at the selected zoom.")
		_bounds_warning_reported = true


func _desired_center(visible_size: Vector2) -> Vector2:
	return _player.global_position + Vector2(
		visible_size.x * (front_view_ratio - 0.5) * _look_direction,
		visible_size.y * (0.5 - vertical_player_ratio)
	)


func _visible_size() -> Vector2:
	return _phantom_camera.get_viewport_rect().size / _phantom_camera.zoom.max(Vector2(0.001, 0.001))


func _publish_center() -> void:
	_phantom_camera.follow_offset = _camera_center - _player.global_position


func _weight(delta: float, smoothing_time: float) -> float:
	return 1.0 if smoothing_time <= 0.0 else 1.0 - exp(-delta / smoothing_time)


func _overlaps_x(body: Rect2, floor_rect: Rect2) -> bool:
	return body.end.x > floor_rect.position.x and body.position.x < floor_rect.end.x

