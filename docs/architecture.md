# 项目架构

## 1. 目标与边界

这是一个源自 Game Jam 的单机 2D 横版动作项目。2026-09-06 起正式版本采用完整战斗与七区温室关卡，范围依据见 [战斗设计](combat_design.md)。架构优先保证三件事：

- 角色移动手感可以独立调参。
- 形态切换可以新增或删除，不复制整套玩家控制器。
- 战斗是正式游戏的核心功能，仍与移动、形态保持独立职责，复用同一套物理移动循环。

当前范围不引入联网、持久存档、复杂背包、开放世界流式加载或通用 ECS。本次计划按质量推进，不受原 48 小时上限限制；遭遇快照只服务于当前运行内的重试。

## 2. 分层规则

```text
Presentation:  UI、Sprite2D、AnimationPlayer、粒子、音效
Logic:         玩家控制器、状态机、形态/能力运行时、战斗协调
Data:          Resource 配置（形态、能力、敌人、关卡参数）
Infrastructure: GlobalSignalBus、RunState、输入与场景启动
```

依赖方向是向下调用、向上发信号：

- 子节点通过类型化 signal 通知父节点。
- 父节点用明确的方法调用子节点。
- UI 只监听事件或读取只读查询，不直接修改玩家或 Resource 数据。
- 跨场景事件才进入 `GlobalSignalBus`；同一场景内不使用全局总线。

## 3. 目录与所有权

```text
autoloads/
  global_signal_bus.gd       全局、过去时生命周期事件，保持少量
  run_state.gd               跨关卡的当前运行数据
core/
  通用但不属于任何具体玩法的基础类型与工具
features/
  player/                    CharacterBody2D、移动、状态机、玩家场景
  forms/                     FormDefinition Resource、形态选择与切换
  abilities/                 AbilityDefinition Resource、能力运行时
  combat/                    战斗时序、生命、判定查询、伤害请求、姿势与反馈
  enemies/                   敌人场景与敌人专属逻辑
  level/                     关卡规则、出生点、检查点、目标
  ui/                        HUD、暂停菜单、结果界面
scenes/
  app/main.tscn              启动壳，不放具体玩法
  levels/                    组合关卡场景
assets/
  source/                    PSD/BLEND/原始音频等编辑源，已用 .gdignore
  runtime/                   导出时实际使用的贴图、音频、字体
tests/
  unit/                      纯数据与纯逻辑测试
  scene/                     小型场景/物理/信号集成测试
docs/                        架构、工具包和开发约定
```

每个功能目录内部仍按功能放场景、脚本和资源；不要创建全局 `scripts/`、`sprites/`、`resources/` 类型目录。

## 4. 玩家与形态架构

玩家只保留一个 `CharacterBody2D` 场景，当前关键场景边界如下（省略表现细节）：

```text
Player (CharacterBody2D)
  CollisionShape2D             数据驱动的圆形／胶囊形
  GrowthCast                   形态切换的空间检查
  LegExtension                 能力交互判定，独立于攻击层
  Visuals (Node2D)              Spine／既有动画、藤蔓和战斗表现
  StateMachine (Node)
  Movement (Node)
  FormController (Node)
  Resources (Node)
  Abilities (Node)
  Combat (CombatController)
    CombatHealth (HealthComponent)
  Hurtbox (Area2D)              Player._ready() 按当前形态建立
```

职责分配：

- `Movement` 统一执行速度、重力、加速度、跳跃窗口和碰撞后的移动；战斗通过通用运动覆盖请求接入闪避／击退，不调用第二次独立移动。
- `StateMachine` 只负责状态转换，不把移动、攻击和动画都塞进一个大脚本。
- `FormController` 拥有当前形态，通过 `FormDefinition` 提供移动修正、可用能力和视觉配置。
- `AbilityController` 执行扎根、伸腿、藤蔓与上环，参数来自形态配置和自身导出属性。
- `CombatController` 拥有动作、连段、输入缓存、闪避／弹反时序与一次攻击的目标去重；`HealthComponent` 拥有该角色的生命和受击保护。
- `Player` 作为组合根把输入、状态和子组件接起来，不负责保存每个系统的内部数据。形态改变会取消能力／攻击、更新形状与 Hurtbox，表现再读取新的状态。

形态切换流程：

```text
Input action
  -> Player/StateMachine 接收切换意图
  -> FormController.validate_and_switch(form_id)
  -> current_form 更新（运行时 duplicate Resource）
  -> form_changed.emit(form_id)
  -> Visuals / AbilityController / HUD 各自响应
```

形态差异优先写成 `Resource` 字段或能力资源，不为每种形态复制 `Player.tscn`。只有碰撞轮廓或节点结构确实不同，才允许形态提供一个局部视觉/碰撞子场景。

## 5. 平台跳跃物理约定

- 标准角色使用 `CharacterBody2D` 和 `move_and_slide()`。
- 移动只在 `_physics_process()` 中执行，不能用 `global_position` 推进玩法位置。
- 保留约 `0.10s` coyote time、约 `0.15s` jump buffer 和可变跳跃高度；最终数值在玩家资源中调参。
- `move_and_slide()` 前不乘 `delta`；重力作为加速度乘 `delta` 后写入 `velocity`。
- 落地时清理向下速度；处理 `is_on_ceiling()`，避免顶头后继续保留跳跃速度。
- 单向平台使用 TileSet/碰撞形状的 one-way 配置和明确的 layer/mask，不通过改坐标穿透。
- 移动平台使用 `AnimatableBody2D`，打开 `sync_to_physics`。
- 网格化白盒或标准瓦片关卡使用 `TileMapLayer`；非 Tile 美术关卡可以由手工组合的可复用地形场景构成。手工地形的碰撞与美术必须分离，整块地形优先使用一个简化碰撞体，而不是按装饰 Sprite 拼碰撞。

