# 文档索引变更（WIP）

- `docs/presentation/芽_游戏讲解.pptx`：约五分钟的中文游戏讲解演示文稿，含正式关卡渲染截图、三阶段形态说明与逐页讲解备注。

- `tests/scene/test_main_completion.gd`：正式入口中 `Button_59bb7020` 的物理接触通关、一次性结算、暂停和 F5/F6 重玩验证；其他按钮（含旧终点 `Button_bbbb4660`）不通关，复用生产关卡，不新增可玩测试场景。

- `docs/level_playthrough_audit.md`：2026-09-06 正式关卡的真实输入模拟检查；区分连续出生路线、隔离软锁复现和接线检查，附 `docs/level_playthrough_map.png`。记录用户要求移除出生区升降方块后的验证；不代表已整关通关。

- `docs/main_camera_audit.md`：2026-09-06 正式 main 镜头问题的考察记录，附初始建议图 `docs/main_camera_regions.png`；后续已授权实施，当前行为以 `docs/camera_follow_rules.md` 为准。

- `docs/camera_follow_rules.md`：当前分区镜头规则、七个 CameraRegion2D 区域、入口身份、前视/墙界/下落/重生与调参说明；场景为 `features/level/camera/main_camera_regions.tscn`，正式回归为 `tests/scene/test_camera_regions.gd`。Floor2 由 Ground13/14 支撑，StartFloor 对应用户的 StartFloor1。

- `features/ui/main_level_hud.gd` / `.tscn`：正式手工主关卡 HUD；由 `level_01/Interface` 实例化，显示形态、成长、稳定度、随 InputMap 生成的能力提示及关卡计时/重试/检查点反馈。`HandbuiltLevel` 可选绑定，不改变其他关卡入口。使用现有项目等比缩放，HUD 位于独立 CanvasLayer，鼠标穿透。
- `tests/scene/test_main_level_hud.gd`：正式入口 HUD 的资源/形态更新、统计、检查点、新局清零、重绑隔离与鼠标穿透验证；命令 `Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/scene/test_main_level_hud.gd`。

- `features/level/level_event_bus.gd` / `.tscn`：关卡局部机关事件总线；使用契约与正式关卡接线记录在 `docs/handbuilt_level_building.md`，生命周期和隔离由 `tests/scene/test_level_event_bus.gd` 验证。

- `scenes/levels/level_02.tscn`：JSON 上部空间按 Floor2 ↔ Ground13 + Ground14 整段跨度标定，位置映射为 `(-262,-3) + (源坐标-(0,304)) × (2.625,2.5)`；地形尺寸烘焙，贴图密度保持 0.4，横向地板碰撞上边距 6.5。作为无独立角色/镜头的上部区块，在 `Level_main/Level01/Level02` 拼合预览。
- `scenes/levels/Level_main.tscn`：隐藏并禁用参考 Floor2，以 Ground13、Ground14 两段地板替代，保留 x=200..284 的机关缺口；共享 Level01 角色、HUD、背景与生命周期，扩展相机范围覆盖上下两部分。
- `features/level/handbuilt/level_02_upper_entities.tscn`：上部 24 个实际实体与桌面 JSON 原始连接；目标方块与目标吊环只保存为终点数据，源数据未连接的按钮不补写连接。
- `features/level/handbuilt/restored_upper_entities.gd` / `restored_cube_motion.gd`：区块内按钮和吊环接线，以及继承 `MoveableCube` 的旋转、平移与尺寸终点适配；终点使用区块局部坐标，支持组合场景平移。
- `tests/scene/test_level_02.gd` / `test_level_main.gd`：映射后的上部逐格地形、Floor2 与两段 Ground 的范围对应和机关缺口、机关连接和运动，以及单角色/镜头/HUD 的组合入口验证。

- `docs/merge_main_20260906.md`：本次 main 选择性合并的保留范围、接入内容与本分支验证结果。
- `docs/backup/main_20260906/INDEX.md`：本次获取的上游设计和验证历史索引，仅作按需查询。

- `docs/handbuilt_level_building.md`：手工非 Tile 关卡的组件目录、搭建流程、组件接线方式与验证清单；手工关卡流程稳定后评估是否提升至 `AGENT.md`。

- `docs/whitebox_acceptance_criteria.md`：本次 JSON 白盒落地的验收标准、操作步骤与证据要求；实施后逐项记录结果。

- `docs/whitebox_entity_rules.md`：记录白盒按钮与可移动方块的逐项行为规则；等待逐项确认完成后提升到 `AGENT.md` 权威索引。

- `docs/superpowers/specs/2026-09-05-whitebox-playable-vertical-slice-design.md`：一次性交付角色、三形态核心能力、资源转换和可通关白模关卡的已确认设计规格；实现验收完成后保留为过程记录。
- `docs/superpowers/plans/2026-09-05-whitebox-playable-vertical-slice.md`：上述白模垂直切片的测试驱动实施计划，覆盖形态、资源、能力、交互、关卡和实际操作验收。
- `docs/superpowers/plans/2026-09-04-whitebox-core-gameplay.md`：白模核心功能实现计划，完成执行后保留为过程记录，不列入权威文档索引。
- `docs/scene_design_and_ownership.md`：白模场景层级、模块所有权、通信契约和并行实施分工；待首个白模关卡验收后决定是否提升为权威索引。
- `docs/superpowers/plans/2026-09-04-whitebox-integration-scenes.md`：本分支白模交互实体、启动壳与关卡组装的测试优先实施计划。
# 待确认文档

- `docs/scenery_asset_mapping_template.md`：场景 PNG 素材到 JSON 关卡 Tile / Entity 的待填写映射表。
- `docs/handbuilt_level_building.md`：补充普通与硬质地板的 Polygon2D / CollisionPolygon2D 编辑、素材变体与实例覆盖说明。

- `assets/runtime/scenery/variants/`：根据场景素材表建立可复用的 `SpriteVariantSet` 素材组；待关卡实际采用后评估是否提升至权威索引。
