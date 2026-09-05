# 玩家、能力与战斗 API

## 职责

玩家系统组合移动、形态、资源、能力和战斗。移动只在物理帧更新，玩家场景保持单一可复用 `CharacterBody2D`。以下接口以当前生产脚本为准；正式关卡使用 `GreenhouseLevel` 负责检查点、暂停、死亡重试和通关。

## 公共类型

### `MovementController : Node`

```gdscript
func setup(p_body: CharacterBody2D, p_form: FormDefinition, p_resources: ResourceController = null) -> void
func set_form(p_form: FormDefinition) -> void
func request_jump() -> void
func release_jump() -> void
func tick(delta: float, move_dir: float, jump_held: bool) -> void
func set_motion_override(horizontal: float, vertical: float = NAN) -> void
func clear_motion_override() -> void
```

实现必须保留 coyote time、jump buffer、可变跳跃高度和 `move_and_slide()`；不得通过设置 `global_position` 推进玩法位置。

跳跃由 `FormDefinition.can_jump` 控制：幼芽期为 `false`，`MovementController` 会丢弃其跳跃输入并清空已有跳跃缓冲；人形期和成熟期保持跳跃、coyote time、jump buffer 与可变跳跃高度的既有行为。形态切换到不可跳跃形态时，也必须清除待执行的跳跃，避免切换后误起跳。

通用移动手感在玩家 `Movement` 节点的 Inspector 中调整：`Horizontal Movement` 下的 `acceleration`、`friction`、`turn_acceleration` 分别控制起步、松手刹车与反向转向，默认值为 `2400`、`3600`、`4800`，地面与空中共用。三种形态的 `FormDefinition.move_speed` 统一为 `240`；人形和成熟的普通跳跃均使用 `jump_force = -400`、`gravity_scale = 1`，三种形态的最大下落速度均为 `800`。变形时保留正常行走速度，不重新起步；扎根伸腿、藤蔓和滑翔仍由各自能力控制。

战斗通过 set_motion_override 请求闪避／击退速度，并设置 control_scale、allow_jump、allow_glide 控制动作中的移动限制；实际运动仍由 Movement 统一执行。vertical = NAN 表示不覆盖垂直速度。CombatController 的 cancel / reset 会清除自身施加的运动限制。

能力参数目前来自 FormDefinition 与 AbilityController 导出属性，未提供早期设计文档中的 AbilityDefinition 公共资源类型。

### `AbilityController : Node`

```gdscript
signal ability_state_changed(label: StringName)
signal feedback_requested(message: String)
signal primary_ability_requested(ability_id: StringName)
signal vine_fired(target_position: Vector2, will_attach: bool)

func tick(delta: float = 0.0) -> void
func post_movement_update() -> void
func toggle_primary() -> bool
func set_vine_aim_global_position(global_position: Vector2) -> void
func request_vine_climb() -> void
func set_leg_extension_direction(direction: Vector2) -> void
func get_leg_length() -> float
func get_max_leg_length() -> float
func get_leg_path() -> PackedVector2Array
func is_rooted() -> bool
func is_leg_extended() -> bool
func is_vine_attached() -> bool
func get_leg_extension_direction() -> Vector2
func cancel_all() -> void
```

能力尝试接口返回布尔值；面向玩家的提示通过 `feedback_requested(message)` 发出，没有统一的错误码枚举。控制器不直接操作 HUD 或全局状态。Player 在战斗忙碌期间不接受 Q 能力和资源吸收。

### `Player : CharacterBody2D`

```gdscript
signal resource_absorbed(kind: StringName, amount: float)
signal died

func current_state() -> StringName
func current_form_id() -> StringName
func is_grounded() -> bool
func is_absorbing_resource() -> bool
func requires_absorption_release() -> bool
func absorb_nutrition(amount: float) -> bool
func absorb_toxin(amount: float) -> bool
func receive_damage(request: DamageRequest) -> int
func capture_state() -> Dictionary
func restore_state(saved: Dictionary) -> void
func cancel_actions() -> void
func play_death_animation() -> bool
func revive_animation() -> void
```

