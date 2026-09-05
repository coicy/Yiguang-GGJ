# 隔离庭院与温室核心：几何交接与素材制作

2026-09-06。**可编辑布局JSON、注册一致的前景/后景SVG已完成；最终位图由根任务生成和集成。** 本子任务没有改主场景、生成器或玩法脚本。最新任务期间没有启动Godot。

## 可执行数据入口

| 房间 | JSON | 前景几何目标 | 后景构图目标 |
|---|---|---|---|
| 隔离庭院 | [layout.json](../assets/source/rooms/courtyard/layout.json) | [foreground_layout.svg](../assets/source/rooms/courtyard/foreground_layout.svg) | [background_layout.svg](../assets/source/rooms/courtyard/background_layout.svg) |
| 温室核心 | [layout.json](../assets/source/rooms/core/layout.json) | [foreground_layout.svg](../assets/source/rooms/core/foreground_layout.svg) | [background_layout.svg](../assets/source/rooms/core/background_layout.svg) |

schema为authored-room-layout/v1。shells[].polygonWorld可作为近景轮廓和独立World碰撞；foundationPolygonWorld保存完整地基；walkContourWorld保存脚面；battle、connections、embeddedSources保存净空与功能锚点。所有位置是世界坐标，正y向下。纹理字段仍为空，不把纯几何SVG当成正式美术。

两个房间使用相同artScale=0.5，转换为：像素坐标=(世界坐标-artOrigin)/0.5。庭院artOrigin=(6480,-250)，画布1920×1200；核心artOrigin=(7440,-250)，画布2360×1200。生成图片若改变尺寸，应先核对轮廓比例并记录实际映射，不能静默把旧注册硬套到新输出。

## 路线与嵌墙资源

| 区域 | 世界坐标 |
|---|---|
| 庭院入口 | x6480，前一区脚面y170，沿左边界下落40到y210；前一区负责x6480之前的高走面 |
| 庭院战斗面 | x6480..7040，宽560，脚面y210，中央无障碍 |
| 第一阶 | x7040升40到y170，台面至7160 |
| 第二阶及准备区 | x7160再升40到y130，连续台面至7440 |
| CoreGrowth | 营养源锚点(7240,158)，建议吸收半径78；视觉腔中心(7240,162)，圆润亮绿膜和供养根嵌于基础内 |
| CoreWither | 污染源锚点(7370,163)，建议吸收半径70；视觉口中心(7370,166)，横向裂口金属格栅与紫色排液，区别于绿色圆腔 |
| 核心精英面 | x7440..8160，宽720，脚面y130；这一区域所有顶碰撞y<=-100，净高至少230 |
| 核心出口廊 | x8160..8620仍为y130连续地面，出口锚点(8370,130) |

两个源均在战斗房之外。视觉口嵌在y130脚面之下的连续墙基，没有落地盆罐和新的地面障碍。它们的站立锚点分别为(7240,130)、(7370,130)；二者之间没有台阶、落差、坑或战斗触发区，幼芽可以从污染点沿同层走回营养点。建议半径在几何上覆盖人形/幼芽站立中心，但吸收、枯萎恢复和锁门仍须由根任务实机验证。

庭院的前景几何采用不对称破损西拱和准备区顶壳，中间x6670..6940留出断裂天窗。核心采用完整高拱加厚基础，右侧接低出口廊。不要将这两种房间重新排成相同的对称桥面。

## ImageGen接入关键点

沿用用户认可的nursery/foreground_onepass.png作为植物、根系和旧石材画法参考，不复制其低洞或台阶布局。目标图像以各自foreground_layout.svg的几何为准，一次完成完整近景，空气为纯白，沿用既有去白材质；不生成重复地块、悬浮根条或新盆罐。background_layout.svg是低对比远景构图，不含可踩地形和近景实体。

庭院脚面像素坐标：

- (0,920)→(1120,920)→(1120,840)→(1360,840)→(1360,760)→(1920,760)。
- CoreGrowth视觉中心为(1520,824)，CoreWither视觉中心为(1780,832)。

核心全脚面像素y=760。**精英厅占核心源图左侧1440像素，右侧920像素是出口廊，不能把主拱和培养核移到整张图中央。** 后景培养核世界中心(7800,-30)对应像素(720,440)。它以低对比青绿玻璃和输养根系表现，不是中央碰撞柱；不得有抢过守圃者红色重砸预警的黄白热点或红光。

后续提示词保存在[courtyard/prompts_pending.md](../assets/source/rooms/courtyard/prompts_pending.md)与[core/prompts_pending.md](../assets/source/rooms/core/prompts_pending.md)，由根任务结合图像参考提交。这些文字尚未宣称存在对应输出图。

## 已做验证与限制

23项静态检查全部通过，记录于[layout_validation.json](../assets/source/rooms/core/layout_validation.json)：画布变换一致、主轮廓无自交、两级40高台阶、庭院/核心接缝y130、560/720宽平直战斗面、核心顶净空、源点位于战斗外且有同层恢复路线、建议半径覆盖幼芽/人形中心。这些是JSON几何检查，不是Godot运行或实机玩法验收。

最终位图尚由根任务生成，待实际图片到位后需重新对照站立边、植被外缘与像素注册，并在正式主场景验证源点吸收、幼芽恢复、精英预警可见性与出口路线。

## 旧稿、失败请求与来源

本子任务先前一次内置ImageGen请求返回HTTP429 / usage_limit_reached，未生成图片，未重试或切换CLI；原提示词和错误保留在[generation_request_failed.md](../assets/source/rooms/core/generation_request_failed.md)。根任务随后确认其图像请求可用，因此当前不等待本子任务额度，由根任务继续位图制作。

已实际查看并原样归档根任务提供的旧核心母稿为[reference_legacy_floor400.png](../assets/source/rooms/core/reference_legacy_floor400.png)，1672×941，原文件exec-40b909b1-68a5-4ed0-99f5-873e4a428a7f.png。它近景/后景已合成，中央黄白高光偏强，不能直接当作新前景或低对比后景。其原提示词未随委托提供，不用失败请求的提示词冒充来源。

core/collision_guide.png、geometry_guide.json、make_guide.gd属于旧脚面y400草稿，已明确标记废弃映射；layout_draft.json均由新layout.json取代。没有把旧图硬套到新y130路线。

当前SVG和布局由本项目代码制作，是几何制作源，不是完成的插画。旧核心和培养室参考来自本项目此前内置OpenAI ImageGen产出；不新增CC0或MIT声明。没有复制《空洞骑士》游戏美术、下载新外部资产或新增工具依赖。旧角色与scenery的原作者及发布许可待确认状态仍以docs/credits.md为准。
