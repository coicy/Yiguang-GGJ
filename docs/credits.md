# Credits

本版使用已有素材分支 origin/lan 的 a591027 提交中的 19 个音效文件，保留原始文件名与音频字节。以下来源与 CC0 标识已在 2026-09-05 对照 Kenney 官方页面核实。

| 项目 | 来源/作者 | 许可证 | 用途 | 文件位置 |
|---|---|---|---|---|
| 一阶段角色 `m10067` Spine 素材 | 用户提供的替换包 `part1(1).zip`；原作者待补充 | 待确认 | 幼芽期角色图集、骨骼与动画素材；已导入共享 Spine 资源及视觉场景 | `assets/source/part1/`、`assets/runtime/characters/part1/`、`features/player/visuals/part1_spine_visual.tscn` |
| 二阶段角色 `p0003` Spine 素材 | 用户提供的替换包 `part2(1).zip`；原作者待补充 | 待确认 | 人形期角色图集、骨骼与动画素材；已导入共享 Spine 资源及视觉场景 | `assets/source/part2/`、`assets/runtime/characters/part2/`、`features/player/visuals/part2_spine_visual.tscn` |
| 三阶段角色 `p0003` Spine 素材 | 用户提供的替换包 `part3(2).zip`；原作者待补充 | 待确认 | 成熟期角色图集、骨骼与动画素材；已导入共享 Spine 资源及视觉场景 | `assets/source/part3/`、`assets/runtime/characters/part3/`、`features/player/visuals/part3_spine_visual.tscn` |
| spine-godot GDExtension | Esoteric Software | 以官方 Spine Runtimes License 为准 | Godot 4.7.2 的 Spine 4.3 运行时 | `bin/` |
| 场景 PNG 素材 | 用户提供的 `png.zip`；原作者待补充 | 待确认 | Level 01 地形、机关与环境装饰 | `assets/source/scenery_png/png/`、`assets/runtime/scenery/` |
| 荆棘与小藤蔓 PNG 素材 | 用户提供的 `png-1.zip`；原作者待补充 | 待确认 | 荆棘危险机关与藤蔓环境装饰 | `assets/source/scenery_png/png-1/`、`assets/runtime/scenery/` |
| Grow / UnGrow 罐子素材 | 用户提供的 `罐子.zip`；原作者待补充 | 待确认 | 绿色成长罐与紫色退化罐 | `assets/source/tanks/`、`assets/runtime/scenery/grow_tank.png`、`assets/runtime/scenery/ungrow_tank.png` |
| Phantom Camera `0.11.0.3` | [Marcus Skov / ramokz](https://github.com/ramokz/phantom-camera) | MIT | 2D 镜头跟随、可调死区、关卡边界与插值 | `addons/phantom_camera/` |

## 音频素材

| 素材包 / 作者 | 许可证 | 使用文件（位于 assets/runtime/audio/） | 游戏用途 |
| --- | --- | --- | --- |
| [Impact Sounds / Kenney](https://kenney.nl/assets/impact-sounds) | CC0 | footstep_grass_000/001/002.ogg、footstep_concrete_000/001.ogg、impactSoft_medium_000.ogg、impactSoft_heavy_000.ogg、impactWood_medium_000.ogg | 脚步、落地、死亡、平台停止 |
| [RPG Audio / Kenney](https://kenney.nl/assets/rpg-audio) | CC0 | cloth1.ogg、cloth2.ogg、clothBelt.ogg、beltHandle1.ogg、metalLatch.ogg、creak1.ogg、handleCoins2.ogg | 跳跃、滑翔、伸腿、扎根、藤蔓、机关启动、吸收 |
| [UI Audio / Kenney](https://kenney.nl/assets/ui-audio) | CC0 | click3.ogg | 按钮触发 |
| [Music Jingles / Kenney](https://kenney.nl/assets/music-jingles) | CC0 | jingles_PIZZI00.ogg、jingles_PIZZI02.ogg、jingles_PIZZI06.ogg | 检查点、成长、枯萎 |

未从素材分支取用其标记为“待确认”的音乐和音效。对外发布前须完成外部内容的来源、作者和许可证登记；当前本地验证保留用户提供的角色与场景资产，其待确认状态不会因导入、制作新动作或生成测试构建而改变。

事件映射与音量位于 features/audio/sound_emitter.gd；玩家步频与吸收音间隔位于 features/player/player_audio.gd。各实例使用固定数量的声音通道，不修改共享 AudioStream 资源，不每帧重复启动声音。

## 出口与 HUD 复用素材（2026-09-06）

本轮从已有素材分支 `origin/feat/coicy` 的固定提交 `8ca691b7776454f695985d414962bfe05844b098` 精选导入以下文件；图片、音频和字体保留原始字节，运行时副本位于 `assets/runtime/ui/`。没有整合该分支的 Godot 3 工程或 Spine 插件。

| 原分支路径 | 本地文件 / 用途 | 许可依据 |
| --- | --- | --- |
| `2.0/Objects/Teleporter/Assets/Door.png` | `exit_door.png`：关卡出口与胜利图标 | 原仓库 MIT，Copyright (c) 2022 Finn |
| `2.0/Objects/Teleporter/Assets/Jump Prompt.png` | `jump_prompt.png`：操作提示图标 | 同上 |
| `2.0/Objects/DialogArea/Assets/Sign.png` | `sign.png`：出口路牌 | 同上 |
| `2.0/Objects/BlockSwitch/Assets/Lever1.png`、`Lever2.png` | `lever_off.png`、`lever_on.png`：出口目标状态 | 同上 |
| `2.0/UI/CoinCounter/Win.wav` | `win.wav`：胜利音效 | 同上 |
| `2.0/Fonts/yoster.ttf` | `yoster.ttf`：计时数字 | codeman38 / zone38.net，随附字体许可 |

原仓库 MIT 全文保存在 [ASSET_LICENSE.txt](../assets/runtime/ui/ASSET_LICENSE.txt)；字体许可全文保存在 [FONT_LICENSE.txt](../assets/runtime/ui/FONT_LICENSE.txt)，字体未修改，作者为 codeman38。中文使用 Godot 默认字体回退。`features/ui/game_ui_theme.tres` 将同一提交中 `2.0/UI/DialogBox/DialogBox.tscn` 与 `2.0/UI/AnimatedButton/AnimatedButton.tres` 的紫色、桃色面板配色适配为 Godot 4 Theme，许可同原仓库 MIT。

## 正式关卡 HUD（2026-09-06）

| 素材 / 作者 | 来源与版本 | 许可 | 用途 |
| --- | --- | --- | --- |
| UI Pack - Adventure / Kenney | [官方页面](https://kenney.nl/assets/ui-pack-adventure)，1.0 | CC0；随附 KENNEY_ADVENTURE_LICENSE.txt | 米白木框面板、形态圆框 |
| Input Prompts / Kenney | [官方页面](https://kenney.nl/assets/input-prompts)，官方 1.5 下载包（页面标识 1.5a） | CC0；随附 KENNEY_INPUT_LICENSE.txt | A/D/E/R 图标；Q、空格与战斗操作使用原生文字键帽／提示 |
| Noto Sans SC / Adobe、Google Noto | [Google Fonts 源文件](https://github.com/google/fonts/tree/main/ofl/notosanssc)，2026-09-06 下载 | SIL OFL 1.1，随附 OFL.txt；字体字节未修改 | HUD 简体中文和数字 |
| 三形态头像 | 从本项目既有 Spine 角色渲染静态帧 | 沿用上方角色素材许可 | 当前形态圆框图标 |

以上运行时文件位于 assets/runtime/ui/botanical/。仅引入使用中的 PNG 与字体，不安装菜单插件；handbuilt_hud.tscn 与 botanical_theme.tres 使用 Godot 4.7.2 原生 CanvasLayer、Control、Container、Theme。维护归属为 features/ui；移除 level_01.tscn 的 Interface 和 handbuilt_level.gd 的 HUD 绑定、恢复罐子的 show_world_prompt 后，即可删除这批 HUD 文件，不影响角色移动与吸收逻辑。

## 正式战斗系统新增资产（2026-09-06）

| 素材 | 来源与制作 | 运行时位置 | 原始文件与许可状态 |
| --- | --- | --- | --- |
| 污染甲虫、孢子囊、修枝机兵、守圃者四张部件图集 | 本次使用 OpenAI 图像生成工具，按项目设计新生成，由 Codex 配置分部件动画；不冒称手绘作者 | assets/runtime/enemies/{beetle,spore,pruner,warden}_atlas.png | 原始 PNG 已归档于 assets/source/combat/*_atlas_source.png；未另行宣称 CC0 或 MIT 授权 |
| 温室背景 | 本次为本项目 AI 生成的宽幅场景图 | assets/runtime/scenery/greenhouse_background.png | assets/source/combat/greenhouse_background_source.png；未另行宣称第三方开源许可 |
| 可平铺苔藓地面 | 以用户提供的 `_0036_苔藓地1.png` 为参考，通过 imagegen 编辑生成的 AI 衍生素材 | assets/runtime/scenery/greenhouse_ground.png | assets/source/combat/greenhouse_ground_source.png；继承原场景素材的作者／发布许可待确认状态，不声明完全独立原创 |
| 两形态新战斗姿势 | 本项目配置的骨骼角度、阶段时间与插值动作，叠加到既有 Spine 骨骼 | features/combat/data/humanoid_poses.tres、mature_poses.tres | 可编辑 Godot 资源；不是新 Spine 原工程，角色基础素材许可继续待确认 |
| 藤鞭、命中、弹反、闪避、敌人预警与战斗 UI | 本项目 Godot 原生绘制、节点和资源配置 | features/combat/、features/enemies/、features/ui/combat_hud.* | UI 字体、已有面板及角色头像仍沿用上方来源 |

每张敌人原始 PNG 为 1254 × 1254 的 2 × 2 部件图集，温室背景为 2172 × 724，苔藓地面衍生图为 1774 × 887。地面通过静态 AtlasTexture 裁去顶部 98 像素，使用 Rect2(0, 98, 1774, 789) 的平直顶缘对齐地形碰撞；裁切不改变其衍生来源。原始 PNG 可继续编辑，运行时把图集各格作为独立部件裁切；未交付 PSD 多图层工程或新的 Spine 编辑器源工程。完整文件映射和制作边界见 [战斗资产制作说明](../assets/source/combat/production_notes.md)。

战斗音效全部复用上方已登记音频：clothBelt 用于挥空，impactSoft_medium/heavy 用于轻／重命中，metalLatch 用于格挡，jingles_PIZZI00 用于弹反，cloth2 用于闪避，impactWood_medium 用于受伤，beltHandle1／creak1 区分普通预警与危险预警。事件映射位于 features/audio/sound_emitter.gd；这些是复用和接线，不登记为新录制音效。

旧角色、地形和场景素材仍需确认原作者与发布许可。实际试玩、美术检查和导出验证状态见 [战斗验证记录](combat_validation.md)，本来源表不代表相关验收已经完成。


## 藤蔓攻击独立素材与动画（2026-09-06）

| 素材 / 制作 | 来源与文件 | 许可与交付说明 |
| --- | --- | --- |
| 九部件藤蔓图集 | 本轮使用内置 OpenAI ImageGen，以用户既有人形、成熟形态头像为风格参考；原图 assets/source/combat/vine_attack/vine_parts_source.png，运行时副本 assets/runtime/combat/vine_attack/vine_parts_atlas.png | AI 衍生素材；参考角色的原作者与发布许可仍待确认，不新增 CC0 或 MIT 声明。实际为 1254 × 1254 RGB PNG，无 alpha 通道；保留原始位图，通过 vine_cutout.gdshader 在游戏渲染时去除亮色低色度背景 |
| 两形态十套藤蔓动画与柔性骨骼 | 本项目 Godot Skeleton2D / Bone2D / Polygon2D 场景及 AnimationPlayer 关键帧；features/combat/visuals/vine_whip_visual.tscn、features/combat/data/vine_attack/ | 可编辑 Godot 场景、AnimationLibrary、Animation 与外形 Resource；不是新 Spine 编辑器工程或 PSD 分层源 |
| 两形态攻击发力与挂点同步 | humanoid_poses.tres、mature_poses.tres 的逐骨骼时序与肘腕姿势，SpineCharacterVisual 的世界骨骼更新后手部信号 | 叠加到已有角色骨骼，沿用原角色素材许可状态；不修改原角色图集或改变其来源 |

生成器两稿都未提供 alpha，第二稿未采用。原图与运行时图集都不能登记为透明源 PNG；游戏中的透明轮廓依赖 features/combat/visuals/vine_cutout.gdshader，属于相对原计划的交付方式调整。完整制作过程、可编辑入口及已确认的身体/挂点验证见 [藤蔓攻击制作记录](../assets/source/combat/vine_attack/production_notes.md)。本条补充并取代上方“藤鞭使用原生绘制”的旧藤鞭来源描述；命中、弹反、闪避等其它已登记表现仍沿用各自来源。


## 正式地形十件部件与二十张原图复用（2026-09-06）

| 资源 | 来源与制作 | 可编辑源／运行时位置 | 许可与说明 |
|---|---|---|---|
| 建筑图集六件：drain、catwalk、culvert、pipe、buttress、core_plinth | 本项目使用OpenAI ImageGen新生成；初稿为RGB棋盘背景，随后由ImageGen编辑清底为RGBA | assets/source/terrain/architecture_kit_source.png、architecture_kit_alpha.png；assets/runtime/terrain/architecture_kit.png及parts/*.tres | AI生成与编辑；不另行声明CC0／MIT，也不冒称人工分层原画 |
| 生态图集四件：root_soil、fungal_log、seedling_tray、broken_planter | 本项目使用OpenAI ImageGen新生成并编辑清底；初稿1254×1254 RGB，最终1536×1024 RGBA | assets/source/terrain/ecology_kit_source.png、ecology_kit_alpha.png；assets/runtime/terrain/ecology_kit.png及parts/*.tres | 最终裁切以RGBA版轮廓为准；不把画布变化描述为原图像素完全不变的处理 |
| 旧植物与垂坠图十张 | 用户此前提供的png.zip；_0001_草团2、_0003_红花2、_0004_针草1、_0005_针草2、_0010_藤蔓3、_0012_高草2、_0013_高草3、_0020_爬墙藤、_0040_垂坠1、_0041_垂坠2 | assets/source/scenery_png/png/至assets/runtime/scenery/，均保留.png原名 | 原样复用，内容相同；原作者与公开发布许可待确认 |
| 旧设施图三张 | 同一用户素材包；_0015_培养罐、_0016_量杯、_0017_锥形瓶1 | 同上 | 原样复用，原许可待确认 |
| 旧承托／板底／坡面图七张 | 同一用户素材包；_0025_根部延申、_0027_图层-57、_0029_石板、_0032_底面地板、_0033_底面地板、_0034_水泥板、_0035_草地坡 | 同上 | 原样复用，原许可待确认；不计为新生成地形 |

两张runtime图集均原样复制ImageGen的alpha编辑版，已核对内容相同；没有用Python或其他工具修改像素。RGBA版的低alpha柔光在Godot渲染时由terrain_cutout.gdshader以0.85阈值处理。材质保留默认CanvasItem受光，以兼容上游PointLight2D与遮光设计。

七套TerrainSurface、TerrainSkin、十个部件AtlasTexture均为本项目Godot资源与代码配置；没有新增PSD／Spine编辑器工程。branch_run.tres另从已有_0026_树枝平台（延申）.png裁取实心长杆中段，属于旧图复用，沿用原许可待确认状态，不是第十一件新生成素材。原素材及其AI衍生设计的来源依赖不会因裁切、重新组合或导出构建而消失。逐项尺寸、裁切坐标、清底过程与验证证据见[地形资产制作记录](../assets/source/terrain/production_notes.md)。


## 音频重制（2026-09-06）

下表取代上文“战斗音效全部复用”的现状描述；原 Kenney 素材仍保留作声源与兼容文件。

| 来源 / 作者 | 页面与许可 | 用途与修改 |
|---|---|---|
| 80 CC0 RPG SFX / rubberduck | https://opengameart.org/content/80-cc0-rpg-sfx · CC0 1.0 | 生物、刀刃、木、链、金属、魔法、宝石；离线裁切、滤波、变速、分层 |
| 100 CC0 SFX #2 / rubberduck | https://opengameart.org/content/100-cc0-sfx-2 · CC0 1.0 | 空气、脚步、金属、门、机械、水与环境；同上 |
| 40 CC0 water / splash / slime SFX / rubberduck | https://opengameart.org/content/40-cc0-water-splash-slime-sfx · CC0 1.0 | 气泡、黏液、水流、喷溅；同上 |
| Dark Forest Theme / The Cynic Project (cynicmusic) | https://opengameart.org/content/dark-forest-theme · CC0 1.0 | 探索配乐；响度调整、首尾接合、Ogg 编码 |
| Battle Theme A / The Cynic Project (cynicmusic) | https://opengameart.org/content/battle-theme-a · CC0 1.0 | 已撤下；原始下载仅保留于制作源，不进入播放列表 |
| Battle Theme B for RPG / The Cynic Project (cynicmusic) | https://opengameart.org/content/battle-theme-b-for-rpg · CC0 1.0 | 已由下列新首领曲替换；原始下载仅保留于制作源 |
| Battle Theme / Wolfgang_ | https://opengameart.org/node/16611 · CC0 1.0 | 普通战斗变体一；响度调整、首尾交叠与 Ogg 编码 |
| Ghosts & Heroes (2025 loop) / Bobjt | https://opengameart.org/content/ghosts-heroes · CC0 1.0 | 普通战斗变体二；作者循环版，响度调整、接点修正与 Ogg 编码 |
| Heartfelt Battle (loop) / request | https://opengameart.org/content/heartfelt-battle-loopable-fantasy-stringspianohorn · CC0 1.0 | 普通战斗变体三；作者循环版，同上 |
| Epic Boss Battle [Seamlessly Looping] / Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/boss-battle-music · CC0 1.0 | 新首领曲；作者循环版，同上 |

作者署名：rubberduck / OpenGameArt.org；The Cynic Project / cynicmusic.com / pixelsphere.org；Kenney.nl。CC0 1.0 许可：https://creativecommons.org/publicdomain/zero/1.0/ 。本次使用的是上述独立资源页明确标注 CC0 的下载，不推定作者网站其他作品同样免费。

分层音效与循环素材位于 assets/runtime/audio/designed/，配方与每层所用原始文件见 assets/source/audio/recipes.json。原始下载与来源页保存在 assets/source/audio/。没有使用《空洞骑士》原始音频或旋律，也没有把这些音频标注为生成式 AI 输出。背景音乐作者署名不会因转码而改变。
