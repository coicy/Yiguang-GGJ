class_name CompletionOverlay
extends Control

@onready var result_label: Label = %ResultLabel


func show_completion(seconds: float) -> void:
	visible = true
	result_label.text = "白模关卡完成\n用时 %.1f 秒\n\n按 R 重新开始" % seconds


func hide_completion() -> void:
	visible = false
