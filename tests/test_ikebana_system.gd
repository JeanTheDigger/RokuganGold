extends GutTest
## Tests for s57.29 Ikebana Flower Arrangement System.
## Covers: IkebanaSystem constants/helpers, IkebanaArrangementData,
## DayOrchestrator writebacks (creation, decay, visitor effects, deceased topic),
## context injection (slot empty, worship FR), world-start seeding.


var _dice: DiceEngine
var _artisan: L5RCharacterData
var _visitor: L5RCharacterData
var _settlement_castle: SettlementData
var _settlement_temple: SettlementData
var _settlement_village: SettlementData


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)

	_artisan = L5RCharacterData.new()
	_artisan.character_id = 1
	_artisan.clan = "Crane"
	_artisan.awareness = 3
	_artisan.skills = {"Artisan: Ikebana": 4}
	_artisan.topic_pool = []
	_artisan.met_characters = []
	_artisan.temporary_modifiers = {}
	_artisan.physical_location = "10"
	_artisan.bushido_virtue = "Rei"
	_artisan.shourido_virtue = ""

	_visitor = L5RCharacterData.new()
	_visitor.character_id = 2
	_visitor.clan = "Lion"
	_visitor.temporary_modifiers = {}
	_visitor.physical_location = "10"
	_visitor.met_characters = []

	_settlement_castle = SettlementData.new()
	_settlement_castle.settlement_id = 10
	_settlement_castle.settlement_type = Enums.SettlementType.CASTLE

	_settlement_temple = SettlementData.new()
	_settlement_temple.settlement_id = 20
	_settlement_temple.settlement_type = Enums.SettlementType.TEMPLE

	_settlement_village = SettlementData.new()
	_settlement_village.settlement_id = 30
	_settlement_village.settlement_type = Enums.SettlementType.VILLAGE


# --------------------------------------------------------------------------
# IkebanaSystem — quality_from_raises
# --------------------------------------------------------------------------

func test_quality_0_raises_returns_normal() -> void:
	assert_eq(IkebanaSystem.quality_from_raises(0), GiftGivingSystem.QualityTier.NORMAL)


func test_quality_1_raise_returns_fine() -> void:
	assert_eq(IkebanaSystem.quality_from_raises(1), GiftGivingSystem.QualityTier.FINE)


func test_quality_2_raises_returns_exceptional() -> void:
	assert_eq(IkebanaSystem.quality_from_raises(2), GiftGivingSystem.QualityTier.EXCEPTIONAL)


func test_quality_3_raises_returns_masterwork() -> void:
	assert_eq(IkebanaSystem.quality_from_raises(3), GiftGivingSystem.QualityTier.MASTERWORK)


func test_quality_4_plus_raises_returns_legendary() -> void:
	assert_eq(IkebanaSystem.quality_from_raises(4), GiftGivingSystem.QualityTier.LEGENDARY)
	assert_eq(IkebanaSystem.quality_from_raises(9), GiftGivingSystem.QualityTier.LEGENDARY)


# --------------------------------------------------------------------------
# IkebanaSystem — default_lifespan
# --------------------------------------------------------------------------

func test_lifespan_normal_is_7() -> void:
	assert_eq(IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.NORMAL), 7)


func test_lifespan_fine_is_14() -> void:
	assert_eq(IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.FINE), 14)


func test_lifespan_exceptional_is_21() -> void:
	assert_eq(IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.EXCEPTIONAL), 21)


func test_lifespan_masterwork_is_30() -> void:
	assert_eq(IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.MASTERWORK), 30)


func test_lifespan_legendary_is_45() -> void:
	assert_eq(IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.LEGENDARY), 45)


# --------------------------------------------------------------------------
# IkebanaSystem — visitor_bonus_for_quality
# --------------------------------------------------------------------------

func test_visitor_bonus_normal_is_1() -> void:
	assert_eq(IkebanaSystem.visitor_bonus_for_quality(GiftGivingSystem.QualityTier.NORMAL), 1)


