extends GutTest
## Tests for FugitiveExtraditionSystem per GDD s11.3.16.


func _make_lord(
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 10
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.character_name = "Lord"
	c.disposition_values = {}
	return c


# -- Fugitive Visibility (s11.3.16a) ----

func test_high_status_generates_sighting_topic():
	assert_true(FugitiveExtraditionSystem.generates_sighting_topic(5.0))
	assert_true(FugitiveExtraditionSystem.generates_sighting_topic(3.0))


func test_low_status_no_sighting_topic():
	assert_false(FugitiveExtraditionSystem.generates_sighting_topic(2.0))
	assert_false(FugitiveExtraditionSystem.generates_sighting_topic(1.0))


func test_visibility_tier_scaling():
	assert_eq(FugitiveExtraditionSystem.get_visibility_tier(1.0), 1)
	assert_eq(FugitiveExtraditionSystem.get_visibility_tier(3.0), 2)
	assert_eq(FugitiveExtraditionSystem.get_visibility_tier(6.0), 3)


func test_concealment_tn_scales_with_status_and_glory():
	var low := FugitiveExtraditionSystem.get_concealment_tn(1.0, 1.0)
	var high := FugitiveExtraditionSystem.get_concealment_tn(5.0, 5.0)
	assert_lt(low, high)


# -- Extradition Request (s11.3.16b) ----

func test_extradition_request_format():
	var r := FugitiveExtraditionSystem.create_extradition_request(
		"Crane", "Scorpion", "Bayushi Toru", Enums.CrimeType.TREASON
	)
	assert_eq(r["requesting_clan"], "Crane")
	assert_eq(r["harboring_clan"], "Scorpion")
	assert_eq(r["topic_tier"], 4)
	assert_true(r["topic_title"].find("Crane") >= 0)
	assert_true(r["topic_title"].find("Bayushi Toru") >= 0)


# -- Harboring Lord Decision (s11.3.16c) ----

func test_gi_lord_cooperates_readily():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 3.0, 3, "none", "no_value"
	)
	assert_true(r["cooperates"])
	assert_eq(r["personality_score"], 30)


func test_seigyo_lord_resists():
	var lord := _make_lord(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 3.0, 3, "none", "no_value"
	)
	assert_eq(r["personality_score"], -20)


func test_valuable_fugitive_resists_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 3.0, 3, "valuable_intelligence", "bargaining_chip"
	)
	assert_eq(r["usefulness_score"], -25)
	assert_eq(r["leverage_score"], -20)
	assert_false(r["cooperates"])


func test_maho_crime_pushes_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 3.0, 1, "none", "no_value"
	)
	assert_eq(r["severity_score"], -30)


func test_high_status_fugitive_hard_to_hide():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 5.0, 3, "none", "no_value"
	)
	assert_eq(r["status_score"], -15)


func test_ji_samurai_easy_to_hide():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var r := FugitiveExtraditionSystem.evaluate_extradition(
		lord, "Crane", 1.0, 4, "none", "no_value"
	)
	assert_eq(r["status_score"], 0)


# -- Response Options (s11.3.16d) ----

func test_cooperation_returns_fugitive():
	var r := FugitiveExtraditionSystem.get_cooperation_consequences(3)
	assert_true(r["fugitive_returned"])
	assert_eq(r["disposition_gain"], 5)


func test_cooperation_higher_gain_for_serious_crime():
	var r := FugitiveExtraditionSystem.get_cooperation_consequences(2)
	assert_eq(r["disposition_gain"], 10)


func test_refusal_disposition_hit():
	var r := FugitiveExtraditionSystem.get_refusal_consequences(3)
	assert_eq(r["disposition_hit"], -10)
	assert_true(r["topic_escalates"])
	assert_eq(r["escalated_topic_tier"], 3)


func test_refusal_worse_for_serious_crime():
	var r := FugitiveExtraditionSystem.get_refusal_consequences(2)
	assert_eq(r["disposition_hit"], -20)


