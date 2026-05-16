extends GutTest
## Tests for UnsanctionedKillingSystem per GDD s11.3.9.


# -- Classification (s11.3.9a/b) ----

func test_tier_1_unsanctioned_duel():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH, 3.0, 3.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH)
	assert_false(result["status_escalated"])


func test_tier_2_open_killing():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 3.0, 3.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.OPEN_KILLING)


func test_tier_3_covert_killing():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 3.0, 3.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.COVERT_KILLING)


func test_killing_upward_escalates_tier_1_to_2():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH, 2.0, 5.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.OPEN_KILLING)
	assert_true(result["status_escalated"])
	assert_true(result["killing_upward"])


func test_killing_upward_escalates_tier_2_to_3():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 2.0, 5.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.COVERT_KILLING)
	assert_true(result["status_escalated"])


func test_tier_3_cannot_escalate_further():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 2.0, 5.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.COVERT_KILLING)
	assert_false(result["status_escalated"])


func test_killing_downward_no_escalation():
	var result := UnsanctionedKillingSystem.classify_killing(
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH, 5.0, 2.0)
	assert_eq(result["effective_tier"], UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH)
	assert_true(result["killing_downward"])


# -- Consequences (s11.3.9g) ----

func test_tier_1_consequences():
	var result := UnsanctionedKillingSystem.get_consequences(
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH, 3.0, true)
	assert_almost_eq(result["honor_loss"], -0.3, 0.01)
	assert_almost_eq(result["glory_loss"], 0.0, 0.01)
	assert_almost_eq(result["infamy_gain"], 0.0, 0.01)
	assert_eq(result["topic_tier"], 4)
	assert_false(result["seppuku_offered"])


func test_tier_2_consequences_public():
	var result := UnsanctionedKillingSystem.get_consequences(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 3.0, true)
	assert_almost_eq(result["honor_loss"], -1.0, 0.01)
	assert_almost_eq(result["glory_loss"], -0.5, 0.01)
	assert_almost_eq(result["infamy_gain"], 1.0, 0.01)
	assert_eq(result["topic_tier"], 3)
	assert_true(result["seppuku_offered"])
	assert_true(result["leniency_possible"])


func test_tier_2_no_infamy_if_not_public():
	var result := UnsanctionedKillingSystem.get_consequences(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 3.0, false)
	assert_almost_eq(result["infamy_gain"], 0.0, 0.01)


func test_tier_3_consequences():
	var result := UnsanctionedKillingSystem.get_consequences(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 3.0, false)
	assert_almost_eq(result["honor_loss"], -2.0, 0.01)
	assert_almost_eq(result["glory_loss"], -1.0, 0.01)
	assert_almost_eq(result["infamy_gain"], 1.0, 0.01)
	assert_true(result["capital"])
	assert_false(result["leniency_possible"])


func test_tier_3_high_status_victim_tier_2_topic():
	var result := UnsanctionedKillingSystem.get_consequences(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 6.0, false)
	assert_eq(result["topic_tier"], 2)


# -- Punishment Ranges ----

func test_tier_1_punishment_range():
	var result := UnsanctionedKillingSystem.get_punishment_range(
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH)
	assert_eq(result["min"], "house_arrest")
	assert_false(result["seppuku"])


func test_tier_2_punishment_range():
	var result := UnsanctionedKillingSystem.get_punishment_range(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING)
	assert_true(result["seppuku"])
	assert_true(result["exile_possible"])


func test_tier_3_punishment_range():
	var result := UnsanctionedKillingSystem.get_punishment_range(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING)
	assert_true(result["seppuku"])
	assert_false(result["exile_possible"])


# -- Self-Defense (s11.3.9j) ----

func test_self_defense_proved_by_zone_log():
	var result := UnsanctionedKillingSystem.is_self_defense(true, false, true)
	assert_true(result["self_defense_proved"])
	assert_true(result["no_crime"])
	assert_eq(result["evidence_source"], "zone_event_log")


func test_self_defense_proved_by_witnesses():
	var result := UnsanctionedKillingSystem.is_self_defense(true, true, false)
	assert_true(result["self_defense_proved"])
	assert_eq(result["evidence_source"], "witness_testimony")


func test_self_defense_not_proved_without_evidence():
	var result := UnsanctionedKillingSystem.is_self_defense(true, false, false)
	assert_false(result["self_defense_proved"])


func test_defender_acted_first_not_self_defense():
	var result := UnsanctionedKillingSystem.is_self_defense(false, true, true)
	assert_false(result["self_defense_proved"])


# -- Wartime Exception (s11.3.9h) ----

func test_battlefield_killing_no_crime():
	var result := UnsanctionedKillingSystem.is_wartime_exception(true, true, false)
	assert_true(result["exception_applies"])
	assert_true(result["no_crime"])


func test_prisoner_killing_no_crime_but_honor_loss():
	var result := UnsanctionedKillingSystem.is_wartime_exception(true, false, true)
	assert_true(result["exception_applies"])
	assert_true(result["no_crime"])
	assert_almost_eq(result["honor_loss"], -0.5, 0.01)


func test_not_at_war_no_exception():
	var result := UnsanctionedKillingSystem.is_wartime_exception(false, true, false)
	assert_false(result["exception_applies"])


