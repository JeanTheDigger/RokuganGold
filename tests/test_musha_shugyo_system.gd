extends GutTest
## Tests for MushaShugyo system per GDD s57.48.
## Covers: probability calculation, gempukku evaluation, begin/end pilgrimage,
## lord death handling, SEEK_EXPERIENCE decomposition, destination weighting,
## objectives map helpers, DayOrchestrator wiring.


var _char: L5RCharacterData
var _dice: DiceEngine
var _ctx: NPCDataStructures.ContextSnapshot


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.character_name = "Test Samurai"
	_char.clan = "Crane"
	_char.family = "Kakita"
	_char.school = "Kakita Bushi"
	_char.school_type = Enums.SchoolType.BUSHI
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	_char.shourido_virtue = Enums.ShouridoVirtue.NONE
	_char.honor = 5.0
	_char.glory = 1.0
	_char.status = 1.0
	_char.lord_id = 100
	_char.skills = {"Iaijutsu": 3, "Kenjutsu": 2}
	_char.emphases = {}
	_char.reflexes = 3
	_char.awareness = 3
	_char.stamina = 2
	_char.willpower = 2
	_char.agility = 3
	_char.intelligence = 2
	_char.strength = 2
	_char.perception = 2
	_char.void_ring = 2
	_char.wounds_taken = 0

	_dice = DiceEngine.new()
	_dice.set_seed(42)

	_ctx = NPCDataStructures.ContextSnapshot.new()
	_ctx.school_type = Enums.SchoolType.BUSHI
	_ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	_ctx.province_statuses = []
	_ctx.famine_crisis_province_ids = []
	_ctx.zone_flags = {}


func _make_ctx(flag: int, school: Enums.SchoolType = Enums.SchoolType.BUSHI) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school_type = school
	ctx.context_flag = flag
	ctx.province_statuses = []
	ctx.famine_crisis_province_ids = []
	ctx.zone_flags = {}
	ctx.active_insurgency_id = -1
	return ctx


# =============================================================================
# Probability Calculation
# =============================================================================

func test_base_chance_is_ten_percent() -> void:
	_char.clan = "Mantis"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.10, 0.001)


func test_dragon_clan_has_highest_modifier() -> void:
	_char.clan = "Dragon"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.20, 0.001)


func test_crab_clan_has_lowest_modifier() -> void:
	_char.clan = "Crab"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.05, 0.001)


func test_crane_modifier() -> void:
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.15, 0.001)


func test_phoenix_modifier() -> void:
	_char.clan = "Phoenix"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.15, 0.001)


func test_lion_modifier() -> void:
	_char.clan = "Lion"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.07, 0.001)


func test_yu_adds_three_percent() -> void:
	_char.clan = "Mantis"
	_char.bushido_virtue = Enums.BushidoVirtue.YU
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.13, 0.001)


func test_chugi_subtracts_three_percent() -> void:
	_char.clan = "Mantis"
	_char.bushido_virtue = Enums.BushidoVirtue.CHUGI
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.07, 0.001)


func test_dosatsu_adds_three_percent() -> void:
	_char.clan = "Mantis"
	_char.bushido_virtue = Enums.BushidoVirtue.NONE
	_char.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.13, 0.001)


func test_seigyo_subtracts_two_percent() -> void:
	_char.clan = "Mantis"
	_char.bushido_virtue = Enums.BushidoVirtue.NONE
	_char.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.08, 0.001)


func test_combined_virtue_modifiers() -> void:
	_char.clan = "Dragon"
	_char.bushido_virtue = Enums.BushidoVirtue.YU
	_char.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.26, 0.001)


func test_probability_never_below_zero() -> void:
	_char.clan = "Crab"
	_char.bushido_virtue = Enums.BushidoVirtue.CHUGI
	_char.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_true(prob >= 0.0, "Probability should never go negative")


func test_probability_never_above_one() -> void:
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_true(prob <= 1.0, "Probability should never exceed 1.0")


func test_unknown_clan_uses_zero_modifier() -> void:
	_char.clan = "Unknown"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.10, 0.001)


func test_imperial_modifier() -> void:
	_char.clan = "Imperial"
	_char.bushido_virtue = Enums.BushidoVirtue.MEIYO
	var prob: float = MushaShugyo.compute_probability(_char)
	assert_almost_eq(prob, 0.07, 0.001)


# =============================================================================
# Begin Pilgrimage
# =============================================================================

