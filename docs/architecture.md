# 项目架构

## 1. 目标与边界

这是一个单机、2D、横向平台跳跃 Game Jam 项目。架构优先保证三件事：

- 角色移动手感可以独立调参。
- 形态切换可以新增或删除，不复制整套玩家控制器。
- 战斗可选，关闭战斗后平台跳跃仍能独立运行。

不在 48 小时首版中引入联网、存档、复杂背包、开放世界流式加载或通用 ECS。这些系统会提高接线和调试成本，不能直接服务当前体验目标。

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
  combat/                    Hitbox、Hurtbox、DamageRequest、伤害协调
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

玩家只保留一个 `CharacterBody2D` 场景，建议的场景边界如下：

```text
Player (CharacterBody2D)
  CollisionShape2D             只使用 CapsuleShape2D 或 RectangleShape2D
  Visuals (Node2D)
    Sprite2D / AnimatedSprite2D
    AnimationPlayer
  StateMachine (Node)
  Movement (Node)
  FormController (Node)
  AbilityController (Node)
  Hurtbox (Area2D)              只有启用战斗时才需要
  CameraTarget (Marker2D)
```

职责分配：

- `Movement` 拥有速度、重力、加速度、跳跃窗口和碰撞后状态读取。
- `StateMachine` 只负责状态转换，不把移动、攻击和动画都塞进一个大脚本。
- `FormController` 拥有当前形态，通过 `FormDefinition` 提供移动修正、可用能力和视觉配置。
- `AbilityController` 执行能力冷却/施放流程；具体能力数据来自 `AbilityDefinition`。
- `Player` 作为组合根把输入、状态和子组件接起来，不负责保存每个系统的内部数据。

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
- 关卡几何使用 `TileMapLayer`，不要用大量独立 Sprite2D 拼碰撞。

## 6. 碰撞层约定

| 层 | 名称 | 用途 |
|---|---|---|
| 1 | World | 地面、墙、单向平台 |
| 2 | Player | 玩家本体 |
| 3 | Enemy | 敌人本体 |
| 4 | PlayerHitbox | 玩家攻击/能力 |
| 5 | EnemyHitbox | 敌人攻击 |
| 6 | Hazard | 即死、伤害区、陷阱 |
| 7 | Interactable | 检查点、机关、出口 |

每个碰撞体在创建时同时记录 layer 与 mask。不要使用“全选 mask”来省事。

## 7. 战斗作为可选模块

战斗不应该被 `Movement` 或 `FormController` 依赖。建议接口是：

- `Hitbox` 发现目标后生成一个轻量 `DamageRequest` 数据对象。
- `Hurtbox`/`Health` 负责验证目标是否可受伤并修改自己的生命值。
- 伤害、死亡、击退完成后发出信号；UI、音效、粒子和分数各自监听。
- 首版如果时间不足，保留目录和接口契约，删除战斗场景实例即可。

## 8. Autoload 约束

当前只注册两个 Autoload：

- `GlobalSignalBus`：只放 `run_started`、`level_started`、`player_died` 等少量跨场景过去时事件，目标少于 15 个。
- `RunState`：只保存死亡次数、当前关卡 ID、当前形态 ID 等跨场景运行数据。

不要在 Autoload 中持有玩家、HUD、敌人等场景节点引用；不要在 `_init()` 访问其他 Autoload；不要形成循环依赖。

## 9. 场景流

```text
Main
  -> App bootstrap / 当前关卡
      -> Level
          -> Geometry (TileMapLayer)
          -> Actors
          -> Effects
          -> CameraRig
      -> Interface (CanvasLayer)
```

`Main` 只负责生命周期容器。关卡切换在 `Level`/场景服务中完成，UI 通过总线或父节点信号获得状态，不直接搜索关卡节点。