func test_visitor_bonus_legendary_is_5() -> void:
	assert_eq(IkebanaSystem.visitor_bonus_for_quality(GiftGivingSystem.QualityTier.LEGENDARY), 5)


# --------------------------------------------------------------------------
# IkebanaSystem — worship_fr_for_quality
# --------------------------------------------------------------------------

func test_worship_fr_normal_is_0() -> void:
	assert_eq(IkebanaSystem.worship_fr_for_quality(GiftGivingSystem.QualityTier.NORMAL), 0)


func test_worship_fr_fine_is_0() -> void:
	assert_eq(IkebanaSystem.worship_fr_for_quality(GiftGivingSystem.QualityTier.FINE), 0)


func test_worship_fr_exceptional_is_1() -> void:
	assert_eq(IkebanaSystem.worship_fr_for_quality(GiftGivingSystem.QualityTier.EXCEPTIONAL), 1)


func test_worship_fr_masterwork_is_1() -> void:
	assert_eq(IkebanaSystem.worship_fr_for_quality(GiftGivingSystem.QualityTier.MASTERWORK), 1)


func test_worship_fr_legendary_is_1() -> void:
	assert_eq(IkebanaSystem.worship_fr_for_quality(GiftGivingSystem.QualityTier.LEGENDARY), 1)


# --------------------------------------------------------------------------
# IkebanaSystem — garden_fr_for_quality
# --------------------------------------------------------------------------

func test_garden_fr_normal_is_0() -> void:
	assert_eq(IkebanaSystem.garden_fr_for_quality(GiftGivingSystem.QualityTier.NORMAL), 0)


func test_garden_fr_fine_is_1() -> void:
	assert_eq(IkebanaSystem.garden_fr_for_quality(GiftGivingSystem.QualityTier.FINE), 1)


func test_garden_fr_masterwork_is_2() -> void:
	assert_eq(IkebanaSystem.garden_fr_for_quality(GiftGivingSystem.QualityTier.MASTERWORK), 2)


# --------------------------------------------------------------------------
# IkebanaSystem — is_eligible_display_settlement
# --------------------------------------------------------------------------

func test_castle_is_eligible() -> void:
	assert_true(IkebanaSystem.is_eligible_display_settlement(_settlement_castle))


func test_temple_is_eligible() -> void:
	assert_true(IkebanaSystem.is_eligible_display_settlement(_settlement_temple))


func test_village_is_not_eligible() -> void:
	assert_false(IkebanaSystem.is_eligible_display_settlement(_settlement_village))


# --------------------------------------------------------------------------
# IkebanaSystem — is_shrine_eligible
# --------------------------------------------------------------------------

func test_temple_is_shrine_eligible() -> void:
	assert_true(IkebanaSystem.is_shrine_eligible(_settlement_temple))


func test_castle_is_not_shrine_eligible() -> void:
	assert_false(IkebanaSystem.is_shrine_eligible(_settlement_castle))


# --------------------------------------------------------------------------
# IkebanaSystem — select_season_materials
# --------------------------------------------------------------------------

func test_winter_exceptional_rei_may_produce_shochikubai() -> void:
	# With seed 42 and Rei virtue, exceptional winter should sometimes pick shochikubai.
	# Test passes if the result contains all three canonical materials OR falls back
	# to regular selection (both are valid outcomes).
	var materials: Array[String] = IkebanaSystem.select_season_materials(
		TimeSystem.Season.WINTER,
		_artisan,
		GiftGivingSystem.QualityTier.EXCEPTIONAL,
		_dice,
	)
	assert_gt(materials.size(), 0)
	assert_lt(materials.size(), 4)


func test_normal_quality_selects_single_material() -> void:
	var materials: Array[String] = IkebanaSystem.select_season_materials(
		TimeSystem.Season.SPRING,
		_artisan,
		GiftGivingSystem.QualityTier.NORMAL,
		_dice,
	)
	assert_eq(materials.size(), 1)


