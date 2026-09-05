class_name WalkSoundTest
extends Node2D
## Isolated integration scene: movement requests a footstep, the emitter plays it.

@onready var walker: WalkTestActor = %Walker
@onready var footstep_player: SoundEmitter = %FootstepPlayer
@onready var status_label: Label = %StatusLabel
@onready var count_label: Label = %CountLabel

var _footstep_count: int = 0


func _ready() -> void:
	walker.footstep_requested.connect(_on_footstep_requested)
	footstep_player.cue_played.connect(_on_cue_played)
	status_label.text = "状态：等待移动"


func _on_footstep_requested(cue: StringName) -> void:
	footstep_player.play_cue(cue)


func _on_cue_played(cue: StringName) -> void:
	if cue != &"step_grass":
		return
	_footstep_count += 1
	count_label.text = "已播放脚步：%d" % _footstep_count
	status_label.text = "状态：正在播放 %s（变体轮换 + 固定通道池）" % cue

