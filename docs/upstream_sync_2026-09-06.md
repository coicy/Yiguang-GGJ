# 2026-09-06 上游同步与设计参考

当前 main 已从 c5a443a 快进至 bb9c9f9（origin/main，Merge PR #9）。同步前先保存全部受版本管理的本地修改及项目内未跟踪素材/代码；Godot 本机工具目录和忽略的 build 产物没有移动。原工作保留于 stash 9b2ae97c1434b3c2b376aec8f974992187b11b8d，尚未删除。没有创建实现提交或推送远端。

## 合并决定

- 保留本地完整战斗主关卡、玩家战斗/能力/动画与新地形资产；上游原 level_01 保存为 docs/reference_levels/upstream_level_01_bb9c9f9.tscn.txt，便于参考其布置，不另建第二个可玩关卡。
- 保留上游 Phantom Camera、完整贴图地形模式、浮岛变体组、发光花、玩家花灯、藤环与荆棘组件。正式温室迁移为单一 Phantom Camera 控制，保留探索和固定战斗构图；验证结果完成后记录于下节。
- 人形采用上游 16×34 碰撞尺寸，同时保留已调过的 240 移动速度。TerrainPiece 的 show_artwork 开关也控制新增 WholeArtwork，避免与 TerrainSkin 重叠。
- 藤环提示改为 Q，与当前左键攻击的操作一致。
- tests/scene/test_player_movement_response.gd.uid 同步时与暂存的未跟踪 UID 重名；脚本完整保留，UID 采用已进入上游版本管理的 b4fymj4ectkmy。全部暂存的未跟踪文件均已恢复；该提示没有造成素材或代码丢失。
- 更新正式关卡断言以验证七区关卡，保留新增可复用组件的独立测试。没有用旧小关卡的固定坐标断言替代温室主流程。

## 设计数据

仓库 data/Yiguang.json 与用户提供的 Yiguang(1).json 使用同一地形、世界位置和全部 43 个实体位置；区别是 4 条按钮 EntityRef 连接，仓库版为 13 条有效连接、附件为 9 条。仓库版本包括连接出口门的按钮，不能因附件刚提供就认为其接线更完整。详见 terrain_ldtk_reference.md 和 reference_levels/ 中的原稿及空间图。

## 合并后验证

以下结果来自 bb9c9f9 合并并恢复本地实现之后的 Godot 4.7.2 headless 运行，包含人形 16×34 碰撞、240 移速、单一 Phantom Host 镜头，以及树冠两处窄缝封口。运行日志保存在被忽略的 build/ 目录；全部列出的进程退出码为 0。

| 用例 | 结果与覆盖范围 | 日志 |
|---|---|---|
| test_combat_system | 129 条断言通过：两形态招式、连段时序、取消、单次挥击去重、格挡、闪避、弹反、精英与弹体墙体阻挡 | build/post_merge_test_combat_system.log |
| test_greenhouse_encounters | 36 条断言通过：两形态各清完正式八场遭遇，含庭院两波；无弹反、零死亡 | build/post_merge_test_greenhouse_encounters.log |
| test_phantom_camera_integration | 54 条断言通过：真实 Host 的探索死区/前视、普通与精英固定构图、过渡中暂停、完成切回、重试位置/缩放及旧过渡清理 | build/camera_integration.log |
| test_greenhouse_level | 65 条断言通过：正式入口、幼芽通行、两形态上层跳跃、遭遇/重试/暂停及出口流程 | build/camera_greenhouse_lifecycle.log |
| test_terrain_routes | 52 条断言通过：两形态真实落入下层、枯萎为幼芽、进入支洞后原路返回营养点、成长并逐台回主路；成熟三环 Q/E 实际爬升、释放与落地 | build/camera_terrain_routes.log |
| test_level_main / F5 默认入口 | 正式场景包装、探索 Phantom 接线与世界边界通过；默认入口短启动无报错 | build/camera_entry.log / build/camera_F5.log |
| test_vine_ring | 独立用例通过：藤蔓锚点组、钩取范围、成熟提示可见性及幼芽隐藏提示 | build/post_merge_test_vine_ring.log |
| test_glowing_flower | 独立用例通过：红花变体、外缘光晕、有效纹理、PointLight2D 与阴影开关 | build/post_merge_test_glowing_flower.log |
| test_thorn_damage | 独立用例通过：三种荆棘变体、伤害/死亡信号、缩放后美术与碰撞一致 | build/post_merge_test_thorn_damage.log |

八房测试仅在各房入口定位以隔离战斗，随后通过玩家控制器实际攻击和闪避，不直接扣除敌人生命。机器人会识别实体花槽并跳越、对附近近战前摇使用现有闪避；本轮没有修改测试策略、敌人数值或生产实现。人形/成熟的庭院结果分别为 8.39 秒、剩 4 生命和 10.56 秒、剩 5 生命；精英分别为 20.60 秒和 16.74 秒，均剩 5 生命。这些是精确读取敌人状态的程序结果，不是首次玩家体验时间。

地形回路仅在每次路线起点设置位置与形态，之后没有传送或直接补充成长资源；两形态最终均从下层回到约 (6282,400)，三环连续路线落在 (5950,300)。幼芽洞按进入后原路返回的支洞验收，不声称左侧贯通。镜头测试的敌人冻结只用于隔离构图断言，八房战斗测试使用正常敌人逻辑。

本轮保留所有已有主流程检查，没有因上游旧小关卡布局而降低温室验收要求。自动测试不替代正常速度的视觉检查、三轮独立完整人类试玩或首次 10–15 分钟目标验收。

Windows 内部评审包仍是上一轮战斗验证版；等待最终截图与地形完成通知后再重新导出和验证。当前记录不代表更新后的 Windows 包已经交付，也不代表素材公开发行许可已确认。