func test_masterwork_quality_selects_three_materials() -> void:
	var materials: Array[String] = IkebanaSystem.select_season_materials(
		TimeSystem.Season.AUTUMN,
		_artisan,
		GiftGivingSystem.QualityTier.MASTERWORK,
		_dice,
	)
	assert_eq(materials.size(), 3)


# --------------------------------------------------------------------------
# IkebanaSystem — generate_composition_description
# --------------------------------------------------------------------------

func test_composition_description_not_empty() -> void:
	var mats: Array[String] = ["Sakura"]
	var desc: String = IkebanaSystem.generate_composition_description(
		mats, GiftGivingSystem.QualityTier.NORMAL, TimeSystem.Season.SPRING, "Crane"
	)
	assert_false(desc.is_empty())


func test_composition_description_shochikubai() -> void:
	var mats: Array[String] = ["Matsu", "Take", "Ume"]
	var desc: String = IkebanaSystem.generate_composition_description(
		mats, GiftGivingSystem.QualityTier.MASTERWORK, TimeSystem.Season.WINTER, "Crane"
	)
	assert_true("shōchikubai" in desc)


# --------------------------------------------------------------------------
# DayOrchestrator._process_ikebana_daily_decay
# --------------------------------------------------------------------------

func test_daily_decay_decrements_lifespan() -> void:
	var arr: IkebanaArrangementData = IkebanaArrangementData.new()
	arr.arrangement_id = 1
	arr.lifespan_remaining = 7
	arr.display_settlement_id = "10"
	var arrangements: Array = [arr]
	DayOrchestrator._process_ikebana_daily_decay(arrangements)
	assert_eq(arr.lifespan_remaining, 6)
	assert_false(arr.expired)


func test_daily_decay_expires_at_zero() -> void:
	var arr: IkebanaArrangementData = IkebanaArrangementData.new()
	arr.arrangement_id = 1
	arr.lifespan_remaining = 1
	arr.display_settlement_id = "10"
	var arrangements: Array = [arr]
	DayOrchestrator._process_ikebana_daily_decay(arrangements)
	assert_eq(arr.lifespan_remaining, 0)
	assert_true(arr.expired)


func test_daily_decay_skips_inventory_arrangements() -> void:
	var arr: IkebanaArrangementData = IkebanaArrangementData.new()
	arr.arrangement_id = 1
	arr.lifespan_remaining = 7
	arr.display_settlement_id = ""  # Not displayed
	var arrangements: Array = [arr]
	DayOrchestrator._process_ikebana_daily_decay(arrangements)
	assert_eq(arr.lifespan_remaining, 7)


# --------------------------------------------------------------------------
# DayOrchestrator._process_ikebana_visitor_effects
# --------------------------------------------------------------------------

func _make_displayed_arrangement(quality: int, settlement_str_id: String, creator_id: int) -> IkebanaArrangementData:
	var arr: IkebanaArrangementData = IkebanaArrangementData.new()
	arr.arrangement_id = 1
	arr.creator_id = creator_id
	arr.quality_tier = quality
	arr.display_settlement_id = settlement_str_id
	arr.lifespan_remaining = 14
	return arr


func test_visitor_receives_disposition_modifier() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.FINE, "10", _artisan.character_id
	)
	var arrangements: Array = [arr]
	var characters: Array = [_artisan, _visitor]
	var chars_by_id: Dictionary = {1: _artisan, 2: _visitor}
	var settlements: Array = [_settlement_castle]

	DayOrchestrator._process_ikebana_visitor_effects(
		arrangements, characters, chars_by_id, settlements, 1
	)

	# _visitor should have received a temporary modifier toward _artisan
	var bucket: Array = _visitor.temporary_modifiers.get(_artisan.character_id, [])
	assert_eq(bucket.size(), 1)
	assert_eq(bucket[0].get("event_type"), "ikebana_visitor")
	assert_eq(bucket[0].get("value"), 2)  # Fine = +2


