class_name WarTermination
## War termination mechanics per GDD s53 (ENDING WAR STATUS, PEACE WILLINGNESS).
## Four resolution mechanisms: formal surrender, negotiated settlement,
## imperial edict, annihilation. Pure static functions.


enum ResolutionType {
	FORMAL_SURRENDER,
	NEGOTIATED_SETTLEMENT,
	IMPERIAL_EDICT,
	ANNIHILATION,
}

const RESOLUTION_NAMES: Dictionary = {
	ResolutionType.FORMAL_SURRENDER: "formal_surrender",
	ResolutionType.NEGOTIATED_SETTLEMENT: "negotiated_settlement",
	ResolutionType.IMPERIAL_EDICT: "imperial_edict",
	ResolutionType.ANNIHILATION: "annihilation",
}

# Peace willingness threshold — at or above this value the lord accepts terms.
const PEACE_ACCEPTANCE_THRESHOLD: int = 50

# Disposition penalty toward the enemy when war ends with ceded territory.
const CEDE_TERRITORY_DISPOSITION: int = -15

# Honor cost for the surrendering side's lord.
const SURRENDER_HONOR_COST: float = -1.0

# Honor gain for negotiating peace (both sides, negotiated settlement only).
const PEACE_NEGOTIATION_HONOR: float = 0.1

# Stability bonus to all involved provinces when war ends.
const PEACE_STABILITY_BONUS: int = 3

# War score thresholds for term severity.
const DOMINANT_THRESHOLD: int = 80
const WINNING_THRESHOLD: int = 65
const AHEAD_THRESHOLD: int = 50


# -- Peace Terms ---------------------------------------------------------------

static func compute_peace_terms(
	war: WarData,
	proposing_clan: String,
) -> Dictionary:
	## Compute what terms the winning side can demand based on war score.
	## Returns a terms dict with: territory_demand, hostage_return,
	## honor_concession, status_quo_ante.
	var proposer_side: String = WarSystem.get_clan_side(war, proposing_clan)
	var proposer_score: int = _get_score_for_side(war, proposer_side)
	var opponent_score: int = _get_score_for_side(war, _opposite_side(proposer_side))

	var terms: Dictionary = {
		"proposing_clan": proposing_clan,
		"proposer_score": proposer_score,
		"opponent_score": opponent_score,
		"territory_demand": false,
		"territory_count": 0,
		"hostage_return": false,
		"honor_concession": false,
		"status_quo_ante": false,
	}

	if proposer_score >= DOMINANT_THRESHOLD:
		# Dominant — can demand everything.
		terms["territory_demand"] = true
		var captured: Array = _get_captured_provinces(war, proposer_side)
		terms["territory_count"] = captured.size()
		terms["honor_concession"] = true
	elif proposer_score >= WINNING_THRESHOLD:
		# Winning — can demand captured territory kept.
		var captured: Array = _get_captured_provinces(war, proposer_side)
		if not captured.is_empty():
			terms["territory_demand"] = true
			terms["territory_count"] = captured.size()
	elif proposer_score >= AHEAD_THRESHOLD:
		# Ahead — modest terms, keep some captured territory.
		var captured: Array = _get_captured_provinces(war, proposer_side)
		if captured.size() > 1:
			terms["territory_demand"] = true
			terms["territory_count"] = ceili(captured.size() / 2.0)
	else:
		# Behind/Losing/Desperate — status quo ante is the best they can get.
		terms["status_quo_ante"] = true

	# Hostage return: always included if the other side holds hostages.
	var opponent_captured: Array = _get_captured_provinces(war, _opposite_side(proposer_side))
	if not opponent_captured.is_empty():
		terms["hostage_return"] = true

	return terms


# -- Evaluate Peace Acceptance -------------------------------------------------

