# 白模场景设计、功能边界与分工

## 目标

为 48 小时版本建立一个可独立测试、可并行开发的 Godot 4.7.2 白模垂直切片。首个可玩闭环为：玩家移动与形态变化 → 进入资源或毒区 → 操作机关 → 打开出口 → 死亡后从检查点重置。

本设计遵循“状态归属唯一、命令向下调用、事实向上发 signal”。表示层只订阅状态变化，不修改玩法状态；`GlobalSignalBus` 只承载跨场景生命周期事件。

## 场景与目录边界

```text
scenes/
  app/
    main.tscn                         启动壳：承载当前关卡和全局界面
  levels/
    whitebox_sandbox.tscn             首个可玩垂直切片
    whitebox_sandbox.gd               关卡接线、检查点、重置、完成
features/
  player/
    player.tscn                       唯一可复用 CharacterBody2D 玩家
    player.gd                         玩家组合根，仅负责输入与组件接线
    movement_controller.gd            物理移动、coyote time、jump buffer
  forms/
    form_definition.gd                形态静态 Resource
    form_catalog.gd                   形态查询
    form_state.gd                     运行时形态/稳定度数据
    form_controller.gd                形态变更唯一入口
    resource_absorber.gd              连续资源吸收
  abilities/
    ability_definition.gd             能力静态 Resource
    ability_controller.gd             门槛、冷却与施放流程
  level/
    nutrition_tank.tscn/.gd           营养液资源点
    toxin_zone.tscn/.gd               毒区范围检测
    hazard.tscn/.gd                   伤害/死亡事实报告
    checkpoint.tscn/.gd               检查点激活与出生点标识
    whitebox_switch.tscn/.gd          机关状态
    exit_device.tscn/.gd              出口开启条件与完成触发
    interactable.gd                   可交互节点的公共基类/契约
```

不将 `2.0/` 嵌套工程、场景节点引用或 UI 状态纳入根项目的白模实现。

## 场景树

### `main.tscn`

```text
Main (Node2D)
  LevelHost (Node2D)                  当前关卡的唯一挂载点
    WhiteboxSandbox (实例)
  Interface (CanvasLayer)             HUD/暂停/结果界面的宿主
  Debug (Node)                        仅开发期诊断；不承载玩法
```

`Main` 不搜索或操控关卡内机关。它仅实例化/替换 `LevelHost` 的关卡，并在关卡开始或完成时转发跨场景生命周期事件。

### `whitebox_sandbox.tscn`

```text
WhiteboxSandbox (Node2D, whitebox_sandbox.gd)
  Geometry (Node2D)
    Ground (TileMapLayer)             World 层；地面、墙、单向平台
    MovingPlatforms (Node2D)          AnimatableBody2D，sync_to_physics=true
  Actors (Node2D)
    Player (Player 实例)              Player 层
  Interactions (Node2D)
    NutritionTank (实例)              Interactable 层
    ToxinZone (实例)                  Interactable 层，检测 Player
    SwitchA (实例)                    Interactable 层
    ExitDevice (实例)                 Interactable 层
  Hazards (Node2D)
    FallHazard (Hazard 实例)          Hazard 层，检测 Player
  Checkpoints (Node2D)
    StartCheckpoint (Checkpoint)     默认出生点
    MidCheckpoint (Checkpoint)       关卡内检查点
  CameraRig (Node2D)
    Camera2D                          跟随玩家；边界由关卡设置
  Presentation (Node2D)               仅关卡内 VFX/提示，不保存玩法状态
```

`Geometry` 使用 `TileMapLayer`/`TileSet` 管理静态碰撞和单向平台；不要用大量独立 `Sprite2D` 拼接碰撞。可移动平台必须是 `AnimatableBody2D` 并同步物理。

### `player.tscn`

```text
Player (CharacterBody2D, player.gd)
  CollisionShape2D
  Visuals (Node2D)
  StateMachine (Node)
  Movement (Node, movement_controller.gd)
  FormController (Node, form_controller.gd)
  AbilityController (Node, ability_controller.gd)
  ResourceAbsorber (Node, resource_absorber.gd)
  CameraTarget (Marker2D)
```

`Player` 是组合根，不保存移动、形态或能力内部算法。所有玩家形态复用此一个场景；形态差异由 `FormDefinition` 和局部视觉/碰撞配置表达，不复制玩家场景。

## 状态所有权与通信

