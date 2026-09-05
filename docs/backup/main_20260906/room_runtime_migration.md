# 房间与垂直路线运行时迁移

状态：只读审计与最小迁移建议，尚未改动运行时代码、生成器或正式场景。对象是当前正式 main → Level_main → level_01 与 GreenhouseLevel；下一步由新培养室空间样板决定坐标和视域。旧八房排列、固定 X 分段、全局 y400 地面均不是新空间设计约束。

当前战斗、动画、资源成长、死亡重试和单一 Phantom Host 保留。此前 129 条战斗、36 条分房实战、54 条镜头等测试只证明当时实现的契约；不能证明旧地形达到金标准，也不能直接当成重设计后的空间验收。Windows 导出继续暂停。

## 1. 已确认的耦合与风险

| 位置 | 现有行为 | 新房间路线的风险 | 最小处理 |
|---|---|---|---|
| greenhouse_level.gd：SECTION_STARTS、_process、_on_player_died | 仅按玩家全局 X 选择标题/目标；死亡界面也索引同一数组 | 同 X 的上下房间无法区分，向左回路会显示错误目标；未来负 X 路线可能沿用旧区域状态 | 用实际 RoomRegion 身份提供标题/目标；死亡界面读取当前房间，不再推算横向进度 |
| greenhouse_level.gd：_process | 玩家 y>650 立即经统一生命组件死亡 | 合法下层房、深井和恢复台无论是否安全都被杀死；把 650 调大仍无法表达上层坑与下层安全路并存 | 设计危险处放现有 HazardArea；另设覆盖整个有效世界的可配置越界兜底，独立于相机边界 |
| greenhouse_level.gd：_checkpoint_state、retry_checkpoint | 快照仅含玩家位置、形态与资源，随后重置探索 Phantom | 从另一层/房间重生时可能沿用死亡处的视域；区域 Area2D 的重叠事件通常要等物理更新，不能作为重试瞬时定位的唯一依据 | 快照补稳定 room_id；恢复位置前确定目标房间，恢复该房镜头参数/边界，再调用现有 Host 重置流程 |
| handbuilt_level.gd：_configure_camera、_configure_phantom_bounds | 一份全局 CameraBounds 同步给探索和战斗相机 | 垂直大房和相邻密闭房间需要不同视域；只改相机位置仍可能被旧世界边界钳住 | 边界同步函数接收明确的世界 Rect2；全局 CameraBounds 作为默认配置，不再是每个房间唯一视域 |
| camera_bounds.gd：get_world_rect | 返回 Rect2(global_position, bounds_size)，没有应用节点 scale/rotation | 在编辑器缩放边界节点会让预览尺寸与运行时限制不同 | 样板的边界节点保持 scale=1、rotation=0，直接编辑 bounds_size；不为样板重写通用变换支持 |
| greenhouse_level.gd：_ready | Geometry/Areas/Actors/Encounters/Checkpoints 被设为 PAUSABLE，关卡根节点是 ALWAYS | 新增 Rooms 根分支若承载移动物/脚本而继承 ALWAYS，会在暂停时继续运行 | 新 RoomRegion/房间容器明确 PAUSABLE；继续保留独立相机节点的 PAUSABLE 设置 |
| greenhouse_level.gd：遭遇注册 | 只遍历 %Encounters 的直接子节点 | 若把每个遭遇随意移进房间深层，事件接线将静默遗漏 | 样板保留扁平 Encounters 容器，房间仅作为空间元数据；以后确需嵌套再改为明确注册或递归收集 |
| encounter_controller.gd：can_trigger | 局部 x≥52、x<宽−20，局部 y在−110..20，且非幼芽 | 从房间上部进入、反向门口或台阶入口无法由这条水平条带准确表达；相邻上下层可能过早/漏触发 | 为重设计的遭遇提供独立入口触发区，保留“非幼芽、活着、未完成”的规则；旧触发条带仅作旧场地兼容默认 |
| encounter_controller.gd：_ready、_set_gates、_draw | 自动创建左右两扇竖门，门的位置/绘制都由 arena_size 推导 | 顶部、底部或偏置门口不能表达；新立柱/平台可能与自动门相交 | 样板未改变的战斗房保留原门。真正重做某战斗房时，增加显式 gate 节点引用，绘制和碰撞由同一门场景负责 |
| encounter_controller.gd：_next_wave | 生成点为宽度的 .48/.65/.82，局部 y=0；所有敌人共享一个矩形 bounds | 多个高低战斗面不能靠改变 arena_size 自动得到正确出生点/活动范围 | 重做战斗房时改为有序 Spawn Marker；根据实际战斗面配置敌人范围，不改变敌人血量与招式 |
| encounter_controller.gd：camera_center、checkpoint_position | 镜头固定为本地(宽/2,−80)；重生点为(72,−2)，精英ID例外(−80,−2) | 空间中心不再等于横向战斗中心；反向/上下入口重生会埋墙或出现在门内 | 增加明确 CameraFocus 和 RetryPoint 标记；保留方法名，内部优先读标记，兼容旧默认 |
| combat_enemy.gd：_physics_process、_tick_pursuit | bounds 控制左右活动及底部出局；普通近战敌人不会跳台，落到 bounds.bottom+fall_out_margin 以下才算击败 | 掉到下层安全台但仍在出局阈值内的敌人可能不可达而锁门；跨层敌人不能假设会自动找到玩家 | 为该遭遇明确可战斗面与不可恢复坠落区。需要保留的下层敌人必须有玩家可达路线；不要借此次迁移增加通用跳台寻路 |
| checkpoint.gd：get_checkpoint_position、activate | Area2D 原点就是重生点，激活后本次场景不会再次触发；灯具画法还假设原点高于地面20 | 视觉/触发位置与真正安全落脚点被绑在一起；回路重新路过旧点不会自动把它变回当前检查点 | 补可选 RespawnPoint Marker，兼容原点默认；明确是否按“最近到访”刷新快照，将点已发现与当前重生点分开 |

