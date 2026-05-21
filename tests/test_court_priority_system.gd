extends GutTest
## Tests for CourtPrioritySystem per GDD s15.8.


# -- Helpers ------------------------------------------------------------------

func _make_court(id: String, status: float = 5.0, relevance: float = 0.0, assigned: bool = false) -> Dictionary:
	return {
		"court_id": id,
		"court_status": status,
		"personal_relevance": relevance,
		"assigned_by_lord": assigned,
		"topics": [],
	}


# -- Court selection tests ----------------------------------------------------

func test_single_court_always_selected():
	var courts: Array = [_make_court("A")]
	var result := CourtPrioritySystem.select_court(courts, {}, "", 3.0)
	assert_eq(result["court_id"], "A")


func test_empty_courts_returns_empty():
	var courts: Array = []
	var result := CourtPrioritySystem.select_court(courts, {}, "", 3.0)
	assert_true(result.is_empty())


func test_lord_assigned_court_wins():
	var courts: Array = [
		_make_court("A", 10.0, 5.0),
		_make_court("B", 1.0, 0.0, true),
	]
	var result := CourtPrioritySystem.select_court(courts, {}, "", 3.0)
	assert_eq(result["court_id"], "B")


func test_primary_objective_court_wins():
	var courts: Array = [
		_make_court("A", 10.0),
		_make_court("B", 5.0),
	]
	var obj: Dictionary = {"target_court_id": "B"}
	var result := CourtPrioritySystem.select_court(courts, obj, "", 3.0)
	assert_eq(result["court_id"], "B")


func test_personal_relevance_breaks_tie():
	var courts: Array = [
		_make_court("A", 5.0, 2.0),
		_make_court("B", 5.0, 8.0),
	]
	var result := CourtPrioritySystem.select_court(courts, {}, "", 3.0)
	assert_eq(result["court_id"], "B")


func test_higher_status_court_wins_when_equal():
	var courts: Array = [
		_make_court("A", 3.0),
		_make_court("B", 8.0),
	]
	var result := CourtPrioritySystem.select_court(courts, {}, "", 3.0)
	assert_eq(result["court_id"], "B")


# -- Early departure tests ----------------------------------------------------

func test_host_leaving_severe():
	var cost := CourtPrioritySystem.get_early_departure_cost(true, false)
	assert_eq(cost["honor_loss"], -1.0)
	assert_eq(cost["glory_loss"], -0.5)
	assert_false(cost["mandate_violation"])


func test_guest_leaving_mild():
	var cost := CourtPrioritySystem.get_early_departure_cost(false, false)
	assert_eq(cost["disposition_cost"], -3)
	assert_eq(cost["honor_loss"], 0.0)
	assert_false(cost["mandate_violation"])


func test_proxy_leaving_mandate_violation():
	var cost := CourtPrioritySystem.get_early_departure_cost(false, true)
	assert_true(cost["mandate_violation"])
	assert_eq(cost["disposition_cost"], -3)


# -- Negligence tests ---------------------------------------------------------

func test_passive_negligence():
	assert_eq(CourtPrioritySystem.get_negligence_cost(false), -0.1)


func test_deliberate_negligence():
	assert_eq(CourtPrioritySystem.get_negligence_cost(true), -0.5)


# -- Otomo lean tests ---------------------------------------------------------

func test_otomo_gossip_lean():
	assert_eq(CourtPrioritySystem.get_otomo_lean("GOSSIP"), 15)


func test_otomo_disclose_lean():
	assert_eq(CourtPrioritySystem.get_otomo_lean("DISCLOSE"), 10)


func test_otomo_no_lean_for_charm():
	assert_eq(CourtPrioritySystem.get_otomo_lean("CHARM"), 0)


func test_otomo_blocks_inter_clan_goodwill():
	assert_true(CourtPrioritySystem.is_otomo_blocked_action("NEGOTIATE", true))
	assert_false(CourtPrioritySystem.is_otomo_blocked_action("NEGOTIATE", false))


func test_otomo_escalation_at_rival():
	assert_true(CourtPrioritySystem.should_otomo_escalate(-15))
	assert_false(CourtPrioritySystem.should_otomo_escalate(-10))
	assert_false(CourtPrioritySystem.should_otomo_escalate(20))
