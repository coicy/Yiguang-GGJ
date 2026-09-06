# 手工非 Tile 关卡搭建

`scenes/levels/handbuilt_level_template.tscn` 是手工关卡的起点。复制它后，直接在 Godot 的 2D 视图中摆放组件；JSON 白盒仅保留为玩法行为参考，不再参与新关卡布局。当前权威可玩关卡入口是 `scenes/levels/Level_main.tscn`，它包装具体实现关卡 `level_01.tscn`。

`level_01.tscn` 的基础场景先保持清晰的层级边界：根节点下分为 `Background`、`Geometry`、`Areas`、`Checkpoints`、`Actors`、`Foreground` 和 `Effects`；`Geometry` 再划分为 `Terrain` 与 `Mechanisms`。新机关、危险区和美术应按职责放入对应层，不要重新把节点平铺到关卡根节点。

## 搭建顺序

1. 在 `Terrain` 下拖入 `terrain_piece.tscn`、`hard_floor_piece.tscn` 或单独的美术场景。调整 `piece_size`，再选择共享的 `sprite_variants` 资源和 `variant_index`；单张专用贴图仍可填入 `art_texture`。
2. 在 `Mechanisms` 下拖入 `features/level/moveable_cube.tscn` 和 `trigger_button.tscn`，在方块的 `Activation` 分类配置方向和距离。也可使用 `moving_platform.tscn`、`door.tscn`：这两类组件以根节点为起点，使用 `destination_offset` 配置终点；随平台移动的挂环和装饰放到 `Body/Attachments`。
3. 在按钮的 `event_id` 与机关的 `activation_event` 填入相同事件名，例如 `lift_01`。关卡内的 `LevelEventBus` 自动完成接线；`HandbuiltLevel` 会为没有总线节点的手工关卡补建一个。
4. 在 `Areas` 下摆放 `thorn_damage.tscn`、毒雾 `hazard_area.tscn`、营养液、毒素、风区和其他伤害机关。每个组件的碰撞层与掩码已经按项目约定预设。
5. 移动 `SpawnPoint` 与 `CameraBounds`，按 F6 运行关卡。`HandbuiltLevel` 会自动连接危险区和检查点，并用最近激活的检查点复活玩家。

## 组件映射

| 原 JSON 类型 | 手工组件 |
| --- | --- |
| Ground | `terrain_piece.tscn` |
| HardFloor | `hard_floor_piece.tscn` |
| Damage / ThornDamage | `thorn_damage.tscn` |
| Start | `spawn_point.tscn` |
| Camera | `camera_bounds.tscn` |
| Door | `door.tscn` |
| Button | `trigger_button.tscn` |
| MoveableCube | `features/level/moveable_cube.tscn`；`moving_platform.tscn` 仍支持按终点偏移配置 |
| Checkpoint | `checkpoint.tscn` |
| GrowDrug / UnGrowDrug | `nutrition_tank.tscn` / `toxin_resource.tscn` |
| Frog | `toxin_zone.tscn` |
| Wind / Ring / DamageMachine | `wind_zone.tscn` / `vine_anchor.tscn` / `damage_machine.tscn` |

## 美术约定

- 组件根节点的原点是布局锚点；不要缩放物理根节点。
- `VisualRoot` / `Artwork` 可以偏移、缩放或替换为美术子场景；碰撞尺寸由组件的尺寸字段或 `CollisionPolygon2D` 管理。
- 当素材带有透明边缘时，在 `TerrainPiece` 的 `Collision` 分类设置四个 `collision_*_inset`，不要直接移动或缩放碰撞节点；矩形轮廓会根据这些内缩值自动同步。
- 矩形地形使用 `piece_size`。简单不规则地面使用 `TerrainPiece` 的多边形模式；只有需要多段碰撞、特殊机关或独立行为时，才创建专用 `StaticBody2D` 场景。
- TerrainPiece 的贴图只在根节点配置：单张素材填入 `art_texture`，需要复用多张精灵图时填入 `sprite_variants` 并选择 `variant_index`。`SpriteVariantSet` 优先于 `art_texture`；不要在 `Artwork` 或 `PolygonArtwork` 子节点手工填贴图。`SpriteVariantSet` 的每项保存贴图、偏移、缩放和是否适配组件尺寸。地形、危险区、按钮和平台共享该资源后，只需选择 `variant_index`。`variant_sprite_2d.tscn` 可作为现有资源区、风区等组件的直接子节点，复用同一套变体资源；其 `component_size` 用于需要拉伸适配的变体。
- `art_texture` 与精灵变体都为空时，组件显示白模占位图；多边形模式的白模按 `PolygonArtwork` 轮廓绘制，配置素材后占位图自动隐藏。荆棘使用 `thorn_damage.tscn`，它的 `Artwork` 与 `CollisionPolygon2D` 使用相同的素材变换；调整 `ThornDamage` 根节点的 `Scale` 会同步缩放显示和碰撞。