Encounter 的 y=0 是局部地面基准，不是硬编码全局 y400。把整场遭遇连同其场地平移到任意世界高度，现有敌人生成、弹体 to_local 和矩形 bounds 都可继续工作。只改培养室空间时，不必提前重写所有遭遇。保持轴对齐、无整体非均匀缩放；艺术部件可以在独立子节点缩放。

Checkpoint 场景 collision_mask=2，正常物理触发只接收玩家层；本次没有将其通用 activate 参数推测成已发生的敌人抢占问题。现有 HazardArea 已发出 handbuilt_hazards / actor_killed，能直接接入统一死亡流程，无需再造一套扣血系统。

## 2. 培养室样板先落地的接口

建议只增加一个小型 RoomRegion 组件，继续使用现有 CameraBounds、SpawnPoint、Checkpoint、HazardArea、PhantomCamera2D。暂不加入房间流式加载、传送网络、通用导航或新的关卡序列器。

| 接口/数据 | 建议职责 |
|---|---|
| RoomRegion：Area2D，稳定 room_id、display_name、objective | 描述实际空间所属区域。用真实二维触发范围，而非 X 排序；同一大培养室如需多个视域，可有少量子区域，显示名相同而ID不同 |
| RoomRegion：camera_bounds 引用、exploration_zoom、follow_offset | 复用已有边界与 Phantom 配置。死区/前视沿用现有默认，只在空间验收证明需要时覆盖；不为每块台阶添加相机 |
| RoomRegion：selection_priority | 门口范围相交时优先级明确；同优先级优先维持当前房间，避免脚边抖动。区域切换应能逆向与上下发生 |
| resolve_room_at(world_position) → RoomRegion | 一个确定性的查找入口，供出生、正常区域切换与重试共同使用；不依赖“下一帧 Area2D 才通知”来修正镜头 |
| enter_room(room, immediate=false) | 只负责当前房间身份、HUD默认目标和探索镜头参数。活跃遭遇的固定相机仍具有更高优先级；进房本身不自动完成遭遇或覆盖成长资源 |
| _checkpoint_state[room_id] | 保存稳定ID，不保存场景节点引用。位置、形态、资源继续由 Player.capture_state 提供；所有者仍是 GreenhouseLevel |
| Checkpoint/遭遇 RetryPoint | 明确安全的脚底位置，和灯具位置/Area触发中心解耦。允许入口在左、右、上层或下层，不用“精英必须在左80”表达安全区 |
| play_bounds 或同义世界兜底 Rect2 | 包含全部合法房间和连接区，留出足够的坠落恢复余量。只处理逃出整个有效世界的异常；实际危险仍由显式 HazardArea 表达 |

