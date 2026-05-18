class_name OpportunityScanner
## Primary Objective Self-Selection per GDD s55.26.1.
## Scans world state through known information to identify opportunities.
## Produces ranked candidate objectives scored on 4 factors.


class Opportunity:
	var objective_type: String = ""
	var target_fields: Dictionary = {}
	var standing_alignment: float = 0.0
	var feasibility: float = 0.0
	var urgency: float = 0.0
	var personality_fit: float = 0.0

	func get_score() -> float:
		return standing_alignment * 0.4 + feasibility * 0.3 + urgency * 0.2 + personality_fit * 0.1


const DOMAIN_POLITICAL: String = "political"
const DOMAIN_MILITARY: String = "military"
const DOMAIN_ECONOMIC: String = "economic"
const DOMAIN_PERSONAL: String = "personal"

const PERSONALITY_DOMAIN_PREFERENCE: Dictionary = {
	Enums.BushidoVirtue.YU: DOMAIN_MILITARY,
	Enums.BushidoVirtue.REI: DOMAIN_POLITICAL,
	Enums.BushidoVirtue.JIN: DOMAIN_ECONOMIC,
	Enums.BushidoVirtue.CHUGI: DOMAIN_POLITICAL,
	Enums.BushidoVirtue.GI: DOMAIN_PERSONAL,
	Enums.BushidoVirtue.MEIYO: DOMAIN_PERSONAL,
	Enums.BushidoVirtue.MAKOTO: DOMAIN_POLITICAL,
}

const STANDING_OBJECTIVE_DOMAIN: Dictionary = {
	"EXPAND_TERRITORY": DOMAIN_MILITARY,
	"MAINTAIN_BALANCE": DOMAIN_POLITICAL,
	"MAINTAIN_PEACE": DOMAIN_POLITICAL,
	"MAXIMIZE_PROSPERITY": DOMAIN_ECONOMIC,
	"ADVANCE_FAMILY": DOMAIN_POLITICAL,
	"UNDERMINE_CLAN": DOMAIN_POLITICAL,
	"STRENGTHEN_IMPERIAL": DOMAIN_POLITICAL,
	"ACCUMULATE_LEVERAGE": DOMAIN_POLITICAL,
	"UPHOLD_LAW": DOMAIN_POLITICAL,
	"DEFEND_TERRITORY": DOMAIN_MILITARY,
	"STRENGTHEN_FORTIFICATION": DOMAIN_MILITARY,
	"STRENGTHEN_WALL": DOMAIN_MILITARY,
	"MILITARY_DOMINANCE": DOMAIN_MILITARY,
	"ELIMINATE_SHADOWLANDS": DOMAIN_MILITARY,
	"BUILD_STRONGEST_FORCE": DOMAIN_MILITARY,
	"PROTECT_TERRITORY": DOMAIN_MILITARY,
	"CONTROL_TRADE": DOMAIN_ECONOMIC,
	"PREVENT_SHORTAGE": DOMAIN_ECONOMIC,
	"ACCUMULATE_WEALTH": DOMAIN_ECONOMIC,
	"GROW_COMMERCE": DOMAIN_ECONOMIC,
	"HONOR_ANCESTORS": DOMAIN_PERSONAL,
	"PROTECT_DEPENDENTS": DOMAIN_PERSONAL,
	"ACCUMULATE_KNOWLEDGE": DOMAIN_PERSONAL,
	"PERSONAL_EXCELLENCE": DOMAIN_PERSONAL,
	"ELEVATE_FAMILY": DOMAIN_PERSONAL,
	"LIVE_BY_BUSHIDO": DOMAIN_PERSONAL,
	"ADVANCE_GLORY": DOMAIN_PERSONAL,
	"SEEK_GLORY": DOMAIN_PERSONAL,
	"SEEK_VENGEANCE": DOMAIN_PERSONAL,
	"INVESTIGATE_CRIME": DOMAIN_POLITICAL,
	"BUILD_INFRASTRUCTURE": DOMAIN_ECONOMIC,
	"FILL_VACANCY": DOMAIN_POLITICAL,
}

const SELF_SELECTION_DELAY_BUSHIDO: Dictionary = {
	Enums.BushidoVirtue.CHUGI: -1,
	Enums.BushidoVirtue.MAKOTO: 2,
}

const SELF_SELECTION_DELAY_SHOURIDO: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: 1,
	Enums.ShouridoVirtue.ISHI: 1,
	Enums.ShouridoVirtue.KETSUI: 2,
}