func test_begin_pilgrimage_sets_flag() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_true(_char.musha_shugyo)


func test_begin_pilgrimage_sets_end_day() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_eq(_char.musha_shugyo_end_ic_day, 460)


func test_begin_pilgrimage_stores_original_lord() -> void:
	_char.lord_id = 42
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_eq(_char.original_lord_id, 42)


func test_begin_pilgrimage_clears_lord_id() -> void:
	_char.lord_id = 42
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_eq(_char.lord_id, -1)


func test_begin_pilgrimage_sets_seek_experience_objective() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_eq(_char.current_objective, "SEEK_EXPERIENCE")


func test_pilgrimage_duration_is_360_days() -> void:
	assert_eq(MushaShugyo.PILGRIMAGE_DURATION_DAYS, 360)


# =============================================================================
# Is On Pilgrimage
# =============================================================================

func test_is_on_pilgrimage_false_by_default() -> void:
	assert_false(MushaShugyo.is_on_pilgrimage(_char))


func test_is_on_pilgrimage_true_after_begin() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_true(MushaShugyo.is_on_pilgrimage(_char))


# =============================================================================
# Should End Pilgrimage
# =============================================================================

func test_should_end_false_when_not_on_pilgrimage() -> void:
	assert_false(MushaShugyo.should_end_pilgrimage(_char, 500))


func test_should_end_false_before_end_day() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_false(MushaShugyo.should_end_pilgrimage(_char, 459))


func test_should_end_true_on_end_day() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_true(MushaShugyo.should_end_pilgrimage(_char, 460))


func test_should_end_true_after_end_day() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	assert_true(MushaShugyo.should_end_pilgrimage(_char, 500))


# =============================================================================
# End Pilgrimage
# =============================================================================

func test_end_pilgrimage_clears_flag() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	MushaShugyo.end_pilgrimage(_char)
	assert_false(_char.musha_shugyo)


func test_end_pilgrimage_resets_end_day() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	MushaShugyo.end_pilgrimage(_char)
	assert_eq(_char.musha_shugyo_end_ic_day, -1)


func test_end_pilgrimage_restores_lord_id() -> void:
	_char.lord_id = 42
	MushaShugyo.begin_pilgrimage(_char, 100)
	MushaShugyo.end_pilgrimage(_char)
	assert_eq(_char.lord_id, 42)


func test_end_pilgrimage_clears_original_lord_id() -> void:
	_char.lord_id = 42
	MushaShugyo.begin_pilgrimage(_char, 100)
	MushaShugyo.end_pilgrimage(_char)
	assert_eq(_char.original_lord_id, -1)


func test_end_pilgrimage_clears_objective() -> void:
	MushaShugyo.begin_pilgrimage(_char, 100)
	MushaShugyo.end_pilgrimage(_char)
	assert_eq(_char.current_objective, "")


func test_end_pilgrimage_returns_result_dict() -> void:
	_char.lord_id = 42
	MushaShugyo.begin_pilgrimage(_char, 100)
	var result: Dictionary = MushaShugyo.end_pilgrimage(_char)
	assert_eq(result["character_id"], 1)
	assert_eq(result["original_lord_id"], 42)
	assert_true(result["lord_restored"])


# =============================================================================
# Lord Death Detection
# =============================================================================

func test_lord_dead_when_id_negative() -> void:
	assert_true(MushaShugyo.is_lord_dead_or_missing(-1, {}))


func test_lord_dead_when_not_in_dict() -> void:
	assert_true(MushaShugyo.is_lord_dead_or_missing(42, {}))


func test_lord_alive_when_present_and_healthy() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 42
	lord.wounds_taken = 0
	assert_false(MushaShugyo.is_lord_dead_or_missing(42, {42: lord}))


func test_lord_dead_when_dead_in_dict() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 42
	lord.stamina = 2
	lord.willpower = 2
	lord.wounds_taken = 999
	assert_true(MushaShugyo.is_lord_dead_or_missing(42, {42: lord}))


# =============================================================================
# Objectives Map Helpers
# =============================================================================

func test_get_seek_experience_objective() -> void:
	var obj: Dictionary = MushaShugyo.get_seek_experience_objective()
	assert_eq(obj["need_type"], "SEEK_EXPERIENCE")
	assert_eq(obj["priority"], 2)


