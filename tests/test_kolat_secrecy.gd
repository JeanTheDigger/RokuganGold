extends GutTest
## Tests for KolatSecrecy (s54.7i): exposure/awareness scalars, Imperial response
## tiers, and the win condition.


# === Scalar application ===

func test_apply_delta_clamps_0_100() -> void:
	assert_eq(KolatSecrecy.apply_delta(0, -5), 0, "exposure cannot go below 0")
	assert_eq(KolatSecrecy.apply_delta(98, 10), 100, "exposure cannot exceed 100")
	assert_eq(KolatSecrecy.apply_delta(40, KolatSecrecy.EXPOSURE_ORG_ASSASSINATION), 55)


func test_seasonal_decay() -> void:
	assert_eq(KolatSecrecy.apply_seasonal_exposure_decay(10, 0), 8, "−2/season natural decay")
	assert_eq(KolatSecrecy.apply_seasonal_exposure_decay(1, 0), 0, "decay floors at 0")
	# Suppression while aware uses the same numeric (no invented extra amount).
	assert_eq(KolatSecrecy.apply_seasonal_exposure_decay(10, 50), 8)


# === Imperial response ===

func test_response_active_threshold() -> void:
	assert_false(KolatSecrecy.is_response_active(29))
	assert_true(KolatSecrecy.is_response_active(30), "fires at 30")
	assert_true(KolatSecrecy.is_response_active(95))


func test_response_tiers() -> void:
	assert_eq(KolatSecrecy.response_tier(0), KolatSecrecy.ResponseTier.UNAWARE)
	assert_eq(KolatSecrecy.response_tier(29), KolatSecrecy.ResponseTier.UNAWARE)
	assert_eq(KolatSecrecy.response_tier(30), KolatSecrecy.ResponseTier.SUSPICIOUS)
	assert_eq(KolatSecrecy.response_tier(50), KolatSecrecy.ResponseTier.CONFIRMED_THREAT)
	assert_eq(KolatSecrecy.response_tier(70), KolatSecrecy.ResponseTier.PARTIALLY_MAPPED)
	assert_eq(KolatSecrecy.response_tier(90), KolatSecrecy.ResponseTier.SIGNIFICANTLY_MAPPED)
	assert_eq(KolatSecrecy.response_tier(100), KolatSecrecy.ResponseTier.FULL_KNOWLEDGE)


# === Win condition ===

func _candidate(role: String) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.role_position = role
	return c


func test_win_condition_all_met() -> void:
	var cand := _candidate("Regent")
	# Installed one full IC year ago (360 days), awareness below ceiling.
	assert_true(KolatSecrecy.check_win_condition(cand, 0, 360, 69),
		"Regent held one IC year with awareness < 70 wins")


func test_win_blocked_by_short_tenure() -> void:
	var cand := _candidate("Imperial Advisor")
	assert_false(KolatSecrecy.check_win_condition(cand, 0, 359, 0),
		"one day short of a full IC year does not win")


func test_win_blocked_by_awareness_ceiling() -> void:
	var cand := _candidate("Regent")
	assert_false(KolatSecrecy.check_win_condition(cand, 0, 360, 70),
		"awareness at the ceiling blocks the win")


func test_win_blocked_by_wrong_role() -> void:
	var cand := _candidate("Provincial Daimyo")
	assert_false(KolatSecrecy.check_win_condition(cand, 0, 720, 0),
		"a non-Imperial-proximity role cannot win")


func test_win_blocked_when_compromised() -> void:
	var cand := _candidate("Voice of the Emperor")
	cand.special_data["kolat_candidate_pipeline_stage"] = "compromised"
	assert_false(KolatSecrecy.check_win_condition(cand, 0, 360, 0),
		"a discovered (compromised) candidate cannot win")


func test_win_blocked_when_not_installed() -> void:
	var cand := _candidate("Regent")
	assert_false(KolatSecrecy.check_win_condition(cand, -1, 9999, 0),
		"a candidate never installed cannot win")


func test_win_blocked_when_dead() -> void:
	var cand := _candidate("Regent")
	cand.wounds_taken = 9999
	assert_false(KolatSecrecy.check_win_condition(cand, 0, 360, 0),
		"a dead candidate cannot win")
