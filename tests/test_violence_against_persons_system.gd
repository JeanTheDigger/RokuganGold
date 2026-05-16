extends GutTest
## Tests for ViolenceAgainstPersonsSystem per GDD s11.3.12.


# -- Detection (s11.3.12b) ----

func test_always_detected():
	assert_true(ViolenceAgainstPersonsSystem.is_always_detected())


func test_detection_with_doshin():
	var r: Dictionary = ViolenceAgainstPersonsSystem.get_detection_result(true)
	assert_true(r["detected"])
	assert_true(r["doshin_response"])
	assert_true(r["zone_event_log_recorded"])


func test_detection_without_doshin():
	var r: Dictionary = ViolenceAgainstPersonsSystem.get_detection_result(false)
	assert_true(r["detected"])
	assert_false(r["doshin_response"])


# -- Status Modifier (s11.3.12c) ----

func test_status_upward():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_status_direction(2.0, 5.0),
		ViolenceAgainstPersonsSystem.StatusDirection.UPWARD
	)


func test_status_downward():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_status_direction(5.0, 2.0),
		ViolenceAgainstPersonsSystem.StatusDirection.DOWNWARD
	)


func test_status_equal():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_status_direction(3.0, 3.0),
		ViolenceAgainstPersonsSystem.StatusDirection.EQUAL
	)


func test_punishment_upward_is_long_arrest():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_base_punishment(
			ViolenceAgainstPersonsSystem.StatusDirection.UPWARD
		),
		ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_LONG
	)


func test_punishment_equal_is_short_arrest():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_base_punishment(
			ViolenceAgainstPersonsSystem.StatusDirection.EQUAL
		),
		ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_SHORT
	)


func test_punishment_downward_is_reprimand():
	assert_eq(
		ViolenceAgainstPersonsSystem.get_base_punishment(
			ViolenceAgainstPersonsSystem.StatusDirection.DOWNWARD
		),
		ViolenceAgainstPersonsSystem.PunishmentTier.REPRIMAND
	)


# -- Repeated Offenses (s11.3.12e) ----

func test_count_offenses_in_window():
	var offenses: Array[int] = [10, 11, 12, 5]
	assert_eq(ViolenceAgainstPersonsSystem.count_offenses_in_window(offenses, 14), 3)


func test_count_offenses_excludes_old():
	var offenses: Array[int] = [1, 2, 10, 11]
	assert_eq(ViolenceAgainstPersonsSystem.count_offenses_in_window(offenses, 14), 2)


func test_count_offenses_empty():
	var offenses: Array[int] = []
	assert_eq(ViolenceAgainstPersonsSystem.count_offenses_in_window(offenses, 14), 0)


func test_infamy_first_offense():
	assert_eq(ViolenceAgainstPersonsSystem.get_infamy_for_repeated(1), 0.0)


func test_infamy_second_offense():
	assert_almost_eq(ViolenceAgainstPersonsSystem.get_infamy_for_repeated(2), 0.1, 0.001)


func test_infamy_third_offense():
	assert_almost_eq(ViolenceAgainstPersonsSystem.get_infamy_for_repeated(3), 0.2, 0.001)


func test_topic_tier_first_offense():
	assert_eq(ViolenceAgainstPersonsSystem.get_topic_tier(1), 4)


func test_topic_tier_second_offense():
	assert_eq(ViolenceAgainstPersonsSystem.get_topic_tier(2), 4)


func test_topic_tier_third_offense_escalates():
	assert_eq(ViolenceAgainstPersonsSystem.get_topic_tier(3), 3)


func test_punishment_escalation_first():
	var base := ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_SHORT
	assert_eq(
		ViolenceAgainstPersonsSystem.get_punishment_escalation(base, 1),
		ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_SHORT
	)


func test_punishment_escalation_second():
	var base := ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_SHORT
	assert_eq(
		ViolenceAgainstPersonsSystem.get_punishment_escalation(base, 2),
		ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_LONG
	)


func test_punishment_escalation_capped():
	var base := ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_LONG
	assert_eq(
		ViolenceAgainstPersonsSystem.get_punishment_escalation(base, 5),
		ViolenceAgainstPersonsSystem.PunishmentTier.FORMAL_CENSURE
	)


# -- Duel Pretext (s11.3.12d) ----

func test_generates_duel_pretext():
	assert_true(ViolenceAgainstPersonsSystem.generates_duel_pretext())


func test_provocation_result():
	var r: Dictionary = ViolenceAgainstPersonsSystem.get_provocation_result(101, 202)
	assert_true(r["provocation_flag"])
	assert_eq(r["provoked_character_id"], 202)
	assert_eq(r["provoking_character_id"], 101)
	assert_true(r["duel_challenge_permitted"])


# -- Cross-Clan (s11.3.12c) ----

func test_same_clan_not_cross():
	assert_false(ViolenceAgainstPersonsSystem.is_cross_clan(1, 1))


func test_different_clan_is_cross():
	assert_true(ViolenceAgainstPersonsSystem.is_cross_clan(1, 2))


func test_jurisdiction_same_clan():
	var j: Dictionary = ViolenceAgainstPersonsSystem.get_jurisdiction(1, 1)
	assert_eq(j["primary_jurisdiction"], 1)
	assert_false(j["cross_clan"])
	assert_false(j["emerald_escalation_possible"])


func test_jurisdiction_cross_clan():
	var j: Dictionary = ViolenceAgainstPersonsSystem.get_jurisdiction(1, 2)
	assert_eq(j["primary_jurisdiction"], 2)
	assert_true(j["cross_clan"])
	assert_true(j["emerald_escalation_possible"])


# -- Conviction Consequences ----

func test_full_consequences_first_offense():
	var r: Dictionary = ViolenceAgainstPersonsSystem.get_conviction_consequences(
		ViolenceAgainstPersonsSystem.StatusDirection.EQUAL, 1, 5
	)
	assert_eq(r["honor_loss"], -0.2)
	assert_eq(r["glory_loss"], -0.1)
	assert_eq(r["infamy_gain"], 0.0)
	assert_eq(r["punishment_tier"], ViolenceAgainstPersonsSystem.PunishmentTier.HOUSE_ARREST_SHORT)
	assert_eq(r["topic_tier"], 4)
	assert_eq(r["property_damage_restitution"], 5)
	assert_true(r["duel_pretext_generated"])


func test_full_consequences_repeated_upward():
	var r: Dictionary = ViolenceAgainstPersonsSystem.get_conviction_consequences(
		ViolenceAgainstPersonsSystem.StatusDirection.UPWARD, 3, 10
	)
	assert_eq(r["punishment_tier"], ViolenceAgainstPersonsSystem.PunishmentTier.FORMAL_CENSURE)
	assert_eq(r["topic_tier"], 3)
	assert_almost_eq(r["infamy_gain"], 0.2, 0.001)


# -- Heimin Exception (s11.3.12) ----

func test_samurai_vs_samurai_actionable():
	assert_true(
		ViolenceAgainstPersonsSystem.is_legally_actionable(true, true, false)
	)


func test_samurai_vs_heimin_ignored():
	assert_false(
		ViolenceAgainstPersonsSystem.is_legally_actionable(true, false, false)
	)


func test_samurai_vs_heimin_disrupts_productivity():
	assert_true(
		ViolenceAgainstPersonsSystem.is_legally_actionable(true, false, true)
	)


func test_heimin_vs_samurai_not_actionable():
	assert_false(
		ViolenceAgainstPersonsSystem.is_legally_actionable(false, true, false)
	)