func test_populate_objectives_map_creates_entry() -> void:
	var omap: Dictionary = {}
	MushaShugyo.populate_objectives_map(1, omap)
	assert_true(omap.has(1))
	assert_eq(omap[1]["standing"]["need_type"], "SEEK_EXPERIENCE")


func test_populate_objectives_map_clears_primary() -> void:
	var omap: Dictionary = {1: {"primary": {"need_type": "CONQUER_PROVINCE"}, "standing": {"need_type": "EXPAND_TERRITORY"}}}
	MushaShugyo.populate_objectives_map(1, omap)
	assert_false(omap[1].has("primary"))
	assert_eq(omap[1]["standing"]["need_type"], "SEEK_EXPERIENCE")


# =============================================================================
# SEEK_EXPERIENCE Identity
# =============================================================================

func test_is_seek_experience_true() -> void:
	assert_true(MushaShugyo.is_seek_experience("SEEK_EXPERIENCE"))


func test_is_seek_experience_false_for_other() -> void:
	assert_false(MushaShugyo.is_seek_experience("HELP_PEOPLE"))


# =============================================================================
# SEEK_EXPERIENCE Decomposition — Bushi
# =============================================================================

func test_bushi_at_dojo_trains() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_DOJO, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 3)


func test_bushi_at_court_trains() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_COURT, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 2)


func test_bushi_default_trains() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.priority, 2)


func test_bushi_traveling_rests() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.TRAVELING, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.need_type, "REST")


func test_bushi_at_insurgency_patrols() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.BUSHI)
	ctx.active_insurgency_id = 5
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.need_type, "PATROL_PROVINCE")
	assert_eq(need.priority, 2)


# =============================================================================
# SEEK_EXPERIENCE Decomposition — Courtier
# =============================================================================

func test_courtier_at_court_raises_disposition() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_COURT, Enums.SchoolType.COURTIER)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.COURTIER)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.priority, 3)


func test_courtier_default_raises_disposition() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.COURTIER)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.COURTIER)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.priority, 2)


# =============================================================================
# SEEK_EXPERIENCE Decomposition — Shugenja
# =============================================================================

func test_shugenja_at_temple_performs_ritual() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_TEMPLE, Enums.SchoolType.SHUGENJA)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.SHUGENJA)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 3)


func test_shugenja_at_court_raises_disposition() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_COURT, Enums.SchoolType.SHUGENJA)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.SHUGENJA)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.priority, 2)


func test_shugenja_default_performs_ritual() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.SHUGENJA)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.SHUGENJA)
	assert_eq(need.need_type, "PERFORM_RITUAL")
	assert_eq(need.priority, 2)


func test_shugenja_at_insurgency_investigates() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.SHUGENJA)
	ctx.active_insurgency_id = 3
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.SHUGENJA)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.priority, 1)


# =============================================================================
# Decomposition Source Tag
# =============================================================================

func test_decompose_source_tag() -> void:
	var ctx := _make_ctx(Enums.ContextFlag.AT_OWN_HOLDINGS, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = MushaShugyo.decompose({}, ctx, Enums.SchoolType.BUSHI)
	assert_eq(need.source, "musha_shugyo_decomposition")


# =============================================================================
# Destination Weighting
# =============================================================================

func test_bushi_preferred_settlements() -> void:
	var types: Array = MushaShugyo.get_preferred_settlement_types(Enums.SchoolType.BUSHI)
	assert_true(Enums.SettlementType.CASTLE in types)
	assert_true(Enums.SettlementType.FORTIFICATION in types)


func test_courtier_preferred_settlements() -> void:
	var types: Array = MushaShugyo.get_preferred_settlement_types(Enums.SchoolType.COURTIER)
	assert_true(Enums.SettlementType.CASTLE in types)
	assert_true(Enums.SettlementType.CITY in types)
	assert_true(Enums.SettlementType.IMPERIAL_CAPITAL in types)


func test_shugenja_preferred_settlements() -> void:
	var types: Array = MushaShugyo.get_preferred_settlement_types(Enums.SchoolType.SHUGENJA)
	assert_true(Enums.SettlementType.TEMPLE in types)
	assert_true(Enums.SettlementType.SHINDEN in types)
	assert_true(Enums.SettlementType.MONASTERY in types)


func test_settlement_score_preferred_type_bonus() -> void:
	var s := SettlementData.new()
	s.settlement_type = Enums.SettlementType.CASTLE
	s.population_pu = 1
	var score_preferred: int = MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, true)
	s.settlement_type = Enums.SettlementType.VILLAGE
	var score_other: int = MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, true)
	assert_true(score_preferred > score_other, "Preferred settlement type should score higher")


