extends GutTest
## Tests for OperationalHierarchySystem per GDD s11.3.18.


func _make_char(
	id: int,
	lord_id: int = -1,
	op_sup_id: int = -1,
	hierarchy_type: Enums.OperationalHierarchyType = Enums.OperationalHierarchyType.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.lord_id = lord_id
	c.operational_superior_id = op_sup_id
	c.operational_hierarchy_type = hierarchy_type
	c.bushido_virtue = Enums.BushidoVirtue.YU
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.character_name = "Char%d" % id
	return c


# -- Assignment and Clearing (s11.3.18g) ----

func test_assign_operational_superior():
	var c := _make_char(1, 10)
	var r := OperationalHierarchySystem.assign_operational_superior(
		c, 20, Enums.OperationalHierarchyType.LEGAL
	)
	assert_eq(c.operational_superior_id, 20)
	assert_eq(c.operational_hierarchy_type, Enums.OperationalHierarchyType.LEGAL)
	assert_eq(r["new_superior_id"], 20)
	assert_false(r["overwrote_existing"])


func test_assign_overwrites_existing():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.LEGAL)
	var r := OperationalHierarchySystem.assign_operational_superior(
		c, 30, Enums.OperationalHierarchyType.MILITARY
	)
	assert_eq(c.operational_superior_id, 30)
	assert_eq(c.operational_hierarchy_type, Enums.OperationalHierarchyType.MILITARY)
	assert_true(r["overwrote_existing"])
	assert_eq(r["old_superior_id"], 20)


func test_clear_operational_superior():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.MILITARY)
	var r := OperationalHierarchySystem.clear_operational_superior(c)
	assert_eq(c.operational_superior_id, -1)
	assert_eq(c.operational_hierarchy_type, Enums.OperationalHierarchyType.NONE)
	assert_eq(r["cleared_superior_id"], 20)


# -- Chain Traversal (s11.3.18b) ----

func test_get_operational_chain_single_level():
	var c := _make_char(1, 10, 20)
	var superior := _make_char(20, 10)
	var chars: Dictionary = {1: c, 20: superior}
	var chain: Array = OperationalHierarchySystem.get_operational_chain(c, chars)
	assert_eq(chain.size(), 1)
	assert_eq(chain[0], 20)


func test_get_operational_chain_multi_level():
	var soldier := _make_char(1, 10, 2)
	var chui := _make_char(2, 10, 3)
	var taisa := _make_char(3, 10)
	var chars: Dictionary = {1: soldier, 2: chui, 3: taisa}
	var chain: Array = OperationalHierarchySystem.get_operational_chain(soldier, chars)
	assert_eq(chain.size(), 2)
	assert_eq(chain[0], 2)
	assert_eq(chain[1], 3)


func test_get_operational_chain_no_superior():
	var c := _make_char(1, 10)
	var chars: Dictionary = {1: c}
	var chain: Array = OperationalHierarchySystem.get_operational_chain(c, chars)
	assert_eq(chain.size(), 0)


func test_get_operational_subordinates():
	var sup := _make_char(10, 1)
	var sub1 := _make_char(20, 1, 10)
	var sub2 := _make_char(30, 1, 10)
	var other := _make_char(40, 1, 99)
	var all: Array = [sup, sub1, sub2, other]
	var subs: Array = OperationalHierarchySystem.get_operational_subordinates(10, all)
	assert_eq(subs.size(), 2)


func test_shares_operational_chain():
	var soldier := _make_char(1, 10, 2)
	var chui := _make_char(2, 10, 3)
	var taisa := _make_char(3, 10)
	var chars: Dictionary = {1: soldier, 2: chui, 3: taisa}
	assert_true(OperationalHierarchySystem.shares_operational_chain(soldier, taisa, chars))


func test_no_shared_chain():
	var a := _make_char(1, 10, 2)
	var b := _make_char(5, 10, 6)
	var sup_a := _make_char(2, 10)
	var sup_b := _make_char(6, 10)
	var chars: Dictionary = {1: a, 2: sup_a, 5: b, 6: sup_b}
	assert_false(OperationalHierarchySystem.shares_operational_chain(a, b, chars))