const DEFAULT_SELF_SELECTION_DELAY: int = 3


static func select_primary_objective(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Dictionary:
	var domain: String = STANDING_OBJECTIVE_DOMAIN.get(standing_type, DOMAIN_POLITICAL)
	var opportunities: Array[Opportunity] = scan_opportunities(
		character, domain, standing_type, world_state
	)

	if opportunities.is_empty():
		return {}

	opportunities.sort_custom(func(a: Opportunity, b: Opportunity) -> bool:
		if absf(a.get_score() - b.get_score()) < 0.01:
			if absf(a.urgency - b.urgency) > 0.01:
				return a.urgency > b.urgency
			if absf(a.standing_alignment - b.standing_alignment) > 0.01:
				return a.standing_alignment > b.standing_alignment
			return a.feasibility > b.feasibility
		return a.get_score() > b.get_score()
	)

	var best: Opportunity = opportunities[0]
	return {
		"need_type": best.objective_type,
		"objective_type": best.objective_type,
		"target_fields": best.target_fields,
		"score": best.get_score(),
		"source": "SELF_SELECTED",
	}


static func scan_opportunities(
	character: L5RCharacterData,
	domain: String,
	standing_type: String,
	world_state: Dictionary,
) -> Array[Opportunity]:
	var results: Array[Opportunity] = []

	match domain:
		DOMAIN_POLITICAL:
			results.append_array(_scan_political(character, standing_type, world_state))
		DOMAIN_MILITARY:
			results.append_array(_scan_military(character, standing_type, world_state))
		DOMAIN_ECONOMIC:
			results.append_array(_scan_economic(character, standing_type, world_state))
		DOMAIN_PERSONAL:
			results.append_array(_scan_personal(character, standing_type, world_state))

	for opp: Opportunity in results:
		opp.personality_fit = _compute_personality_fit(character, opp, domain)

	return results


static func can_self_select(
	character: L5RCharacterData,
	seasons_without_assignment: int,
) -> bool:
	var delay: int = DEFAULT_SELF_SELECTION_DELAY
	if SELF_SELECTION_DELAY_BUSHIDO.has(character.bushido_virtue):
		delay = SELF_SELECTION_DELAY_BUSHIDO[character.bushido_virtue]
	elif SELF_SELECTION_DELAY_SHOURIDO.has(character.shourido_virtue):
		delay = SELF_SELECTION_DELAY_SHOURIDO[character.shourido_virtue]

	if delay < 0:
		return false

	return seasons_without_assignment >= delay


# -- Political Opportunities ---------------------------------------------------

static func _scan_political(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Array[Opportunity]:
	var results: Array[Opportunity] = []

	var weak_neighbors: Array = world_state.get("weak_neighbor_provinces", [])
	for neighbor: Dictionary in weak_neighbors:
		var opp := Opportunity.new()
		opp.objective_type = "SECURE_ALLIANCE"
		opp.target_fields = {"target_clan_id": neighbor.get("clan", "")}
		opp.standing_alignment = 70.0 if standing_type == "MAINTAIN_PEACE" else 50.0
		opp.feasibility = _assess_alliance_feasibility(character, neighbor)
		opp.urgency = 40.0
		results.append(opp)

	var rising_clans: Array = world_state.get("rising_clans", [])
	for clan_data: Dictionary in rising_clans:
		var clan: String = clan_data.get("clan", "")
		if clan == character.clan:
			continue
		var opp := Opportunity.new()
		opp.objective_type = "ISOLATE_CHARACTER"
		opp.target_fields = {"target_clan_id": clan}
		opp.standing_alignment = 80.0 if standing_type == "ADVANCE_FAMILY" else 60.0
		opp.feasibility = 60.0
		opp.urgency = clan_data.get("urgency", 50.0)
		results.append(opp)

	var upcoming_courts: Array = world_state.get("upcoming_courts", [])
	if not upcoming_courts.is_empty():
		var opp := Opportunity.new()
		opp.objective_type = "GAIN_WINTER_COURT_INVITATION"
		opp.target_fields = {}
		opp.standing_alignment = 65.0 if standing_type == "ADVANCE_FAMILY" else 40.0
		opp.feasibility = 75.0
		opp.urgency = 30.0
		results.append(opp)

	var secrets_held: Array = world_state.get("secrets_held", [])
	for secret: Dictionary in secrets_held:
		var opp := Opportunity.new()
		opp.objective_type = "EXPOSE_SECRET"
		opp.target_fields = {"target_npc_id": secret.get("target_id", -1)}
		opp.standing_alignment = 90.0 if standing_type == "ACCUMULATE_LEVERAGE" else 50.0
		opp.feasibility = 80.0
		opp.urgency = 30.0
		results.append(opp)

	var unmarried_family: Array = world_state.get("unmarried_family_members", [])
	for member: Dictionary in unmarried_family:
		var opp := Opportunity.new()
		opp.objective_type = "ARRANGE_MARRIAGE"
		opp.target_fields = {"target_npc_id": member.get("character_id", -1)}
		opp.standing_alignment = 80.0 if standing_type == "ADVANCE_FAMILY" else 45.0
		opp.feasibility = 70.0
		opp.urgency = member.get("urgency", 30.0)
		results.append(opp)

	return results


# -- Military Opportunities ----------------------------------------------------

static func _scan_military(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Array[Opportunity]:
	var results: Array[Opportunity] = []

	var border_weaknesses: Array = world_state.get("border_weaknesses", [])
	for border: Dictionary in border_weaknesses:
		var opp := Opportunity.new()
		opp.objective_type = "CONQUER_PROVINCE"
		opp.target_fields = {"target_province_id": border.get("province_id", -1)}
		opp.standing_alignment = 100.0 if standing_type == "EXPAND_TERRITORY" else 60.0
		opp.feasibility = border.get("feasibility", 50.0)
		opp.urgency = 50.0
		results.append(opp)

	var insurgencies: Array = world_state.get("active_insurgencies", [])
	for ins: Dictionary in insurgencies:
		var opp := Opportunity.new()
		opp.objective_type = "ELIMINATE_SHADOWLANDS"
		opp.target_fields = {"target_province_id": ins.get("province_id", -1)}
		opp.standing_alignment = 90.0 if standing_type == "ELIMINATE_SHADOWLANDS" else 70.0
		opp.feasibility = 70.0
		opp.urgency = 80.0
		results.append(opp)

	var clan_strengths: Dictionary = world_state.get("known_clan_strengths", {})
	var my_strength: float = clan_strengths.get(character.clan, 0.0)
	var strongest_rival: float = 0.0
	for clan: String in clan_strengths:
		if clan != character.clan and clan_strengths[clan] > strongest_rival:
			strongest_rival = clan_strengths[clan]
	if strongest_rival > my_strength * 1.3:
		var opp := Opportunity.new()
		opp.objective_type = "BUILD_STRONGEST_FORCE"
		opp.target_fields = {}
		opp.standing_alignment = 90.0 if standing_type == "MILITARY_DOMINANCE" else 60.0
		opp.feasibility = 60.0
		opp.urgency = 60.0
		results.append(opp)

	var taint_detected: Array = world_state.get("taint_topic_province_ids", [])
	for province_id: Variant in taint_detected:
		var opp := Opportunity.new()
		opp.objective_type = "ELIMINATE_SHADOWLANDS"
		opp.target_fields = {"target_province_id": province_id if province_id is int else -1}
		opp.standing_alignment = 95.0 if standing_type == "STRENGTHEN_WALL" else 70.0
		opp.feasibility = 65.0
		opp.urgency = 90.0
		results.append(opp)

	var threatened_provinces: Array = world_state.get("threatened_provinces", [])
	for threat: Dictionary in threatened_provinces:
		var opp := Opportunity.new()
		opp.objective_type = "DEFEND_PROVINCE"
		opp.target_fields = {"target_province_id": threat.get("province_id", -1)}
		opp.standing_alignment = 90.0 if standing_type in ["EXPAND_TERRITORY", "MILITARY_DOMINANCE"] else 60.0
		opp.feasibility = threat.get("feasibility", 60.0)
		opp.urgency = threat.get("urgency", 70.0)
		results.append(opp)

	var sieged_allies: Array = world_state.get("sieged_allies", [])
	for siege: Dictionary in sieged_allies:
		var opp := Opportunity.new()
		opp.objective_type = "RELIEVE_SIEGE"
		opp.target_fields = {"target_province_id": siege.get("province_id", -1)}
		opp.standing_alignment = 85.0 if standing_type == "MAINTAIN_PEACE" else 60.0
		opp.feasibility = siege.get("feasibility", 50.0)
		opp.urgency = 80.0
		results.append(opp)

	var tainted_provinces: Array = world_state.get("tainted_provinces", [])
	for prov: Dictionary in tainted_provinces:
		var opp := Opportunity.new()
		opp.objective_type = "MANAGE_TAINT"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 90.0 if standing_type == "ELIMINATE_SHADOWLANDS" else 65.0
		opp.feasibility = 60.0
		opp.urgency = prov.get("urgency", 75.0)
		results.append(opp)

	var insurgent_provinces: Array = world_state.get("insurgent_provinces", [])
	for prov: Dictionary in insurgent_provinces:
		var opp := Opportunity.new()
		opp.objective_type = "PATROL_PROVINCE"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 80.0 if standing_type == "UPHOLD_LAW" else 50.0
		opp.feasibility = 75.0
		opp.urgency = prov.get("urgency", 60.0)
		results.append(opp)

	if strongest_rival > my_strength * 1.1 and strongest_rival <= my_strength * 1.3:
		var opp := Opportunity.new()
		opp.objective_type = "LEVY_TROOPS"
		opp.target_fields = {}
		opp.standing_alignment = 75.0 if standing_type == "BUILD_STRONGEST_FORCE" else 50.0
		opp.feasibility = 80.0
		opp.urgency = 45.0
		results.append(opp)

	return results


# -- Economic Opportunities ----------------------------------------------------

static func _scan_economic(
	_character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Array[Opportunity]:
	var results: Array[Opportunity] = []

	var resource_deficits: Array = world_state.get("resource_deficits", [])
	for deficit: Dictionary in resource_deficits:
		var opp := Opportunity.new()
		opp.objective_type = "PREVENT_SHORTAGE"
		opp.target_fields = {"target_resource": deficit.get("resource", "")}
		opp.standing_alignment = 85.0 if standing_type == "MAXIMIZE_PROSPERITY" else 50.0
		opp.feasibility = 70.0
		opp.urgency = deficit.get("urgency", 60.0)
		results.append(opp)

	var famine_provinces: Array = world_state.get("famine_provinces", [])
	for prov: Dictionary in famine_provinces:
		var opp := Opportunity.new()
		opp.objective_type = "PREVENT_SHORTAGE"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1), "target_resource": "rice"}
		opp.standing_alignment = 80.0
		opp.feasibility = 60.0
		opp.urgency = 90.0
		results.append(opp)

	var low_koku_provinces: Array = world_state.get("low_koku_provinces", [])
	for prov: Dictionary in low_koku_provinces:
		var opp := Opportunity.new()
		opp.objective_type = "INCREASE_KOKU"
		opp.target_fields = {"target_province_id": prov.get("province_id", -1)}
		opp.standing_alignment = 75.0 if standing_type == "CONTROL_TRADE" else 60.0
		opp.feasibility = 75.0
		opp.urgency = 40.0
		results.append(opp)

	var critical_needs: Array = world_state.get("critical_resource_needs", [])
	for need: Dictionary in critical_needs:
		var opp := Opportunity.new()
		opp.objective_type = "ACQUIRE_RESOURCE"
		opp.target_fields = {
			"target_resource": need.get("resource", ""),
			"threshold": need.get("threshold", 0.0),
		}
		opp.standing_alignment = 80.0 if standing_type == "MAXIMIZE_PROSPERITY" else 55.0
		opp.feasibility = 65.0
		opp.urgency = need.get("urgency", 70.0)
		results.append(opp)

	var threatened_routes: Array = world_state.get("threatened_trade_routes", [])
	for route: Dictionary in threatened_routes:
		var opp := Opportunity.new()
		opp.objective_type = "SECURE_TRADE_ROUTE"
		opp.target_fields = {"target_province_id": route.get("province_id", -1)}
		opp.standing_alignment = 90.0 if standing_type == "CONTROL_TRADE" else 55.0
		opp.feasibility = 70.0
		opp.urgency = route.get("urgency", 55.0)
		results.append(opp)

	return results


# -- Personal Opportunities ----------------------------------------------------

static func _scan_personal(
	character: L5RCharacterData,
	standing_type: String,
	world_state: Dictionary,
) -> Array[Opportunity]:
	var results: Array[Opportunity] = []

	if character.honor < 3.0:
		var opp := Opportunity.new()
		opp.objective_type = "RESTORE_HONOR"
		opp.target_fields = {"threshold": 4.0}
		opp.standing_alignment = 80.0 if standing_type == "SEEK_GLORY" else 50.0
		opp.feasibility = 70.0
		opp.urgency = 70.0
		results.append(opp)

	if character.glory < character.status - 1.0:
		var opp := Opportunity.new()
		opp.objective_type = "SEEK_GLORY"
		opp.target_fields = {"threshold": character.status}
		opp.standing_alignment = 90.0 if standing_type == "SEEK_GLORY" else 40.0
		opp.feasibility = 75.0
		opp.urgency = 40.0
		results.append(opp)

	var vengeance_targets: Array = world_state.get("vengeance_targets", [])
	for target: Dictionary in vengeance_targets:
		var opp := Opportunity.new()
		opp.objective_type = "AVENGE"
		opp.target_fields = {"target_npc_id": target.get("target_id", -1)}
		opp.standing_alignment = 100.0 if standing_type == "SEEK_VENGEANCE" else 30.0
		opp.feasibility = target.get("feasibility", 50.0)
		opp.urgency = 60.0
		results.append(opp)

	var trainable_vassals: Array = world_state.get("trainable_vassals", [])
	for vassal: Dictionary in trainable_vassals:
		var opp := Opportunity.new()
		opp.objective_type = "MENTOR_CHARACTER"
		opp.target_fields = {"target_npc_id": vassal.get("vassal_id", -1)}
		opp.standing_alignment = 60.0
		opp.feasibility = 85.0
		opp.urgency = 20.0
		results.append(opp)

	var bitter_rivals: Array = world_state.get("bitter_rivals", [])
	for rival: Dictionary in bitter_rivals:
		var opp := Opportunity.new()
		opp.objective_type = "ELIMINATE_CHARACTER"
		opp.target_fields = {"target_npc_id": rival.get("target_id", -1)}
		opp.standing_alignment = 70.0 if standing_type == "SEEK_VENGEANCE" else 30.0
		opp.feasibility = rival.get("feasibility", 40.0)
		opp.urgency = rival.get("urgency", 50.0)
		results.append(opp)

	return results


# -- Helpers -------------------------------------------------------------------

static func _compute_personality_fit(
	character: L5RCharacterData,
	opp: Opportunity,
	domain: String,
) -> float:
	var preferred_domain: String = PERSONALITY_DOMAIN_PREFERENCE.get(
		character.bushido_virtue, ""
	)
	if preferred_domain == domain:
		return 80.0

	match opp.objective_type:
		"CONQUER_PROVINCE", "BUILD_STRONGEST_FORCE", "MILITARY_DOMINANCE", "LEVY_TROOPS":
			if character.bushido_virtue == Enums.BushidoVirtue.YU:
				return 90.0
			if character.bushido_virtue == Enums.BushidoVirtue.JIN:
				return 20.0
		"MAINTAIN_PEACE", "SECURE_ALLIANCE", "ARRANGE_MARRIAGE":
			if character.bushido_virtue == Enums.BushidoVirtue.JIN:
				return 85.0
			if character.bushido_virtue == Enums.BushidoVirtue.REI:
				return 80.0
		"SEEK_VENGEANCE", "AVENGE", "ELIMINATE_CHARACTER":
			if character.bushido_virtue == Enums.BushidoVirtue.YU:
				return 90.0
			if character.bushido_virtue == Enums.BushidoVirtue.REI:
				return 30.0
		"DEFEND_PROVINCE", "RELIEVE_SIEGE", "PATROL_PROVINCE":
			if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
				return 85.0
			if character.bushido_virtue == Enums.BushidoVirtue.YU:
				return 80.0
		"MANAGE_TAINT":
			if character.bushido_virtue == Enums.BushidoVirtue.GI:
				return 85.0
			if character.bushido_virtue == Enums.BushidoVirtue.JIN:
				return 80.0
		"ACQUIRE_RESOURCE", "SECURE_TRADE_ROUTE":
			if character.bushido_virtue == Enums.BushidoVirtue.JIN:
				return 75.0

	return 50.0


static func _assess_alliance_feasibility(
	character: L5RCharacterData,
	neighbor: Dictionary,
) -> float:
	var target_clan: String = neighbor.get("clan", "")
	var base: float = 50.0

	for cid: int in character.disposition_values:
		var disp: float = character.disposition_values[cid]
		if disp > 15.0:
			base += 10.0
			break

	if target_clan == character.clan:
		base += 20.0

	return clampf(base, 0.0, 100.0)