func test_settlement_score_foreign_clan_bonus() -> void:
	var s := SettlementData.new()
	s.settlement_type = Enums.SettlementType.VILLAGE
	s.population_pu = 1
	var score_own: int = MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, true)
	var score_foreign: int = MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, false)
	assert_true(score_foreign > score_own, "Foreign clan settlement should score higher")


func test_settlement_score_population_bonus() -> void:
	var s := SettlementData.new()
	s.settlement_type = Enums.SettlementType.VILLAGE
	s.population_pu = 1
	var low_pop := MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, true)
	s.population_pu = 5
	var high_pop := MushaShugyo.score_settlement_for_pilgrimage(s, Enums.SchoolType.BUSHI, true)
	assert_true(high_pop > low_pop, "Higher population should score higher")


# =============================================================================
# ObjectiveDecomposer Routing
# =============================================================================

func test_objective_decomposer_routes_seek_experience() -> void:
	var obj: Dictionary = {"need_type": "SEEK_EXPERIENCE", "priority": 2}
	var ctx := _make_ctx(Enums.ContextFlag.AT_DOJO, Enums.SchoolType.BUSHI)
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(obj, ctx)
	assert_not_null(need)
	assert_eq(need.need_type, "TRAIN_SKILL")
	assert_eq(need.source, "musha_shugyo_decomposition")


# =============================================================================
# Evaluate at Gempukku
# =============================================================================

func test_evaluate_gempukku_with_zero_probability_always_fails() -> void:
	_char.clan = "Crab"
	_char.bushido_virtue = Enums.BushidoVirtue.CHUGI
	_char.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var result: bool = MushaShugyo.evaluate_at_gempukku(_char, _dice, 100)
	assert_false(result)
	assert_false(_char.musha_shugyo)


func test_evaluate_gempukku_can_trigger_pilgrimage() -> void:
	_char.clan = "Dragon"
	_char.bushido_virtue = Enums.BushidoVirtue.YU
	_char.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
	var triggered: bool = false
	for i in range(100):
		var test_char := L5RCharacterData.new()
		test_char.character_id = i + 10
		test_char.clan = "Dragon"
		test_char.bushido_virtue = Enums.BushidoVirtue.YU
		test_char.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
		test_char.lord_id = 100
		var d := DiceEngine.new()
		d.set_seed(i)
		if MushaShugyo.evaluate_at_gempukku(test_char, d, 100):
			triggered = true
			assert_true(test_char.musha_shugyo)
			assert_eq(test_char.musha_shugyo_end_ic_day, 460)
			break
	assert_true(triggered, "Dragon + Yu + Dosatsu (26%) should trigger within 100 tries")


# =============================================================================
# DayOrchestrator Wiring
# =============================================================================

func test_orchestrator_ends_pilgrimage_on_correct_day() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var lord := L5RCharacterData.new()
	lord.character_id = 100
	lord.wounds_taken = 0
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char, 100: lord}
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
	var results: Array = DayOrchestrator._process_musha_shugyo(chars, chars_by_id, 360, objectives_map)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["character_id"], 1)
	assert_false(_char.musha_shugyo)
	assert_eq(_char.lord_id, 100)


func test_orchestrator_does_not_end_early() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char}
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
	var results: Array = DayOrchestrator._process_musha_shugyo(chars, chars_by_id, 359, objectives_map)
	assert_eq(results.size(), 0)
	assert_true(_char.musha_shugyo)


func test_orchestrator_detects_dead_lord() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var lord := L5RCharacterData.new()
	lord.character_id = 100
	lord.stamina = 2
	lord.willpower = 2
	lord.wounds_taken = 999
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char, 100: lord}
	var objectives_map: Dictionary = {}
	var results: Array = DayOrchestrator._process_musha_shugyo(chars, chars_by_id, 360, objectives_map)
	assert_eq(results.size(), 1)
	assert_true(results[0].get("lord_dead", false))


func test_orchestrator_clears_objectives_map_on_end() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var lord := L5RCharacterData.new()
	lord.character_id = 100
	lord.wounds_taken = 0
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char, 100: lord}
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
	DayOrchestrator._process_musha_shugyo(chars, chars_by_id, 360, objectives_map)
	assert_false(objectives_map[1].has("standing"))


