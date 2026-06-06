extends GutTest
## Tests for InsurgencyRelocationSystem (s56.13 --- LOCKED).

func _make_insurgency(strength: int = 5) -> InsurgencyData:
	var ins := InsurgencyData.new()
	ins.insurgency_id = 1
	ins.strength = strength
	ins.missions_conducted = 0
	ins.relocation_delay_remaining = 0
	ins.template_type = ""
	return ins

# -- triggers_relocation -------------------------------------------------------

func test_full_success_triggers_relocation() -> void:
	assert_true(
		InsurgencyRelocationSystem.triggers_relocation(
			InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS))

func test_partial_success_triggers_relocation() -> void:
	assert_true(
		InsurgencyRelocationSystem.triggers_relocation(
			InsurgencyRelocationSystem.MissionOutcome.PARTIAL_SUCCESS))

func test_retreat_inside_triggers_relocation() -> void:
	assert_true(
		InsurgencyRelocationSystem.triggers_relocation(
			InsurgencyRelocationSystem.MissionOutcome.RETREAT_INSIDE))

func test_retreat_outside_no_relocation() -> void:
	assert_false(
		InsurgencyRelocationSystem.triggers_relocation(
			InsurgencyRelocationSystem.MissionOutcome.RETREAT_OUTSIDE))

func test_failure_no_relocation() -> void:
	assert_false(
		InsurgencyRelocationSystem.triggers_relocation(
			InsurgencyRelocationSystem.MissionOutcome.FAILURE))

# -- province_has_ruin --------------------------------------------------------

func test_war_damage_tag_returns_true() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["war_damage"]))

func test_famine_tag_returns_true() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["famine"]))

func test_taint_corruption_tag_returns_true() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["taint_corruption"]))

func test_peasant_revolt_tag_returns_true() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["peasant_revolt"]))

func test_natural_decay_tag_returns_true() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["natural_decay"]))

func test_no_matching_tag_returns_false() -> void:
	assert_false(InsurgencyRelocationSystem.province_has_ruin(["prosperity", "trade_boom"]))

func test_empty_history_returns_false() -> void:
	assert_false(InsurgencyRelocationSystem.province_has_ruin([]))

func test_ruin_among_other_tags() -> void:
	assert_true(InsurgencyRelocationSystem.province_has_ruin(["prosperity", "war_damage", "growth"]))

# -- adjacent_relocation_chance (PROVISIONAL) ---------------------------------

func test_adjacent_relocation_chance_returns_zero() -> void:
	assert_eq(InsurgencyRelocationSystem.adjacent_relocation_chance(0), 0.0)
	assert_eq(InsurgencyRelocationSystem.adjacent_relocation_chance(5), 0.0)

# -- compute_rabble_attrition (PROVISIONAL) -----------------------------------

func test_rabble_attrition_returns_zero() -> void:
	assert_eq(InsurgencyRelocationSystem.compute_rabble_attrition(10, 50), 0)

# -- evaluate_relocation: no trigger ------------------------------------------

func test_no_trigger_returns_false() -> void:
	var ins := _make_insurgency(5)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FAILURE,
		2, "", true, [])
	assert_false(r["triggers"])

func test_no_trigger_preserves_strength() -> void:
	var ins := _make_insurgency(5)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FAILURE,
		2, "", true, [])
	assert_eq(r["strength_after"], 5)

# -- evaluate_relocation: trigger, survivors > 0 ------------------------------

func test_trigger_sets_triggers_true() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		3, "", true, [])
	assert_true(r["triggers"])

func test_trigger_survivors_strength() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		3, "", true, [])
	assert_eq(r["strength_after"], 5)

func test_trigger_kills_exceed_strength_floors_at_zero() -> void:
	var ins := _make_insurgency(3)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		10, "", true, [])
	assert_eq(r["strength_after"], 0)

func test_all_killed_returns_early_no_delay() -> void:
	var ins := _make_insurgency(3)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		10, "", true, [])
	assert_eq(r["delay_seasons"], 0)
	assert_false(r.get("triggers", false),
		"No survivors → relocation must NOT trigger")

# -- Stockade delay -----------------------------------------------------------

func test_stockade_template_same_province_adds_delay() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2,
		InsurgencyRelocationSystem.STOCKADE_TEMPLATE,
		true, [])
	assert_eq(r["delay_seasons"], InsurgencyRelocationSystem.STOCKADE_DELAY_SEASONS)

func test_stockade_template_adjacent_no_delay() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2,
		InsurgencyRelocationSystem.STOCKADE_TEMPLATE,
		false, [])
	assert_eq(r["delay_seasons"], 0)

func test_non_stockade_template_no_delay() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2, "BanditCampMapData", true, [])
	assert_eq(r["delay_seasons"], 0)

# -- Ruin template restriction ------------------------------------------------

func test_ruin_template_no_ruin_in_dest_restricted() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2,
		InsurgencyRelocationSystem.RUIN_TEMPLATE,
		false, ["prosperity"])
	assert_true(r["template_restricted"])

func test_ruin_template_ruin_in_dest_not_restricted() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2,
		InsurgencyRelocationSystem.RUIN_TEMPLATE,
		false, ["war_damage"])
	assert_false(r["template_restricted"])

func test_non_ruin_template_never_restricted() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2, "BanditCampMapData", false, ["prosperity"])
	assert_false(r["template_restricted"])

# -- Province reset -----------------------------------------------------------

func test_adjacent_province_sets_reset_province() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2, "", false, [])
	assert_true(r["reset_province"])

func test_same_province_no_reset() -> void:
	var ins := _make_insurgency(8)
	var r: Dictionary = InsurgencyRelocationSystem.evaluate_relocation(
		ins,
		InsurgencyRelocationSystem.MissionOutcome.FULL_SUCCESS,
		2, "", true, [])
	assert_false(r["reset_province"])

# -- apply_adjacent_effects ---------------------------------------------------

func test_adjacent_effects_transferred_strength() -> void:
	var ins := _make_insurgency(10)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 3, "Crane", "Lion", 50)
	assert_eq(r["strength_transferred"], 7)

func test_adjacent_effects_rabble_attrition_zero() -> void:
	var ins := _make_insurgency(10)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 3, "Crane", "Lion", 50)
	assert_eq(r["rabble_attrition"], 0)

func test_adjacent_effects_topic_category_political() -> void:
	var ins := _make_insurgency(10)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 3, "Crane", "Lion", 50)
	assert_eq(r["topic_category"], "POLITICAL")

func test_adjacent_effects_topic_tier_4() -> void:
	var ins := _make_insurgency(10)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 3, "Crane", "Lion", 50)
	# topic_tier = 3 maps to TopicData.Tier.TIER_4
	assert_eq(r["topic_tier"], 3)

func test_adjacent_effects_topic_subject_clan() -> void:
	var ins := _make_insurgency(5)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 1, "Crab", "Scorpion", 30)
	assert_eq(r["topic_subject_clan"], "Crab")

func test_adjacent_effects_topic_title_includes_clans() -> void:
	var ins := _make_insurgency(5)
	var r: Dictionary = InsurgencyRelocationSystem.apply_adjacent_effects(
		ins, 0, "Dragon", "Phoenix", 60)
	assert_string_contains(r["topic_title"], "Dragon")
	assert_string_contains(r["topic_title"], "Phoenix")

# -- apply_origin_recovery ----------------------------------------------------

func test_origin_recovery_removes_stability_penalty() -> void:
	var ins := _make_insurgency(5)
	var r: Dictionary = InsurgencyRelocationSystem.apply_origin_recovery(ins)
	assert_true(r["insurgency_stability_penalty_removed"])