### 多边形地板

`terrain_piece.tscn` 与 `hard_floor_piece.tscn` 提供三套显示模式：`display_mode=SPRITE` 使用 `NinePatchRect` 平铺矩形地块，`display_mode=POLYGON` 使用纹理 `Polygon2D`，`display_mode=WHOLE_TEXTURE` 使用 `Sprite2D` 按原始素材整体显示；唯一的 `CollisionPolygon2D` 在矩形模式下生成矩形轮廓，在多边形模式下承载自定义轮廓。前两种模式默认使用 `SPRITE + RECTANGLE`；改变 `piece_size` 会直接扩大布局与碰撞。

- 选择 `POLYGON` 后，在 2D 视图编辑 `PolygonArtwork` 的顶点；`collision_follows_visual` 默认开启，加载实例和编辑有效视觉轮廓时都会同步到碰撞轮廓。
- 若视觉边缘不适合承重，关闭 `collision_follows_visual`，再单独编辑唯一的 `CollisionPolygon2D`。
- 地板根节点和碰撞节点均保持单位缩放。多边形必须有至少三个不自交顶点；无效轮廓会保留上一份有效碰撞并显示一次警告。
- 需要“素材整体与碰撞体一起缩放”时，选择 `display_mode=WHOLE_TEXTURE`，让 `piece_size` 先描述未缩放的本地碰撞范围，再直接调整 `TerrainPiece` 根节点的 `Scale`。该模式会保留根节点缩放，不执行普通地形的缩放烘焙；素材和 `StaticBody2D` 碰撞会继承同一个 Transform。浮空岛等不规则素材应同时使用 `collision_mode=POLYGON` 并编辑 `CollisionPolygon2D`。
- `one_way_collision` 仅用于多边形碰撞的平台版本。矩形碰撞时该开关不会生效，Inspector 会给出配置警告。普通地板默认允许扎根，硬质地板默认禁止。
- 自然和硬质地板的默认素材组位于 `assets/runtime/scenery/variants/`。设置 `sprite_variants` 后通过 `variant_index` 换肤；它只影响显示，不修改碰撞或扎根规则。

### 长地面与平铺贴图

长地面应分别处理轮廓、贴图和碰撞：延长 `piece_size` 或视觉多边形来定义地形范围，使用可无缝平铺的中段贴图填充范围，碰撞则只覆盖实际可站立表面。不要通过缩放 `Sprite2D` 或物理根节点来拉长地面；`stretch_art` 仅用于允许变形的一次性美术，不用于常规地形。