初始状态和切换时序应统一：

1. 出生：放置玩家 → 从出生标记确定 RoomRegion → 应用当前房间边界/视域 → 等 Host 首个 process_frame 注册后初始化镜头。
2. 正常穿房：选择实际区域 → 更新 HUD/探索参数；当前遭遇仍活跃时保留固定战斗视图，不能被房间边界检测抢走。
3. 遭遇开始：使用该遭遇的明确 RetryPoint 保存玩家快照及其所属 room_id → 设置 CameraFocus/zoom/边界 → 提升固定 Phantom 优先级。
4. 死亡重试：清理当前未完成遭遇与效果 → 从快照解析目标房间 → 恢复玩家位置/形态/资源、生命和速度 → 应用目标房间镜头边界 → 经现有 Host 瞬时重置 → 下一物理帧允许重新触发遭遇。
5. 遭遇完成：保留 completed 状态并开门 → 依据玩家当前所在 RoomRegion 返回探索。回路可以回到以前的房间；不能根据更大的 X 强行选择下一区。

如快照没有 room_id，兼容旧快照时按重生位置解析；找不到匹配区域应报告布局错误并使用出生区域兜底，不能默默套用第七区或上一次死亡区域。

## 3. 镜头、危险与检查点的具体边界

### 镜头

- 保留一个实际 Camera2D 和一个 PhantomCameraHost。探索 FRAMED 与战斗 NONE 的两台 Phantom 已有优先级切换；不恢复 GreenhouseLevel 对实际 Camera2D 的逐帧位置/缩放写入。
- 房间视域不是碰撞外接框，也不是死亡范围。可行走空间很窄的通道可能需要更大的镜头边界；狭小房间的镜头边界不得小于实际 viewport_size / zoom，否则上下或左右钳制范围会反转。
- CameraBounds 是轴对齐世界矩形。为新样板填写真实 bounds_size；相机跟随目标、跳跃高低差、下落落点均按最终坐标验收，不沿用 8840×850 的旧世界大小。
- 房间边界不同后，原镜头测试“重试镜头必须等于玩家位置+offset”需要改成“等于允许边界内的预期位置，且玩家在安全画幅内”；靠墙检查点必然会被合法钳制。这是补上边界契约，不是放宽到只检查相机存在。
- 当前插件只在活动 Phantom 更新 limit 时同步实际 Camera2D；过渡还会临时 reset_limit。切换应由关卡集中处理，不能由多个房间脚本持续争写限制。跨密闭房的平滑路径要在实帧检查，不能让镜头穿过大量未设计空间。
- 现有重试通过局部零时长 Tween 和 Host 清理旧过渡、跟随速度与前视。继续保留这一清理，但先恢复新房间参数，最后再提交实际镜头结果。
- 垂直路线的落点应在玩家承诺跳下前可判断。不能只验证角色仍在画面里：需要检查下一落脚面、危险与回路入口是否可读。具体 zoom/offset/视域划分等待新培养室坐标和实机画面决定。

### 危险与恢复

- 删除固定 y650 的含义，不把其数字机械替换成另一个全球死亡线。新房间下层平台可以低于原650而合法存活。
- 危险判定继续调用 GreenhouseLevel._on_actor_killed，保留闪避不免疫坠落/关卡即死危险的规则；不能经 CombatController 的闪避免伤路径过滤。
- 显式危险体不能覆盖有效下层路线、幼芽洞或恢复营养点。危险体顶边应与实际看得见的危险吻合，不以 HUD、相机边缘或背景黑色区域代替。
- 重生标记应落在真实承托面上，角色与门/墙有完整碰撞净空。若保留轻微空中落下表现，落差必须明确、落点安全，并在两形态中实测，不能继续隐式依赖灯具原点高于地面20。
- 幼芽恢复仍须步行可达；纵向结构不能把营养点放到必须跳跃/挂藤才能到达的地方。新样板是否包含可主动枯萎支路由空间设计决定，运行时不假定它在固定X。

## 4. 战斗房以后扩展时保持的契约

培养室样板优先只改空间层与镜头/重生归属。现有 AttackDefinition、EnemyDefinition、CombatController、HealthComponent、物理移动与输入保持。

