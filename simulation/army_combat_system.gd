class_name ArmyCombatSystem
## Resolves army-level battles per GDD s11.7.
## Victoria II-inspired grid combat: Companies fight in columns with Row 1 (front)
## and Row 2 (reserve/archer). Resolution is fully automated — no player input.


# -- Unit Stat Blocks (GDD s11.7) -----------------------------------------------

const UNIT_STATS: Dictionary = {
	Enums.CompanyUnitType.PEASANT_LEVY: {
		"health": 153, "attack": 1, "defense": 1, "morale": 8, "morale_defense": 1,
	},
	Enums.CompanyUnitType.ASHIGARU_SPEARMEN: {
		"health": 153, "attack": 3, "defense": 4, "morale": 12, "morale_defense": 3,
	},
	Enums.CompanyUnitType.ASHIGARU_ARCHERS: {
		"health": 153, "attack": 4, "defense": 2, "morale": 10, "morale_defense": 2,
	},
	Enums.CompanyUnitType.BUSHI_RETAINER: {
		"health": 153, "attack": 6, "defense": 5, "morale": 18, "morale_defense": 8,
	},
	Enums.CompanyUnitType.LIGHT_CAVALRY: {
		"health": 153, "attack": 3, "defense": 2, "morale": 11, "morale_defense": 4,
	},
	Enums.CompanyUnitType.RONIN: {
		"health": 153, "attack": 5, "defense": 4, "morale": 10, "morale_defense": 4,
	},
	Enums.CompanyUnitType.GARRISON: {
		"health": 153, "attack": 3, "defense": 5, "morale": 16, "morale_defense": 7,
	},
}

const GARRISON_HOME_DEFENSE_BONUS: int = 2

const ASHIGARU_SPEARMEN_VS_CAVALRY_BONUS: int = 3

const LIGHT_CAVALRY_FLANK_BONUS: int = 4
const BASE_FLANK_BONUS: int = 2

const ENCIRCLEMENT_MORALE_DAMAGE: int = 10


# -- Commander Bonus (GDD s11.7) -------------------------------------------------

const CLAN_RING_PRIORITY: Dictionary = {
	"Lion": ["attack", "defense", "morale"],
	"Scorpion": ["attack", "defense", "morale"],
	"Unicorn": ["attack", "defense", "morale"],
	"Crab": ["defense", "attack", "morale"],
	"Crane": ["defense", "attack", "morale"],
	"Dragon": ["morale", "defense", "attack"],
	"Phoenix": ["morale", "attack", "defense"],
	"Wasp": ["attack", "defense", "morale"],
	"Mantis": ["attack", "defense", "morale"],
	"Bat": ["attack", "defense", "morale"],
	"Snake": ["attack", "defense", "morale"],
	"Hare": ["attack", "morale", "defense"],
	"Monkey": ["attack", "morale", "defense"],
	"Ox": ["defense", "attack", "morale"],
	"Tortoise": ["defense", "attack", "morale"],
	"Oriole": ["defense", "attack", "morale"],
	"Fox": ["morale", "defense", "attack"],
	"Sparrow": ["morale", "defense", "attack"],
	"Dragonfly": ["morale", "defense", "attack"],
	"Centipede": ["morale", "attack", "defense"],
}

const RING_TO_BONUS_TYPE: Dictionary = {
	Enums.Ring.FIRE: "attack",
	Enums.Ring.WATER: "attack",
	Enums.Ring.EARTH: "defense",
	Enums.Ring.AIR: "defense",
	Enums.Ring.VOID: "morale",
}


static func resolve_commander_bonus(
	commander: L5RCharacterData,
	clan_id: String,
) -> Dictionary:
	if commander == null:
		return {"bonus_type": "", "bonus_value": 0}

	var battle_rank: int = commander.skills.get("Battle", 0)
	if battle_rank <= 0:
		return {"bonus_type": "", "bonus_value": 0}

	var highest_ring: Enums.Ring = _get_highest_ring(commander, clan_id)
	var bonus_type: String = RING_TO_BONUS_TYPE.get(highest_ring, "attack")

	return {"bonus_type": bonus_type, "bonus_value": battle_rank}


