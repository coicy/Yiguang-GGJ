# 修枝车间：两张正式图与配准记录

2026-09-06。依据 [车间施工JSON](../assets/source/rooms/workshop/layout.json) 制作；本次交付近景和背景素材及配准建议，正式主场景接入由关卡实现方完成。

## 图像与构图

| 图像 | 原始与运行时文件 | 实际规格 |
|---|---|---|
| 完整近景 | [foreground_onepass.png](../assets/source/rooms/workshop/foreground_onepass.png) → [workshop_foreground.png](../assets/runtime/rooms/workshop_foreground.png) | 1788×880，RGB，无alpha；空域为接近纯白的去白底 |
| 完整远景 | [distant_layer.png](../assets/source/rooms/workshop/distant_layer.png) → [workshop_distant.png](../assets/runtime/rooms/workshop_distant.png) | 1789×879，RGB，不透明 |
| 几何指南 | [geometry_guide.svg](../assets/source/rooms/workshop/geometry_guide.svg)、[geometry_guide.png](../assets/source/rooms/workshop/geometry_guide.png) | 2048×1010；从已有layout的两个碰撞多边形绘制，非可玩地图 |

近景一次统一绘制全部地基、屋顶设备壳体、根系、稀疏侵入植被与左端营养器官。左间是低位压机壳体和弯曲通风管，右间为更高的分段修枝刀具罩；中间留下检修上行口。两片平整战斗台与三阶属于连续金属面板、格栅与混凝土承托，根系抓住承重梁。没有把培养室根拱复制成两间房，也没有另外补贴植物或罐盆。

背景由这张近景作为编辑目标生成完整后壁：左间液压修枝设备、右间长修枝输送设备、连接部的斜向检修玻璃廊和暗黄窗光。前景的实心轮廓与白色空域均被背景后壁补全；原近景继续在独立层绘制。原图背景已有较弱边缘与空气感，接入时仍按实际玩家尺寸检查前后对比；不要把背景机器赋予碰撞。

## 来源和制作方法

使用内置OpenAI image_gen.imagegen，两次调用分别生成近景和背景，均成功。近景参考图1是本房间的几何指南；参考图2为已认可培养室foreground_onepass.png，**只用于绘画风格**。背景由车间近景编辑补全，没有再引用培养室构图。完整提示词保存为 [foreground_prompt.txt](../assets/source/rooms/workshop/foreground_prompt.txt) 与 [background_prompt.txt](../assets/source/rooms/workshop/background_prompt.txt)。

原始返回PNG与runtime副本均保持像素不变，没有用程序删除白色、补画叶片或修改颜色。可编辑源是PNG、SVG指南和JSON配准点，未交付PSD分层工程；该批为本项目AI生成素材，不冒称人工手绘作者，也不另行声明CC0/MIT许可。

## 接入合同

[registration.json](../assets/source/rooms/workshop/registration.json) 登记原图尺寸、实际走边像素、屋顶边缘样点、建议变换和独立去白材质参数。保持layout的入口(3640,440)、出口(5080,330)、两场560宽战斗面与40/40/30三阶。

近景统一参考scale=1440/1788≈0.805369，origin=(3640,-60.134228)，以图中左台面pixel y621准确锚定world y440。右台面pixel y485由此映射world约330.470，与目标差0.470。实际首阶约pixel(850,569)、第二阶(940,523)、第三阶(1033,485)。首阶X直接缩放落在4324.564，比目标4336早11.436；第二阶落在4397.047，比4404早6.953。它们不能被写成已达到≤3世界单位配准。

建议保留玩法碰撞坐标，使用registration中的foundation_uv_correspondence将同一近景纹理UV对齐完整基础多边形；不要为图像漂移修改战斗场宽度或随意缩窄助跑区。屋顶生成结果也有轮廓偏移，尤其左间设备壳体的中央垂下部，其位置不同于原指南。JSON保留实际source_vault_edge_pixels，供接入方对照做局部UV配准或明确修订碰撞轮廓；未经处理不能称整个房体已经精确贴合设计。较高屋顶与台面之间的运动净空仍以施工JSON和真实输入验证为准。

背景建议origin=(3640,-60)、等比scale=1440/1789≈0.804919；这使横向范围精确对应整房间。上下不足约2.5世界单位的底边位于实心地基后，可用房间底色覆盖。前后图尺寸相差1像素，未通过改图伪称两层像素完全相同。

### 去白与营养亮部

复用已修复的 [foreground_cutout.gdshader](../features/level/rooms/foreground_cutout.gdshader)，但为车间使用独立ShaderMaterial参数。不能原样共享培养室foreground_cutout.tres内的亮部中心(1012,688)。车间建议值：highlight_center_px=(34,618)、highlight_radius_px=(26,30)、highlight_preservation=1、opaque_floor=0.28。

近景空域抽样RGB为(254,254,254)、(254,253,253)、(255,254,254)，不是带alpha的透明图，也不是每个像素严格255。现有材质按白底覆盖率去混色，并在matte0.95–0.99区间归零，适合这些样点；不可改回二值阈值或只删外连白区，否则细叶间隙与边缘会重新发白。白边最终以正式main中的深色背景截图确认。

营养器官视觉中心约pixel(34,618)，按上述变换约world(3667.4,437.6)，位于layout营养Area中心(3665,425)的48×48范围内。Area保持原设计位置；单独事件亮光可跟随实际画中器官中心。它是画在台基接缝的发光器官，不新增独立玻璃罐或盆。

## 已完成检查与交接范围

已实际查看完整近景与背景：两间用途和高低关系可区分，近景三阶及两片连续作业面可读，全部植被一次绘入；记录了像素尺寸、白底样点与台肩/屋顶偏差。JSON和文档链接已检查。没有启动Godot或改写主场景/生成器，故运行时去白、碰撞配准、战斗遮挡和真实输入通路由接入后的主场景验证；本记录不把原画查看写成正式验收通过。
