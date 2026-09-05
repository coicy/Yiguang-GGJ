class_name HandbuiltHud
extends Control
## Screen-space, read-only presentation for the hand-built level.

const DETAIL_SECONDS: float = 3.0

const PORTRAITS: Dictionary = {
	&"sprout": preload("res://assets/runtime/ui/botanical/portrait_sprout.png"),
	&"humanoid": preload("res://assets/runtime/ui/botanical/portrait_humanoid.png"),
	&"mature": preload("res://assets/runtime/ui/botanical/portrait_mature.png"),
}

@onready var form_name: Label = %FormName
@onready var portrait: TextureRect = %Portrait
@onready var stage: Label = %Stage
@onready var activity: Label = %Activity
@onready var growth_bar: ProgressBar = %GrowthBar
@onready var growth_value: Label = %GrowthValue
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var stability_value: Label = %StabilityValue
@onready var stability_label: Label = %StabilityLabel
@onready var interaction: PanelContainer = %Interaction
@onready var interaction_title: Label = %InteractionTitle
@onready var interaction_detail: Label = %InteractionDetail
@onready var interaction_bar: ProgressBar = %InteractionBar
@onready var interaction_key: TextureRect = %InteractionKey
@onready var toast: PanelContainer = %Toast
@onready var toast_text: Label = %ToastText

var _player: Player
var _nearby: Array[Area2D] = []
var _connections: Array[Array] = []
var _message_time: float = 0.0
var _form_id: StringName = &""
var _toxin_active: bool = false
var _binding: bool = false
var _detail_time: float = 0.0
var _details_expanded: bool = true
var _compact_resources: Label

func _ready() -> void:
	_compact_resources = Label.new()
	_compact_resources.name = "CompactResources"
	_compact_resources.theme_type_variation = &"PromptDetail"
	_compact_resources.add_theme_font_size_override(&"font_size", 14)
	%Status.get_node("Rows").add_child(_compact_resources)
	_set_details_expanded(false)
	_ignore_mouse(self)

func bind_player(player: Player, points: Array[Area2D] = []) -> void:
	_unbind()
	_player = player
	if not is_instance_valid(_player):
		hide()
		return
	show()
	_binding = true
	_connect(_player, &"resource_absorbed", _on_resource_absorbed)
	_connect(_player.resources, &"values_changed", _on_values_changed)
	_connect(_player.resources, &"toxin_changed", _on_toxin_changed)
	_connect(_player.form_controller, &"form_changed", _on_form_changed)
	_connect(_player.abilities, &"feedback_requested", show_message)
	_connect(_player.abilities, &"vine_fired", _on_vine_fired)
	for point: Area2D in points:
		_connect(point, &"body_entered", _on_point_entered.bind(point))
		_connect(point, &"body_exited", _on_point_exited.bind(point))
		if point.overlaps_body(player):
			_nearby.append(point)
	_on_form_changed(player.current_form_id())
	_binding = false

func _exit_tree() -> void:
	_unbind()

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_message_time = maxf(0.0, _message_time - delta)
	toast.visible = _message_time > 0.0
	if not get_tree().paused:
		_detail_time = maxf(0.0, _detail_time - delta)
	_set_details_expanded(_detail_time > 0.0)
	_refresh_activity()
	_refresh_interaction()

func _on_form_changed(form_id: StringName) -> void:
	var changed := _form_id != form_id
	_form_id = form_id
	var form := _player.form_controller.get_current()
	form_name.text = form.display_name
	portrait.texture = PORTRAITS.get(form_id)
	var form_index := [&"sprout", &"humanoid", &"mature"].find(form_id)
	stage.text = "%02d  /  03" % (form_index + 1)
	%JumpHint.visible = form.can_jump
	%AbilityHint.visible = form.can_root or form.can_use_vine
	_on_values_changed(_player.resources.growth_progress, form.growth_threshold, _player.resources.stability)
	_refresh_activity()
	if not _binding and changed:
		_show_details()
		show_message("形态变化 · " + form.display_name)

func _on_values_changed(growth: float, threshold: float, stability: float) -> void:
	growth_bar.max_value = maxf(threshold, 1.0)
	growth_bar.value = growth if threshold > 0.0 else 1.0
	growth_value.text = "%d%%" % floori(growth / maxf(threshold, 1.0) * 100.0) if threshold > 0.0 else "已成熟"
	stability_bar.value = stability
	stability_value.text = "%d%%" % ceili(stability)
	stability_label.text = "稳定度 · 危险" if stability <= 30.0 else ("稳定度 · 毒雾中" if _toxin_active else "稳定度")
	var bar_type: StringName = &"DangerBar" if stability <= 30.0 else &"StabilityBar"
	if stability_bar.theme_type_variation != bar_type:
		stability_bar.theme_type_variation = bar_type
	_compact_resources.text = "成长 %s · 稳定 %s%s" % [growth_value.text, stability_value.text, " 危险" if stability <= 30.0 else (" 毒雾" if _toxin_active else "")]