| 状态/事实 | 唯一所有者 | 允许修改者 | 对外通知 |
| --- | --- | --- | --- |
| 速度、跳跃缓冲、土狼时间 | `MovementController` | `MovementController` | 本地移动/落地 signal（如需要） |
| 当前形态、稳定度、成长/毒素进度 | `FormState`，由 `FormController` 管理 | `FormController` 与资源入口 | `form_changed`、`form_change_rejected` |
| 能力冷却与施放结果 | `AbilityController` | `AbilityController` | `ability_used`、`ability_rejected` |
| 单个机关开关状态 | `WhiteboxSwitch` | `activate()` / `deactivate()` | `activated`、`deactivated` |
| 出口开启状态 | `ExitDevice` | `ExitDevice`（根据已注册机关） | `opened` |
| 本关检查点 | `WhiteboxSandbox` | `checkpoint_reached` 处理器 | 无需全局事件 |
| 跨场景关卡 ID、选择形态、死亡计数、检查点 ID | `RunState` | 关卡生命周期协调者 | 按需查询，不保存 Node |
| 跨场景生命周期 | `GlobalSignalBus` | 关卡/启动壳 | `level_started`、`player_died`、`level_completed` 等过去时事件 |

场景内连接关系：

```text
ToxinZone.actor_entered/exited -> Player 的毒区入口
NutritionTank 吸收请求       -> Player 的公开资源入口
Checkpoint.checkpoint_reached -> WhiteboxSandbox 更新本地检查点
Hazard.actor_killed           -> WhiteboxSandbox.reset_level()
WhiteboxSwitch.activated      -> ExitDevice 重新评估开启条件
ExitDevice.opened + 玩家抵达  -> WhiteboxSandbox.complete_level()
WhiteboxSandbox 完成/死亡     -> GlobalSignalBus（仅生命周期事实）
```

禁止 `ToxinZone`、`Hazard`、`Checkpoint` 直接改写玩家字段；禁止 `ExitDevice` 搜索场景树查找机关或玩家。关卡组合根负责获取实例并完成本地接线。

## 碰撞层

| 层 | 节点类别 | 检测目标 |
| --- | --- | --- |
| 1 World | `TileMapLayer`、移动平台 | Player |
| 2 Player | `Player` 本体 | World、移动平台 |
| 6 Hazard | `Hazard` | Player |
| 7 Interactable | 毒区、资源点、机关、检查点、出口 | Player |

战斗相关的第 3 至第 5 层保留给未来模块，但白模不实例化敌人或战斗节点。

## 并行分工

| 工作流 | 责任范围 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| A：形态与资源 | `features/forms/` | Resource、运行时状态、形态控制、模型测试 | 无 | 单元测试；无场景依赖 |
| B：玩家与能力 | `features/player/`、`features/abilities/` | 单一玩家场景、移动、能力控制、玩家/能力测试 | A 的公开形态 API | 玩家场景 F6；单位测试 |
| C：关卡交互 | `features/level/` | 毒区、资源点、机关、陷阱、检查点、出口、交互测试 | 仅 Player 公开资源/重置 API | 各实体场景 F6；交互测试 |
| D：本分支架构/集成 | `scenes/app/`、`scenes/levels/`、必要的 `autoloads/` | 启动壳、白模关卡、局部接线、重置/完成、项目验收 | A/B/C 的已文档化 API | F5、白模场景 F6、手动闭环 |
| E：UI（后置） | `features/ui/` | HUD、暂停、结果展示 | A/B/D 的 signal | UI 场景 F6；不修改玩法状态 |

跨分工只能通过 `docs/api/*.md` 中的公开方法和 signal 协作。修改公共 API 的工作流必须同步更新该文档；其他工作流不得直接修改对方功能目录。

## 实施顺序

1. A 完成 `FormDefinition`、`FormState`、`FormController` 的无场景测试契约。
2. B 完成 `Player` 的公开入口、移动和能力门槛；C 可同时实现不依赖玩家内部字段的交互节点。
3. C 与 B 对齐资源吸收、毒区进入/离开、死亡和重置的公共 API。
4. D 创建白模关卡结构、静态 `TileMapLayer` 几何和实例化接线；必要时仅扩充生命周期事件和 `RunState` 的纯数据字段。
5. D 按闭环验收，再由 E 以订阅信号的方式补 HUD/结果展示。

## 白模验收清单

- 每个可复用实体场景可单独 F6 启动，不依赖当前关卡的节点路径。
- 玩家使用 `velocity` 和 `_physics_process()` + `move_and_slide()`；保留跳跃缓冲、土狼时间和可变跳高。
- 进入/离开毒区会通过公开入口改变形态系统状态；毒区本身不保存玩家状态。
- 营养液、毒素、机关和出口的状态变化有清晰、即时的白模反馈。
- 触发陷阱后只由 `WhiteboxSandbox` 执行重置；最近检查点和关卡内机关状态按设计恢复。
- 出口仅在登记的机关满足条件且玩家到达出口后完成关卡。
- F5 项目启动、白模场景 F6、所有纯逻辑单元测试和 `git diff --check` 均通过。