static func evaluate_peace_acceptance(
	war: WarData,
	terms: Dictionary,
	receiving_clan: String,
	receiving_virtue: String,
	hostage_held: bool,
	superior_pressuring: bool,
) -> Dictionary:
	## Evaluate whether the receiving clan's lord would accept the proposed
	## peace terms. Uses WarSystem.compute_peace_willingness() internally.
	## Returns {accepted, willingness, threshold, reason}.
	var side: String = WarSystem.get_clan_side(war, receiving_clan)
	var score: int = _get_score_for_side(war, side)

	var cede_territory: bool = terms.get("territory_demand", false)

	var willingness: int = WarSystem.compute_peace_willingness(
		score,
		cede_territory,
		hostage_held,
		superior_pressuring,
		receiving_virtue,
	)

	var accepted: bool = willingness >= PEACE_ACCEPTANCE_THRESHOLD
	var reason: String = ""
	if accepted:
		reason = "willingness_met"
	elif willingness >= 40:
		reason = "close_but_rejected"
	elif score >= WINNING_THRESHOLD:
		reason = "winning_refuses"
	else:
		reason = "insufficient_willingness"

	return {
		"accepted": accepted,
		"willingness": willingness,
		"threshold": PEACE_ACCEPTANCE_THRESHOLD,
		"reason": reason,
		"war_score": score,
	}


# -- Resolve Formal Surrender --------------------------------------------------

static func resolve_formal_surrender(
	war: WarData,
	surrendering_clan: String,
) -> Dictionary:
	## The surrendering clan yields. War ends immediately.
	## Returns effects dict with disposition/honor changes.
	var winner_clan: String = _get_opponent_clan(war, surrendering_clan)

	WarSystem.end_war(war, RESOLUTION_NAMES[ResolutionType.FORMAL_SURRENDER])

	return {
		"resolution": RESOLUTION_NAMES[ResolutionType.FORMAL_SURRENDER],
		"war_id": war.war_id,
		"winner_clan": winner_clan,
		"loser_clan": surrendering_clan,
		"surrendering_clan": surrendering_clan,
		"honor_cost_loser": SURRENDER_HONOR_COST,
		"stability_bonus": PEACE_STABILITY_BONUS,
		"territory_transferred": _get_captured_provinces(
			war, WarSystem.get_clan_side(war, winner_clan)
		),
	}


# -- Resolve Negotiated Settlement ---------------------------------------------

static func resolve_negotiated_settlement(
	war: WarData,
	terms: Dictionary,
) -> Dictionary:
	## Both sides accept terms. War ends.
	## Returns effects dict.
	var proposing_clan: String = terms.get("proposing_clan", "")
	var receiving_clan: String = _get_opponent_clan(war, proposing_clan)

	WarSystem.end_war(war, RESOLUTION_NAMES[ResolutionType.NEGOTIATED_SETTLEMENT])

	var territory_transferred: Array = []
	if terms.get("territory_demand", false):
		var proposer_side: String = WarSystem.get_clan_side(war, proposing_clan)
		var all_captured: Array = _get_captured_provinces(war, proposer_side)
		var count: int = mini(terms.get("territory_count", 0), all_captured.size())
		territory_transferred = all_captured.slice(0, count)

	return {
		"resolution": RESOLUTION_NAMES[ResolutionType.NEGOTIATED_SETTLEMENT],
		"war_id": war.war_id,
		"proposing_clan": proposing_clan,
		"receiving_clan": receiving_clan,
		"honor_both": PEACE_NEGOTIATION_HONOR,
		"stability_bonus": PEACE_STABILITY_BONUS,
		"status_quo_ante": terms.get("status_quo_ante", false),
		"territory_transferred": territory_transferred,
		"honor_concession": terms.get("honor_concession", false),
	}


# -- Resolve Imperial Edict ---------------------------------------------------

static func resolve_imperial_edict(war: WarData) -> Dictionary:
	## Emperor orders cease of hostilities. Both sides legally obligated.
	WarSystem.end_war(war, RESOLUTION_NAMES[ResolutionType.IMPERIAL_EDICT])

	return {
		"resolution": RESOLUTION_NAMES[ResolutionType.IMPERIAL_EDICT],
		"war_id": war.war_id,
		"clan_a": war.clan_a,
		"clan_b": war.clan_b,
		"status_quo_ante": true,
		"stability_bonus": PEACE_STABILITY_BONUS,
	}


