class_name NavalCombatSystem
## Resolves ship-to-ship naval battles per GDD s11.9.
## Ships are treated as Companies following the same row/column grid as
## ArmyCombatSystem, but with naval-specific rules: no flanking, weather
## replaces terrain, Kobune ranged from reserve row, Koutetsukan ram,
## Atakebune adjacent defense bonus, boarding first-round penalty.


const MAX_ROUNDS: int = 200

const MORALE_MOD_HEAVY_LOSS: int = 2
const MORALE_MOD_LOW_HEALTH: int = 1
const MORALE_MOD_CAPTAIN_DEATH: int = 3

const HEALTH_HEAVY_LOSS_THRESHOLD: float = 0.25
const HEALTH_LOW_THRESHOLD: float = 0.50

const COMMANDER_SURVIVAL_TNS: Dictionary = {
	75: 10,
	50: 15,
	25: 20,
	0: 25,
}


# -- Naval Battle Company State --------------------------------------------------

static func make_naval_company(
	ship: ShipData,
	row: int,
	column: int,
	side: String,
	weather: int = Enums.NavalWeather.CLEAR,
	is_mantis_operated: bool = false,
	captain: L5RCharacterData = null,
	captain_bonus: Dictionary = {},
) -> Dictionary:
	var eff_attack: int = NavalSystem.get_effective_attack(ship, weather, is_mantis_operated)
	var eff_defense: int = NavalSystem.get_effective_defense(ship, weather)

	var is_kobune_ranged: bool = (ship.ship_class == Enums.ShipClass.KOBUNE and row == 2)

	return {
		"ship": ship,
		"company_id": ship.ship_id,
		"ship_class": ship.ship_class,
		"owning_clan": ship.owning_clan,
		"starting_health": ship.max_health,
		"current_health": ship.health,
		"starting_morale": ship.morale,
		"current_morale": ship.morale,
		"base_attack": eff_attack,
		"base_defense": eff_defense,
		"base_morale_defense": ship.morale_defense,
		"row": row,
		"column": column,
		"side": side,
		"is_routed": false,
		"is_destroyed": false,
		"is_captured": false,
		"is_civilian": NavalSystem.is_civilian_vessel(ship.ship_class),
		"auto_surrenders": NavalSystem.civilian_auto_surrenders(ship.ship_class),
		"auto_flees": NavalSystem.civilian_auto_flees(ship.ship_class),
		"is_kobune_ranged": is_kobune_ranged,
		"weather": weather,
		"captain": captain,
		"captain_bonus": captain_bonus,
		"captain_injured": false,
		"captain_dead": false,
		"survival_thresholds_triggered": [],
		"health_damage_this_round": 0,
		"round_number": 0,
		"ram_used": false,
		"escape_attempted": false,
		"is_escaped": false,
		"is_mantis_operated": is_mantis_operated,
	}


static func is_active(bc: Dictionary) -> bool:
	return (
		not bc["is_routed"]
		and not bc["is_destroyed"]
		and not bc.get("is_captured", false)
		and not bc.get("auto_flees", false)
		and not bc.get("is_escaped", false)
	)


# -- Pre-Battle: Civilian Processing ---------------------------------------------

static func process_civilians(
	attacker_states: Array,
	defender_states: Array,
) -> Dictionary:
	var fled: Array = []
	var surrendered: Array = []

	for bc: Dictionary in attacker_states:
		if bc.get("auto_flees", false):
			fled.append(bc["company_id"])
		elif bc.get("auto_surrenders", false):
			if _any_active_on_side(defender_states):
				bc["is_captured"] = true
				surrendered.append(bc["company_id"])

	for bc: Dictionary in defender_states:
		if bc.get("auto_flees", false):
			fled.append(bc["company_id"])
		elif bc.get("auto_surrenders", false):
			if _any_active_on_side(attacker_states):
				bc["is_captured"] = true
				surrendered.append(bc["company_id"])

	return {"fled": fled, "surrendered": surrendered}


