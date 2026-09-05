# Credits

本版使用已有素材分支 origin/lan 的 a591027 提交中的 19 个音效文件，保留原始文件名与音频字节。以下来源与 CC0 标识已在 2026-09-05 对照 Kenney 官方页面核实。

| 素材包 / 作者 | 许可证 | 使用文件（位于 assets/runtime/audio/） | 游戏用途 |
| --- | --- | --- | --- |
| [Impact Sounds / Kenney](https://kenney.nl/assets/impact-sounds) | CC0 | footstep_grass_000/001/002.ogg、footstep_concrete_000/001.ogg、impactSoft_medium_000.ogg、impactSoft_heavy_000.ogg、impactWood_medium_000.ogg | 脚步、落地、死亡、平台停止 |
| [RPG Audio / Kenney](https://kenney.nl/assets/rpg-audio) | CC0 | cloth1.ogg、cloth2.ogg、clothBelt.ogg、beltHandle1.ogg、metalLatch.ogg、creak1.ogg、handleCoins2.ogg | 跳跃、滑翔、伸腿、扎根、藤蔓、机关启动、吸收 |
| [UI Audio / Kenney](https://kenney.nl/assets/ui-audio) | CC0 | click3.ogg | 按钮触发 |
| [Music Jingles / Kenney](https://kenney.nl/assets/music-jingles) | CC0 | jingles_PIZZI00.ogg、jingles_PIZZI02.ogg、jingles_PIZZI06.ogg | 检查点、成长、枯萎 |

未从素材分支取用其标记为“待确认”的音乐和音效。没有完成来源、作者和许可证登记的外部内容，不进入最终导出包。

音效事件与音量由 features/audio 下的 SoundDefinition / SoundBank 资源维护；播放器位于 features/audio/sound_emitter.gd。各实例使用固定数量的声音通道，不修改共享 AudioStream 资源，不为每个 one-shot 创建新节点。正式玩家暂未接入，当前仅由独立 walk_sound_test 场景验证。
