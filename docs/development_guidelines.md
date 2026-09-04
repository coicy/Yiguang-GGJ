# 开发规范

## 命名

- 文件、目录、导出变量、方法、signal：`snake_case`。
- 节点名、类名：`PascalCase`。
- 常量：`UPPER_SNAKE_CASE`。
- signal 使用过去时，例如 `health_changed`、`form_changed`、`died`。
- 节点引用优先使用场景唯一名 `%PlayerVisuals`，禁止硬编码绝对 `get_node()` 路径。
- GDScript 新代码必须写类型；项目设置中的 Untyped Declaration 保持 Warn 或 Error。

## 脚本职责

一个脚本只拥有一个主要职责。文件放在它所属的功能目录：

| 文件 | 允许负责的内容 |
|---|---|
| `player.gd` | 组合玩家组件、接线、向子组件下发命令 |
| `movement_controller.gd` | 物理移动与跳跃手感 |
| `state_machine.gd` | 状态进入/退出/转换 |
| `form_controller.gd` | 形态合法性、切换、当前形态运行时副本 |
| `form_definition.gd` | 可序列化形态配置，不运行每帧逻辑 |
| `ability_controller.gd` | 冷却、施放、取消和能力事件 |
| `damage_request.gd` | 一次伤害请求的纯数据，不是 Node |
| `level.gd` | 关卡内出生点、完成条件、局部规则 |
| `hud.gd` | 展示状态、响应输入，不拥有玩法数据 |

## 数据与 Resource

- 设计师需要在 Inspector 调整的数据写成 `Resource`，例如 `FormDefinition`、`AbilityDefinition`、`EnemyDefinition`。
- 共享 `.tres` 只读使用；运行时修改前必须 `duplicate(true)`，否则会污染资源文件的共享实例。
- Resource 只描述数据，不依赖场景节点，不在里面保存运行时引用。
- 需要每帧更新的对象才用 Node；纯数据包用 `Resource` 或 `RefCounted`。

## 通信规则

- “命令”向下直接调用：`ability_controller.cast()`、`form_controller.switch_to()`。
- “事实”向上发 signal：`cast_started`、`form_changed`、`died`。
- 同一场景的父子关系用本地 signal；跨场景才用 `GlobalSignalBus`。
- 使用 `signal.connect(callable)`，不用旧式字符串连接。
- 不用 signal 驱动父节点对孩子的命令，不让两个系统互相发信号形成环。
- 高频数据（每帧位置、速度）不走全局 signal；直接查询或使用共享状态。

## 输入

玩法代码只读取动作名，不读取具体键位：

`move_left`、`move_right`、`move_up`、`move_down`、`jump`、`switch_form`、`ability_primary`、`attack`、`pause`、`restart`

跳跃的 just-pressed/released 采样必须服务于物理 tick。UI 输入先由 Control 消费，玩法输入在 `_unhandled_input()` 或物理帧查询中处理。以后做重绑定时只改 InputMap，不改玩家脚本。

## 场景与节点

- 可复用实体必须有独立 `.tscn`，通过实例化使用。
- `_init()` 不访问子节点；子节点依赖放到 `@onready` 或 `_ready()`。
- 不在 `_process()` 里打印日志或执行物理移动。
- `queue_free()` 前清理自建的动态 signal 连接和数组/字典引用。
- 视觉节点与碰撞节点分开，缩放碰撞形状前先确认不会破坏法线和地面检测。

## 分支与提交

- 分支建议：`feature/player-movement`、`feature/forms`、`feature/level-01`、`fix/jump-buffer`。
- 一次提交只解决一个可描述的变化，提交信息使用 `type: short description`，例如 `feat: add form definition resource`。
- 不提交 `.godot/`、导出目录、个人编辑器设置和未经授权的素材源文件。
- 每个功能完成后先运行当前场景（F6），再运行项目（F6/F5），最后合并。

## 48 小时决策规则

1. 第一个可玩版本优先：移动、跳跃、一次形态切换、一个可完成关卡。
2. 每次只新增一个会改变玩法的系统；先做垂直切片再扩展内容。
3. 战斗必须能被开关；若在第 24 小时仍不稳定，保留接口并砍掉战斗内容。
4. 不在最后 6 小时更换引擎、渲染器、输入方案或核心插件。
5. 所有可调数字集中在 Resource 或 feature 配置，不散落在脚本魔法数字中。