func _on_resource_absorbed(_kind: StringName, _amount: float) -> void:
	_show_details()

func _show_details() -> void:
	_detail_time = DETAIL_SECONDS
	_set_details_expanded(true)

func _set_details_expanded(expanded: bool) -> void:
	if _details_expanded == expanded:
		return
	_details_expanded = expanded
	var status := %Status as PanelContainer
	var rows := status.get_node("Rows") as VBoxContainer
	var identity := rows.get_node("Identity") as HBoxContainer
	stage.visible = expanded
	activity.visible = expanded
	rows.get_node("Growth").visible = expanded
	rows.get_node("Stability").visible = expanded
	_compact_resources.visible = not expanded
	(identity.get_node("Badge") as Control).custom_minimum_size = Vector2.ONE * (68.0 if expanded else 32.0)
	identity.add_theme_constant_override(&"separation", 12 if expanded else 8)
	rows.add_theme_constant_override(&"separation", 8 if expanded else 4)
	form_name.theme_type_variation = &"Title" if expanded else &"Light"
	form_name.add_theme_font_size_override(&"font_size", 25 if expanded else 17)
	status.theme_type_variation = &"StatusPanel" if expanded else &"DarkPanel"
	# Containers shrink once after the visibility change; no layout animation
	# or timer is restarted by the resource component's every-frame signal.
	status.set_deferred("size", Vector2(310.0 if expanded else 252.0, 0.0))

func _on_toxin_changed(active: bool) -> void:
	_toxin_active = active
	if active:
		show_message("毒雾正在消耗稳定度，尽快离开")

func _refresh_activity() -> void:
	var rooted := _player.abilities.is_rooted()
	var vine := _player.abilities.is_vine_attached()
	%MoveIcon0.visible = not rooted
	%MoveIcon1.visible = not rooted
	%MoveText.text = "WASD 伸腿 · 松手收回" if rooted else "移动"
	%AbilityText.text = "拔根" if rooted else ("藤蔓" if _form_id == &"mature" else "扎根")
	%JumpHint.visible = _player.form_controller.get_current().can_jump and not rooted and not vine
	%JumpText.text = "跳跃 / 按住滑翔" if _form_id == &"mature" else "跳跃"
	%AbsorbText.text = "上环" if vine else "吸收"
	if _player.abilities.is_leg_extended():
		var returning := _player.abilities.get_leg_extension_direction().is_zero_approx()
		var at_limit := _player.abilities.get_leg_length() >= _player.abilities.get_max_leg_length() - 0.1
		activity.text = "沿原路收腿 · Q 拔根" if returning else ("已到最长 · 松手收回" if at_limit else "扎根伸腿 · Q 拔根")
	elif rooted:
		activity.text = "已扎根 · 方向键伸腿"
	elif vine:
		activity.text = "正在上环" if _player.movement.is_vine_climbing() else "藤蔓连接 · E 上环"
	else:
		match _form_id:
			&"sprout": activity.text = "穿过狭缝，寻找营养"
			&"humanoid": activity.text = "跳跃探索，扎根伸腿"
			&"mature": activity.text = "连接藤蔓，展叶滑翔"

