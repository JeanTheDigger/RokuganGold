class_name KokuCascadeSystem
## Monthly Koku flow per GDD s4.3.9.
## Phase 1: Pool upward — drain settlement koku_stockpile to clan champion.
## Phase 2: Cascade downward — champion → family → provincial → local daimyo.
## Phase 3: Pay individual character stipends from local daimyo pool.
## Personality modifier adjusts each lord's retention (±15%).


# -- Tier Retention Rates per GDD s4.3.9 --------------------------------------

const TIER_RETENTION: Dictionary = {
	"clan_champion": 0.40,
	"family_daimyo": 0.25,
	"provincial_daimyo": 0.20,
	"local_daimyo": 0.15,
}

# -- Individual Stipend Amounts (individual koku per month) --------------------

const STIPEND_BY_LORD_TIER: Dictionary = {
	"clan_champion": 5.0,
	"family_daimyo": 3.0,
	"provincial_daimyo": 2.0,
	"local_daimyo": 1.0,
	"indirect": 0.6,
}

# -- Scale Conversion ---------------------------------------------------------

const INDIVIDUAL_KOKU_PER_UNIT: float = 500.0

# -- Consequence Thresholds per GDD s4.3.9 ------------------------------------

const REDUCED_STIPEND_FLOOR: float = 0.50
const REDUCED_STIPEND_CEILING: float = 0.75
const DISPOSITION_REDUCED: int = -2
const DISPOSITION_SEVERELY_REDUCED: int = -5
const DISPOSITION_NO_STIPEND: int = -10
const MONTHS_WITHOUT_PAY_CRISIS: int = 3
const MAX_LORD_CHAIN_DEPTH: int = 10


static func get_tier_for_lord_rank(rank: Enums.LordRank) -> String:
	match rank:
		Enums.LordRank.CLAN_CHAMPION:
			return "clan_champion"
		Enums.LordRank.FAMILY_DAIMYO:
			return "family_daimyo"
		Enums.LordRank.PROVINCIAL_DAIMYO:
			return "provincial_daimyo"
		Enums.LordRank.CITY_DAIMYO, Enums.LordRank.VILLAGE_HEADMAN:
			return "local_daimyo"
		_:
			return "local_daimyo"


static func process_monthly_koku_flow(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	clans: Dictionary,
	months_in_season: int,
) -> Dictionary:
	var upward: Dictionary = _pool_upward(settlements, clans, months_in_season)
	var downward: Dictionary = _cascade_downward(
		upward, characters, characters_by_id,
	)
	var stipends: Dictionary = _pay_individual_stipends(
		downward, characters, characters_by_id,
	)
	return {
		"upward": upward,
		"downward": downward,
		"stipends": stipends,
	}


static func _pool_upward(
	settlements: Array[SettlementData],
	clans: Dictionary,
	months_in_season: int,
) -> Dictionary:
	var clan_monthly_koku: Dictionary = {}
	var divisor: float = maxf(1.0, float(months_in_season))
	for clan_name: String in clans:
		var cd: ClanData = clans[clan_name] as ClanData
		if cd == null:
			continue
		var clan_total: float = 0.0
		for s: SettlementData in settlements:
			if s.province_id not in cd.province_ids:
				continue
			var monthly_share: float = s.koku_stockpile / divisor
			s.koku_stockpile -= monthly_share
			clan_total += monthly_share
		clan_monthly_koku[clan_name] = clan_total
	return clan_monthly_koku


