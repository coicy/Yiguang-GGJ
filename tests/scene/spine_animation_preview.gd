extends Node2D
## F6 preview that cycles through every imported Spine animation.

const PART1_ANIMATIONS: Array[StringName] = [&"idle", &"move", &"death"]
const PART2_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"move",
	&"jump_start",
	&"jump_up",
	&"jump_down",
	&"jump_end",
	&"skill",
	&"death",
]
const PART3_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"move",
	&"jump_start",
	&"jump_up",
	&"jump_down",
	&"jump_end",
	&"skill",
	&"death",
]
const LOOPING_ANIMATIONS: Array[StringName] = [&"idle", &"move"]

@onready var part1_visual: Node = %Part1Visual
@onready var part2_visual: Node = %Part2Visual
@onready var part3_visual: Node = %Part3Visual
@onready var part1_label: Label = %Part1AnimationLabel
@onready var part2_label: Label = %Part2AnimationLabel
@onready var part3_label: Label = %Part3AnimationLabel

var _animation_index: int = 0


func _ready() -> void:
	_show_current_animations()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_advance_animations()


func _advance_animations() -> void:
	_animation_index += 1
	_show_current_animations()


func _show_current_animations() -> void:
	var part1_animation: StringName = PART1_ANIMATIONS[_animation_index % PART1_ANIMATIONS.size()]
	var part2_animation: StringName = PART2_ANIMATIONS[_animation_index % PART2_ANIMATIONS.size()]
	var part3_animation: StringName = PART3_ANIMATIONS[_animation_index % PART3_ANIMATIONS.size()]
	part1_visual.play_animation(part1_animation, LOOPING_ANIMATIONS.has(part1_animation))
	part2_visual.play_animation(part2_animation, LOOPING_ANIMATIONS.has(part2_animation))
	part3_visual.play_animation(part3_animation, LOOPING_ANIMATIONS.has(part3_animation))
	part1_label.text = "part1 · %s" % part1_animation
	part2_label.text = "part2 · %s" % part2_animation
	part3_label.text = "part3 · %s" % part3_animation
