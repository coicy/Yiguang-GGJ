# 正式地形资产制作记录

日期：2026-09-06。制作范围为十个不同结构职责的新部件、二十张已有场景原图复用，以及可编辑的裁切／材质配置。素材数量按职责与原图来源记录；同图裁切、复制、换色、镜像和缩放不计作新生成素材。

## 新图集的生成与透明处理

两张图集由本项目使用 OpenAI ImageGen 制作，延续既有植物／旧设施风格；不冒称人工绘制作者，不新增CC0、MIT等第三方开源许可声明。初次输出实际为带棋盘背景的RGB位图；随后通过ImageGen编辑请求透明背景，得到RGBA版。原始输出、编辑输出均保留。

| 图集 | 首次源文件与真实尺寸／格式 | ImageGen清底编辑结果 | runtime文件 |
|---|---|---|---|
| 建筑结构 | architecture_kit_source.png；1536 × 1024；8-bit RGB，无alpha | architecture_kit_alpha.png；1536 × 1024；8-bit RGBA | assets/runtime/terrain/architecture_kit.png |
| 生态结构 | ecology_kit_source.png；1254 × 1254；8-bit RGB，无alpha | ecology_kit_alpha.png；1536 × 1024；8-bit RGBA | assets/runtime/terrain/ecology_kit.png |

清底编辑由ImageGen完成，没有用Python或其他像素工具处理图像。生态图编辑后画布尺寸发生变化，因此裁切以最终RGBA版的真实轮廓为准，不能沿用首次方形图的格子坐标。两个runtime PNG均为各自alpha版的原样副本，已直接核对文件内容相同。

RGBA版仍有部分低alpha光晕。运行时通过 [terrain_cutout.gdshader](../../../features/level/terrain/terrain_cutout.gdshader) 的alpha_clip=0.85丢弃这些像素；这是显示方式，不是重新导出／修图。2026-09-06合并上游植物灯与遮光设计后，材质使用默认CanvasItem受光，保留PointLight2D照明和阴影响应。

## 十件独特功能部件

以下均为 [parts目录](../../runtime/terrain/parts/) 中可编辑AtlasTexture，region格式为x、y、宽、高。资源设置filter_clip=true，避免采样到相邻图像。这里是两张图集中的十件部件，不是十次重复生成同一地块。

| 裁切资源 | 最终RGBA图集 | Rect2区域（px） | 功能职责 |
|---|---|---|---|
| [drain.tres](../../runtime/terrain/parts/drain.tres) | architecture_kit.png | 20, 224, 476, 128 | 排水格栅与沟口；地点性设施，避免沿全地面重复 |
| [catwalk.tres](../../runtime/terrain/parts/catwalk.tres) | architecture_kit.png | 519, 225, 493, 127 | 金属格栅踏面与承重侧梁 |
| [culvert.tres](../../runtime/terrain/parts/culvert.tres) | architecture_kit.png | 1039, 138, 478, 221 | 砌筑拱洞／水渠结构 |
| [pipe.tres](../../runtime/terrain/parts/pipe.tres) | architecture_kit.png | 77, 452, 341, 444 | 带阀门的弯管设施 |
| [buttress.tres](../../runtime/terrain/parts/buttress.tres) | architecture_kit.png | 605, 441, 303, 462 | 带箍支柱与基脚 |
| [core_plinth.tres](../../runtime/terrain/parts/core_plinth.tres) | architecture_kit.png | 1016, 687, 502, 217 | 核心铜质台基与石质上沿 |
| [root_soil.tres](../../runtime/terrain/parts/root_soil.tres) | ecology_kit.png | 70, 43, 679, 376 | 根系交织的岩土截面 |
| [fungal_log.tres](../../runtime/terrain/parts/fungal_log.tres) | ecology_kit.png | 821, 43, 694, 397 | 附生菌朽木；地点性部件，避免连续铺成漂浮原木 |
| [seedling_tray.tres](../../runtime/terrain/parts/seedling_tray.tres) | ecology_kit.png | 30, 599, 708, 333 | 分格幼苗种植槽 |
| [broken_planter.tres](../../runtime/terrain/parts/broken_planter.tres) | ecology_kit.png | 811, 440, 676, 546 | 破裂花盆、露土与根系 |

atlas_regions.json是首次区域检查结果；最终.tres是运行时裁切真值。首次buttress区域误含右侧台基，其最终区域已缩为(605,441,303,462)；core_plinth取(1016,687,502,217)。二者不交叠，已在资源检查中验证。

