class_name GameHud
extends Control
## Read-only presentation of player and level state.

@onready var form_label: Label = %FormLabel
@onready var growth_label: Label = %GrowthLabel
@onready var growth_bar: ProgressBar = %GrowthBar
@onready var stability_label: Label = %StabilityLabel
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var state_label: Label = %StateLabel
@onready var controls_label: Label = %ControlsLabel
@onready var message_label: Label = %MessageLabel

var _player: Player
var _level: WhiteboxSandbox


func bind_player(player: Player, level: WhiteboxSandbox) -> void:
	_player = player
	_level = level
	player.resources.values_changed.connect(_on_values_changed)
	player.form_controller.form_changed.connect(_on_form_changed)
	player.abilities.ability_state_changed.connect(_on_ability_state_changed)
	player.abilities.feedback_requested.connect(show_message)
	level.checkpoint_changed.connect(_on_checkpoint_changed)
	level.completion_changed.connect(_on_completion_changed)
	_refresh_all()


func _process(_delta: float) -> void:
	if _player == null:
		return
	var ability := "自由"
	if _player.abilities.is_rooted():
		ability = "扎根抗风"
	elif _player.abilities.is_leg_extended():
		ability = "伸腿推进"
	elif _player.abilities.is_vine_attached():
		ability = "藤蔓摆荡"
	state_label.text = "状态：%s · %s" % [_player.current_state(), ability]


func show_message(message: String) -> void:
	message_label.text = message


func _refresh_all() -> void:
	_on_form_changed(_player.current_form_id())
	var form := _player.form_controller.get_current()
	_on_values_changed(_player.resources.growth_progress, form.growth_threshold, _player.resources.stability)
	_on_ability_state_changed(&"none")


func _on_values_changed(growth: float, threshold: float, stability: float) -> void:
	growth_bar.max_value = maxf(1.0, threshold)
	growth_bar.value = growth
	growth_label.text = "成长：已成熟" if threshold <= 0.0 else "成长：%.0f / %.0f" % [growth, threshold]
	stability_bar.value = stability
	stability_label.text = "稳定度：%.0f / 100" % stability


func _on_form_changed(form_id: StringName) -> void:
	var display := "幼芽体"
	var controls := "A/D 移动 · 空格 跳跃 · R 重开"
	match form_id:
		&"humanoid":
			display = "人形体"
			controls += " · 左键扎根/拔根 · 扎根后 WASD 正交伸腿推进 · 按住 E 吸取液体"
		&"mature":
			display = "成熟体"
			controls += " · 左键连接/断开藤蔓 · 按住 E 吸取液体 · 下落按住空格滑翔"
	form_label.text = "形态：%s" % display
	controls_label.text = controls


func _on_ability_state_changed(_ability: StringName) -> void:
	queue_redraw()


func _on_checkpoint_changed(checkpoint_id: StringName) -> void:
	show_message("检查点已记录：%s" % checkpoint_id)


func _on_completion_changed(completed: bool, seconds: float) -> void:
	if completed:
		show_message("已完成！用时 %.1f 秒" % seconds)
