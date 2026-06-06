extends GutTest
## GUT tests for KolatSystem (simulation/kolat_system.gd). GDD s54.7c/e/h / s54.7j.


func _char(id: int, wil: int = 2) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.willpower = wil
	c.intelligence = 3
	c.honor = 5.0
	return c


func _temple(vault: int = 100) -> SettlementData:
	var s := SettlementData.new()
	s.temple_vault_koku = vault
	return s


# === Sect / master / sleeper identity ===

func test_identity_helpers() -> void:
	var c := _char(1)
	assert_false(KolatSystem.is_kolat(c))
	assert_false(KolatSystem.is_master(c))
	assert_false(KolatSystem.is_sleeper(c))
	c.kolat_sect = Enums.KolatSect.SILK
	c.is_kolat_master = true
	c.conditioning_stability = 80.0
	assert_true(KolatSystem.is_kolat(c))
	assert_true(KolatSystem.is_master(c))
	assert_true(KolatSystem.is_sleeper(c))


# === Sleeper conditioning ===

func test_sessions_required_is_willpower_x3() -> void:
	assert_eq(KolatSystem.sessions_required(_char(1, 2)), 6)
	assert_eq(KolatSystem.sessions_required(_char(1, 4)), 12)


func test_progress_per_session() -> void:
	assert_almost_eq(KolatSystem.progress_per_session(_char(1, 2)), 100.0 / 6.0, 0.001)


func test_complete_conditioning_installs_fields_and_costs_honor() -> void:
	var dream := _char(10); dream.honor = 5.0
	var target := _char(11, 2)
	KolatSystem.complete_conditioning(target, dream, "the river runs red", {"need": "ELIMINATE", "target_npc_id": 99})
	assert_eq(target.trigger_phrase, "the river runs red")
	assert_eq(target.sleeper_command.get("target_npc_id"), 99)
	assert_eq(target.conditioning_stability, 100.0)
	assert_eq(target.sleeper_contact_overdue, 0)
	assert_true(target.active_sleeper_command.is_empty(), "dormant on install")
	assert_almost_eq(dream.honor, 2.0, 0.001, "−3.0 conditioning Honor cost applied once")


func test_conditioning_session_strong_master_progresses() -> void:
	# Overwhelming Dream Master (high Temptation+Int) vs weak-willed target.
	var dream := _char(10); dream.skills = {"Temptation": 8}; dream.intelligence = 5
	var target := _char(11, 1)
	var progressed: int = 0
	for seed: int in range(20):
		if KolatSystem.resolve_conditioning_session(dream, target, DiceEngine.new(seed))["progressed"]:
			progressed += 1
	assert_gt(progressed, 10, "a strong conditioner usually progresses")


func test_seasonal_degradation_and_maintenance() -> void:
	var s := _char(11, 2); s.conditioning_stability = 100.0; s.sleeper_contact_overdue = 0
	KolatSystem.degrade_sleeper_seasonal(s, 90)
	assert_eq(s.conditioning_stability, 95.0, "−5 per season")
	assert_eq(s.sleeper_contact_overdue, 90)
	KolatSystem.maintain_sleeper_contact(s)
	assert_eq(s.conditioning_stability, 100.0, "+10 restore, capped at 100")
	assert_eq(s.sleeper_contact_overdue, 0, "contact resets overdue")


func test_degradation_skips_activated_sleeper() -> void:
	var s := _char(11, 2); s.conditioning_stability = 60.0
	s.active_sleeper_command = {"need": "ELIMINATE"}
	KolatSystem.degrade_sleeper_seasonal(s, 90)
	assert_eq(s.conditioning_stability, 60.0, "stability not evaluated once activated")


func test_activation_gating() -> void:
	var s := _char(11, 2)
	KolatSystem.complete_conditioning(s, _char(10), "phrase here", {"need": "DISCLOSE"})
	# Right phrase, dormant, stability 100 → activates.
	var r := KolatSystem.activate_sleeper(s, "phrase here")
	assert_true(r["ok"])
	assert_false(s.active_sleeper_command.is_empty(), "command populated")
	# Cannot re-activate while already executing.
	assert_false(KolatSystem.activate_sleeper(s, "phrase here")["ok"])


func test_activation_phrase_mismatch() -> void:
	var s := _char(11, 2)
	KolatSystem.complete_conditioning(s, _char(10), "correct phrase", {"need": "X"})
	var r := KolatSystem.activate_sleeper(s, "wrong words")
	assert_false(r["ok"])
	assert_eq(r["reason"], "phrase_mismatch")


