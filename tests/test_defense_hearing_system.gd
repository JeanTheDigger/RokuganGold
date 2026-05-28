extends GutTest
## Tests for DefenseHearingSystem per GDD s11.3.8c and s11.3.9f.


func _make_character(
	school: Enums.SchoolType = Enums.SchoolType.BUSHI,
	bushido: Enums.BushidoVirtue = Enums.BushidoVirtue.GI,
	status: float = 3.0,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.school_type = school
	c.bushido_virtue = bushido
	c.status = status
	c.character_name = "TestChar"
	return c


# -- Trial by Combat Eligibility (s11.3.9f) ----

func test_can_demand_trial():
	var c := _make_character()
	assert_true(DefenseHearingSystem.can_demand_trial_by_combat(
		c, Enums.CrimeType.VIOLENCE
	))


func test_cannot_demand_trial_maho():
	var c := _make_character()
	assert_false(DefenseHearingSystem.can_demand_trial_by_combat(
		c, Enums.CrimeType.MAHO
	))


# -- Trial by Combat Outcomes ----

func test_accused_wins():
	var r: Dictionary = DefenseHearingSystem.get_trial_by_combat_result(
		DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_WINS, 3.0
	)
	assert_true(r["case_cleared"])
	assert_true(r["evidence_wiped"])
	assert_true(r["no_re_accusation"])
	assert_true(r["divine_judgment"])
	assert_eq(r["victim_clan_disposition_hit"], -10)


func test_accused_wins_high_status_victim():
	var r: Dictionary = DefenseHearingSystem.get_trial_by_combat_result(
		DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_WINS, 6.0
	)
	assert_eq(r["victim_clan_disposition_hit"], -30)


func test_accused_loses():
	var r: Dictionary = DefenseHearingSystem.get_trial_by_combat_result(
		DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_LOSES, 3.0
	)
	assert_true(r["case_cleared"])
	assert_true(r["accused_dead"])
	assert_true(r["divine_judgment"])


func test_accuser_declines():
	var r: Dictionary = DefenseHearingSystem.get_trial_by_combat_result(
		DefenseHearingSystem.TrialByCombatOutcome.ACCUSER_DECLINES, 3.0
	)
	assert_true(r["case_cleared"])
	assert_true(r["evidence_wiped"])
	assert_true(r["accuser_implicit_agreement"])


# -- Political Intervention ----

func test_higher_status_can_intervene():
	assert_true(DefenseHearingSystem.can_intervene(6.0, 4.0))


func test_equal_status_cannot_intervene():
	assert_false(DefenseHearingSystem.can_intervene(4.0, 4.0))


func test_lower_status_cannot_intervene():
	assert_false(DefenseHearingSystem.can_intervene(3.0, 5.0))


func test_pardon_cost():
	var r: Dictionary = DefenseHearingSystem.get_intervention_cost(
		DefenseHearingSystem.InterventionType.PARDON
	)
	assert_eq(r["honor_cost"], -0.3)
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_3)
	assert_true(r["undermines_authority"])


func test_commute_cost():
	var r: Dictionary = DefenseHearingSystem.get_intervention_cost(
		DefenseHearingSystem.InterventionType.COMMUTE
	)
	assert_eq(r["honor_cost"], -0.1)
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_4)
	assert_false(r["undermines_authority"])


func test_dismiss_cost():
	var r: Dictionary = DefenseHearingSystem.get_intervention_cost(
		DefenseHearingSystem.InterventionType.DISMISS_CHARGES
	)
	assert_eq(r["honor_cost"], -0.5)
	assert_eq(r["topic_tier"], TopicData.Tier.TIER_2)
	assert_true(r["undermines_authority"])


# -- Re-Accusation Protection (s11.3.8c) ----

func test_can_re_accuse_with_new_evidence():
	assert_true(DefenseHearingSystem.can_re_accuse(20))


func test_cannot_re_accuse_insufficient():
	assert_false(DefenseHearingSystem.can_re_accuse(19))


func test_false_persecution_cost():
	var r: Dictionary = DefenseHearingSystem.get_false_persecution_cost()
	assert_eq(r["lord_honor_loss"], -0.3)
	assert_eq(r["vassal_disposition_loss_from_all"], -10)


# -- Sincerity Defense (s11.3.8c) ----

func test_defense_succeeds():
	var r: Dictionary = DefenseHearingSystem.resolve_sincerity_defense(20, 25, 40)
	assert_true(r["defense_succeeded"])
	assert_eq(r["evidence_halved_to"], 20)
	assert_true(r["political_shield_active"])


func test_defense_fails():
	var r: Dictionary = DefenseHearingSystem.resolve_sincerity_defense(10, 15, 40)
	assert_false(r["defense_succeeded"])
	assert_true(r["proceed_to_judgment"])


func test_defense_exact_tie_succeeds():
	var r: Dictionary = DefenseHearingSystem.resolve_sincerity_defense(15, 25, 40)
	assert_true(r["defense_succeeded"])


# -- NPC Trial Demand Decision ----

func test_bushi_demands_when_evidence_strong():
	var c := _make_character(Enums.SchoolType.BUSHI)
	assert_true(DefenseHearingSystem.should_demand_trial(c, 15, 40))


func test_bushi_does_not_demand_when_testimony_strong():
	var c := _make_character(Enums.SchoolType.BUSHI)
	assert_false(DefenseHearingSystem.should_demand_trial(c, 40, 35))


func test_courtier_yu_demands_trial():
	var c := _make_character(Enums.SchoolType.COURTIER, Enums.BushidoVirtue.YU)
	assert_true(DefenseHearingSystem.should_demand_trial(c, 10, 40))


func test_courtier_gi_does_not_demand():
	var c := _make_character(Enums.SchoolType.COURTIER, Enums.BushidoVirtue.GI)
	assert_false(DefenseHearingSystem.should_demand_trial(c, 10, 40))