# -- Override Rules (s11.3.18f) ----

func test_feudal_lord_can_override():
	var c := _make_char(1, 10, 20)
	assert_true(OperationalHierarchySystem.can_feudal_lord_override(10, c))
	assert_false(OperationalHierarchySystem.can_feudal_lord_override(99, c))


func test_higher_superior_can_override():
	var soldier := _make_char(1, 10, 2)
	var chui := _make_char(2, 10, 3)
	var taisa := _make_char(3, 10)
	var chars: Dictionary = {1: soldier, 2: chui, 3: taisa}
	assert_true(OperationalHierarchySystem.can_higher_superior_override(3, soldier, chars))
	assert_false(OperationalHierarchySystem.can_higher_superior_override(99, soldier, chars))


func test_feudal_override_execution():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.LEGAL)
	var r := OperationalHierarchySystem.execute_feudal_override(
		c, 30, Enums.OperationalHierarchyType.MILITARY
	)
	assert_eq(c.operational_superior_id, 30)
	assert_true(r["feudal_override"])
	assert_eq(r["disrupted_superior_id"], 20)


# -- Objective Priority (s11.3.18f) ----

func test_objective_priority_operational():
	var c := _make_char(1, 10, 20)
	assert_eq(
		OperationalHierarchySystem.get_objective_priority(c),
		OperationalHierarchySystem.ObjectiveSource.OPERATIONAL_SUPERIOR
	)


func test_objective_priority_feudal():
	var c := _make_char(1, 10)
	assert_eq(
		OperationalHierarchySystem.get_objective_priority(c),
		OperationalHierarchySystem.ObjectiveSource.FEUDAL_LORD
	)


func test_is_on_operational_assignment():
	var assigned := _make_char(1, 10, 20)
	var unassigned := _make_char(2, 10)
	assert_true(OperationalHierarchySystem.is_on_operational_assignment(assigned))
	assert_false(OperationalHierarchySystem.is_on_operational_assignment(unassigned))


# -- Order Refusal (s11.3.18h) ----

func test_refusal_disposition_hit_minor():
	assert_eq(
		OperationalHierarchySystem.get_refusal_disposition_hit(
			OperationalHierarchySystem.RefusalSeverity.MINOR
		),
		-10
	)


func test_refusal_disposition_hit_critical():
	assert_eq(
		OperationalHierarchySystem.get_refusal_disposition_hit(
			OperationalHierarchySystem.RefusalSeverity.CRITICAL
		),
		-20
	)


func test_gi_escalates_refusal():
	var c := _make_char(1, 10, 20)
	c.bushido_virtue = Enums.BushidoVirtue.GI
	assert_true(OperationalHierarchySystem.will_escalate_refusal(c))


func test_chugi_does_not_escalate():
	var c := _make_char(1, 10, 20)
	c.bushido_virtue = Enums.BushidoVirtue.CHUGI
	assert_false(OperationalHierarchySystem.will_escalate_refusal(c))


func test_yu_does_not_escalate():
	var c := _make_char(1, 10, 20)
	c.bushido_virtue = Enums.BushidoVirtue.YU
	assert_false(OperationalHierarchySystem.will_escalate_refusal(c))


func test_makoto_escalates():
	var c := _make_char(1, 10, 20)
	c.bushido_virtue = Enums.BushidoVirtue.MAKOTO
	assert_true(OperationalHierarchySystem.will_escalate_refusal(c))


func test_seigyo_does_not_escalate():
	var c := _make_char(1, 10, 20)
	c.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	assert_false(OperationalHierarchySystem.will_escalate_refusal(c))


# -- Escalation Outcomes (s11.3.18h) ----

func test_gi_daimyo_believes_subordinate():
	var daimyo := _make_char(10, 1)
	daimyo.bushido_virtue = Enums.BushidoVirtue.GI
	var outcome := OperationalHierarchySystem.get_escalation_outcome(daimyo)
	assert_eq(outcome, OperationalHierarchySystem.EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE)


