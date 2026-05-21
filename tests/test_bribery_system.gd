extends GutTest
## Tests for BriberySystem per GDD s11.3.11.


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


func _make_character(virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE, shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.bushido_virtue = virtue
	c.shourido_virtue = shourido
	c.skills = {"Temptation": 3, "Etiquette": 3}
	c.emphases = {}
	c.awareness = 3
	c.willpower = 3
	c.perception = 3
	c.honor = 5.0
	c.wounds_taken = 0
	return c


func _make_magistrate(honor: float = 7.0) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 2
	c.bushido_virtue = Enums.BushidoVirtue.GI
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.skills = {"Etiquette": 4, "Temptation": 1}
	c.emphases = {}
	c.awareness = 3
	c.willpower = 4
	c.perception = 3
	c.honor = honor
	c.wounds_taken = 0
	return c


func _make_crime_record() -> CrimeRecord:
	var r := CrimeRecord.new()
	r.case_id = 1
	r.crime_type = Enums.CrimeType.SKIMMING
	r.perpetrator_id = 1
	r.evidence_total = 30
	return r


# -- Personality Gates (s11.3.11g) ----

func test_gi_always_blocked():
	var c := _make_character(Enums.BushidoVirtue.GI)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))


func test_makoto_always_blocked():
	var c := _make_character(Enums.BushidoVirtue.MAKOTO)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))


func test_meiyo_always_blocked():
	var c := _make_character(Enums.BushidoVirtue.MEIYO)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))


func test_seigyo_always_allowed():
	var c := _make_character(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	assert_true(BriberySystem.can_attempt_bribe(c, false, false, false))


func test_ketsui_always_allowed():
	var c := _make_character(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KETSUI)
	assert_true(BriberySystem.can_attempt_bribe(c, false, false, false))


func test_jin_blocked_unless_protecting():
	var c := _make_character(Enums.BushidoVirtue.JIN)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))
	assert_true(BriberySystem.can_attempt_bribe(c, true, false, false))


func test_yu_blocked_unless_protecting():
	var c := _make_character(Enums.BushidoVirtue.YU)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))
	assert_true(BriberySystem.can_attempt_bribe(c, true, false, false))


func test_rei_blocked_unless_intermediary():
	var c := _make_character(Enums.BushidoVirtue.REI)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))
	assert_true(BriberySystem.can_attempt_bribe(c, false, false, true))


func test_chugi_blocked_unless_lord_assigned():
	var c := _make_character(Enums.BushidoVirtue.CHUGI)
	assert_false(BriberySystem.can_attempt_bribe(c, false, false, false))
	assert_true(BriberySystem.can_attempt_bribe(c, false, true, false))


# -- Resistance TN ----

func test_honor_7_gives_tn_35():
	var mag := _make_magistrate(7.0)
	assert_eq(BriberySystem.calculate_resistance_tn(mag), 35)


func test_honor_3_gives_tn_15():
	var mag := _make_magistrate(3.0)
	assert_eq(BriberySystem.calculate_resistance_tn(mag), 15)


func test_honor_1_gives_tn_5():
	var mag := _make_magistrate(1.5)
	assert_eq(BriberySystem.calculate_resistance_tn(mag), 5)


# -- Bribe Attempt ----

