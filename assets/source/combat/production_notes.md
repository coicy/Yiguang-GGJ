# 战斗资产制作说明

日期：2026-09-06。本文登记本次为项目新生成及编辑衍生的 AI 图像、可编辑动作资源与实际交付边界。设计清单见 [战斗设计](../../../docs/combat_design.md)，验证事实见 [战斗验证记录](../../../docs/combat_validation.md)，旧素材许可见 [credits](../../../docs/credits.md)。

## 1. 新生成图像档案

以下五张图像由本次工作通过 OpenAI 图像生成工具，按植物／温室战斗题材为本项目生成；由 Codex 组织制作、配置和接入。它们没有被冒称为某位手绘作者的作品，也不是从第三方素材包中重新署名取得的内容。此处不另行宣称生成输出具有 CC0、MIT 或其他未提供的开源许可证。

| 内容 | 原始生成 PNG | 运行时副本 | 规格 |
| --- | --- | --- | --- |
| 污染甲虫部件图集 | [beetle_atlas_source.png](beetle_atlas_source.png) | [beetle_atlas.png](../../runtime/enemies/beetle_atlas.png) | 1254 × 1254，2 × 2 格 |
| 孢子囊部件图集 | [spore_atlas_source.png](spore_atlas_source.png) | [spore_atlas.png](../../runtime/enemies/spore_atlas.png) | 1254 × 1254，2 × 2 格 |
| 修枝机兵部件图集 | [pruner_atlas_source.png](pruner_atlas_source.png) | [pruner_atlas.png](../../runtime/enemies/pruner_atlas.png) | 1254 × 1254，2 × 2 格 |
| 守圃者部件图集 | [warden_atlas_source.png](warden_atlas_source.png) | [warden_atlas.png](../../runtime/enemies/warden_atlas.png) | 1254 × 1254，2 × 2 格 |
| 温室宽幅背景 | [greenhouse_background_source.png](greenhouse_background_source.png) | [greenhouse_background.png](../../runtime/scenery/greenhouse_background.png) | 2172 × 724，宽幅背景 |

源图保存在本目录，实际加载副本保存在 assets/runtime 下。源图归档表示保留可继续编辑的原始 PNG，不表示存在 PSD 图层、画笔历史、生成模型工程或逐帧动画原稿。

### 苔藓地面衍生图

| 原参考素材 | 生成编辑输出／运行时副本 | 规格与来源状态 |
| --- | --- | --- |
| 用户提供的 [_0036_苔藓地1.png](../../runtime/scenery/_0036_苔藓地1.png)，来自旧场景素材包 | [greenhouse_ground_source.png](greenhouse_ground_source.png) ／ [greenhouse_ground.png](../../runtime/scenery/greenhouse_ground.png) | 1774 × 887；由原图经 imagegen 编辑生成可平铺地面，继承原场景素材的作者／发布许可待确认状态 |

这张地面图是已有用户素材的 AI 衍生作品，不作为完全独立原创重新署名，也不另行宣称 CC0／MIT 许可。静态场景内的 AtlasTexture 使用 Rect2(0, 98, 1774, 789)，裁去上方 98 像素，让平直顶缘与碰撞面重合；保留完整生成输出 PNG，未声称存在 PSD 图层工程。

## 2. 敌人分部件制作方式

四张敌人图集均把可独立裁切的部件放在 2 × 2 网格中；按从左到右、从上到下编号 0–3。图集是单张 PNG，部件层是通过裁切这些格子得到的独立运行时 Sprite2D，没有额外的多图层 PSD 源文件。

| 敌人 | 部件用途与复用 |
| --- | --- |
| 甲虫 | 身体、头部、支撑腿、甲壳；腿格多次复用并错开摆动 |
| 孢子囊 | 主囊、喷口、根部、附属叶片；主囊鼓胀、喷口发射回缩 |
| 机兵 | 躯体、攻击部件、腿部、护甲／装饰；腿格左右复用，武器绕关节挥动 |
| 守圃者 | 独立躯体与攻击部件、腿部、上身附属部件；放大骨架轮廓并突出核心与武器 |

[EnemyVisual](../../../features/enemies/enemy_visual.gd) 使用 AtlasTexture 按格裁切，每格边缘内缩 7 像素以排除生成图集分隔线；各部件配置自己的关节、尺寸、位置和绘制顺序。待机呼吸、步态、准备、发力、收招、失衡与死亡散落由原生节点变换驱动，跟随实际敌人状态。

后续修改部件时保留格子顺序与关节关系，或同步更新 EnemyVisual 的裁切和关节配置；在实际镜头下检查脚底、重叠、左右翻转、准备与命中动作。当前图像不能自动证明所有关节和遮挡均已通过最终美术验收。

## 3. 玩家动作资源

新增动作沿用既有三形态角色中的人形、成熟形态 Spine 骨骼。基础待机、移动、跳跃、能力和死亡仍来自用户提供的原有素材。

本次新增的是两份可编辑的 Godot 姿势资源：

- [humanoid_poses.tres](../../../features/combat/data/humanoid_poses.tres)
- [mature_poses.tres](../../../features/combat/data/mature_poses.tres)

每份覆盖三段轻击、重击、空中攻击、闪避、弹反起手、弹反成功和受击九类动作。资源记录骨骼角度和关键阶段时间；CombatPoseLibrary 在准备、发力、跟随与回收之间插值，再叠加到既有骨骼。藤鞭和轨迹是独立视觉，读取同一招式的攻击距离、有效段和收招时序，并连接到角色手部位置。

没有新增独立的 Spine 编辑器源工程或重新导出的 Spine 攻击动画包。可编辑性交付是原有 Spine 数据、这两份姿势资源与运行时动画脚本；不能将其描述为已交付新的 PSD／Spine 原文件。

动作检查产物为约 32 秒的 [combat_pose_review.avi](../../../build/qa/combat-visuals/combat_pose_review.avi)，展示两形态共 18 个动作条目的左右朝向慢放。已抽查重击的左右朝向及收招帧；这是程序化姿态检查录像，不是连续真人玩法录像，也不表示全部动作已完成逐帧人工验收。

## 4. 背景、声音与界面

新温室背景由 GreenhouseBackdrop 作为宽幅环境图配置，结合窗框和植物轮廓绘制。苔藓地面使用上方登记的 AI 衍生纹理；已有钢板、树枝、花草与培养罐继续复用项目素材，不把它们列为本次 AI 新创作。

战斗声音复用 credits 已登记的 Kenney CC0 音频；新增的是挥空、命中、格挡、弹反、闪避、预警和死亡的事件映射，没有声称录制了原创 Foley 或音乐。HUD 复用 botanical 主题、Kenney 图形与 Noto Sans SC，并以原生 Control 制作生命叶片、进度条和菜单。

## 5. 发布与验收状态

用户提供的既有 Spine 角色、场景 PNG、荆棘与罐子素材，其原作者和发布许可仍待确认；新图集和新姿势资源不会替代这些原素材的来源要求。Spine 运行时也继续受对应的官方运行时许可约束，具体登记见 credits。

当前源图归档和自动化测试不代表正式美术、人类试玩或对外发布验收已全部完成。姿态慢放录像与抽样检查已经留档；至少三轮完整人类试玩、连续玩法中的动作复核、声音混合、Windows 构建完整性和稳定帧率仍需要各自的证据记录；不在本文虚构这些结果。
