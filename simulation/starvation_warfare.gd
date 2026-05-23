class_name StarvationWarfare
## Player-Initiated Starvation Strategies per GDD s4.3.17 Phase 4.
## Two hostile military actions: trade route blockade and harvest destruction.
## Pure static functions — caller owns all state.


# -- Constants: Harvest Destruction --------------------------------------------

const HARVEST_HONOR_COST: float = -2.0
const HARVEST_GLORY_COST: float = -0.5
const HARVEST_DISP_TARGETED_CLAN: int = -20
const HARVEST_DISP_OTHER_CLANS: int = -10
const HARVEST_TOPIC_TIER: int = TopicData.Tier.TIER_2
const HARVEST_TOPIC_MOMENTUM: float = 60.0

const HARVEST_NEVER_VIRTUES: Array[String] = ["Jin", "Gi"]
const HARVEST_CONDITIONAL_VIRTUES: Dictionary = {
	"Yu": "no_other_path",
	"Meiyo": "hated_enemy",
	"Chugi": "lord_commands",
	"Makoto": "publicly_declared",
	"Rei": "prior_formal_demand",
}

const EDICT_HONOR_COST: float = -3.0
const EDICT_SYMPATHY_BONUS: int = 5


# -- Constants: Trade Route Blockade -------------------------------------------

const BLOCKADE_HONOR_COST_PER_SEASON: float = -0.5
const BLOCKADE_MIN_PU: float = 1.0
const BLOCKADE_WAR_AUTHORITY: int = 0  # Provincial Raid (WarData.AuthorityLevel.PROVINCIAL_RAID)


# -- Harvest Destruction -------------------------------------------------------

static func can_destroy_harvest(
	virtue: String,
	season: String,
	has_army_in_province: bool,
	condition_met: bool = false,
) -> Dictionary:
	if season != "autumn":
		return {"allowed": false, "reason": "wrong_season"}
	if not has_army_in_province:
		return {"allowed": false, "reason": "no_army_present"}
	if virtue in HARVEST_NEVER_VIRTUES:
		return {"allowed": false, "reason": "personality_block"}
	if HARVEST_CONDITIONAL_VIRTUES.has(virtue):
		if not condition_met:
			return {"allowed": false, "reason": "condition_not_met", "condition": HARVEST_CONDITIONAL_VIRTUES[virtue]}
	return {"allowed": true}


static func execute_harvest_destruction(
	province_id: int,
	ordering_clan: String,
	target_clan: String,
) -> Dictionary:
	return {
		"province_id": province_id,
		"ordering_clan": ordering_clan,
		"target_clan": target_clan,
		"harvest_destroyed": true,
		"honor_change": HARVEST_HONOR_COST,
		"glory_change": HARVEST_GLORY_COST,
		"targeted_clan_disposition": HARVEST_DISP_TARGETED_CLAN,
		"other_clans_disposition": HARVEST_DISP_OTHER_CLANS,
		"generates_topic": true,
		"topic_tier": HARVEST_TOPIC_TIER,
		"generates_crisis": true,
		"crisis_type": "provincial_famine",
	}


static func apply_harvest_destruction(
	province_id: int,
	settlement_meta: Dictionary,
) -> void:
	if not settlement_meta.has(province_id):
		settlement_meta[province_id] = {}
	settlement_meta[province_id]["harvest_destroyed"] = true


static func is_harvest_destroyed(
	province_id: int,
	settlement_meta: Dictionary,
) -> bool:
	var meta: Dictionary = settlement_meta.get(province_id, {})
	return meta.get("harvest_destroyed", false)


# -- Trade Route Blockade ------------------------------------------------------

static func can_blockade(
	army_pu: float,
	is_at_route_node: bool,
) -> Dictionary:
	if army_pu < BLOCKADE_MIN_PU:
		return {"allowed": false, "reason": "insufficient_pu"}
	if not is_at_route_node:
		return {"allowed": false, "reason": "not_at_route_node"}
	return {"allowed": true}


static func execute_blockade(
	route_id: int,
	blocking_clan: String,
	target_clan: String,
) -> Dictionary:
	return {
		"route_id": route_id,
		"blocking_clan": blocking_clan,
		"target_clan": target_clan,
		"route_blocked": true,
		"disruption_reason": "blockade_%s" % blocking_clan,
		"triggers_war_status": true,
		"war_authority": BLOCKADE_WAR_AUTHORITY,
	}


static func apply_blockade(
	route: TradeRouteData,
	disruption_reason: String,
) -> void:
	route.is_disrupted = true
	route.disruption_reason = disruption_reason