- `RECT_FROM_PIECE_SIZE` 是默认布局，用于直线、矩形地面。`display_mode=SPRITE` 时由 `NinePatchRect` 直接接收 `piece_size`，左右边缘保持不变，中间贴图平铺延长；连续平坦的可站立表面应尽量使用一个矩形碰撞体，避免装饰或相邻小碰撞体产生接缝。
- 斜坡、洞穴和简单不规则地面必须显式选择 `CUSTOM_POLYGON`，再在 2D 视图中编辑 `PolygonArtwork` 轮廓；使用可重复的土壤或岩石贴图填充内部，并用独立的草皮、岩层或悬崖边缘素材修饰轮廓。碰撞按本节的 `collision_follows_visual` 规则同步，或保留独立的碰撞多边形。
- 一个可延长的地面素材至少分为中段、左端帽和右端帽。中段必须在延长方向上无缝衔接；端帽保持原始尺寸，摆在地形两端。草、石头、藤蔓等装饰是独立节点，不参与地面碰撞。
- 矩形地块中段纹理通过 `NinePatchRect` 的 `AXIS_STRETCH_MODE_TILE` 重复；将 `stretch_art` 改为 `true` 才会切换为拉伸。多边形地块仍通过 `PolygonArtwork.texture_repeat` 重复。`art_offset`、`art_scale_multiplier` 和 `art_rotation_degrees` 同时作用于两种视觉节点；像素风素材使用整数位置、整数顶点和 Nearest 过滤，以避免边缘出现采样缝。
- 九宫格切分直接编辑 `TerrainVisual` 子节点的 `patch_margin_left/top/right/bottom`；在实例场景中先对 `TerrainPiece` 选择“Editable Children”，再在 2D 视图选中 `TerrainVisual`，拖动边界手柄即可观察和调整切分。脚本不会覆盖这些边距，只会把 `piece_size` 同步为 NinePatchRect 的显示尺寸。
- 多个 `TerrainPiece` 首尾拼接时，在每个实例上设置 `polygon_repeat_offset`，使右侧实例的纹理相位承接左侧实例。例如左侧宽度为 `480` 时，右侧实例从 `Vector2(-480, 0)` 开始。该偏移属于 TerrainPiece 实例，不能写回共享的 `SpriteVariantSet` 或 `LevelSpriteVariant` 资源。
- 当关卡需要大量规则网格地形、自动转角或自动边缘连接时，改用 `TileMapLayer` 和 TileSet Terrain Set。`TerrainPiece` 继续用于手工不规则地形、端帽和特殊地表。

## 接线与复用

按钮与机关通过关卡内的 `LevelEventBus` 交互。总线场景为 `features/level/level_event_bus.tscn`，放在关卡根节点下；作用域为该关卡的所有后代，嵌套关卡的总线拥有独立作用域。`HandbuiltLevel` 会在没有显式总线时补建一个，组件单独 F6 运行也不依赖总线存在。

- `TriggerButton.event_id`：首次触发时发布的事件名，例如 `lift_01`。
- `MoveableCube`、`MovingPlatform`（含手工门）、`MechanismMotion` 的 `activation_event`：要订阅的事件名；同名事件到来时执行原有 `activate()`。`WhiteboxDoor` 继承这一接收接口，并执行自己的开门配置。
- 一个按钮可通过同一个事件激活多个机关；多个按钮也可发送同名事件。复制机关组合后，如需独立控制，应为新组合分配新的事件名。空事件名不触发机关。
- 按钮不再提供 `targets` 直连配置；旧手工模板已迁移。`MechanismMotion.targets` 仍用于组合机关内部指定运动方块，不承担按钮通信。
- 总线只转发当次事件，不保存已触发历史、不重放、不排队重试。按钮和机关各自维持原有单次锁存；正在忙碌的机关可拒绝激活。同步发布相同事件的反馈循环会被总线截断。
- 动态加入关卡的组件自动接线，移出或销毁时解除连接；重开关卡重新创建总线和组件，旧关卡事件不会影响新关卡。

脚本可通过关卡拥有的总线调用 `publish(&"lift_01")`。新增发送组件声明 `level_event_requested(event_id: StringName)` 信号，新增接收组件实现 `receive_level_event(event_id: StringName)`；业务状态仍由组件自己管理。

`tests/scene/test_level_event_bus.gd` 验证真实接触、一对多事件、关卡隔离、动态节点清理、重建和正式关卡接线。

### MoveableCube 的激活方向

将 `features/level/moveable_cube.tscn` 拖入关卡，选择根节点，在 Inspector 配置：

| 属性 | 用途 |
| --- | --- |
| `cube_size` | 方块的显示占位与实体碰撞尺寸 |
| `movement_direction` | 局部移动方向；右 `(1, 0)`、左 `(-1, 0)`、上 `(0, -1)`、下 `(0, 1)`，也支持斜向 |
| `move_distance` | 移动距离，默认 128 个局部像素；方向向量会自动归一化 |
| `motion_speed` | 沿用方块的运动速度参数，实际过程使用平滑起停曲线 |
| `startup_shake_duration` / `startup_shake_distance` | 启动前抖动的时长和幅度，设时长为 0 可关闭 |

例如向上移动 96 像素：设置 `movement_direction = Vector2(0, -1)`、`move_distance = 96`。编辑器内的蓝色箭头和终点轮廓随参数更新；旋转方块或它的父节点时，局部移动方向也随之旋转。物理根节点保持单位缩放。