# -- Resolve Annihilation ------------------------------------------------------

static func resolve_annihilation(
	war: WarData,
	annihilated_clan: String,
) -> Dictionary:
	## One side is militarily destroyed. War ends.
	var victor_clan: String = _get_opponent_clan(war, annihilated_clan)

	WarSystem.end_war(war, RESOLUTION_NAMES[ResolutionType.ANNIHILATION])

	return {
		"resolution": RESOLUTION_NAMES[ResolutionType.ANNIHILATION],
		"war_id": war.war_id,
		"victor_clan": victor_clan,
		"annihilated_clan": annihilated_clan,
		"stability_bonus": 0,
	}


# -- Check for Annihilation (daily scan) --------------------------------------

static func check_annihilation(war: WarData) -> Dictionary:
	## Check if either side has been annihilated (war score 0).
	## Returns {annihilated: bool, clan: String} or {annihilated: false}.
	if war.war_score_a == 0:
		return {"annihilated": true, "clan": war.clan_a}
	if war.war_score_b == 0:
		return {"annihilated": true, "clan": war.clan_b}
	return {"annihilated": false, "clan": ""}


# -- NEGOTIATE_SURRENDER Action Resolution ------------------------------------

static func resolve_negotiate_surrender(
	character: L5RCharacterData,
	ctx_war: Dictionary,
	target_virtue: String,
	hostage_held: bool,
	superior_pressuring: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	## Resolve a NEGOTIATE_SURRENDER action. The character is attempting to
	## negotiate peace with the enemy. Uses Courtier + Awareness vs TN 20.
	## On success, evaluate whether the enemy accepts.
	## ctx_war must contain: war (WarData), own_clan, enemy_clan.
	var war: WarData = ctx_war.get("war")
	var own_clan: String = ctx_war.get("own_clan", "")
	var enemy_clan: String = ctx_war.get("enemy_clan", "")

	if war == null or own_clan.is_empty() or enemy_clan.is_empty():
		return {"failed": true, "reason": "no_active_war"}

	var roll_result: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Courtier", 20
	)

	if not roll_result.get("success", false):
		return {
			"failed": true,
			"reason": "negotiation_failed",
			"roll_total": roll_result.get("total", 0),
			"tn": 20,
		}

	var margin: int = roll_result.get("total", 0) - 20
	var raises: int = maxi(0, margin / 5)

	var terms: Dictionary = compute_peace_terms(war, own_clan)

	# Raises improve terms for the negotiator: each raise softens demands,
	# making acceptance more likely (we reduce territory_count).
	if raises > 0 and terms.get("territory_demand", false):
		var reduced: int = maxi(0, terms["territory_count"] - raises)
		if reduced == 0:
			terms["territory_demand"] = false
		terms["territory_count"] = reduced

	var acceptance: Dictionary = evaluate_peace_acceptance(
		war, terms, enemy_clan, target_virtue,
		hostage_held, superior_pressuring,
	)

	if not acceptance.get("accepted", false):
		return {
			"failed": false,
			"peace_accepted": false,
			"reason": acceptance.get("reason", "rejected"),
			"willingness": acceptance.get("willingness", 0),
			"roll_total": roll_result.get("total", 0),
			"raises": raises,
			"terms": terms,
		}

	# Peace accepted — flag for DayOrchestrator to process.
	return {
		"failed": false,
		"peace_accepted": true,
		"requires_peace_resolution": true,
		"resolution_type": "negotiated_settlement",
		"war_id": war.war_id,
		"terms": terms,
		"own_clan": own_clan,
		"enemy_clan": enemy_clan,
		"willingness": acceptance.get("willingness", 0),
		"roll_total": roll_result.get("total", 0),
		"raises": raises,
		"honor_change": PEACE_NEGOTIATION_HONOR,
	}


# -- Generate War End Topic ----------------------------------------------------

