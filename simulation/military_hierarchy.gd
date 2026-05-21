class_name MilitaryHierarchy
## Military organizational hierarchy per GDD s57.21.
## Queries and mutations for the Company → Legion → Section → Army chain.
## Separate from operational_superior_id (person chain) — this is unit chain.


# =============================================================================
# 57.21 — Clan Army Roster (standing army counts)
# =============================================================================

const CLAN_ARMY_COUNT: Dictionary = {
	"Crab": 4,
	"Crane": 2,
	"Dragon": 2,
	"Lion": 4,
	"Mantis": 3,
	"Phoenix": 1,
	"Scorpion": 1,
	"Unicorn": 3,
	"Imperial": 1,
}

const COMPANIES_PER_LEGION: int = 7
const REGULAR_COMPANIES_PER_LEGION: int = 6
const RESERVE_COMPANIES_PER_LEGION: int = 1


# =============================================================================
# 57.17 — Direct Subordinate Query (feudal + operational)
# =============================================================================

static func get_direct_subordinates(
	character_id: int,
	characters: Array,
) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.character_id == character_id:
			continue
		if c.lord_id == character_id or c.operational_superior_id == character_id:
			if not seen.has(c.character_id):
				seen[c.character_id] = true
				result.append(c)
	return result


static func get_direct_vassals(
	character_id: int,
	characters: Array,
) -> Array:
	return get_direct_subordinates(character_id, characters)


# =============================================================================
# 57.21.2 — Organizational Queries
# =============================================================================

static func get_company(
	companies: Dictionary,
	company_id: int,
) -> MilitaryUnitData.CompanyData:
	return companies.get(company_id)


static func get_legion_companies(
	companies: Dictionary,
	legion_id: int,
) -> Array:
	var result: Array = []
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id:
			result.append(c)
	return result


static func get_legion_regular_companies(
	companies: Dictionary,
	legion_id: int,
) -> Array:
	var result: Array = []
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id and not c.is_reserve:
			result.append(c)
	return result


static func get_legion_reserve(
	companies: Dictionary,
	legion_id: int,
) -> MilitaryUnitData.CompanyData:
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id and c.is_reserve:
			return c
	return null


static func get_section_legions(
	legions: Dictionary,
	section_id: int,
) -> Array:
	var result: Array = []
	for lid: int in legions:
		var l: MilitaryUnitData.LegionData = legions[lid]
		if l.parent_section_id == section_id:
			result.append(l)
	return result


static func get_army_sections(
	sections: Dictionary,
	army_id: int,
) -> Array:
	var result: Array = []
	for sid: int in sections:
		var s: MilitaryUnitData.SectionData = sections[sid]
		if s.parent_army_id == army_id:
			result.append(s)
	return result


static func get_clan_armies(
	armies: Dictionary,
	clan_id: String,
) -> Array:
	var result: Array = []
	for aid: int in armies:
		var a: MilitaryUnitData.ArmyData = armies[aid]
		if a.clan_id == clan_id:
			result.append(a)
	return result


# =============================================================================
# 57.21.2 — Full Organizational Chain
# =============================================================================

static func get_company_chain(
	company: MilitaryUnitData.CompanyData,
	legions: Dictionary,
	sections: Dictionary,
	armies: Dictionary,
) -> Dictionary:
	var chain: Dictionary = {
		"company_id": company.company_id,
		"legion_id": -1,
		"section_id": -1,
		"army_id": -1,
		"clan_id": "",
	}

	var legion: MilitaryUnitData.LegionData = legions.get(company.parent_legion_id)
	if legion == null:
		return chain
	chain["legion_id"] = legion.legion_id

	var section: MilitaryUnitData.SectionData = sections.get(legion.parent_section_id)
	if section == null:
		return chain
	chain["section_id"] = section.section_id

	var army: MilitaryUnitData.ArmyData = armies.get(section.parent_army_id)
	if army == null:
		return chain
	chain["army_id"] = army.army_id
	chain["clan_id"] = army.clan_id

	return chain


static func get_commander_chain(
	company: MilitaryUnitData.CompanyData,
	legions: Dictionary,
	sections: Dictionary,
	armies: Dictionary,
) -> Array:
	var chain: Array = []

	var legion: MilitaryUnitData.LegionData = legions.get(company.parent_legion_id)
	if legion == null:
		return chain
	if legion.commander_id >= 0:
		chain.append(legion.commander_id)

	var section: MilitaryUnitData.SectionData = sections.get(legion.parent_section_id)
	if section == null:
		return chain
	if section.commander_id >= 0:
		chain.append(section.commander_id)

	var army: MilitaryUnitData.ArmyData = armies.get(section.parent_army_id)
	if army == null:
		return chain
	if army.commander_id >= 0:
		chain.append(army.commander_id)

	return chain


# =============================================================================
# 57.21.2 — Deployment Status
# =============================================================================

