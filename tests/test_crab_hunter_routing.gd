extends GutTest
## Verifies the Crab witch-hunter routing the seasonal maho casts feed into:
## tainted province → ELIMINATE_SHADOWLANDS opportunity → INVESTIGATE_THREAT →
## INVESTIGATE_PROVINCE → Kuni/Asako shugenja PTL detection (s11.11, Decision #5).

# -- Link 1: active insurgency → ELIMINATE_SHADOWLANDS opportunity --

func test_insurgency_yields_eliminate_shadowlands_opportunity() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.clan = "Crab"
	var ws := {"active_insurgencies": [{"province_id": 7}]}
	var opps := OpportunityScanner.scan_opportunities(c, "military", "ELIMINATE_SHADOWLANDS", ws)
	var found := false
	for o in opps:
		if o.objective_type == "ELIMINATE_SHADOWLANDS" and o.target_fields.get("target_province_id", -1) == 7:
			found = true
	assert_true(found, "a maho/taint insurgency surfaces an ELIMINATE_SHADOWLANDS opportunity for its province")


# -- Link 2: ELIMINATE_SHADOWLANDS objective + active insurgency → INVESTIGATE_THREAT --

func test_eliminate_shadowlands_routes_to_investigate() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 7
	ps.active_crisis_id = -1          # skip the shadowlands_incursion (Wall) branch
	ps.active_insurgency_id = 99      # taint insurgency present
	ctx.province_statuses = [ps]
	var need := ObjectiveDecomposer.decompose({"need_type": "ELIMINATE_SHADOWLANDS"}, ctx)
	assert_eq(need.need_type, "INVESTIGATE_THREAT")
	assert_eq(need.target_province_id, 7)


# -- Link 3: the Crab hunter detects on INVESTIGATE_PROVINCE in a tainted province --

func _shugenja(id: int, family: String, lore: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.school_type = Enums.SchoolType.SHUGENJA
	c.family = family
	c.perception = 4
	c.skills = {"Lore: Shadowlands": lore} if lore > 0 else {}
	c.lord_id = -1
	return c


func _tainted_prov(pid: int, ptl: float) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = pid
	p.province_name = "Test Province"
	p.province_taint_level = ptl
	return p


func _run_detection(character: L5RCharacterData) -> Array:
	var topics: Array = []
	var results := [{
		"action_id": "INVESTIGATE_PROVINCE", "success": true, "character_id": character.character_id,
	}]
	DayOrchestrator._process_ptl_detection(
		results, {character.character_id: character}, {7: _tainted_prov(7, 1.0)},
		{character.character_id: 7}, DiceEngine.new(7), topics, [300], 12)
	return topics


func test_kuni_shugenja_detects_corruption() -> void:
	var topics := _run_detection(_shugenja(1, "Kuni", 5))
	var found := false
	for t in topics:
		if t.variant == "ptl_detection":
			found = true
	assert_true(found, "Kuni shugenja's province investigation detects spiritual corruption")


func test_non_shugenja_does_not_detect() -> void:
	var bushi := _shugenja(2, "Hida", 5)
	bushi.school_type = Enums.SchoolType.BUSHI
	assert_eq(_run_detection(bushi).size(), 0, "non-shugenja gets no PTL detection")


func test_shugenja_without_lore_does_not_detect() -> void:
	assert_eq(_run_detection(_shugenja(3, "Asako", 0)).size(), 0, "shugenja with no Lore: Shadowlands cannot detect")