func test_seigyo_daimyo_dismisses():
	var daimyo := _make_char(10, 1)
	daimyo.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	var outcome := OperationalHierarchySystem.get_escalation_outcome(daimyo)
	assert_eq(outcome, OperationalHierarchySystem.EscalationOutcome.DAIMYO_DISMISSES)


func test_yu_daimyo_sides_with_superior():
	var daimyo := _make_char(10, 1)
	daimyo.bushido_virtue = Enums.BushidoVirtue.YU
	var outcome := OperationalHierarchySystem.get_escalation_outcome(daimyo)
	assert_eq(outcome, OperationalHierarchySystem.EscalationOutcome.DAIMYO_SIDES_WITH_SUPERIOR)


func test_vindication_consequences():
	var r := OperationalHierarchySystem.get_escalation_consequences(
		OperationalHierarchySystem.EscalationOutcome.DAIMYO_BELIEVES_SUBORDINATE
	)
	assert_true(r["subordinate_vindicated"])
	assert_true(r["superior_investigated"])
	assert_eq(r["enemy_disposition_floor"], -50)


func test_insubordination_consequences():
	var r := OperationalHierarchySystem.get_escalation_consequences(
		OperationalHierarchySystem.EscalationOutcome.DAIMYO_SIDES_WITH_SUPERIOR
	)
	assert_true(r["insubordination_guilty"])
	assert_eq(r["honor_loss"], -0.3)
	assert_eq(r["daimyo_disposition_loss"], -10)


func test_dismissed_consequences():
	var r := OperationalHierarchySystem.get_escalation_consequences(
		OperationalHierarchySystem.EscalationOutcome.DAIMYO_DISMISSES
	)
	assert_true(r["complaint_dismissed"])
	assert_true(r["subordinate_exposed"])


# -- Death of Superior (s11.3.18g) ----

func test_clear_subordinates_on_death():
	var sub1 := _make_char(1, 10, 20, Enums.OperationalHierarchyType.LEGAL)
	var sub2 := _make_char(2, 10, 20, Enums.OperationalHierarchyType.LEGAL)
	var other := _make_char(3, 10, 99, Enums.OperationalHierarchyType.MILITARY)
	var all: Array = [sub1, sub2, other]
	var cleared: Array = OperationalHierarchySystem.clear_subordinates_on_death(20, all)
	assert_eq(cleared.size(), 2)
	assert_eq(sub1.operational_superior_id, -1)
	assert_eq(sub1.operational_hierarchy_type, Enums.OperationalHierarchyType.NONE)
	assert_eq(other.operational_superior_id, 99)


# -- Starting Baseline (s11.3.18i) ----

func test_baseline_military():
	assert_eq(
		OperationalHierarchySystem.get_starting_baseline(Enums.OperationalHierarchyType.MILITARY),
		5
	)


func test_baseline_legal():
	assert_eq(
		OperationalHierarchySystem.get_starting_baseline(Enums.OperationalHierarchyType.LEGAL),
		5
	)


func test_baseline_delegation():
	assert_eq(
		OperationalHierarchySystem.get_starting_baseline(Enums.OperationalHierarchyType.DELEGATION),
		10
	)


func test_baseline_none():
	assert_eq(
		OperationalHierarchySystem.get_starting_baseline(Enums.OperationalHierarchyType.NONE),
		0
	)


# -- Hierarchy Type Queries ----

func test_is_legal_subordinate():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.LEGAL)
	assert_true(OperationalHierarchySystem.is_legal_subordinate(c))


func test_is_military_subordinate():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.MILITARY)
	assert_true(OperationalHierarchySystem.is_military_subordinate(c))


func test_is_delegation_member():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.DELEGATION)
	assert_true(OperationalHierarchySystem.is_delegation_member(c))


func test_not_legal_if_military():
	var c := _make_char(1, 10, 20, Enums.OperationalHierarchyType.MILITARY)
	assert_false(OperationalHierarchySystem.is_legal_subordinate(c))
