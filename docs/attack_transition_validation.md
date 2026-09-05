# 移动与攻击衔接验证

日期：2026-09-06。引擎：Godot 4.7.2 stable，Windows，60 Hz 物理步长。仅调整生产玩家组件、战斗约束和动作衔接；没有新增可玩测试关卡。

## 行为

| 情况 | 实际行为 |
| --- | --- |
| 行走中轻击／重击 | 依当前水平速度短促减速，在前摇结束前站稳；有效段与收招不再由方向输入推动 |
| 持续按方向／反向输入 | 攻击朝向锁定；收招后恢复方向输入，步态按真实速度混合 |
| 上升／下落中普通攻击 | 使用空击与对应跳跃底层动画；保持纵向运动规律，水平保留惯性并允许 35% 加速度的方向修正 |
| 空击中接地 | 当帧结束伤害，身体接落地动作；藤蔓从接触瞬间曲线在 0.08 秒内收回 |
| 地面挥击时离开平台 | 中断地面招式并进入下落 |
| 同时按跳跃与普通攻击 | 当前帧先起跳，下一物理帧从输入缓存启动空击 |
| 收招末尾按跳跃 | 使用既有 0.15 秒跳跃缓存，恢复动作权限后起跳 |

招式伤害、距离和三个攻击阶段的配置未改动。空中攻击每次腾空仍限一次；落地恢复阶段没有伤害查询。四个新增手感参数保存在 features/combat/data/player_combat.tres。

## 验证边界

自动物理检查使用生产 Player 和非可玩碰撞夹具，图形录制使用正式主关卡。测试断言与录像用于验证输入、状态、姿势和接地回收，不代表完整新玩家试玩或战斗平衡验收。

## 已通过检查

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 移动／攻击衔接 | 616 项通过，覆盖两形态、地面刹停与步态、空中轨迹与惯性、落地关闭伤害、边缘、同帧输入与收招跳跃缓存 | build/qa/attack-transitions/test_attack_transitions.log |
| 幼芽跳跃限制 | 通过 | build/qa/attack-transitions/test_sprout_jump_lockout.log |
| 既有战斗规则 | 129 项通过；伤害、取消、连段、去重、格挡和弹反回归 | build/qa/attack-transitions/test_combat_system.log |
| 原有移动响应 | 三形态起步 0.100 秒、停止 0.067 秒、反向消速 0.050 秒；与改动前一致 | build/qa/attack-transitions/test_player_movement_response.log |
| 藤蔓既有契约 | 901 项通过 | tests/scene/test_vine_whip_visual.gd |
| 接地藤蔓采样 | 648 项通过；两形态、左右与六种中断时刻，回收单调、重复采样不累乘、末尾隐藏 | build/qa/vine-attack/test_landing_sampling.gd |
| Spine 动作与姿势 | 18 类姿势检查与 Spine 导入检查通过 | tests/scene/test_combat_visual_poses.gd、test_spine_imports.gd |
| 玩家独立场景／正式 F5 | 各 120 帧，退出码 0，stderr 为空 | build/qa/attack-transitions/player_f6.log、main_f5.log |

同帧跳跃检查使用真实 Player 物理回调及 InputEventAction 注入；不用手工调用 _physics_process 时的输入瞬时标记代替真实输入。正式关卡和角色场景保持原有相机、灯光与环境配置。

## 正常速度图形证据

录制脚本 tools/capture_attack_transitions.gd 使用正式主关卡中的生产 Player 与真实输入／物理更新。两形态各四段：行走轻击接跑动、行走重击接反向移动、同帧跳跃空击、下落挥击中接地并继续走动。录像为 1280×720、60 fps、748 帧，约 12.47 秒，播放速率 1×。

- build/qa/attack-transitions/attack_transitions_1x.avi：完整正常速度录像。
- build/qa/attack-transitions/transition_manifest.json：746 个有标记的运动／攻击状态采样，另有两帧录制初始化／结束画面。
- 同目录 *_windup.webp、*_strike.webp、*_landing.webp、*_resume.webp：关键帧。

已查看地面站稳、腾空收腿，以及两形态长藤接地画面，藤蔓与手部连续连接。录制实例固定原普通战斗 2.1 倍镜头用于比较，没有修改生产相机配置。图形日志有既有 shader 缓存目录提示及磁盘空间提示；录像已完整写入，无新脚本或节点错误。

[正常速度动图预览](../build/qa/attack-transitions/attack_motion_preview.gif)从上述录像裁切动作区域并缩小至 768×280；374 帧、30 fps，保留 12.47 秒实际时长，未慢放。裁切范围已按逐帧坐标核对，覆盖角色移动与藤蔓范围。
