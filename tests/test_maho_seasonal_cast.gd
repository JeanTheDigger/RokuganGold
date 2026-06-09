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


# -- Spreading the Darkness transfer (s43, owner-authorized 2026-06-09) --------

func _cultist(id: int, loc: String, taint: float) -> L5RCharacterData:
	var c := _char(id, loc, taint)
	c.cult_affiliation = true
	return c


func test_shed_source_requires_rank2_cult_member() -> void:
	var low := _cultist(1, "100", 1.5)   # Rank 1 cult member
	var ok := _cultist(2, "100", 2.0)    # Rank 2 cult member
	var clean := _char(3, "100", 4.0)    # heavily tainted but not cult
	assert_null(DayOrchestrator._pick_taint_shed_source([low, clean]),
		"no Rank-2 cult member → no shed source (non-cult taint ignored)")
	var src := DayOrchestrator._pick_taint_shed_source([low, ok, clean])
	assert_eq(src.character_id, 2, "Rank-2 cult member selected")


func test_shed_source_picks_most_tainted() -> void:
	var a := _cultist(1, "100", 2.0)
	var b := _cultist(2, "100", 4.0)
	assert_eq(DayOrchestrator._pick_taint_shed_source([a, b]).character_id, 2)


func test_dump_when_no_named_target() -> void:
	var src := _cultist(1, "100", 3.0)
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		src, src, [src], {}, DiceEngine.new(7))
	assert_eq(res["mode"], "dump", "no co-located named target → dump into a victim")
	# cap = Earth(3) + Insight(1) = 4; transferable = min(4, 3.0-1.0) = 2.0
	assert_almost_eq(src.taint, 1.0, 0.001, "dump drops the source to the 1.0 floor")


func test_dump_respects_floor_partial() -> void:
	var src := _cultist(1, "100", 1.4)
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		src, src, [src], {}, DiceEngine.new(7))
	assert_eq(res["mode"], "dump")
	assert_almost_eq(src.taint, 1.0, 0.001, "only 0.4 transferable above the floor")


func test_no_transfer_at_floor() -> void:
	var src := _cultist(1, "100", 1.0)
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		src, src, [src], {}, DiceEngine.new(7))
	assert_false(res["resolved"], "nothing transferable at the 1.0 floor")
	assert_almost_eq(src.taint, 1.0, 0.001)


func test_push_onto_non_cultist_succeeds() -> void:
	var caster := _cultist(1, "100", 3.0); caster.willpower = 10
	var victim := _char(2, "100", 0.0); victim.willpower = 1
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		caster, caster, [caster, victim], {}, DiceEngine.new(7))
	assert_eq(res["mode"], "push", "valid named target present → push")
	assert_eq(res["target_id"], 2)
	assert_gt(victim.taint, 0.0, "named target receives the pushed Taint")
	assert_almost_eq(caster.taint, 1.0, 0.001, "source drops to the floor")


func test_push_resisted_when_target_wins() -> void:
	var caster := _cultist(1, "100", 3.0); caster.willpower = 1
	var victim := _char(2, "100", 0.0); victim.willpower = 10
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		caster, caster, [caster, victim], {}, DiceEngine.new(7))
	assert_eq(res["mode"], "push_resisted", "recipient wins the contested Willpower roll")
	assert_almost_eq(victim.taint, 0.0, 0.001, "resisted: no Taint pushed")
	assert_almost_eq(caster.taint, 3.0, 0.001, "resisted: source keeps its Taint")


func test_push_prefers_investigator_over_higher_status_leader() -> void:
	var caster := _cultist(1, "100", 3.0); caster.willpower = 10
	var lawman := _char(2, "100", 0.0); lawman.willpower = 1; lawman.status = 2.0
	var lord := _char(3, "100", 0.0); lord.willpower = 1; lord.status = 8.0
	var omap := {2: {"standing": {"need_type": "UPHOLD_LAW"}}}
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		caster, caster, [caster, lawman, lord], omap, DiceEngine.new(7))
	assert_eq(res["mode"], "push")
	assert_eq(res["target_id"], 2,
		"frame the investigator even though the lord has higher Status")


func test_push_excludes_pc_and_cultists() -> void:
	var caster := _cultist(1, "100", 3.0); caster.willpower = 10
	var pc := _char(2, "100", 0.0, true)
	var ally := _cultist(3, "100", 0.0)
	var res := DayOrchestrator._resolve_spreading_the_darkness(
		caster, caster, [caster, pc, ally], {}, DiceEngine.new(7))
	assert_eq(res["mode"], "dump", "PCs and cultists are never push targets → dump")


func test_seasonal_pass_casts_spreading_and_pushes() -> void:
	var caster := _char(1, "100", 2.0); caster.willpower = 10  # Rank 2, Earth supports ML2
	var victim := _char(2, "100", 0.0); victim.willpower = 1
	var prov := _prov(5)
	var crime_records: Array = []
	var casts := DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.ACTIVE)], {5: prov}, [caster, victim],
		{100: 5}, crime_records, [1], DiceEngine.new(7), 10, {})
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["spell_id"], "spreading_the_darkness",
		"dangerously-tainted member → cell casts Spreading the Darkness")
	assert_eq(casts[0]["transfer"]["mode"], "push")
	assert_gt(victim.taint, 0.0, "co-located non-cultist receives the pushed Taint")


