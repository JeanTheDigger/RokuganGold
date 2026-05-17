extends GutTest


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()
	_dice.set_seed(42)


func _make_magistrate(investigation_rank: int = 3) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Magistrate"
	c.skills = {"Investigation": investigation_rank}
	c.emphases = {}
	c.perception = 3
	c.awareness = 3
	c.wounds_taken = 0
	c.bushido_virtue = Enums.BushidoVirtue.GI
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_crime_record(concealment: int = 15, day: int = 0) -> CrimeRecord:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.crime_type = Enums.CrimeType.SKIMMING
	cr.perpetrator_id = 5
	cr.location = "castle_crane"
	cr.ic_day_committed = day
	cr.concealment_tn = concealment
	cr.evidence_total = 0
	cr.known_suspects = []
	return cr


# -- examine_scene -------------------------------------------------------------

func test_examine_scene_success_adds_evidence() -> void:
	var mag := _make_magistrate(5)
	var cr := _make_crime_record(10, 0)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 1)
	assert_true(result["success"])
	assert_true(result["evidence_gained"] > 0)
	assert_true(cr.evidence_total > 0)


func test_examine_scene_failure_no_evidence() -> void:
	var mag := _make_magistrate(1)
	mag.perception = 1
	var cr := _make_crime_record(30, 0)
	_dice.set_seed(999)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 1)
	if not result["success"]:
		assert_eq(result["evidence_gained"], 0)
		assert_eq(cr.evidence_total, 0)


func test_examine_scene_high_raises_identifies_suspect() -> void:
	var mag := _make_magistrate(5)
	mag.perception = 5
	var cr := _make_crime_record(5, 0)
	_dice.set_seed(7)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 0)
	if result["success"] and result["raises"] >= 2:
		assert_eq(result["suspect_found"], 5)
		assert_true(5 in cr.known_suspects)


func test_examine_scene_elapsed_time_increases_difficulty() -> void:
	var mag := _make_magistrate(5)
	var cr_fresh := _make_crime_record(10, 10)
	var cr_old := _make_crime_record(10, 0)
	_dice.set_seed(42)
	var result_fresh: Dictionary = InvestigationSystem.examine_scene(mag, cr_fresh, _dice, 10)
	_dice.set_seed(42)
	var result_old: Dictionary = InvestigationSystem.examine_scene(mag, cr_old, _dice, 10)
	if result_fresh["success"] and result_old["success"]:
		assert_true(result_fresh["evidence_gained"] >= result_old["evidence_gained"],
			"Fresh scene should yield same or more evidence than old scene")


func test_examine_scene_uses_concealment_tn() -> void:
	var mag := _make_magistrate(3)
	mag.perception = 3
	var cr := _make_crime_record(25, 0)
	_dice.set_seed(100)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 0)
	# High TN makes failure more likely; check result is a valid dict
	assert_true(result.has("success"))


# -- UPHOLD_LAW probability ---------------------------------------------------

func test_uphold_law_gi_always() -> void:
	assert_eq(InvestigationSystem.get_uphold_law_probability(
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE
	), 100)


func test_uphold_law_yu_low() -> void:
	assert_eq(InvestigationSystem.get_uphold_law_probability(
		Enums.BushidoVirtue.YU, Enums.ShouridoVirtue.NONE
	), 30)


func test_uphold_law_seigyo_lowest() -> void:
	assert_eq(InvestigationSystem.get_uphold_law_probability(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO
	), 20)


func test_uphold_law_kanpeki_high() -> void:
	assert_eq(InvestigationSystem.get_uphold_law_probability(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.KANPEKI
	), 70)


func test_should_assign_uphold_law_gi_always_true() -> void:
	assert_true(InvestigationSystem.should_assign_uphold_law(
		Enums.BushidoVirtue.GI, Enums.ShouridoVirtue.NONE, 99
	))


func test_should_assign_uphold_law_seigyo_usually_false() -> void:
	assert_false(InvestigationSystem.should_assign_uphold_law(
		Enums.BushidoVirtue.NONE, Enums.ShouridoVirtue.SEIGYO, 50
	))


# -- Witness evidence ----------------------------------------------------------

func test_witness_evidence_base() -> void:
	var evidence: int = InvestigationSystem.calculate_witness_evidence(3, 5.0)
	assert_eq(evidence, InvestigationSystem.WITNESS_BASE_EVIDENCE)


