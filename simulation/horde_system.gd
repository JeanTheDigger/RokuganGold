class_name HordeSystem
## Jigoku Horde generation and combat resolution per GDD s2.4.4–s2.4.7, s2.4.10.
## Pure static functions — caller owns all HordeData and world state.


# -- Horde Frequency (s2.4.4 — LOCKED) ----------------------------------------

## Every 2 seasons a horde roll fires.
const HORDE_ROLL_SEASON_INTERVAL: int = 2

## Base probability a horde forms when the roll fires (50%).
const HORDE_BASE_PROBABILITY: float = 0.50


# -- Invasion Type Weights (s2.4.6 — LOCKED) -----------------------------------

## Cumulative thresholds for a d100 roll.
## Jigoku 60%, Undead Legion 25%, Oni-Led 15%.
const INVASION_TYPE_WEIGHTS: Dictionary = {
	60: Enums.InvasionType.JIGOKU_HORDE,
	85: Enums.InvasionType.UNDEAD_LEGION,
	100: Enums.InvasionType.ONI_LED,
}

## Probability that an Oni-Led horde has the Spawn variant (Pool 3 weighted Rare).
## The GDD labels Spawn as Rare in Pool 3. Using 15% as the "Rare" weight.
const ONI_SPAWN_PROBABILITY: float = 0.15


# -- Shadowlands Unit Stat Blocks (s2.4.7 — LOCKED) ---------------------------
## Keys match Enums.ShadowlandsUnitType enum values.
## Fields: attack, defense, morale, morale_defense, health.
## Special-ability flags are handled in battle resolution (deferred).

const SHADOWLANDS_UNIT_STATS: Dictionary = {
	Enums.ShadowlandsUnitType.BAKEMONO: {
		"attack": 2, "defense": 1, "morale": 7, "morale_defense": 1, "health": 153,
		"immune_routing_contagion": true,
	},
	Enums.ShadowlandsUnitType.BAKEMONO_WARRIOR: {
		"attack": 3, "defense": 2, "morale": 9, "morale_defense": 2, "health": 153,
		"immune_routing_contagion": true,
	},
	Enums.ShadowlandsUnitType.BAKEMONO_ARCHERS: {
		"attack": 3, "defense": 1, "morale": 7, "morale_defense": 1, "health": 153,
		"immune_routing_contagion": true,
		"ranged": true,
		"poison_arrows": true,
	},
	Enums.ShadowlandsUnitType.BAKEMONO_SHAMAN: {
		"attack": 2, "defense": 1, "morale": 10, "morale_defense": 3, "health": 153,
		"immune_routing_contagion": true,
		"dark_spellcraft": true,  # Direct Morale damage instead of standard attack.
	},
	Enums.ShadowlandsUnitType.OMONI_BAKEMONO: {
		"attack": 5, "defense": 3, "morale": 13, "morale_defense": 4, "health": 153,
		"immune_routing_contagion": true,
		"pack_hunters": true,  # +1 Attack adjacent to another Omoni's Bakemono.
	},
	Enums.ShadowlandsUnitType.ZOMBIE: {
		"attack": 3, "defense": 4, "morale": -1, "morale_defense": -1, "health": 153,
		"no_morale": true,
		"immune_routing_contagion": true,
	},
	Enums.ShadowlandsUnitType.SKELETON_WARRIOR: {
		"attack": 4, "defense": 2, "morale": -1, "morale_defense": -1, "health": 153,
		"no_morale": true,
		"first_round_attack_bonus": 1,
	},
	Enums.ShadowlandsUnitType.UNDEAD_REVENANT: {
		"attack": 5, "defense": 4, "morale": -1, "morale_defense": -1, "health": 153,
		"no_morale": true,
		"can_flank": true,
	},
	Enums.ShadowlandsUnitType.MAHO_TSUKAI: {
		"attack": 2, "defense": 2, "morale": 12, "morale_defense": 5, "health": 153,
		"horde_command": true,   # All undead +1 Attack while alive.
		"commander_unit": true,  # Not a combat unit; always in Row 2.
	},
	Enums.ShadowlandsUnitType.OGRE_WARRIOR: {
		"attack": 7, "defense": 6, "morale": 15, "morale_defense": 6, "health": 153,
		"wall_breaker_attack_bonus": 3,  # +3 Attack vs fortifications.
		"wall_breaker_si_ignore": 2,     # Ignores 2 points of SI Defense bonus.
	},
	Enums.ShadowlandsUnitType.RAVENOUS_OGRE: {
		"attack": 9, "defense": 4, "morale": 12, "morale_defense": 4, "health": 153,
		"feeding_frenzy": true,  # +1 Attack per adjacent ally destroyed, max +3.
	},
	Enums.ShadowlandsUnitType.OGRE_WARLORD: {
		"attack": 8, "defense": 7, "morale": 18, "morale_defense": 8, "health": 153,
		"brutal_authority": true,  # Ogres within 2 slots: +1 Attack, +1 MD.
		"wall_breaker_attack_bonus": 3,
		"wall_breaker_si_ignore": 2,
	},
}