func test_visitor_not_duplicated() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "10", _artisan.character_id
	)
	arr.visitors_who_received_bonus.append(_visitor.character_id)  # Already visited
	var arrangements: Array = [arr]
	var characters: Array = [_artisan, _visitor]
	var chars_by_id: Dictionary = {1: _artisan, 2: _visitor}
	var settlements: Array = [_settlement_castle]

	DayOrchestrator._process_ikebana_visitor_effects(
		arrangements, characters, chars_by_id, settlements, 1
	)

	var bucket: Array = _visitor.temporary_modifiers.get(_artisan.character_id, [])
	assert_eq(bucket.size(), 0)  # No new entry added


func test_glory_tick_fires_at_5_visitors() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "10", _artisan.character_id
	)
	# Pre-load 4 previous visitors
	arr.visitors_who_received_bonus = [10, 11, 12, 13]

	var arrangements: Array = [arr]
	var characters: Array = [_artisan, _visitor]
	var chars_by_id: Dictionary = {1: _artisan, 2: _visitor}
	var settlements: Array = [_settlement_castle]
	var initial_glory: float = _artisan.glory

	DayOrchestrator._process_ikebana_visitor_effects(
		arrangements, characters, chars_by_id, settlements, 1
	)

	# 5th visitor triggers a glory tick: creator +0.1
	assert_almost_eq(_artisan.glory, initial_glory + IkebanaSystem.CREATOR_GLORY_PER_TICK, 0.001)
	assert_eq(arr.glory_ticks_applied, 1)


# --------------------------------------------------------------------------
# DayOrchestrator._process_ikebana_creator_deceased_topics
# --------------------------------------------------------------------------

func test_creator_deceased_topic_fires_once() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "10", _artisan.character_id
	)
	arr.creator_deceased_topic_fired = false

	# Mark artisan as dead — earth_ring = 0 makes threshold = 0 → is_dead() = true
	_artisan.earth_ring = 0

	var chars_by_id: Dictionary = {1: _artisan}
	var active_topics: Array = []
	var next_topic_id: Array = [1]
	var arrangements: Array = [arr]

	DayOrchestrator._process_ikebana_creator_deceased_topics(
		arrangements, chars_by_id, active_topics, next_topic_id, 1
	)

	assert_eq(active_topics.size(), 1)
	assert_eq(active_topics[0].topic_type, "ikebana_creator_deceased")
	assert_eq(active_topics[0].subject_role, "NEUTRAL")
	assert_true(arr.creator_deceased_topic_fired)


func test_creator_deceased_topic_does_not_fire_twice() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "10", _artisan.character_id
	)
	arr.creator_deceased_topic_fired = true  # Already fired

	_artisan.earth_ring = 0  # is_dead() = true

	var chars_by_id: Dictionary = {1: _artisan}
	var active_topics: Array = []
	var next_topic_id: Array = [1]
	var arrangements: Array = [arr]

	DayOrchestrator._process_ikebana_creator_deceased_topics(
		arrangements, chars_by_id, active_topics, next_topic_id, 1
	)

	assert_eq(active_topics.size(), 0)


# --------------------------------------------------------------------------
# DayOrchestrator._remove_expired_arrangements
# --------------------------------------------------------------------------

func test_remove_expired_removes_expired_only() -> void:
	var live_arr: IkebanaArrangementData = IkebanaArrangementData.new()
	live_arr.arrangement_id = 1
	live_arr.expired = false
	live_arr.display_settlement_id = "10"

	var dead_arr: IkebanaArrangementData = IkebanaArrangementData.new()
	dead_arr.arrangement_id = 2
	dead_arr.expired = true
	dead_arr.display_settlement_id = "10"

	var arrangements: Array = [live_arr, dead_arr]
	DayOrchestrator._remove_expired_arrangements(arrangements)
	assert_eq(arrangements.size(), 1)
	assert_eq((arrangements[0] as IkebanaArrangementData).arrangement_id, 1)


# --------------------------------------------------------------------------
# DayOrchestrator._inject_ikebana_context
# --------------------------------------------------------------------------

func test_inject_context_slot_empty_when_no_arrangement() -> void:
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	DayOrchestrator._inject_ikebana_context([], [_settlement_castle], [_artisan], world_states)

	var ws: Dictionary = world_states[_artisan.character_id]
	assert_true(ws["known_objectives"].get("ikebana_slot_empty", false))


