extends GutTest
## Tests for PersonalVisitSystem per GDD s17.


# -- Initiation tests --------------------------------------------------------

func test_initiate_visit_creates_record():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 50)
	assert_eq(visit["visitor_id"], 1)
	assert_eq(visit["host_id"], 2)
	assert_eq(visit["visit_type"], PersonalVisitSystem.VisitType.INVITATION_SENT)
	assert_eq(visit["initiated_ic_day"], 50)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.INITIATED)


func test_initiate_uninvited_visit():
	var visit := PersonalVisitSystem.initiate_visit(3, 4, PersonalVisitSystem.VisitType.UNINVITED, 100)
	assert_eq(visit["visit_type"], PersonalVisitSystem.VisitType.UNINVITED)


# -- Host response: Invitation Sent ------------------------------------------

func test_refuse_after_invitation_severe_consequences():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 50)
	var effects := PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.REFUSE)
	assert_false(effects["accepted"])
	assert_eq(effects["disposition_change_to_host"], -10)
	assert_eq(effects["honor_change_host"], -0.3)


func test_accept_invitation_no_special_bonus():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 50)
	var effects := PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.ACCEPT)
	assert_true(effects["accepted"])
	assert_eq(effects["disposition_change_to_visitor"], 0)
	assert_eq(effects["disposition_change_to_host"], 0)


# -- Host response: Letter Announcing Arrival ---------------------------------

func test_refuse_letter_arrival_mild_consequences():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.LETTER_ANNOUNCING_ARRIVAL, 50)
	var effects := PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.REFUSE)
	assert_eq(effects["disposition_change_to_host"], -2)
	assert_eq(effects["honor_change_host"], 0.0)


# -- Host response: Uninvited ------------------------------------------------

func test_refuse_uninvited_no_cost():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.UNINVITED, 50)
	var effects := PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.REFUSE)
	assert_eq(effects["disposition_change_to_host"], 0)


func test_accept_uninvited_goodwill_bonus():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.UNINVITED, 50)
	var effects := PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.ACCEPT)
	assert_true(effects["accepted"])
	assert_eq(effects["disposition_change_to_visitor"], 5)


# -- Decline invitation (recipient side) -------------------------------------

func test_decline_invitation_small_disposition_cost():
	var effects := PersonalVisitSystem.decline_invitation_effects()
	assert_eq(effects["disposition_change"], -3)


# -- Action filtering --------------------------------------------------------

func test_category_1_actions_available():
	for action_id in PersonalVisitSystem.CATEGORY_1_ACTIONS:
		assert_true(PersonalVisitSystem.is_action_available_during_visit(action_id),
			"%s should be available" % action_id)


func test_category_3_actions_available():
	for action_id in PersonalVisitSystem.CATEGORY_3_ACTIONS:
		assert_true(PersonalVisitSystem.is_action_available_during_visit(action_id),
			"%s should be available" % action_id)


func test_category_5_actions_available():
	for action_id in PersonalVisitSystem.CATEGORY_5_ACTIONS:
		assert_true(PersonalVisitSystem.is_action_available_during_visit(action_id),
			"%s should be available" % action_id)


func test_broadcast_actions_not_available():
	assert_false(PersonalVisitSystem.is_action_available_during_visit("PUBLIC_PERFORMANCE"))
	assert_false(PersonalVisitSystem.is_action_available_during_visit("SWAY_OPINION"))
	assert_false(PersonalVisitSystem.is_action_available_during_visit("ORDER_BATTLE"))


func test_get_available_actions_returns_all_visit_actions():
	var actions := PersonalVisitSystem.get_available_actions()
	assert_eq(actions.size(), PersonalVisitSystem.VISIT_ACTIONS.size())
	assert_has(actions, "CHARM")
	assert_has(actions, "PROBE")


# -- Intimate setting bonus ---------------------------------------------------

func test_charm_gets_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("CHARM", 4)
	assert_eq(result, 7)


func test_deliver_gift_gets_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("DELIVER_GIFT", 5)
	assert_eq(result, 8)


func test_offer_favor_gets_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("OFFER_FAVOR", 6)
	assert_eq(result, 9)


func test_perform_for_gets_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("PERFORM_FOR", 3)
	assert_eq(result, 6)


func test_negotiate_gets_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("NEGOTIATE", 4)
	assert_eq(result, 7)


func test_gossip_no_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("GOSSIP", 4)
	assert_eq(result, 4)