func test_deny_knowledge_viable_low_status():
	var r := FugitiveExtraditionSystem.get_deny_knowledge_consequences(2.0, false)
	assert_true(r["viable"])
	assert_false(r["fugitive_returned"])


func test_deny_knowledge_not_viable_high_status():
	var r := FugitiveExtraditionSystem.get_deny_knowledge_consequences(4.0, false)
	assert_true(r["denial_transparent"])
	assert_eq(r["additional_disposition_hit"], -5)


func test_deny_knowledge_not_viable_if_intel_exists():
	var r := FugitiveExtraditionSystem.get_deny_knowledge_consequences(2.0, true)
	assert_true(r["denial_transparent"])


func test_negotiate_demands_concession():
	var r := FugitiveExtraditionSystem.get_negotiate_consequences()
	assert_true(r["demands_concession"])
	assert_true(r["topic_remains_active"])


# -- Response Selection ----

func test_cooperating_lord_returns_fugitive():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	var eval_result := {"cooperates": true, "total_score": 25}
	var response := FugitiveExtraditionSystem.select_response(eval_result, lord, 3.0)
	assert_eq(response, FugitiveExtraditionSystem.ExtraditionResponse.COOPERATE)


func test_seigyo_prefers_negotiate():
	var lord := _make_lord(Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.SEIGYO)
	var eval_result := {"cooperates": false, "total_score": -10}
	var response := FugitiveExtraditionSystem.select_response(eval_result, lord, 3.0)
	assert_eq(response, FugitiveExtraditionSystem.ExtraditionResponse.NEGOTIATE)


func test_ishi_refuses_outright():
	var lord := _make_lord(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.ISHI)
	var eval_result := {"cooperates": false, "total_score": -25}
	var response := FugitiveExtraditionSystem.select_response(eval_result, lord, 4.0)
	assert_eq(response, FugitiveExtraditionSystem.ExtraditionResponse.REFUSE)


func test_low_status_fugitive_deny_knowledge():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var eval_result := {"cooperates": false, "total_score": -5}
	var response := FugitiveExtraditionSystem.select_response(eval_result, lord, 2.0)
	assert_eq(response, FugitiveExtraditionSystem.ExtraditionResponse.DENY_KNOWLEDGE)


# -- Escalation (s11.3.16e) ----

func test_imperial_warrant_available_for_serious_crimes():
	assert_true(FugitiveExtraditionSystem.can_request_imperial_warrant(1))
	assert_true(FugitiveExtraditionSystem.can_request_imperial_warrant(2))


func test_no_imperial_warrant_for_minor_crimes():
	assert_false(FugitiveExtraditionSystem.can_request_imperial_warrant(3))
	assert_false(FugitiveExtraditionSystem.can_request_imperial_warrant(4))


func test_gi_complies_with_imperial_warrant():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	var r := FugitiveExtraditionSystem.evaluate_imperial_warrant_compliance(lord)
	assert_true(r["complies"])


func test_seigyo_resists_imperial_warrant():
	# Use YU (not GI/CHUGI) so bushido doesn't force compliance before shourido check.
	var lord := _make_lord(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.SEIGYO)
	var r := FugitiveExtraditionSystem.evaluate_imperial_warrant_compliance(lord)
	assert_false(r["complies"])


func test_ishi_resists_imperial_warrant():
	var lord := _make_lord(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.ISHI)
	var r := FugitiveExtraditionSystem.evaluate_imperial_warrant_compliance(lord)
	assert_false(r["complies"])


func test_covert_extraction_risk():
	var r := FugitiveExtraditionSystem.get_covert_extraction_risk()
	assert_true(r["sovereignty_violation"])
	assert_eq(r["topic_tier_if_caught"], 3)


func test_standing_warrant_persists():
	var r := FugitiveExtraditionSystem.get_standing_warrant_consequences()
	assert_true(r["warrant_persists"])
	assert_true(r["arrest_on_return"])
