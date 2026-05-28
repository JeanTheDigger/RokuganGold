extends GutTest
## Tests for FavorSystem per GDD s12.10.


# -- Helpers ------------------------------------------------------------------

func _make_favor(
	tier: FavorData.FavorTier = FavorData.FavorTier.MINOR,
	favor_type: FavorData.FavorType = FavorData.FavorType.GENERAL,
	creditor: int = 1,
	debtor: int = 2,
	created_day: int = 0,
) -> FavorData:
	var f := FavorData.new()
	f.favor_id = 100
	f.tier = tier
	f.favor_type = favor_type
	f.creditor_id = creditor
	f.debtor_id = debtor
	f.created_ic_day = created_day
	return f


# -- Offering tests -----------------------------------------------------------

func test_offer_creates_favor_with_correct_fields():
	var f := FavorSystem.offer_favor(
		FavorData.FavorType.SPECIFIC,
		FavorData.FavorTier.MODERATE,
		1, 2, 10, "support at court", "OFFER_FAVOR", 5
	)
	assert_eq(f.favor_id, 5)
	assert_eq(f.favor_type, FavorData.FavorType.SPECIFIC)
	assert_eq(f.tier, FavorData.FavorTier.MODERATE)
	assert_eq(f.creditor_id, 1)
	assert_eq(f.debtor_id, 2)
	assert_eq(f.created_ic_day, 10)
	assert_eq(f.terms, "support at court")
	assert_eq(f.invoked, false)


func test_offer_disposition_minor():
	var d := FavorSystem.get_offer_disposition(FavorData.FavorTier.MINOR, 0, false)
	assert_eq(d, 6)


func test_offer_disposition_moderate_with_raises():
	var d := FavorSystem.get_offer_disposition(FavorData.FavorTier.MODERATE, 2, false)
	assert_eq(d, 16)  # 10 + 3*2


func test_offer_disposition_major_with_raises():
	var d := FavorSystem.get_offer_disposition(FavorData.FavorTier.MAJOR, 1, false)
	assert_eq(d, 19)  # 15 + 4*1


func test_offer_disposition_critical_failure():
	var d := FavorSystem.get_offer_disposition(FavorData.FavorTier.MAJOR, 3, true)
	assert_eq(d, -5)


# -- Invoking tests -----------------------------------------------------------

func test_invoke_by_letter():
	var f := _make_favor()
	var result := FavorSystem.invoke_favor(f, FavorData.InvocationMethod.LETTER, 100)
	assert_true(f.invoked)
	assert_eq(f.invoked_ic_day, 100)
	assert_eq(f.response_deadline_ic_day, 190)  # 100 + 90
	assert_eq(result["deadline_ic_day"], 190)


func test_invoke_at_court():
	var f := _make_favor()
	var result := FavorSystem.invoke_favor(f, FavorData.InvocationMethod.COURT, 50)
	assert_eq(f.response_deadline_ic_day, 51)  # 50 + 1
	assert_eq(result["method"], FavorData.InvocationMethod.COURT)


func test_invoke_personal_visit():
	var f := _make_favor()
	FavorSystem.invoke_favor(f, FavorData.InvocationMethod.PERSONAL_VISIT, 200)
	assert_eq(f.response_deadline_ic_day, 290)  # 200 + 90


# -- Honoring tests -----------------------------------------------------------

func test_honor_favor_returns_honor_gain():
	var f := _make_favor()
	f.favor_id = 42
	var result := FavorSystem.honor_favor(f)
	assert_eq(result["honor_change"], 0.1)
	assert_eq(result["debtor_id"], 2)
	assert_true(result["resolved"])


# -- Breaking tests -----------------------------------------------------------

func test_break_minor_favor():
	var f := _make_favor(FavorData.FavorTier.MINOR)
	var result := FavorSystem.break_favor(f)
	assert_eq(result["disposition_change"], -20)
	assert_eq(result["disposition_floor"], -15)
	assert_eq(result["honor_loss"], -0.5)
	assert_eq(result["glory_loss"], 0.0)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_4)


func test_break_moderate_favor():
	var f := _make_favor(FavorData.FavorTier.MODERATE)
	var result := FavorSystem.break_favor(f, [3, 4, 5])
	assert_eq(result["disposition_change"], -35)
	assert_eq(result["disposition_floor"], -30)
	assert_eq(result["honor_loss"], -1.0)
	assert_eq(result["witness_disposition_loss"], -5)
	assert_eq(result["witnesses"], [3, 4, 5])
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_4)