static func _get_highest_ring(
	commander: L5RCharacterData,
	clan_id: String,
) -> Enums.Ring:
	var rings: Array[Enums.Ring] = [
		Enums.Ring.FIRE, Enums.Ring.WATER,
		Enums.Ring.EARTH, Enums.Ring.AIR, Enums.Ring.VOID,
	]
	var best_value: int = 0
	var tied_rings: Array[Enums.Ring] = []

	for ring: Enums.Ring in rings:
		var val: int = CharacterStats.get_ring_value(commander, ring)
		if val > best_value:
			best_value = val
			tied_rings = [ring]
		elif val == best_value:
			tied_rings.append(ring)

	if tied_rings.size() == 1:
		return tied_rings[0]

	var priority: Array = CLAN_RING_PRIORITY.get(clan_id, ["attack", "defense", "morale"])
	for prio_type: String in priority:
		for ring: Enums.Ring in tied_rings:
			if RING_TO_BONUS_TYPE.get(ring, "") == prio_type:
				return ring
	return tied_rings[0]


# -- Terrain Modifiers (GDD s11.7) -----------------------------------------------

const TERRAIN_MODIFIERS: Dictionary = {
	Enums.BattleTerrainType.PLAINS: {
		"cavalry_flanking_bonus": 2,
	},
	Enums.BattleTerrainType.FOREST: {
		"defender_defense": 2,
		"cavalry_flanking_disabled": true,
		"cavalry_attack_penalty": -2,
		"spearmen_defense_penalty": -1,
	},
	Enums.BattleTerrainType.HILLS: {
		"attacker_attack_penalty": -2,
		"cavalry_attacker_flanking_penalty": -1,
	},
	Enums.BattleTerrainType.MOUNTAIN: {
		"defender_defense": 4,
		"cavalry_flanking_disabled": true,
		"cavalry_attack_penalty": -3,
		"archer_defender_attack_bonus": 1,
	},
	Enums.BattleTerrainType.URBAN: {
		"defender_defense": 3,
		"cavalry_flanking_disabled": true,
		"cavalry_attack_penalty": -3,
		"spearmen_defender_defense_bonus": 1,
	},
	Enums.BattleTerrainType.COASTAL_BEACH: {
		"amphibious_attacker_attack_penalty": -3,
		"amphibious_cavalry_attack_penalty": -2,
		"amphibious_cavalry_flanking_disabled": true,
	},
}


static func get_terrain_modifiers(
	terrain: Enums.BattleTerrainType,
	unit_type: Enums.CompanyUnitType,
	is_defender: bool,
	is_amphibious: bool,
) -> Dictionary:
	var mods: Dictionary = {"attack_mod": 0, "defense_mod": 0, "flanking_disabled": false, "flanking_bonus_mod": 0}
	var t: Dictionary = TERRAIN_MODIFIERS.get(terrain, {})

	if is_defender:
		mods["defense_mod"] += t.get("defender_defense", 0)
	else:
		mods["attack_mod"] += t.get("attacker_attack_penalty", 0)

	var is_cavalry: bool = unit_type == Enums.CompanyUnitType.LIGHT_CAVALRY
	var is_spearmen: bool = unit_type == Enums.CompanyUnitType.ASHIGARU_SPEARMEN
	var is_archer: bool = unit_type == Enums.CompanyUnitType.ASHIGARU_ARCHERS

	if is_cavalry:
		if t.get("cavalry_flanking_disabled", false):
			mods["flanking_disabled"] = true
		mods["attack_mod"] += t.get("cavalry_attack_penalty", 0)
		mods["flanking_bonus_mod"] += t.get("cavalry_flanking_bonus", 0)
		if not is_defender:
			mods["flanking_bonus_mod"] += t.get("cavalry_attacker_flanking_penalty", 0)
		if is_amphibious and not is_defender:
			mods["attack_mod"] += t.get("amphibious_cavalry_attack_penalty", 0)
			if t.get("amphibious_cavalry_flanking_disabled", false):
				mods["flanking_disabled"] = true

	if is_spearmen:
		mods["defense_mod"] += t.get("spearmen_defense_penalty", 0)
		if is_defender:
			mods["defense_mod"] += t.get("spearmen_defender_defense_bonus", 0)

	if is_archer and is_defender:
		mods["attack_mod"] += t.get("archer_defender_attack_bonus", 0)

	if is_amphibious and not is_defender and not is_cavalry:
		mods["attack_mod"] += t.get("amphibious_attacker_attack_penalty", 0)

	return mods


