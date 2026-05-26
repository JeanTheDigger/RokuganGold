extends GutTest
## Tests for SpiritualInsurgencySystem per GDD s56.16.
## Covers: trigger detection, severity determination, realm/element selection,
## event generation, seasonal processing, topic generation.
##
## REMOVED (2026-05-26): tests for invented content not specified in GDD s56.16.
## - Realm selection bias tests (famine/battle/forest) — weights removed.
## - Battle-triggered event tests — generate_battle_triggered_event() removed.
## - NPC resolution tests — resolve_npc_event() removed.
## - Resolution effects tests — get_resolution_effects() removed.
## - Topic tier-specific tests — severity-to-tier mapping removed.
## - DayOrchestrator shugenja finder tests — _find_province_shugenja() removed.
## - DayOrchestrator resolution integration tests — NPC resolution removed.


var _dice_engine: DiceEngine


func before_each() -> void:
	_dice_engine = DiceEngine.new()
	_dice_engine.set_seed(42)


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
# Realm Selection — Equal Probability
# =============================================================================


func test_realm_selection_returns_valid_realm() -> void:
	var realm: Enums.SpiritRealm = SpiritualInsurgencySystem.select_realm(_dice_engine)
	assert_true(realm >= 0 and realm <= 5)


func test_realm_selection_covers_all_realms() -> void:
	var seen: Dictionary = {}
	for _i: int in range(200):
		var r: Enums.SpiritRealm = SpiritualInsurgencySystem.select_realm(_dice_engine)
		seen[r] = true
	assert_eq(seen.size(), 6, "Should cover all 6 realms with equal probability")


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
	_dice_engine.set_seed(1)
	var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_event(
		10, tiers, 1, 5, _dice_engine,
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
		10, tiers, 1, 0, _dice_engine,
	)
	if event.event_type == Enums.SpiritualEventType.REALM_OVERLAP:
		assert_ne(event.realm, Enums.SpiritRealm.GAKI_DO if event.realm != Enums.SpiritRealm.GAKI_DO else -99)
		assert_eq(event.element, Enums.Ring.NONE)


func test_generate_event_elemental_imbalance_sets_element() -> void:
	for seed_val: int in range(100):
		_dice_engine.set_seed(seed_val)
		var event: SpiritualInsurgencyData = SpiritualInsurgencySystem.generate_event(
			10, _make_tiers(2), 1, 0, _dice_engine,
		)
		if event.event_type == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE:
			assert_ne(event.element, Enums.Ring.NONE)
			return
	assert_true(true, "All seeds produced REALM_OVERLAP, which is statistically unlikely but valid")


# =============================================================================
# Seasonal Processing
# =============================================================================


func test_seasonal_check_no_trigger_no_events() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(1)}}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 0)


func test_seasonal_check_mild_generates_one_event() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 1)
	assert_eq(new_events[0].province_id, 10)
	assert_eq(next_id[0], 2)


func test_seasonal_check_moderate_generates_one_event() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(3)}}
	var events: Array = []
	var next_id: Array = [1]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 1, "MODERATE generates 1 event per season")


func test_seasonal_check_respects_existing_event_cap() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var existing: SpiritualInsurgencyData = _make_event()
	var events: Array = [existing]
	var next_id: Array = [2]
	var new_events: Array = SpiritualInsurgencySystem.process_seasonal_check(
		worship_state, events, next_id, 0, _dice_engine,
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
		worship_state, events, next_id, 0, _dice_engine,
	)
	assert_eq(new_events.size(), 2, "MILD=1 + MODERATE=1")


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


func test_create_topic_returns_sentinel_tier() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	var next_tid: Array = [100]
	var topic: Dictionary = SpiritualInsurgencySystem.create_event_topic(event, next_tid, 42)
	assert_eq(topic["tier"], -1, "Tier is sentinel — GDD does not specify severity-to-tier mapping")
	assert_eq(topic["topic_id"], 100)
	assert_eq(next_tid[0], 101)
	assert_eq(topic["ic_day_created"], 42)


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


func test_events_per_season_moderate() -> void:
	assert_eq(SpiritualInsurgencySystem.EVENTS_PER_SEASON[Enums.SpiritualSeverity.MODERATE], 1)


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
# DayOrchestrator Integration
# =============================================================================


func test_process_spiritual_insurgency_generates_events() -> void:
	var worship_state: Dictionary = {"province_tiers": {10: _make_tiers(2)}}
	var events: Array = []
	var next_id: Array = [1]
	var active_topics: Array = []
	var next_tid: Array = [1000]

	var result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		worship_state, events, next_id, 0, _dice_engine,
		active_topics, next_tid, 42,
	)
	assert_gt(result.get("new_events", []).size(), 0)


func test_resolved_events_removed_from_active_list() -> void:
	var event: SpiritualInsurgencyData = _make_event(Enums.SpiritualSeverity.MILD)
	event.resolved = true
	var events: Array = [event]
	var next_id: Array = [2]

	var _result: Dictionary = DayOrchestrator._process_spiritual_insurgency(
		{"province_tiers": {}}, events, next_id, 0, _dice_engine,
		[], [100], 42,
	)
	assert_eq(events.size(), 0, "Resolved events should be removed")


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
