class_name MissionBuilder
## s56.9 Objective Slot assignment --- LOCKED.
## Wires QuestSeedSelector output into the full ASCII map mission pipeline:
## seed_dict → objectives → map generation → roster composition → unit placement.
## Returns a complete mission package ready for the quest display layer.

# Objectives by seed type (s56.10) -----------------------------------------------
# Maps seed_type int → ObjType int array passed to the template generator.
# ObjType 0 == KILL_LEADER is universal across all non-urban templates.
# SEED_URBAN_CRIMINAL_NETWORK uses UrbanHideoutMapData.ObjType numbering (s56.10.15):
#   [2] = KILL_CAPTURE_LEADER, [4] = RECOVER_EVIDENCE.
const _OBJECTIVES_BY_SEED: Dictionary = {
	RosterCompositionSystem.SEED_MAHO_CULT:              [0, 1],    # KILL_LEADER + RECOVER_GOODS (s56.10.8)
	RosterCompositionSystem.SEED_PEASANT_REVOLT:         [0],       # KILL_LEADER; DRIVE_OUT excluded per s56.10.4e
	RosterCompositionSystem.SEED_RONIN_BANDIT:           [0],       # KILL_LEADER
	RosterCompositionSystem.SEED_TAINT_MANIFESTATION:    [0],       # KILL_LEADER (focal point guardian, s56.10.10)
	RosterCompositionSystem.SEED_NEZUMI_INFESTATION:     [0, 1, 2], # chieftain + goods + burn nest (s56.10.6f)
	RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK: [2, 4],    # KILL_CAPTURE_LEADER + RECOVER_EVIDENCE (s56.10.15)
	RosterCompositionSystem.SEED_WALL_SORTIE:            [0],       # KILL_LEADER
	QuestSeedSelector.SEED_ONI_MANIFESTATION:            [0],       # KILL_LEADER (oni boss; roster_ready=false in practice)
	QuestSeedSelector.SEED_ROAD_ENCOUNTER:               [0],       # road encounters use RONIN_BANDIT seed_type in practice
}


## Assembles a complete mission package from a QuestSeedSelector seed_dict.
## province_history: Array[String] event tags (war_damage, famine, taint_corruption,
##   peasant_revolt, natural_decay) — controls RuinedStructure availability.
## seed_str: deterministic seed string (province_id + "_" + season + "_" + seed_type).
##
## Return dict keys:
##   "map"             → AsciiMapData subclass instance
##   "placements"      → Array of placement dicts (standard)
##                     | {"friendly": Array, "enemy": Array} (SEED_WALL_SORTIE)
##   "objective_slots" → Array from map.objective_slots
##   "seed_dict"       → input seed_dict unchanged
##   "roster"          → Dictionary from RosterCompositionSystem.compose_roster()
##
## Returns {} when roster_ready is false (encounter design blocked on future GDD sections).
static func assemble(
		province: ProvinceData,
		province_history: Array,
		seed_dict: Dictionary,
		seed_str: String) -> Dictionary:
	if not seed_dict.get("roster_ready", true):
		return {}

	var seed_type: int        = seed_dict.get("seed_type", -1)
	var strength:  int        = seed_dict.get("strength", 1)
	var options:   Dictionary = seed_dict.get("options", {})
	var objectives: Array     = _OBJECTIVES_BY_SEED.get(seed_type, [0])

	var pop_seed: int = hash(seed_str + "_pop")

	var roster: Dictionary = RosterCompositionSystem.compose_roster(
		seed_type, strength, options, pop_seed)

	var map: AsciiMapData
	var placements  # Array (standard) or {"friendly":Array,"enemy":Array} (sortie)

	if seed_type == RosterCompositionSystem.SEED_URBAN_CRIMINAL_NETWORK:
		# UrbanHideout is absent from every TemplateSelector terrain pool — call directly.
		map = UrbanHideoutGenerator.generate(seed_str, strength, objectives)
		placements = MissionPopulator.populate(map, roster, pop_seed)
	elif seed_type == RosterCompositionSystem.SEED_WALL_SORTIE:
		map = MissionTemplateResolver.select_and_generate(
			province, province_history, seed_dict, objectives, seed_str)
		placements = MissionPopulator.populate_sortie(map, roster, pop_seed)
	else:
		map = MissionTemplateResolver.select_and_generate(
			province, province_history, seed_dict, objectives, seed_str)
		placements = MissionPopulator.populate(map, roster, pop_seed)

	return {
		"map":             map,
		"placements":      placements,
		"objective_slots": map.objective_slots,
		"seed_dict":       seed_dict,
		"roster":          roster,
	}