# -- Morale Check Modifiers (GDD s11.7) ------------------------------------------

const MORALE_MOD_HEAVY_LOSS: int = 2
const MORALE_MOD_LOW_HEALTH: int = 1
const MORALE_MOD_CHUI_DEATH: int = 3
const MORALE_MOD_HIGHER_COMMANDER_DEATH: int = 4

const HEALTH_HEAVY_LOSS_THRESHOLD: float = 0.25
const HEALTH_LOW_THRESHOLD: float = 0.50

const COMMANDER_SURVIVAL_TNS: Dictionary = {
	75: 10,
	50: 15,
	25: 20,
	0: 25,
}

const MAX_ROUNDS: int = 200


# -- Battle Company State --------------------------------------------------------

static func make_battle_company(
	company: MilitaryUnitData.CompanyData,
	row: int,
	column: int,
	side: String,
	commander: L5RCharacterData = null,
	commander_bonus: Dictionary = {},
) -> Dictionary:
	return {
		"company": company,
		"company_id": company.company_id,
		"unit_type": company.unit_type,
		"starting_health": company.health,
		"current_health": company.health,
		"current_morale": company.morale,
		"base_attack": company.attack,
		"base_defense": company.defense,
		"base_morale_defense": company.morale_defense,
		"row": row,
		"column": column,
		"side": side,
		"is_routed": false,
		"is_destroyed": false,
		"commander": commander,
		"commander_bonus": commander_bonus,
		"commander_injured": false,
		"commander_dead": false,
		"survival_thresholds_triggered": [],
		"health_damage_this_round": 0,
		"is_archer": company.unit_type == Enums.CompanyUnitType.ASHIGARU_ARCHERS,
		"no_morale": false,
	}


static func is_active(bc: Dictionary) -> bool:
	return not bc["is_routed"] and not bc["is_destroyed"]


# -- Core Battle Entry Point -----------------------------------------------------

static func resolve_battle(
	attacker_states: Array[Dictionary],
	defender_states: Array[Dictionary],
	terrain: Enums.BattleTerrainType,
	dice_engine: DiceEngine,
	is_amphibious: bool = false,
	fortification_bonus: int = 0,
) -> Dictionary:
	_apply_setup_modifiers(attacker_states, terrain, false, is_amphibious, fortification_bonus)
	_apply_setup_modifiers(defender_states, terrain, true, is_amphibious, fortification_bonus)

	var round_log: Array[Dictionary] = []
	var round_num: int = 0
	var commander_deaths: Array[Dictionary] = []

	while round_num < MAX_ROUNDS:
		round_num += 1
		var round_result: Dictionary = _resolve_combat_round(
			attacker_states, defender_states, terrain, dice_engine,
		)
		round_log.append(round_result)
		commander_deaths.append_array(round_result.get("commander_deaths", []))

		if _check_battle_end(attacker_states) or _check_battle_end(defender_states):
			break

	var attacker_defeated: bool = _check_battle_end(attacker_states)
	var defender_defeated: bool = _check_battle_end(defender_states)

	var victor: String = "draw"
	if attacker_defeated and not defender_defeated:
		victor = "defender"
	elif defender_defeated and not attacker_defeated:
		victor = "attacker"
	elif attacker_defeated and defender_defeated:
		victor = "draw"

	return {
		"victor": victor,
		"rounds": round_num,
		"round_log": round_log,
		"attacker_states": attacker_states,
		"defender_states": defender_states,
		"commander_deaths": commander_deaths,
	}


# -- Setup Modifiers -------------------------------------------------------------