func test_orchestrator_skips_non_pilgrimage_characters() -> void:
	var other := L5RCharacterData.new()
	other.character_id = 2
	other.lord_id = 100
	other.musha_shugyo = false
	var chars: Array = [_char, other]
	var chars_by_id: Dictionary = {1: _char, 2: other}
	var objectives_map: Dictionary = {}
	var results: Array = DayOrchestrator._process_musha_shugyo(chars, chars_by_id, 500, objectives_map)
	assert_eq(results.size(), 0)


# =============================================================================
# Character Sheet Fields Default Values
# =============================================================================

func test_default_musha_shugyo_false() -> void:
	var c := L5RCharacterData.new()
	assert_false(c.musha_shugyo)


func test_default_musha_shugyo_end_day_sentinel() -> void:
	var c := L5RCharacterData.new()
	assert_eq(c.musha_shugyo_end_ic_day, -1)


func test_default_original_lord_id_sentinel() -> void:
	var c := L5RCharacterData.new()
	assert_eq(c.original_lord_id, -1)


func test_default_permanent_ronin_false() -> void:
	var c := L5RCharacterData.new()
	assert_false(c.permanent_ronin)


# =============================================================================
# Pilgrimage Ronin Conversion
# =============================================================================

func test_pilgrimage_ronin_chance_is_three_percent() -> void:
	assert_almost_eq(MushaShugyo.PILGRIMAGE_RONIN_CHANCE, 0.03, 0.001)


func test_check_ronin_conversion_returns_bool() -> void:
	var result: bool = MushaShugyo.check_ronin_conversion(_char, _dice)
	assert_typeof(result, TYPE_BOOL)


func test_end_pilgrimage_as_ronin_sets_permanent_flag() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_true(_char.permanent_ronin)


func test_end_pilgrimage_as_ronin_clears_musha_shugyo() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_false(_char.musha_shugyo)
	assert_eq(_char.musha_shugyo_end_ic_day, -1)


func test_end_pilgrimage_as_ronin_clears_original_lord() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_eq(_char.original_lord_id, -1)


func test_end_pilgrimage_as_ronin_calls_make_ronin() -> void:
	_char.lord_id = 100
	_char.honor = 5.0
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_eq(_char.lord_id, -1)
	assert_eq(_char.role_position, "")
	assert_almost_eq(_char.honor, 4.0, 0.01)


func test_end_pilgrimage_as_ronin_uses_voluntary_departure() -> void:
	_char.lord_id = 100
	_char.honor = 5.0
	MushaShugyo.begin_pilgrimage(_char, 0)
	var result: Dictionary = MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_true(result["became_ronin"])
	assert_eq(result["ronin_report"]["cause"], RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)


func test_end_pilgrimage_as_ronin_returns_result_dict() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var result: Dictionary = MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_eq(result["character_id"], _char.character_id)
	assert_true(result["became_ronin"])
	assert_true(result.has("ronin_report"))


func test_end_pilgrimage_as_ronin_clears_objective() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	assert_eq(_char.current_objective, "")


# =============================================================================
# Permanent Ronin — Service Rejection
# =============================================================================

func test_permanent_ronin_cannot_accept_service() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	var result: Dictionary = RoninSystem.accept_into_service(_char, 200, "Retainer", "Crane")
	assert_true(result.get("rejected", false))
	assert_eq(result["reason"], "permanent_ronin")
	assert_eq(_char.lord_id, -1)


func test_permanent_ronin_cannot_petition() -> void:
	_char.lord_id = 100
	_char.awareness = 4
	_char.skills["Etiquette"] = 3
	MushaShugyo.begin_pilgrimage(_char, 0)
	MushaShugyo.end_pilgrimage_as_ronin(_char)
	var lord := L5RCharacterData.new()
	lord.character_id = 200
	lord.disposition_values = {}
	var result: Dictionary = RoninSystem.resolve_petition(_char, lord, _dice)
	assert_false(result["success"])
	assert_true(result.get("rejected", false))
	assert_eq(result["reason"], "permanent_ronin")


func test_normal_ronin_can_still_accept_service() -> void:
	_char.lord_id = 100
	_char.status = 2.0
	RoninSystem.make_ronin(_char, RoninSystem.RoninCause.DISMISSAL)
	assert_false(_char.permanent_ronin)
	var result: Dictionary = RoninSystem.accept_into_service(_char, 200, "Retainer", "Crane")
	assert_false(result.get("rejected", false))
	assert_eq(_char.lord_id, 200)


