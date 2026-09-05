# 文档索引变更（WIP）

- `docs/warden_design.md`：精英怪「守圃者」的设计参考、距离决策、招式时序、全身发力、玩家反制与正式关卡验证。

- `docs/beetle_design.md`：第一个小怪「污染甲虫」的招式、距离决策、全身发力与受击规则，以及正式关卡验证入口。

- `docs/handbuilt_level_building.md`：手工非 Tile 关卡的组件目录、搭建流程、组件接线方式与验证清单；手工关卡流程稳定后评估是否提升至 `AGENT.md`。

- `docs/whitebox_acceptance_criteria.md`：本次 JSON 白盒落地的验收标准、操作步骤与证据要求；实施后逐项记录结果。

- `docs/whitebox_entity_rules.md`：记录白盒按钮与可移动方块的逐项行为规则；等待逐项确认完成后提升到 `AGENT.md` 权威索引。

- `docs/superpowers/specs/2026-09-05-whitebox-playable-vertical-slice-design.md`：一次性交付角色、三形态核心能力、资源转换和可通关白模关卡的已确认设计规格；实现验收完成后保留为过程记录。
- `docs/superpowers/plans/2026-09-05-whitebox-playable-vertical-slice.md`：上述白模垂直切片的测试驱动实施计划，覆盖形态、资源、能力、交互、关卡和实际操作验收。
- `docs/superpowers/plans/2026-09-04-whitebox-core-gameplay.md`：白模核心功能实现计划，完成执行后保留为过程记录，不列入权威文档索引。
- `docs/scene_design_and_ownership.md`：白模场景层级、模块所有权、通信契约和并行实施分工；待首个白模关卡验收后决定是否提升为权威索引。
- `docs/superpowers/plans/2026-09-04-whitebox-integration-scenes.md`：本分支白模交互实体、启动壳与关卡组装的测试优先实施计划。
# 待确认文档

- `docs/scenery_asset_mapping_template.md`：场景 PNG 素材到 JSON 关卡 Tile / Entity 的待填写映射表。
- `docs/handbuilt_level_building.md`：补充普通与硬质地板的 Polygon2D / CollisionPolygon2D 编辑、素材变体与实例覆盖说明。

- `assets/runtime/scenery/variants/`：根据场景素材表建立可复用的 `SpriteVariantSet` 素材组；待关卡实际采用后评估是否提升至权威索引。

- `docs/audio_design.md`：声音身份、素材来源、事件覆盖与客观验证和试听边界。