static func _any_active_on_side(states: Array) -> bool:
	for bc: Dictionary in states:
		if is_active(bc) and not bc.get("is_civilian", false):
			return true
	return false


# -- Core Battle Entry Point -----------------------------------------------------

static func resolve_naval_battle(
	attacker_states: Array,
	defender_states: Array,
	weather: int,
	dice_engine: DiceEngine,
	is_river: bool = false,
	is_downstream_attacker: bool = false,
) -> Dictionary:
	var civilian_result: Dictionary = process_civilians(attacker_states, defender_states)

	if is_river:
		_apply_river_modifiers(attacker_states, defender_states, is_downstream_attacker)

	var round_log: Array = []
	var round_num: int = 0
	var captain_deaths: Array = []

	while round_num < MAX_ROUNDS:
		round_num += 1
		var round_result: Dictionary = _resolve_naval_round(
			attacker_states, defender_states, weather, dice_engine, round_num,
		)
		round_log.append(round_result)
		captain_deaths.append_array(round_result.get("captain_deaths", []))

		if _check_battle_end(attacker_states) or _check_battle_end(defender_states):
			break

	var attacker_defeated: bool = _check_battle_end(attacker_states)
	var defender_defeated: bool = _check_battle_end(defender_states)

	var victor: String = "draw"
	if attacker_defeated and not defender_defeated:
		victor = "defender"
	elif defender_defeated and not attacker_defeated:
		victor = "attacker"

	var captured_ships: Array = _collect_captured_ships(attacker_states, defender_states)
	var escaped_ships: Array = _collect_escaped_ships(attacker_states, defender_states)

	return {
		"victor": victor,
		"rounds": round_num,
		"round_log": round_log,
		"attacker_states": attacker_states,
		"defender_states": defender_states,
		"captain_deaths": captain_deaths,
		"civilian_result": civilian_result,
		"captured_ships": captured_ships,
		"escaped_ships": escaped_ships,
		"weather": weather,
	}


# -- River Modifiers -------------------------------------------------------------

static func _apply_river_modifiers(
	attacker_states: Array,
	defender_states: Array,
	is_downstream_attacker: bool,
) -> void:
	var atk_mod: int = NavalSystem.get_river_current_modifier(is_downstream_attacker)
	var def_mod: int = NavalSystem.get_river_current_modifier(not is_downstream_attacker)
	for bc: Dictionary in attacker_states:
		bc["base_attack"] = maxi(bc["base_attack"] + atk_mod, 0)
	for bc: Dictionary in defender_states:
		bc["base_attack"] = maxi(bc["base_attack"] + def_mod, 0)


# -- Atakebune Adjacent Defense --------------------------------------------------

static func _apply_atakebune_defense(side: Array) -> void:
	for bc: Dictionary in side:
		if not is_active(bc):
			continue
		if bc["ship_class"] == Enums.ShipClass.ATAKEBUNE:
			for ally: Dictionary in side:
				if ally["company_id"] == bc["company_id"]:
					continue
				if not is_active(ally):
					continue
				if absi(ally["column"] - bc["column"]) <= 1 and ally["row"] == bc["row"]:
					ally["atakebune_def_bonus"] = NavalSystem.ATAKEBUNE_ADJACENT_DEFENSE_BONUS


# -- Tortoise Escape Attempt (s11.9) --------------------------------------------
# Tortoise ships attempt escape before the round's matchups (consuming their
# Company action). NPC captains always flee — the design philosophy is
# flee-before-fight. Escape is contested once per engagement; escape_attempted
# blocks retries on failure.

static func _tortoise_captain_nav_int(bc: Dictionary) -> Dictionary:
	var cap: L5RCharacterData = bc.get("captain") as L5RCharacterData
	if cap == null:
		return {"navigation": 0, "intelligence": 2}
	return {
		"navigation": cap.skills.get("Navigation", 0),
		"intelligence": cap.intelligence,
	}


