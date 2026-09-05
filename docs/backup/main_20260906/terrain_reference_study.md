# 同类横版游戏地形参考研究

研究日期：2026-09-06。服务于《失控温室》的独立地形制作流程，范围是层次、表面、截面、支撑、过渡、战斗读图和探索路线。只提炼结构原则，不复制任何游戏的纹样、建筑造型、配色组合或具体构图。

本次浏览开发者官网、游戏官网和官方 Steam 商店，并实际查看下列官方页面中的截图。文中的“观察”描述图片可见内容，“应用建议”是本项目的设计推论。静态截图不能证明原作的碰撞实现、视差参数或整段路线可达性，也不能代替本项目试玩。

## 1. 官方来源与观察样本

| 编号 | 官方来源 | 本次核查的图片与用途 |
|---|---|---|
| HK1 | [Team Cherry：Hollow Knight: Then and Now](https://www.teamcherry.com.au/blog/hollow-knight-then-and-now) | 文中最后一组 Green Path 新旧对比；[新版本截图](https://images.squarespace-cdn.com/content/v1/606d4deb4db8c15ea53b3624/1618899930590-LJTD63I9Q61WISRJB522/ee09c92b4fe43f04a3f7697dd103cb2a_original.jpg)，观察悬台、地表与前后景 |
| HK2 | [Team Cherry：The Green Path – A Hollow Knight Tour](https://www.teamcherry.com.au/blog/the-green-path-a-hollow-knight-tour) | [Fungus_03.jpg 桥面截图](https://images.squarespace-cdn.com/content/v1/606d4deb4db8c15ea53b3624/1618900771877-ZNK32GKBU2AR3OGN1EUO/Fungus_03.jpg?format=1500w)，观察桥面、立柱与水面分层。该文为开发期记录，不用于断言最终版地名关系 |
| OR1 | [Ori 官方 Media](https://www.orithegame.com/media/) | [E3 2019 01](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_01-1024x576.jpg)：洞穴蛛网与横向枝干场地 |
| OR2 | [Ori 官方 Media](https://www.orithegame.com/media/) | [E3 2019 03](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_03-1024x576.jpg)：熔岩环境中石质平台、断拱与植物覆盖；[E3 2019 04](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_04-1024x576.jpg)：蓝色森林中的斜枝与右上方落点 |
| EL1 | [ENDER LILIES 官方 Steam 商店](https://store.steampowered.com/app/1369630/ENDER_LILIES_Quietus_of_the_Knights/) | [Screenshot #0：Knight Captain Julius](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_1c2bf22139c82d0c46ccee075e1e71e08b88ab44.1920x1080.jpg)、[Screenshot #6：Gerrod](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_59f1eb49ddb7d2b27d54eab4ef752b5f0c3dbc10.1920x1080.jpg)，观察连续地面与攻击读图 |
| EL2 | [ENDER LILIES 官方 Steam 商店](https://store.steampowered.com/app/1369630/ENDER_LILIES_Quietus_of_the_Knights/) | [Screenshot #5：错层石台与树丛](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_9b18286c32d4851f07ef2c17b4774962147b87cb.1920x1080.jpg)、[Screenshot #7：Dark Witch Eleine](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_298c04f318b846a6d68748d4332870ab1ae1395c.1920x1080.jpg)，比较探索空间与弹幕战斗空间 |

Steam 截图编号按此次商店返回的从 0 开始编号记录，文件标识与直接链接用于避免以后排序变化造成歧义。参考图片只在线查看，不纳入项目可发布素材。

## 2. Hollow Knight：用明确轮廓建立可行走层

### 观察

Green Path 对比图里，角色脚下小平台具有较亮、连续的苔藓顶缘和较暗的厚实底部；画面边角的垂挂植物更暗，远处叶丛较淡，角色附近留有明度差。官方文章也把改版后的变化描述为增加色彩、细节和深度。[HK1](https://www.teamcherry.com.au/blog/hollow-knight-then-and-now)

桥面图把平直上沿、栏饰下缘和竖向桥柱分开画出。水面在下方连续通过，后方大叶和岩块不截断玩家脚下的细桥面。天然植被与人工桥梁同时出现，靠结构关系区分用途。[HK2](https://www.teamcherry.com.au/blog/the-green-path-a-hollow-knight-tour)

### 对温室的应用建议

- 苔藓只承担表皮和边缘节奏；土、石、根须承担截面，不能把一张厚苔藓块同时当成地表、墙体和悬台。
- 修枝车间把踏板与托架分开装配，柱脚落到基础或延伸到画面外的合理结构；树冠平台则连到枝叉或主干。
- 前景高草集中在画面边缘和脚下读图区以外。平台顶缘不能被草尖遮成虚假落点。
- 不直接照搬原作的漂浮平台逻辑；温室各段已有培养设施、检修结构和枝干，优先让它们解释承重。

## 3. Ori and the Will of the Wisps：让材料与轮廓描述路线

### 观察

官方 E3 2019 01 图在深色洞壁和蛛网中保留中部较亮的通道，角色站在连接两侧的枝干上，枝干下方仍可见厚度与杂枝。高密度细节主要在外围，中央角色轮廓清楚。[OR1](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_01-1024x576.jpg)

03 图用苔色表面、石质断面和破损拱架区分同一场所的覆盖层与旧结构；04 图中斜枝指向右上方平台，枝条走势与明亮上沿共同表达前进方向。这些图展示的是可见构图，不能据此认定所有亮边都可碰撞。[OR2-03](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_03-1024x576.jpg)、[OR2-04](https://www.orithegame.com/wp-content/uploads/2021/08/screenshot_wotw_E32019_04-1024x576.jpg)

### 对温室的应用建议

- 过渡段通过“旧设施被生长改变”连接材料：水泥裂缝生根、根系托起断钢板、树枝跨接旧检修架。
- 树冠通路先安排主干、枝叉、落点和回路，再添加叶簇。藤蔓环与实际落点要在探索镜头中同时可见。
- 用重复的表面语言教会落脚点，用不同支撑关系增加丰富度；避免每个平台都换一个无法辨认的新纹理。
- 光和颜色只加强已经成立的轮廓。绿色玩家、绿色地表与背景不能挤在同一明度；危险孢子和不可弹反预警需要独立识别。

## 4. ENDER LILIES：战斗场和探索场采用不同密度

### 观察

Julius 与 Gerrod 官方截图的主要战斗地面近似连续水平带。砖石、柱子、旗帜和窗格补充场景信息，攻击与角色活动区仍有较大连续空间；Julius 的背景灰暗，Gerrod 上方主要是低细节天空。[EL1-Julius](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_1c2bf22139c82d0c46ccee075e1e71e08b88ab44.1920x1080.jpg)、[EL1-Gerrod](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_59f1eb49ddb7d2b27d54eab4ef752b5f0c3dbc10.1920x1080.jpg)

错层石台图中，上、中、下平台有清楚的厚边框，背后的树丛和石柱更淡；Eleine 图则保留宽阔下方地面，亮弹体分布在大面积暗色背景前。两者可见的空间组织分别强调多高度落点和战斗移动余地。[EL2-探索](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_9b18286c32d4851f07ef2c17b4774962147b87cb.1920x1080.jpg)、[EL2-战斗](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1369630/ss_298c04f318b846a6d68748d4332870ab1ae1395c.1920x1080.jpg)

### 对温室的应用建议

- 隔离庭院和核心采用连续主走面，变化放在台基、侧墙、远景和场边设施上。不能为增加材料种类挤占躲避距离。
- 普通遭遇中的矮台必须服务绕背、接近孢子囊或跳跃反击；避免只为装饰新增碰撞台阶。
- 孢子廊需要从玩家到敌人的清楚弹道带，装饰孢子不能与真实弹体使用同等亮度、尺寸和运动提示。
- 树冠才承担明显错层与回路；幼芽支路必须能看懂入口和恢复路线，不能因为截图好看而形成无法返回的落差。

## 5. 转成项目部件职责与七区装配

以下是本项目建议，不是对参考游戏内部制作方式的断言。材料最终分配和尺寸由 [正式地形流程](terrain_production.md) 的结构设计、资产审计与关卡验证落实。

| 层级 / 职责 | 项目中应该表达什么 | 现有资源与补齐方向 |
|---|---|---|
| 远景 | 温室玻璃架、远处植物与深度 | 复用 greenhouse_background；降低主活动区后方的细节竞争，不再生成另一张同职责整景图 |
| 中景结构 | 设施用途、墙、管线和主干 | 复用培养罐、爬墙藤、树根；只有缺少明确连接职责时才补结构件 |
| 可行走表面 | 精确、连续、可预期的脚底边缘 | 已有苔藓、水泥板、石板、锈蚀钢板与树枝平台；先检查其尺寸和顶缘，不因换区重复生成同类面板 |
| 截面与支撑 | 土石厚度、板底、断口、承重来源 | 复用苔藓水泥块与树根；优先审计是否缺独立土层端头、钢架斜撑、枝干接口 |
| 过渡 | 两种材料为什么在此相接 | 门槛、排水槽边、开裂地砖与根系跨接；作为明确交界部件，不用整张背景掩盖拼缝 |
| 前景细节 | 局部生长与距离感 | 复用草皮、草团、红花、细藤变体；不覆盖落脚顶缘、弹体和重砸落点 |

七区装配重点：培养室用人工基础与局部培养土建立起点；苔藓步道显示植物抬起旧石板；孢子廊沿排水和潮湿结构变化；车间显示踏板、立柱与托架；树冠用主干、枝叉解释高差；庭院用厚基座承接战斗净空；核心通过汇入基座的根与管线收束材料关系。区域差异来自用途、轮廓和结构，不以同一地板的换色代替。

当前 assets/runtime/scenery 已包含水泥板、石板、苔藓水泥块、树根、树枝、钢板、草皮及九组 variants 资源。是否新增由资产审计逐项判断；本研究没有提出重复生成现有图，也没有生成或导入新的参考素材。旧素材及其衍生图的许可状态仍按 [credits](credits.md) 记录。

## 6. 样板与验收要求

1. 在正式培养室与一个战斗区做样板；先检查表面、截面、支撑和交界，再增加装饰密度。
2. 同时以探索 2.5、普通战斗 2.1、精英 1.65 的实际镜头检查：脚底、平台边缘、敌人前摇、弹体和落点是否清晰。上述倍率来自本项目当前设计，不是参考作品参数。
3. 每个交界至少看一张近处截图和一张正常镜头截图；确认没有厚板竖向拉伸、透明接缝、假落点和无来源悬台。
4. 两种战斗形态检查全部主路；幼芽检查探索支路、恢复资源与回程。装饰不能改变已验收的战斗宽度和难度。
5. 按 [温室验证记录](greenhouse_validation.md) 记录真实证据。静态截图只能证明其可见范围；持续移动、正常输入通关和首次体验时间仍需实际试玩。

本研究交付的是来源、观察和装配原则；地形最终完成状态以独立地形流程的 T0–T6 记录为准。