func test_wartime_standing_permission():
	var result := UnsanctionedKillingSystem.is_wartime_exception(true, false, false)
	assert_true(result["exception_applies"])
	assert_true(result["no_crime"])


# -- Trial by Combat (s11.3.9f) ----

func test_accused_wins_trial_cleared():
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS, 3.0)
	assert_true(result["case_cleared"])
	assert_true(result["accused_alive"])
	assert_true(result["evidence_wiped"])
	assert_true(result["cannot_reaccuse_same_evidence"])


func test_accused_wins_low_status_victim_small_disposition_hit():
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS, 2.0)
	assert_eq(result["disposition_hit_from_victim_clan"], -10)


func test_accused_wins_mid_status_victim_medium_disposition_hit():
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS, 4.0)
	assert_eq(result["disposition_hit_from_victim_clan"], -20)


func test_accused_wins_high_status_victim_large_disposition_hit():
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS, 6.0)
	assert_eq(result["disposition_hit_from_victim_clan"], -30)


func test_accused_loses_trial_dead():
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		UnsanctionedKillingSystem.TrialOutcome.ACCUSED_LOSES, 3.0)
	assert_true(result["case_cleared"])
	assert_false(result["accused_alive"])
	assert_true(result["divine_judgment"])


# -- Attempted Murder (s11.3.9n) ----

func test_attempted_open_killing():
	var result := UnsanctionedKillingSystem.evaluate_attempted_murder(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 3.0, 3.0)
	assert_almost_eq(result["honor_loss"], -1.0, 0.01)
	assert_eq(result["standard_punishment"], "exile")
	assert_false(result["escalated_by_status"])


func test_attempted_covert_killing():
	var result := UnsanctionedKillingSystem.evaluate_attempted_murder(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 3.0, 3.0)
	assert_almost_eq(result["honor_loss"], -2.0, 0.01)


func test_attempted_murder_upward_escalates_to_capital():
	var result := UnsanctionedKillingSystem.evaluate_attempted_murder(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 2.0, 5.0)
	assert_eq(result["standard_punishment"], "capital")
	assert_true(result["escalated_by_status"])


# -- Ronin Killing (s11.3.9k) ----

func test_ronin_killing_unprosecutable_without_patron():
	assert_false(UnsanctionedKillingSystem.is_ronin_killing_prosecutable(false, false))


func test_ronin_killing_prosecutable_with_patron():
	assert_true(UnsanctionedKillingSystem.is_ronin_killing_prosecutable(true, false))


func test_ronin_killing_prosecutable_with_friends():
	assert_true(UnsanctionedKillingSystem.is_ronin_killing_prosecutable(false, true))


# -- Conspiracy (s11.3.9l) ----

func test_conspiracy_same_tier_as_method():
	var result := UnsanctionedKillingSystem.evaluate_conspiracy(
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING, 4.0, 3.0)
	assert_true(result["is_conspiracy"])
	assert_true(result["same_tier_as_executioner"])
	assert_almost_eq(result["honor_loss"], -2.0, 0.01)


func test_conspiracy_upward_escalates():
	var result := UnsanctionedKillingSystem.evaluate_conspiracy(
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING, 2.0, 5.0)
	# Open killing upward → escalated to covert killing tier
	assert_almost_eq(result["honor_loss"], -2.0, 0.01)


# -- Manslaughter (s11.3.9m) ----

func test_manslaughter_no_crime():
	var result := UnsanctionedKillingSystem.is_manslaughter(true)
	assert_true(result["no_crime"])
	assert_false(result["legal_status_progression"])
	assert_true(result["disposition_hit_applies"])


func test_not_manslaughter():
	var result := UnsanctionedKillingSystem.is_manslaughter(false)
	assert_false(result["no_crime"])


# -- Jurisdiction (s11.3.9d) ----

func test_same_clan_jurisdiction():
	var result := UnsanctionedKillingSystem.get_jurisdiction("Crane", "Crane")
	assert_eq(result["type"], "same_clan")
	assert_false(result["can_escalate_to_emerald"])


func test_cross_clan_jurisdiction():
	var result := UnsanctionedKillingSystem.get_jurisdiction("Scorpion", "Crane")
	assert_eq(result["type"], "cross_clan")
	assert_eq(result["investigating_clan"], "Crane")
	assert_eq(result["observer_clan"], "Scorpion")
	assert_true(result["can_escalate_to_emerald"])


# -- Cross-Clan Disposition (s11.3.9d) ----

func test_cooperation_halves_disposition_hit():
	var hit := UnsanctionedKillingSystem.get_cross_clan_disposition_hit(
		true, UnsanctionedKillingSystem.KillingTier.OPEN_KILLING)
	assert_eq(hit, -7)


func test_non_cooperation_full_disposition_hit():
	var hit := UnsanctionedKillingSystem.get_cross_clan_disposition_hit(
		false, UnsanctionedKillingSystem.KillingTier.OPEN_KILLING)
	assert_eq(hit, -15)


func test_covert_killing_largest_disposition_hit():
	var hit := UnsanctionedKillingSystem.get_cross_clan_disposition_hit(
		false, UnsanctionedKillingSystem.KillingTier.COVERT_KILLING)
	assert_eq(hit, -25)
