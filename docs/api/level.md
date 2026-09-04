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
    SwitchA (WhiteboxSwitch)
    ExitDevice (ExitDevice)
  Hazards
    FallHazard (Hazard)
  Checkpoints
    StartCheckpoint (Checkpoint)
  CameraRig
    Camera2D
  Presentation
```

`Main` 只负责启动壳和生命周期容器。白模关卡通过本地引用连接场景内系统，跨场景生命周期事件才使用 `GlobalSignalBus`。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.2 | 明确玩家无关的沙盒外壳、锚点重置和出口完成条件。 |
