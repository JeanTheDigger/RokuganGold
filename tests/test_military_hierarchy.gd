extends GutTest


var _companies: Dictionary
var _legions: Dictionary
var _sections: Dictionary
var _armies: Dictionary


func _make_company(id: int, legion_id: int, reserve: bool = false) -> MilitaryUnitData.CompanyData:
	var c := MilitaryUnitData.CompanyData.new()
	c.company_id = id
	c.parent_legion_id = legion_id
	c.commander_id = id * 100
	c.current_location_id = "province_1"
	c.is_reserve = reserve
	return c


func _make_legion(id: int, section_id: int) -> MilitaryUnitData.LegionData:
	var l := MilitaryUnitData.LegionData.new()
	l.legion_id = id
	l.parent_section_id = section_id
	l.commander_id = 5000 + id
	l.home_province_id = 1
	return l


func _make_section(id: int, army_id: int) -> MilitaryUnitData.SectionData:
	var s := MilitaryUnitData.SectionData.new()
	s.section_id = id
	s.parent_army_id = army_id
	s.commander_id = 6000 + id
	return s


func _make_army(id: int, clan: String) -> MilitaryUnitData.ArmyData:
	var a := MilitaryUnitData.ArmyData.new()
	a.army_id = id
	a.clan_id = clan
	a.commander_id = 7000 + id
	return a


func before_each() -> void:
	_armies = {1: _make_army(1, "Lion")}
	_sections = {10: _make_section(10, 1)}
	_legions = {100: _make_legion(100, 10)}
	_companies = {}
	for i: int in range(6):
		var c := _make_company(1000 + i, 100)
		_companies[c.company_id] = c
	var reserve := _make_company(1006, 100, true)
	_companies[1006] = reserve


# =============================================================================
# Organizational Queries
# =============================================================================

func test_get_legion_companies_returns_seven():
	var result := MilitaryHierarchy.get_legion_companies(_companies, 100)
	assert_eq(result.size(), 7)

func test_get_regular_companies_returns_six():
	var result := MilitaryHierarchy.get_legion_regular_companies(_companies, 100)
	assert_eq(result.size(), 6)

func test_get_reserve_company():
	var reserve := MilitaryHierarchy.get_legion_reserve(_companies, 100)
	assert_not_null(reserve)
	assert_true(reserve.is_reserve)

func test_reserve_null_for_wrong_legion():
	assert_null(MilitaryHierarchy.get_legion_reserve(_companies, 999))

func test_get_section_legions():
	var result := MilitaryHierarchy.get_section_legions(_legions, 10)
	assert_eq(result.size(), 1)
	assert_eq(result[0].legion_id, 100)

func test_get_army_sections():
	var result := MilitaryHierarchy.get_army_sections(_sections, 1)
	assert_eq(result.size(), 1)

func test_get_clan_armies():
	var result := MilitaryHierarchy.get_clan_armies(_armies, "Lion")
	assert_eq(result.size(), 1)

func test_get_clan_armies_empty_for_wrong_clan():
	var result := MilitaryHierarchy.get_clan_armies(_armies, "Crane")
	assert_eq(result.size(), 0)


# =============================================================================
# Full Chain
# =============================================================================

func test_company_chain():
	var company: MilitaryUnitData.CompanyData = _companies[1000]
	var chain: Dictionary = MilitaryHierarchy.get_company_chain(
		company, _legions, _sections, _armies
	)
	assert_eq(chain["company_id"], 1000)
	assert_eq(chain["legion_id"], 100)
	assert_eq(chain["section_id"], 10)
	assert_eq(chain["army_id"], 1)
	assert_eq(chain["clan_id"], "Lion")

func test_company_chain_broken_at_legion():
	var company := _make_company(9999, 999)
	var chain: Dictionary = MilitaryHierarchy.get_company_chain(
		company, _legions, _sections, _armies
	)
	assert_eq(chain["legion_id"], -1)
	assert_eq(chain["section_id"], -1)

func test_commander_chain():
	var company: MilitaryUnitData.CompanyData = _companies[1000]
	var chain: Array = MilitaryHierarchy.get_commander_chain(
		company, _legions, _sections, _armies
	)
	assert_eq(chain.size(), 3)
	assert_eq(chain[0], 5100)  # Taisa (legion 100)
	assert_eq(chain[1], 6010)  # Shireikan (section 10)
	assert_eq(chain[2], 7001)  # Rikugunshokan (army 1)

