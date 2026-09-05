# 藤蔓攻击表现验证

日期：2026-09-06。实现：独立植物部件图集、十段藤蔓骨骼和连续网格、两形态各五招动画、人物逐骨骼发力时序、Spine 本帧手部挂点同步。

## 实现与证据

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 新藤蔓组件与实际 Player 契约 | 901 项通过 | tests/scene/test_vine_whip_visual.gd；build/qa/vine-attack/after/test_vine_whip_visual.log |
| 既有战斗规则 | 最终 129 项通过，未改伤害／距离／形态倍率 | tests/scene/test_combat_system.gd；build/qa/vine-attack/after/test_combat_system.log |
| 原有身体姿势与复位 | 18 类动作检查通过 | tests/scene/test_combat_visual_poses.gd |
| 本帧手部变换 | 两形态、五攻击、左右共 420 样本通过 | build/qa/vine-attack/test_body_socket.gd |
| 独立场景启动 | VineWhipVisual 与 Player 各 120 帧通过，无脚本错误 | 最终启动检查日志，见 after 目录 |
| 正式 F5 主入口 | 120 帧启动通过，无脚本错误 | 主入口检查日志，见 after 目录 |
| 两形态五招左右图形检查 | 20 段配置时序采样，1× 速度，12.4 秒／744 帧 | after/attacks_1x.avi 与 capture_manifest.json |
| 实际伤害查询样例 | 8/8 通过，命中位于有效窗口 | contacts/contact_manifest.json 与录制日志 |
| 真实跳跃攻击 | 两形态×左右 4/4 通过，命中采样时离地且处于 jump 状态 | airborne/air_attacks_1x.avi 与 airborne_manifest.json |

证据目录统一为 build/qa/vine-attack/。新组件测试覆盖只读动画采样、两形态与左右、蒙皮绑定、距离边界、固定叶片尺寸、暂停／命中停顿同时间采样、中断清理与生产 Player 接入；不会用 headless 通过代替视觉质量判断。

## 视觉结果

查看正式 1280×720 画面和关键帧，藤蔓已具备附着叶片、粗细变化与卷曲末梢。普通战斗镜头约 2.1，核心样例约 1.65。准备、挥出和回收姿势有明确变化，关闭残影后植物实体仍能辨认。

实施中曾发现藤身网格与叶片／卷梢分离，根因是蒙皮网格和旋转骨架处于不同坐标空间。最终将 Polygon2D 放入 Skeleton2D，并关闭该视觉组件的物理插值；重新捕获后藤身、叶片和末梢连续相接。另将正式 Spine 采样统一放在 world_transforms_changed 后，避免把旧手部姿势写进残影历史。

## 可直接查看的产物

- [正常速度 GIF 预览](../build/qa/vine-attack/vine_attacks_1x.gif)：最终录像裁取战斗区域，30 fps，保留 12.4 秒实际时长；未慢放。
- [修改前后关键帧](../build/qa/vine-attack/before_after.webp)：同镜头／同光照下，准备、有效、收招的 2× 裁切对照。
- [完整画面前后对照](../build/qa/vine-attack/before_after_full.webp)：普通战斗完整视口。
- after/attacks_1x.avi：最终正常速度、当前主角灯光，20 段动作。
- after_slow/attacks_025x.avi：0.25× 采样慢放，40.13 秒，用于定位关节和挂点，不作为正常手感证据。
- after_same_light/：仅录制实例关闭并行加入的 FlowerLight，与改前录像保持光照可比；没有修改主角生产灯光。
- after_body_only/：关闭藤蔓残影，60 张关键帧。
- airborne/air_attacks_1x.avi：4.83 秒真实物理跳跃攻击，两形态与左右共四例。
- contacts/：固定敌人 AI 的实际攻击查询样例，包含普通敌人受伤、机兵格挡／破防、核心精英受伤；不是人类通关录像。

正式项目同期有另一项相机工作。图形录制仅在录制实例禁用 Phantom 跟随驱动并固定生产镜头，以保持机位可比；生产相机文件没有为本次录像修改。正式 F5 启动另行验证。图形工具有既有 user:// shader 缓存环境提示，最终样本无新脚本／节点错误。

## 素材与编辑