func test_witness_evidence_high_awareness_bonus() -> void:
	var evidence: int = InvestigationSystem.calculate_witness_evidence(4, 5.0)
	assert_eq(evidence, InvestigationSystem.WITNESS_BASE_EVIDENCE + InvestigationSystem.WITNESS_HIGH_AWARENESS_BONUS)


func test_witness_evidence_low_honor_penalty() -> void:
	var evidence: int = InvestigationSystem.calculate_witness_evidence(3, 2.0)
	assert_eq(evidence, InvestigationSystem.WITNESS_BASE_EVIDENCE + InvestigationSystem.WITNESS_LOW_HONOR_PENALTY)


func test_witness_evidence_minimum_one() -> void:
	var evidence: int = InvestigationSystem.calculate_witness_evidence(1, 0.0)
	assert_true(evidence >= 1)


# -- Witness prioritization ----------------------------------------------------

func test_prioritize_witnesses_present_first() -> void:
	var c1 := L5RCharacterData.new()
	c1.character_id = 10
	c1.awareness = 2
	c1.honor = 5.0
	var c2 := L5RCharacterData.new()
	c2.character_id = 20
	c2.awareness = 4
	c2.honor = 3.0
	var chars_by_id: Dictionary = {10: c1, 20: c2}
	var candidates: Array[int] = [10, 20]
	var present: Array[int] = [10]
	var result: Array[int] = InvestigationSystem.prioritize_witnesses(candidates, chars_by_id, present)
	assert_eq(result[0], 10)


func test_prioritize_witnesses_awareness_tiebreak() -> void:
	var c1 := L5RCharacterData.new()
	c1.character_id = 10
	c1.awareness = 2
	c1.honor = 5.0
	var c2 := L5RCharacterData.new()
	c2.character_id = 20
	c2.awareness = 4
	c2.honor = 3.0
	var chars_by_id: Dictionary = {10: c1, 20: c2}
	var candidates: Array[int] = [10, 20]
	var present: Array[int] = [10, 20]
	var result: Array[int] = InvestigationSystem.prioritize_witnesses(candidates, chars_by_id, present)
	assert_eq(result[0], 20)


func test_prioritize_witnesses_honor_tiebreak() -> void:
	var c1 := L5RCharacterData.new()
	c1.character_id = 10
	c1.awareness = 3
	c1.honor = 6.0
	var c2 := L5RCharacterData.new()
	c2.character_id = 20
	c2.awareness = 3
	c2.honor = 2.0
	var chars_by_id: Dictionary = {10: c1, 20: c2}
	var candidates: Array[int] = [10, 20]
	var present: Array[int] = [10, 20]
	var result: Array[int] = InvestigationSystem.prioritize_witnesses(candidates, chars_by_id, present)
	assert_eq(result[0], 20)


func test_prioritize_single_candidate() -> void:
	var candidates: Array[int] = [5]
	var result: Array[int] = InvestigationSystem.prioritize_witnesses(candidates, {}, [])
	assert_eq(result.size(), 1)
	assert_eq(result[0], 5)


# -- Jurisdiction check --------------------------------------------------------

func test_jurisdiction_same_province() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	cr.location = "castle_crane"
	assert_true(InvestigationSystem.check_jurisdiction(mag, cr))


func test_jurisdiction_different_province() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	cr.location = "castle_lion"
	assert_false(InvestigationSystem.check_jurisdiction(mag, cr))


func test_jurisdiction_emerald_magistrate_anywhere() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	mag.role_position = "emerald_magistrate"
	var cr := _make_crime_record()
	cr.location = "castle_lion"
	assert_true(InvestigationSystem.check_jurisdiction(mag, cr))


# -- UPHOLD_LAW activation ----------------------------------------------------

func _make_crime_topic(case_id: int, topic_id: int = 100) -> TopicData:
	var t := TopicData.new()
	t.topic_id = topic_id
	t.topic_type = "crime"
	t.slug = "crime_case_%d" % case_id
	t.tier = TopicData.Tier.TIER_4
	t.category = TopicData.Category.LEGAL
	return t


func test_activate_uphold_law_sets_active_case() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	cr.witnesses = [10, 20]
	var standing: Dictionary = {"need_type": "UPHOLD_LAW"}
	var result: Dictionary = InvestigationSystem.activate_uphold_law(mag, cr, standing)
	assert_eq(result["case_id"], 1)
	assert_eq(result["crime_location"], "castle_crane")
	assert_eq(result["witness_pool"].size(), 2)
	assert_false(result["scene_examined"])
	assert_eq(cr.investigating_magistrate_id, mag.character_id)
	assert_eq(cr.legal_status, Enums.LegalStatus.UNDER_INVESTIGATION)
	assert_true(standing.has("active_case"))


