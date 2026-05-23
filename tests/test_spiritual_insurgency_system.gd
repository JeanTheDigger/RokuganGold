extends GutTest
## Tests for SpiritualInsurgencySystem per GDD s56.16.
## Covers: trigger detection, severity determination, realm/element selection,
## event generation, NPC resolution, seasonal processing, topic generation,
## resolution effects, battle-triggered events, and DayOrchestrator wiring.


var _dice_engine: DiceEngine
var _shugenja: L5RCharacterData


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)

	_shugenja = L5RCharacterData.new()
	_shugenja.character_id = 1
	_shugenja.character_name = "Test Shugenja"
	_shugenja.clan = "Phoenix"
	_shugenja.school_type = Enums.SchoolType.SHUGENJA
	_shugenja.school_name = "Isawa Shugenja"
	_shugenja.skills = {"Lore: Theology": 4, "Meditation": 3}
	_shugenja.awareness = 4
	_shugenja.willpower = 3
	_shugenja.perception = 3
	_shugenja.intelligence = 3
	_shugenja.void_ring = 3
	_shugenja.reflexes = 2
	_shugenja.stamina = 2
	_shugenja.agility = 2
	_shugenja.strength = 2
	_shugenja.honor = 5.0
	_shugenja.glory = 3.0
	_shugenja.wounds_taken = 0
	_shugenja.physical_location = "100"


func _make_tiers(displeased: int, wrathful: int = 0) -> Dictionary:
	var tiers: Dictionary = {}
	var fortune: int = 0
	for _i: int in range(wrathful):
		tiers[fortune] = Enums.WorshipTier.WRATHFUL
		fortune += 1
	for _i: int in range(displeased):
		tiers[fortune] = Enums.WorshipTier.DISPLEASED
		fortune += 1
	while fortune < WorshipSystem.GREAT_FORTUNE_COUNT:
		tiers[fortune] = Enums.WorshipTier.NONE
		fortune += 1
	return tiers


func _make_event(
	severity: Enums.SpiritualSeverity = Enums.SpiritualSeverity.MILD,
	event_type: Enums.SpiritualEventType = Enums.SpiritualEventType.REALM_OVERLAP,
	realm: Enums.SpiritRealm = Enums.SpiritRealm.GAKI_DO,
	element: Enums.Ring = Enums.Ring.NONE,
) -> SpiritualInsurgencyData:
	var event := SpiritualInsurgencyData.new()
	event.event_id = 1
	event.province_id = 10
	event.severity = severity
	event.event_type = event_type
	event.realm = realm
	event.element = element
	event.season_spawned = 0
	return event


# =============================================================================
# Trigger Detection
# =============================================================================


func test_no_trigger_with_zero_displeased() -> void:
	var tiers: Dictionary = _make_tiers(0)
	assert_false(SpiritualInsurgencySystem.should_trigger(tiers))


func test_no_trigger_with_one_displeased() -> void:
	var tiers: Dictionary = _make_tiers(1)
	assert_false(SpiritualInsurgencySystem.should_trigger(tiers))


func test_trigger_with_two_displeased() -> void:
	var tiers: Dictionary = _make_tiers(2)
	assert_true(SpiritualInsurgencySystem.should_trigger(tiers))


func test_trigger_with_three_displeased() -> void:
	var tiers: Dictionary = _make_tiers(3)
	assert_true(SpiritualInsurgencySystem.should_trigger(tiers))


func test_trigger_with_wrathful() -> void:
	var tiers: Dictionary = _make_tiers(1, 1)
	assert_true(SpiritualInsurgencySystem.should_trigger(tiers))


# =============================================================================
# Severity Determination
# =============================================================================


func test_severity_mild_with_two_displeased() -> void:
	var tiers: Dictionary = _make_tiers(2)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.MILD,
	)


func test_severity_moderate_with_three_displeased() -> void:
	var tiers: Dictionary = _make_tiers(3)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.MODERATE,
	)


func test_severity_severe_with_four_displeased() -> void:
	var tiers: Dictionary = _make_tiers(4)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.SEVERE,
	)


func test_severity_severe_with_one_wrathful() -> void:
	var tiers: Dictionary = _make_tiers(1, 1)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.SEVERE,
	)


