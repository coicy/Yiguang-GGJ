# 形态系统 API

## 职责

形态系统管理三阶段形态、营养液成长、毒素枯萎和毒区稳定度。它不负责玩家物理移动、UI 展示或关卡节点查找。

## 公共类型

### `FormDefinition : Resource`

```gdscript
@export var form_id: StringName
@export var stage_index: int
@export var move_speed_multiplier: float
@export var jump_multiplier: float
@export var body_size: Vector2
@export var abilities: Array[StringName]
```

约束：`stage_index` 从 `0` 到 `2`；幼芽期、人形期、成熟期分别对应 `0`、`1`、`2`。能力列表只声明能力 ID，不持有运行时节点引用。

### `FormCatalog : RefCounted`

```gdscript
func add_form(form: FormDefinition) -> void
func get_form(form_id: StringName) -> FormDefinition
func has_form(form_id: StringName) -> bool
func get_form_at_stage(stage_index: int) -> FormDefinition
```

缺少形态时，`get_form` 和 `get_form_at_stage` 返回 `null`，调用方必须先用 `has_form` 或结果判空。

### `FormState : RefCounted`

```gdscript
var current_form_id: StringName
var stability: float
var nutrition_progress: float
var toxin_progress: float
var in_toxin_zone: bool

func set_form(form_id: StringName) -> void
func absorb_nutrition(amount: float) -> bool
func absorb_toxin(amount: float) -> bool
func tick_toxin_zone(delta: float) -> void
func recover_stability(amount: float) -> void
```

规则：

- 营养液达到当前成长阈值后，状态进入下一阶段并清零当前成长进度。
- 毒素达到当前枯萎阈值后，状态进入上一阶段并清零当前毒素进度。
- 毒区 tick 同时降低移动效果所需的稳定度；离开毒区后由 `recover_stability` 恢复。
- 稳定度归零时自动枯萎；幼芽期不能继续向下枯萎。
- 数值参数必须由外部配置提供，状态对象不依赖场景节点。

### `FormController : Node`

```gdscript
signal form_changed(form_id: StringName)
signal form_change_rejected(form_id: StringName, reason: StringName)

func switch_to(form_id: StringName) -> bool
func can_switch_to(form_id: StringName) -> bool
func get_current_form() -> FormDefinition
```

`FormController` 是形态变更的唯一入口。成功切换后发出 `form_changed`；失败时发出 `form_change_rejected`，原因使用稳定的 `StringName`。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.1 | 建立形态和资源转换公共接口。 |
