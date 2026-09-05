# 藤蔓攻击素材与动画制作记录

日期：2026-09-06。对应实施计划：docs/superpowers/plans/2026-09-06-player-vine-attack-visuals.md。

## 来源与实际图像格式

本轮使用内置 OpenAI ImageGen，以用户已经提供的人形、成熟形态角色头像为风格参考，生成第一稿九部件藤蔓图集。生成提示词由本目录的 prompt.md 归档。素材采用既有角色的深色轮廓、黄绿色植物块面和叶片语言；属于参考既有角色制作的 AI 衍生素材，不冒称手绘或完全独立原创。参考角色的原作者与发布许可仍为待确认状态，沿用 docs/credits.md 的登记，不新增 CC0 或 MIT 授权声明。

| 文件 | 实际交付与用途 |
| --- | --- |
| assets/source/combat/vine_attack/vine_parts_source.png | 第一稿生成原图；1254 × 1254、RGB PNG，没有 alpha 通道 |
| assets/runtime/combat/vine_attack/vine_parts_atlas.png | 保留第一稿原始位图的运行时副本；部件通过各自 AtlasTexture 的区域独立引用 |
| features/combat/visuals/vine_cutout.gdshader | Godot 原生画布材质；渲染时去除低色度的亮色背景，使游戏中的部件背景透明 |
| assets/source/combat/vine_attack/prompt.md | 生成提示词和参考来源说明 |

生成器两次都没有交付真正的 alpha 背景；第二稿效果更差，未采用。本轮保留第一稿原始位图，不通过程序改写像素或伪造透明源文件。**游戏渲染时透明，但源 PNG 与运行时 PNG 都不是带 alpha 通道的透明图片。** 这是与原计划“1024 × 1024 透明 PNG 图集”交付方式的明确差异：实际尺寸为 1254 × 1254，透明处理由材质完成。单独在普通图片查看器打开 PNG，仍会看见原背景；若以后移出 Godot 使用，需要另行制作真正的 alpha 素材。

部件使用独立 AtlasTexture 和局部挂点；原图不是分图层 PSD，也没有新增 Spine 编辑器工程。图集范围、叶柄挂点、世界尺寸和材质引用以两份 VineWhipProfile 资源为实际运行依据。藤身沿 Polygon2D 网格变形，叶片、茎节、叶鞘和藤梢分别挂接，不把整张叶片随攻击距离横向拉长。

## 可编辑的藤蔓场景与动画

打开 features/combat/visuals/vine_whip_visual.tscn。场景包含 Skeleton2D、10 个 Bone2D、带骨骼权重的连续 Polygon2D 藤身、叶片/茎节/藤梢 Sprite2D，以及 AnimationPlayer。基础骨骼、叶片所属藤段和前后绘制设置均可在 Godot 中编辑。

| 编辑入口 | 内容 |
| --- | --- |
| features/combat/data/vine_attack/humanoid.tres、mature.tres | 两形态外形、贴图、材质、藤身粗细、部件尺寸、挂点和叶片数量 |
| features/combat/data/vine_attack/humanoid_animations.tres、mature_animations.tres | 两套 AnimationLibrary，每套引用 light_1、light_2、light_3、heavy、air 五招 |
| features/combat/data/vine_attack/{humanoid,mature}_{light_1,light_2,light_3,heavy,air}.tres | 十份独立 Godot Animation 资源；骨骼角度、伸展比例、扫击高度、叶片摆动、轮廓透明度和前后层级关键帧 |

AnimationPlayer 的 0、1、2、3 时间坐标是前摇开始、有效段开始、收招开始、动作结束四个阶段边界，不代表游戏中每招固定播放三秒。运行时由 CombatController.elapsed、招式 windup/active/recovery 和形态时间倍率计算采样位置，再定位动画；暂停、命中停顿和重复采样不会额外推进一份视觉计时。编辑器预览可以通过 preview_form、preview_reach、preview_height 选择形态与尺度。

这是原生 Godot 场景与动画资源的交付；可以编辑关键帧与部件参数，没有交付新的 .spine 工程或不存在的 Photoshop 分层文件。

## 人物发力与手部连接

人物身体继续使用用户提供的 Spine 骨骼。真实发力链为 z3（腰）→ z4（胸肩）→ hand_L_2（上臂）→ hand_L_1（前臂）→ hand_L_3（手腕/掌部）。

features/combat/data/humanoid_poses.tres 与 mature_poses.tres 的 poses 保存各骨骼的蓄势、挥出、余势三个角度；phase_times 保存动作共用的三个时刻，新增 bone_phase_times 仅为五种攻击覆盖各骨骼时刻。features/combat/combat_pose_library.gd 负责插值并在动作末尾回到原动画。时刻使用整招进度 0–1，可直接在 Godot Resource Inspector 或文本资源中编辑。

本轮保留已有肩、躯干、头部的角度幅度，错开发力时刻，并小幅调整肘腕蓄势和回收；成熟形态的前臂、腕部和回卷稍晚，形成更舒展的余势。空中招式保留收腿。闪避、弹反和受伤姿势沿用原有共用时序。

SpineCharacterVisual 监听原生 world_transforms_changed，在本帧世界骨骼完成后发出 combat_hand_transform_updated(global_hand_transform)。combat_hand_global_transform() 返回同一手部变换，原点已经包含 hand.x × 18 的掌长偏移；变换保留形态缩放、手部方向和左右反射。上层连接藤根时不能再次添加掌长。

## 本记录已确认的验证

- tests/scene/test_combat_visual_poses.gd：两形态共 18 动作通过，骨骼变换有限、重复更新不累积，移动与死亡姿势能够恢复。
- build/qa/vine-attack/test_body_socket.gd：两形态 × 五招 × 两朝向 × 21 个进度，共 420 个样本通过；每次 Spine 更新后信号恰好一次，挂点原点、完整 basis 和形态缩放与当前帧手骨一致。
- build/qa/vine-attack/body_pose_sheet.webp：已渲染并检查两形态五招各三个身体关键姿势；肘腕没有可见断裂，空中收腿保留。该图用于身体姿势检查，不代替藤蔓完整动作与正常速度实战验收。

本记录不提前宣称完整集成验收通过。组件、材质透明边缘、浅深背景、正常速度十招、左右镜像、取消与实际攻击范围的最终验证，以 docs/combat_validation.md 和 build/qa/vine-attack/ 的实际记录为准。