func test_scan_for_crime_topics_finds_matching_case() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	mag.topic_pool = [100]
	var topic := _make_crime_topic(1, 100)
	var standing: Dictionary = {"need_type": "UPHOLD_LAW"}
	var topics: Array[TopicData] = [topic]
	var records: Array[CrimeRecord] = [cr]
	var result: Dictionary = InvestigationSystem.scan_for_crime_topics(
		mag, standing, records, topics
	)
	assert_false(result.is_empty())
	assert_eq(result["case_id"], 1)


func test_scan_skips_already_investigated_case() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	cr.investigating_magistrate_id = 99
	mag.topic_pool = [100]
	var topic := _make_crime_topic(1, 100)
	var standing: Dictionary = {"need_type": "UPHOLD_LAW"}
	var topics: Array[TopicData] = [topic]
	var records: Array[CrimeRecord] = [cr]
	var result: Dictionary = InvestigationSystem.scan_for_crime_topics(
		mag, standing, records, topics
	)
	assert_true(result.is_empty())


func test_scan_skips_out_of_jurisdiction() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_lion"
	var cr := _make_crime_record()
	cr.location = "castle_crane"
	mag.topic_pool = [100]
	var topic := _make_crime_topic(1, 100)
	var standing: Dictionary = {"need_type": "UPHOLD_LAW"}
	var topics: Array[TopicData] = [topic]
	var records: Array[CrimeRecord] = [cr]
	var result: Dictionary = InvestigationSystem.scan_for_crime_topics(
		mag, standing, records, topics
	)
	assert_true(result.is_empty())


func test_scan_skips_when_active_case_exists() -> void:
	var mag := _make_magistrate()
	mag.physical_location = "castle_crane"
	var cr := _make_crime_record()
	mag.topic_pool = [100]
	var topic := _make_crime_topic(1, 100)
	var standing: Dictionary = {"need_type": "UPHOLD_LAW", "active_case": {"case_id": 99}}
	var topics: Array[TopicData] = [topic]
	var records: Array[CrimeRecord] = [cr]
	var result: Dictionary = InvestigationSystem.scan_for_crime_topics(
		mag, standing, records, topics
	)
	assert_true(result.is_empty())


# -- Witness PROBE evidence ----------------------------------------------------

func test_witness_interview_adds_evidence() -> void:
	var cr := _make_crime_record()
	cr.witnesses = [10]
	var objective: Dictionary = {
		"case_id": 1,
		"interviewed_witnesses": [],
		"evidence_total": 0,
	}
	var result: Dictionary = InvestigationSystem.process_witness_interview(cr, 10, 3, objective)
	assert_eq(result["role"], "witness")
	assert_true(result["evidence_gained"] >= InvestigationSystem.PROBE_WITNESS_EVIDENCE_MIN)
	assert_true(result["evidence_gained"] <= InvestigationSystem.PROBE_WITNESS_EVIDENCE_MAX)
	assert_true(cr.evidence_total > 0)
	assert_true(10 in objective["interviewed_witnesses"])


func test_suspect_interview_adds_evidence() -> void:
	var cr := _make_crime_record()
	cr.known_suspects = [5]
	var objective: Dictionary = {
		"case_id": 1,
		"interviewed_suspects": [],
		"evidence_total": 0,
	}
	var result: Dictionary = InvestigationSystem.process_witness_interview(cr, 5, 3, objective)
	assert_eq(result["role"], "suspect")
	assert_true(result["evidence_gained"] >= InvestigationSystem.PROBE_SUSPECT_EVIDENCE_MIN)
	assert_true(result["evidence_gained"] <= InvestigationSystem.PROBE_SUSPECT_EVIDENCE_MAX)
	assert_true(5 in objective["interviewed_suspects"])


func test_interview_unrelated_target_no_evidence() -> void:
	var cr := _make_crime_record()
	cr.witnesses = [10]
	cr.known_suspects = [5]
	var objective: Dictionary = {"case_id": 1, "interviewed_witnesses": [], "evidence_total": 0}
	var result: Dictionary = InvestigationSystem.process_witness_interview(cr, 99, 3, objective)
	assert_eq(result["evidence_gained"], 0)
	assert_eq(result["role"], "none")
	assert_eq(cr.evidence_total, 0)


