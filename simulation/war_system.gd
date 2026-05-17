class_name WarSystem
## War Status tracking, War Score management, escalation, peace willingness,
## and mechanical effects per GDD s53. Pure static functions.


# -- War Score Shift Values (s53) -----------------------------------------------

# Each entry: [winner_gain, loser_loss]. Scores are independent per GDD s53.
const SCORE_SHIFTS: Dictionary = {
	"minor_battle": [3, 3],
	"major_battle": [8, 8],
	"decisive_battle": [15, 15],
	"province_captured": [5, 5],
	"castle_captured": [10, 10],
	"siege_won_attacker": [12, 8],
	"siege_won_defender": [8, 5],
	"gunso_chui_killed": [2, 2],
	"taisa_shireikan_killed": [5, 5],
	"rikugunshokan_killed": [10, 10],
	"hostage_rank3": [3, 3],
	"hostage_rank5_champion": [8, 8],
	"lord_assassinated": [12, 12],
	"supply_line_cut": [3, 3],
	"seasonal_attrition": [1, 1],
	"family_daimyo_commits": [5, 0],
	"clan_champion_commits": [10, 0],
	"allied_clan_joins": [8, 0],
	"condemn_clan": [10, 0],
	"authorize_war": [10, 0],
}


# -- War Score Tier Thresholds ---------------------------------------------------

static func get_war_score_tier(score: int) -> WarData.WarScoreTier:
	if score >= 80:
		return WarData.WarScoreTier.DOMINANT
	if score >= 65:
		return WarData.WarScoreTier.WINNING
	if score >= 50:
		return WarData.WarScoreTier.AHEAD
	if score >= 40:
		return WarData.WarScoreTier.BEHIND
	if score >= 25:
		return WarData.WarScoreTier.LOSING
	return WarData.WarScoreTier.DESPERATE


# -- Declaration -----------------------------------------------------------------

static func declare_war(
	war_id: int,
	clan_a: String,
	clan_b: String,
	authority_level: WarData.AuthorityLevel,
	declaring_lord_id: int,
	target_lord_id: int,
	ic_day: int,
) -> WarData:
	var war: WarData = WarData.new()
	war.war_id = war_id
	war.clan_a = clan_a
	war.clan_b = clan_b
	war.authority_level = authority_level
	war.initiator_clan = clan_a
	war.declaring_lord_id = declaring_lord_id
	war.target_lord_id = target_lord_id
	war.ic_day_started = ic_day
	war.war_score_a = 50
	war.war_score_b = 50
	war.is_active = true
	return war


# -- Score Manipulation ----------------------------------------------------------

static func apply_score_shift(
	war: WarData,
	event_type: String,
	winning_clan: String,
) -> Dictionary:
	var pair: Variant = SCORE_SHIFTS.get(event_type, null)
	if pair == null:
		return {"shift": 0, "score_a": war.war_score_a, "score_b": war.war_score_b}
	var gain: int = pair[0]
	var loss: int = pair[1]

	if winning_clan == war.clan_a:
		war.war_score_a = clampi(war.war_score_a + gain, 0, 100)
		if loss > 0:
			war.war_score_b = clampi(war.war_score_b - loss, 0, 100)
	elif winning_clan == war.clan_b:
		war.war_score_b = clampi(war.war_score_b + gain, 0, 100)
		if loss > 0:
			war.war_score_a = clampi(war.war_score_a - loss, 0, 100)

	return {
		"shift": gain,
		"score_a": war.war_score_a,
		"score_b": war.war_score_b,
	}


static func apply_raw_shift(
	war: WarData,
	clan: String,
	amount: int,
) -> void:
	if clan == war.clan_a:
		war.war_score_a = clampi(war.war_score_a + amount, 0, 100)
	elif clan == war.clan_b:
		war.war_score_b = clampi(war.war_score_b + amount, 0, 100)


# -- Escalation ------------------------------------------------------------------

static func can_escalate(war: WarData) -> bool:
	return war.authority_level < WarData.AuthorityLevel.CLAN_WAR


static func escalate(war: WarData) -> WarData.AuthorityLevel:
	if not can_escalate(war):
		return war.authority_level
	war.authority_level = (war.authority_level + 1) as WarData.AuthorityLevel
	return war.authority_level


