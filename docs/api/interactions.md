# 关卡交互 API

## 职责

交互系统提供白模所需的机关、资源、毒素、陷阱、检查点和出口。交互节点通过公开方法接收命令，通过本地 typed signal 广播事实。

## 公共类型

### `Interactable : Node`

```gdscript
signal interaction_succeeded(actor: Node)
signal interaction_rejected(actor: Node, reason: StringName)

func can_interact(actor: Node) -> bool
func interact(actor: Node) -> bool
```

### 资源节点

营养液罐和特殊资源点使用统一吸收契约：

```gdscript
func absorb(actor: Node, amount: float) -> bool
```

吸收必须是连续过程；资源点不能直接修改玩家内部字段，应调用玩家暴露的资源入口。

### `ToxinZone : Area2D`

```gdscript
signal actor_entered(actor: Node)
signal actor_exited(actor: Node)

func is_actor_inside(actor: Node) -> bool
```

毒素区只负责检测范围与报告事实；毒素消耗、速度修正和稳定度规则由玩家/形态状态系统处理。

### `WhiteboxSwitch : Node`

```gdscript
signal activated
signal deactivated

func activate() -> void
func deactivate() -> void
func is_active() -> bool
```

### `ExitDevice : Node`

```gdscript
signal opened

func set_required_switches(count: int) -> void
func register_switch(switch: WhiteboxSwitch) -> void
func is_open() -> bool
```

出口只根据注册机关状态判断是否开启，不搜索场景树寻找玩家或机关。`set_required_switches()` 会将需求数量限制为不小于 0 的整数；注册同一个机关多次不会重复连接。机关状态满足需求时，出口从关闭变为开启并只发出一次 `opened`；若机关随后关闭，出口会回到关闭状态，下一次重新满足需求时可再次发出 `opened`。

### `Checkpoint : Node2D`

```gdscript
signal checkpoint_reached(position: Vector2)

func activate(actor: Node) -> bool
func get_checkpoint_position() -> Vector2
```

### `Hazard : Area2D`

```gdscript
signal actor_hurt(actor: Node)
signal actor_killed(actor: Node)
```

陷阱负责报告碰撞结果；重置由关卡拥有者执行。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-04 | 0.1 | 建立白模交互公共接口。 |