static func get_companies_by_status(
	companies: Dictionary,
	legion_id: int,
	status: Enums.DeploymentStatus,
) -> Array:
	var result: Array = []
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id and c.deployment_status == status:
			result.append(c)
	return result


static func get_present_companies(
	companies: Dictionary,
	legion_id: int,
) -> Array:
	var result: Array = []
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id:
			if c.deployment_status == Enums.DeploymentStatus.WITH_LEGION or c.deployment_status == Enums.DeploymentStatus.ON_CAMPAIGN:
				result.append(c)
	return result


static func deploy_company(
	company: MilitaryUnitData.CompanyData,
	new_status: Enums.DeploymentStatus,
	location_id: String = "",
) -> void:
	company.deployment_status = new_status
	if not location_id.is_empty():
		company.current_location_id = location_id


static func recall_company(
	company: MilitaryUnitData.CompanyData,
	legion_location: String,
) -> void:
	company.deployment_status = Enums.DeploymentStatus.WITH_LEGION
	company.current_location_id = legion_location


# =============================================================================
# 57.21.3 — Commander Assignment and Vacancy
# =============================================================================

static func assign_commander(
	unit_commander_id_setter: Callable,
	new_commander: L5RCharacterData,
	operational_superior_id: int,
) -> void:
	unit_commander_id_setter.call(new_commander.character_id)
	new_commander.lord_id = operational_superior_id


static func vacate_company(company: MilitaryUnitData.CompanyData) -> int:
	var old: int = company.commander_id
	company.commander_id = -1
	return old


static func vacate_legion(legion: MilitaryUnitData.LegionData) -> int:
	var old: int = legion.commander_id
	legion.commander_id = -1
	return old


static func vacate_section(section: MilitaryUnitData.SectionData) -> int:
	var old: int = section.commander_id
	section.commander_id = -1
	return old


static func vacate_army(army: MilitaryUnitData.ArmyData) -> int:
	var old: int = army.commander_id
	army.commander_id = -1
	return old


static func is_company_vacant(company: MilitaryUnitData.CompanyData) -> bool:
	return company.commander_id < 0


static func is_legion_vacant(legion: MilitaryUnitData.LegionData) -> bool:
	return legion.commander_id < 0


static func get_vacant_companies(
	companies: Dictionary,
	legion_id: int,
) -> Array:
	var result: Array = []
	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id == legion_id and c.commander_id < 0:
			result.append(c)
	return result


# =============================================================================
# 57.21.3 — Operational Superior Resolution
# =============================================================================

static func resolve_operational_superior(
	company: MilitaryUnitData.CompanyData,
	legions: Dictionary,
) -> int:
	var legion: MilitaryUnitData.LegionData = legions.get(company.parent_legion_id)
	if legion == null:
		return -1
	return legion.commander_id


static func resolve_legion_superior(
	legion: MilitaryUnitData.LegionData,
	sections: Dictionary,
) -> int:
	var section: MilitaryUnitData.SectionData = sections.get(legion.parent_section_id)
	if section == null:
		return -1
	return section.commander_id


static func resolve_section_superior(
	section: MilitaryUnitData.SectionData,
	armies: Dictionary,
) -> int:
	var army: MilitaryUnitData.ArmyData = armies.get(section.parent_army_id)
	if army == null:
		return -1
	return army.commander_id


# =============================================================================
# 57.21.1 — Legion Strength
# =============================================================================

static func get_legion_strength(
	companies: Dictionary,
	legion_id: int,
) -> Dictionary:
	var total: int = 0
	var present: int = 0
	var garrisoned: int = 0
	var detached: int = 0
	var on_campaign: int = 0

	for cid: int in companies:
		var c: MilitaryUnitData.CompanyData = companies[cid]
		if c.parent_legion_id != legion_id:
			continue
		total += 1
		match c.deployment_status:
			Enums.DeploymentStatus.WITH_LEGION:
				present += 1
			Enums.DeploymentStatus.GARRISONED:
				garrisoned += 1
			Enums.DeploymentStatus.DETACHED:
				detached += 1
			Enums.DeploymentStatus.ON_CAMPAIGN:
				on_campaign += 1

	return {
		"total": total,
		"present": present,
		"garrisoned": garrisoned,
		"detached": detached,
		"on_campaign": on_campaign,
		"has_reserve": get_legion_reserve(companies, legion_id) != null,
	}


# =============================================================================
# 57.21.3 — Vacancy Effects
# =============================================================================

static func get_vacancy_penalties(
	company: MilitaryUnitData.CompanyData,
) -> Dictionary:
	if company.commander_id >= 0:
		return {"commander_bonus_lost": false, "specialist_lost": false}
	return {
		"commander_bonus_lost": true,
		"specialist_lost": company.is_reserve,
	}


static func can_legion_coordinate(legion: MilitaryUnitData.LegionData) -> bool:
	return legion.commander_id >= 0


static func can_section_initiate_campaign(section: MilitaryUnitData.SectionData) -> bool:
	return section.commander_id >= 0