func test_inject_context_slot_filled_when_arrangement_present() -> void:
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.FINE, "10", _artisan.character_id
	)
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	DayOrchestrator._inject_ikebana_context(
		[arr], [_settlement_castle], [_artisan], world_states
	)

	var ws: Dictionary = world_states[_artisan.character_id]
	assert_false(ws["known_objectives"].get("ikebana_slot_empty", true))


func test_inject_context_worship_fr_for_exceptional_at_temple() -> void:
	# Artisan at temple with Exceptional arrangement should see worship FR = 1
	_artisan.physical_location = "20"  # Temple settlement
	_visitor.physical_location = "20"
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.EXCEPTIONAL, "20", _artisan.character_id
	)
	var world_states: Dictionary = {
		_visitor.character_id: {"known_objectives": {}}
	}
	DayOrchestrator._inject_ikebana_context(
		[arr], [_settlement_temple], [_visitor], world_states
	)

	var ws: Dictionary = world_states[_visitor.character_id]
	assert_eq(ws["known_objectives"].get("ikebana_worship_fr", 0), 1)


func test_inject_context_no_worship_fr_for_normal() -> void:
	_artisan.physical_location = "20"
	_visitor.physical_location = "20"
	var arr: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "20", _artisan.character_id
	)
	var world_states: Dictionary = {
		_visitor.character_id: {"known_objectives": {}}
	}
	DayOrchestrator._inject_ikebana_context(
		[arr], [_settlement_temple], [_visitor], world_states
	)

	var ws: Dictionary = world_states[_visitor.character_id]
	assert_eq(ws["known_objectives"].get("ikebana_worship_fr", 0), 0)


# --------------------------------------------------------------------------
# IkebanaSystem — generate_initial_arrangements (world bootstrap)
# --------------------------------------------------------------------------

func test_generate_initial_arrangements_creates_for_eligible_settlement() -> void:
	var settlements: Array = [_settlement_castle]
	var characters: Array = [_artisan]
	var next_id: Array = [1]

	var result: Array[IkebanaArrangementData] = IkebanaSystem.generate_initial_arrangements(
		characters, settlements, _dice, next_id, 0
	)

	assert_gt(result.size(), 0)
	var arr: IkebanaArrangementData = result[0]
	assert_eq(arr.creator_id, _artisan.character_id)
	assert_eq(arr.display_settlement_id, "10")
	assert_false(arr.expired)


func test_generate_initial_no_arrangements_for_village() -> void:
	var settlements: Array = [_settlement_village]
	var characters: Array = [_artisan]
	var next_id: Array = [1]

	var result: Array[IkebanaArrangementData] = IkebanaSystem.generate_initial_arrangements(
		characters, settlements, _dice, next_id, 0
	)

	assert_eq(result.size(), 0)


func test_generate_initial_no_arrangement_without_artisan() -> void:
	# Character with no Artisan: Ikebana skill
	var non_artisan: L5RCharacterData = L5RCharacterData.new()
	non_artisan.character_id = 5
	non_artisan.physical_location = "10"
	non_artisan.skills = {}

	var settlements: Array = [_settlement_castle]
	var characters: Array = [non_artisan]
	var next_id: Array = [1]

	var result: Array[IkebanaArrangementData] = IkebanaSystem.generate_initial_arrangements(
		characters, settlements, _dice, next_id, 0
	)

	assert_eq(result.size(), 0)


func test_generate_initial_arrangement_has_valid_lifespan() -> void:
	var settlements: Array = [_settlement_castle]
	var characters: Array = [_artisan]
	var next_id: Array = [1]

	var result: Array[IkebanaArrangementData] = IkebanaSystem.generate_initial_arrangements(
		characters, settlements, _dice, next_id, 0
	)

	assert_gt(result.size(), 0)
	var arr: IkebanaArrangementData = result[0]
	assert_gt(arr.lifespan_remaining, 0)
	assert_le(arr.lifespan_remaining, IkebanaSystem.default_lifespan(arr.quality_tier))


