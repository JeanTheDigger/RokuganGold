extends GutTest
## Seasonal Bloodspeaker maho cast pass (s43, owner-authorized 2026-06-09).

func _char(id: int, loc: String, taint: float, pc: bool = false) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.physical_location = loc
	c.taint = taint
	c.stamina = 3; c.willpower = 3
	c.agility = 3; c.intelligence = 3
	c.reflexes = 3; c.awareness = 3
	c.strength = 3; c.perception = 3
	c.is_pc = pc
	return c


func _cell(pid: int, state: int) -> BloodspeakerCellData:
	var cell := BloodspeakerCellData.new()
	cell.cell_id = 1
	cell.province_id = pid
	cell.state = state
	return cell


func _prov(pid: int) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.province_taint_level = 0.0
	return p


# -- caster selection --

func test_prefers_existing_affiliate() -> void:
	var a := _char(1, "100", 0.0); a.cult_affiliation = true
	var b := _char(2, "100", 5.0)
	var caster := DayOrchestrator._select_or_corrupt_maho_caster([a, b])
	assert_eq(caster.character_id, 1, "existing affiliate chosen over more-tainted non-member")


func test_corrupts_most_tainted() -> void:
	var a := _char(1, "100", 1.0)
	var b := _char(2, "100", 3.0)
	var caster := DayOrchestrator._select_or_corrupt_maho_caster([a, b])
	assert_eq(caster.character_id, 2, "most-tainted corrupted")
	assert_true(b.cult_affiliation, "corruption sets cult_affiliation")


func test_skips_pc_for_corruption() -> void:
	var pc := _char(1, "100", 9.0, true)
	var caster := DayOrchestrator._select_or_corrupt_maho_caster([pc])
	assert_null(caster, "PCs are never auto-corrupted")
	assert_false(pc.cult_affiliation)


func test_no_caster_when_untainted() -> void:
	var a := _char(1, "100", 0.0)
	assert_null(DayOrchestrator._select_or_corrupt_maho_caster([a]))


# -- full seasonal pass --

func test_active_cell_casts() -> void:
	var caster := _char(1, "100", 2.0)
	var prov := _prov(5)
	var crime_records: Array = []
	var casts := DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.ACTIVE)], {5: prov}, [caster],
		{100: 5}, crime_records, [1], DiceEngine.new(7), 10)
	assert_eq(casts.size(), 1, "active cell casts once")
	assert_gt(prov.province_taint_level, 0.0, "PTL raised by cast")
	assert_eq(crime_records.size(), 1, "MAHO crime record created")
	assert_eq(crime_records[0].crime_type, Enums.CrimeType.MAHO)
	assert_true(caster.cult_affiliation, "caster corrupted into cult")


func test_dormant_cell_does_not_cast() -> void:
	var caster := _char(1, "100", 2.0)
	var crime_records: Array = []
	var casts := DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.DORMANT)], {5: _prov(5)}, [caster],
		{100: 5}, crime_records, [1], DiceEngine.new(7), 10)
	assert_eq(casts.size(), 0, "dormant cell casts nothing")
	assert_eq(crime_records.size(), 0)


func test_no_tainted_member_no_cast() -> void:
	var clean := _char(1, "100", 0.0)
	var crime_records: Array = []
	var casts := DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.ACTIVE)], {5: _prov(5)}, [clean],
		{100: 5}, crime_records, [1], DiceEngine.new(7), 10)
	assert_eq(casts.size(), 0, "no corruptible member → no cast")


# -- detection loop closure (Channel 2): cast → crime record → discovery --

func _weak_caster(id: int, loc: String) -> L5RCharacterData:
	var c := _char(id, loc, 2.0)
	c.agility = 1; c.stamina = 1; c.willpower = 1
	c.reflexes = 1; c.awareness = 1; c.intelligence = 1
	c.strength = 1; c.perception = 1
	c.skills = {}  # Stealth 0 → low blood-evidence concealment TN
	return c


func test_cast_then_province_investigation_discovers_blood_evidence() -> void:
	var caster := _weak_caster(1, "100")
	var prov := _prov(5)
	var crime_records: Array = []
	var dice := DiceEngine.new(7)
	DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.ACTIVE)], {5: prov}, [caster],
		{100: 5}, crime_records, [1], dice, 10)
	assert_eq(crime_records.size(), 1, "cast created a MAHO crime record")
	assert_gt(crime_records[0].concealment_tn, 0, "blood evidence has a concealment TN")
	assert_eq(crime_records[0].location, "100", "evidence located at the cast settlement")

	# A skilled magistrate co-located at the cast settlement investigates the province.
	var mag := _char(2, "100", 0.0)
	mag.skills = {"Investigation": 8}
	mag.perception = 8
	mag.lord_id = -1
	var topics: Array = []
	var results: Array = [{
		"action_id": "INVESTIGATE_PROVINCE",
		"success": true,
		"character_id": 2,
		"effects": {},
	}]
	DayOrchestrator._process_blood_evidence_discovery(
		results, crime_records, {2: mag}, topics, [200], 12, dice)

	var found := false
	for t: TopicData in topics:
		if t.slug == "blood_evidence_%d" % crime_records[0].case_id:
			found = true
	assert_true(found, "co-located magistrate's province investigation discovers the blood evidence")
