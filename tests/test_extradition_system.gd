extends GutTest
## Tests for ExtraditionSystem per GDD s11.3.16.


func _make_lord(virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE, shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.bushido_virtue = virtue
	c.shourido_virtue = shourido
	return c


# -- Personality Base Tests ----

func test_gi_lord_strongly_cooperates():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], 30, "GI gives +30 cooperation")
	assert_true(result["cooperates"])
	assert_eq(result["response"], ExtraditionSystem.Response.COOPERATE)


func test_seigyo_lord_resists_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], -20, "SEIGYO gives -20 cooperation")
	assert_false(result["cooperates"])


func test_ishi_lord_resists():
	var lord := _make_lord(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], -15)
	assert_false(result["cooperates"])


# -- Disposition Factor Tests ----

func test_friend_disposition_boosts_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 50, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], 20, "YU(0) + Friend(+20) = 20")
	assert_true(result["cooperates"])


func test_rival_disposition_hurts_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, -30, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], -20, "YU(0) + Rival(-20) = -20")
	assert_false(result["cooperates"])


func test_neutral_disposition_no_effect():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 10, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], 0, "YU(0) + Neutral(0) = 0")


# -- Crime Severity Tests ----

func test_maho_tier_1_massive_pressure():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_1, false, false, false)
	assert_eq(result["cooperation_score"], -30, "Tier 1 crime = -30 pressure")


func test_minor_crime_no_severity_pressure():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], 0, "Tier 4 = no severity pressure")


# -- Fugitive Usefulness ----

func test_competent_fugitive_resists_handover():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, 4, true, false, false)
	assert_eq(result["cooperation_score"], -15, "Competent fugitive = -15")


func test_intelligence_fugitive_strongly_resists():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, 4, false, true, false)
	assert_eq(result["cooperation_score"], -25, "Intelligence fugitive = -25")


func test_intelligence_overrides_competent():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, 4, true, true, false)
	assert_eq(result["cooperation_score"], -25, "Intelligence (-25) overrides competent (-15)")


# -- Leverage ----

func test_leverage_resists_cooperation():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, 4, false, false, true)
	assert_eq(result["cooperation_score"], -20, "Leverage = -20")


# -- Status Visibility ----

func test_high_status_fugitive_hard_to_hide():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 6.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], -15, "Status 5+ = -15")


func test_mid_status_fugitive():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 4.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], -5, "Status 3-4 = -5")


func test_low_status_fugitive_invisible():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["cooperation_score"], 0, "Status 1-2 = 0")


# -- Response Determination ----

func test_seigyo_negotiates_when_refusing():
	var lord := _make_lord(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["response"], ExtraditionSystem.Response.NEGOTIATE)


func test_low_status_fugitive_gets_denied():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	var result := ExtraditionSystem.evaluate_extradition(lord, -20, 1.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["response"], ExtraditionSystem.Response.DENY_KNOWLEDGE,
		"Low-status fugitive with moderate refusal = deny knowledge")


func test_high_status_fugitive_gets_outright_refusal():
	var lord := _make_lord(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KYORYOKU)
	var result := ExtraditionSystem.evaluate_extradition(lord, -20, 6.0, TopicData.Tier.TIER_4, false, false, false)
	assert_eq(result["response"], ExtraditionSystem.Response.REFUSE,
		"High-status fugitive cannot be denied — lord must refuse openly")


# -- Combined Scenarios ----

func test_gi_lord_cooperates_despite_useful_fugitive():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	# GI(+30) + competent(-15) = +15
	var result := ExtraditionSystem.evaluate_extradition(lord, 0, 1.0, 4, true, false, false)
	assert_true(result["cooperates"])
	assert_eq(result["cooperation_score"], 15)


func test_hostile_lord_with_maho_fugitive_cooperates():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	# YU(0) + rival(-20) + maho(-30) = -50 → does NOT cooperate
	# Even maho pressure isn't enough to overcome hostility for a Yu lord
	var result := ExtraditionSystem.evaluate_extradition(lord, -30, 1.0, TopicData.Tier.TIER_1, false, false, false)
	assert_false(result["cooperates"])
	assert_eq(result["cooperation_score"], -50)


func test_meiyo_lord_friend_returns_fugitive():
	var lord := _make_lord(Enums.BushidoVirtue.MEIYO)
	# MEIYO(+20) + friend(+20) + tier3(-5) = +35
	var result := ExtraditionSystem.evaluate_extradition(lord, 50, 3.0, TopicData.Tier.TIER_3, false, false, false)
	assert_true(result["cooperates"])
	assert_eq(result["cooperation_score"], 30)  # +20 +20 -5 -5(mid status)


# -- Apply Cooperation / Refusal ----

func test_apply_cooperation_grants_disposition():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	lord.disposition_values[99] = 10
	var result := ExtraditionSystem.apply_cooperation(lord, 99, TopicData.Tier.TIER_2)
	assert_eq(result["disposition_change"], 10, "Tier 2 crime grants max disposition")
	assert_eq(lord.disposition_values[99], 20)
	assert_true(result["fugitive_returned"])


func test_apply_cooperation_minor_crime_less_disposition():
	var lord := _make_lord(Enums.BushidoVirtue.GI)
	lord.disposition_values[99] = 0
	var result := ExtraditionSystem.apply_cooperation(lord, 99, TopicData.Tier.TIER_4)
	assert_eq(result["disposition_change"], 5, "Tier 4 crime grants min disposition")


func test_apply_refusal_disposition_loss():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	lord.disposition_values[99] = 0
	var result := ExtraditionSystem.apply_refusal(lord, 99, TopicData.Tier.TIER_2, false)
	assert_eq(result["disposition_change"], -20, "Tier 2 refusal = max disposition loss")
	assert_eq(lord.disposition_values[99], -20)
	assert_true(result["topic_escalation"])
	assert_eq(result["escalated_tier"], TopicData.Tier.TIER_3)


func test_apply_denial_extra_insult_penalty():
	var lord := _make_lord(Enums.BushidoVirtue.YU)
	lord.disposition_values[99] = 0
	var result := ExtraditionSystem.apply_refusal(lord, 99, TopicData.Tier.TIER_4, true)
	# tier 4 refusal(-10) + denial insult(-5) = -15
	assert_eq(result["disposition_change"], -15)


# -- Emerald Champion Petition ----

func test_can_petition_for_tier_2():
	assert_true(ExtraditionSystem.can_petition_emerald_champion(TopicData.Tier.TIER_2))


func test_can_petition_for_tier_1():
	assert_true(ExtraditionSystem.can_petition_emerald_champion(TopicData.Tier.TIER_1))


func test_cannot_petition_for_tier_3():
	assert_false(ExtraditionSystem.can_petition_emerald_champion(TopicData.Tier.TIER_3))


func test_cannot_petition_for_tier_4():
	assert_false(ExtraditionSystem.can_petition_emerald_champion(TopicData.Tier.TIER_4))


func test_cooperation_disposition_clamped_at_100():
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.disposition_values = {2: 96}
	ExtraditionSystem.apply_cooperation(lord, 2, TopicData.Tier.TIER_1)
	assert_eq(lord.disposition_values[2], 100, "Disposition should clamp at 100")


func test_refusal_disposition_clamped_at_negative_100():
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.disposition_values = {2: -90}
	ExtraditionSystem.apply_refusal(lord, 2, TopicData.Tier.TIER_1, true)
	assert_eq(lord.disposition_values[2], -100, "Disposition should clamp at -100")