func test_activation_blocked_below_stability_floor() -> void:
	var s := _char(11, 2)
	KolatSystem.complete_conditioning(s, _char(10), "p", {"need": "X"})
	s.conditioning_stability = 40.0  # below 50 floor
	assert_false(KolatSystem.can_activate_sleeper(s))
	assert_false(KolatSystem.activate_sleeper(s, "p")["ok"])


func test_command_phrase_word_limit() -> void:
	assert_true(KolatSystem.is_valid_command_phrase("kill the lord now please"))  # 5 words
	assert_false(KolatSystem.is_valid_command_phrase("kill the lord now please immediately"))  # 6
	assert_false(KolatSystem.is_valid_command_phrase("   "))


# === Koku pipeline ===

func test_launder_moves_dirty_to_clean() -> void:
	var coin := _char(20)
	KolatSystem.add_dirty_koku(coin, 12)
	assert_eq(KolatSystem.launder_koku(coin), 5, "5 per AP")
	assert_eq(coin.dirty_koku, 7)
	assert_eq(coin.kolat_koku, 5)
	KolatSystem.launder_koku(coin)
	KolatSystem.launder_koku(coin)  # only 2 left
	assert_eq(coin.dirty_koku, 0)
	assert_eq(coin.kolat_koku, 12)


func test_transfer_to_vault() -> void:
	var coin := _char(20); coin.kolat_koku = 30
	var temple := _temple(100)
	assert_eq(KolatSystem.transfer_to_vault(coin, temple, 25), 25)
	assert_eq(coin.kolat_koku, 5)
	assert_eq(temple.temple_vault_koku, 125)
	assert_eq(KolatSystem.transfer_to_vault(coin, temple, 999), 5, "capped at available")


func test_allocate_from_vault() -> void:
	var temple := _temple(100)
	var master := _char(21)
	assert_eq(KolatSystem.allocate_from_vault(temple, master, 40), 40)
	assert_eq(temple.temple_vault_koku, 60)
	assert_eq(master.operational_koku, 40)
	assert_eq(KolatSystem.allocate_from_vault(temple, master, 999), 0, "no funds → 0 allocated")


func test_vault_threshold() -> void:
	assert_true(KolatSystem.vault_below_threshold(_temple(40)))
	assert_false(KolatSystem.vault_below_threshold(_temple(60)))


# === Disruption funding ===

func test_disruption_costs() -> void:
	assert_eq(KolatSystem.sponsor_insurgency_cost(3), 30)
	assert_eq(KolatSystem.bribe_garrison_cost_per_season(), 5)
	assert_true(KolatSystem.can_fund_disruption(30, 30))
	assert_false(KolatSystem.can_fund_disruption(20, 30))


# === Dead-drop concealment ===

func test_dead_drop_degrades_after_three_visits() -> void:
	var drop := KolatSystem.make_dead_drop(2)
	for i: int in range(3):
		KolatSystem.register_dead_drop_visit(drop)
	assert_eq(drop["concealment"], 2, "first 3 visits free")
	assert_false(drop["abandoned"])
	KolatSystem.register_dead_drop_visit(drop)  # 4th
	assert_eq(drop["concealment"], 1)
	KolatSystem.register_dead_drop_visit(drop)  # 5th → 0 → abandoned
	assert_eq(drop["concealment"], 0)
	assert_true(drop["abandoned"])


func test_dead_drop_season_reset() -> void:
	var drop := KolatSystem.make_dead_drop(3)
	for i: int in range(4):
		KolatSystem.register_dead_drop_visit(drop)
	KolatSystem.reset_dead_drop_season(drop)
	assert_eq(drop["visits_this_season"], 0)


# === Eye contention ===

func test_eye_contention_priority_wins() -> void:
	var winner := KolatSystem.resolve_eye_contention([
		{"npc_id": 1, "priority": 2, "is_tiger": false, "status": 5.0},
		{"npc_id": 2, "priority": 3, "is_tiger": false, "status": 3.0},
	])
	assert_eq(winner, 2, "highest priority wins")


func test_eye_contention_tiger_breaks_tie() -> void:
	var winner := KolatSystem.resolve_eye_contention([
		{"npc_id": 1, "priority": 3, "is_tiger": false, "status": 9.0},
		{"npc_id": 2, "priority": 3, "is_tiger": true, "status": 2.0},
	])
	assert_eq(winner, 2, "Tiger wins a priority tie regardless of Status")


func test_eye_contention_status_breaks_remaining_tie() -> void:
	var winner := KolatSystem.resolve_eye_contention([
		{"npc_id": 1, "priority": 2, "is_tiger": false, "status": 4.0},
		{"npc_id": 2, "priority": 2, "is_tiger": false, "status": 7.0},
	])
	assert_eq(winner, 2, "higher Status wins when priority and Tiger-status tie")
