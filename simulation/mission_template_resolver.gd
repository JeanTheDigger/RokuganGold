class_name MissionTemplateResolver
## Structural wiring: QuestSeedSelector → TemplateSelector → template generator → AsciiMapData.
## Implements the dispatch logic implied by GDD s56.2 (selection pools) and
## s56.3–s56.15 (per-template generation). No game design — selection weights and
## generation rules are already locked in their respective systems; this function
## connects them.

# -- Default objectives -------------------------------------------------------
# ObjType.KILL_LEADER == 0 in every template (Cave, OccupiedVillage, Forest,
# Stockade, Hilltop, Ravine, Ruin). Passing [0] is the universal single-leader
# default. Callers may override with template-specific ObjType arrays.
const DEFAULT_OBJECTIVES: Array = [0]  # [ObjType.KILL_LEADER]


## Full pipeline convenience function.
## Selects the template for the province terrain, then generates and returns the map.
## province_history: Array[String] event tags (war_damage, famine, taint_corruption,
##   peasant_revolt, natural_decay) — controls Ruined Structure availability.
## objectives: template-specific ObjType int array; defaults to [KILL_LEADER] if empty.
## seed_str: deterministic seed string; typically province_id + "_" + season + "_" + seed_type.
static func select_and_generate(
		province: ProvinceData,
		province_history: Array,
		seed_dict: Dictionary,
		objectives: Array,
		seed_str: String) -> AsciiMapData:
	var template_id: String = TemplateSelector.select_template(
		province.terrain_type, province_history, seed_str)
	var strength: int = seed_dict.get("strength", 1)
	var objs: Array = objectives if not objectives.is_empty() else DEFAULT_OBJECTIVES
	return dispatch(template_id, strength, objs, seed_str)


## Generates a map for an already-chosen template ID.
## Use when the caller has already resolved the template (e.g. re-rolling after
## a failed strength check, or honouring a specific seed type restriction).
static func dispatch(
		template_id: String,
		strength: int,
		objectives: Array,
		seed_str: String) -> AsciiMapData:
	var objs: Array = objectives if not objectives.is_empty() else DEFAULT_OBJECTIVES
	match template_id:
		TemplateSelector.CAVE:
			return CaveMapGenerator.generate(seed_str, strength, objs)
		TemplateSelector.OCCUPIED_VILLAGE:
			return OccupiedVillageGenerator.generate(seed_str, strength, objs)
		TemplateSelector.FOREST_APPROACH_CAMP:
			return ForestApproachCampGenerator.generate(seed_str, strength, objs)
		TemplateSelector.MAKESHIFT_STOCKADE:
			return MakeshiftStockadeGenerator.generate(seed_str, strength, objs)
		TemplateSelector.HILLTOP_POSITION:
			return HilltopPositionGenerator.generate(seed_str, strength, objs)
		TemplateSelector.RAVINE_CAMP:
			return RavineCampGenerator.generate(seed_str, strength, objs)
		TemplateSelector.RUINED_STRUCTURE:
			return RuinedStructureGenerator.generate(seed_str, strength, objs)
		_:
			# Unknown template ID: fall back to Cave (underground is the safest
			# generic layout for any seed type that doesn't depend on open terrain).
			return CaveMapGenerator.generate(seed_str, strength, objs)