func test_normal_ronin_can_still_petition() -> void:
	_char.lord_id = 100
	_char.status = 2.0
	_char.awareness = 4
	_char.skills["Etiquette"] = 3
	RoninSystem.make_ronin(_char, RoninSystem.RoninCause.DISMISSAL)
	var lord := L5RCharacterData.new()
	lord.character_id = 200
	lord.disposition_values = {_char.character_id: 10}
	var result: Dictionary = RoninSystem.resolve_petition(_char, lord, _dice)
	assert_false(result.get("rejected", false))
	assert_true(result.has("success"))


# =============================================================================
# Orchestrator Ronin Conversion Wiring
# =============================================================================

func test_orchestrator_ronin_conversion_sets_permanent_flag() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char}
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
	var converted: bool = false
	for seed_val: int in range(200):
		var test_char := L5RCharacterData.new()
		test_char.character_id = 1
		test_char.character_name = "Test"
		test_char.clan = "Crane"
		test_char.family = "Kakita"
		test_char.school = "Kakita Bushi"
		test_char.school_type = Enums.SchoolType.BUSHI
		test_char.lord_id = 100
		test_char.status = 1.0
		test_char.honor = 5.0
		test_char.role_position = "Samurai"
		MushaShugyo.begin_pilgrimage(test_char, 0)
		var test_chars: Array = [test_char]
		var test_cbi: Dictionary = {1: test_char}
		var test_omap: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
		var d := DiceEngine.new()
		d.set_seed(seed_val)
		var results: Array = DayOrchestrator._process_musha_shugyo(test_chars, test_cbi, 360, test_omap, d)
		if results.size() > 0 and results[0].get("became_ronin", false):
			converted = true
			assert_true(test_char.permanent_ronin)
			assert_true(RoninSystem.is_ronin(test_char))
			assert_false(test_omap[1].has("standing"))
			break
	assert_true(converted, "At 3% chance should trigger within 200 seeds")


func test_orchestrator_normal_end_when_no_ronin_conversion() -> void:
	_char.lord_id = 100
	MushaShugyo.begin_pilgrimage(_char, 0)
	var lord := L5RCharacterData.new()
	lord.character_id = 100
	lord.wounds_taken = 0
	var chars: Array = [_char]
	var chars_by_id: Dictionary = {1: _char, 100: lord}
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
	var found_normal: bool = false
	for seed_val: int in range(200):
		var test_char := L5RCharacterData.new()
		test_char.character_id = 1
		test_char.character_name = "Test"
		test_char.clan = "Crane"
		test_char.lord_id = 100
		test_char.status = 1.0
		test_char.honor = 5.0
		MushaShugyo.begin_pilgrimage(test_char, 0)
		var test_chars: Array = [test_char]
		var test_cbi: Dictionary = {1: test_char, 100: lord}
		var test_omap: Dictionary = {1: {"standing": {"need_type": "SEEK_EXPERIENCE"}}}
		var d := DiceEngine.new()
		d.set_seed(seed_val)
		var results: Array = DayOrchestrator._process_musha_shugyo(test_chars, test_cbi, 360, test_omap, d)
		if results.size() > 0 and not results[0].get("became_ronin", false):
			found_normal = true
			assert_false(test_char.permanent_ronin)
			assert_eq(test_char.lord_id, 100)
			assert_true(results[0]["lord_restored"])
			break
	assert_true(found_normal, "Should find normal end within 200 seeds")


func test_orchestrator_ronin_marks_ronin_start() -> void:
	for seed_val: int in range(200):
		var test_char := L5RCharacterData.new()
		test_char.character_id = 1
		test_char.clan = "Crane"
		test_char.lord_id = 100
		test_char.status = 1.0
		test_char.honor = 5.0
		test_char.role_position = "Samurai"
		MushaShugyo.begin_pilgrimage(test_char, 0)
		var test_chars: Array = [test_char]
		var test_cbi: Dictionary = {1: test_char}
		var test_omap: Dictionary = {}
		var d := DiceEngine.new()
		d.set_seed(seed_val)
		var results: Array = DayOrchestrator._process_musha_shugyo(test_chars, test_cbi, 360, test_omap, d, 5)
		if results.size() > 0 and results[0].get("became_ronin", false):
			assert_eq(test_char.supply_ledger.get("ronin_since_season"), 5)
			return
	fail_test("Should find ronin conversion within 200 seeds")
