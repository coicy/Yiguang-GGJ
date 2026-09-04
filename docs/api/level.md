# 白模关卡 API

## 职责

白模关卡负责组合实体、维护检查点、响应出口完成和执行关卡重置。它不实现玩家移动、形态状态或具体机关算法。当前白模外壳不实例化或搜索 `Player`；`Actors/PlayerAnchor` 是未来玩家接入时使用的出生位置标记。

## 公共类型

### `WhiteboxSandbox : Node2D`

```gdscript
func reset_level() -> void
func complete_level() -> void
func get_checkpoint_position() -> Vector2
```

`reset_level()` 只恢复关卡拥有的临时机关状态，并将 `PlayerAnchor` 移到最近检查点；它不改写尚未接入的玩家。`complete_level()` 只在出口开放时发出 `GlobalSignalBus.level_completed(level_id)`。未来玩家到达出口的检测应由场景内接线调用该方法。

## 场景边界

```text
WhiteboxSandbox
  Geometry
    Ground (TileMapLayer)
  Actors
    PlayerAnchor (Marker2D)
  Interactions
    NutritionTank (NutritionTank)
    ToxinZone (ToxinZone)
    SwitchA (WhiteboxSwitch)
    ExitDevice (ExitDevice)
  Hazards
    FallHazard (Hazard)
  Checkpoints
    StartCheckpoint (Checkpoint)
    MidCheckpoint (Checkpoint)
  CameraRig
    Camera2D
  Presentation
```

`Main` 只负责启动壳和生命周期容器。白模关卡通过本地引用连接场景内系统，跨场景生命周期事件才使用 `GlobalSignalBus`。

### `YiguangWhitebox : Node2D`

`yiguang_whitebox.tscn` 根据 `Yiguang.json/Level_0` 的 45×30 IntGrid 和实体坐标构建。运行时使用 `TileMapLayer` 提供 Ground/HardFloor 碰撞，Damage 格由 `Hazard` 提供检测；被移动块占据的固定网格碰撞会排除，避免机关移动后残留不可见墙体。

公开方法：

```gdscript
func get_player() -> Player
func get_checkpoint_position() -> Vector2
func respawn_player() -> void
func restart_level() -> void
func elapsed_time() -> float
func is_completed() -> bool
```

## 白模布局

`PlayerAnchor` 和 `StartCheckpoint` 位于 `(96, 576)`；`MidCheckpoint` 位于 `(640, 576)`；`NutritionTank`、`ToxinZone`、`SwitchA`、`ExitDevice` 分别位于 `(352, 560)`、`(560, 560)`、`(832, 560)`、`(1120, 560)`；`FallHazard` 位于路线上的 `(960, 576)`。`SwitchA` 与 `ExitDevice` 保持逻辑 `Node` 根，并通过各自的 `PositionMarker` 和 `Polygon2D` 子节点表达白模位置和可视标识。场景使用无素材的 `Polygon2D` 与 `StaticBody2D` 表示可见、可碰撞的地面和平台；它不实例化临时 `Player`。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-05 | 0.4 | 增加依据 Yiguang Level_0 数据生成的完整可玩白膜关卡。 |
| 2026-09-04 | 0.3 | 补充资源、毒区、中点检查点及可见白模布局。 |
| 2026-09-04 | 0.2 | 明确玩家无关的沙盒外壳、锚点重置和出口完成条件。 |