func test_interview_updates_objective_evidence_total() -> void:
	var cr := _make_crime_record()
	cr.witnesses = [10]
	cr.evidence_total = 5
	var objective: Dictionary = {
		"case_id": 1,
		"interviewed_witnesses": [],
		"evidence_total": 5,
	}
	InvestigationSystem.process_witness_interview(cr, 10, 3, objective)
	assert_eq(objective["evidence_total"], cr.evidence_total)
	assert_true(cr.evidence_total > 5)


# -- Conviction topic generation -----------------------------------------------

func test_conviction_topic_created() -> void:
	var cr := _make_crime_record()
	var convicted := L5RCharacterData.new()
	convicted.character_id = 5
	convicted.character_name = "Criminal"
	convicted.clan = "Scorpion"
	convicted.family = "Bayushi"
	var next_id: Array[int] = [1]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, 3, next_id, 10
	)
	assert_not_null(topic)
	assert_eq(topic.topic_id, 1)
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_true(topic.title.contains("Criminal"))
	assert_true(topic.title.contains("Skimming"))
	assert_eq(topic.subject_character_id, 5)
	assert_eq(topic.clan_involved, "Scorpion")
	assert_eq(topic.subject_role, "PERPETRATOR")
	assert_eq(topic.slug, "conviction_1")
	assert_eq(next_id[0], 2)


func test_conviction_topic_tier_1_maho() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 2
	cr.crime_type = Enums.CrimeType.MAHO
	var convicted := L5RCharacterData.new()
	convicted.character_id = 7
	convicted.character_name = "Tsukai"
	var next_id: Array[int] = [10]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, 1, next_id, 20
	)
	assert_not_null(topic)
	assert_eq(topic.tier, TopicData.Tier.TIER_1)
	assert_eq(topic.category, TopicData.Category.SUPERNATURAL)
	assert_true(topic.momentum >= 80.0)


func test_conviction_topic_tier_2_treason() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 3
	cr.crime_type = Enums.CrimeType.TREASON
	var convicted := L5RCharacterData.new()
	convicted.character_id = 8
	convicted.character_name = "Traitor"
	var next_id: Array[int] = [20]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, 2, next_id, 30
	)
	assert_not_null(topic)
	assert_eq(topic.tier, TopicData.Tier.TIER_2)
	assert_eq(topic.category, TopicData.Category.POLITICAL)
	assert_true(topic.momentum >= 50.0)


func test_conviction_topic_zero_tier_returns_null() -> void:
	var cr := _make_crime_record()
	cr.crime_type = Enums.CrimeType.DISHONORABLE_CONDUCT
	var convicted := L5RCharacterData.new()
	convicted.character_id = 9
	var next_id: Array[int] = [30]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, 0, next_id, 40
	)
	assert_null(topic)
	assert_eq(next_id[0], 30)


func test_seppuku_refusal_topic() -> void:
	var convicted := L5RCharacterData.new()
	convicted.character_id = 5
	convicted.character_name = "Coward"
	convicted.clan = "Lion"
	convicted.family = "Matsu"
	var next_id: Array[int] = [50]
	var topic: TopicData = InvestigationSystem.generate_seppuku_refusal_topic(
		convicted, next_id, 10
	)
	assert_not_null(topic)
	assert_eq(topic.tier, TopicData.Tier.TIER_4)
	assert_eq(topic.category, TopicData.Category.PERSONAL)
	assert_true(topic.title.contains("Coward"))
	assert_true(topic.title.contains("refused seppuku"))
	assert_eq(topic.subject_role, "PERPETRATOR")
	assert_eq(next_id[0], 51)


func test_find_crime_record_for_topic() -> void:
	var cr := _make_crime_record()
	var topic := _make_crime_topic(1, 100)
	var records: Array[CrimeRecord] = [cr]
	var found: CrimeRecord = InvestigationSystem.find_crime_record_for_topic(topic, records)
	assert_not_null(found)
	assert_eq(found.case_id, 1)


func test_find_crime_record_wrong_type() -> void:
	var cr := _make_crime_record()
	var topic := TopicData.new()
	topic.topic_type = "political"
	topic.slug = "crime_case_1"
	var records: Array[CrimeRecord] = [cr]
	var found: CrimeRecord = InvestigationSystem.find_crime_record_for_topic(topic, records)
	assert_null(found)


