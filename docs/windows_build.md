# Windows 战斗验证版（内部评审）

状态：2026-09-06 当前战斗系统已构建为内部评审用的战斗验证版，并通过独立 headless 与实际 OpenGL 启动验证。此版本不是最终交付；正式地形设计、新地表素材及区域重构将另行制作，完成后需要重新构建。

## 产物与运行

- 运行 `build/windows/失控温室-战斗验证版.exe`；同目录保留 `libspine_godot.windows.template_release.x86_64.dll`。
- PCK 已嵌入 EXE，不需要另行分发 PCK。目标平台为 Windows x86_64，使用 Godot 4.7.2 release 模板。
- 本产物用于内部评审。角色、部分场景素材的来源／许可和 Spine 运行时授权尚未完成确认，不能视为公开发行许可已经完成。详见 `docs/credits.md` 与构建目录内的 `INTERNAL_REVIEW.txt`。

## 导出设置

原 `Windows Desktop` preset 保持不变。新增 `Windows Internal Review` preset，沿用既有图形、压缩与 PCK 设置，添加 `internal_review` 特性及内部评审产品描述。

内部评审 preset 排除 `tests/`、`docs/`、`assets/source/`、`build/`、`builds/`、本地 `Godot/` 数据、旧 `2.0/` 工程、原始设计文件和归档，以及非 Windows 平台的 Spine 二进制。战斗验证导出日志确认上述目录没有进入 PCK。测试及截图产物放在带 `.gdignore` 的 `build/` 内。

官方模板来源：[Godot 4.7.2 发布页](https://godotengine.org/download/archive/4.7.2-stable/)、[官方模板包](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz)。仅从该 ZIP 包提取 Windows x86_64 release、console、`icudt_godot.dat` 和 `version.txt`；没有下载或使用第三方引擎二进制。

本机模板安装位置：`C:/Users/Administrator/AppData/Roaming/Godot/export_templates/4.7.2.stable/`。导出时需确保 `APPDATA` 为 `C:/Users/Administrator/AppData/Roaming`。模板不存入仓库，不修改全局环境变量。

```powershell
$env:APPDATA = 'C:\Users\Administrator\AppData\Roaming'
& 'C:\Users\Administrator\AppData\Local\Temp\gj-playtest-KrDXa3\Godot_v4.7.2-stable_win64.exe' --headless --path . --export-release 'Windows Internal Review' 'build/windows/失控温室-战斗验证版.exe'
```

## 已执行的战斗验证构建验证

| 项目 | 结果 |
|---|---|
| release 导出 | 退出码 0；既有 `2.0` 嵌套项目被忽略的提示，无导出错误 |
| 导出 EXE 独立 headless 启动 | 180 帧，退出码 0，无 stderr |
| 导出 EXE 实际 OpenGL 启动 | 1280×720，600 帧，退出码 0，无 stderr |
| 显示启动采样 | 60 FPS 上限下，日志连续 8 次记录 60 FPS／16.66 ms；只覆盖培养室静止启动场景 |
| 依赖 | Spine release DLL 加载成功，未报告脚本或资源加载错误 |
| 战斗组件 | 129 项断言通过 |
| 正式八场遭遇自动实战 | 36 项断言通过；两形态均以实际攻击清空所有波次，无弹反、零死亡 |
| 正式关卡路线与生命周期 | 主任务报告 65 项断言通过，覆盖幼芽通行、两形态树冠路线、重试与出口 |

日志位于 `build/windows_export_final.log`、`build/windows_final_smoke.log` 和 `build/windows_final_opengl.log`。当前验证版 EXE 为 133,154,624 字节，Spine DLL 为 1,562,112 字节。本次验证版导出前再次通过 129 项战斗断言及四种敌人的 90 帧独立启动检查；日志见 `build/windows_final_prechecks.log`。

测试机器：Windows 10 build 19044 x64；Intel Core i5-14600KF，20 逻辑处理器；31.82 GiB RAM；NVIDIA GeForce RTX 4060，驱动 610.88（Windows 驱动版本 32.0.16.1088）；OpenGL 3.3 Compatibility。

## 验证边界

启动采样不能证明完整关卡、战斗高负载或不同硬件上始终稳定 60 FPS。自动战斗与移动证据见 `docs/combat_validation.md`；正式路线与生命周期已有上述自动验证；人工首次通关时长和三轮完整人类试玩仍未完成。未进行代码签名或公开发布。