static func check_auto_escalation(
	war: WarData,
	seasons_active: int,
	castle_fallen: bool,
	enemy_spread_to_other_family: bool,
	enemy_allied_with_other_clan: bool,
	requesting_lord_score: int,
) -> Dictionary:
	var should_escalate: bool = false
	var reason: String = ""

	if requesting_lord_score < 25:
		should_escalate = true
		reason = "lord_score_desperate"
	elif castle_fallen:
		should_escalate = true
		reason = "castle_fallen"
	elif enemy_spread_to_other_family:
		should_escalate = true
		reason = "enemy_spread"
	elif seasons_active > 3:
		should_escalate = true
		reason = "prolonged_conflict"
	elif enemy_allied_with_other_clan:
		should_escalate = true
		reason = "enemy_alliance"

	return {
		"should_escalate": should_escalate,
		"reason": reason,
		"current_level": war.authority_level,
	}


# -- Peace Willingness -----------------------------------------------------------

const PEACE_POSITIVE_VIRTUES: Array[String] = [
	"SEIGYO", "CHISHIKI", "GI", "MAKOTO",
]
const PEACE_NEGATIVE_VIRTUES: Array[String] = [
	"YU", "KETSUI", "ISHI",
]


static func compute_peace_willingness(
	war_score: int,
	terms_cede_territory: bool,
	hostage_held: bool,
	superior_pressuring: bool,
	primary_virtue: String,
) -> int:
	var willingness: int = 0

	var tier: WarData.WarScoreTier = get_war_score_tier(war_score)
	match tier:
		WarData.WarScoreTier.DESPERATE:
			willingness += 40
		WarData.WarScoreTier.LOSING:
			willingness += 25
		WarData.WarScoreTier.BEHIND:
			willingness += 10

	if not terms_cede_territory:
		willingness += 10
	else:
		willingness -= 15

	if hostage_held:
		willingness += 10

	if superior_pressuring:
		willingness += 15

	if primary_virtue.to_upper() in PEACE_POSITIVE_VIRTUES:
		willingness += 10
	elif primary_virtue.to_upper() in PEACE_NEGATIVE_VIRTUES:
		willingness -= 15

	if tier == WarData.WarScoreTier.WINNING or tier == WarData.WarScoreTier.DOMINANT:
		willingness -= 20

	return clampi(willingness, 0, 100)


# -- Honor Cost of Asking for Aid ------------------------------------------------

static func get_aid_request_honor_cost(war_score: int) -> float:
	if war_score < 25:
		return 0.0
	if war_score < 40:
		return -1.0
	return -0.5


static func get_refusal_honor_cost(
	authority_level: WarData.AuthorityLevel,
) -> float:
	match authority_level:
		WarData.AuthorityLevel.FAMILY_WAR:
			return -2.0
		WarData.AuthorityLevel.CLAN_WAR:
			return -3.0
	return -1.0


static func get_refusal_disposition_effects() -> Dictionary:
	return {
		"direct_vassals": -15,
		"abandoned_family": -20,
		"neighboring_lords": -5,
		"imperial_court": -10,
	}


static func get_territory_fall_honor_cost() -> float:
	return -2.0


# -- Alliances -------------------------------------------------------------------

static func add_ally(
	war: WarData,
	allied_clan: String,
	side: String,
) -> void:
	if side == "a" and allied_clan not in war.allied_clans_a:
		war.allied_clans_a.append(allied_clan)
	elif side == "b" and allied_clan not in war.allied_clans_b:
		war.allied_clans_b.append(allied_clan)


static func remove_ally(
	war: WarData,
	clan: String,
) -> void:
	war.allied_clans_a.erase(clan)
	war.allied_clans_b.erase(clan)


static func get_all_combatant_clans(war: WarData) -> Array[String]:
	var clans: Array[String] = [war.clan_a, war.clan_b]
	for c: String in war.allied_clans_a:
		if c not in clans:
			clans.append(c)
	for c: String in war.allied_clans_b:
		if c not in clans:
			clans.append(c)
	return clans


