# 培养室完整近景制作记录

日期：2026-09-06。当前依据用户最新要求：保留认可的背景；植被、墙体、地基和营养源先统一布局，再一次生成完整近景。旧版独立营养罐、盆状资源和散贴植物方案在本房间停用。

## 当前素材与职责

| 文件 | 用途 |
|---|---|
| assets/source/rooms/nursery/foreground_layout.svg / .png | 可编辑布局草图；确定低洞、三阶、墙内营养器官与植物覆盖体积 |
| assets/source/rooms/nursery/foreground_onepass.png | 新生成完整近景母稿，1632 × 964；未在旧完稿上反复编辑 |
| assets/runtime/rooms/nursery_foreground.png | 同一母稿的运行时副本 |
| assets/source/rooms/nursery/distant_layer.png | 已认可的青灰温室后景；保留远处母罐与空间骨架 |
| assets/source/rooms/nursery/registration.json | 近景变换、碰撞轮廓及实际营养交互位置 |
| features/level/rooms/foreground_cutout.gdshader | 运行时白底合成；源 PNG 的空白并非真实透明通道 |
| tools/nursery_room.mjs | 将上述图层、碰撞与房间相机接入正式主关卡 |

近景包含连续厚根壳、苔藓地被、附生小叶、蕨类、台壁垂落植物及右下大叶。植物的根部、遮挡和光照在同一张画中安排，不调用 nursery_ecology.mjs 逐棵粘贴。低矮草缘是视觉覆盖，不单独制造碰撞尖角。

首个营养源是一枚大而明亮的黄绿色输养器官，凹入第一阶挡土墙，外缘由根系和旧结构包住。静态外观属于近景原画，原 NutritionTank Area2D 继续负责 E 吸收和形态规则，隐藏其独立 TankSprite。交互范围为 96 × 48，中心约 (429.43, 511.43)，幼芽从左侧接近即可吸收；不得让幼芽先跳上台阶才能成长。动态吸收流来自实际交互事件。

## 一次生成的构图约束

以下是本次提交给图像生成的制作约束摘要（不是逐字工具日志）：以布局图为几何参考，重新绘制一张横版植物温室的完整近景；纯白表示空隙，远景不画入近景；左上厚重根壳形成幼芽低洞，右侧三阶由完整地基承托；苔藓、蕨类、附生植物、垂叶和近处大叶按生长位置连续构图；第一阶墙内安排清晰、足够大的发光黄绿色营养器官；深色清晰结构、植物绿、分层明暗；保留走面与可读角色空间，不添加角色、HUD、文字或孤立摆放的营养瓶。

生成工具：内置 image_gen。生成文件编号：exec-0014391d-1324-4e07-9fd8-a6c13fb2585f.png。输出于当前任务生成目录，随后保存为上述源文件与运行时副本。没有使用第三方游戏画面作为可发布素材；《空洞骑士》仅用于空间层次、地表覆盖及读图标准的研究。

## 历史稿与后续约束

chamber_master.png 为早期房体母稿；chamber_integrated.png 是资源过于细小的已否决尝试。独立 root_reservoirs 和 ecological_cover 系列仅留作历史草稿，不重新启用于培养室。其他区段尚未全部按此方法重制，不能把本房间的结果当成全关交付。

资源需要按房间用途差异化：营养可从墙内输养器官、树根裂隙或嵌入式生长腔出现；毒素需要有污染泄漏、腐化根腔或渗流来源。下一房间生成前先记录源点与幼芽恢复路线，不把成品小罐或毒盆后贴在地面。

画面验收与实际输入通行结果记录在 nursery_room_review.md；静态截图和自动输入都不等于三轮真人试玩。


### 白边修复

foreground_cutout.gdshader 使用连续白底覆盖率和去白混色，取代只在近白像素邻域去底的旧算法；后者遗漏了封闭的细叶灰白孔隙。foreground_cutout.tres 的 highlight_center_px=(1012,688)、highlight_radius_px=(48,58) 是该母稿中营养器官的内部高光保护区，仅影响合成，不改源 PNG。实际同镜头效果见 build/qa/white-edge-fix/after.webp。
