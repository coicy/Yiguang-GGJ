extends SceneTree

const VARIANT_SETS := {
	"natural": ["res://assets/runtime/scenery/variants/natural_floor_variants.tres", 2],
	"hard": ["res://assets/runtime/scenery/variants/hard_floor_variants.tres", 3],
	"platform": ["res://assets/runtime/scenery/variants/platform_variants.tres", 4],
	"foliage": ["res://assets/runtime/scenery/variants/foliage_variants.tres", 3],
	"vine_root": ["res://assets/runtime/scenery/variants/vine_root_variants.tres", 3],
	"laboratory": ["res://assets/runtime/scenery/variants/laboratory_prop_variants.tres", 2],
	"thorn_hazard": ["res://assets/runtime/scenery/variants/thorn_hazard_variants.tres", 3],
	"small_vine": ["res://assets/runtime/scenery/variants/small_vine_variants.tres", 3],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for group_name: String in VARIANT_SETS:
		var definition: Array = VARIANT_SETS[group_name]
		var variant_set := load(definition[0]) as SpriteVariantSet
		assert(variant_set != null, "%s variant set did not load." % group_name)
		assert(variant_set.variants.size() == definition[1], "%s has an unexpected variant count." % group_name)
		for variant: LevelSpriteVariant in variant_set.variants:
			assert(variant.texture != null, "%s contains a missing texture." % group_name)
	quit()