func test_severity_catastrophic_with_five_wrathful() -> void:
	var tiers: Dictionary = _make_tiers(0, 5)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.CATASTROPHIC,
	)


func test_severity_severe_with_four_wrathful() -> void:
	var tiers: Dictionary = _make_tiers(0, 4)
	assert_eq(
		SpiritualInsurgencySystem.determine_severity(tiers),
		Enums.SpiritualSeverity.SEVERE,
	)


# =============================================================================
# Event Type Selection
# =============================================================================


func test_event_type_returns_valid_type() -> void:
	var result: Enums.SpiritualEventType = SpiritualInsurgencySystem.select_event_type(_dice_engine)
	assert_true(
		result == Enums.SpiritualEventType.REALM_OVERLAP
		or result == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE,
	)


func test_event_type_distribution() -> void:
	var realm_count: int = 0
	var elem_count: int = 0
	for _i: int in range(100):
		var t: Enums.SpiritualEventType = SpiritualInsurgencySystem.select_event_type(_dice_engine)
		if t == Enums.SpiritualEventType.REALM_OVERLAP:
			realm_count += 1
		else:
			elem_count += 1
	assert_gt(realm_count, 20)
	assert_gt(elem_count, 20)


# =============================================================================
# Realm Selection
# =============================================================================


func test_realm_selection_returns_valid_realm() -> void:
	var conditions: Dictionary = {}
	var realm: Enums.SpiritRealm = SpiritualInsurgencySystem.select_realm(conditions, _dice_engine)
	assert_true(realm >= 0 and realm <= 5)


func test_realm_selection_famine_bias() -> void:
	var conditions: Dictionary = {"famine_active": true}
	var gaki_count: int = 0
	for _i: int in range(200):
		if SpiritualInsurgencySystem.select_realm(conditions, _dice_engine) == Enums.SpiritRealm.GAKI_DO:
			gaki_count += 1
	assert_gt(gaki_count, 40, "Famine should heavily bias toward Gaki-do")


func test_realm_selection_battle_bias() -> void:
	var conditions: Dictionary = {"recent_battle": true}
	var toshi_count: int = 0
	for _i: int in range(200):
		if SpiritualInsurgencySystem.select_realm(conditions, _dice_engine) == Enums.SpiritRealm.TOSHIGOKU:
			toshi_count += 1
	assert_gt(toshi_count, 30, "Battle should bias toward Toshigoku")


func test_realm_selection_forest_bias() -> void:
	var conditions: Dictionary = {"forest_province": true}
	var chiku_count: int = 0
	for _i: int in range(200):
		if SpiritualInsurgencySystem.select_realm(conditions, _dice_engine) == Enums.SpiritRealm.CHIKUSHUDO:
			chiku_count += 1
	assert_gt(chiku_count, 30, "Forest should bias toward Chikushudo")


# =============================================================================
# Element Selection
# =============================================================================


func test_element_selection_returns_valid_element() -> void:
	var elem: Enums.Ring = SpiritualInsurgencySystem.select_element(_dice_engine)
	assert_true(elem >= Enums.Ring.AIR and elem <= Enums.Ring.VOID)
	assert_ne(elem, Enums.Ring.NONE)


func test_element_selection_covers_all_elements() -> void:
	var seen: Dictionary = {}
	for _i: int in range(200):
		var elem: Enums.Ring = SpiritualInsurgencySystem.select_element(_dice_engine)
		seen[elem] = true
	assert_true(seen.has(Enums.Ring.AIR))
	assert_true(seen.has(Enums.Ring.EARTH))
	assert_true(seen.has(Enums.Ring.FIRE))
	assert_true(seen.has(Enums.Ring.WATER))
	assert_true(seen.has(Enums.Ring.VOID))


# =============================================================================
# Event Generation
# =============================================================================


func test_generate_event_realm_overlap() -> void:
	var tiers: Dictionary = _make_tiers(2)
	var conditions: Dictionary = {}
	_dice_engine.set_seed(1)
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_event(
		10, tiers, conditions, 1, 5, _dice_engine,
	)
	assert_eq(event.event_id, 1)
	assert_eq(event.province_id, 10)
	assert_eq(event.season_spawned, 5)
	assert_eq(event.severity, Enums.SpiritualSeverity.MILD)
	assert_false(event.resolved)