现有 [branch_run.tres](../../runtime/terrain/parts/branch_run.tres) 是用户旧图 _0026_树枝平台（延申）.png 的实心长杆中段Rect2(270,42,166,23)，用于连续可踩枝面；它属于已有素材复用，不是第十一件新生成资产。有完整端头和节疤的原枝可继续用于WHOLE_TEXTURE独立平台，避免把完整枝重复排出假坑。

## 二十张旧原图复用

这二十张图来自用户此前提供的png.zip，源文件位于assets/source/scenery_png/png/。本轮从已存在的源文件收录到runtime，未生成新变体，未修改像素，二十对源／runtime文件内容已逐项核对相同。原作者与对外发布许可仍待确认；导入、裁切、组合或生成构建不会改变这一状态。

| 源图 | 原始尺寸（px） | runtime位置 | 处理与许可 |
|---|---:|---|---|
| [_0001_草团2.png](../scenery_png/png/_0001_%E8%8D%89%E5%9B%A22.png) | 258 × 137 | assets/runtime/scenery/_0001_草团2.png | 原样副本；许可待确认 |
| [_0003_红花2.png](../scenery_png/png/_0003_%E7%BA%A2%E8%8A%B12.png) | 124 × 211 | assets/runtime/scenery/_0003_红花2.png | 原样副本；许可待确认 |
| [_0004_针草1.png](../scenery_png/png/_0004_%E9%92%88%E8%8D%891.png) | 181 × 133 | assets/runtime/scenery/_0004_针草1.png | 原样副本；许可待确认 |
| [_0005_针草2.png](../scenery_png/png/_0005_%E9%92%88%E8%8D%892.png) | 238 × 238 | assets/runtime/scenery/_0005_针草2.png | 原样副本；许可待确认 |
| [_0010_藤蔓3.png](../scenery_png/png/_0010_%E8%97%A4%E8%94%933.png) | 328 × 246 | assets/runtime/scenery/_0010_藤蔓3.png | 原样副本；许可待确认 |
| [_0012_高草2.png](../scenery_png/png/_0012_%E9%AB%98%E8%8D%892.png) | 202 × 314 | assets/runtime/scenery/_0012_高草2.png | 原样副本；许可待确认 |
| [_0013_高草3.png](../scenery_png/png/_0013_%E9%AB%98%E8%8D%893.png) | 104 × 255 | assets/runtime/scenery/_0013_高草3.png | 原样副本；许可待确认 |
| [_0015_培养罐.png](../scenery_png/png/_0015_%E5%9F%B9%E5%85%BB%E7%BD%90.png) | 329 × 796 | assets/runtime/scenery/_0015_培养罐.png | 原样副本；许可待确认 |
| [_0016_量杯.png](../scenery_png/png/_0016_%E9%87%8F%E6%9D%AF.png) | 110 × 160 | assets/runtime/scenery/_0016_量杯.png | 原样副本；许可待确认 |
| [_0017_锥形瓶1.png](../scenery_png/png/_0017_%E9%94%A5%E5%BD%A2%E7%93%B61.png) | 98 × 144 | assets/runtime/scenery/_0017_锥形瓶1.png | 原样副本；许可待确认 |
| [_0020_爬墙藤.png](../scenery_png/png/_0020_%E7%88%AC%E5%A2%99%E8%97%A4.png) | 112 × 225 | assets/runtime/scenery/_0020_爬墙藤.png | 原样副本；许可待确认 |
| [_0025_根部延申.png](../scenery_png/png/_0025_%E6%A0%B9%E9%83%A8%E5%BB%B6%E7%94%B3.png) | 406 × 224 | assets/runtime/scenery/_0025_根部延申.png | 原样副本；许可待确认 |
| [_0027_图层-57.png](../scenery_png/png/_0027_%E5%9B%BE%E5%B1%82-57.png) | 537 × 148 | assets/runtime/scenery/_0027_图层-57.png | 原样副本；许可待确认 |
| [_0029_石板.png](../scenery_png/png/_0029_%E7%9F%B3%E6%9D%BF.png) | 484 × 114 | assets/runtime/scenery/_0029_石板.png | 原样副本；许可待确认 |
| [_0032_底面地板.png](../scenery_png/png/_0032_%E5%BA%95%E9%9D%A2%E5%9C%B0%E6%9D%BF.png) | 502 × 170 | assets/runtime/scenery/_0032_底面地板.png | 原样副本；许可待确认 |
| [_0033_底面地板.png](../scenery_png/png/_0033_%E5%BA%95%E9%9D%A2%E5%9C%B0%E6%9D%BF.png) | 568 × 165 | assets/runtime/scenery/_0033_底面地板.png | 原样副本；许可待确认 |
| [_0034_水泥板.png](../scenery_png/png/_0034_%E6%B0%B4%E6%B3%A5%E6%9D%BF.png) | 468 × 120 | assets/runtime/scenery/_0034_水泥板.png | 原样副本；许可待确认 |
| [_0035_草地坡.png](../scenery_png/png/_0035_%E8%8D%89%E5%9C%B0%E5%9D%A1.png) | 567 × 146 | assets/runtime/scenery/_0035_草地坡.png | 原样副本；许可待确认 |
| [_0040_垂坠1.png](../scenery_png/png/_0040_%E5%9E%82%E5%9D%A01.png) | 480 × 237 | assets/runtime/scenery/_0040_垂坠1.png | 原样副本；许可待确认 |
| [_0041_垂坠2.png](../scenery_png/png/_0041_%E5%9E%82%E5%9D%A02.png) | 256 × 367 | assets/runtime/scenery/_0041_垂坠2.png | 原样副本；许可待确认 |

