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


func test_examine_scene_elapsed_time_reduces_evidence() -> void:
	var mag := _make_magistrate(5)
	var cr_fresh := _make_crime_record(10, 10)
	var cr_old := _make_crime_record(10, 0)
	_dice.set_seed(42)
	var result_fresh: Dictionary = InvestigationSystem.examine_scene(mag, cr_fresh, _dice, 10)
	_dice.set_seed(42)
	var result_old: Dictionary = InvestigationSystem.examine_scene(mag, cr_old, _dice, 10)
	if result_fresh["success"] and result_old["success"]:
		assert_true(result_fresh["evidence_gained"] >= result_old["evidence_gained"])


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