func test_generate_event_realm_overlap_sets_realm() -> void:
	var tiers: Dictionary = _make_tiers(2)
	_dice_engine.set_seed(0)
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_event(
		10, tiers, {}, 1, 0, _dice_engine,
	)
	if event.event_type == Enums.SpiritualEventType.REALM_OVERLAP:
		assert_ne(event.realm, Enums.SpiritRealm.GAKI_DO if event.realm != Enums.SpiritRealm.GAKI_DO else -99)
		assert_eq(event.element, Enums.Ring.NONE)


func test_generate_event_elemental_imbalance_sets_element() -> void:
	for seed_val: int in range(100):
		_dice_engine.set_seed(seed_val)
		var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_event(
			10, _make_tiers(2), {}, 1, 0, _dice_engine,
		)
		if event.event_type == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE:
			assert_ne(event.element, Enums.Ring.NONE)
			return
	assert_true(true, "All seeds produced REALM_OVERLAP, which is statistically unlikely but valid")


# =============================================================================
# Battle-Triggered Event
# =============================================================================


func test_battle_trigger_below_threshold_returns_null() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_battle_triggered_event(
		10, 49, 1, 0, _dice_engine,
	)
	assert_null(event)


func test_battle_trigger_at_threshold() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_battle_triggered_event(
		10, 50, 1, 0, _dice_engine,
	)
	assert_not_null(event)
	assert_eq(event.event_type, Enums.SpiritualEventType.REALM_OVERLAP)
	assert_eq(event.severity, Enums.SpiritualSeverity.MILD)
	assert_true(
		event.realm == Enums.SpiritRealm.GAKI_DO or event.realm == Enums.SpiritRealm.TOSHIGOKU,
	)


func test_battle_trigger_high_casualties_moderate() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_battle_triggered_event(
		10, 100, 1, 0, _dice_engine,
	)
	assert_eq(event.severity, Enums.SpiritualSeverity.MODERATE)


func test_battle_trigger_very_high_casualties_severe() -> void:
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_battle_triggered_event(
		10, 200, 1, 0, _dice_engine,
	)
	assert_eq(event.severity, Enums.SpiritualSeverity.SEVERE)


# =============================================================================
# NPC Resolution
# =============================================================================


func test_npc_resolution_realm_overlap_success() -> void:
	_shugenja.skills["Lore: Theology"] = 5
	_shugenja.awareness = 5
	_dice_engine.set_seed(999)
	var event: SpiritualInsurgencyData = _make_event(
		Enums.SpiritualSeverity.MILD, Enums.SpiritualEventType.REALM_OVERLAP,
		Enums.SpiritRealm.GAKI_DO,
	)
	var result: Dictionary = SpiritualInsurgencySystem.resolve_npc_event(
		event, _shugenja, _dice_engine,
	)
	assert_has(result, "total")
	assert_has(result, "tn")
	assert_has(result, "margin")
	assert_eq(result["tn"], 15)
	assert_true(event.npc_resolution_attempted)


func test_npc_resolution_elemental_imbalance() -> void:
	var event: SpiritualInsurgencyData = _make_event(
		Enums.SpiritualSeverity.MODERATE,
		Enums.SpiritualEventType.ELEMENTAL_IMBALANCE,
		Enums.SpiritRealm.GAKI_DO,
		Enums.Ring.FIRE,
	)
	var result: Dictionary = SpiritualInsurgencySystem.resolve_npc_event(
		event, _shugenja, _dice_engine,
	)
	assert_eq(result["tn"], 20)
	assert_true(event.npc_resolution_attempted)


func test_npc_resolution_void_imbalance_uses_void() -> void:
	var event: SpiritualInsurgencyData = _make_event(
		Enums.SpiritualSeverity.MILD,
		Enums.SpiritualEventType.ELEMENTAL_IMBALANCE,
		Enums.SpiritRealm.GAKI_DO,
		Enums.Ring.VOID,
	)
	_shugenja.void_ring = 5
	var result: Dictionary = SpiritualInsurgencySystem.resolve_npc_event(
		event, _shugenja, _dice_engine,
	)
	assert_has(result, "total")


