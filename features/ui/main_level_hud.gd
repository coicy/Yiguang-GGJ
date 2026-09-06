class_name MainLevelHud
extends Control
## Read-only presentation for the hand-built exploration level.

const FORM_COLORS: Dictionary = {
	&"sprout": Color("b8d78c"),
	&"humanoid": Color("ead197"),
	&"mature": Color("91d6c8"),
}

@onready var form_label: Label = %FormLabel
@onready var state_label: Label = %StateLabel
@onready var growth_label: Label = %GrowthLabel
@onready var growth_bar: ProgressBar = %GrowthBar
@onready var stability_label: Label = %StabilityLabel
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var controls_label: Label = %ControlsLabel
@onready var ability_hint: Label = %AbilityHint
@onready var context_label: Label = %ContextLabel
@onready var time_label: Label = %TimeLabel
@onready var deaths_label: Label = %DeathsLabel
@onready var _message_timer: Timer = %MessageTimer

var _player: Player
var _feedback: String = ""
var _growth_fill: StyleBoxFlat
var _stability_fill: StyleBoxFlat


func _ready() -> void:
	_ignore_mouse(self)
	_growth_fill = growth_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_stability_fill = stability_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	growth_bar.add_theme_stylebox_override("fill", _growth_fill)
	stability_bar.add_theme_stylebox_override("fill", _stability_fill)
	_message_timer.timeout.connect(_clear_message)
	_refresh_context()


func bind_player(player: Player) -> void:
	_unbind()
	_player = player
	_feedback = ""
	_message_timer.stop()
	if not is_instance_valid(_player):
		return
	_player.resources.values_changed.connect(_on_values_changed)
	_player.form_controller.form_changed.connect(_on_form_changed)
	_player.abilities.ability_state_changed.connect(_on_ability_changed)
	_player.abilities.feedback_requested.connect(show_message)
	_player.state_machine.state_changed.connect(_on_state_changed)
	_on_form_changed(_player.current_form_id())


func set_run_stats(seconds: int, retries: int) -> void:
	var total := maxi(0, seconds)
	time_label.text = "%02d:%02d" % [floori(total / 60.0), total % 60]
	deaths_label.text = "重试 %d" % maxi(0, retries)


func show_message(message: String) -> void:
	_feedback = message
	_message_timer.start()
	_refresh_context()


func _on_form_changed(form_id: StringName) -> void:
	var form := _player.form_controller.get_current()
	var absorb := _key(&"absorb_resource")
	var primary := _key(&"ability_primary")
	var jump := _key(&"jump")
	match form_id:
		&"sprout":
			form_label.text = "01  幼芽期"
			ability_hint.text = "幼芽不可跳跃 · 穿过窄道，靠近营养液按住 %s 成长" % absorb
		&"humanoid":
			form_label.text = "02  人形期"
			ability_hint.text = "%s 扎根 / 拔根 · 扎根后 %s%s%s%s 伸腿推进" % [primary, _key(&"move_up"), _key(&"move_left"), _key(&"move_down"), _key(&"move_right")]
		&"mature":
			form_label.text = "03  成熟期"
			ability_hint.text = "%s 朝鼠标接 / 断藤蔓 · 连环后 %s 上环 · 下落按住 %s 滑翔" % [primary, absorb, jump]
		_:
			form_label.text = form.display_name
			ability_hint.text = "探索场景，寻找可通行的路线"
	var accent: Color = FORM_COLORS.get(form_id, Color("b8d78c"))
	form_label.add_theme_color_override("font_color", accent)
	_growth_fill.bg_color = accent
	controls_label.text = "%s / %s 移动    %s按住 %s 吸收液体    %s 重开" % [
		_key(&"move_left"), _key(&"move_right"),
		"%s 跳跃    " % jump if form.can_jump else "", absorb, _key(&"restart")]
	_on_values_changed(_player.resources.growth_progress, form.growth_threshold, _player.resources.stability)


func _on_values_changed(growth: float, threshold: float, stability: float) -> void:
	growth_bar.max_value = maxf(1.0, threshold)
	growth_bar.value = growth_bar.max_value if threshold <= 0.0 else growth
	growth_label.text = "成长  已成熟" if threshold <= 0.0 else "成长  %.0f / %.0f" % [growth, threshold]
	stability_bar.max_value = ResourceController.MAX_STABILITY
	stability_bar.value = stability
	stability_label.text = "稳定  %.0f / %.0f" % [stability, ResourceController.MAX_STABILITY]
	var stability_color := Color("f3a58c") if stability <= 30.0 else Color("8bc5b5")
	if _stability_fill.bg_color != stability_color:
		_stability_fill.bg_color = stability_color
	_refresh_state()
	_refresh_context()


func _on_ability_changed(_ability: StringName) -> void:
	_refresh_state()


func _on_state_changed(_previous: StringName, _current: StringName) -> void:
	_refresh_state()


func _refresh_state() -> void:
	if not is_instance_valid(_player):
		return
	var activity := "探索中"
	if _player.resources.stability <= 30.0:
		activity = "稳定偏低"
	elif _player.abilities.is_vine_attached():
		activity = "藤蔓连接"
	elif _player.abilities.is_leg_extended():
		activity = "伸腿推进"
	elif _player.abilities.is_rooted():
		activity = "已扎根"
	elif _player.state_machine.current_state == StateMachine.STATE_GLIDE:
		activity = "滑翔中"
	if state_label.text == activity:
		return
	state_label.text = activity
	state_label.add_theme_color_override("font_color", Color("f3a58c") if _player.resources.stability <= 30.0 else Color("b4c4b4"))


func _refresh_context() -> void:
	var message := "营养液促进成长 · 退化液缩小形态 · 触碰旗帜记录重试位置"
	if not _feedback.is_empty():
		message = _feedback
	elif is_instance_valid(_player):
		if _player.requires_absorption_release():
			message = "本轮吸收已完成 · 松开 %s，再按住继续吸收" % _key(&"absorb_resource")
		elif _player.resources.stability <= 30.0:
			message = "稳定度偏低 · 离开毒雾可逐渐恢复"
	if context_label.text == message:
		return
	context_label.text = message
	context_label.add_theme_color_override("font_color", Color("ead197") if not _feedback.is_empty() else Color("c3ceb9"))


func _clear_message() -> void:
	_feedback = ""
	_refresh_context()


func _exit_tree() -> void:
	_unbind()


func _unbind() -> void:
	if not is_instance_valid(_player):
		return
	_disconnect(_player.resources, &"values_changed", _on_values_changed)
	_disconnect(_player.form_controller, &"form_changed", _on_form_changed)
	_disconnect(_player.abilities, &"ability_state_changed", _on_ability_changed)
	_disconnect(_player.abilities, &"feedback_requested", show_message)
	_disconnect(_player.state_machine, &"state_changed", _on_state_changed)
	_player = null


func _disconnect(source: Object, event: StringName, callback: Callable) -> void:
	if is_instance_valid(source) and source.is_connected(event, callback):
		source.disconnect(event, callback)


func _key(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			return "空格" if code == KEY_SPACE else OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			return "左键" if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else event.as_text()
	return "未绑定"


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