static func _apply_setup_modifiers(
	states: Array[Dictionary],
	terrain: Enums.BattleTerrainType,
	is_defender: bool,
	is_amphibious: bool,
	fortification_bonus: int,
) -> void:
	for bc: Dictionary in states:
		var t_mods: Dictionary = get_terrain_modifiers(
			terrain, bc["unit_type"], is_defender, is_amphibious,
		)
		bc["terrain_attack_mod"] = t_mods["attack_mod"]
		bc["terrain_defense_mod"] = t_mods["defense_mod"]
		bc["terrain_flanking_disabled"] = t_mods["flanking_disabled"]
		bc["terrain_flanking_bonus_mod"] = t_mods["flanking_bonus_mod"]
		if is_defender:
			bc["terrain_defense_mod"] += fortification_bonus
		if bc["unit_type"] == Enums.CompanyUnitType.GARRISON and is_defender and fortification_bonus > 0:
			bc["terrain_defense_mod"] += GARRISON_HOME_DEFENSE_BONUS


static func _get_effective_attack(bc: Dictionary) -> int:
	var atk: int = bc["base_attack"] + bc.get("terrain_attack_mod", 0)
	var bonus: Dictionary = bc.get("commander_bonus", {})
	if not bc.get("commander_injured", false) and not bc.get("commander_dead", false):
		if bonus.get("bonus_type", "") == "attack":
			atk += bonus.get("bonus_value", 0)
	return maxi(atk, 0)


static func _get_effective_defense(bc: Dictionary) -> int:
	var def: int = bc["base_defense"] + bc.get("terrain_defense_mod", 0)
	var bonus: Dictionary = bc.get("commander_bonus", {})
	if not bc.get("commander_injured", false) and not bc.get("commander_dead", false):
		if bonus.get("bonus_type", "") == "defense":
			def += bonus.get("bonus_value", 0)
	return maxi(def, 0)


static func _get_effective_morale_defense(bc: Dictionary) -> int:
	var md: int = bc["base_morale_defense"]
	var bonus: Dictionary = bc.get("commander_bonus", {})
	if not bc.get("commander_injured", false) and not bc.get("commander_dead", false):
		if bonus.get("bonus_type", "") == "morale":
			md += bonus.get("bonus_value", 0)
	return maxi(md, 0)


# -- Combat Round ----------------------------------------------------------------