static func _cascade_downward(
	clan_pools: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> Dictionary:
	var lord_pools: Dictionary = {}
	var champion_map: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		var rank: Enums.LordRank = CivilianOrderBudget.lord_rank_from_status(c.status)
		if rank == Enums.LordRank.CLAN_CHAMPION:
			champion_map[c.clan] = c.character_id

	for clan_name: String in clan_pools:
		var pool: float = clan_pools[clan_name]
		if pool <= 0.0:
			continue
		var champ_id: int = champion_map.get(clan_name, -1)
		if champ_id < 0:
			continue
		var champ: L5RCharacterData = characters_by_id.get(champ_id) as L5RCharacterData
		if champ == null:
			continue
		var stip_mod: float = ResourceTick.compute_stipend_modifier(
			champ.bushido_virtue, champ.shourido_virtue,
		)
		var retention: float = clampf(
			TIER_RETENTION["clan_champion"] - stip_mod, 0.0, 1.0,
		)
		var retained: float = pool * retention
		var passed_down: float = pool - retained
		champ.koku += retained * INDIVIDUAL_KOKU_PER_UNIT
		lord_pools[champ_id] = {"tier": "clan_champion", "retained": retained, "passed_down": passed_down}
		_distribute_to_subordinates(
			champ_id, passed_down, characters, characters_by_id, lord_pools,
		)
	return lord_pools


static func _distribute_to_subordinates(
	lord_id: int,
	pool_arriving: float,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	lord_pools: Dictionary,
) -> void:
	if pool_arriving <= 0.0:
		return
	var subordinate_lords: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id != lord_id:
			continue
		var rank: Enums.LordRank = CivilianOrderBudget.lord_rank_from_status(c.status)
		if rank >= Enums.LordRank.CITY_DAIMYO:
			subordinate_lords.append(c)
	if subordinate_lords.is_empty():
		return
	var share_per_lord: float = pool_arriving / float(subordinate_lords.size())
	for sub: L5RCharacterData in subordinate_lords:
		var tier: String = get_tier_for_lord_rank(
			CivilianOrderBudget.lord_rank_from_status(sub.status),
		)
		var stip_mod: float = ResourceTick.compute_stipend_modifier(
			sub.bushido_virtue, sub.shourido_virtue,
		)
		var retention: float = clampf(
			TIER_RETENTION.get(tier, 0.15) - stip_mod, 0.0, 1.0,
		)
		var retained: float = share_per_lord * retention
		var passed_down: float = share_per_lord - retained
		sub.koku += retained * INDIVIDUAL_KOKU_PER_UNIT
		lord_pools[sub.character_id] = {
			"tier": tier, "retained": retained, "passed_down": passed_down,
		}
		_distribute_to_subordinates(
			sub.character_id, passed_down, characters, characters_by_id, lord_pools,
		)


static func _pay_individual_stipends(
	lord_pools: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> Dictionary:
	var assignments: Dictionary = {}
	var pool_demands: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id < 0:
			continue
		var rank: Enums.LordRank = CivilianOrderBudget.lord_rank_from_status(c.status)
		if rank >= Enums.LordRank.CITY_DAIMYO:
			continue
		var is_indirect: bool = false
		var funding_lord_id: int = -1
		var base_stipend: float = 0.0
		if lord_pools.has(c.lord_id):
			funding_lord_id = c.lord_id
			var lord: L5RCharacterData = characters_by_id.get(c.lord_id) as L5RCharacterData
			if lord == null:
				continue
			var lord_rank: Enums.LordRank = CivilianOrderBudget.lord_rank_from_status(lord.status)
			var lord_tier: String = get_tier_for_lord_rank(lord_rank)
			base_stipend = STIPEND_BY_LORD_TIER.get(lord_tier, 1.0)
		else:
			funding_lord_id = _find_funding_lord_id(
				c.character_id, characters_by_id, lord_pools,
			)
			if funding_lord_id < 0:
				continue
			is_indirect = true
			base_stipend = STIPEND_BY_LORD_TIER["indirect"]
		assignments[c.character_id] = {
			"funding_lord_id": funding_lord_id,
			"base_stipend": base_stipend,
			"is_indirect": is_indirect,
		}
		pool_demands[funding_lord_id] = pool_demands.get(funding_lord_id, 0.0) + base_stipend
	var results: Dictionary = {}
	for c: L5RCharacterData in characters:
		if not assignments.has(c.character_id):
			continue
		var asgn: Dictionary = assignments[c.character_id]
		var funding_lord_id: int = asgn["funding_lord_id"]
		var base_stipend: float = asgn["base_stipend"]
		var lord_pool_data: Dictionary = lord_pools.get(funding_lord_id, {})
		var pool_koku: float = lord_pool_data.get("passed_down", 0.0) * INDIVIDUAL_KOKU_PER_UNIT
		var total_needed: float = pool_demands.get(funding_lord_id, 0.0)
		var ratio: float = 1.0
		if total_needed > 0.0 and pool_koku < total_needed:
			ratio = pool_koku / total_needed
		var actual_payment: float = base_stipend * ratio
		c.koku += actual_payment
		var consequence: int = _stipend_consequence(ratio)
		if consequence != 0:
			var old_disp: int = c.disposition_values.get(c.lord_id, 0)
			c.disposition_values[c.lord_id] = clampi(old_disp + consequence, -100, 100)
		results[c.character_id] = {
			"base_stipend": base_stipend,
			"actual_payment": actual_payment,
			"ratio": ratio,
			"consequence": consequence,
			"is_indirect": asgn["is_indirect"],
		}
	return results


static func _find_funding_lord_id(
	character_id: int,
	characters_by_id: Dictionary,
	lord_pools: Dictionary,
) -> int:
	var current_id: int = character_id
	for _i: int in range(MAX_LORD_CHAIN_DEPTH):
		var c: L5RCharacterData = characters_by_id.get(current_id) as L5RCharacterData
		if c == null:
			return -1
		if c.lord_id < 0:
			return -1
		if lord_pools.has(c.lord_id):
			return c.lord_id
		current_id = c.lord_id
	return -1


static func _stipend_consequence(ratio: float) -> int:
	if ratio >= REDUCED_STIPEND_CEILING:
		return 0
	if ratio >= REDUCED_STIPEND_FLOOR:
		return DISPOSITION_REDUCED
	if ratio > 0.0:
		return DISPOSITION_SEVERELY_REDUCED
	return DISPOSITION_NO_STIPEND