func test_break_major_favor():
	var f := _make_favor(FavorData.FavorTier.MAJOR)
	var result := FavorSystem.break_favor(f)
	assert_eq(result["disposition_change"], -50)
	assert_eq(result["disposition_floor"], -50)
	assert_eq(result["honor_loss"], -2.0)
	assert_eq(result["glory_loss"], -0.5)
	assert_eq(result["witness_disposition_loss"], -10)
	assert_eq(result["topic_tier"], TopicData.Tier.TIER_2)


# -- Dispute tests ------------------------------------------------------------

func test_can_dispute_general_favor():
	var f := _make_favor(FavorData.FavorTier.MINOR, FavorData.FavorType.GENERAL)
	assert_true(FavorSystem.can_dispute(f))


func test_cannot_dispute_specific_favor():
	var f := _make_favor(FavorData.FavorTier.MINOR, FavorData.FavorType.SPECIFIC)
	assert_false(FavorSystem.can_dispute(f))


func test_dispute_creditor_wins():
	var result := FavorSystem.resolve_dispute(30, 20)
	assert_true(result["creditor_wins"])
	assert_false(result["renegotiated"])


func test_dispute_debtor_wins():
	var result := FavorSystem.resolve_dispute(15, 25)
	assert_false(result["creditor_wins"])
	assert_true(result["renegotiated"])


func test_dispute_tie_goes_to_creditor():
	var result := FavorSystem.resolve_dispute(20, 20)
	assert_true(result["creditor_wins"])


# -- Expiration tests ---------------------------------------------------------

func test_minor_expires_after_360_days():
	var f := _make_favor(FavorData.FavorTier.MINOR)
	f.created_ic_day = 0
	assert_false(FavorSystem.check_expiration(f, 359))
	assert_true(FavorSystem.check_expiration(f, 360))


func test_moderate_expires_after_1080_days():
	var f := _make_favor(FavorData.FavorTier.MODERATE)
	f.created_ic_day = 10
	assert_false(FavorSystem.check_expiration(f, 1089))
	assert_true(FavorSystem.check_expiration(f, 1090))


func test_major_never_expires():
	var f := _make_favor(FavorData.FavorTier.MAJOR)
	f.created_ic_day = 0
	assert_false(FavorSystem.check_expiration(f, 99999))


func test_invoked_favor_does_not_expire():
	var f := _make_favor(FavorData.FavorTier.MINOR)
	f.created_ic_day = 0
	f.invoked = true
	assert_false(FavorSystem.check_expiration(f, 500))


func test_process_expirations():
	var f1 := _make_favor(FavorData.FavorTier.MINOR)
	f1.favor_id = 1
	f1.created_ic_day = 0
	var f2 := _make_favor(FavorData.FavorTier.MODERATE)
	f2.favor_id = 2
	f2.created_ic_day = 0
	var f3 := _make_favor(FavorData.FavorTier.MINOR)
	f3.favor_id = 3
	f3.created_ic_day = 300

	var expired := FavorSystem.process_expirations([f1, f2, f3], 400)
	assert_eq(expired.size(), 1)
	assert_eq(expired[0], 1)


# -- Deadline breach tests ----------------------------------------------------

func test_deadline_breach_detected():
	var f := _make_favor()
	FavorSystem.invoke_favor(f, FavorData.InvocationMethod.COURT, 50)
	assert_false(FavorSystem.check_deadline_breach(f, 51))
	assert_true(FavorSystem.check_deadline_breach(f, 52))


func test_uninvoked_favor_no_breach():
	var f := _make_favor()
	assert_false(FavorSystem.check_deadline_breach(f, 9999))


func test_process_deadline_breaches():
	var f1 := _make_favor(FavorData.FavorTier.MODERATE)
	f1.favor_id = 10
	FavorSystem.invoke_favor(f1, FavorData.InvocationMethod.COURT, 50)
	var f2 := _make_favor(FavorData.FavorTier.MINOR)
	f2.favor_id = 11

	var breaches := FavorSystem.process_deadline_breaches([f1, f2], 55)
	assert_eq(breaches.size(), 1)
	assert_eq(breaches[0]["favor_id"], 10)
	assert_eq(breaches[0]["honor_loss"], -1.0)


# -- Death handling tests -----------------------------------------------------

func test_creditor_death_major_favor_inherited():
	var f := _make_favor(FavorData.FavorTier.MAJOR)
	f.favor_id = 20
	f.creditor_id = 5
	var result := FavorSystem.process_creditor_death([f], 5, 8)
	assert_eq(result["inherited"], [20])
	assert_eq(result["dissolved"].size(), 0)
	assert_eq(f.creditor_id, 8)
	assert_eq(f.heir_id, 8)


