# 工具包与依赖决策

## 已选基础工具

### Godot 4.7.2 Stable

项目目录已带有 `Godot_v4.7.2-stable_win64.exe`。项目目标锁定 Godot 4.7，团队成员使用同一小版本打开工程，避免 `.tscn` 和导入器发生无意义变化。

实际采用的成熟能力全部来自引擎：

- `CharacterBody2D` + `move_and_slide()`：玩家与敌人的响应式移动。
- `TileMapLayer` + `TileSet`：关卡几何、单向平台和碰撞。
- `Resource`：形态、能力、敌人和关卡参数的数据资产。
- `AnimationPlayer`/`AnimatedSprite2D`：2D 动画与状态反馈。
- `Camera2D`：平滑跟随、边界和视野预告。
- `Area2D`：伤害区、触发器、Hitbox/Hurtbox，不作为地面真值。
- `AnimatableBody2D`：与物理同步的移动平台。

项目使用 `GL Compatibility`，因为这是 2D Game Jam，优先保证参赛机器和录屏环境的启动兼容性；不需要 Forward+ 的 3D、HDR 或复杂光照。

## 可选第三方工具

### GdUnit4：只用于测试

建议版本：使用与 Godot 4.7 兼容的最新稳定版，并从官方仓库/release 安装到 `addons/gdUnit4/`。它是编辑器/测试期依赖，不进入游戏运行时。

官方仓库：<https://github.com/MikeSchulze/gdUnit4>

适合覆盖：

- `FormDefinition` 的切换条件和默认值。
- `AbilityDefinition` 的冷却与消耗规则。
- `GlobalSignalBus` 的事件契约。
- 小型 `Player` 场景的落地、跳跃缓冲和碰撞集成测试。

当前没有把它下载进仓库，因为目录内没有可验证的插件包，也不应在未确认版本和许可证时把外部代码塞进 48 小时项目。安装后只提交 `addons/gdUnit4/` 以及团队确认过的版本锁定文件。

### 状态机插件：暂不安装

不建议首版加入 LimboHSM 或其他通用 FSM 插件。玩家状态数量有限，项目已预留 `features/player/state_machine.gd` 接口；等状态超过“地面/空中/受击/死亡/能力中”且本地实现开始重复时再评估。这样避免插件 API 成为玩法核心依赖。

### 资源与素材工具：按许可证单独登记

Kenney 等素材包、Aseprite、Blender、Audacity 可以作为制作工具或素材来源，但不应被当作运行时插件。每一批外部素材在 `docs/credits.md` 登记来源、许可证和作者；原始文件放 `assets/source/`，导出文件放 `assets/runtime/`。

## 禁止默认加入的依赖

- 任何未确认支持 Godot 4.7 的插件。
- 为了“以后可能用到”加入的存档、联网、对话、背包框架。
- 会替换物理或输入主循环的插件。
- 运行时从网络下载资源的 SDK。

## 插件引入检查表

引入前必须回答：

1. 该插件是否直接减少当前 48 小时目标的工作量？
2. 是否确认 Godot 4.7.2 兼容、许可证和导出平台？
3. 删除插件后，核心玩法能否仍然启动？
4. 是否写入版本、来源、用途和卸载方式？
5. 是否由一位队员负责升级/故障处理？

任一答案为“否”，就不用这个插件。

## 官方资料入口

- Godot 4.7 文档：<https://docs.godotengine.org/en/4.7/>
- Godot Asset Library：<https://godotengine.org/asset-library/asset>
