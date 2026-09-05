# TerrainSkin 地形表现接口

TerrainSkin只绘制表现，不建立或修改碰撞。正式关卡仍由TerrainPiece决定几何。

- `profile`：引用 `data/{nursery,moss,spore,workshop,canopy,courtyard,core}.tres`。
- `span`：可见水平范围，局部x从0至span。
- `depth`：向下可见范围；短平台裁去下面的图像，深平台不会把短板纵向拉长。
- `pattern_offset`：表面候选图顺序偏移。当前每区主要采用一张顶面，多个候选时才可见变化。
- 局部 `(0,0)` 对应碰撞站立面。节点不应以非等比scale改变比例。

`terrain_skin.tscn` 是独立可启动部件。直接挂 `terrain_skin.gd` 的节点也会在_ready自动取得 `terrain_cutout.tres`；需要独立Sprite2D展示图集部件时手动复用该材质。alpha_clip=0.85去掉清底后低alpha光晕，源图与PNG文件不受修改。

## 三个图像层

表面、截面和支撑分别配置，尺寸均为保持原比例的上限。连续段按完整面板数量均分宽度再等比缩放；所以实际高度可小于配置上限。末段不会横向截出半个洞口，深度只裁切。

| 材质 | 表面高度上限 | 截面高度上限 | 支撑高度上限 | 连续主体 |
|---|---:|---:|---:|---|
| nursery | 10 | 74 | 无 | 原有板底32，灰绿 |
| moss | 16 | 114 | 无 | 根土截面 |
| spore | 10 | 74 | 无 | 原有板底33，湿冷灰绿 |
| workshop | 12 | 57 | 84 | 金属格栅侧梁 |
| canopy | 48 | 无 | 76 | 原有完整树枝、原有L形根托 |
| courtyard | 8 | 102 | 112 | 石拱沟渠结构 |
| core | 8 | 95 | 128 | 核心基座 |

截面与支撑从表面高度的0.35倍处起画，向下受depth限制。nursery/moss/spore在图像背后有暗色基础填充；其他材质保持结构之间的透明空间。支撑也受span/depth裁切，不会自动向碰撞范围外伸出。

排水件、管道、菌木、幼苗槽、破罐应作为少量地点性部件由场景作者选择，不在连续地面中重复铺放。10个独立AtlasTexture在 `assets/runtime/terrain/parts`。buttress裁切已排除邻近core_plinth；两图集没有新增生成。

## 验证

`tests/scene/test_terrain_visual_capture.gd` 是现有生产资源的非可玩捕获脚本，模式为 profiles_a、profiles_b、parts；输出到 `build/qa/terrain-visuals`。检查10个Atlas资源及区域边界、两块相邻结构不串图、7套材质可加载和截图保存，共29项。检查不宣称地形与碰撞已完成主场景验收；实例坐标与摆放由正式关卡集成负责。

2026-09-06：3组渲染检查各0失败，TerrainSkin独立场景headless启动退出正常。GPU渲染机为NVIDIA GeForce RTX 4060，Godot4.7.2 Compatibility。环境user://着色器缓存目录不可建，日志有缓存提示，但本轮渲染与输出完成。