玩家作为组合根负责接线和对外状态，不持有移动、形态、能力或战斗的内部算法。`player.combat` 为 CombatController，生命通过 `player.combat.health` 读取；形态变化信号位于 `player.form_controller.form_changed`，不是 Player 自身的 signal。

`capture_state()` 返回 position、velocity、form、resources。`restore_state()` 取消当前动作并恢复这些字段，包含重生时的位置恢复；它不负责补满生命、恢复死亡动画或重置遭遇。GreenhouseLevel 随后调用 `combat.reset()`、`revive_animation()` 等完成重试。`cancel_actions()` 只取消能力与战斗动作，不相当于恢复生命。

### `CombatController : Node`

```gdscript
signal action_started(action: StringName)
signal feedback_requested(kind: StringName, point: Vector2, strength: float)
signal defeated

func setup(actor: Player) -> void
func request_action(action: StringName, aim: Vector2) -> void
func tick(delta: float) -> void
func after_movement() -> void
func receive_damage(request: DamageRequest) -> int
func is_busy() -> bool
func can_use_ability() -> bool
func progress() -> float
func cancel() -> void
func reset() -> void
```

request_action 将 attack / heavy / dash / parry 请求写入短时输入缓存，aim 使用世界坐标；返回 void，不表示当前帧已经成功出招。Player 在物理帧先调用 tick、执行移动，再调用 after_movement 结算攻击有效段。控制器负责形态门槛、取消窗口、一次挥击去重、正面弹反和闪避免疫；伤害结果取 DamageRequest.Result。

幼芽只接受地面 attack 请求，选择 sprout_bump：准备 0.10 秒、有效 0.08 秒、收招 0.16 秒。有效段以 180 世界单位／秒向锁定朝向前顶，完整位移约 14.4；由 MovementController 的 move_and_slide 处理墙体。判定原点在脚底上方 12，前伸 24、高 20，伤害 1、击退 85，不破防。它不进入三连；失去地面、受击、成长和死亡均中断动作。身体压缩、前倾与回弹只作用于视觉节点，不缩放碰撞体。参数位于 sprout_bump.tres，骨骼与身体关键帧位于 sprout_poses.tres。

供表现只读查询的状态包括 state、attack、facing、elapsed、dash_cooldown_left、air_dash_used 和 air_attack_used。HUD 不直接写这些字段。reset 会取消动作、清理冷却和空中次数并重置生命；cancel 用于单纯中断。

### `HealthComponent : Node` 与 `DamageRequest : RefCounted`

```gdscript
signal health_changed(current: int, maximum: int)
signal damaged(request: DamageRequest)
signal died

func take_damage(request: DamageRequest) -> bool
func reset_health() -> void
func tick(delta: float) -> void
```

HealthComponent 拥有 current、maximum 和 protection_left。普通外部攻击应调用 Player.receive_damage，以经过闪避／弹反检查，再进入 HealthComponent；关卡即死危险由关卡显式处理生命。不要让 UI 直接扣血。

DamageRequest 传递 source、attack_id、amount、origin、knockback、parryable 和 breaks_guard。结果枚举为 IGNORED、HIT、BLOCKED、PARRIED。AttackDefinition 与 CombatTuning 是可编辑只读配置，生命和动作计时属于各实例。

## 输入与消费顺序

| InputMap 动作 | 当前默认输入 | Player／关卡行为 |
| --- | --- | --- |
| move_left / move_right | A / D | 物理帧读取移动方向 |
| jump | 空格 | 保留跳跃缓冲与松手截断；成熟形态空闲下落时按住可滑翔 |
| attack | 鼠标左键 | 幼芽地面前顶；人形／成熟地面三连或每次腾空一次的空击 |
| heavy | 鼠标右键 | 地面重击 |
| dash | Shift | 水平闪避，空中每次腾空一次 |
| parry | F | 前方短窗口弹反 |
| ability_primary | Q | 扎根／拔根或朝鼠标瞄准藤蔓 |
| absorb_resource | E | 按住吸收；挂藤时请求上环；形态变化后松开再按下 |
| pause / restart | Esc / R | 由 GreenhouseLevel 管理暂停或重启整关 |