资产和提示词通过内置 ImageGen 制作，提示词见 assets/source/combat/vine_attack/prompt.md。选用第一张 1254×1254 RGB 部件图集；透明提取重试未得到可用 alpha。实际交付是保留原图并由原生 Godot 材质在渲染时去掉浅色中性底，不把它描述成带 alpha 的源 PNG。

打开 features/combat/visuals/vine_whip_visual.tscn，在 AnimationPlayer 选择 humanoid／mature 库内五种攻击，可编辑关键帧。图集部件、挂点和尺寸见 assets/runtime/combat/vine_attack/ 及 features/combat/data/vine_attack/{humanoid,mature}.tres。人物发力时序在两份 poses 资源的 bone_phase_times 中调整。

## 尚未进行的体验验收

没有进行“不知改动内容的新玩家”盲认测试；自动采样与截图不证明该项完成。主动作集的 air 段是配置时序展示，真实跳跃攻击已在 airborne/ 单独验证并记录；不把站位采样称为玩家实际腾空。玩家对第一击辨识度与动作手感的最终评价仍应以正常速度试玩为准。

## 移动与攻击衔接补充

随后补充行走收步、空中惯性、接地短收势与跳跃输入缓冲。新的规则、自动检查与正常速度图形证据见 [动作衔接验证](attack_transition_validation.md)。

## 手部弹性牵连与蓄势（2026-09-06）

根据后续反馈，藤蔓从位置挂接进一步改为手部方向约束与弹性链：根点固定于 Spine 当帧掌心，首段沿掌轴；前后段以不同弹性响应跟随，世界空间运动保留手部移动引起的惯性，逐节长度和最大弯折角受约束。关键帧继续控制放出、挥击和回收的节奏；它是服务动作可读性的视觉模拟，CombatController 仍负责伤害。残影保留在世界位置，避免随手整片平移。

手掌与攻击轨迹之间用连续曲线过渡，第二击回抽允许多节回弯。落地沿连续的动作时钟回收，同时间重复渲染只投影副本，不再次推进模拟；中断与换招清空弹性历史。参数位于 VineWhipProfile 的 Hand and elastic follow 分组。

人物蓄势提前建立，轻击收腕转肩，重击增加后拉、压身，空击收臂收腿。修复两份 poses 资源中导致逐骨骼时序未读取的注释，并减少起手重复淡入；10 招的 50 条腰肩肘腕时间配置已验证真实加载。掌心偏移仍为手骨 x 轴的 18 单位，标记图确认位于掌部，无须换挂点。伤害、范围和各招阶段时长未变。

新证据位于 build/qa/vine-physics/。最终检查如下：

| 检查 | 结果 |
| --- | --- |
| 手部牵连行为 | 4542 项通过，覆盖两形态十招双朝向、真实骨根与掌轴、受限藤节长度/弯曲、急移/急转后的滞后与跟上、同时间缓存隔离、落地与中断 |
| 原有藤蔓契约 | 901 项通过；修正左向夹具的掌轴镜像，保留实际前沿不超过攻击范围+12的警戒 |
| 移动攻击衔接 | 616 项通过 |
| 战斗回归 | 当前 189 项通过；同期新增幼芽冲撞测试把动作结束后的反向走动也计入了冲撞距离，已修正为最后攻击帧测量，生产冲撞行为未改 |
| 人物与挂点 | 10 招逐骨骼时序、18 类动作、420 挂点样本通过 |
| 独立场景与主入口 | Player、VineWhipVisual、正式 F5 启动通过，无脚本错误 |

图形检查包含两形态轻2/轻3左右的逐帧回抽标记图，以及正式主关卡走动、跳跃、接地的8段正常速度录像。回抽根部最终弯角限制为每节0.95弧度，转弯分散到多节；根部连续贴掌，叶片和藤身无分离。轻2右向最终对照见 build/qa/vine-attack/return_light_2_right.webp，其余回抽标记图是收紧弯角前的方向检查记录。

[正常速度预览](../build/qa/vine-physics/vine_physics_preview.gif)：从最终 vine_physics_1x.avi 裁切动作区域，768×280、374帧、30fps，保留12.47秒真实时长。原录像1280×720、748帧、60fps；未慢放。关键帧 *_charge.webp / *_strike.webp / *_landing.webp 已核对。图形录制有既有 shader 缓存目录及磁盘空间提示，文件完整写入，无新脚本错误。