static func lift_blockade(
	route: TradeRouteData,
	blocking_clan: String,
) -> bool:
	var expected_reason: String = "blockade_%s" % blocking_clan
	if route.disruption_reason == expected_reason:
		route.is_disrupted = false
		route.disruption_reason = ""
		return true
	return false


static func get_blockaded_routes(
	trade_routes: Array,
	blocking_clan: String,
) -> Array:
	var result: Array = []
	var reason: String = "blockade_%s" % blocking_clan
	for r: Variant in trade_routes:
		if r is TradeRouteData and (r as TradeRouteData).disruption_reason == reason:
			result.append(r as TradeRouteData)
	return result


static func process_seasonal_blockade_honor(
	trade_routes: Array,
	characters_by_id: Dictionary,
) -> Array:
	var results: Array = []
	var clans_with_blockades: Dictionary = {}

	for r: Variant in trade_routes:
		if not (r is TradeRouteData):
			continue
		var route: TradeRouteData = r as TradeRouteData
		if not route.is_disrupted:
			continue
		if not route.disruption_reason.begins_with("blockade_"):
			continue
		var clan: String = route.disruption_reason.substr("blockade_".length())
		if not clans_with_blockades.has(clan):
			clans_with_blockades[clan] = 0
		clans_with_blockades[clan] += 1

	for clan: String in clans_with_blockades:
		var lord_id: int = _find_clan_lord(clan, characters_by_id)
		if lord_id < 0:
			continue
		var route_count: int = clans_with_blockades[clan]
		results.append({
			"clan": clan,
			"lord_id": lord_id,
			"honor_cost": BLOCKADE_HONOR_COST_PER_SEASON * route_count,
			"routes_maintained": route_count,
		})
	return results


static func _find_clan_lord(
	clan: String,
	characters_by_id: Dictionary,
) -> int:
	var best_id: int = -1
	var best_status: float = -1.0
	for id: Variant in characters_by_id:
		var c: L5RCharacterData = characters_by_id[id] as L5RCharacterData
		if c == null:
			continue
		if c.clan != clan:
			continue
		if c.status > best_status:
			best_status = c.status
			best_id = c.character_id
	return best_id


# -- Harvest Destruction Topic -------------------------------------------------

static func generate_harvest_topic(
	ordering_clan: String,
	target_province_id: int,
	next_topic_id: Array,
	ic_day: int,
) -> TopicData:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.slug = "harvest_destroyed_%s_p%d_d%d" % [ordering_clan, target_province_id, ic_day]
	topic.title = "Harvest Destroyed by %s" % ordering_clan
	topic.topic_type = "military"
	topic.variant = "harvest_destroyed"
	topic.tier = TopicData.Tier.TIER_2
	topic.momentum = HARVEST_TOPIC_MOMENTUM
	topic.category = TopicData.Category.POLITICAL
	topic.clan_involved = ordering_clan
	topic.ic_day_created = ic_day
	return topic


# -- Imperial Edict Consequence ------------------------------------------------

static func apply_imperial_edict_consequence(
	lord_id: int,
	target_clan: String,
	_characters_by_id: Dictionary,
) -> Dictionary:
	return {
		"lord_honor_cost": EDICT_HONOR_COST,
		"lord_id": lord_id,
		"sympathy_clan": target_clan,
		"sympathy_bonus": EDICT_SYMPATHY_BONUS,
	}


# -- Personality Gate Helpers --------------------------------------------------

static func is_shourido_virtue(virtue: String) -> bool:
	return virtue in [
		"Seigyo", "Ketsui", "Dosatsu", "Chishiki",
		"Kanpeki", "Ishi", "Kyoryoku",
	]


static func evaluate_ai_harvest_decision(
	virtue: String,
	season: String,
	has_army: bool,
	no_other_path: bool = false,
	hated_enemy: bool = false,
	lord_commands: bool = false,
	publicly_declared: bool = false,
	prior_formal_demand: bool = false,
) -> Dictionary:
	var condition_met: bool = false
	if is_shourido_virtue(virtue):
		condition_met = true
	elif virtue == "Yu":
		condition_met = no_other_path
	elif virtue == "Meiyo":
		condition_met = hated_enemy
	elif virtue == "Chugi":
		condition_met = lord_commands
	elif virtue == "Makoto":
		condition_met = publicly_declared
	elif virtue == "Rei":
		condition_met = prior_formal_demand

	return can_destroy_harvest(virtue, season, has_army, condition_met)