func test_creditor_death_minor_favor_dissolved():
	var f := _make_favor(FavorData.FavorTier.MINOR)
	f.favor_id = 21
	f.creditor_id = 5
	var result := FavorSystem.process_creditor_death([f], 5, 8)
	assert_eq(result["inherited"].size(), 0)
	assert_eq(result["dissolved"], [21])


func test_creditor_death_major_no_heir_dissolved():
	var f := _make_favor(FavorData.FavorTier.MAJOR)
	f.favor_id = 22
	f.creditor_id = 5
	var result := FavorSystem.process_creditor_death([f], 5, -1)
	assert_eq(result["dissolved"], [22])


func test_debtor_death_dissolves_all():
	var f1 := _make_favor(FavorData.FavorTier.MAJOR)
	f1.favor_id = 30
	f1.debtor_id = 7
	var f2 := _make_favor(FavorData.FavorTier.MINOR)
	f2.favor_id = 31
	f2.debtor_id = 7
	var dissolved := FavorSystem.process_debtor_death([f1, f2], 7)
	assert_eq(dissolved.size(), 2)
	assert_has(dissolved, 30)
	assert_has(dissolved, 31)


# -- Blackmail extraction tests -----------------------------------------------

func test_blackmail_tier1_extracts_major_favors():
	var favors := FavorSystem.extract_blackmail_favor(1, 10, 20, 2, 100, 50)
	assert_eq(favors.size(), 2)
	assert_eq(favors[0].tier, FavorData.FavorTier.MAJOR)
	assert_eq(favors[0].favor_type, FavorData.FavorType.GENERAL)
	assert_true(favors[0].is_blackmail_extracted)
	assert_eq(favors[0].favor_id, 50)
	assert_eq(favors[1].favor_id, 51)


func test_blackmail_tier2_extracts_moderate():
	var favors := FavorSystem.extract_blackmail_favor(2, 10, 20, 1, 100, 60)
	assert_eq(favors.size(), 1)
	assert_eq(favors[0].tier, FavorData.FavorTier.MODERATE)


func test_blackmail_tier3_extracts_minor():
	var favors := FavorSystem.extract_blackmail_favor(3, 10, 20, 3, 100, 70)
	assert_eq(favors.size(), 3)
	assert_eq(favors[0].tier, FavorData.FavorTier.MINOR)


func test_blackmail_tier4_extracts_nothing():
	var favors := FavorSystem.extract_blackmail_favor(4, 10, 20, 2, 100, 80)
	assert_eq(favors.size(), 0)


# -- Supply sharing tests -----------------------------------------------------

func test_supply_sharing_unlocked_by_moderate():
	assert_true(FavorSystem.can_unlock_supply_sharing(FavorData.FavorTier.MODERATE))


func test_supply_sharing_unlocked_by_major():
	assert_true(FavorSystem.can_unlock_supply_sharing(FavorData.FavorTier.MAJOR))


func test_supply_sharing_not_unlocked_by_minor():
	assert_false(FavorSystem.can_unlock_supply_sharing(FavorData.FavorTier.MINOR))


# -- Heir forgiveness tests ---------------------------------------------------

func test_forgive_favor():
	var f := _make_favor(FavorData.FavorTier.MAJOR)
	f.favor_id = 99
	f.creditor_id = 5
	f.debtor_id = 10
	var result := FavorSystem.forgive_favor(f)
	assert_true(result["forgiven"])
	assert_true(result["resolved"])
	assert_eq(result["debtor_id"], 10)
	assert_eq(result["creditor_id"], 5)


# -- Blackmail exposure risk tests --------------------------------------------

func test_blackmail_public_invocation_risky():
	var f := _make_favor()
	f.is_blackmail_extracted = true
	assert_true(FavorSystem.is_blackmail_exposure_risk(f, true))


func test_blackmail_private_invocation_safe():
	var f := _make_favor()
	f.is_blackmail_extracted = true
	assert_false(FavorSystem.is_blackmail_exposure_risk(f, false))


func test_normal_favor_no_exposure_risk():
	var f := _make_favor()
	f.is_blackmail_extracted = false
	assert_false(FavorSystem.is_blackmail_exposure_risk(f, true))


# -- Dispute witness disposition tests ----------------------------------------

func test_dispute_witness_creditor_wins():
	assert_eq(FavorSystem.get_dispute_witness_disposition(true), 0)


func test_dispute_witness_debtor_wins():
	assert_eq(FavorSystem.get_dispute_witness_disposition(false), 0)
