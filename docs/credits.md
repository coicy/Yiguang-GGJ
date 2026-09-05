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

## 音频素材

| 素材包 / 作者 | 许可证 | 使用文件（位于 assets/runtime/audio/） | 游戏用途 |
| --- | --- | --- | --- |
| [Impact Sounds / Kenney](https://kenney.nl/assets/impact-sounds) | CC0 | footstep_grass_000/001/002.ogg、footstep_concrete_000/001.ogg、impactSoft_medium_000.ogg、impactSoft_heavy_000.ogg、impactWood_medium_000.ogg | 脚步、落地、死亡、平台停止 |
| [RPG Audio / Kenney](https://kenney.nl/assets/rpg-audio) | CC0 | cloth1.ogg、cloth2.ogg、clothBelt.ogg、beltHandle1.ogg、metalLatch.ogg、creak1.ogg、handleCoins2.ogg | 跳跃、滑翔、伸腿、扎根、藤蔓、机关启动、吸收 |
| [UI Audio / Kenney](https://kenney.nl/assets/ui-audio) | CC0 | click3.ogg | 按钮触发 |
| [Music Jingles / Kenney](https://kenney.nl/assets/music-jingles) | CC0 | jingles_PIZZI00.ogg、jingles_PIZZI02.ogg、jingles_PIZZI06.ogg | 检查点、成长、枯萎 |

未从素材分支取用其标记为“待确认”的音乐和音效。没有完成来源、作者和许可证登记的外部内容，不进入最终导出包。

事件映射与音量位于 features/audio/sound_emitter.gd；玩家步频与吸收音间隔位于 features/player/player_audio.gd。各实例使用固定数量的声音通道，不修改共享 AudioStream 资源，不每帧重复启动声音。