# --------------------------------------------------------------------------
# DayOrchestrator._process_ikebana_performance_writebacks
# --------------------------------------------------------------------------

func test_performance_writeback_creates_arrangement() -> void:
	var chars_by_id: Dictionary = {1: _artisan}
	var settlements: Array = [_settlement_castle]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 2,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 1)
	var arr: IkebanaArrangementData = active_arrangements[0] as IkebanaArrangementData
	assert_eq(arr.creator_id, _artisan.character_id)
	assert_eq(arr.quality_tier, GiftGivingSystem.QualityTier.EXCEPTIONAL)
	assert_eq(arr.display_settlement_id, "10")
	assert_eq(arr.lifespan_remaining, IkebanaSystem.default_lifespan(GiftGivingSystem.QualityTier.EXCEPTIONAL))


func test_performance_writeback_replaces_prior_arrangement() -> void:
	var prior: IkebanaArrangementData = _make_displayed_arrangement(
		GiftGivingSystem.QualityTier.NORMAL, "10", _artisan.character_id
	)
	var active_arrangements: Array = [prior]
	var next_id: Array = [2]
	var chars_by_id: Dictionary = {1: _artisan}
	var settlements: Array = [_settlement_castle]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PERFORM_FOR",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 1,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 2, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	# Prior arrangement should be expired
	assert_true(prior.expired)
	# New arrangement added
	assert_eq(active_arrangements.size(), 2)  # Both present until _remove_expired runs
	var new_arr: IkebanaArrangementData = active_arrangements[1] as IkebanaArrangementData
	assert_eq(new_arr.quality_tier, GiftGivingSystem.QualityTier.FINE)


func test_performance_writeback_ignores_non_ikebana() -> void:
	var chars_by_id: Dictionary = {1: _artisan}
	var settlements: Array = [_settlement_castle]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.POETRY,  # Not ikebana
			"raises": 2,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 0)


func test_performance_writeback_skips_non_eligible_settlement() -> void:
	_artisan.physical_location = "30"  # Village
	var chars_by_id: Dictionary = {1: _artisan}
	var settlements: Array = [_settlement_village]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 0,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 0)


# --------------------------------------------------------------------------
# IkebanaArrangementData — shrine offering flag
# --------------------------------------------------------------------------

func test_shrine_offering_flag_set_for_temple() -> void:
	_artisan.physical_location = "20"
	var chars_by_id: Dictionary = {1: _artisan}
	var settlements: Array = [_settlement_temple]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 0,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 1)
	var arr: IkebanaArrangementData = active_arrangements[0] as IkebanaArrangementData
	assert_true(arr.is_shrine_offering)


# --------------------------------------------------------------------------
# Garden synergy — _inject_ikebana_context (s57.29.6)
# --------------------------------------------------------------------------

func _make_garden(gid: int, sid: int, tier: int, destroyed: bool = false) -> GardenData:
	var g: GardenData = GardenData.new()
	g.garden_id = gid
	g.settlement_id = sid
	g.current_tier = tier
	g.destroyed = destroyed
	return g


func test_inject_ikebana_context_injects_garden_fr_for_ikebana_artisan() -> void:
	## Artisan: Ikebana at same settlement as a Fine (tier 2) garden gets +1 FR.
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	var garden: GardenData = _make_garden(99, 10, 2)  # Fine tier at settlement "10"
	DayOrchestrator._inject_ikebana_context(
		[], [_settlement_castle], [_artisan], world_states, [garden]
	)
	var obj: Dictionary = world_states[_artisan.character_id]["known_objectives"]
	assert_eq(obj.get("ikebana_garden_fr", -99), 1, "Fine garden gives +1 FR")
	assert_eq(obj.get("ikebana_garden_id", -99), 99, "garden_id recorded")