func test_attempt_bribe_returns_valid_result():
	var briber := _make_character(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	briber.skills["Temptation"] = 5
	var mag := _make_magistrate(3.0)
	var result := BriberySystem.attempt_bribe(briber, mag, _dice, 10)
	assert_true(result["result"] == BriberySystem.BribeResult.ACCEPTED or result["result"] == BriberySystem.BribeResult.REFUSED)
	assert_true(result.has("briber_total"))
	assert_true(result.has("magistrate_total"))


func test_blocked_personality_returns_blocked():
	var briber := _make_character(Enums.BushidoVirtue.GI)
	var mag := _make_magistrate(3.0)
	var result := BriberySystem.attempt_bribe(briber, mag, _dice)
	assert_eq(result["result"], BriberySystem.BribeResult.BLOCKED_BY_PERSONALITY)
	assert_eq(result["evidence_gained"], 0)


func test_refused_bribe_gives_evidence():
	var briber := _make_character(Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO)
	briber.skills["Temptation"] = 1
	briber.awareness = 1
	var mag := _make_magistrate(9.0)
	mag.willpower = 5
	_dice.set_seed(1)
	var result := BriberySystem.attempt_bribe(briber, mag, _dice)
	if result["result"] == BriberySystem.BribeResult.REFUSED:
		assert_eq(result["evidence_gained"], 15)


# -- Apply Bribe Accepted ----

func test_apply_accepted_clears_evidence():
	var mag := _make_magistrate(5.0)
	var cr := _make_crime_record()
	var result := BriberySystem.apply_bribe_accepted(mag, cr)
	assert_eq(cr.evidence_total, 0)
	assert_eq(cr.legal_status, Enums.LegalStatus.CLEAR)
	assert_eq(result["evidence_suppressed"], 30)
	assert_true(result["creates_secret"])
	assert_eq(result["secret_tier"], 1)


func test_apply_accepted_honor_loss():
	var mag := _make_magistrate(5.0)
	var initial_honor: float = mag.honor
	var cr := _make_crime_record()
	var result := BriberySystem.apply_bribe_accepted(mag, cr)
	assert_almost_eq(mag.honor, initial_honor + result["honor_loss"], 0.01)


# -- Apply Bribe Refused ----

func test_apply_refused_adds_evidence():
	var cr := _make_crime_record()
	var initial: int = cr.evidence_total
	var result := BriberySystem.apply_bribe_refused(cr)
	assert_eq(cr.evidence_total, initial + 15)
	assert_eq(result["evidence_added"], 15)
	assert_true(result["generates_separate_offense"])


func test_apply_refused_can_trigger_accusation():
	var cr := _make_crime_record()
	cr.evidence_total = 30
	var result := BriberySystem.apply_bribe_refused(cr)
	assert_eq(cr.evidence_total, 45)
	assert_eq(result["threshold_crossed"], "accusation")
	assert_eq(cr.legal_status, Enums.LegalStatus.ACCUSED)


# -- Evidence Destruction (s11.3.11h) ----

func test_destroy_physical_evidence():
	var cr := _make_crime_record()
	cr.evidence_total = 50
	var result := BriberySystem.destroy_physical_evidence(cr, 20)
	assert_eq(cr.evidence_total, 30)
	assert_eq(result["evidence_removed"], 20)
	assert_true(result["case_stalled"])


func test_destroy_evidence_cannot_go_negative():
	var cr := _make_crime_record()
	cr.evidence_total = 10
	var result := BriberySystem.destroy_physical_evidence(cr, 50)
	assert_eq(cr.evidence_total, 0)
	assert_eq(result["evidence_removed"], 10)


func test_destroy_large_evidence_stalls_case():
	var cr := _make_crime_record()
	cr.evidence_total = 45
	var result := BriberySystem.destroy_physical_evidence(cr, 10)
	assert_eq(cr.evidence_total, 35)
	assert_true(result["case_stalled"], "Case below accusation threshold = stalled")


func test_destroy_small_evidence_doesnt_stall():
	var cr := _make_crime_record()
	cr.evidence_total = 50
	var result := BriberySystem.destroy_physical_evidence(cr, 5)
	assert_eq(cr.evidence_total, 45)
	assert_false(result["case_stalled"])


# -- Report Behavior (s11.3.11k) ----

func test_gi_magistrate_reports_publicly():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.GI
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.REPORT_PUBLIC)


func test_yu_magistrate_reports_loud():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.YU
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.REPORT_LOUD)


func test_chugi_magistrate_reports_privately():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.CHUGI
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.REPORT_PRIVATE)


func test_seigyo_magistrate_holds_leverage():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.NONE
	mag.shourido_virtue = Enums.ShouridoVirtue.SEIGYO
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.HOLD_LEVERAGE)


func test_dosatsu_magistrate_holds_intelligence():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.NONE
	mag.shourido_virtue = Enums.ShouridoVirtue.DOSATSU
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.HOLD_INTELLIGENCE)


func test_meiyo_magistrate_reports_formally():
	var mag := _make_magistrate()
	mag.bushido_virtue = Enums.BushidoVirtue.MEIYO
	assert_eq(BriberySystem.get_report_behavior(mag), BriberySystem.ReportBehavior.REPORT_FORMAL)


func test_public_reports_generate_topic():
	assert_true(BriberySystem.generates_public_topic(BriberySystem.ReportBehavior.REPORT_PUBLIC))
	assert_true(BriberySystem.generates_public_topic(BriberySystem.ReportBehavior.REPORT_LOUD))
	assert_false(BriberySystem.generates_public_topic(BriberySystem.ReportBehavior.REPORT_PRIVATE))
	assert_false(BriberySystem.generates_public_topic(BriberySystem.ReportBehavior.HOLD_LEVERAGE))


# -- Bribery Evaluation Trigger ----

func test_should_evaluate_at_threshold():
	assert_true(BriberySystem.should_evaluate_bribery(25))
	assert_true(BriberySystem.should_evaluate_bribery(30))


func test_should_not_evaluate_below_threshold():
	assert_false(BriberySystem.should_evaluate_bribery(24))
	assert_false(BriberySystem.should_evaluate_bribery(0))
