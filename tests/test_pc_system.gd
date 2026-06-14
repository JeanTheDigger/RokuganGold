extends GutTest
## GUT tests for PcSystem (GDD s60) — PC Integration.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_pc(id: int = 1, logged_in: bool = true, home: int = 100) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.is_pc = true
	c.is_logged_in = logged_in
	c.home_settlement_id = home
	c.physical_location = str(home) if logged_in else ""
	c.banked_ap = 0
	c.offline_policies = {}
	c.pending_events = []
	c.supply_ledger = {}
	return c


func _make_npc(id: int = 99) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.is_pc = false
	c.is_logged_in = false
	c.action_points_current = 2
	return c


# ---------------------------------------------------------------------------
# AP Banking (s60.5)
# ---------------------------------------------------------------------------

func test_bank_daily_ap_accumulates() -> void:
	var c := _make_pc()
	PcSystem.bank_daily_ap(c, 2)
	assert_eq(c.banked_ap, 2)
	PcSystem.bank_daily_ap(c, 2)
	assert_eq(c.banked_ap, 4)


func test_bank_daily_ap_caps_at_4x_daily() -> void:
	var c := _make_pc()
	# Fill to cap: 4 × 2 = 8
	for _i in 5:
		PcSystem.bank_daily_ap(c, 2)
	assert_eq(c.banked_ap, 8)


func test_bank_daily_ap_does_not_overflow_cap() -> void:
	var c := _make_pc()
	c.banked_ap = 7
	PcSystem.bank_daily_ap(c, 2)
	assert_eq(c.banked_ap, 8, "Must clamp at cap, not 9")


func test_reset_daily_ap_banks_for_pc() -> void:
	var c := _make_pc()
	c.action_points_current = 0
	ActionPointSystem.reset_daily_ap(c)
	assert_eq(c.banked_ap, 2)
	assert_eq(c.action_points_current, 0, "PCs never enter NPC wave")


func test_reset_daily_ap_does_not_bank_for_npc() -> void:
	var c := _make_npc()
	ActionPointSystem.reset_daily_ap(c)
	assert_eq(c.banked_ap, 0)
	assert_eq(c.action_points_current, 2)


func test_dead_pc_gets_no_ap() -> void:
	var c := _make_pc()
	c.wounds_taken = 100
	ActionPointSystem.reset_daily_ap(c)
	assert_eq(c.banked_ap, 0)
	assert_eq(c.action_points_current, 0)


# ---------------------------------------------------------------------------
# Login / Logout (s60.3, s60.4)
# ---------------------------------------------------------------------------

func test_login_sets_logged_in() -> void:
	var c := _make_pc(1, false)
	c.home_settlement_id = 50
	c.physical_location = ""
	PcSystem.login(c)
	assert_true(c.is_logged_in)
	assert_eq(c.physical_location, "50")


func test_login_keeps_existing_location() -> void:
	var c := _make_pc(1, false)
	c.physical_location = "75"
	c.home_settlement_id = 50
	PcSystem.login(c)
	assert_eq(c.physical_location, "75", "Should not overwrite an already-set location")


func test_logout_clears_location() -> void:
	var c := _make_pc(1, true, 50)
	c.physical_location = "50"
	PcSystem.logout(c)
	assert_false(c.is_logged_in)
	assert_eq(c.physical_location, "")


func test_logout_preserves_home_settlement() -> void:
	var c := _make_pc(1, true, 50)
	c.physical_location = "50"
	PcSystem.logout(c)
	assert_eq(c.home_settlement_id, 50)


func test_logout_sets_home_from_location_when_unset() -> void:
	var c := _make_pc(1, true, -1)
	c.physical_location = "77"
	PcSystem.logout(c)
	assert_eq(c.home_settlement_id, 77)


# ---------------------------------------------------------------------------
# Offline Policy Resolution (s60.6)
# ---------------------------------------------------------------------------

func test_get_policy_returns_default_queue_for_duel() -> void:
	var c := _make_pc()
	assert_eq(PcSystem.get_policy(c, "DUEL_CHALLENGE_RECEIVED"), "QUEUE")


func test_get_policy_returns_default_honor_for_favor() -> void:
	var c := _make_pc()
	assert_eq(PcSystem.get_policy(c, "FAVOR_REQUESTED"), "HONOR")


func test_get_policy_returns_custom_policy() -> void:
	var c := _make_pc()
	c.offline_policies["DUEL_CHALLENGE_RECEIVED"] = "DECLINE"
	assert_eq(PcSystem.get_policy(c, "DUEL_CHALLENGE_RECEIVED"), "DECLINE")


func test_resolve_policy_queue() -> void:
	var c := _make_pc()
	var event := {"reactive_type": "DUEL_CHALLENGE_RECEIVED"}
	assert_eq(PcSystem.resolve_policy(c, event, {}), "QUEUE")