当某个战斗房也改为多入口或多层地貌时，扩展 EncounterController 的最小集合是：入口触发区、明确门引用、按波顺序使用的 Spawn Marker、RetryPoint、CameraFocus、有效敌人区域。保留 begin/reset_encounter、encounter_started/encounter_completed、camera_center/checkpoint_position 方法的对外语义，逐个房间迁移，旧房保留默认值。

- 门关闭前，玩家必须已越过门的实体厚度与自身碰撞范围；顶/底入口不能照搬原左右门碰撞。
- 活跃战斗仍同时只有一场，普通房人数与波次继续由配置决定；RoomRegion 的重叠不应一次启动两场遭遇。
- 新出生点必须落在目标战斗面，完整敌人身体及预警不与墙/台相交。放在上台的孢子和下台的甲虫不等于已经实现跨层近战寻路。
- 当前敌人底部出局条件基于 bounds.bottom+fall_out_margin。设计应明确某次坠落是可继续战斗还是算击败，避免敌人落在关门后不可达的台面仍保持存活。
- 已完成遭遇继续保留，死亡只重置未完成的当前遭遇、弹体和临时效果。房间识别改动不应扩大重置范围。
- warden 完成后解锁总出口、进入出口才通关，是内容流程契约，可继续保留；不因培养室样板新增一个房间出口而提前结算整关。

## 5. 测试迁移与新样板验收

| 现有测试 | 保留的内容 | 应迁移的旧布局依赖 |
|---|---|---|
| test_combat_system | 129条组件/物理契约；两形态、去重、取消、弹反、无敌、墙体阻挡 | 该测试不依赖正式培养室坐标，不为新地形改伤害或删除断言 |
| test_greenhouse_encounters | 真实玩家攻击清敌、各波完成、无弹反可通关 | 按 encounter_id 查找、从明确入口标记初始化；不要继续把(72,−2)当所有门的入口。它仍不是路线试玩 |
| test_greenhouse_level | 单玩家、成长、重试快照、已完成遭遇保留、暂停计时、出口 | 替换培养室固定走155帧/x305/营养x415；上下路线按新地标顺序实际移动。旧上层路线若仍保留可继续独立验收 |
| test_terrain_routes | 初始化后不传送；真实吸收、成长、跳跃、Q/E爬升 | 当前 555/400 与三环坐标只代表旧树冠。新培养室另按正式地标验证，不能把旧52断言当新样板通过 |
| test_phantom_camera_integration | 真实Host、死区/前视、战斗固定、暂停、死亡清理旧过渡 | 去掉探索测试固定x5160、房间数组0/7、默认入口偏移和精英必在左侧；使用稳定ID和边界钳制后的预期构图 |
| test_level_main / test_level_01 | 正式启动链、唯一玩家/实际相机、配置和必要组件接线 | 世界边界从明确配置及设计预期验证；不保留8680/670等旧空间数值。现有战斗内容清单仍保留，不用“任意数量非零”替代要求 |

新培养室坐标确定后，补的实际验证应至少覆盖：

1. 从正式出生点开始，幼芽穿过设计的通道，到达营养点并按真实 E 输入成长；每个关键落脚点按顺序经过，位置帮助只用于用例初始化。
2. 同 X 不同 Y 的上下区域能选择正确 RoomRegion；逆向返回也能恢复对应目标与视域，门口小范围移动不会反复切镜头。
3. 上台、下落与回路转折均使用正常移动/跳跃。下落前的落点和危险可判断；自动测试检查视域，最终仍需正常镜头截图/实际试玩判断构图。
4. 在合法低处（若新布局低于旧y650）不会被旧死亡线杀死；进入明确危险会死亡，且闪避不能免疫该危险。
5. 从另一层/房间死亡后恢复到选定检查点：形态/资源快照正确、生命满、速度清零、区域身份和相机边界立即正确，旧过渡不在后续帧拉回死亡处。
6. 在跨视域过渡、垂直运动和重试界面分别暂停/恢复，玩家、机关与镜头均遵守暂停；时间不计入暂停。
7. 培养室进入战斗区域时，幼芽不会被封门，成熟与人形都能使用安全入口；相机与门的触发应按最终入口位置验收。