# -- Assault SI Hit Table (s2.4.5 — LOCKED) ------------------------------------

const ASSAULT_SI_HIT: Dictionary = {
	Enums.HordeBattleOutcome.DECISIVE_DEFENDER_VICTORY: 1,
	Enums.HordeBattleOutcome.CONTESTED_BATTLE: 2,
	Enums.HordeBattleOutcome.ATTACKER_PUSHED_BACK: 3,
	Enums.HordeBattleOutcome.DEFENDER_OVERRUN: 4,
}


# -- Horde Frequency Roll (s2.4.4 — LOCKED) ------------------------------------

## Returns true if a horde forms this cycle.
## Called every HORDE_ROLL_SEASON_INTERVAL seasons.
static func roll_horde_fires(dice: DiceEngine) -> bool:
	var roll: float = float(dice.roll_and_keep(1, 1, 0).total) / 10.0
	return roll <= HORDE_BASE_PROBABILITY


# -- Invasion Type (s2.4.6 — LOCKED) ------------------------------------------

## Returns an InvasionType enum value based on weighted d100 roll.
static func roll_invasion_type(dice: DiceEngine) -> int:
	var roll: int = (dice.roll_and_keep(1, 1, 0).total % 100) + 1
	var sorted_keys: Array[int] = INVASION_TYPE_WEIGHTS.keys()
	sorted_keys.sort()
	for threshold: int in sorted_keys:
		if roll <= threshold:
			var invasion_type: int = INVASION_TYPE_WEIGHTS[threshold]
			# Check for Spawn variant on Oni-Led (s2.4.8 Pool 3 Spawn = Rare ≈ 15%).
			if invasion_type == Enums.InvasionType.ONI_LED:
				var spawn_roll: float = float(dice.roll_and_keep(1, 1, 0).total) / 10.0
				if spawn_roll <= ONI_SPAWN_PROBABILITY:
					return Enums.InvasionType.ONI_LED_SPAWN
			return invasion_type
	return Enums.InvasionType.JIGOKU_HORDE


# -- Target Tower Selection (s2.4.4 — LOCKED) ----------------------------------

## Returns the province_id of the targeted Wall Tower.
## last_targeted: province_id of the most recently attacked tower (-1 = none).
## The last-targeted tower has 2× probability of being selected again.
static func select_target_tower(
	tower_province_ids: Array[int],
	last_targeted: int,
	dice: DiceEngine,
) -> int:
	if tower_province_ids.is_empty():
		return -1
	if tower_province_ids.size() == 1:
		return tower_province_ids[0]

	# Build weighted list: last-targeted appears twice.
	var pool: Array[int] = []
	for pid: int in tower_province_ids:
		pool.append(pid)
		if pid == last_targeted:
			pool.append(pid)

	var idx: int = dice.roll_and_keep(1, 1, 0).total % pool.size()
	return pool[idx]


# -- Horde Company Generation (s2.4.4, s2.4.6, s2.4.7 — LOCKED) ---------------