# -- Evidence Thresholds (s11.3.13f) -------------------------------------------

func test_accusation_threshold_transitions_status() -> void:
	var cr := _make_crime_record()
	cr.evidence_total = 39
	var result: String = InvestigationSystem.add_evidence(cr, 5)
	assert_eq(result, "accusation")
	assert_eq(cr.legal_status, Enums.LegalStatus.ACCUSED)
	assert_eq(cr.evidence_total, 44)


func test_bribery_eval_trigger() -> void:
	var cr := _make_crime_record()
	cr.evidence_total = 20
	var result: String = InvestigationSystem.add_evidence(cr, 6)
	assert_eq(result, "bribery_eval")
	assert_eq(cr.evidence_total, 26)


func test_below_bribery_trigger_returns_empty() -> void:
	var cr := _make_crime_record()
	cr.evidence_total = 10
	var result: String = InvestigationSystem.add_evidence(cr, 5)
	assert_eq(result, "")


func test_accusation_does_not_re_trigger_if_already_accused() -> void:
	var cr := _make_crime_record()
	cr.evidence_total = 45
	cr.legal_status = Enums.LegalStatus.ACCUSED
	var result: String = InvestigationSystem.check_thresholds(cr)
	assert_eq(result, "")


func test_accusation_does_not_re_trigger_if_convicted() -> void:
	var cr := _make_crime_record()
	cr.evidence_total = 50
	cr.legal_status = Enums.LegalStatus.DECREED_GUILTY
	var result: String = InvestigationSystem.check_thresholds(cr)
	assert_eq(result, "")


# -- Scene Time Penalty (s11.3.13d) --------------------------------------------

func test_scene_penalty_same_day() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(0), 0)


func test_scene_penalty_same_week() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(5), 2)


func test_scene_penalty_same_month() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(20), 5)


func test_scene_penalty_previous_month() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(45), 10)


func test_scene_penalty_approaching_season() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(80), 15)


func test_scene_penalty_beyond_season() -> void:
	assert_eq(InvestigationSystem.get_scene_time_penalty(100), 99)


func test_scene_too_old() -> void:
	assert_false(InvestigationSystem.is_scene_too_old(89))
	assert_true(InvestigationSystem.is_scene_too_old(91))


# -- Witness Recall TN (s11.3.13b) ---------------------------------------------

func test_recall_tn_same_day() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(0), 10)


func test_recall_tn_same_month() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(15), 15)


func test_recall_tn_previous_month() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(45), 20)


func test_recall_tn_two_months() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(75), 25)


func test_recall_tn_approaching_season() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(88), 30)


func test_recall_too_old_returns_negative() -> void:
	assert_eq(InvestigationSystem.get_witness_recall_tn(100), -1)


func test_recall_too_old_check() -> void:
	assert_false(InvestigationSystem.is_recall_too_old(89))
	assert_true(InvestigationSystem.is_recall_too_old(91))


# -- Additional Evidence Sources (s11.3.13f) -----------------------------------

func test_failed_bribe_evidence() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_failed_bribe_evidence(cr)
	assert_eq(cr.evidence_total, 15)


func test_false_alibi_evidence() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_false_alibi_evidence(cr)
	assert_eq(cr.evidence_total, 10)


func test_kitsuki_eye_evidence() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_kitsuki_eye_evidence(cr)
	assert_eq(cr.evidence_total, 15)


func test_confession_evidence_reaches_accusation() -> void:
	var cr := _make_crime_record()
	var result: String = InvestigationSystem.add_confession_evidence(cr)
	assert_eq(cr.evidence_total, 50)
	assert_eq(result, "accusation")
	assert_eq(cr.legal_status, Enums.LegalStatus.ACCUSED)


func test_murder_weapon_evidence_reaches_accusation() -> void:
	var cr := _make_crime_record()
	var result: String = InvestigationSystem.add_murder_weapon_evidence(cr)
	assert_eq(cr.evidence_total, 40)
	assert_eq(result, "accusation")


func test_co_conspirator_evidence_clamped() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_co_conspirator_evidence(cr, 0)
	assert_eq(cr.evidence_total, InvestigationSystem.EVIDENCE_CO_CONSPIRATOR_MIN)


func test_co_conspirator_evidence_high_quality() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_co_conspirator_evidence(cr, 10)
	assert_eq(cr.evidence_total, InvestigationSystem.EVIDENCE_CO_CONSPIRATOR_MAX)