static func is_clan_involved(war: WarData, clan: String) -> bool:
	return (
		clan == war.clan_a
		or clan == war.clan_b
		or clan in war.allied_clans_a
		or clan in war.allied_clans_b
	)


static func get_clan_side(war: WarData, clan: String) -> String:
	if clan == war.clan_a or clan in war.allied_clans_a:
		return "a"
	if clan == war.clan_b or clan in war.allied_clans_b:
		return "b"
	return ""


# -- Resolution ------------------------------------------------------------------

static func end_war(
	war: WarData,
	resolution_type: String,
) -> void:
	war.is_active = false
	war.resolution_type = resolution_type


static func is_annihilated(war: WarData, clan: String) -> bool:
	if clan == war.clan_a:
		return war.war_score_a == 0
	if clan == war.clan_b:
		return war.war_score_b == 0
	return false


# -- Seasonal Effects ------------------------------------------------------------

static func process_seasonal_attrition(war: WarData) -> void:
	war.seasons_active += 1
	apply_score_shift(war, "seasonal_attrition", war.initiator_clan)


# GDD s53 specifies this penalty exists but does not give a value. -2/season is a placeholder.
const WAR_DISPOSITION_PENALTY_PER_SEASON: int = -2

static func get_active_war_disposition_penalty(seasons_active: int) -> int:
	return WAR_DISPOSITION_PENALTY_PER_SEASON * seasons_active


# -- Province Capture Tracking ---------------------------------------------------

static func record_province_capture(
	war: WarData,
	province_id: int,
	capturing_clan: String,
) -> void:
	if capturing_clan == war.clan_a or capturing_clan in war.allied_clans_a:
		if province_id not in war.provinces_captured_by_a:
			war.provinces_captured_by_a.append(province_id)
		war.provinces_captured_by_b.erase(province_id)
	elif capturing_clan == war.clan_b or capturing_clan in war.allied_clans_b:
		if province_id not in war.provinces_captured_by_b:
			war.provinces_captured_by_b.append(province_id)
		war.provinces_captured_by_a.erase(province_id)


# -- Mechanical Effects of Active War (s53) --------------------------------------

static func are_clans_at_war(
	wars: Array[WarData],
	clan_a: String,
	clan_b: String,
) -> bool:
	for war: WarData in wars:
		if not war.is_active:
			continue
		var side_a: String = get_clan_side(war, clan_a)
		var side_b: String = get_clan_side(war, clan_b)
		if side_a != "" and side_b != "" and side_a != side_b:
			return true
	return false


static func get_war_between(
	wars: Array[WarData],
	clan_a: String,
	clan_b: String,
) -> WarData:
	for war: WarData in wars:
		if not war.is_active:
			continue
		var side_a: String = get_clan_side(war, clan_a)
		var side_b: String = get_clan_side(war, clan_b)
		if side_a != "" and side_b != "" and side_a != side_b:
			return war
	return null


static func get_active_wars_for_clan(
	wars: Array[WarData],
	clan: String,
) -> Array[WarData]:
	var result: Array[WarData] = []
	for war: WarData in wars:
		if war.is_active and is_clan_involved(war, clan):
			result.append(war)
	return result


# -- Conversion for NPC Context (existing code expects Dictionary arrays) --------

static func to_context_dict(war: WarData) -> Dictionary:
	return {
		"war_id": war.war_id,
		"clan_a": war.clan_a,
		"clan_b": war.clan_b,
		"authority_level": war.authority_level,
		"war_score_a": war.war_score_a,
		"war_score_b": war.war_score_b,
		"initiator_clan": war.initiator_clan,
		"is_active": war.is_active,
		"seasons_active": war.seasons_active,
		"_war_ref": war,
	}


static func get_enemy_clan_from_war(war: Dictionary, own_clan: String) -> String:
	if war.get("clan_a", "") == own_clan:
		return war.get("clan_b", "")
	if war.get("clan_b", "") == own_clan:
		return war.get("clan_a", "")
	return ""


static func wars_to_context_array(wars: Array[WarData]) -> Array:
	var result: Array = []
	for war: WarData in wars:
		if war.is_active:
			result.append(to_context_dict(war))
	return result
