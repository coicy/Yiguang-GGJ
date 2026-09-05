# 正式温室关卡验证记录

日期：2026-09-06。对象：现有 F5 入口加载的 `scenes/levels/level_01.tscn`，由 GreenhouseLevel 管理。环境为 Windows、Godot 4.7.2 stable、60 Hz 物理步长。

## 1. 最终集成结果

| 测试 | 最终确认结果 | 验证范围 |
| --- | --- | --- |
| `tests/scene/test_greenhouse_level.gd` | **65 项断言，0 项失败** | 正式入口、出生与成长、八个遭遇、战斗门、局部重试、波次、双形态平台路线、精英准备区与出口 |
| `tests/scene/test_level_main.gd` | 通过 | Level_main 指向正式温室、只有所需场景节点、八个遭遇、探索镜头及边界 |
| `tests/scene/test_handbuilt_floor_pieces.gd` | 通过 | 复用手工地形组件的现有场景契约 |
| `tests/scene/test_player_audio.gd` | 通过 | PlayerAudio 的现有事件接线与音频契约 |
| `tests/scene/test_handbuilt_hud.gd` | 通过 | 迁移到 FirstGrowth／BranchWither、正式关卡镜头及 Q 能力后，验证成长 HUD、营养／毒液、吸收释放锁与新布局 |

最终集成测试报告为 `GREENHOUSE: 65 assertions, 0 failures`。此处记录的是自动化验证，不代表完成三轮人类试玩。战斗判定、两形态无需弹反击败精英等独立验证见 [战斗验证记录](combat_validation.md)。

## 2. 65 项集成断言覆盖

- **正式入口与出生**：F5 主入口到达 GreenhouseLevel；只存在一个玩家；七个区段包含八个遭遇；幼芽出生、出口初始锁定，旧成长 HUD 绑定到真实玩家。
- **培养室与成长**：用实际移动通过幼芽低位通道，身体触发机关并打开入口；真实营养罐接受 E 吸收，成长为人形后 HUD 同步更新。
- **遭遇门与出怪**：幼芽不触发封闭战斗；人形进入后建立正确波次并补满生命；敌人清空后标记完成、打开右门。
- **死亡与局部重试**：关卡即死绕过普通战斗保护；死亡只记一次，延迟后进入暂停重试菜单；恢复战前形态和资源、补满生命、清零速度，清除当前敌人及弹体，并保留已完成遭遇。
- **暂停与反馈**：暂停清理命中停顿，时间缩放恢复正常；暂停时间不累计，继续后计时恢复。
- **普通组合与两轮庭院**：甲虫、孢子、机兵的对应遭遇依次触发和完成；庭院每轮三只，第一轮清空后才建立第二轮；掉出有效区域的敌人按击败处理，不锁死房间。
- **树冠平台路线**：人形和成熟形态分别用实际移动与跳跃通过六个平台；起点定位后，平台之间不通过瞬移替代物理移动。
- **精英与胜利**：精英单独出现；失败重试回到战前准备区 `x = 7360`，等待玩家再次进入；锁定出口不能完成，击败守圃者仅解锁出口，进入出口才设置完成并暂停结算。

## 3. 测试方法与实际边界

集成脚本实例化生产主场景，没有新增可玩的测试关卡。为隔离各个生命周期用例，部分步骤直接把玩家定位到营养罐或遭遇入口，并用直接伤害请求清空波次。这验证了出怪、死亡、重试、开门与通关接线，不能作为玩家实际战斗难度或完整连续通关的证明。

培养室低位通道与两形态树冠路径使用真实物理移动；它们不证明全部探索支路、每个跳跃习惯或真人首次路线理解都已验收。音频自动测试验证接线，不代替听音混合；headless 测试不证明图像质量、实际显示帧率或 Windows 导出包完整性。

当前仍需按计划完成至少三轮完整人类试玩，其中一轮由未参与实现的人进行。首次整关 10–15 分钟、首次精英战 60–120 秒仍是待校准目标。已有下节的姿态慢放录像与抽样检查；连续真人玩法中的动作复核、完整音频混合和导出版本稳定帧率仍须分别留证，不能由自动化结果推导为已完成。

## 4. 最终画面与动作检查产物

| 产物 | 已完成的检查 | 证据边界 |
| --- | --- | --- |
| [main_nursery.webp](../build/qa/combat-visuals/main_nursery.webp) | 最终培养室截图已更新，包含新苔藓地面和正式 HUD 布局 | 静态画面，不证明连续游玩或帧率 |
| [combat_pose_review.avi](../build/qa/combat-visuals/combat_pose_review.avi) | 约 32 秒，两形态共 18 个动作条目的左右朝向慢放；已抽查重击左右朝向与收招帧 | 程序化姿态检查，不是连续真人玩法录像；未宣称所有帧均经人工验收 |
| [重击右向](../build/qa/combat-visuals/combat_poses_heavy.webp)、[重击左向](../build/qa/combat-visuals/combat_poses_heavy_left.webp) | 左右动作样本与录像配合检查 | 样本不替代全部地空组合与实际战斗反馈的验证 |

新苔藓地面源图为 1774 × 887，经 imagegen 编辑自既有 _0036_苔藓地1.png；静态 AtlasTexture 裁去上方 98 像素，平直顶缘与地形碰撞对齐。该图属于旧场景素材的 AI 衍生作品，原作者／发布许可待确认状态保持不变，详见 [来源](credits.md) 和 [制作记录](../assets/source/combat/production_notes.md)。

## 5. 复现

从项目根目录使用 Godot 4.7.2：

```text
godot --headless --path . --fixed-fps 60 --script res://tests/scene/test_greenhouse_level.gd
godot --headless --path . --script res://tests/scene/test_level_main.gd
godot --headless --path . --script res://tests/scene/test_handbuilt_floor_pieces.gd
godot --headless --path . --script res://tests/scene/test_player_audio.gd
godot --headless --path . --script res://tests/scene/test_handbuilt_hud.gd
```

检查最终断言数量、失败数、退出码及 stderr。项目新增变更后应重跑相关测试；旧日志只证明对应运行时的状态。截图、日志、录像和导出结果放在带 .gdignore 的 build 目录，不混入运行时素材。

相关文档：[架构](architecture.md)、[玩家 API](api/player.md)、[战斗设计与里程碑](combat_design.md)、[战斗组件验证](combat_validation.md)。