# -- Stealing the Soul (s43, owner-authorized 2026-06-09) ----------------------

func _investigator(id: int, loc: String, wounds: int) -> L5RCharacterData:
	var c := _char(id, loc, 0.0)   # Earth 3 (Stamina/Willpower 3)
	c.wounds_taken = wounds
	return c


func test_soul_steal_healthy_target_survives() -> void:
	assert_false(DayOrchestrator._soul_steal_would_kill(_investigator(1, "100", 0)),
		"a 0-wound target never dies from a capacity reduction")


func test_soul_steal_heavily_wounded_is_lethal() -> void:
	var t := _investigator(1, "100", 40)  # Earth 3 cap 48 (alive); Earth 2 cap 32 → dead
	assert_true(DayOrchestrator._soul_steal_would_kill(t))
	assert_eq(t.stamina, 3, "trait restored — check is side-effect free")
	assert_eq(t.willpower, 3)
	assert_eq(t.wounds_taken, 40, "wounds untouched by the check")


func test_soul_steal_lightly_wounded_survives() -> void:
	assert_false(DayOrchestrator._soul_steal_would_kill(_investigator(1, "100", 20)),
		"Earth-2 capacity (32) still holds 20 wounds")


func test_soul_steal_earth_floor_cannot_kill() -> void:
	var t := _investigator(1, "100", 10)
	t.stamina = 1; t.willpower = 1  # Earth 1 — already at the floor
	assert_false(DayOrchestrator._soul_steal_would_kill(t))


func test_pick_soul_steal_investigator_only() -> void:
	var caster := _char(1, "100", 2.0); caster.stamina = 4; caster.willpower = 4
	var hunter := _investigator(2, "100", 40)
	var civ := _investigator(3, "100", 40)   # wounded but no investigation objective
	var omap := {2: {"standing": {"need_type": "UPHOLD_LAW"}}}
	var t := DayOrchestrator._pick_soul_steal_target(caster, [caster, hunter, civ], omap)
	assert_eq(t.character_id, 2, "only the wounded investigator qualifies")


func test_pick_soul_steal_skips_unkillable_investigator() -> void:
	var caster := _char(1, "100", 2.0); caster.stamina = 4; caster.willpower = 4
	var hunter := _investigator(2, "100", 10)  # investigator but not lethally wounded
	var omap := {2: {"primary": {"need_type": "INVESTIGATE_THREAT"}}}
	assert_null(DayOrchestrator._pick_soul_steal_target(caster, [caster, hunter], omap))


func test_pick_soul_steal_skips_pc_and_cultist() -> void:
	var caster := _char(1, "100", 2.0); caster.stamina = 4; caster.willpower = 4
	var pc := _char(2, "100", 0.0, true); pc.wounds_taken = 40
	var cultist := _cultist(3, "100", 0.0); cultist.wounds_taken = 40
	var omap := {2: {"standing": {"need_type": "UPHOLD_LAW"}},
		3: {"standing": {"need_type": "UPHOLD_LAW"}}}
	assert_null(DayOrchestrator._pick_soul_steal_target(caster, [caster, pc, cultist], omap))


func test_resolve_stealing_the_soul_kills() -> void:
	var caster := _char(1, "100", 2.0)
	var victim := _investigator(2, "100", 40); victim.role_position = "magistrate"
	var deaths: Array = []
	var topics: Array = []
	var res := DayOrchestrator._resolve_stealing_the_soul(
		caster, victim, deaths, topics, [500], 30)
	assert_eq(res["mode"], "killed")
	assert_true(CharacterStats.is_dead(victim), "Earth failure overwhelms the target's wounds")
	assert_eq(deaths.size(), 1)
	assert_true(deaths[0]["suspicious_death"], "death shows no obvious cause")
	assert_eq(deaths[0]["killer_id"], 1)
	assert_true(deaths[0]["is_lord"], "role_position set → succession triggers")
	assert_eq(topics.size(), 1)
	assert_eq(topics[0].tier, TopicData.Tier.TIER_2)
	assert_eq(topics[0].subject_role, "NEUTRAL", "dead-character topic carries NEUTRAL valence")


func test_seasonal_pass_kill_outranks_shed() -> void:
	var caster := _char(1, "100", 2.0); caster.stamina = 4; caster.willpower = 4  # Earth 4, Rank 2
	var hunter := _investigator(2, "100", 40); hunter.role_position = "magistrate"
	var prov := _prov(5)
	var crime_records: Array = []
	var deaths: Array = []
	var topics: Array = []
	var casts := DayOrchestrator._process_seasonal_maho_casts(
		[_cell(5, Enums.BloodspeakerCellState.ACTIVE)], {5: prov}, [caster, hunter],
		{100: 5}, crime_records, [1], DiceEngine.new(7), 30,
		{2: {"standing": {"need_type": "UPHOLD_LAW"}}}, deaths, topics, [500])
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["spell_id"], "stealing_the_soul",
		"a kill opportunity outranks taint-shedding")
	assert_eq(casts[0]["kill"]["mode"], "killed")
	assert_true(CharacterStats.is_dead(hunter), "the investigating magistrate dies")
	assert_eq(deaths.size(), 1, "death_event appended for same-season succession")
