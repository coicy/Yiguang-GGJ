class_name SpineCharacterVisual
extends Node2D
## Reusable presentation wrapper around a SpineSprite and its animation state.

signal animation_changed(animation_name: StringName)
signal animation_completed(animation_name: StringName)
signal animation_event_emitted(event_name: StringName)

@export var default_animation: StringName = &"idle"
@export var supported_animations: Array[StringName] = []
@export var looping_animations: Array[StringName] = [&"idle", &"move"]
@export_group("Glide Leaf Rig")
@export var glide_left_leaf_bones: Array[StringName] = []
@export var glide_right_leaf_bones: Array[StringName] = []
@export var glide_open_rotations: Array[float] = [58.0, -14.0, 9.0]
@export var glide_sway_degrees: float = 3.0
@export var glide_sway_speed: float = 3.5
@export var glide_blend_speed: float = 6.0

@onready var spine_sprite: SpineSprite = %SpineSprite

var _current_animation: StringName = &""
var _gliding: bool = false
var _glide_blend: float = 0.0
var _glide_time: float = 0.0
var _glide_needs_reset: bool = false
var _leaf_setup_transforms: Dictionary[StringName, Transform2D] = {}


func _ready() -> void:
	spine_sprite.animation_completed.connect(_on_spine_animation_completed)
	spine_sprite.animation_event.connect(_on_spine_animation_event)
	spine_sprite.before_world_transforms_change.connect(_on_before_world_transforms_change)
	_cache_leaf_setup_transforms()
	if not default_animation.is_empty():
		play_animation(default_animation, looping_animations.has(default_animation))


func _process(delta: float) -> void:
	if _gliding:
		_glide_time += delta
	var target := 1.0 if _gliding else 0.0
	var previous_blend := _glide_blend
	_glide_blend = move_toward(_glide_blend, target, glide_blend_speed * delta)
	if previous_blend > 0.0 and is_zero_approx(_glide_blend):
		_glide_needs_reset = true


func play_animation(animation_name: StringName, loop: bool = false) -> bool:
	if not has_animation(animation_name):
		push_warning("Spine animation '%s' is unavailable on %s." % [animation_name, name])
		return false
	var track_entry: Object = spine_sprite.get_animation_state().set_animation(animation_name, loop, 0)
	if track_entry == null:
		return false
	_current_animation = animation_name
	animation_changed.emit(animation_name)
	return true


func play_default() -> bool:
	return play_animation(default_animation, looping_animations.has(default_animation))


func has_animation(animation_name: StringName) -> bool:
	if not supported_animations.has(animation_name):
		return false
	var skeleton: Object = spine_sprite.get_skeleton()
	if skeleton == null:
		return false
	var skeleton_data: Object = skeleton.get_data()
	return skeleton_data != null and skeleton_data.find_animation(animation_name) != null


func current_animation() -> StringName:
	return _current_animation


func set_gliding(active: bool) -> void:
	if active == _gliding:
		return
	_gliding = active
	if active:
		_glide_time = 0.0
	else:
		_glide_needs_reset = true


func is_gliding() -> bool:
	return _gliding


func set_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
	spine_sprite.scale.x = absf(spine_sprite.scale.x) * signf(direction)


func _cache_leaf_setup_transforms() -> void:
	_leaf_setup_transforms.clear()
	var skeleton: Object = spine_sprite.get_skeleton()
	if skeleton == null:
		return
	for bone_name: StringName in glide_left_leaf_bones + glide_right_leaf_bones:
		var bone: Object = skeleton.find_bone(bone_name)
		if bone != null:
			_leaf_setup_transforms[bone_name] = bone.get_transform()


func _on_before_world_transforms_change(_sprite: SpineSprite) -> void:
	if _leaf_setup_transforms.is_empty():
		return
	if _glide_blend <= 0.0 and not _glide_needs_reset:
		return
	var eased_blend := smoothstep(0.0, 1.0, _glide_blend)
	_apply_leaf_chain(glide_left_leaf_bones, -1.0, eased_blend)
	_apply_leaf_chain(glide_right_leaf_bones, 1.0, eased_blend)
	if is_zero_approx(_glide_blend):
		_glide_needs_reset = false


func _apply_leaf_chain(bone_names: Array[StringName], side: float, blend: float) -> void:
	var skeleton: Object = spine_sprite.get_skeleton()
	for index in range(bone_names.size()):
		var bone_name := bone_names[index]
		if not _leaf_setup_transforms.has(bone_name):
			continue
		var setup: Transform2D = _leaf_setup_transforms[bone_name]
		var open_degrees := glide_open_rotations[index] if index < glide_open_rotations.size() else 0.0
		var sway := sin(_glide_time * glide_sway_speed + index * 0.8) * glide_sway_degrees
		var rotation_offset := deg_to_rad((open_degrees * side + sway * side) * blend)
		var animated := Transform2D(
			setup.get_rotation() + rotation_offset,
			setup.get_scale(),
			setup.get_skew(),
			setup.origin
		)
		var bone: Object = skeleton.find_bone(bone_name)
		if bone != null:
			bone.set_transform(animated)


func _on_spine_animation_completed(
	_sprite: SpineSprite,
	_animation_state: Object,
	_track_entry: Object
) -> void:
	animation_completed.emit(_current_animation)


func _on_spine_animation_event(
	_sprite: SpineSprite,
	_animation_state: Object,
	_track_entry: Object,
	event: Object
) -> void:
	if event == null or event.get_data() == null:
		return
	animation_event_emitted.emit(StringName(event.get_data().get_event_name()))