## Returns the get_unit_stats() entry for a given ShadowlandsUnitType,
## with a unit_type key added for identification.
static func get_unit_stats(unit_type: int) -> Dictionary:
	var stats: Dictionary = SHADOWLANDS_UNIT_STATS.get(unit_type, {}).duplicate()
	stats["unit_type"] = unit_type
	stats["current_health"] = stats.get("health", 153)
	stats["current_morale"] = stats.get("morale", -1)
	return stats


## Generate horde companies for a JIGOKU_HORDE assault.
## Base composition: 4 Bakemono + 2 Bakemono Warrior + 1 Ogre Warrior.
## Each strength point adds 1 random Bakemono or Ogre Warrior company.
static func _generate_jigoku_companies(
	strength: int, dice: DiceEngine
) -> Array[Dictionary]:
	var companies: Array[Dictionary] = []
	# Base composition.
	for _i: int in range(4):
		companies.append(get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO))
	for _i: int in range(2):
		companies.append(get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO_WARRIOR))
	companies.append(get_unit_stats(Enums.ShadowlandsUnitType.OGRE_WARRIOR))

	# Strength bonus: each point adds 1 Bakemono or Ogre Warrior (50/50).
	for _i: int in range(strength):
		var roll: int = dice.roll_and_keep(1, 1, 0).total % 2
		if roll == 0:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO))
		else:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.OGRE_WARRIOR))

	return companies


## Generate horde companies for an UNDEAD_LEGION assault.
## Base composition: 3 Zombie + 2 Skeleton Warrior + 1 Undead Revenant + 1 Maho-tsukai.
## Each strength point adds 1 Zombie or Skeleton Warrior.
static func _generate_undead_companies(
	strength: int, dice: DiceEngine
) -> Array[Dictionary]:
	var companies: Array[Dictionary] = []
	for _i: int in range(3):
		companies.append(get_unit_stats(Enums.ShadowlandsUnitType.ZOMBIE))
	for _i: int in range(2):
		companies.append(get_unit_stats(Enums.ShadowlandsUnitType.SKELETON_WARRIOR))
	companies.append(get_unit_stats(Enums.ShadowlandsUnitType.UNDEAD_REVENANT))
	companies.append(get_unit_stats(Enums.ShadowlandsUnitType.MAHO_TSUKAI))

	for _i: int in range(strength):
		var roll: int = dice.roll_and_keep(1, 1, 0).total % 2
		if roll == 0:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.ZOMBIE))
		else:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.SKELETON_WARRIOR))

	return companies


## Generate horde companies for an ONI_LED or ONI_LED_SPAWN assault.
## Base Bakemono/Ogre composition as Jigoku Horde (Oni occupies its own slot).
## The Oni itself is not a Company — it is represented separately in HordeData.
static func _generate_oni_led_companies(
	strength: int, dice: DiceEngine
) -> Array[Dictionary]:
	return _generate_jigoku_companies(strength, dice)


## Top-level company generator: returns companies for the given invasion type.
## The Oni (if present) is generated separately via OniGenerator.
static func generate_horde_companies(
	invasion_type: int,
	strength: int,
	dice: DiceEngine,
) -> Array[Dictionary]:
	match invasion_type:
		Enums.InvasionType.JIGOKU_HORDE:
			return _generate_jigoku_companies(strength, dice)
		Enums.InvasionType.UNDEAD_LEGION:
			return _generate_undead_companies(strength, dice)
		Enums.InvasionType.ONI_LED, Enums.InvasionType.ONI_LED_SPAWN:
			return _generate_oni_led_companies(strength, dice)
	return []


# -- Assault SI Hit (s2.4.5 — LOCKED) -----------------------------------------

## Returns the SI damage applied to the Tower after an assault, regardless
## of outcome. Caller reads HordeBattleOutcome from the resolved battle.
static func get_assault_si_hit(outcome: int) -> int:
	return ASSAULT_SI_HIT.get(outcome, 2)