func test_commander_chain_with_vacancy():
	_legions[100].commander_id = -1
	var company: MilitaryUnitData.CompanyData = _companies[1000]
	var chain: Array = MilitaryHierarchy.get_commander_chain(
		company, _legions, _sections, _armies
	)
	assert_eq(chain.size(), 2)


# =============================================================================
# Deployment Status
# =============================================================================

func test_deploy_company_garrison():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	MilitaryHierarchy.deploy_company(c, Enums.DeploymentStatus.GARRISONED, "fort_1")
	assert_eq(c.deployment_status, Enums.DeploymentStatus.GARRISONED)
	assert_eq(c.current_location_id, "fort_1")

func test_recall_company():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	MilitaryHierarchy.deploy_company(c, Enums.DeploymentStatus.GARRISONED, "fort_1")
	MilitaryHierarchy.recall_company(c, "province_1")
	assert_eq(c.deployment_status, Enums.DeploymentStatus.WITH_LEGION)
	assert_eq(c.current_location_id, "province_1")

func test_get_companies_by_status():
	_companies[1000].deployment_status = Enums.DeploymentStatus.GARRISONED
	_companies[1001].deployment_status = Enums.DeploymentStatus.GARRISONED
	var garrisoned := MilitaryHierarchy.get_companies_by_status(
		_companies, 100, Enums.DeploymentStatus.GARRISONED
	)
	assert_eq(garrisoned.size(), 2)

func test_get_present_companies():
	_companies[1000].deployment_status = Enums.DeploymentStatus.GARRISONED
	_companies[1001].deployment_status = Enums.DeploymentStatus.DETACHED
	var present := MilitaryHierarchy.get_present_companies(_companies, 100)
	assert_eq(present.size(), 5)

func test_present_includes_on_campaign():
	_companies[1000].deployment_status = Enums.DeploymentStatus.ON_CAMPAIGN
	var present := MilitaryHierarchy.get_present_companies(_companies, 100)
	assert_eq(present.size(), 7)


# =============================================================================
# Commander Assignment and Vacancy
# =============================================================================

func test_vacate_company():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	var old: int = MilitaryHierarchy.vacate_company(c)
	assert_eq(old, 100000)
	assert_eq(c.commander_id, -1)
	assert_true(MilitaryHierarchy.is_company_vacant(c))

func test_vacate_legion():
	var old: int = MilitaryHierarchy.vacate_legion(_legions[100])
	assert_eq(old, 5100)
	assert_true(MilitaryHierarchy.is_legion_vacant(_legions[100]))

func test_get_vacant_companies():
	_companies[1000].commander_id = -1
	_companies[1002].commander_id = -1
	var vacant := MilitaryHierarchy.get_vacant_companies(_companies, 100)
	assert_eq(vacant.size(), 2)

func test_no_vacancies():
	var vacant := MilitaryHierarchy.get_vacant_companies(_companies, 100)
	assert_eq(vacant.size(), 0)


# =============================================================================
# Operational Superior Resolution
# =============================================================================

func test_resolve_company_superior():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	var superior: int = MilitaryHierarchy.resolve_operational_superior(c, _legions)
	assert_eq(superior, 5100)

func test_resolve_company_superior_orphan():
	var orphan := _make_company(9999, 999)
	assert_eq(MilitaryHierarchy.resolve_operational_superior(orphan, _legions), -1)

func test_resolve_legion_superior():
	var superior: int = MilitaryHierarchy.resolve_legion_superior(_legions[100], _sections)
	assert_eq(superior, 6010)

func test_resolve_section_superior():
	var superior: int = MilitaryHierarchy.resolve_section_superior(_sections[10], _armies)
	assert_eq(superior, 7001)


# =============================================================================
# Legion Strength
# =============================================================================

func test_legion_strength_all_present():
	var strength: Dictionary = MilitaryHierarchy.get_legion_strength(_companies, 100)
	assert_eq(strength["total"], 7)
	assert_eq(strength["present"], 7)
	assert_eq(strength["garrisoned"], 0)
	assert_true(strength["has_reserve"])

func test_legion_strength_mixed():
	_companies[1000].deployment_status = Enums.DeploymentStatus.GARRISONED
	_companies[1001].deployment_status = Enums.DeploymentStatus.DETACHED
	_companies[1002].deployment_status = Enums.DeploymentStatus.ON_CAMPAIGN
	var strength: Dictionary = MilitaryHierarchy.get_legion_strength(_companies, 100)
	assert_eq(strength["total"], 7)
	assert_eq(strength["present"], 4)
	assert_eq(strength["garrisoned"], 1)
	assert_eq(strength["detached"], 1)
	assert_eq(strength["on_campaign"], 1)