没有在本次审计中启动新的 Godot 测试、修改场景或生成器。下一步需要设计给出正式出生点、路线地标、区域触发范围、视域边界、危险体和检查点落脚点；随后按上述契约实现最小运行时调整并验证实际路线。


## 培养室样板已落地接口与验证（2026-09-06）

本轮只在正式主关卡接入培养室区域。其余区域继续使用旧 X 分段，尚未完成七区空间迁移。生产修改为 `features/level/rooms/room_region.gd` 与 `features/level/combat/greenhouse_level.gd`；场景和生成器由关卡负责人维护。

实际采用 `RoomRegion extends Node2D`，由局部矩形元数据查询位置，不增加物理碰撞或依赖延迟的 Area 进出事件。字段为 `room_id`、`room_name`、`objective`、`region_size`、`camera_center`、`camera_zoom`、`selection_priority`；节点位置是区域左上角，镜头中心相对节点。重叠区域优先较大 selection_priority，同值保留场景顺序。

当前 EntryView 覆盖世界 (-80,200) 至 (310,620)，中心 (154,433)，zoom 2.5；ChamberView 覆盖 (310,200) 至 (695,620)，中心 (472,426)，zoom 2.25。x >= 695 回到原 FRAMED 跟随。每个固定区域创建属于同一 GreenhouseLevel 的 Phantom，通过优先级向同一 Host 交接；战斗固定 Phantom 优先于房间视域。没有新增第二个 Camera2D，也没有恢复每帧写入 Camera2D 位置或缩放。

初始区域在 _ready 同步选定；重试恢复角色快照后按位置重新解析区域，再通过既有 Host 瞬时选择与跟随速度清理。快照附带 room_id 便于追踪，但恢复时位置查询是当前布局的依据。逃逸判死暂时改为 CameraBounds 底部 + 可调 fall_out_margin；当前 670 + 34 = 704。显式危险仍沿用 HazardArea；该临时全局下界不是未来所有房间的死亡区域定义。

验证结果：

| 用例 | 结果 | 范围 |
|---|---|---|
| test_nursery_room.gd，headless | 56 断言通过 | 从正式出生点真实按键穿洞、开低位机关、洞外 E 成长、三级实台、出口检查点；两次跨区域死亡重试；实际跳跃中 ESC 暂停/恢复 |
| 同一用例，真实 GPU + --capture | 64 断言通过 | 上述 56 项 + 8 张 PNG 成功落盘；1280×720，NVIDIA GeForce RTX 4060，OpenGL 3.3 Compatibility |
| test_phantom_camera_integration.gd | 54 断言通过 | 实际 Host、FRAMED 死区与前视、战斗固定构图、暂停中切换、普通与精英死亡重试 |
| test_greenhouse_level.gd | 68 断言通过 | 原 65 项内容保留，并增加培养室 3 阶真实跳跃；其余遭遇、两形态旧树冠路线、局部重试与出口 |
| test_level_main.gd | 通过，退出码 0 | 正式入口、单一 Camera2D、房间初始接管、后续 FRAMED 配置及数据驱动边界 |

真实输入图位于 `build/qa/nursery-input/`：01_entry、02_tunnel、03_cavity_sprout、04_cavity_human、05_stair_0/1/2、06_checkpoint。这组画面保持 Host 启用，角色从 (35,530) 连续运动；没有在路线中传送、直接改形态/资源或摆放镜头。死亡回调仅隔离重试生命周期。净高约 29.7 的洞可由 24 高幼芽穿过；在 (355,515) 营养点成长后，实际跳跃到达顶面约 485.959、444.571、400 的三阶，无需调整生产运动或碰撞数值。

渲染测试首次运行在新窗口切换焦点后丢失了 D 持键状态，导致一次步行超时；后续步骤仍真实穿洞成功。测试驱动改为检查实际 Input 按下状态后重新发出键盘事件，最终渲染测试通过。没有通过生产代码修改掩盖该问题。

最终日志：`build/nursery_route_v2.log`、`build/nursery_rendered_input_v2.log`、`build/room_camera_final.log`、`build/room_lifecycle_regression.log`、`build/room_entry_regression.log`。这些是自动路线与代码验证，不代表独立人类试玩、首通 10–15 分钟或全关卡美术质量验收。Windows 导出保持暂停。