## Apply assault SI hit to a Tower settlement.
## Returns {"new_si": int, "si_hit": int, "breach": bool}.
static func apply_assault_si_hit(
	settlement: SettlementData,
	outcome: int,
) -> Dictionary:
	var si_hit: int = get_assault_si_hit(outcome)
	var old_si: int = settlement.wall_si
	var new_si: int = maxi(0, old_si - si_hit)
	settlement.wall_si = new_si
	return {
		"old_si": old_si,
		"new_si": new_si,
		"si_hit": si_hit,
		"breach": new_si == 0 and outcome == Enums.HordeBattleOutcome.DEFENDER_OVERRUN,
	}


# -- Strength Counter (s2.4.4 — LOCKED) ----------------------------------------

## Increment the strength counter on a failed horde roll.
## Counter is stored in world state as "horde_strength_counter" dict
## keyed by province_id. Counter only resets when a horde fires.
static func increment_strength_counter(
	strength_counters: Dictionary,
	all_tower_province_ids: Array[int],
) -> void:
	# The strength counter accumulates globally — it doesn't track per-tower
	# pre-targeting. A single global counter applies when any horde finally fires.
	# s2.4.4: "Each point of Strength adds one additional Company to the
	# generated horde." The counter is shared across all potential targets.
	var current: int = int(strength_counters.get("global", 0))
	strength_counters["global"] = current + 1
	# province IDs not used in global counter but kept in signature for future per-tower tracking.
	var _tower_ids_kept_for_future := all_tower_province_ids


## Reset the global strength counter after a horde fires.
static func reset_strength_counter(strength_counters: Dictionary) -> void:
	strength_counters["global"] = 0


## Read the current strength counter value.
static func get_strength_counter(strength_counters: Dictionary) -> int:
	return int(strength_counters.get("global", 0))


# -- Full Horde Generation Entry Point -----------------------------------------

## Generate a complete HordeData from the current world state.
## Returns a populated HordeData; caller appends it to world horde list.
static func generate_horde(
	tower_province_ids: Array[int],
	last_targeted_province_id: int,
	strength_counters: Dictionary,
	dice: DiceEngine,
	ic_day: int,
) -> HordeData:
	var horde := HordeData.new()
	horde.ic_day_generated = ic_day

	var invasion_type: int = roll_invasion_type(dice)
	horde.invasion_type = invasion_type

	horde.target_province_id = select_target_tower(
		tower_province_ids, last_targeted_province_id, dice
	)

	var strength: int = get_strength_counter(strength_counters)
	horde.strength_at_formation = strength
	reset_strength_counter(strength_counters)

	horde.companies = generate_horde_companies(invasion_type, strength, dice)

	horde.has_oni = invasion_type in [
		Enums.InvasionType.ONI_LED,
		Enums.InvasionType.ONI_LED_SPAWN,
	]
	horde.has_spawn = invasion_type == Enums.InvasionType.ONI_LED_SPAWN

	return horde


# -- Horde Battle Company Construction (s2.4.5, s2.4.7) -----------------------

## Offset added to ShadowlandsUnitType int values in battle company dicts.
## Prevents collision with CompanyUnitType int values (both enums start at 0).
const SHADOWLANDS_UNIT_TYPE_OFFSET: int = 10000