# =============================================================================
# Vacancy Effects
# =============================================================================

func test_no_penalty_when_commanded():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	var penalties: Dictionary = MilitaryHierarchy.get_vacancy_penalties(c)
	assert_false(penalties["commander_bonus_lost"])
	assert_false(penalties["specialist_lost"])

func test_penalty_when_vacant():
	var c: MilitaryUnitData.CompanyData = _companies[1000]
	c.commander_id = -1
	var penalties: Dictionary = MilitaryHierarchy.get_vacancy_penalties(c)
	assert_true(penalties["commander_bonus_lost"])
	assert_false(penalties["specialist_lost"])

func test_reserve_specialist_lost_when_vacant():
	var reserve: MilitaryUnitData.CompanyData = _companies[1006]
	reserve.commander_id = -1
	var penalties: Dictionary = MilitaryHierarchy.get_vacancy_penalties(reserve)
	assert_true(penalties["specialist_lost"])

func test_legion_can_coordinate_with_commander():
	assert_true(MilitaryHierarchy.can_legion_coordinate(_legions[100]))

func test_legion_cannot_coordinate_when_vacant():
	_legions[100].commander_id = -1
	assert_false(MilitaryHierarchy.can_legion_coordinate(_legions[100]))

func test_section_can_initiate_campaign():
	assert_true(MilitaryHierarchy.can_section_initiate_campaign(_sections[10]))

func test_section_cannot_initiate_when_vacant():
	_sections[10].commander_id = -1
	assert_false(MilitaryHierarchy.can_section_initiate_campaign(_sections[10]))


# =============================================================================
# Clan Army Roster Constants
# =============================================================================

func test_lion_has_four_armies():
	assert_eq(MilitaryHierarchy.CLAN_ARMY_COUNT["Lion"], 4)

func test_crab_has_four_armies():
	assert_eq(MilitaryHierarchy.CLAN_ARMY_COUNT["Crab"], 4)

func test_phoenix_has_one_army():
	assert_eq(MilitaryHierarchy.CLAN_ARMY_COUNT["Phoenix"], 1)

func test_companies_per_legion():
	assert_eq(MilitaryHierarchy.COMPANIES_PER_LEGION, 7)


# -- s57.17 — Direct Subordinate Query ----------------------------------------

func _make_subordinate_char(id: int, lord: int, op_sup: int = -1) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.lord_id = lord
	c.operational_superior_id = op_sup
	return c


func test_get_direct_subordinates_feudal_only():
	var lord := _make_subordinate_char(1, -1)
	var v1 := _make_subordinate_char(10, 1)
	var v2 := _make_subordinate_char(11, 1)
	var other := _make_subordinate_char(20, 5)
	var chars: Array = [lord, v1, v2, other]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 2)


func test_get_direct_subordinates_operational_only():
	var commander := _make_subordinate_char(1, -1)
	var op1 := _make_subordinate_char(10, 5, 1)
	var chars: Array = [commander, op1]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 1)
	assert_eq(result[0].character_id, 10)


func test_get_direct_subordinates_mixed():
	var lord := _make_subordinate_char(1, -1)
	var vassal := _make_subordinate_char(10, 1)
	var op_sub := _make_subordinate_char(11, 5, 1)
	var chars: Array = [lord, vassal, op_sub]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 2)


func test_get_direct_subordinates_deduplicates():
	var lord := _make_subordinate_char(1, -1)
	var both := _make_subordinate_char(10, 1, 1)
	var chars: Array = [lord, both]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 1)


func test_get_direct_subordinates_excludes_self():
	var lord := _make_subordinate_char(1, 1)
	var chars: Array = [lord]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 0)


func test_get_direct_subordinates_empty():
	var lord := _make_subordinate_char(1, -1)
	var chars: Array = [lord]
	var result := MilitaryHierarchy.get_direct_subordinates(1, chars)
	assert_eq(result.size(), 0)


func test_get_direct_vassals_is_alias():
	var lord := _make_subordinate_char(1, -1)
	var v := _make_subordinate_char(10, 1)
	var chars: Array = [lord, v]
	var r1 := MilitaryHierarchy.get_direct_subordinates(1, chars)
	var r2 := MilitaryHierarchy.get_direct_vassals(1, chars)
	assert_eq(r1.size(), r2.size())