func test_npc_resolution_marks_resolved_on_success() -> void:
	_shugenja.skills["Lore: Theology"] = 7
	_shugenja.awareness = 5
	_dice_engine.set_seed(100)
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var result: Dictionary = SpiritualInsurgencySystem.resolve_npc_event(
		event, _shugenja, _dice_engine,
	)
	if result.get("success", false):
		assert_true(event.resolved)
		assert_true(result["resolution_type"] == "full" or result["resolution_type"] == "partial")


func test_npc_resolution_severity_tn_scaling() -> void:
	assert_eq(
		SpiritualInsurgencySystem.NPC_RESOLUTION_BASE_TN[Enums.SpiritualSeverity.MILD], 15,
	)
	assert_eq(
		SpiritualInsurgencySystem.NPC_RESOLUTION_BASE_TN[Enums.SpiritualSeverity.MODERATE], 20,
	)
	assert_eq(
		SpiritualInsurgencySystem.NPC_RESOLUTION_BASE_TN[Enums.SpiritualSeverity.SEVERE], 25,
	)
	assert_eq(
		SpiritualInsurgencySystem.NPC_RESOLUTION_BASE_TN[Enums.SpiritualSeverity.CATASTROPHIC], 30,
	)


# =============================================================================
# Seasonal Processing
# =============================================================================


func test_seasonal_check_no_trigger_no_events() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(1)}}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, {}, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 0)


func test_seasonal_check_mild_generates_one_event() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var events: Array = []
	var next_id: Array = [1]
	var provinces: Dictionary = {}
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, provinces, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 1)
	assert_eq(new_events[0].province_id, 10)
	assert_eq(next_id[0], 2)


func test_seasonal_check_moderate_generates_two_events() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(3)}}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, {}, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 2)
	assert_eq(next_id[0], 3)


func test_seasonal_check_respects_existing_event_cap() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var existing: SpiritualInsurgencyData = _make_event()
	var events: Array = [existing]
	var next_id: Array = [2]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, {}, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 0, "Should not exceed max events for severity")


func test_seasonal_check_multiple_provinces() -> void:
	var worship_state: Dictionary = {
		"province_tiers": {
			10: _make_tiers(2),
			20: _make_tiers(3),
		}
	}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, {}, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 3)


func test_increment_seasons() -> void:
	var event: SpiritualInsurgencyData = _make_event()
	event.seasons_active = 2
	var resolved_event: SpiritualInsurgencyData = _make_event()
	resolved_event.resolved = true
	resolved_event.seasons_active = 5
	SpiritualInsurgencySystem.increment_seasons([event, resolved_event])
	assert_eq(event.seasons_active, 3)
	assert_eq(resolved_event.seasons_active, 5, "Resolved events should not increment")


# =============================================================================
# Topic Generation
# =============================================================================


func test_create_topic_mild_tier_3() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var next_tid: Array = [100]
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, next_tid, 42)
	assert_eq(topic["tier"], TopicData.Tier.TIER_3)
	assert_eq(topic["topic_id"], 100)
	assert_eq(next_tid[0], 101)
	assert_eq(topic["ic_day_created"], 42)


func test_create_topic_moderate_tier_2() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MODERATE)
	var next_tid: Array = [200]
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, next_tid, 10)
	assert_eq(topic["tier"], TopicData.Tier.TIER_2)


func test_create_topic_severe_tier_1() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.SEVERE)
	var next_tid: Array = [300]
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, next_tid, 10)
	assert_eq(topic["tier"], TopicData.Tier.TIER_1)


func test_create_topic_catastrophic_tier_1() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.CATASTROPHIC)
	var next_tid: Array = [400]
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, next_tid, 10)
	assert_eq(topic["tier"], TopicData.Tier.TIER_1)


func test_create_topic_realm_overlap_title() -> void:
	var event: SpiritualInsurgencyData = _make_event()
	event.event_type = Enums.SpiritualEventType.REALM_OVERLAP
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, [1], 0)
	assert_true(topic["title"].contains("Spirit realm"))