static func _best_enemy_battle_int(enemy_side: Array) -> Dictionary:
	var best_battle: int = 0
	var best_int: int = 2
	for bc: Dictionary in enemy_side:
		if not is_active(bc):
			continue
		var cap: L5RCharacterData = bc.get("captain") as L5RCharacterData
		if cap == null:
			continue
		var bat: int = cap.skills.get("Battle", 0)
		var intel: int = cap.intelligence
		if bat + intel > best_battle + best_int:
			best_battle = bat
			best_int = intel
	return {"battle": best_battle, "intelligence": best_int}


static func _process_tortoise_escapes(
	own_side: Array,
	enemy_side: Array,
	dice_engine: DiceEngine,
	weather: int,
) -> Array:
	var results: Array = []
	var enemy_stats: Dictionary = _best_enemy_battle_int(enemy_side)
	for bc: Dictionary in own_side:
		if bc["ship_class"] != Enums.ShipClass.TORTOISE_OCEANGOING:
			continue
		if not is_active(bc):
			continue
		if bc.get("escape_attempted", false):
			continue
		bc["escape_attempted"] = true
		var nav_int: Dictionary = _tortoise_captain_nav_int(bc)
		var attempt: Dictionary = NavalSystem.resolve_escape_attempt(
			dice_engine,
			nav_int["navigation"],
			nav_int["intelligence"],
			enemy_stats["battle"],
			enemy_stats["intelligence"],
			weather,
		)
		if attempt["escaped"]:
			bc["is_escaped"] = true
		results.append({
			"company_id": bc["company_id"],
			"ship_id": bc.get("ship", {}).get("ship_id", bc["company_id"]),
			"escaped": attempt["escaped"],
			"escape_total": attempt["escape_total"],
			"pursue_total": attempt["pursue_total"],
			"weather_bonus": attempt["weather_bonus"],
		})
	return results


# -- Combat Round ----------------------------------------------------------------

static func _resolve_naval_round(
	attackers: Array,
	defenders: Array,
	weather: int,
	dice_engine: DiceEngine,
	round_num: int,
) -> Dictionary:
	for bc: Dictionary in attackers:
		bc["health_damage_this_round"] = 0
		bc["round_number"] = round_num
		bc["atakebune_def_bonus"] = 0
	for bc: Dictionary in defenders:
		bc["health_damage_this_round"] = 0
		bc["round_number"] = round_num
		bc["atakebune_def_bonus"] = 0

	# Tortoise escape attempts happen before matchups (consumes Company action).
	var escape_results: Array = []
	escape_results.append_array(_process_tortoise_escapes(attackers, defenders, dice_engine, weather))
	escape_results.append_array(_process_tortoise_escapes(defenders, attackers, dice_engine, weather))

	_apply_atakebune_defense(attackers)
	_apply_atakebune_defense(defenders)

	var pending_damage: Dictionary = {}
	var pending_morale_triggers: Dictionary = {}
	var captain_deaths: Array = []

	var active_atk_r1: Array = _get_active_row(attackers, 1)
	var active_def_r1: Array = _get_active_row(defenders, 1)
	var active_atk_r2: Array = _get_active_row(attackers, 2)
	var active_def_r2: Array = _get_active_row(defenders, 2)

	var matchups: Array = _build_matchups(active_atk_r1, active_def_r1)

	for m: Dictionary in matchups:
		var atk: Dictionary = m["attacker"]
		var dfn: Dictionary = m["defender"]

		if not _can_engage(atk, dfn):
			continue

		var is_first: bool = (round_num == 1)
		var atk_dmg: int = _compute_naval_damage(atk, dfn, dice_engine, is_first)
		var def_dmg: int = _compute_naval_damage(dfn, atk, dice_engine, is_first)

		_add_pending(pending_damage, dfn, atk_dmg)
		_add_pending(pending_damage, atk, def_dmg)

		if atk_dmg > 0:
			_ensure_trigger(pending_morale_triggers, dfn)
		if def_dmg > 0:
			_ensure_trigger(pending_morale_triggers, atk)

	# Kobune ranged support from reserve row
	_resolve_kobune_ranged_fire(active_atk_r2, active_def_r1, weather, dice_engine, pending_damage, pending_morale_triggers)
	_resolve_kobune_ranged_fire(active_def_r2, active_atk_r1, weather, dice_engine, pending_damage, pending_morale_triggers)

	# Apply pending damage
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

		var survival: Dictionary = _check_captain_survival(bc, health_before, dice_engine)
		if survival.get("died", false):
			captain_deaths.append(survival)
		if survival.get("injured", false):
			bc["captain_injured"] = true

	# Morale checks for damaged ships
	for bc_id: int in pending_morale_triggers:
		var bc: Dictionary = _find_bc_by_id(attackers, defenders, bc_id)
		if bc.is_empty() or not is_active(bc):
			continue
		var triggers: Dictionary = pending_morale_triggers[bc_id]
		_resolve_morale_check(bc, triggers, dice_engine, captain_deaths)

	# Civilian surrender on morale 0
	for bc: Dictionary in attackers:
		if bc.get("auto_surrenders", false) and bc["current_morale"] <= 0 and not bc.get("is_captured", false):
			bc["is_captured"] = true
	for bc: Dictionary in defenders:
		if bc.get("auto_surrenders", false) and bc["current_morale"] <= 0 and not bc.get("is_captured", false):
			bc["is_captured"] = true

	_process_rout_contagion(attackers, dice_engine)
	_process_rout_contagion(defenders, dice_engine)
	_promote_reserves(attackers)
	_promote_reserves(defenders)

	return {
		"matchups": matchups.size(),
		"captain_deaths": captain_deaths,
		"escape_results": escape_results,
	}


