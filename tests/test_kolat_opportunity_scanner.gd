extends GutTest
## s54.7d/e — KolatOpportunityScanner self-initiated objectives.


func _master(id: int, sect: Enums.KolatSect) -> L5RCharacterData:
	var m := L5RCharacterData.new()
	m.character_id = id
	m.kolat_sect = sect
	m.is_kolat_master = true
	m.physical_location = "5"
	m.stamina = 4; m.willpower = 4  # alive (Earth ring > 0)
	m.special_data = {}
	return m


func _candidate(id: int, disp_to_master: int, master_id: int, wp: int = 2) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = "5"
	c.stamina = 4; c.willpower = wp  # alive (wp >= 1)
	c.kolat_sect = Enums.KolatSect.NONE
	c.disposition_values = {master_id: disp_to_master}
	return c


# === RECRUIT (agent-network Sects) ===

func test_silk_recruits_friend_tier_candidate() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var cand := _candidate(2, 40, 1)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: cand})
	assert_eq(opp.get("need_type", ""), "RECRUIT_KOLAT_AGENT")
	assert_eq(opp.get("target_npc_id", -1), 2)
	assert_eq(opp.get("source", ""), KolatOpportunityScanner.SOURCE)


func test_silk_picks_highest_disposition_candidate() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var low := _candidate(2, 35, 1)
	var high := _candidate(3, 55, 1)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: low, 3: high})
	assert_eq(opp.get("target_npc_id", -1), 3)


func test_silk_no_candidate_below_friend_tier() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var cand := _candidate(2, 20, 1)  # below +31
	assert_true(KolatOpportunityScanner.scan(m, {1: m, 2: cand}).is_empty())


func test_silk_excludes_already_kolat_and_dead() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var kolat := _candidate(2, 50, 1); kolat.kolat_sect = Enums.KolatSect.COIN
	var dead := _candidate(3, 50, 1); dead.stamina = 0  # Earth 0 → DEAD
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: kolat, 3: dead})
	# Neither qualifies (kolat already affiliated; dead excluded) → no recruit.
	assert_true(opp.is_empty())


func test_silk_at_capacity_does_not_recruit() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	for i in range(6):
		KolatNetwork.register_silk_operative(m, "a%d" % i, 100 + i, "court", 1)
	var cand := _candidate(2, 50, 1)
	assert_true(KolatOpportunityScanner.scan(m, {1: m, 2: cand}).is_empty())


# === CONDITION_SLEEPER (Dream) ===

func test_dream_conditions_below_target() -> void:
	var m := _master(1, Enums.KolatSect.DREAM)
	m.special_data["world_start_sleepers"] = 2
	var cand := _candidate(2, 0, 1, 3)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: cand})
	assert_eq(opp.get("need_type", ""), "CONDITION_SLEEPER")
	assert_eq(opp.get("target_npc_id", -1), 2)


func test_dream_picks_lowest_willpower() -> void:
	var m := _master(1, Enums.KolatSect.DREAM)
	m.special_data["world_start_sleepers"] = 1
	var tough := _candidate(2, 0, 1, 5)
	var weak := _candidate(3, 0, 1, 2)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: tough, 3: weak})
	assert_eq(opp.get("target_npc_id", -1), 3)


func test_dream_at_target_does_nothing() -> void:
	var m := _master(1, Enums.KolatSect.DREAM)
	m.special_data["world_start_sleepers"] = 1
	KolatNetwork.register_sleeper(m, "s1", 9, "phrase", "cmd", 1, false)
	var cand := _candidate(2, 0, 1, 2)
	assert_true(KolatOpportunityScanner.scan(m, {1: m, 2: cand}).is_empty())


# === SECURE_DEAD_DROP (Lotus) ===

func test_lotus_secures_compromised_drop_first() -> void:
	var m := _master(1, Enums.KolatSect.LOTUS)
	KolatNetwork.register_lotus_operative(m, "op", 7, "10", "11")
	var rec := KolatNetwork.get_network(m, Enums.KolatSect.LOTUS)
	rec["op"]["dead_drop_compromised"] = true
	# Even with a recruitable candidate present, securing takes priority.
	var cand := _candidate(2, 50, 1)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: cand})
	assert_eq(opp.get("need_type", ""), "SECURE_DEAD_DROP_NETWORK")


