extends GutTest
## Tests for DayOrchestrator's Miya's Blessing follow-up step (s11.5b §7) —
## topic generation, disposition deltas, suspension counter, and
## suspension stability penalty. These exercise the helper functions
## directly via `_process_miya_blessing_followup`.


var _provinces: Dictionary
var _characters_by_id: Dictionary
var _active_topics: Array
var _next_topic_id: Array
var _season_meta: Dictionary


func before_each() -> void:
	_provinces = {}
	_characters_by_id = {}
	_active_topics = []
	_next_topic_id = [1000]
	_season_meta = {}


func _make_province(pid: int, clan: String, family: String, stability: float = 50.0) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.province_name = "Province %d" % pid
	p.clan = clan
	p.family = family
	p.stability = stability
	_provinces[pid] = p
	return p


func _make_char(cid: int, clan: String, family: String, status: float = 5.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = cid
	c.clan = clan
	c.family = family
	c.status = status
	_characters_by_id[cid] = c
	return c


# -- Success path: blessing fired -------------------------------------------

func test_fired_blessing_generates_topic_per_province() -> void:
	_make_province(1, "Lion", "Akodo")
	_make_province(2, "Crab", "Hida")
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {
				"fired": true,
				"selected_province_ids": [1, 2],
			},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_active_topics.size(), 2)
	for t: TopicData in _active_topics:
		assert_eq(t.topic_type, "miya_blessing")
		assert_eq(t.variant, "delivered")
		assert_eq(t.tier, TopicData.Tier.TIER_4)
		assert_eq(t.subject_role, "BENEFICIARY")


func test_fired_blessing_resets_suspension_counter() -> void:
	_make_province(1, "Lion", "Akodo")
	_season_meta["consecutive_blessing_suspensions"] = 4
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"fired": true, "selected_province_ids": [1]},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_season_meta["consecutive_blessing_suspensions"], 0)


func test_fired_blessing_disposition_deltas_applied() -> void:
	# Lion lord receives +2 toward Miya rep, +1 toward Emperor.
	_make_province(1, "Lion", "Akodo")
	var lord: L5RCharacterData = _make_char(11, "Lion", "Akodo", 7.0)
	_make_char(99, "Imperial", "Otomo")  # Emperor
	_make_char(50, "Imperial", "Miya")    # Miya rep
	var miya_inputs: Dictionary = {
		"emperor_id": 99,
		"miya_representative_id": 50,
	}
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"fired": true, "selected_province_ids": [1]},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, miya_inputs, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(lord.disposition_values[50], 2)
	assert_eq(lord.disposition_values[99], 1)


func test_fired_blessing_skips_disposition_when_ids_unset() -> void:
	# No Miya rep, no Emperor → no disposition deltas (defaults to -1).
	_make_province(1, "Lion", "Akodo")
	var lord: L5RCharacterData = _make_char(11, "Lion", "Akodo", 7.0)
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"fired": true, "selected_province_ids": [1]},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	# Nothing was changed in disposition_values for either id.
	assert_eq(lord.disposition_values, {})


# -- Suspension path --------------------------------------------------------

func test_suspended_blessing_increments_counter() -> void:
	_make_province(1, "Lion", "Akodo", 30.0)
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_season_meta["consecutive_blessing_suspensions"], 1)
	# Run again — counter ticks to 2.
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_season_meta["consecutive_blessing_suspensions"], 2)


func test_suspended_blessing_generates_tier4_topic_first_year() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_active_topics.size(), 1)
	assert_eq(_active_topics[0].tier, TopicData.Tier.TIER_4)


func test_suspended_3_consecutive_years_escalates_to_tier3() -> void:
	_season_meta["consecutive_blessing_suspensions"] = 2
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	# Counter reaches 3 → tier escalates.
	assert_eq(_active_topics.size(), 1)
	assert_eq(_active_topics[0].tier, TopicData.Tier.TIER_3)


func test_tyrant_suspension_topic_has_distinct_title() -> void:
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "tyrant_archetype"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_active_topics[0].title, "Miya's Blessing Denied by Imperial Order")


func test_suspension_applies_minus_1_stability_to_needy_provinces() -> void:
	_make_province(1, "Lion", "Akodo", 30.0)   # needy
	_make_province(2, "Crab", "Hida", 90.0)    # stable, no insurgency
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_provinces[1].stability, 29.0)
	assert_eq(_provinces[2].stability, 90.0)


func test_two_consecutive_suspensions_double_stability_penalty() -> void:
	_make_province(1, "Lion", "Akodo", 30.0)
	_season_meta["consecutive_blessing_suspensions"] = 1
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	# Counter reaches 2 → -2 stability instead of -1.
	assert_eq(_provinces[1].stability, 28.0)


func test_suspension_applies_miya_disposition_penalty_toward_emperor() -> void:
	var miya: L5RCharacterData = _make_char(50, "Imperial", "Miya")
	miya.lord_id = 99  # Not a champion — avoid clan champion penalty stacking.
	_make_char(99, "Imperial", "Otomo")  # Emperor
	var miya_inputs: Dictionary = {
		"emperor_id": 99,
		"miya_representative_id": 50,
	}
	var seasonal_result: Dictionary = {
		"resource_tick": {
			"miya_blessing": {"suspended": true, "suspension_reason": "below_threshold"},
		},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, miya_inputs, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(miya.disposition_values[99], -3)


# -- No-op cases -------------------------------------------------------------

func test_no_blessing_in_seasonal_result_is_noop() -> void:
	var seasonal_result: Dictionary = {"resource_tick": {}}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_active_topics.size(), 0)
	assert_false(_season_meta.has("consecutive_blessing_suspensions"))


func test_neither_fired_nor_suspended_is_noop() -> void:
	# Defensive — empty blessing dict (no fired/suspended flags) should not crash.
	var seasonal_result: Dictionary = {
		"resource_tick": {"miya_blessing": {}},
	}
	DayOrchestrator._process_miya_blessing_followup(
		seasonal_result, {}, _provinces, _characters_by_id,
		_active_topics, _next_topic_id, 100, _season_meta,
	)
	assert_eq(_active_topics.size(), 0)