# -- Engagement Rules -----------------------------------------------------------

static func _can_engage(attacker: Dictionary, defender: Dictionary) -> bool:
	if defender["ship_class"] == Enums.ShipClass.KOUTETSUKAN:
		return false
	if attacker["ship_class"] == Enums.ShipClass.KOUTETSUKAN:
		return false
	return true


# -- Naval Damage Computation ---------------------------------------------------

static func _compute_naval_damage(
	attacker: Dictionary,
	defender: Dictionary,
	dice_engine: DiceEngine,
	is_first_round: bool,
) -> int:
	var atk_val: int = _get_eff_attack(attacker)
	var def_val: int = _get_eff_defense(defender)

	var roll: int = dice_engine.rand_int_range(1, 10)
	var bonus: int = 0

	if is_first_round:
		bonus += NavalSystem.get_boarding_attack_modifier(true)
		if attacker["ship_class"] == Enums.ShipClass.KOBUNE:
			bonus += NavalSystem.KOBUNE_FIRST_ROUND_ATTACK_BONUS

	return maxi(roll + atk_val + bonus - def_val, 0)


static func _get_eff_attack(bc: Dictionary) -> int:
	var atk: int = bc["base_attack"]
	var bonus: Dictionary = bc.get("captain_bonus", {})
	if not bc.get("captain_injured", false) and not bc.get("captain_dead", false):
		if bonus.get("bonus_type", "") == "attack":
			atk += bonus.get("bonus_value", 0)
	return maxi(atk, 0)


static func _get_eff_defense(bc: Dictionary) -> int:
	var def: int = bc["base_defense"]
	def += bc.get("atakebune_def_bonus", 0)
	var bonus: Dictionary = bc.get("captain_bonus", {})
	if not bc.get("captain_injured", false) and not bc.get("captain_dead", false):
		if bonus.get("bonus_type", "") == "defense":
			def += bonus.get("bonus_value", 0)
	return maxi(def, 0)


# -- Koutetsukan Ram Attack (once per battle) -----------------------------------

