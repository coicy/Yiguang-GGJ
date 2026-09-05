class_name CombatHud
extends CanvasLayer
## Read-only combat presentation. The level owns pause, retry and run state.

const DETAIL_SECONDS: float = 3.0

signal pause_requested
signal resume_requested
signal retry_requested
signal restart_requested

@onready var screen: Control = %Screen
@onready var health_label: Label = %HealthLabel
@onready var health_pips: HBoxContainer = %HealthPips
@onready var dash_label: Label = %DashLabel
@onready var dash_bar: ProgressBar = %DashBar
@onready var parry_label: Label = %ParryLabel
@onready var parry_bar: ProgressBar = %ParryBar
@onready var section_label: Label = %SectionLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var run_label: Label = %RunLabel
@onready var boss_panel: PanelContainer = %BossPanel
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_phase: Label = %BossPhase
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_detail: Label = %OverlayDetail
@onready var overlay_kicker: Label = %OverlayKicker
@onready var overlay_stats: Label = %OverlayStats
@onready var controls_guide: GridContainer = %ControlsGuide
@onready var primary_button: Button = %PrimaryButton
@onready var restart_button: Button = %RestartButton

var _player: Player
var _boss: CombatEnemy
var _seconds: float = 0.0
var _deaths: int = 0
var _overlay_kind: StringName = &""
var _health: HealthComponent
var _display_health: int = -1
var _health_tween: Tween
var _overlay_tween: Tween
var _detail_time: float = 0.0
var _details_expanded: bool = true
var _form_id: StringName = &""
var _compact_actions: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_compact_actions = Label.new()
	_compact_actions.name = "CompactActions"
	_compact_actions.theme_type_variation = &"PromptDetail"
	_compact_actions.add_theme_font_size_override(&"font_size", 13)
	%CombatPanel.get_node("Rows").add_child(_compact_actions)
	_set_details_expanded(false)
	_ignore_mouse(%Gameplay)
	primary_button.pressed.connect(_on_primary_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	boss_panel.hide()
	hide_overlay()

func bind_player(player: Player) -> void:
	_unbind_player()
	_player = player
	%CombatPanel.visible = is_instance_valid(_player)
	if not is_instance_valid(_player):
		return
	_form_id = _player.current_form_id()
	_player.form_controller.form_changed.connect(_on_form_changed)
	_player.resource_absorbed.connect(_on_resource_absorbed)
	_health = _player.combat.health
	_health.health_changed.connect(_on_health_changed)
	_on_health_changed(_health.current, _health.maximum)
	_refresh_actions()

func set_progress(section: String, objective: String, seconds: float, deaths: int) -> void:
	section_label.text = section
	objective_label.text = objective
	_seconds = maxf(0.0, seconds)
	_deaths = maxi(0, deaths)
	run_label.text = "%s   ·   重试 %d" % [_time_text(_seconds), _deaths]

func set_boss(enemy: CombatEnemy) -> void:
	_boss = enemy
	_refresh_boss()

func show_pause() -> void:
	_show_overlay(&"pause", "稍作停留", "休息片刻，随时继续探索温室。")
	overlay_kicker.text = "失控温室  /  已暂停"
	primary_button.text = "继续游戏"
	restart_button.text = "重新开始整关"
	controls_guide.show()

func show_death() -> void:
	_show_overlay(&"death", "再次生长", "从最近的安全点重试，生命将恢复。")
	overlay_kicker.text = "温室仍在等待"
	primary_button.text = "重试当前遭遇"
	restart_button.text = "重新开始整关"
	controls_guide.hide()

func show_complete(seconds: float, deaths: int) -> void:
	_seconds = maxf(0.0, seconds)
	_deaths = maxi(0, deaths)
	_show_overlay(&"complete", "温室重获新生", "守圃者已停止运转。新芽将继续生长。")
	overlay_kicker.text = "失控温室  /  探索完成"
	primary_button.text = "再玩一次"
	restart_button.hide()
	controls_guide.hide()

func hide_overlay() -> void:
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_kind = &""
	overlay.hide()
	primary_button.release_focus()
	restart_button.release_focus()

func is_overlay_visible() -> bool:
	return overlay.visible

func _process(delta: float) -> void:
	if not get_tree().paused:
		_detail_time = maxf(0.0, _detail_time - delta)
	if is_instance_valid(_player):
		_refresh_actions()
	_refresh_boss()

func _refresh_actions() -> void:
	var combat := _player.combat
	var can_fight := _player.current_form_id() != &"sprout" and combat.health.current > 0
	_set_details_expanded(can_fight and _detail_time > 0.0)
	%AttackHint.text = "左键 连击 / 空击  ·  右键 重击" if can_fight else "左键 前顶  ·  成长后解锁藤鞭与闪避"
	if not can_fight:
		dash_label.text = "Shift  闪避 · 未解锁" if combat.health.current > 0 else "Shift  闪避"
		parry_label.text = "F  弹反 · 未解锁" if combat.health.current > 0 else "F  弹反"
		dash_bar.value = 0.0
		parry_bar.value = 0.0
		_compact_actions.text = "左键 前顶 · 成长后解锁闪避" if combat.health.current > 0 else "等待再次生长"
		return
	var dash_left := combat.dash_cooldown_left
	var air_used := combat.air_dash_used and not _player.is_on_floor()
	dash_bar.value = 1.0 - dash_left / maxf(combat.tuning.dash_cooldown, 0.001)
	if combat.state == &"dash":
		dash_label.text = "Shift  闪避中"
		dash_bar.value = 0.0
	elif air_used:
		dash_label.text = "Shift  闪避 · 落地恢复"
		dash_bar.value = 0.0
	elif dash_left > 0.0:
		dash_label.text = "Shift  闪避 · %.1fs" % dash_left
	else:
		dash_label.text = "Shift  闪避 · 就绪"
	parry_bar.value = 1.0
	if combat.state == &"parry_success":
		parry_label.text = "F  弹反成功 · 反击！"
	elif combat.state == &"parry":
		var active_end := combat.tuning.parry_start + combat.tuning.parry_window
		if combat.elapsed < combat.tuning.parry_start:
			parry_label.text = "F  弹反 · 起手"
		elif combat.elapsed <= active_end:
			parry_label.text = "F  弹反 · 防御窗口"
		else:
			parry_label.text = "F  弹反 · 收招"
			parry_bar.value = (combat.elapsed - active_end) / maxf(combat.tuning.parry_recovery, 0.001)
	else:
		parry_label.text = "F  弹反 · 就绪"
	var dash_status := "落地恢复" if air_used else ("%.1fs" % dash_left if dash_left > 0.0 else "就绪")
	if combat.state == &"dash":
		dash_status = "闪避中"
	var parry_status := "反击" if combat.state == &"parry_success" else parry_label.text.trim_prefix("F  弹反 · ").replace("防御窗口", "防御")
	_compact_actions.text = "闪避 %s · 弹反 %s" % [dash_status, parry_status]

func _on_form_changed(form_id: StringName) -> void:
	if form_id != _form_id:
		_form_id = form_id
		_detail_time = DETAIL_SECONDS
	_refresh_actions()

func _on_resource_absorbed(_kind: StringName, _amount: float) -> void:
	_detail_time = DETAIL_SECONDS
	_refresh_actions()

func _set_details_expanded(expanded: bool) -> void:
	if _details_expanded == expanded:
		return
	_details_expanded = expanded
	for control: Control in [dash_label, dash_bar, parry_label, parry_bar, %AttackHint]:
		control.visible = expanded
	_compact_actions.visible = not expanded
	health_label.add_theme_font_size_override(&"font_size", 19 if expanded else 16)
	%CombatPanel.get_node("Rows").add_theme_constant_override(&"separation", 8 if expanded else 4)
	%CombatPanel.set_deferred("size", Vector2(266.0, 0.0))

func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "生命  %d / %d" % [current, maximum]
	for index: int in health_pips.get_child_count():
		var pip := health_pips.get_child(index) as ProgressBar
		pip.value = 1.0 if index < current else 0.0
	if current <= 2 and current > 0:
		health_label.text += " · 危险"
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	health_pips.modulate = Color.WHITE
	if _display_health > current:
		health_pips.modulate = Color(1.35, 1.15, 1.0)
		_health_tween = create_tween()
		_health_tween.tween_property(health_pips, "modulate", Color.WHITE, 0.22)
	_display_health = current

func _refresh_boss() -> void:
	boss_panel.visible = is_instance_valid(_boss) and is_instance_valid(_boss.health) and _boss.health.current > 0
	if not boss_panel.visible:
		return
	boss_bar.max_value = _boss.health.maximum
	boss_bar.value = _boss.health.current
	boss_phase.text = "过载 · 第二阶段" if _boss.second_phase else "第一阶段"
	if _boss.warden_behavior != null:
		if _boss.state == &"stun":
			boss_phase.text = "失衡 · 反击窗口"
		elif _boss.state == &"overload":
			boss_phase.text = "核心过载 · 准备追击"
		elif _boss.warden_behavior.phase_pending:
			boss_phase.text = "核心不稳"
	%BossName.text = "守圃者"

func _show_overlay(kind: StringName, title: String, detail: String) -> void:
	_overlay_kind = kind
	overlay_title.text = title
	overlay_detail.text = detail
	overlay_stats.text = "探索用时  %s     /     重试  %d 次" % [_time_text(_seconds), _deaths]
	restart_button.show()
	overlay.show()
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	overlay.modulate.a = 0.0
	_overlay_tween = create_tween()
	_overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.16)
	primary_button.grab_focus.call_deferred()

func _on_primary_pressed() -> void:
	match _overlay_kind:
		&"pause": resume_requested.emit()
		&"death": retry_requested.emit()
		&"complete": restart_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _unbind_player() -> void:
	if is_instance_valid(_player):
		if _player.form_controller.form_changed.is_connected(_on_form_changed):
			_player.form_controller.form_changed.disconnect(_on_form_changed)
		if _player.resource_absorbed.is_connected(_on_resource_absorbed):
			_player.resource_absorbed.disconnect(_on_resource_absorbed)
	_detail_time = 0.0
	_form_id = &""
	if is_instance_valid(_health) and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	_health = null
	_display_health = -1
	_player = null

func _exit_tree() -> void:
	_unbind_player()
	_boss = null

func _time_text(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