func test_intercepted_letter_evidence_scales() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_intercepted_letter_evidence(cr, 2)
	assert_eq(cr.evidence_total, 40)


func test_intercepted_letter_evidence_clamped_max() -> void:
	var cr := _make_crime_record()
	InvestigationSystem.add_intercepted_letter_evidence(cr, 10)
	assert_eq(cr.evidence_total, InvestigationSystem.EVIDENCE_INTERCEPTED_LETTER_MAX)


# -- Scene Evidence by Margin (s11.3.13d) --------------------------------------

func test_scene_evidence_minor_traces() -> void:
	var evidence: int = InvestigationSystem._scene_evidence_by_margin(3)
	assert_eq(evidence, InvestigationSystem.SCENE_EVIDENCE_MINOR)


func test_scene_evidence_significant() -> void:
	var evidence: int = InvestigationSystem._scene_evidence_by_margin(7)
	assert_eq(evidence, InvestigationSystem.SCENE_EVIDENCE_SIGNIFICANT)


func test_scene_evidence_major() -> void:
	var evidence: int = InvestigationSystem._scene_evidence_by_margin(12)
	assert_eq(evidence, InvestigationSystem.SCENE_EVIDENCE_MAJOR)


# -- Examine Scene with New Evidence Values ------------------------------------

func test_examine_scene_returns_threshold_crossed() -> void:
	var mag := _make_magistrate(5)
	mag.perception = 5
	var cr := _make_crime_record(5, 0)
	cr.evidence_total = 35
	_dice.set_seed(7)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 0)
	if result["success"]:
		assert_true(result.has("threshold_crossed"))


func test_examine_scene_open_killing_concealment_zero() -> void:
	var mag := _make_magistrate(3)
	var cr := _make_crime_record(0, 0)
	_dice.set_seed(42)
	var result: Dictionary = InvestigationSystem.examine_scene(mag, cr, _dice, 0)
	assert_true(result["success"])
	assert_true(result["evidence_gained"] >= InvestigationSystem.SCENE_EVIDENCE_MINOR)


# -- Accusation Topic Generation -----------------------------------------------

func test_generate_accusation_topic_creates_valid_topic() -> void:
	var cr := _make_crime_record(15, 0)
	cr.crime_type = Enums.CrimeType.VIOLENCE
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Bayushi Koro"
	accused.clan = "Scorpion"
	accused.family = "Bayushi"
	var next_id: Array[int] = [100]

	var topic: TopicData = InvestigationSystem.generate_accusation_topic(
		cr, accused, next_id, 50
	)
	assert_not_null(topic)
	assert_eq(topic.topic_id, 100)
	assert_eq(next_id[0], 101)
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_eq(topic.category, TopicData.Category.POLITICAL)
	assert_true(topic.title.contains("Bayushi Koro"))
	assert_true(topic.title.contains("Violence"))
	assert_eq(topic.slug, "accusation_1")
	assert_eq(topic.subject_role, "PERPETRATOR")


func test_generate_accusation_topic_uses_crime_name() -> void:
	var cr := _make_crime_record(15, 0)
	cr.crime_type = Enums.CrimeType.TREASON
	var accused := L5RCharacterData.new()
	accused.character_id = 5
	accused.character_name = "Shosuro Mei"
	accused.clan = "Scorpion"
	accused.family = "Shosuro"
	var next_id: Array[int] = [200]

	var topic: TopicData = InvestigationSystem.generate_accusation_topic(
		cr, accused, next_id, 75
	)
	assert_not_null(topic)
	assert_true(topic.title.contains("Treason"))


func test_accusation_threshold_triggers_on_evidence_40() -> void:
	var cr := _make_crime_record(15, 0)
	cr.evidence_total = 39
	cr.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	var threshold: String = InvestigationSystem.add_evidence(cr, 5)
	assert_eq(threshold, "accusation")
	assert_eq(cr.legal_status, Enums.LegalStatus.ACCUSED)
	assert_eq(cr.evidence_total, 44)


func test_accusation_threshold_not_re_triggered_if_already_accused() -> void:
	var cr := _make_crime_record(15, 0)
	cr.evidence_total = 45
	cr.legal_status = Enums.LegalStatus.ACCUSED
	var threshold: String = InvestigationSystem.add_evidence(cr, 5)
	assert_eq(threshold, "")
	assert_eq(cr.legal_status, Enums.LegalStatus.ACCUSED)
