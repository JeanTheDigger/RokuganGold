extends GutTest
## Tests for ConvictionProcessor — defense hearing through conviction pipeline.


var _dice: DiceEngine


func before_each() -> void:
	_dice = DiceEngine.new()


func _make_char(
	id: int, clan: String, status: float,
	honor: float = 3.5, lord_id: int = -1,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = clan
	c.status = status
	c.honor = honor
	c.lord_id = lord_id
	c.character_name = "Char_%d" % id
	c.physical_location = "zone_a"
	c.skills = {"Sincerity": 3}
	c.rings = {"awareness": 3}
	c.bushido_virtue = Enums.BushidoVirtue.GI
	return c


func _make_record(
	crime_type: Enums.CrimeType,
	case_id: int = 1,
	perp_id: int = 1,
) -> CrimeRecord:
	var r := CrimeSystem.create_crime_record(
		case_id, crime_type, perp_id, "zone_a", 100, 2
	)
	r.legal_status = Enums.LegalStatus.ACCUSED
	r.evidence_total = 45
	return r


func _make_case_entry(case_id: int, evidence: int = 45) -> LegalCaseEntry:
	var e := LegalCaseEntry.new()
	e.crime_record_id = case_id
	e.state = Enums.LegalStatus.ACCUSED
	e.evidence_total = evidence
	return e


# -- Pipeline: basic conviction ----

func test_conviction_for_violence():
	var accused := _make_char(1, "Lion", 3.0, 2.0, 10)
	var lord := _make_char(10, "Lion", 6.0)
	var record := _make_record(Enums.CrimeType.VIOLENCE)

	var case_entry := _make_case_entry(1)
	accused.legal_cases = [case_entry]

	var characters_by_id: Dictionary = {1: accused, 10: lord}
	var lord_map: Dictionary = {1: 10}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var records: Array[CrimeRecord] = [record]

	var results := ConvictionProcessor.process_accused_cases(
		records, characters_by_id, _dice, 200, next_id, topics, lord_map
	)
	assert_gt(results.size(), 0)
	var r: Dictionary = results[0]
	assert_eq(r["case_id"], 1)
	assert_eq(r["accused_id"], 1)


func test_skips_non_accused_records():
	var accused := _make_char(1, "Lion", 3.0, 2.0, 10)
	var lord := _make_char(10, "Lion", 6.0)
	var record := _make_record(Enums.CrimeType.VIOLENCE)
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION

	var characters_by_id: Dictionary = {1: accused, 10: lord}
	var lord_map: Dictionary = {1: 10}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var records: Array[CrimeRecord] = [record]

	var results := ConvictionProcessor.process_accused_cases(
		records, characters_by_id, _dice, 200, next_id, topics, lord_map
	)
	assert_eq(results.size(), 0)


func test_skips_already_convicted():
	var accused := _make_char(1, "Lion", 3.0, 2.0, 10)
	var lord := _make_char(10, "Lion", 6.0)
	var record := _make_record(Enums.CrimeType.VIOLENCE)
	record.ic_day_conviction = 150

	var characters_by_id: Dictionary = {1: accused, 10: lord}
	var lord_map: Dictionary = {1: 10}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var records: Array[CrimeRecord] = [record]

	var results := ConvictionProcessor.process_accused_cases(
		records, characters_by_id, _dice, 200, next_id, topics, lord_map
	)
	assert_eq(results.size(), 0)


# -- Seppuku resolution ----

func test_seppuku_accepted():
	var record := _make_record(Enums.CrimeType.TREASON)
	record.seppuku_offered = true
	var convicted := _make_char(1, "Lion", 3.0)

	var next_id: Array[int] = [200]
	var r := ConvictionProcessor.resolve_seppuku(
		record, convicted, true, 300, next_id
	)
	assert_true(r["applicable"])
	assert_true(r["accepted"])
	assert_true(r["character_dead"])
	assert_true(record.seppuku_accepted)


func test_seppuku_refused():
	var record := _make_record(Enums.CrimeType.TREASON)
	record.seppuku_offered = true
	var convicted := _make_char(1, "Lion", 3.0)

	var next_id: Array[int] = [200]
	var r := ConvictionProcessor.resolve_seppuku(
		record, convicted, false, 300, next_id
	)
	assert_true(r["applicable"])
	assert_false(r["accepted"])
	assert_false(record.seppuku_accepted)
	assert_true(r["exile"])


func test_seppuku_not_applicable_when_not_offered():
	var record := _make_record(Enums.CrimeType.VIOLENCE)
	record.seppuku_offered = false
	var convicted := _make_char(1, "Lion", 3.0)

	var next_id: Array[int] = [200]
	var r := ConvictionProcessor.resolve_seppuku(
		record, convicted, true, 300, next_id
	)
	assert_false(r["applicable"])


# -- Treason: authority block ----

func test_treason_blocked_by_authority():
	var accused := _make_char(1, "Lion", 6.0, 3.5, 10)
	var lord := _make_char(10, "Lion", 4.0)
	var record := _make_record(Enums.CrimeType.TREASON)

	var case_entry := _make_case_entry(1)
	accused.legal_cases = [case_entry]

	var characters_by_id: Dictionary = {1: accused, 10: lord}
	var lord_map: Dictionary = {1: 10}
	var topics: Array[TopicData] = []
	var next_id: Array[int] = [100]
	var records: Array[CrimeRecord] = [record]

	var results := ConvictionProcessor.process_accused_cases(
		records, characters_by_id, _dice, 200, next_id, topics, lord_map
	)
	assert_gt(results.size(), 0)
	assert_eq(results[0]["outcome"], "blocked")
	assert_eq(results[0]["reason"], "insufficient_authority")


# -- Cross-clan disposition ----

func test_cross_clan_consequences():
	var record := _make_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	var accused := _make_char(1, "Scorpion", 3.0)
	var victim := _make_char(2, "Crane", 3.0)

	var r := ConvictionProcessor.apply_cross_clan_consequences(
		record, accused, victim, false
	)
	assert_true(r["applies"])
	assert_lt(r["disposition_hit"], 0)


func test_no_cross_clan_for_same_clan():
	var record := _make_record(Enums.CrimeType.UNSANCTIONED_OPEN_KILLING)
	var accused := _make_char(1, "Lion", 3.0)
	var victim := _make_char(2, "Lion", 3.0)

	var r := ConvictionProcessor.apply_cross_clan_consequences(
		record, accused, victim, false
	)
	assert_false(r["applies"])