func _refresh_interaction() -> void:
	var source := _nearest_point()
	interaction.visible = source != null and not _player.abilities.is_vine_attached()
	if not interaction.visible:
		return
	var nutrition := source is NutritionTank
	var form := _player.form_controller.get_current()
	var prompt_title := "吸收营养液" if nutrition else "吸收毒液"
	var next_form := _player.form_controller.peek_grown_form() if nutrition else _player.form_controller.peek_withered_form()
	var detail := "按住 E · " + (("成长为" if nutrition else "退化为") + next_form.display_name if next_form != null else "恢复稳定度")
	var progress := _player.resources.growth_progress if nutrition else _player.resources.toxin_progress
	var threshold := form.growth_threshold if nutrition else _player.resources.toxin_threshold()
	var available := true
	interaction_bar.visible = true
	if _player.requires_absorption_release():
		prompt_title = "已变为" + form.display_name
		detail = "松开 E，再按住继续吸收"
		progress = 1.0
		threshold = 1.0
	elif nutrition and not (source as NutritionTank).accepted_form_id.is_empty() and (source as NutritionTank).accepted_form_id != form.id:
		prompt_title = "已完成这处补给"
		detail = "这处营养供幼芽成长使用"
		available = false
	elif not nutrition and form.id == &"sprout":
		prompt_title = "幼芽无需退化"
		detail = "成长后可用毒液回到较小形态"
		available = false
	elif nutrition and _player.resources.stability < ResourceController.MAX_STABILITY:
		prompt_title = "吸收营养 · 恢复稳定"
		progress = _player.resources.stability
		threshold = ResourceController.MAX_STABILITY
		detail = "按住 E · 稳定度优先恢复"
	elif nutrition and threshold <= 0.0:
		prompt_title = "营养充足"
		detail = "已是成熟形态，稳定度已满"
		available = false
	elif nutrition and progress >= threshold:
		prompt_title = "成长空间不足"
		detail = "移到开阔处后继续吸收"
	elif Input.is_action_pressed(&"absorb_resource"):
		prompt_title = "正在吸收营养液" if nutrition else "正在吸收毒液"
		detail = "保持按住 E · %d%%" % floori(progress / maxf(threshold, 1.0) * 100.0)
	interaction_title.text = prompt_title
	interaction_detail.text = detail
	interaction_key.modulate.a = 1.0 if available else 0.4
	interaction_bar.visible = available
	interaction_bar.max_value = maxf(threshold, 1.0)
	interaction_bar.value = progress
	var bar_type: StringName = &"NutritionBar" if nutrition else &"ToxinBar"
	if interaction_bar.theme_type_variation != bar_type:
		interaction_bar.theme_type_variation = bar_type
	_place_interaction(source)

func _place_interaction(source: Area2D) -> void:
	var collision := source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var local_tip := Vector2(0.0, -24.0)
	if collision != null and collision.shape != null:
		var shape_rect := collision.shape.get_rect()
		local_tip = collision.position + Vector2(shape_rect.get_center().x, shape_rect.position.y)
	var canvas_to_hud := get_global_transform_with_canvas().affine_inverse()
	var tip := canvas_to_hud * (source.get_global_transform_with_canvas() * local_tip)
	var desired := tip - Vector2(interaction.size.x * 0.5, interaction.size.y + 16.0)
	var player_head := canvas_to_hud * (_player.get_global_transform_with_canvas() * Vector2(0.0, -_player.form_controller.get_current().collision_size.y))
	# Keep the prompt above both the tank and the character, never over the face.
	desired.y = minf(desired.y, player_head.y - interaction.size.y - 18.0)
	desired.x = clampf(desired.x, 18.0, maxf(18.0, size.x - interaction.size.x - 18.0))
	desired.y = clampf(desired.y, 18.0, maxf(18.0, size.y - interaction.size.y - 88.0))
	var status_rect: Rect2 = %Status.get_rect().grow(12.0)
	if Rect2(desired, interaction.size).intersects(status_rect):
		desired.x = minf(status_rect.end.x + 12.0, size.x - interaction.size.x - 18.0)
	interaction.position = desired.round()

func _nearest_point() -> Area2D:
	var nearest: Area2D
	var distance := INF
	for point: Area2D in _nearby:
		if not is_instance_valid(point):
			continue
		var candidate := point.global_position.distance_squared_to(_player.global_position)
		if candidate < distance:
			distance = candidate
			nearest = point
	return nearest

func _on_point_entered(body: Node2D, point: Area2D) -> void:
	if body == _player and not point in _nearby:
		_nearby.append(point)

func _on_point_exited(body: Node2D, point: Area2D) -> void:
	if body == _player:
		_nearby.erase(point)

func _on_vine_fired(_target: Vector2, will_attach: bool) -> void:
	if will_attach:
		# A successful cast supersedes the previous failed-cast hint.
		_message_time = 0.0
		toast.hide()

func show_message(message: String) -> void:
	toast_text.text = message
	_message_time = 3.0
	toast.show()

func _connect(source: Object, event: StringName, callback: Callable) -> void:
	source.connect(event, callback)
	_connections.append([source, event, callback])

func _unbind() -> void:
	for connection: Array in _connections:
		var source: Object = connection[0]
		if is_instance_valid(source) and source.is_connected(connection[1], connection[2]):
			source.disconnect(connection[1], connection[2])
	_connections.clear()
	_nearby.clear()
	_player = null
	_message_time = 0.0
	_detail_time = 0.0
	_toxin_active = false
	if is_node_ready():
		_set_details_expanded(false)
		interaction.hide()
		toast.hide()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
