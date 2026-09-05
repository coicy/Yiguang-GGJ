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

### Phantom Camera：运行时镜头约束

版本锁定：Phantom Camera `0.11.0.3`，固定上游提交 `cb6e0966ac305202c47f1d1a81c105966e29da96`。

来源/所有者：[ramokz/phantom-camera](https://github.com/ramokz/phantom-camera)，官方文档：[phantom-camera.dev](https://phantom-camera.dev/)，许可证：MIT。该版本的发布说明包含 Godot 4.7.1 兼容性修复；已在本项目 Godot 4.7.2 headless 启动与场景集成测试中验证。

用途：`PhantomCamera2D` 提供 Framed Follow 跟随、可调水平/垂直死区、水平 look-ahead 与平滑插值；`CameraBounds` 仍是关卡边界真值，关卡脚本会同步设置 Phantom Camera 与备用 `Camera2D` 的四向限制。`PhantomCameraHost` 负责把活动 Phantom 相机接入场景中的 `Camera2D`。

运行时集成：插件目录为 `addons/phantom_camera/`，并注册 `PhantomCameraManager` Autoload；当前仅使用 GDScript，不引入 GDExtension 或外部二进制。关卡场景保留普通 `Camera2D` 作为可回退路径。

移除路径：删除 `addons/phantom_camera/`；从 `project.godot` 的 `[autoload]` 移除 `PhantomCameraManager`，从 `[editor_plugins]` 移除插件条目；删除关卡中的 `PhantomCameraHost`/`PhantomCamera2D` 节点及 `handbuilt_level.gd` 对 Phantom Camera 的同步代码。保留的 `Camera2D + CameraBounds` 可继续提供基础跟随和边界。

### 已筹备运行时：spine-godot GDExtension

版本锁定：Spine runtime 4.3，Godot 4.7-stable，官方包 `spine-godot-extension-4.3-4.7-stable.zip`。

来源/所有者：Esoteric Software；下载地址：<https://spine-godot.s3.eu-central-1.amazonaws.com/4.3/4.7-stable/spine-godot-extension-4.3-4.7-stable.zip>。

用途：加载本仓库 `part1/m10067`、`part2/p0003` 与 `part3/p0003` 的 Spine 4.3.23 JSON/Atlas 数据。当前素材来自用户提供的替换包 `part1(1).zip`、`part2(1).zip`、`part3(2).zip`。GDExtension 已解包至项目根目录 `bin/`；运行时通过 `.spine-json`、共享 `SpineSkeletonDataResource` 和 `SpineSprite` 接入，不使用 GDExtension 未提供的 `SpineAnimationTrack`。

已导入动画：

| 资源 | 动画（时长，秒） | 默认循环 |
|---|---|---|
| `part1/m10067` | `death` 0.40、`idle` 1.00、`move` 0.53 | `idle`、`move` |
| `part2/p0003` | `death` 0.40、`idle` 1.00、`jump_down` 0.50、`jump_end` 0.50、`jump_start` 0.50、`jump_up` 0.50、`move` 0.67、`skill` 2.17 | `idle`、`move` |
| `part3` | `death` 0.40、`idle` 1.00、`jump_down` 0.13、`jump_end` 0.23、`jump_start` 0.07、`jump_up` 0.10、`move` 0.67、`skill` 2.17 | `idle`、`move` |

`part2/skill` 在动画约 1.17 秒处包含 `skill` 事件，`part3/skill` 在约 1.10 秒处包含同名事件。三份替换 Atlas 的图片引用均与实际文件名一致，且不再声明 `pma:true`。

玩家表现层使用 `PlayerAnimationMachine` 映射玩法状态，不让动画反向驱动物理：`idle -> idle`、`run -> move`、`jump -> jump_start/jump_up`、`fall/glide -> jump_down`，从空中回到地面时先播 `jump_end`；能力开始时用 `skill` 临时覆盖并在完成后返回最新移动状态，`death` 为最高优先级直到显式复活。幼芽期素材不含跳跃和技能片段，缺失动画会回退至 `idle` 或 `move`。形态与视觉对应关系为 `sprout -> part1`、`humanoid -> part2`、`mature -> part3`。

兼容性：当前项目为 Godot 4.7.2、GDScript、GL Compatibility；已准备 Windows x86_64 编辑器与导出库，同时保留包内其他平台库。运行时集成与最终发布必须确认 Spine 编辑器/运行时授权。

移除路径：删除项目根目录 `bin/` 下的 `spine_godot_extension.gdextension` 与 `libspine_godot.*` 文件，移除 `assets/runtime/characters/part1/`、`assets/runtime/characters/part2/`、`assets/runtime/characters/part3/` 和 `features/player/visuals/*spine*`；不影响核心白盒玩法。

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


## 音频离线制作工具（2026-09-06）

维护归属 features/audio 与 tools/build_audio.py。游戏只使用 Godot 4.7.2 原生 AudioStreamPlayer/2D、AudioBusLayout、Limiter、Compressor 与 WAV/Ogg；没有新增 Godot addon。

上游制作环境的离线依赖安装在被忽略的 build/audio/tools（本次合并未在本机安装）：SciPy 1.17.0（BSD-3-Clause）、SoundFile 0.13.1（BSD-3-Clause；libsndfile 为 LGPL-2.1-or-later）、imageio-ffmpeg 0.6.0（BSD-2-Clause，捆绑 FFmpeg 遵循其构建许可），NumPy 2.5.2（BSD-3-Clause）。来源分别为 scipy.org、python-soundfile.readthedocs.io、github.com/imageio/imageio-ffmpeg、numpy.org；通过 PyPI 官方包下载。只用于本地裁切、滤波、变速、解码、转码和客观检查，不随游戏分发。

构建：Python tools/build_audio.py；质检：Python tools/check_audio.py。当前 Windows 上 libsndfile 的 Ogg 编码发生堆栈溢出，因此配乐编码使用 FFmpeg libvorbis；SoundFile 仅负责安全通过验证的读取和 WAV 写入。

本分支只接入 SoundEmitter、AudioPalette、默认混音总线及 PlayerAudio 兼容反馈；不接入 GreenhouseSoundscape、EnemyAudio 或新战斗控制。移除离线依赖不影响游戏运行；撤销音频更新时恢复 SoundEmitter/PlayerAudio 旧版并删除新 palette 和总线配置。完整来源见 docs/credits.md；上游音频设计归档于 docs/backup/main_20260906/audio_design.md，当前验证见 docs/merge_main_20260906.md。