func test_resolve_policy_honor_maps_to_accept() -> void:
	var c := _make_pc()
	var event := {"reactive_type": "FAVOR_REQUESTED"}
	assert_eq(PcSystem.resolve_policy(c, event, {}), "ACCEPT")


func test_resolve_policy_decline() -> void:
	var c := _make_pc()
	var event := {"reactive_type": "ACCEPT_TRAINING"}
	assert_eq(PcSystem.resolve_policy(c, event, {}), "DECLINE")


func test_resolve_policy_conditional_same_clan_match() -> void:
	var pc := _make_pc(1)
	pc.clan = "Crane"
	pc.offline_policies["COURT_INVITATION"] = "CONDITIONAL:same_clan"

	var initiator := _make_npc(2)
	initiator.clan = "Crane"
	var chars := {2: initiator}

	var event := {"reactive_type": "COURT_INVITATION", "host_id": 2}
	assert_eq(PcSystem.resolve_policy(pc, event, chars), "ACCEPT")


func test_resolve_policy_conditional_same_clan_no_match() -> void:
	var pc := _make_pc(1)
	pc.clan = "Crane"
	pc.offline_policies["COURT_INVITATION"] = "CONDITIONAL:same_clan"

	var initiator := _make_npc(2)
	initiator.clan = "Lion"
	var chars := {2: initiator}

	var event := {"reactive_type": "COURT_INVITATION", "host_id": 2}
	assert_eq(PcSystem.resolve_policy(pc, event, chars), "DECLINE")


func test_resolve_policy_conditional_disposition_friend() -> void:
	var pc := _make_pc(1)
	pc.offline_policies["CONTRACT_OFFERED"] = "CONDITIONAL:disposition_friend"
	pc.disposition_values[2] = 50

	var lord := _make_npc(2)
	var chars := {2: lord}

	var event := {"reactive_type": "CONTRACT_OFFERED", "lord_id": 2}
	assert_eq(PcSystem.resolve_policy(pc, event, chars), "ACCEPT")


func test_resolve_policy_conditional_disposition_not_friend() -> void:
	var pc := _make_pc(1)
	pc.offline_policies["CONTRACT_OFFERED"] = "CONDITIONAL:disposition_friend"
	pc.disposition_values[2] = 10

	var lord := _make_npc(2)
	var chars := {2: lord}

	var event := {"reactive_type": "CONTRACT_OFFERED", "lord_id": 2}
	assert_eq(PcSystem.resolve_policy(pc, event, chars), "DECLINE")


# ---------------------------------------------------------------------------
# Offline Event Processing (s60.6)
# ---------------------------------------------------------------------------

func test_process_offline_events_empty_when_logged_in() -> void:
	var c := _make_pc(1, true)
	c.pending_events = [{"reactive_type": "FAVOR_REQUESTED", "requester_id": 2}]
	var results := PcSystem.process_offline_events(c, {}, 1)
	assert_eq(results.size(), 0, "Logged-in PC: no offline processing")
	assert_eq(c.pending_events.size(), 1, "Event must remain for logged-in PC")


func test_process_offline_events_queued_event_stays() -> void:
	var c := _make_pc(1, false)
	c.pending_events = [{"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": 2}]
	var results := PcSystem.process_offline_events(c, {}, 1)
	assert_eq(results.size(), 0)
	assert_eq(c.pending_events.size(), 1, "QUEUE event must remain in pending_events")


func test_process_offline_events_honor_favor_consumed_and_returned() -> void:
	var c := _make_pc(1, false)
	c.pending_events = [{"reactive_type": "FAVOR_REQUESTED", "requester_id": 2}]
	var results := PcSystem.process_offline_events(c, {}, 5)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["resolution"], "ACCEPT")
	assert_eq(results[0]["event_type"], "FAVOR_REQUESTED")
	assert_eq(c.pending_events.size(), 0, "Consumed event must be removed")


func test_process_offline_events_decline_training() -> void:
	var c := _make_pc(1, false)
	c.pending_events = [{"reactive_type": "ACCEPT_TRAINING", "sensei_id": 3}]
	var results := PcSystem.process_offline_events(c, {}, 1)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["resolution"], "DECLINE")
	assert_eq(c.pending_events.size(), 0)


func test_process_offline_events_queue_cap_enforced() -> void:
	var c := _make_pc(1, false)
	# Fill with 35 QUEUE events (cap is 30)
	for i in 35:
		c.pending_events.append({"reactive_type": "DUEL_CHALLENGE_RECEIVED", "challenger_id": i})
	PcSystem.process_offline_events(c, {}, 1)
	assert_eq(c.pending_events.size(), PcSystem.OFFLINE_EVENT_QUEUE_CAP)