将按钮的 `event_id` 和 Cube 的 `activation_event` 配成同名事件即可，不必额外放置 `MechanismMotion`。脚本也可调用 `cube.activate()`：成功启动返回 `true`，并保持单次激活状态；重复调用、正在执行其他运动、方向为零或距离为零时返回 `false`。方块自身在拒绝启动时不会消耗激活机会。到达终点后停留，`reset_platform()` 恢复初始位置、尺寸及未激活状态；复用原按钮再次触发时还需调用它的 `reset_button()`，R 重开则重新载入场景。

`move_to_rect()`、`move_top_left_to()` 和 `rotate_clockwise_about()` 继续供已有机关调用。继承方块的 `WhiteboxDoor.activate()` 执行门自己的 `open_offset` / 旋转配置。

`tests/scene/test_moveable_cube_activation.gd` 验证方向、斜向距离、旋转父节点、按钮事件接线、单次激活与复位；既有实体测试继续验证玩家站立与平台随动。

每个组件场景应可单独 F6 启动。完整关卡至少验证：出生与复活、普通/不可扎根地面、危险区、按钮控制的平台、平台随动挂环、摄像机边界，以及 R 重开。

## 正式关卡 Level_main

`scenes/levels/Level_main.tscn` 是正式关卡入口，启动壳和场景测试均从这里进入；它实例化当前从基础层级重新搭建的 `level_01.tscn`。初始白盒只保留一块 `StartFloor`、玩家出生点和摄像机边界，地图边界为 `Rect2(-256, -128, 1344, 768)`，运行时不读取 JSON。后续机关、危险区、检查点和美术应逐层加入，不应直接恢复旧关卡的整套内容。

- 场景素材来自 `assets/runtime/scenery`，只使用等比缩放；`stretch_art` 保持关闭。
- 非地形装饰使用 `features/level/handbuilt/decorative_scenery.tscn`。组件固定包含单张渲染用的 `Artwork: Sprite2D` 和运行时批量平铺用的 `TiledArtwork: MultiMeshInstance2D`，不绑定具体素材；在任意关卡实例的 Inspector 中修改 `sprite_variants` 和 `variant_index` 即可立即换图。`layout_mode=SINGLE` 显示单张素材；改为 `GRID` 后，通过 `tile_count` 设置列数和行数，组件会按纹理缩放后的实际宽高自动排列，`tile_spacing` 追加横纵间距，也允许负值让相邻透明边缘重叠。`tile_spacing` 使用组件局部单位，最终显示间距还会乘以根节点 Transform Scale。GRID 的编辑器预览由 `DecorativeScenery` 根节点直接自绘，并只在配置签名变化时自动刷新；运行时自动切换为 MultiMesh 批量渲染。组件实例本身的 Position、Rotation、Scale、Z Index 和 Modulate 负责整组摆放，`flip_h` / `flip_v` 负责翻转；无需创建 Placement 资源或专用素材场景。组件不生成碰撞、不承担地形规则。
- 装饰组件适用于草团、花、针草、高草、根、藤蔓、爬墙藤、草皮、实验室道具、垂坠和遮盖素材。荆棘由 Damage 组件负责，不放入装饰组件。
- 草皮精灵集为 `assets/runtime/scenery/variants/grass_turf_variants.tres`，包含 `_0022_草皮.png`、`_0023_草皮2.png` 和 `_0024_草皮.png` 三个变体。
- 长地面遵循“中段平铺、端帽定尺、碰撞覆盖连续表面”的规则；多个 `TerrainPiece` 拼接时，用各实例的 `polygon_repeat_offset` 保持纹理连续，透明装饰不参与碰撞。
- 摄像机由 `Actors/Player/Camera2D` 承载，使用 `zoom = Vector2(4, 4)`、平滑边界和位置平滑；边界由根节点的 `CameraBounds` 统一配置。
- 当前 `StartFloor` 使用 `art_scale_multiplier = 0.4` 做首轮像素密度校准：`_0036_苔藓地1.png` 的原始高度约为 136px，缩放后约 54 世界单位，与成熟角色的视觉高度处于同一量级。
- 根节点下的 `LevelEventBus` 负责本关卡按钮与机关通信。出生区域的 `LiftCube` 及其 `LiftButton` 已按用户要求移除；新增机关仍可通过匹配事件名接线。