func test_inject_ikebana_context_no_fr_without_garden() -> void:
	## No garden present → FR = 0, garden_id = -1.
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	DayOrchestrator._inject_ikebana_context(
		[], [_settlement_castle], [_artisan], world_states, []
	)
	var obj: Dictionary = world_states[_artisan.character_id]["known_objectives"]
	assert_eq(obj.get("ikebana_garden_fr", -99), 0)
	assert_eq(obj.get("ikebana_garden_id", -99), -1)


func test_inject_ikebana_context_destroyed_garden_ignored() -> void:
	## Destroyed garden contributes no FR bonus.
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	var garden: GardenData = _make_garden(99, 10, 5, true)  # destroyed Legendary
	DayOrchestrator._inject_ikebana_context(
		[], [_settlement_castle], [_artisan], world_states, [garden]
	)
	var obj: Dictionary = world_states[_artisan.character_id]["known_objectives"]
	assert_eq(obj.get("ikebana_garden_fr", -99), 0)
	assert_eq(obj.get("ikebana_garden_id", -99), -1)


func test_inject_ikebana_context_no_fr_without_ikebana_skill() -> void:
	## Character at same settlement but lacking Artisan: Ikebana gets no garden FR.
	var non_artisan: L5RCharacterData = L5RCharacterData.new()
	non_artisan.character_id = 99
	non_artisan.skills = {}
	non_artisan.physical_location = "10"
	var world_states: Dictionary = {
		non_artisan.character_id: {"known_objectives": {}}
	}
	var garden: GardenData = _make_garden(99, 10, 4)  # Masterwork
	DayOrchestrator._inject_ikebana_context(
		[], [_settlement_castle], [non_artisan], world_states, [garden]
	)
	var obj: Dictionary = world_states[non_artisan.character_id]["known_objectives"]
	assert_eq(obj.get("ikebana_garden_fr", -99), 0)
	assert_eq(obj.get("ikebana_garden_id", -99), -1)


func test_inject_ikebana_context_masterwork_gives_2_fr() -> void:
	## Masterwork garden (tier 4) gives +2 FR to ikebana artisan.
	var world_states: Dictionary = {
		_artisan.character_id: {"known_objectives": {}}
	}
	var garden: GardenData = _make_garden(7, 10, 4)
	DayOrchestrator._inject_ikebana_context(
		[], [_settlement_castle], [_artisan], world_states, [garden]
	)
	var obj: Dictionary = world_states[_artisan.character_id]["known_objectives"]
	assert_eq(obj.get("ikebana_garden_fr", -99), 2)


# --------------------------------------------------------------------------
# Garden synergy — _process_ikebana_performance_writebacks sets materials_source
# --------------------------------------------------------------------------

func test_writeback_sets_materials_source_when_garden_id_present() -> void:
	## When effects contain garden_id >= 0, arr.materials_source is set to it.
	var chars_by_id: Dictionary = {_artisan.character_id: _artisan}
	var settlements: Array = [_settlement_castle]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 0,
			"garden_id": 42,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 1)
	var arr: IkebanaArrangementData = active_arrangements[0] as IkebanaArrangementData
	assert_eq(arr.materials_source, 42)


func test_writeback_materials_source_minus1_when_no_garden() -> void:
	## When garden_id is absent from effects, materials_source stays at default -1.
	var chars_by_id: Dictionary = {_artisan.character_id: _artisan}
	var settlements: Array = [_settlement_castle]
	var active_arrangements: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_topic_id: Array = [1]

	var result: Dictionary = {
		"action_id": "PUBLIC_PERFORMANCE",
		"success": true,
		"character_id": _artisan.character_id,
		"effects": {
			"art_form": PerformativeArtsSystem.ArtForm.IKEBANA,
			"raises": 0,
		},
	}

	DayOrchestrator._process_ikebana_performance_writebacks(
		[result], active_arrangements, next_id, chars_by_id,
		settlements, 1, TimeSystem.Season.SPRING,
		active_topics, next_topic_id, _dice
	)

	assert_eq(active_arrangements.size(), 1)
	var arr: IkebanaArrangementData = active_arrangements[0] as IkebanaArrangementData
	assert_eq(arr.materials_source, -1)
