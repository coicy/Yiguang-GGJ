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

跳跃由 `FormDefinition.can_jump` 控制：幼芽期为 `false`，`MovementController` 会丢弃其跳跃输入并清空已有跳跃缓冲；人形期和成熟期保持跳跃、coyote time、jump buffer 与可变跳跃高度的既有行为。形态切换到不可跳跃形态时，也必须清除待执行的跳跃，避免切换后误起跳。

通用移动手感在玩家 `Movement` 节点的 Inspector 中调整：`Ground Movement` 下的 `acceleration`、`friction`、`turn_acceleration` 分别控制地面起步、松手刹车与反向转向，默认值为 `2400`、`3600`、`4800`。`Air Movement` 下的 `air_acceleration` 和 `air_friction` 保持 `1200`、`800`，起跳当帧即使用空中参数；三种形态的最高速度仍由各自 `FormDefinition.move_speed` 决定。

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
func get_leg_length() -> float
func get_max_leg_length() -> float
func get_leg_path() -> PackedVector2Array
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
func is_absorbing_resource() -> bool
```

玩家作为组合根负责接线和对外状态，不持有移动、形态和能力的内部算法。

## 能力映射

| 形态 | 能力 ID | 白模行为 |
| --- | --- | --- |
| 幼芽期 | `small_passage` | 允许通过小尺寸通道；不可跳跃 |
| 人形期 | `root` | 固定玩家，抵抗移动或风力 |
| 人形期 | `stretch_legs` | 正交缓慢伸长腿部并沿伸长方向推进 |
| 成熟期 | `vine_pull` | 牵引远处机关或连接锚点；白盒中的 `Ring` 是可钩挂的环形锚点 |
| 成熟期 | `leaf_glide` | 减缓下落并抵抗部分风力 |

当前输入约定：人形期左键切换扎根/拔根，扎根时 `W/A/S/D` 控制腿部沿上下左右缓慢伸长并推动玩家；腿部总路径长度不超过当前角色长度的 4 倍，方向变化只形成 90°转角；
成熟期左键沿鼠标方向连接/断开藤蔓，滑翔继续复用跳跃键；在营养液或毒液区域内按住 `E` 才会吸取液体。
藤蔓连接目标包括 `VineAnchor` 和白盒 `Ring`；`Ring` 不是装饰实体，只有成熟期可以钩挂。

## 变更记录

- 2026-09-05：形态碰撞改为数据驱动的圆形/胶囊形。幼芽使用直径 24 的圆形；人形使用 `20×36` 胶囊；成熟期使用 `18×46` 胶囊。幼芽和人形碰撞中心相对角色原点向右偏移 2 像素。形态切换的空间探测复用目标形态及其偏移，避免通行判断与实体碰撞不一致。
- 2026-09-05：能力表现由 `PlayerVisuals` 维护：扎根根须固定在世界锚点并渐入/收回；根茎通过 `leg_L3`、`leg_R3` 连接双脚，带节段与转角叶芽；藤蔓从 `hand_L_3` 骨骼发出，锚点显示缠绕；成熟期滑翔沿用 `jump_down` 身体姿态，并由 `SpineCharacterVisual` 对左右叶片骨骼链 `z21-z23`、`z24-z26` 叠加展开、摆动和收拢动画。扎根期间身体使用站立状态，技能动画仍可临时覆盖。效果不驱动物理或修改碰撞体。`tests/scene/test_form_passage.gd` 对沙盒两处通道的实际碰撞几何执行三形态通行扫描。

- 2026-09-05：新增 `FormDefinition.can_jump`。幼芽期禁用跳跃，且切换至幼芽期时清除跳跃缓冲；人形期与成熟期的跳跃手感保持不变。

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.1 | 建立玩家、移动和能力公共接口。 |
| 2026-09-05 | 0.2 | 明确白盒 `Ring` 为成熟期长藤蔓可钩挂的环形锚点。 |
