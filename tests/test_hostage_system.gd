extends GutTest
## Tests for HostageSystem per GDD s22.9.


# -- Capture tests ------------------------------------------------------------

func test_capture_hostage():
	var h := HostageSystem.capture_hostage(1, 2, HostageSystem.CaptureSource.SIEGE_SURRENDER, "castle_01", 50)
	assert_eq(h["character_id"], 1)
	assert_eq(h["captor_id"], 2)
	assert_eq(h["source"], HostageSystem.CaptureSource.SIEGE_SURRENDER)
	assert_false(h["released"])
	assert_false(h["escaped"])


# -- Personality gate tests ---------------------------------------------------

func test_bushi_with_stealth_can_escape():
	assert_true(HostageSystem.can_attempt_escape(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
		Enums.SchoolType.BUSHI, 3
	))


func test_courtier_cannot_escape():
	assert_false(HostageSystem.can_attempt_escape(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
		Enums.SchoolType.COURTIER, 5
	))


func test_low_stealth_cannot_escape():
	assert_false(HostageSystem.can_attempt_escape(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.NONE,
		Enums.SchoolType.BUSHI, 2
	))


func test_ishi_committed_cannot_escape():
	assert_false(HostageSystem.can_attempt_escape(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI,
		Enums.SchoolType.BUSHI, 5, true
	))


func test_ishi_not_committed_can_escape():
	assert_true(HostageSystem.can_attempt_escape(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI,
		Enums.SchoolType.BUSHI, 4, false
	))


# -- Capture likelihood tests -------------------------------------------------

func test_yu_less_likely_captured():
	var mod := HostageSystem.get_capture_likelihood_modifier(Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.NONE)
	assert_eq(mod, 0.5)


func test_ishi_less_likely_captured():
	var mod := HostageSystem.get_capture_likelihood_modifier(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.ISHI)
	assert_eq(mod, 0.3)


func test_default_capture_likelihood():
	var mod := HostageSystem.get_capture_likelihood_modifier(Enums.BushidoVirtue.JIN, Enums.ShouridoVirtue.NONE)
	assert_eq(mod, 1.0)


# -- Escape TN tests ----------------------------------------------------------

func test_escape_tn_town():
	assert_eq(HostageSystem.get_escape_tn("town", 0.5, 0.5), 20)


func test_escape_tn_castle():
	assert_eq(HostageSystem.get_escape_tn("castle", 1.0, 1.0), 25)


func test_escape_tn_major_castle():
	assert_eq(HostageSystem.get_escape_tn("major_castle", 2.0, 2.0), 30)


func test_escape_tn_reinforced_garrison():
	# Castle with 2.0 PU garrison (1.0 excess), excess = 2 half-PUs, +4
	assert_eq(HostageSystem.get_escape_tn("castle", 2.0, 1.0), 29)


# -- Escape resolution tests --------------------------------------------------

func test_escape_success():
	var result := HostageSystem.resolve_escape(25, 25)
	assert_true(result["success"])
	assert_false(result["executed"])
	assert_eq(result["family_honor_loss"], -1.0)


func test_escape_failure():
	var result := HostageSystem.resolve_escape(20, 25)
	assert_false(result["success"])
	assert_true(result["executed"])
	assert_false(result["critical_failure"])


func test_escape_critical_failure():
	var result := HostageSystem.resolve_escape(15, 25)
	assert_false(result["success"])
	assert_true(result["executed"])
	assert_true(result["critical_failure"])
	assert_eq(result["family_honor_loss"], -2.0)


# -- Leverage tests -----------------------------------------------------------

func test_leverage_rank5():
	assert_eq(HostageSystem.get_leverage_value(5, false), 8)


func test_leverage_champion_family():
	assert_eq(HostageSystem.get_leverage_value(1, true), 8)


func test_leverage_rank3():
	assert_eq(HostageSystem.get_leverage_value(3, false), 3)


func test_leverage_low_rank():
	assert_eq(HostageSystem.get_leverage_value(2, false), 1)


# -- Release tests ------------------------------------------------------------

func test_release_hostage():
	var h := HostageSystem.capture_hostage(1, 2, HostageSystem.CaptureSource.BATTLE_CAPTURE, "castle_01", 50)
	var result := HostageSystem.release_hostage(h, 200)
	assert_true(h["released"])
	assert_eq(h["released_ic_day"], 200)
	assert_eq(result["character_id"], 1)


# -- Action restriction tests -------------------------------------------------

func test_action_blocked_targets_captor():
	assert_true(HostageSystem.is_action_blocked_for_hostage("CHARM", true))


func test_travel_blocked():
	assert_true(HostageSystem.is_action_blocked_for_hostage("TRAVEL_TO", false))


func test_charm_not_blocked():
	assert_false(HostageSystem.is_action_blocked_for_hostage("CHARM", false))


func test_letter_not_blocked():
	assert_false(HostageSystem.is_action_blocked_for_hostage("WRITE_LETTER", false))


# -- Harm consequences tests --------------------------------------------------

func test_harm_hostage_consequences():
	var c := HostageSystem.harm_hostage_consequences()
	assert_eq(c["honor_loss"], -3.0)
	assert_eq(c["historical_modifier"], "harmed_hostage")