func test_lotus_no_compromise_falls_to_recruit() -> void:
	var m := _master(1, Enums.KolatSect.LOTUS)
	KolatNetwork.register_lotus_operative(m, "op", 7, "10", "11")
	var cand := _candidate(2, 50, 1)
	var opp := KolatOpportunityScanner.scan(m, {1: m, 2: cand})
	assert_eq(opp.get("need_type", ""), "RECRUIT_KOLAT_AGENT")


# === should_clear ===

func test_should_clear_recruit_when_target_now_kolat() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var t := _candidate(2, 50, 1); t.kolat_sect = Enums.KolatSect.SILK
	var slot := {"need_type": "RECRUIT_KOLAT_AGENT", "source": KolatOpportunityScanner.SOURCE, "target_npc_id": 2}
	assert_true(KolatOpportunityScanner.should_clear(m, slot, {2: t}))


func test_should_clear_condition_when_target_met() -> void:
	var m := _master(1, Enums.KolatSect.DREAM)
	m.special_data["world_start_sleepers"] = 1
	KolatNetwork.register_sleeper(m, "s1", 9, "p", "c", 1, false)
	var slot := {"need_type": "CONDITION_SLEEPER", "source": KolatOpportunityScanner.SOURCE, "target_npc_id": 2}
	assert_true(KolatOpportunityScanner.should_clear(m, slot, {}))


func test_should_not_clear_tiger_directive() -> void:
	var m := _master(1, Enums.KolatSect.SILK)
	var slot := {"need_type": "RECRUIT_KOLAT_AGENT", "source": "kolat_directive", "target_npc_id": 2}
	assert_false(KolatOpportunityScanner.should_clear(m, slot, {}))


# === Stage-5 damage-assessment recall (s54.7) ===

func _dead_silk_master_with_agent(master_id: int, agent_id: int) -> L5RCharacterData:
	var sm := _master(master_id, Enums.KolatSect.SILK)
	KolatNetwork.register_silk_operative(sm, "op", agent_id, "court", 1)
	sm.stamina = 0  # Earth 0 → DEAD
	return sm


func test_master_death_recalls_agents_with_living_tiger() -> void:
	var tiger := _master(1, Enums.KolatSect.TIGER)
	var sm := _dead_silk_master_with_agent(2, 50)
	var objectives := {50: {"kolat": {"need_type": "DISTRIBUTE_INTELLIGENCE"}}}
	var chars := {1: tiger, 2: sm, 50: _candidate(50, 0, 2)}
	var n := DayOrchestrator._process_kolat_master_death_recall(
		[{"character_id": 2}], chars, objectives)
	assert_eq(n, 1, "one agent recalled")
	assert_false(objectives[50].has("kolat"), "agent's kolat slot cleared")


func test_no_recall_without_living_tiger() -> void:
	var sm := _dead_silk_master_with_agent(2, 50)
	var objectives := {50: {"kolat": {"need_type": "DISTRIBUTE_INTELLIGENCE"}}}
	var chars := {2: sm, 50: _candidate(50, 0, 2)}
	var n := DayOrchestrator._process_kolat_master_death_recall(
		[{"character_id": 2}], chars, objectives)
	assert_eq(n, 0, "no living Tiger → no recall")
	assert_true(objectives[50].has("kolat"), "agent's kolat slot retained")


func test_non_master_death_no_recall() -> void:
	var tiger := _master(1, Enums.KolatSect.TIGER)
	var plain := _candidate(2, 0, 1); plain.stamina = 0  # dead non-master
	var objectives := {50: {"kolat": {"need_type": "DISTRIBUTE_INTELLIGENCE"}}}
	var chars := {1: tiger, 2: plain}
	var n := DayOrchestrator._process_kolat_master_death_recall(
		[{"character_id": 2}], chars, objectives)
	assert_eq(n, 0)