HUD 的常驻部分忽略鼠标，菜单先消费 UI 输入；未消费的攻击和 Q 事件由 Player._unhandled_input 转为子组件请求。攻击与弹反起手锁定朝向，移动输入不会翻转当前动作。战斗动作会取消扎根／伸腿／挂藤并暂时禁止滑翔，受击、形态变化、死亡和重试会清理残留攻击。

## 能力映射

| 形态 | 能力 ID | 白模行为 |
| --- | --- | --- |
| 幼芽期 | `small_passage` | 允许通过小尺寸通道；不可跳跃 |
| 人形期 | `root` | 固定玩家，抵抗移动或风力 |
| 人形期 | `stretch_legs` | 正交缓慢伸长腿部并沿伸长方向推进 |
| 成熟期 | `vine_pull` | 牵引远处机关或连接锚点；白盒中的 `Ring` 是可钩挂的环形锚点 |
| 成熟期 | `leaf_glide` | 减缓下落并抵抗部分风力 |

当前输入约定：人形期 Q 切换扎根/拔根，扎根时 `W/A/S/D` 控制腿部沿上下左右缓慢伸长并推动玩家；腿部总路径长度不超过当前角色长度的 4 倍，方向变化只形成 90°转角；松开方向键后身体沿折线逐个拐点收回，默认完整直线收腿约 0.67 秒（60 Hz）。按住方向键达到长度上限时保持静止，扎根期间朝向跟随伸腿输入；拔根或吸收切换形态会清除腿部速度与路径。

成熟期 Q 沿鼠标方向连接/断开藤蔓：每次发射会重播出手动作，藤蔓前端从手部飞出，命中时缠绕、绷紧并播放命中声，断开时收回。未找到锚点也会沿瞄准方向甩出再收回，碰到墙面即止；切换形态、死亡或重生会清除未完成的效果。`VineVisual` 只负责表现，物理连接与攀爬仍由能力和移动控制器负责；Inspector 可调发射速度、收回速度、飞行时长上下限和命中效果时长。滑翔继续复用跳跃键；在营养液或毒液区域内按住 `E` 才会吸取液体。
藤蔓连接目标包括 `VineAnchor` 和白盒 `Ring`；`Ring` 不是装饰实体，只有成熟期可以钩挂。

## 变更记录

- 2026-09-06：正式主关卡加入完整战斗。左键／右键用于轻击／重击，Shift 闪避，F 弹反，原形态能力迁移到 Q。补充真实 Player、CombatController、HealthComponent 与 Movement 运动覆盖接口；保留既有移动、资源和形态规则。

- 2026-09-05：形态碰撞改为数据驱动的圆形/胶囊形。幼芽使用直径 24 的圆形；人形使用 `20×36` 胶囊；成熟期使用 `18×46` 胶囊。幼芽和人形碰撞中心相对角色原点向右偏移 2 像素。形态切换的空间探测复用目标形态及其偏移，避免通行判断与实体碰撞不一致。
- 2026-09-05：能力表现由 `PlayerVisuals` 维护：扎根根须固定在世界锚点并渐入/收回；根茎通过 `leg_L3`、`leg_R3` 连接双脚，带节段与转角叶芽；藤蔓从 `hand_L_3` 骨骼发出，锚点显示缠绕；成熟期滑翔沿用 `jump_down` 身体姿态，并由 `SpineCharacterVisual` 对左右叶片骨骼链 `z21-z23`、`z24-z26` 叠加展开、摆动和收拢动画。扎根期间身体使用站立状态，技能动画仍可临时覆盖。效果不驱动物理或修改碰撞体。`tests/scene/test_form_passage.gd` 对沙盒两处通道的实际碰撞几何执行三形态通行扫描。

- 2026-09-05：新增 `FormDefinition.can_jump`。幼芽期禁用跳跃，且切换至幼芽期时清除跳跃缓冲；人形期与成熟期的跳跃手感保持不变。

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.1 | 建立玩家、移动和能力公共接口。 |
| 2026-09-05 | 0.2 | 明确白盒 `Ring` 为成熟期长藤蔓可钩挂的环形锚点。 |