除上述新收录二十张以外，原本已经在runtime中的苔藓薄台、石板、水泥板、钢板、完整枝体等继续复用；它们的来源状态见 [credits.md](../../../docs/credits.md) 与 [资产审计](../../../docs/terrain_asset_audit.md)。原审计的“尚未收录”数字是审计时快照，二十张复用发生在该快照之后。

## 可编辑入口与组合边界

- [TerrainSurface资源](../../../features/level/terrain/data/)：nursery、moss、spore、workshop、canopy、courtyard、core，分别保存顶面、截面、支撑、自然尺寸上限与颜色。
- [terrain_skin.tscn](../../../features/level/terrain/terrain_skin.tscn)：只负责表现，保留profile、span、depth、pattern_offset接口。碰撞仍由TerrainPiece拥有。
- 图像按自然比例绘制；深度裁切下缘而不把短板竖向撑高；有限面板均分宽度后等比缩放，避免最后半个洞口。浅台不足以展示支撑时不画被截断的支撑碎片。
- 上游WHOLE_TEXTURE=2与WholeArtwork节点继续保留。show_artwork=false隐藏旧三种外观及端头，让TerrainSkin显示，但不改变手工碰撞或根缩放。完整不规则原图不强制替换为连续矩形皮肤。
- nursery／spore的主要连续墙基使用旧板底32／33。drain、pipe、fungal_log、seedling_tray、broken_planter用于有目的的地点性设施；不通过密集重复这些大轮廓凑地形丰富度。
- 此处保留的是原始位图、ImageGen编辑位图和Godot可编辑资源；没有交付PSD分层工程，不能将两个图集称为手工分层原画工程。

## 已做验证与证据

- 现有test_handbuilt_floor_pieces补充整图／隐藏外观／TerrainSkin兼容例：保留上游根缩放和手工碰撞，隐藏WholeArtwork后Skin可见；切换隐藏Polygon模式时端头不复活。测试通过。
- test_terrain_visual_capture检查十个Atlas可加载、裁切在图集内、相邻支柱／台基不串图、七套材质可加载和截图保存，共29项；profiles_a、profiles_b及两档受光捕获均为0失败。
- [材质A](../../../build/qa/terrain-visuals/terrain_profiles_a.webp)、[材质B](../../../build/qa/terrain-visuals/terrain_profiles_b.webp)、[十件部件](../../../build/qa/terrain-visuals/terrain_parts.webp)。树冠连续面与90×28短台现为实心走面，未见原来的假坑／截断悬枝碎片。
- 明亮环境下同色植物灯对照：[energy 1.8](../../../build/qa/terrain-visuals/terrain_lit_day_1p8.webp)在板底／根土上产生明显黄亮斑；[energy 0.3](../../../build/qa/terrain-visuals/terrain_lit_day_0p3.webp)保留更清楚的纹理。建议明亮正式场景采用低强度实例覆盖，保留上游暗场景的组件默认；此文不修改场景灯光参数。

验证在Godot4.7.2 Compatibility、NVIDIA GeForce RTX4060上进行。headless组件测试正常退出；GPU捕获存在环境user://缓存目录不可建立的提示，但图片成功渲染保存。资源和静态视觉检查不替代正式关卡可达性、碰撞落脚和真人完整试玩验收。
