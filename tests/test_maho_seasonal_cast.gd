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