## Build a battle company dict for a Shadowlands unit, compatible with
## ArmyCombatSystem.resolve_battle. unit_type is offset by
## SHADOWLANDS_UNIT_TYPE_OFFSET to prevent collision with CompanyUnitType.
## wall_breaker_attack_bonus (Ogre Warrior, Ogre Warlord) is applied to
## base_attack directly when is_tower_assault is true.
static func make_horde_battle_company(
	unit_stats: Dictionary,
	row: int,
	column: int,
	side: String,
	company_id: int,
	is_tower_assault: bool = false,
) -> Dictionary:
	var raw_morale: int = unit_stats.get("morale", 10)
	var no_morale: bool = unit_stats.get("no_morale", false)
	# Undead have morale sentinel -1 — use 1 as starting_morale to prevent div-by-zero.
	# no_morale flag causes ArmyCombatSystem to skip all morale checks anyway.
	var start_morale: int = 1 if no_morale else raw_morale
	var cur_morale: int = 0 if no_morale else raw_morale
	var raw_md: int = unit_stats.get("morale_defense", 0)
	var base_md: int = maxi(raw_md, 0)

	var base_attack: int = unit_stats.get("attack", 0)
	if is_tower_assault and unit_stats.get("wall_breaker_attack_bonus", 0) > 0:
		base_attack += unit_stats["wall_breaker_attack_bonus"]

	return {
		"company": null,
		"company_id": company_id,
		"unit_type": SHADOWLANDS_UNIT_TYPE_OFFSET + unit_stats.get("unit_type", 0),
		"starting_health": unit_stats.get("health", 153),
		"current_health": unit_stats.get("current_health", unit_stats.get("health", 153)),
		"starting_morale": start_morale,
		"current_morale": cur_morale,
		"base_attack": base_attack,
		"base_defense": unit_stats.get("defense", 0),
		"base_morale_defense": base_md,
		"row": row,
		"column": column,
		"side": side,
		"is_routed": false,
		"is_destroyed": false,
		"commander": null,
		"commander_bonus": {},
		"commander_injured": false,
		"commander_dead": false,
		"survival_thresholds_triggered": [],
		"no_morale": no_morale,
		"immune_routing_contagion": unit_stats.get("immune_routing_contagion", false),
		# Shadowlands special ability flags (s2.4.7 — LOCKED)
		"sl_dark_spellcraft": unit_stats.get("dark_spellcraft", false),
		"sl_pack_hunters": unit_stats.get("pack_hunters", false),
		"sl_first_round_atk_bonus": unit_stats.get("first_round_attack_bonus", 0),
		"sl_horde_command": unit_stats.get("horde_command", false),
		"sl_feeding_frenzy": unit_stats.get("feeding_frenzy", false),
		"sl_brutal_authority": unit_stats.get("brutal_authority", false),
		# Wall Breaker SI ignore only applies in tower assault context.
		"sl_wall_breaker_si_ignore": unit_stats.get("wall_breaker_si_ignore", 0) if is_tower_assault else 0,
		# True for Zombie, Skeleton Warrior, Undead Revenant — targeted by Horde Command.
		"sl_undead": no_morale,
	}


## Convert an Array[Dictionary] of horde unit_stats (from generate_horde_companies)
## into an Array[Dictionary] of battle companies compatible with ArmyCombatSystem.
## Companies are assigned to rows/columns in waves: front row first.
static func horde_companies_to_battle_states(
	companies: Array[Dictionary],
	side: String,
	start_company_id: int = 5000,
	is_tower_assault: bool = false,
) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var id: int = start_company_id
	# Maho-tsukai goes to row 2 (back); all others to row 1 (front).
	# Columns assigned left to right.
	var front_col: int = 0
	var back_col: int = 0
	for stats: Dictionary in companies:
		var row: int = 2 if stats.get("commander_unit", false) else 1
		var col: int = back_col if row == 2 else front_col
		states.append(make_horde_battle_company(stats, row, col, side, id, is_tower_assault))
		id += 1
		if row == 2:
			back_col += 1
		else:
			front_col += 1
	return states


# -- Horde Assault Combat (s2.4.5, s2.4.7) ------------------------------------

## Map an ArmyCombatSystem victor string + round data to HordeBattleOutcome.
## Per s2.4.5: outcome determines SI hit applied after the battle.
static func _map_battle_outcome(battle_result: Dictionary, rounds: int) -> int:
	var victor: String = battle_result.get("victor", "draw")
	if victor == "defender":
		# Decisive if horde routed quickly (<=2 rounds), else Contested.
		if rounds <= 2:
			return Enums.HordeBattleOutcome.DECISIVE_DEFENDER_VICTORY
		return Enums.HordeBattleOutcome.CONTESTED_BATTLE
	elif victor == "attacker":
		return Enums.HordeBattleOutcome.DEFENDER_OVERRUN
	else:
		# Draw: garrison badly damaged but horde stopped.
		return Enums.HordeBattleOutcome.ATTACKER_PUSHED_BACK