func test_probe_no_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("PROBE", 4)
	assert_eq(result, 4)


func test_read_character_no_intimate_bonus():
	var result := PersonalVisitSystem.apply_intimate_bonus("READ_CHARACTER", 4)
	assert_eq(result, 4)


func test_get_intimate_bonus_category_1():
	assert_eq(PersonalVisitSystem.get_intimate_bonus("PERSUADE"), 3)
	assert_eq(PersonalVisitSystem.get_intimate_bonus("IMPRESS"), 3)
	assert_eq(PersonalVisitSystem.get_intimate_bonus("LISTEN_REFLECT"), 3)


func test_get_intimate_bonus_non_category_1():
	assert_eq(PersonalVisitSystem.get_intimate_bonus("DISCLOSE"), 0)
	assert_eq(PersonalVisitSystem.get_intimate_bonus("REVEAL_SECRET_PRIVATELY"), 0)


# -- All Category 1 actions listed --------------------------------------------

func test_all_category_1_are_in_visit_actions():
	for action_id in PersonalVisitSystem.CATEGORY_1_ACTIONS:
		assert_has(PersonalVisitSystem.VISIT_ACTIONS, action_id,
			"%s should be in VISIT_ACTIONS" % action_id)


func test_is_category_1_action():
	assert_true(PersonalVisitSystem.is_category_1_action("CHARM"))
	assert_true(PersonalVisitSystem.is_category_1_action("NEGOTIATE"))
	assert_true(PersonalVisitSystem.is_category_1_action("DELIVER_GIFT"))
	assert_false(PersonalVisitSystem.is_category_1_action("GOSSIP"))
	assert_false(PersonalVisitSystem.is_category_1_action("PROBE"))


# -- Visit lifecycle tests ----------------------------------------------------

func test_initiate_visit_state():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.INITIATED)
	assert_eq(visit["started_ic_day"], -1)
	assert_eq(visit["concluded_ic_day"], -1)


func test_activate_visit():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	PersonalVisitSystem.activate_visit(visit, 105)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.ACTIVE)
	assert_eq(visit["started_ic_day"], 105)


func test_conclude_visit():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	PersonalVisitSystem.activate_visit(visit, 105)
	PersonalVisitSystem.conclude_visit(visit, 110)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.CONCLUDED)
	assert_eq(visit["concluded_ic_day"], 110)


func test_is_visit_active():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	assert_false(PersonalVisitSystem.is_visit_active(visit))
	PersonalVisitSystem.activate_visit(visit, 105)
	assert_true(PersonalVisitSystem.is_visit_active(visit))
	PersonalVisitSystem.conclude_visit(visit, 110)
	assert_false(PersonalVisitSystem.is_visit_active(visit))


func test_visit_duration():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	assert_eq(PersonalVisitSystem.get_visit_duration_days(visit, 105), 0)
	PersonalVisitSystem.activate_visit(visit, 105)
	assert_eq(PersonalVisitSystem.get_visit_duration_days(visit, 108), 3)


func test_refuse_sets_refused_state():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.INVITATION_SENT, 100)
	PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.REFUSE)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.REFUSED)


func test_accept_sets_accepted_state():
	var visit := PersonalVisitSystem.initiate_visit(1, 2, PersonalVisitSystem.VisitType.UNINVITED, 100)
	PersonalVisitSystem.resolve_host_response(visit, PersonalVisitSystem.HostResponse.ACCEPT)
	assert_eq(visit["state"], PersonalVisitSystem.VisitState.ACCEPTED)


func test_daily_ap_during_visit():
	assert_eq(PersonalVisitSystem.DAILY_AP_DURING_VISIT, 2)


# -- Category 3/5 qualitative advantage tests ---------------------------------

func test_category_3_lower_exposure():
	assert_true(PersonalVisitSystem.has_lower_exposure_risk("GOSSIP"))
	assert_true(PersonalVisitSystem.has_lower_exposure_risk("DISCLOSE"))
	assert_false(PersonalVisitSystem.has_lower_exposure_risk("CHARM"))


func test_category_5_extended_observation():
	assert_true(PersonalVisitSystem.has_extended_observation("PROBE", 2))
	assert_true(PersonalVisitSystem.has_extended_observation("READ_CHARACTER", 3))
	assert_false(PersonalVisitSystem.has_extended_observation("PROBE", 1))
	assert_false(PersonalVisitSystem.has_extended_observation("CHARM", 5))