static func generate_war_end_topic(
	resolution: Dictionary,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	## Create a topic for the war ending.
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1

	var res_type: String = resolution.get("resolution", "unknown")
	topic.slug = "war_ended_%s_%d" % [res_type, ic_day]
	topic.topic_type = "war_end"
	topic.variant = res_type
	topic.category = TopicData.Category.POLITICAL

	match res_type:
		"formal_surrender":
			topic.momentum = 60.0
			topic.tier = TopicData.Tier.TIER_2
			topic.clan_involved = resolution.get("loser_clan", "")
			topic.subject_role = "VICTIM"
		"negotiated_settlement":
			topic.momentum = 40.0
			topic.tier = TopicData.Tier.TIER_3
		"imperial_edict":
			topic.momentum = 70.0
			topic.tier = TopicData.Tier.TIER_2
		"annihilation":
			topic.momentum = 80.0
			topic.tier = TopicData.Tier.TIER_1
			topic.clan_involved = resolution.get("annihilated_clan", "")
			topic.subject_role = "VICTIM"

	topic.ic_day_created = ic_day
	return topic


# -- Helpers -------------------------------------------------------------------

static func _get_score_for_side(war: WarData, side: String) -> int:
	if side == "a":
		return war.war_score_a
	if side == "b":
		return war.war_score_b
	return 50


static func _opposite_side(side: String) -> String:
	if side == "a":
		return "b"
	return "a"


static func _get_captured_provinces(war: WarData, side: String) -> Array:
	if side == "a":
		return war.provinces_captured_by_a
	if side == "b":
		return war.provinces_captured_by_b
	return []


static func _get_opponent_clan(war: WarData, clan: String) -> String:
	if clan == war.clan_a:
		return war.clan_b
	if clan == war.clan_b:
		return war.clan_a
	return ""


# -- Trade Route Suspension (GDD s53 Mechanical Effects) -----------------------

static func suspend_trade_routes_for_war(
	trade_routes: Array,
	provinces: Dictionary,
	clan_a: String,
	clan_b: String,
) -> Array[Dictionary]:
	## Disrupt all trade routes connecting provinces of two warring clans.
	## Per GDD s53: "Trade routes between the two clans are suspended."
	var results: Array[Dictionary] = []
	for route: Variant in trade_routes:
		var r: TradeRouteData = route as TradeRouteData
		if r == null or r.is_disrupted:
			continue
		var prov_a: ProvinceData = provinces.get(r.province_a_id) as ProvinceData
		var prov_b: ProvinceData = provinces.get(r.province_b_id) as ProvinceData
		if prov_a == null or prov_b == null:
			continue
		var connects_clan_a: bool = prov_a.clan == clan_a or prov_b.clan == clan_a
		var connects_clan_b: bool = prov_a.clan == clan_b or prov_b.clan == clan_b
		if connects_clan_a and connects_clan_b:
			RiceMarketSystem.disrupt_route(r, "war_%s_%s" % [clan_a, clan_b])
			results.append({
				"route_id": r.route_id,
				"province_a_id": r.province_a_id,
				"province_b_id": r.province_b_id,
				"action": "suspended",
			})
	return results


static func restore_trade_routes_for_peace(
	trade_routes: Array,
	clan_a: String,
	clan_b: String,
) -> Array[Dictionary]:
	## Restore trade routes that were disrupted by a specific war.
	var war_reason_1: String = "war_%s_%s" % [clan_a, clan_b]
	var war_reason_2: String = "war_%s_%s" % [clan_b, clan_a]
	var results: Array[Dictionary] = []
	for route: Variant in trade_routes:
		var r: TradeRouteData = route as TradeRouteData
		if r == null or not r.is_disrupted:
			continue
		if r.disruption_reason == war_reason_1 or r.disruption_reason == war_reason_2:
			RiceMarketSystem.restore_route(r)
			results.append({
				"route_id": r.route_id,
				"province_a_id": r.province_a_id,
				"province_b_id": r.province_b_id,
				"action": "restored",
			})
	return results