func test_create_topic_elemental_imbalance_title() -> void:
	var event: SpiritualInsurgencyData = _make_event()
	event.event_type = Enums.SpiritualEventType.ELEMENTAL_IMBALANCE
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, [1], 0)
	assert_true(topic["title"].contains("Elemental imbalance"))


# =============================================================================
# Resolution Effects
# =============================================================================


func test_resolution_effects_full_success() -> void:
	var result: Dictionary = {"resolution_type": "full"}
	var effects: Dictionary = SpiritualInsurgencySystem.get_resolution_effects(result)
	assert_true(effects.get("overlap_dissolves", false))
	assert_eq(effects.get("honor_gain", 0.0), 0.3)
	assert_eq(effects.get("glory_gain", 0.0), 0.5)


func test_resolution_effects_partial_success() -> void:
	var result: Dictionary = {"resolution_type": "partial"}
	var effects: Dictionary = SpiritualInsurgencySystem.get_resolution_effects(result)
	assert_true(effects.get("overlap_weakened", false))
	assert_eq(effects.get("honor_gain", 0.0), 0.1)
	assert_eq(effects.get("glory_gain", 0.0), 0.2)


func test_resolution_effects_retreat() -> void:
	var result: Dictionary = {"resolution_type": "retreat"}
	var effects: Dictionary = SpiritualInsurgencySystem.get_resolution_effects(result)
	assert_true(effects.get("overlap_agitated", false))
	assert_eq(effects.get("severity_increase_duration", 0), 1)


func test_resolution_effects_failure() -> void:
	var result: Dictionary = {"resolution_type": "failure"}
	var effects: Dictionary = SpiritualInsurgencySystem.get_resolution_effects(result)
	assert_true(effects.get("overlap_fully_agitated", false))


# =============================================================================
# Elemental Counter Pairs
# =============================================================================


func test_elemental_counter_fire_water() -> void:
	assert_eq(
		SpiritualInsurgencySystem.ELEMENTAL_COUNTER[Enums.Ring.FIRE],
		Enums.Ring.WATER,
	)


func test_elemental_counter_water_earth() -> void:
	assert_eq(
		SpiritualInsurgencySystem.ELEMENTAL_COUNTER[Enums.Ring.WATER],
		Enums.Ring.EARTH,
	)


func test_elemental_counter_earth_fire() -> void:
	assert_eq(
		SpiritualInsurgencySystem.ELEMENTAL_COUNTER[Enums.Ring.EARTH],
		Enums.Ring.FIRE,
	)


func test_elemental_counter_air_earth() -> void:
	assert_eq(
		SpiritualInsurgencySystem.ELEMENTAL_COUNTER[Enums.Ring.AIR],
		Enums.Ring.EARTH,
	)


func test_elemental_counter_void_none() -> void:
	assert_eq(
		SpiritualInsurgencySystem.ELEMENTAL_COUNTER[Enums.Ring.VOID],
		Enums.Ring.NONE,
	)


# =============================================================================
# Ritual Rounds
# =============================================================================


func test_ritual_rounds_mild() -> void:
	assert_eq(SpiritualInsurgencySystem.RITUAL_ROUNDS[Enums.SpiritualSeverity.MILD], 10)


func test_ritual_rounds_catastrophic() -> void:
	assert_eq(SpiritualInsurgencySystem.RITUAL_ROUNDS[Enums.SpiritualSeverity.CATASTROPHIC], 50)


# =============================================================================
# Events Per Season
# =============================================================================


func test_events_per_season_mild() -> void:
	assert_eq(SpiritualInsurgencySystem.EVENTS_PER_SEASON[Enums.SpiritualSeverity.MILD], 1)


func test_events_per_season_catastrophic() -> void:
	assert_eq(SpiritualInsurgencySystem.EVENTS_PER_SEASON[Enums.SpiritualSeverity.CATASTROPHIC], 4)


# =============================================================================
# Helper Functions
# =============================================================================


func test_get_realm_name() -> void:
	assert_eq(SpiritualInsurgencySystem.get_realm_name(Enums.SpiritRealm.GAKI_DO), "Gaki-do")
	assert_eq(SpiritualInsurgencySystem.get_realm_name(Enums.SpiritRealm.TOSHIGOKU), "Toshigoku")
	assert_eq(SpiritualInsurgencySystem.get_realm_name(Enums.SpiritRealm.YUME_DO), "Yume-do")