static func _resolve_combat_round(
	attackers: Array[Dictionary],
	defenders: Array[Dictionary],
	terrain: Enums.BattleTerrainType,
	dice_engine: DiceEngine,
) -> Dictionary:
	for bc: Dictionary in attackers:
		bc["health_damage_this_round"] = 0
	for bc: Dictionary in defenders:
		bc["health_damage_this_round"] = 0

	var pending_damage: Dictionary = {}
	var pending_morale_triggers: Dictionary = {}
	var commander_deaths: Array[Dictionary] = []

	var active_atk_r1: Array[Dictionary] = _get_active_row(attackers, 1)
	var active_def_r1: Array[Dictionary] = _get_active_row(defenders, 1)
	var active_atk_r2: Array[Dictionary] = _get_active_row(attackers, 2)
	var active_def_r2: Array[Dictionary] = _get_active_row(defenders, 2)

	var matchups: Array[Dictionary] = _build_matchups(active_atk_r1, active_def_r1)
	var flanks: Array[Dictionary] = _find_flanking_opportunities(
		active_atk_r1, active_def_r1, attackers, defenders, terrain,
	)

	for m: Dictionary in matchups:
		var atk: Dictionary = m["attacker"]
		var dfn: Dictionary = m["defender"]

		var atk_dmg: int = _compute_attack_damage(atk, dfn, dice_engine, false, false)
		var def_dmg: int = _compute_attack_damage(dfn, atk, dice_engine, false, false)

		_add_pending(pending_damage, dfn, atk_dmg)
		_add_pending(pending_damage, atk, def_dmg)

		if atk_dmg > 0:
			_ensure_trigger(pending_morale_triggers, dfn)
		if def_dmg > 0:
			_ensure_trigger(pending_morale_triggers, atk)

	for f: Dictionary in flanks:
		var flanker: Dictionary = f["flanker"]
		var target: Dictionary = f["target"]
		var flank_dmg: int = _compute_attack_damage(flanker, target, dice_engine, true, false)
		_add_pending(pending_damage, target, flank_dmg)
		if flank_dmg > 0:
			_ensure_trigger(pending_morale_triggers, target)
			pending_morale_triggers[target["company_id"]]["flanked"] = true

	_resolve_archer_fire(active_atk_r2, active_def_r1, dice_engine, pending_damage, pending_morale_triggers)
	_resolve_archer_fire(active_def_r2, active_atk_r1, dice_engine, pending_damage, pending_morale_triggers)

	for bc_id: int in pending_damage:
		var bc: Dictionary = _find_bc_by_id(attackers, defenders, bc_id)
		if bc.is_empty():
			continue
		var dmg: int = pending_damage[bc_id]
		var health_before: int = bc["current_health"]
		bc["current_health"] = maxi(bc["current_health"] - dmg, 0)
		bc["health_damage_this_round"] = dmg

		if bc["current_health"] <= 0:
			bc["is_destroyed"] = true

		var survival: Dictionary = _check_commander_survival_thresholds(
			bc, health_before, dice_engine,
		)
		if survival.get("died", false):
			commander_deaths.append(survival)
		if survival.get("injured", false):
			bc["commander_injured"] = true

	for bc_id: int in pending_morale_triggers:
		var bc: Dictionary = _find_bc_by_id(attackers, defenders, bc_id)
		if bc.is_empty() or not is_active(bc):
			continue
		if bc.get("no_morale", false):
			continue
		var triggers: Dictionary = pending_morale_triggers[bc_id]
		_resolve_morale_check(bc, triggers, dice_engine, commander_deaths)

	_process_rout_contagion(attackers, dice_engine)
	_process_rout_contagion(defenders, dice_engine)

	_promote_reserves(attackers)
	_promote_reserves(defenders)

	return {
		"matchups": matchups.size(),
		"flanks": flanks.size(),
		"commander_deaths": commander_deaths,
	}


