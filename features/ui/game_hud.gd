class_name GameHud
extends Control
## Read-only HUD shared by the JSON course and the older sandbox.

const LEVER_OFF: Texture2D = preload("res://assets/runtime/ui/lever_off.png")
const LEVER_ON: Texture2D = preload("res://assets/runtime/ui/lever_on.png")

@onready var form_label: Label = %FormLabel
@onready var growth_label: Label = %GrowthLabel
@onready var growth_bar: ProgressBar = %GrowthBar
@onready var stability_label: Label = %StabilityLabel
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var state_label: Label = %StateLabel
@onready var controls_label: Label = %ControlsLabel
@onready var message_label: Label = %MessageLabel
@onready var context_label: Label = %ContextLabel
@onready var ability_hint: Label = %AbilityHint
@onready var time_label: Label = %TimeLabel
@onready var deaths_label: Label = %DeathsLabel
@onready var objective_icon: TextureRect = %ObjectiveIcon

var _player: Player
var _level: Node
var _message_remaining: float = 0.0
var _feedback: String = ""
var _toxin_active: bool = false
var _stability_fill: StyleBoxFlat


func _ready() -> void:
	# The HUD must never consume the gameplay mouse click beneath it.
	_ignore_mouse(self)
	_stability_fill = stability_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	stability_bar.add_theme_stylebox_override("fill", _stability_fill)


func bind_player(player: Player, level: Node = null) -> void:
	_unbind()
	_player = player
	_level = level
	if not is_instance_valid(player):
		return
	player.resources.values_changed.connect(_on_values_changed)
	player.resources.toxin_changed.connect(_on_toxin_changed)
	player.form_controller.form_changed.connect(_on_form_changed)
	player.abilities.feedback_requested.connect(show_message)
	if is_instance_valid(level):
		if level.has_signal(&"checkpoint_changed"):
			level.connect(&"checkpoint_changed", _on_checkpoint_changed)
		if level.has_signal(&"completion_changed"):
			level.connect(&"completion_changed", _on_completion_changed)
	_on_form_changed(player.current_form_id())


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_message_remaining = maxf(0.0, _message_remaining - delta)
	var activity := "自由行动"
	if _player.abilities.is_leg_extended():
		activity = "伸腿推进"
	elif _player.abilities.is_rooted():
		activity = "扎根抗风"
	elif _player.abilities.is_vine_attached():
		activity = "翻越圆环" if _player.movement.is_vine_climbing() else "藤蔓摆荡"
	state_label.text = activity
	if _player.requires_absorption_release():
		context_label.text = "本轮吸收已完成 · 松开 E，再按住继续吸收"
	elif _message_remaining > 0.0:
		context_label.text = _feedback
	elif _toxin_active:
		context_label.text = "毒雾正在消耗稳定度 · 离开毒雾可逐渐恢复"
	else:
		context_label.text = "触碰按钮启动机关 · 抵达旗帜记录重试位置"
	if is_instance_valid(_level) and _level.has_method(&"elapsed_time"):
		var seconds := float(_level.call(&"elapsed_time"))
		var total := maxi(0, int(seconds))
		time_label.text = "%02d:%02d" % [floori(total / 60.0), total % 60]
		if _level.has_method(&"death_count"):
			deaths_label.text = "重试 %d" % int(_level.call(&"death_count"))


func set_objective(text: String, unlocked: bool = false) -> void:
	message_label.text = text
	objective_icon.texture = LEVER_ON if unlocked else LEVER_OFF


func show_message(message: String) -> void:
	_feedback = message
	_message_remaining = 3.5
	context_label.text = message


func _on_values_changed(growth: float, threshold: float, stability: float) -> void:
	growth_bar.max_value = maxf(1.0, threshold)
	growth_bar.value = 1.0 if threshold <= 0.0 else growth
	growth_label.text = "成长  已成熟" if threshold <= 0.0 else "成长  %.0f / %.0f" % [growth, threshold]
	stability_bar.value = stability
	stability_label.text = "稳定  %.0f / 100" % stability
	if _stability_fill != null:
		_stability_fill.bg_color = Color("#ef795f") if stability <= 30.0 else Color("#edb566")


func _on_form_changed(form_id: StringName) -> void:
	var display := "幼芽期"
	var hint := "幼芽：不可跳跃 · 可以穿过狭窄通道，吸收营养液后成长"
	match form_id:
		&"humanoid":
			display = "人形期"
			hint = "人形：左键 扎根 / 拔根 · 扎根后 WASD 伸腿推进"
		&"mature":
			display = "成熟期"
			hint = "成熟：左键沿鼠标方向接 / 断藤蔓 · 连环后 E 上环 · 下落按住空格滑翔"
	form_label.text = display
	ability_hint.text = hint
	var form := _player.form_controller.get_current()
	controls_label.text = "A / D 移动    按住 E 吸收液体    R 重开"
	if form.can_jump:
		controls_label.text = "A / D 移动    空格 跳跃    按住 E 吸收液体    R 重开"
	_on_values_changed(_player.resources.growth_progress, form.growth_threshold, _player.resources.stability)


func _on_toxin_changed(active: bool) -> void:
	_toxin_active = active


func _on_checkpoint_changed(_checkpoint_id: StringName) -> void:
	show_message("检查点已记录 · 失误后从这里继续")


func _on_completion_changed(completed: bool, seconds: float) -> void:
	if completed:
		set_objective("关卡完成 · 已抵达出口", true)
		show_message("探索完成，用时 %.1f 秒" % seconds)


func _unbind() -> void:
	if is_instance_valid(_player):
		_disconnect(_player.resources, &"values_changed", _on_values_changed)
		_disconnect(_player.resources, &"toxin_changed", _on_toxin_changed)
		_disconnect(_player.form_controller, &"form_changed", _on_form_changed)
		_disconnect(_player.abilities, &"feedback_requested", show_message)
	if is_instance_valid(_level):
		_disconnect(_level, &"checkpoint_changed", _on_checkpoint_changed)
		_disconnect(_level, &"completion_changed", _on_completion_changed)


func _disconnect(source: Object, event: StringName, callback: Callable) -> void:
	if is_instance_valid(source) and source.has_signal(event) and source.is_connected(event, callback):
		source.disconnect(event, callback)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