static func resolve_ram_in_battle(
	ram_ship: Dictionary,
	target: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	if ram_ship["ship_class"] != Enums.ShipClass.KOUTETSUKAN:
		return {"success": false, "reason": "not_koutetsukan"}
	if ram_ship.get("ram_used", false):
		return {"success": false, "reason": "already_used"}

	ram_ship["ram_used"] = true

	var atk_val: int = _get_eff_attack(ram_ship) + NavalSystem.RAM_ATTACK_BONUS
	var def_val: int = _get_eff_defense(target)
	var damage: int = maxi(atk_val - def_val, 0)
	var self_damage: int = NavalSystem.RAM_SELF_DAMAGE

	target["current_health"] = maxi(target["current_health"] - damage, 0)
	if target["current_health"] <= 0:
		target["is_destroyed"] = true

	ram_ship["current_health"] = maxi(ram_ship["current_health"] - self_damage, 0)
	if ram_ship["current_health"] <= 0:
		ram_ship["is_destroyed"] = true

	return {
		"success": true,
		"damage_dealt": damage,
		"self_damage": self_damage,
	}


# -- Kobune Ranged Fire (Reserve Row) -------------------------------------------

static func _resolve_kobune_ranged_fire(
	reserve_row: Array,
	enemy_r1: Array,
	weather: int,
	dice_engine: DiceEngine,
	pending_damage: Dictionary,
	pending_morale_triggers: Dictionary,
) -> void:
	for bc: Dictionary in reserve_row:
		if not is_active(bc):
			continue
		if not bc.get("is_kobune_ranged", false):
			continue
		var target: Dictionary = _find_target_in_column(bc, enemy_r1)
		if target.is_empty():
			continue
		var dmg: int = NavalSystem.resolve_kobune_ranged(dice_engine, weather, bc["base_attack"])
		if dmg > 0:
			var def_val: int = _get_eff_defense(target)
			var net_dmg: int = maxi(dmg - def_val, 0)
			if net_dmg > 0:
				_add_pending(pending_damage, target, net_dmg)
				_ensure_trigger(pending_morale_triggers, target)


static func _find_target_in_column(
	bc: Dictionary,
	enemy_r1: Array,
) -> Dictionary:
	for e: Dictionary in enemy_r1:
		if is_active(e) and e["column"] == bc["column"]:
			return e
	return {}


# -- Morale ----------------------------------------------------------------------

static func _resolve_morale_check(
	bc: Dictionary,
	_triggers: Dictionary,
	dice_engine: DiceEngine,
	captain_deaths: Array,
) -> void:
	var modifier: int = 0

	var health_pct: float = float(bc["current_health"]) / float(bc["starting_health"])
	var dmg_pct: float = float(bc["health_damage_this_round"]) / float(bc["starting_health"])

	if dmg_pct > HEALTH_HEAVY_LOSS_THRESHOLD:
		modifier += MORALE_MOD_HEAVY_LOSS
	if health_pct < HEALTH_LOW_THRESHOLD:
		modifier += MORALE_MOD_LOW_HEALTH

	for cd: Dictionary in captain_deaths:
		if cd.get("company_id", -1) == bc["company_id"]:
			modifier += MORALE_MOD_CAPTAIN_DEATH

	var roll: int = dice_engine.rand_int_range(1, 10)
	var md: int = bc["base_morale_defense"]
	var bonus: Dictionary = bc.get("captain_bonus", {})
	if not bc.get("captain_injured", false) and not bc.get("captain_dead", false):
		if bonus.get("bonus_type", "") == "morale":
			md += bonus.get("bonus_value", 0)
	md = maxi(md, 0)

	var morale_dmg: int = maxi(roll + modifier - md, 0)
	bc["current_morale"] = maxi(bc["current_morale"] - morale_dmg, 0)

	if bc["current_morale"] <= 0:
		bc["is_routed"] = true


static func _process_rout_contagion(
	side: Array,
	dice_engine: DiceEngine,
) -> void:
	var had_new_routs: bool = true
	while had_new_routs:
		had_new_routs = false
		var newly_routed: Array = []
		for bc: Dictionary in side:
			if bc["is_routed"] and not bc.get("_rout_contagion_processed", false):
				newly_routed.append(bc)
				bc["_rout_contagion_processed"] = true

		for routed: Dictionary in newly_routed:
			for bc: Dictionary in side:
				if not is_active(bc):
					continue
				if absi(bc["column"] - routed["column"]) <= 1 and bc["row"] == routed["row"]:
					var roll: int = dice_engine.rand_int_range(1, 10)
					var md: int = bc["base_morale_defense"]
					var morale_dmg: int = maxi(roll - md, 0)
					bc["current_morale"] = maxi(bc["current_morale"] - morale_dmg, 0)
					if bc["current_morale"] <= 0:
						bc["is_routed"] = true
						had_new_routs = true


# -- Captain Survival (mirrors commander survival from s11.7) --------------------

static func _check_captain_survival(
	bc: Dictionary,
	health_before: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var captain: L5RCharacterData = bc.get("captain")
	if captain == null:
		return {}
	if bc.get("captain_dead", false):
		return {}

	var starting: int = bc["starting_health"]
	if starting <= 0:
		return {}

	var thresholds: Array = [75, 50, 25, 0]
	var triggered: Array = bc.get("survival_thresholds_triggered", [])

	for threshold: int in thresholds:
		if threshold in triggered:
			continue
		var threshold_health: int = ceili(float(starting) * float(threshold) / 100.0)
		if health_before > threshold_health and bc["current_health"] <= threshold_health:
			triggered.append(threshold)
			bc["survival_thresholds_triggered"] = triggered

			var result: Dictionary = _roll_captain_survival(
				captain, COMMANDER_SURVIVAL_TNS[threshold], dice_engine,
			)
			if result["outcome"] == "dead":
				bc["captain_dead"] = true
				return {
					"company_id": bc["company_id"],
					"captain_id": captain.character_id,
					"side": bc["side"],
					"died": true,
					"injured": false,
					"threshold": threshold,
				}
			elif result["outcome"] == "injured":
				return {
					"company_id": bc["company_id"],
					"captain_id": captain.character_id,
					"side": bc["side"],
					"died": false,
					"injured": true,
					"threshold": threshold,
				}
			else:
				return {}

	return {}


static func _roll_captain_survival(
	captain: L5RCharacterData,
	tn: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var earth: int = CharacterStats.get_ring_value(captain, Enums.Ring.EARTH)
	var battle: int = captain.skills.get("Battle", 0)
	var rolled: int = earth + battle
	var kept: int = earth

	if rolled <= 0 or kept <= 0:
		return {"outcome": "dead", "roll_total": 0, "tn": tn}

	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, true, false)
	var total: int = result.total

	if total >= tn:
		return {"outcome": "survived", "roll_total": total, "tn": tn}
	elif tn - total <= 3:
		return {"outcome": "injured", "roll_total": total, "tn": tn}
	else:
		return {"outcome": "dead", "roll_total": total, "tn": tn}


# -- Reserve Promotion -----------------------------------------------------------

static func _promote_reserves(states: Array) -> void:
	for bc: Dictionary in states:
		if bc["row"] != 2:
			continue
		if not is_active(bc):
			continue
		if bc.get("is_kobune_ranged", false):
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

static func _check_battle_end(states: Array) -> bool:
	for bc: Dictionary in states:
		if is_active(bc):
			return false
	return true


# -- Captured Ship Collection ---------------------------------------------------

static func _collect_captured_ships(
	attackers: Array,
	defenders: Array,
) -> Array:
	var captured: Array = []
	for bc: Dictionary in attackers:
		if bc.get("is_captured", false):
			captured.append({
				"ship_id": bc["company_id"],
				"ship_class": bc["ship_class"],
				"captured_by": "defender",
				"prize_value": NavalSystem.compute_capture_prize_value(bc["ship_class"]),
			})
	for bc: Dictionary in defenders:
		if bc.get("is_captured", false):
			captured.append({
				"ship_id": bc["company_id"],
				"ship_class": bc["ship_class"],
				"captured_by": "attacker",
				"prize_value": NavalSystem.compute_capture_prize_value(bc["ship_class"]),
			})
	# Ships reduced to 0 health via boarding are also captured
	for bc: Dictionary in attackers:
		if bc["is_destroyed"] and bc["ship_class"] != Enums.ShipClass.KOUTETSUKAN:
			if not bc.get("is_captured", false):
				captured.append({
					"ship_id": bc["company_id"],
					"ship_class": bc["ship_class"],
					"captured_by": "defender",
					"prize_value": NavalSystem.compute_capture_prize_value(bc["ship_class"]),
				})
	for bc: Dictionary in defenders:
		if bc["is_destroyed"] and bc["ship_class"] != Enums.ShipClass.KOUTETSUKAN:
			if not bc.get("is_captured", false):
				captured.append({
					"ship_id": bc["company_id"],
					"ship_class": bc["ship_class"],
					"captured_by": "attacker",
					"prize_value": NavalSystem.compute_capture_prize_value(bc["ship_class"]),
				})
	return captured


# -- Escaped Ship Collection ---------------------------------------------------

static func _collect_escaped_ships(
	attackers: Array,
	defenders: Array,
) -> Array:
	var escaped: Array = []
	for bc: Dictionary in attackers:
		if bc.get("is_escaped", false):
			escaped.append({
				"ship_id": bc["company_id"],
				"ship_class": bc["ship_class"],
				"side": "attacker",
			})
	for bc: Dictionary in defenders:
		if bc.get("is_escaped", false):
			escaped.append({
				"ship_id": bc["company_id"],
				"ship_class": bc["ship_class"],
				"side": "defender",
			})
	return escaped


# -- Rout Resolution (naval — same structure as land) ---------------------------

static func resolve_naval_rout(
	routed_states: Array,
	dice_engine: DiceEngine,
) -> Dictionary:
	var total_remaining: int = 0
	var total_starting: int = 0
	for bc: Dictionary in routed_states:
		total_starting += bc["starting_health"]
		if not bc["is_destroyed"]:
			total_remaining += maxi(bc["current_health"], 0)

	# No cavalry at sea — always use the lower pursuit percentage
	var roll: int = dice_engine.rand_int_range(1, 10)
	var pursuit_pct: float = (float(roll) + 5.0) / 100.0

	var pursuit_casualties: int = ceili(float(total_remaining) * pursuit_pct)
	var health_after: int = maxi(total_remaining - pursuit_casualties, 0)

	var dissolved: bool = health_after <= ceili(float(total_starting) * 0.20)

	return {
		"total_starting_health": total_starting,
		"total_remaining_before_pursuit": total_remaining,
		"pursuit_casualties": pursuit_casualties,
		"health_after_pursuit": health_after,
		"dissolved": dissolved,
	}


# -- Helpers --------------------------------------------------------------------

static func _get_active_row(states: Array, row: int) -> Array:
	var result: Array = []
	for bc: Dictionary in states:
		if is_active(bc) and bc["row"] == row:
			result.append(bc)
	return result


static func _build_matchups(
	atk_r1: Array,
	def_r1: Array,
) -> Array:
	var matchups: Array = []
	var matched_def_ids: Array = []
	for atk: Dictionary in atk_r1:
		for dfn: Dictionary in def_r1:
			if dfn["company_id"] in matched_def_ids:
				continue
			if dfn["column"] == atk["column"]:
				matchups.append({"attacker": atk, "defender": dfn})
				matched_def_ids.append(dfn["company_id"])
				break
	return matchups


static func _add_pending(pending: Dictionary, bc: Dictionary, dmg: int) -> void:
	var cid: int = bc["company_id"]
	pending[cid] = pending.get(cid, 0) + dmg


static func _ensure_trigger(triggers: Dictionary, bc: Dictionary) -> void:
	var cid: int = bc["company_id"]
	if not triggers.has(cid):
		triggers[cid] = {}


static func _find_bc_by_id(
	attackers: Array,
	defenders: Array,
	company_id: int,
) -> Dictionary:
	for bc: Dictionary in attackers:
		if bc["company_id"] == company_id:
			return bc
	for bc: Dictionary in defenders:
		if bc["company_id"] == company_id:
			return bc
	return {}