## Resolve a Shadowlands horde assault on a Wall Tower (s2.4.5).
## garrison_states: Array[Dictionary] of battle companies for the defending garrison.
## horde_companies: Array[Dictionary] of unit_stats from HordeSystem (raw dicts).
## si: current Tower SI, used for fortification bonus and the SI hit afterwards.
## tower_settlement: SettlementData whose wall_si will be mutated on return.
## Returns full result including battle log, outcome, SI hit, and breach flag.
static func resolve_horde_assault(
	garrison_states: Array[Dictionary],
	horde_companies: Array[Dictionary],
	tower_settlement: SettlementData,
	dice: DiceEngine,
) -> Dictionary:
	var si: int = tower_settlement.wall_si
	var fortification_bonus: int = WallSystem.get_si_defense_bonus(si)

	var horde_states: Array[Dictionary] = horde_companies_to_battle_states(
		horde_companies, "attacker", 5000, true,
	)

	var battle_result: Dictionary = ArmyCombatSystem.resolve_battle(
		horde_states,
		garrison_states,
		Enums.BattleTerrainType.PLAINS,
		dice,
		false,
		fortification_bonus,
	)

	var rounds: int = battle_result.get("rounds", 0)
	var outcome: int = _map_battle_outcome(battle_result, rounds)

	var si_result: Dictionary = apply_assault_si_hit(tower_settlement, outcome)

	return {
		"outcome": outcome,
		"victor": battle_result.get("victor", "draw"),
		"rounds": rounds,
		"si_hit": si_result["si_hit"],
		"new_si": si_result["new_si"],
		"breach": si_result["breach"],
		"battle_result": battle_result,
	}


# -- Sortie Combat (s2.4.10) ---------------------------------------------------

## Generate a Jigoku Horde scaled to the current SS for a sortie engagement.
## Per s2.4.10: "the game generates a Jigoku Horde proportional to current SS."
## Uses SS tier to determine company count: Low→2, Medium→4, High→6.
static func _generate_sortie_horde_companies(
	ss: int,
	dice: DiceEngine,
) -> Array[Dictionary]:
	var count: int
	if ss >= 9:
		count = 6
	elif ss >= 5:
		count = 4
	else:
		count = 2

	var companies: Array[Dictionary] = []
	for i: int in range(count):
		# Alternate Bakemono / Bakemono Warrior with a single Ogre Warrior at end.
		if i == count - 1:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.OGRE_WARRIOR))
		elif i % 2 == 0:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO))
		else:
			companies.append(get_unit_stats(Enums.ShadowlandsUnitType.BAKEMONO_WARRIOR))
	return companies


## Resolve a sortie's combat against a scaled Jigoku Horde (s2.4.10).
## sortie_states: garrison battle companies committed to the sortie.
## Returns {success, ss_reduction, casualties, battle_result}.
## A successful sortie means the horde is routed/destroyed (attacker wins).
## A failed sortie: garrison takes casualties, no SS reduction.
static func resolve_sortie_combat(
	sortie_states: Array[Dictionary],
	ss_reduction: int,
	ss: int,
	dice: DiceEngine,
) -> Dictionary:
	var horde_companies: Array[Dictionary] = _generate_sortie_horde_companies(ss, dice)
	var horde_states: Array[Dictionary] = horde_companies_to_battle_states(
		horde_companies, "attacker", 6000, false,
	)

	# Sortie fights in the open Shadowlands — no fortification bonus for either side.
	var battle_result: Dictionary = ArmyCombatSystem.resolve_battle(
		horde_states,
		sortie_states,
		Enums.BattleTerrainType.PLAINS,
		dice,
		false,
		0,
	)

	var victor: String = battle_result.get("victor", "draw")
	var success: bool = victor == "defender"

	var casualties: int = 0
	for bc: Dictionary in battle_result.get("defender_states", []):
		casualties += bc["starting_health"] - bc["current_health"]

	return {
		"success": success,
		"ss_reduction": ss_reduction if success else 0,
		"casualties_health": casualties,
		"battle_result": battle_result,
	}