static func _get_active_row(states: Array[Dictionary], row: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bc: Dictionary in states:
		if is_active(bc) and bc["row"] == row:
			result.append(bc)
	return result


static func _build_matchups(
	atk_r1: Array[Dictionary],
	def_r1: Array[Dictionary],
) -> Array[Dictionary]:
	var matchups: Array[Dictionary] = []
	var matched_def_ids: Array[int] = []

	for atk: Dictionary in atk_r1:
		var best: Dictionary = {}
		for dfn: Dictionary in def_r1:
			if dfn["company_id"] in matched_def_ids:
				continue
			if dfn["column"] == atk["column"]:
				best = dfn
				break
		if not best.is_empty():
			matchups.append({"attacker": atk, "defender": best})
			matched_def_ids.append(best["company_id"])

	return matchups


static func _find_flanking_opportunities(
	atk_r1: Array[Dictionary],
	def_r1: Array[Dictionary],
	all_attackers: Array[Dictionary],
	all_defenders: Array[Dictionary],
	terrain: Enums.BattleTerrainType,
) -> Array[Dictionary]:
	var flanks: Array[Dictionary] = []
	var engaged_atk_ids: Array[int] = []
	for atk: Dictionary in atk_r1:
		for dfn: Dictionary in def_r1:
			if dfn["column"] == atk["column"]:
				engaged_atk_ids.append(atk["company_id"])
				break

	for atk: Dictionary in atk_r1:
		if atk["company_id"] in engaged_atk_ids:
			continue
		if atk.get("terrain_flanking_disabled", false):
			continue
		var target: Dictionary = _find_adjacent_flank_target(atk, def_r1)
		if not target.is_empty():
			flanks.append({"flanker": atk, "target": target})

	for dfn: Dictionary in def_r1:
		var engaged: bool = false
		for atk: Dictionary in atk_r1:
			if atk["column"] == dfn["column"]:
				engaged = true
				break
		if engaged:
			continue
		if dfn.get("terrain_flanking_disabled", false):
			continue
		var target: Dictionary = _find_adjacent_flank_target(dfn, atk_r1)
		if not target.is_empty():
			flanks.append({"flanker": dfn, "target": target})

	return flanks


static func _find_adjacent_flank_target(
	flanker: Dictionary,
	enemy_r1: Array[Dictionary],
) -> Dictionary:
	var col: int = flanker["column"]
	for dfn: Dictionary in enemy_r1:
		if is_active(dfn) and absi(dfn["column"] - col) == 1:
			return dfn
	for dfn: Dictionary in enemy_r1:
		if is_active(dfn) and absi(dfn["column"] - col) == 2:
			return dfn
	return {}


# -- Attack Damage ---------------------------------------------------------------

static func _compute_attack_damage(
	attacker: Dictionary,
	defender: Dictionary,
	dice_engine: DiceEngine,
	is_flanking: bool,
	is_archer_fire: bool,
) -> int:
	var atk_val: int = _get_effective_attack(attacker)
	var def_val: int = _get_effective_defense(defender)

	if is_archer_fire:
		if attacker.get("is_archer", false) and not is_flanking:
			var roll: int = dice_engine.rand_int_range(1, 5)
			return maxi(roll + atk_val - def_val, 0)
		return 0

	var roll: int = dice_engine.rand_int_range(1, 10)
	var bonus: int = 0

	if is_flanking:
		var is_cavalry: bool = attacker["unit_type"] == Enums.CompanyUnitType.LIGHT_CAVALRY
		if is_cavalry:
			bonus += LIGHT_CAVALRY_FLANK_BONUS
		else:
			bonus += BASE_FLANK_BONUS
		bonus += attacker.get("terrain_flanking_bonus_mod", 0)

	if attacker["unit_type"] == Enums.CompanyUnitType.ASHIGARU_SPEARMEN:
		if defender["unit_type"] == Enums.CompanyUnitType.LIGHT_CAVALRY:
			bonus += ASHIGARU_SPEARMEN_VS_CAVALRY_BONUS

	if attacker["unit_type"] == Enums.CompanyUnitType.ASHIGARU_ARCHERS:
		bonus -= 3

	return maxi(roll + atk_val + bonus - def_val, 0)


static func _resolve_archer_fire(
	archer_row: Array[Dictionary],
	enemy_r1: Array[Dictionary],
	dice_engine: DiceEngine,
	pending_damage: Dictionary,
	pending_morale_triggers: Dictionary,
) -> void:
	for archer: Dictionary in archer_row:
		if not archer.get("is_archer", false):
			continue
		if not is_active(archer):
			continue
		var target: Dictionary = _find_archer_target(archer, enemy_r1)
		if target.is_empty():
			continue
		var dmg: int = _compute_attack_damage(archer, target, dice_engine, false, true)
		if dmg > 0:
			_add_pending(pending_damage, target, dmg)
			_ensure_trigger(pending_morale_triggers, target)


static func _find_archer_target(
	archer: Dictionary,
	enemy_r1: Array[Dictionary],
) -> Dictionary:
	for e: Dictionary in enemy_r1:
		if is_active(e) and e["column"] == archer["column"]:
			return e
	return {}


# -- Morale ----------------------------------------------------------------------

static func _resolve_morale_check(
	bc: Dictionary,
	triggers: Dictionary,
	dice_engine: DiceEngine,
	commander_deaths: Array[Dictionary],
) -> void:
	if bc.get("no_morale", false):
		return

	var modifier: int = 0

	var health_pct: float = float(bc["current_health"]) / float(bc["starting_health"])
	var dmg_pct: float = float(bc["health_damage_this_round"]) / float(bc["starting_health"])

	if dmg_pct > HEALTH_HEAVY_LOSS_THRESHOLD:
		modifier += MORALE_MOD_HEAVY_LOSS
	if health_pct < HEALTH_LOW_THRESHOLD:
		modifier += MORALE_MOD_LOW_HEALTH

	for cd: Dictionary in commander_deaths:
		if cd.get("company_id", -1) == bc["company_id"]:
			modifier += MORALE_MOD_CHUI_DEATH
		if cd.get("is_higher_commander", false) and cd.get("side", "") == bc["side"]:
			modifier += MORALE_MOD_HIGHER_COMMANDER_DEATH

	if triggers.get("flanked", false):
		pass

	var roll: int = dice_engine.rand_int_range(1, 10)
	var md: int = _get_effective_morale_defense(bc)
	var morale_dmg: int = maxi(roll + modifier - md, 0)

	bc["current_morale"] = maxi(bc["current_morale"] - morale_dmg, 0)

	if bc["current_morale"] <= 0:
		bc["is_routed"] = true


static func _process_rout_contagion(
	side: Array[Dictionary],
	dice_engine: DiceEngine,
) -> void:
	var newly_routed: Array[Dictionary] = []
	for bc: Dictionary in side:
		if bc["is_routed"] and bc.get("_rout_contagion_processed", false) == false:
			newly_routed.append(bc)
			bc["_rout_contagion_processed"] = true

	for routed: Dictionary in newly_routed:
		for bc: Dictionary in side:
			if not is_active(bc):
				continue
			if bc.get("no_morale", false):
				continue
			if absi(bc["column"] - routed["column"]) <= 1 and bc["row"] == routed["row"]:
				var roll: int = dice_engine.rand_int_range(1, 10)
				var md: int = _get_effective_morale_defense(bc)
				var morale_dmg: int = maxi(roll - md, 0)
				bc["current_morale"] = maxi(bc["current_morale"] - morale_dmg, 0)
				if bc["current_morale"] <= 0:
					bc["is_routed"] = true


# -- Commander Survival ----------------------------------------------------------

static func _check_commander_survival_thresholds(
	bc: Dictionary,
	health_before: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var commander: L5RCharacterData = bc.get("commander")
	if commander == null:
		return {}
	if bc.get("commander_dead", false):
		return {}

	var starting: int = bc["starting_health"]
	if starting <= 0:
		return {}

	var thresholds: Array[int] = [75, 50, 25, 0]
	var triggered: Array = bc.get("survival_thresholds_triggered", [])

	for threshold: int in thresholds:
		if threshold in triggered:
			continue
		var threshold_health: int = ceili(float(starting) * float(threshold) / 100.0)
		if health_before > threshold_health and bc["current_health"] <= threshold_health:
			triggered.append(threshold)
			bc["survival_thresholds_triggered"] = triggered

			var result: Dictionary = _roll_commander_survival(
				commander, COMMANDER_SURVIVAL_TNS[threshold], dice_engine,
			)
			if result["outcome"] == "dead":
				bc["commander_dead"] = true
				return {
					"company_id": bc["company_id"],
					"commander_id": commander.character_id,
					"side": bc["side"],
					"died": true,
					"injured": false,
					"threshold": threshold,
					"is_higher_commander": false,
				}
			elif result["outcome"] == "injured":
				return {
					"company_id": bc["company_id"],
					"commander_id": commander.character_id,
					"side": bc["side"],
					"died": false,
					"injured": true,
					"threshold": threshold,
					"is_higher_commander": false,
				}
			else:
				return {}

	return {}


static func _roll_commander_survival(
	commander: L5RCharacterData,
	tn: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var earth: int = CharacterStats.get_ring_value(commander, Enums.Ring.EARTH)
	var battle: int = commander.skills.get("Battle", 0)
	var rolled: int = earth + battle
	var kept: int = earth

	if rolled <= 0 or kept <= 0:
		return {"outcome": "dead", "roll_total": 0, "tn": tn}

	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, true, false)
	var total: int = result.total + battle

	if total >= tn:
		return {"outcome": "survived", "roll_total": total, "tn": tn}
	elif tn - total <= 3:
		return {"outcome": "injured", "roll_total": total, "tn": tn}
	else:
		return {"outcome": "dead", "roll_total": total, "tn": tn}


# -- Reserve Promotion -----------------------------------------------------------

static func _promote_reserves(states: Array[Dictionary]) -> void:
	for bc: Dictionary in states:
		if bc["row"] != 2:
			continue
		if not is_active(bc):
			continue
		if bc.get("is_archer", false):
			continue
		var col: int = bc["column"]
		var r1_exists: bool = false
		for other: Dictionary in states:
			if other["row"] == 1 and other["column"] == col and is_active(other):
				r1_exists = true
				break
		if not r1_exists:
			bc["row"] = 1


# -- Battle End ------------------------------------------------------------------

static func _check_battle_end(states: Array[Dictionary]) -> bool:
	for bc: Dictionary in states:
		if is_active(bc):
			return false
	return true


# -- Rout Resolution (GDD s11.7) -------------------------------------------------

static func resolve_rout(
	routed_states: Array[Dictionary],
	victor_has_cavalry: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	var total_remaining: int = 0
	var total_starting: int = 0
	for bc: Dictionary in routed_states:
		total_starting += bc["starting_health"]
		if not bc["is_destroyed"]:
			total_remaining += maxi(bc["current_health"], 0)

	var roll: int = dice_engine.rand_int_range(1, 10)
	var pursuit_pct: float
	if victor_has_cavalry:
		pursuit_pct = (float(roll) + 25.0) / 100.0
	else:
		pursuit_pct = (float(roll) + 5.0) / 100.0

	var pursuit_casualties: int = ceili(float(total_remaining) * pursuit_pct)
	var health_after_pursuit: int = maxi(total_remaining - pursuit_casualties, 0)

	var dissolved: bool = health_after_pursuit <= ceili(float(total_starting) * 0.20)

	return {
		"total_starting_health": total_starting,
		"total_remaining_before_pursuit": total_remaining,
		"pursuit_casualties": pursuit_casualties,
		"health_after_pursuit": health_after_pursuit,
		"dissolved": dissolved,
	}


# -- Post-Battle Recovery (GDD s11.7, victor only) --------------------------------

static func compute_post_battle_recovery(
	victor_states: Array[Dictionary],
) -> Dictionary:
	var total_lost: int = 0
	for bc: Dictionary in victor_states:
		var lost: int = bc["starting_health"] - maxi(bc["current_health"], 0)
		total_lost += lost

	var recovered: int = ceili(float(total_lost) * 0.10)
	var returned_pu: int = ceili(float(total_lost) * 0.10)
	var dead: int = total_lost - recovered - returned_pu

	return {
		"total_health_lost": total_lost,
		"recovered_to_companies": recovered,
		"returned_as_pu": returned_pu,
		"permanently_dead": dead,
	}


# -- Helpers ---------------------------------------------------------------------

static func _add_pending(pending: Dictionary, bc: Dictionary, dmg: int) -> void:
	var cid: int = bc["company_id"]
	pending[cid] = pending.get(cid, 0) + dmg


static func _ensure_trigger(triggers: Dictionary, bc: Dictionary) -> void:
	var cid: int = bc["company_id"]
	if not triggers.has(cid):
		triggers[cid] = {"flanked": false}


static func _find_bc_by_id(
	attackers: Array[Dictionary],
	defenders: Array[Dictionary],
	company_id: int,
) -> Dictionary:
	for bc: Dictionary in attackers:
		if bc["company_id"] == company_id:
			return bc
	for bc: Dictionary in defenders:
		if bc["company_id"] == company_id:
			return bc
	return {}


static func create_company(
	company_id: int,
	unit_type: Enums.CompanyUnitType,
	commander_id: int = -1,
	source_province_id: int = -1,
) -> MilitaryUnitData.CompanyData:
	var c: MilitaryUnitData.CompanyData = MilitaryUnitData.CompanyData.new()
	c.company_id = company_id
	c.unit_type = unit_type
	c.commander_id = commander_id
	c.source_province_id = source_province_id
	var stats: Dictionary = UNIT_STATS.get(unit_type, {})
	c.health = stats.get("health", 153)
	c.attack = stats.get("attack", 0)
	c.defense = stats.get("defense", 0)
	c.morale = stats.get("morale", 10)
	c.morale_defense = stats.get("morale_defense", 0)
	return c