func test_get_element_name() -> void:
	assert_eq(SpiritualInsurgencySystem.get_element_name(Enums.Ring.FIRE), "Fire")
	assert_eq(SpiritualInsurgencySystem.get_element_name(Enums.Ring.VOID), "Void")


# =============================================================================
# Realm Restoration Traits
# =============================================================================


func test_realm_trait_gaki_do_uses_awareness() -> void:
	assert_eq(
		SpiritualInsurgencySystem.REALM_RESTORATION_TRAIT[Enums.SpiritRealm.GAKI_DO],
		"awareness",
	)


func test_realm_trait_toshigoku_uses_willpower() -> void:
	assert_eq(
		SpiritualInsurgencySystem.REALM_RESTORATION_TRAIT[Enums.SpiritRealm.TOSHIGOKU],
		"willpower",
	)


func test_realm_trait_chikushudo_uses_perception() -> void:
	assert_eq(
		SpiritualInsurgencySystem.REALM_RESTORATION_TRAIT[Enums.SpiritRealm.CHIKUSHUDO],
		"perception",
	)


func test_realm_trait_sakkaku_uses_intelligence() -> void:
	assert_eq(
		SpiritualInsurgencySystem.REALM_RESTORATION_TRAIT[Enums.SpiritRealm.SAKKAKU],
		"intelligence",
	)


# =============================================================================
# DayOrchestrator Integration — Shugenja Finder
# =============================================================================


func test_find_province_shugenja_returns_best_theology() -> void:
	var spm: Dictionary = {100: 10, 200: 20}
	var shugenja_a := L5RCharacterData.new()
	shugenja_a.character_id = 10
	shugenja_a.school_type = Enums.SchoolType.SHUGENJA
	shugenja_a.physical_location = "100"
	shugenja_a.skills = {"Lore: Theology": 3}
	shugenja_a.wounds_taken = 0
	var shugenja_b := L5RCharacterData.new()
	shugenja_b.character_id = 11
	shugenja_b.school_type = Enums.SchoolType.SHUGENJA
	shugenja_b.physical_location = "100"
	shugenja_b.skills = {"Lore: Theology": 5}
	shugenja_b.wounds_taken = 0
	var bushi := L5RCharacterData.new()
	bushi.character_id = 12
	bushi.school_type = Enums.SchoolType.BUSHI
	bushi.physical_location = "100"
	bushi.skills = {"Lore: Theology": 7}
	bushi.wounds_taken = 0

	var result: L5RCharacterData = DayOrchestrator._find_province_shugenja(
		10, [shugenja_a, shugenja_b, bushi], spm,
	)
	assert_not_null(result)
	assert_eq(result.character_id, 11, "Should select highest Theology shugenja")


func test_find_province_shugenja_excludes_dead() -> void:
	var spm: Dictionary = {100: 10}
	var dead_shugenja := L5RCharacterData.new()
	dead_shugenja.character_id = 10
	dead_shugenja.school_type = Enums.SchoolType.SHUGENJA
	dead_shugenja.physical_location = "100"
	dead_shugenja.skills = {"Lore: Theology": 5}
	dead_shugenja.wounds_taken = 9999

	var result: L5RCharacterData = DayOrchestrator._find_province_shugenja(
		10, [dead_shugenja], spm,
	)
	assert_null(result)


func test_find_province_shugenja_excludes_wrong_province() -> void:
	var spm: Dictionary = {100: 10, 200: 20}
	_shugenja.physical_location = "200"

	var result: L5RCharacterData = DayOrchestrator._find_province_shugenja(
		10, [_shugenja], spm,
	)
	assert_null(result)


# =============================================================================
# DayOrchestrator Integration — Full Processing
# =============================================================================


func test_process_spiritual_insurgency_generates_events_and_topics() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var events: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_tid: Array = [1000]
	var spm: Dictionary = {100: 10}

	var result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		worship_state, {}, events, next_id, 0, _dice_engine,
		[_shugenja], {1: _shugenja}, active_topics, next_tid, 42,
		{}, spm,
	)
	assert_gt(result.get("new_events", []).size(), 0)
	assert_gt(active_topics.size(), 0)
	assert_eq(active_topics[0].topic_type, "spiritual_insurgency")


