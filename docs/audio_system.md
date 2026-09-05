# 音效播放器方案

## 当前边界

正式玩家、按钮和其他组件暂不接入音效。可复用播放器位于 `features/audio/sound_emitter.tscn`，走路接线只存在于 `features/audio/walk_sound_test.tscn`。

## 分层与职责

- `SoundDefinition`：一个逻辑音效的 ID、变体资源、音量、最短触发间隔和随机音高。
- `SoundBank`：按 `StringName` 建立音效 ID 到配置资源的 O(1) 查询表。
- `SoundEmitter`：拥有固定声音通道池，负责变体轮换、冷却、空闲通道选择和必要时的循环抢占。
- 使用方组件：只发出“播放哪个 cue”的命令，不持有 `AudioStreamPlayer`，也不修改共享资源。

## 使用契约

```gdscript
@onready var sounds: SoundEmitter = %Sounds

func _on_action_done() -> void:
    sounds.play_cue(&"button")
```

组件场景实例化 `SoundEmitter` 后，在 Inspector 指定一个 `SoundBank`；音频文件只登记在 `SoundDefinition` `.tres` 中。播放器默认路由到 `SFX`，找不到该总线时安全回退到 `Master`。

## 后续接入顺序

1. 先为 UI、玩家动作、敌人和机关分别建立小型 `SoundDefinition`/`SoundBank`。
2. 各组件只在“事实发生后”调用播放器，例如按钮确认成功、脚落地、机关状态改变。
3. 再集中调 `SFX` 总线音量和各 cue 的音量/冷却，不在组件逻辑里散落魔法数字。
4. 若全局同时播放量明显增加，再把固定通道池提升为全局音频服务；当前 Game Jam 规模使用局部池更简单，也能避免每次 one-shot 创建节点。

## 验证

- F6：运行 `features/audio/walk_sound_test.tscn`，按住 A/D 应听到脚步音效并看到播放计数。
- 场景测试：`tests/scene/test_player_audio.gd` 验证 cue、SFX 总线、资源赋值、冷却和固定通道池。