## 6. 碰撞层约定

| 层 | 名称 | 用途 |
|---|---|---|
| 1 | World | 地面、墙、单向平台 |
| 2 | Player | 玩家本体 |
| 3 | Enemy | 敌人本体 |
| 4 | PlayerHitbox | 玩家攻击层约定；不用于机关伸腿交互 |
| 5 | EnemyHitbox | 敌人攻击 |
| 6 | Hazard | 即死、伤害区、陷阱 |
| 7 | Interactable | 检查点、机关、出口 |
| 8 | AbilityInteract | 扎根伸腿等能力交互 |
| 9 | PlayerHurtbox | 玩家受击查询，CombatQuery.PLAYER_HURT = 256 |
| 10 | EnemyHurtbox | 敌人受击查询，CombatQuery.ENEMY_HURT = 512 |

每个碰撞体在创建时同时记录 layer 与 mask。不要使用“全选 mask”来省事。

## 7. 战斗、遭遇与 HUD 所有权

战斗与 Movement／FormController 保持职责分离。当前实现通过物理空间查询寻找 Hurtbox，伤害请求由接收者验证；界面与效果不决定伤害。

| 组件／数据 | 拥有的数据与职责 | 对外关系 |
| --- | --- | --- |
| AttackDefinition / CombatTuning | 招式伤害、准备／有效／收招、距离、取消与闪避／弹反参数 | Resource 配置只读；运行时计时不写回共享资源 |
| EnemyDefinition | 敌人类型、生命上限、行为参数、身体尺寸与图集 | 各敌人读取同一配置，生命保存在独立组件 |
| CombatController | 玩家动作状态、连段、输入缓存、攻击实例、闪避和弹反时序 | Player 下发动作请求；通过 Movement 通用覆盖执行运动，发出动作／反馈／死亡信号 |
| PoiseComponent | 单个普通敌人的剩余韧性、破韧状态、恢复延迟和恢复保护 | CombatEnemy 推进和调用；数值来自 EnemyDefinition，视图只读取状态 |
| HealthComponent | 当前生命、生命上限、受击保护剩余时间 | take_damage / reset_health 修改状态；health_changed、damaged、died 通知订阅者 |
| CombatQuery / Hurtbox / DamageRequest | 目标空间查询、地形阻挡与一次伤害的数据传递 | Player／CombatEnemy 接收并判定 HIT、BLOCKED、PARRIED 或 IGNORED |
| CombatEnemy | 单个敌人的目标、行为状态、攻击阶段和精英阶段 | 持有自己的 HealthComponent；向遭遇发出死亡、弹体和反馈事件 |
| EncounterController | 当前遭遇的波次、敌人、弹体、战斗门与完成状态 | 接收 begin / reset_encounter；向关卡报告开始、完成和新敌人 |
| GreenhouseLevel | 当前遭遇、安全快照、死亡数、计时、暂停、镜头、重试和出口状态 | 组合场景、调用遭遇与 HUD；恢复快照后重置战斗、生命和表现 |
| HandbuiltHud / CombatHud | 形态／资源与战斗状态的屏幕表现、菜单操作意图 | 只读玩家／敌人或监听局部信号；菜单向关卡发出 resume/retry/restart 请求，不修改玩法数据 |

Player 的物理帧先推进战斗和能力，再由 StateMachine／Movement 执行角色运动，随后结算攻击查询并刷新表现。生命／资源快照与攻击配置不相互混用。命中停顿由 CombatFeedback 集中管理，暂停、死亡、重试、完成和退出清理时间缩放。

详细接口见 [玩家 API](api/player.md)，招式与遭遇配置见 [战斗设计](combat_design.md)。

## 8. Autoload 约束

当前只注册两个 Autoload：

- `GlobalSignalBus`：只放 `run_started`、`level_started`、`player_died` 等少量跨场景过去时事件，目标少于 15 个。
- `RunState`：只保存死亡次数、当前关卡 ID、当前形态 ID 等跨场景运行数据。

不要在 Autoload 中持有玩家、HUD、敌人等场景节点引用；不要在 `_init()` 访问其他 Autoload；不要形成循环依赖。

## 9. 正式场景流

```text
scenes/app/main.tscn
  -> LevelHost / LevelMain (scenes/levels/Level_main.tscn)
      -> Level01 (scenes/levels/level_01.tscn, GreenhouseLevel)
          -> Geometry / Areas / Actors
          -> Encounters / Checkpoints
          -> Camera2D / CombatFeedback / LevelSounds
          -> Interface (CanvasLayer) / HandbuiltHud
          -> CombatHud (CanvasLayer)
```

Main 只负责生命周期容器，正式玩法由 GreenhouseLevel 扩展既有 HandbuiltLevel 管理。F5 始终走上述手工主关卡；旧 JSON 白盒与历史测试场景不作为本次新增玩法入口。

GreenhouseLevel 通过局部信号连接遭遇和菜单，负责暂停 SceneTree、恢复安全快照、保留已完成遭遇、打开精英后的出口及结算。HUD 保持在独立 CanvasLayer，菜单使用 PROCESS_MODE_ALWAYS 接受暂停期间输入；玩法分支在暂停期间停止。UI 不搜索关卡或自行重载场景。

当前运行内的计时、死亡数和遭遇状态由 GreenhouseLevel 持有，不把这些场景节点或敌人引用存入 Autoload。正式关卡集成验证见 [温室验证记录](greenhouse_validation.md)。
