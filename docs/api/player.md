# 玩家与能力 API

## 职责

玩家系统组合移动、形态控制和能力控制。移动只在物理帧更新，玩家场景保持单一可复用 `CharacterBody2D`。

## 公共类型

### `MovementController : Node`

```gdscript
func configure_from_form(form: FormDefinition) -> void
func set_input_axis(axis: float) -> void
func request_jump() -> void
func release_jump() -> void
func physics_step(delta: float) -> void
```

实现必须保留 coyote time、jump buffer、可变跳跃高度和 `move_and_slide()`；不得通过设置 `global_position` 推进玩法位置。

### `AbilityDefinition : Resource`

```gdscript
@export var ability_id: StringName
@export var required_form_id: StringName
@export var cooldown: float
@export var stability_cost: float
```

具体能力行为由运行时控制器或能力节点实现，定义资源只保存可调参数和形态门槛。

### `AbilityController : Node`

```gdscript
signal ability_used(ability_id: StringName)
signal ability_rejected(ability_id: StringName, reason: StringName)

func can_use(ability_id: StringName) -> bool
func use(ability_id: StringName) -> bool
func tick_cooldowns(delta: float) -> void
func toggle_primary() -> bool
func set_leg_extension_direction(direction: Vector2) -> void
func is_rooted() -> bool
func get_leg_extension_direction() -> Vector2
```

失败原因至少包括 `unknown_ability`、`wrong_form`、`cooldown` 和 `insufficient_stability`。控制器不直接操作 HUD 或全局状态。

### `Player : CharacterBody2D`

```gdscript
signal died
signal form_changed(form_id: StringName)

func reset_to_checkpoint(position: Vector2) -> void
func get_current_form_id() -> StringName
```

玩家作为组合根负责接线和对外状态，不持有移动、形态和能力的内部算法。

## 能力映射

| 形态 | 能力 ID | 白模行为 |
| --- | --- | --- |
| 幼芽期 | `small_passage` | 允许通过小尺寸通道 |
| 人形期 | `root` | 固定玩家，抵抗移动或风力 |
| 人形期 | `stretch_legs` | 扩大有效触发/跨越范围 |
| 成熟期 | `vine_pull` | 牵引远处机关或连接锚点 |
| 成熟期 | `leaf_glide` | 减缓下落并抵抗部分风力 |

当前输入约定：人形期左键切换扎根/拔根，扎根时 `W/A/S/D` 控制腿部伸长方向并锁定水平移动；
成熟期左键连接/断开藤蔓，滑翔继续复用跳跃键。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.1 | 建立玩家、移动和能力公共接口。 |