# ---------------------------------------------------------------------------
# NPC Wave Resolver exclusion
# ---------------------------------------------------------------------------

func test_pc_excluded_from_active_characters() -> void:
	var pc := _make_pc()
	pc.action_points_current = 2
	var active := NPCWaveResolver._get_active_characters([pc])
	assert_eq(active.size(), 0, "PC must be excluded even with AP > 0")


func test_npc_included_in_active_characters() -> void:
	var npc := _make_npc()
	npc.action_points_current = 2
	var active := NPCWaveResolver._get_active_characters([npc])
	assert_eq(active.size(), 1)


func test_pc_excluded_from_reactive_npcs() -> void:
	var pc := _make_pc()
	var ws := {pc.character_id: {"pending_events": [{"reactive_type": "DUEL_CHALLENGE_RECEIVED"}]}}
	var reactive := NPCWaveResolver._gather_reactive_npcs([pc], ws)
	assert_eq(reactive.size(), 0, "Logged-out PC pending events must not enter NPC reactive phase")


# ---------------------------------------------------------------------------
# Bubble Time (s60.7)
# ---------------------------------------------------------------------------

func test_create_bubble_scene_assigns_scene_id() -> void:
	var pc1 := _make_pc(1)
	var pc2 := _make_pc(2)
	var chars := {1: pc1, 2: pc2}
	var next_id: Array[int] = [1]
	var scene := PcSystem.create_bubble_scene([1, 2], 100, next_id, chars)
	assert_eq(scene["scene_id"], 1)
	assert_eq(next_id[0], 2)


func test_create_bubble_scene_sets_participant_fields() -> void:
	var pc1 := _make_pc(1)
	var chars := {1: pc1}
	var next_id: Array[int] = [5]
	PcSystem.create_bubble_scene([1], 200, next_id, chars)
	assert_eq(pc1.bubble_scene_id, 5)
	assert_eq(pc1.bubble_anchor_ic_day, 200)


func test_close_bubble_scene_clears_participant_fields() -> void:
	var pc1 := _make_pc(1)
	pc1.bubble_scene_id = 3
	pc1.bubble_anchor_ic_day = 50
	var chars := {1: pc1}
	var scenes: Array[Dictionary] = [
		{"scene_id": 3, "participant_ids": [1], "anchor_ic_day": 50, "queued_actions": []}
	]
	var result := PcSystem.close_bubble_scene(3, scenes, chars)
	assert_true(result["success"])
	assert_eq(pc1.bubble_scene_id, -1)
	assert_eq(pc1.bubble_anchor_ic_day, -1)
	assert_eq(scenes.size(), 0)


func test_close_bubble_scene_returns_queued_actions() -> void:
	var chars := {}
	var act := {"action": "CHARM", "target": 5}
	var scenes: Array[Dictionary] = [
		{"scene_id": 7, "participant_ids": [], "anchor_ic_day": 10, "queued_actions": [act]}
	]
	var result := PcSystem.close_bubble_scene(7, scenes, chars)
	assert_eq(result["queued_actions"].size(), 1)
	assert_eq(result["queued_actions"][0]["action"], "CHARM")


func test_close_bubble_scene_not_found() -> void:
	var scenes: Array[Dictionary] = []
	var result := PcSystem.close_bubble_scene(99, scenes, {})
	assert_false(result["success"])


# === Character creation constraints (s60.2) ===

func test_pc_cannot_be_monk_school_type() -> void:
	assert_false(PcSystem.is_school_type_allowed_for_pc(Enums.SchoolType.MONK),
		"PCs may not be monks (s60.2)")
	assert_true(PcSystem.is_school_type_allowed_for_pc(Enums.SchoolType.BUSHI),
		"Bushi PC allowed")
	assert_true(PcSystem.is_school_type_allowed_for_pc(Enums.SchoolType.SHUGENJA),
		"Shugenja PC allowed")
	assert_true(PcSystem.is_school_type_allowed_for_pc(Enums.SchoolType.COURTIER),
		"Courtier PC allowed")


func test_is_valid_pc_rejects_monk() -> void:
	var c := L5RCharacterData.new()
	c.is_pc = true
	c.school_type = Enums.SchoolType.MONK
	assert_false(PcSystem.is_valid_pc(c), "Monk PC is invalid")
	c.school_type = Enums.SchoolType.BUSHI
	assert_true(PcSystem.is_valid_pc(c), "Bushi PC is valid")


func test_is_valid_pc_requires_is_pc() -> void:
	var c := L5RCharacterData.new()
	c.is_pc = false
	c.school_type = Enums.SchoolType.BUSHI
	assert_false(PcSystem.is_valid_pc(c), "Non-PC is not a valid PC")