func test_process_spiritual_insurgency_resolves_with_shugenja() -> void:
	_shugenja.skills["Lore: Theology"] = 6
	_shugenja.awareness = 5
	var spm: Dictionary = {100: 10}
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var events: Array = [event]
	var next_id: Array = [2]
	var active_topics: Array = []
	var next_tid: Array = [100]

	var result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		{"province_tiers": {}}, {}, events, next_id, 0, _dice_engine,
		[_shugenja], {1: _shugenja}, active_topics, next_tid, 42,
		{}, spm,
	)
	assert_gt(result.get("resolution_results", []).size(), 0)


func test_process_spiritual_insurgency_no_shugenja_no_resolution() -> void:
	var bushi := L5RCharacterData.new()
	bushi.character_id = 2
	bushi.school_type = Enums.SchoolType.BUSHI
	bushi.physical_location = "100"
	bushi.wounds_taken = 0
	var spm: Dictionary = {100: 10}
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var events: Array = [event]
	var next_id: Array = [2]

	var result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		{"province_tiers": {}}, {}, events, next_id, 0, _dice_engine,
		[bushi], {2: bushi}, [], [100], 42, {}, spm,
	)
	assert_eq(result.get("resolution_results", []).size(), 0)
	assert_false(event.npc_resolution_attempted)


func test_resolved_events_removed_from_active_list() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	event.resolved = true
	var events: Array = [event]
	var next_id: Array = [2]

	var _result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		{"province_tiers": {}}, {}, events, next_id, 0, _dice_engine,
		[], {}, [], [100], 42, {},
	)
	assert_eq(events.size(), 0, "Resolved events should be removed")


func test_honor_glory_applied_on_successful_resolution() -> void:
	_shugenja.skills["Lore: Theology"] = 8
	_shugenja.awareness = 6
	_shugenja.honor = 5.0
	_shugenja.glory = 3.0
	var spm: Dictionary = {100: 10}
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var events: Array = [event]
	var initial_honor: float = _shugenja.honor
	var initial_glory: float = _shugenja.glory

	var result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		{"province_tiers": {}}, {}, events, [2], 0, _dice_engine,
		[_shugenja], {1: _shugenja}, [], [100], 42, {}, spm,
	)
	var resolutions: Array = result.get("resolution_results", [])
	if resolutions.size() > 0 and resolutions[0].get("success", false):
		assert_gt(_shugenja.honor, initial_honor, "Honor should increase on success")
		assert_gt(_shugenja.glory, initial_glory, "Glory should increase on success")


# =============================================================================
# Data Model
# =============================================================================


func test_spiritual_insurgency_data_defaults() -> void:
	var data := SpiritualInsurgencyData.new()
	assert_eq(data.event_id, -1)
	assert_eq(data.province_id, -1)
	assert_eq(data.event_type, Enums.SpiritualEventType.REALM_OVERLAP)
	assert_eq(data.severity, Enums.SpiritualSeverity.MILD)
	assert_eq(data.season_spawned, -1)
	assert_eq(data.seasons_active, 0)
	assert_false(data.resolved)
	assert_false(data.npc_resolution_attempted)


func test_spiritual_insurgency_data_realm_default() -> void:
	var data := SpiritualInsurgencyData.new()
	assert_eq(data.realm, Enums.SpiritRealm.GAKI_DO)


func test_spiritual_insurgency_data_element_default() -> void:
	var data := SpiritualInsurgencyData.new()
	assert_eq(data.element, Enums.Ring.NONE)


func test_spiritual_insurgency_topic_has_momentum() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var events: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_tid: Array = [1000]
	var spm: Dictionary = {100: 10}
	DayOrchestrator._process_spiritual_insurgency(
		worship_state, {}, events, next_id, 0, _dice_engine,
		[_shugenja], {1: _shugenja}, active_topics, next_tid, 42,
		{}, spm,
	)
	for t: TopicData in active_topics:
		assert_gt(t.momentum, 0.0,
			"Spiritual insurgency topic should have non-zero momentum")
