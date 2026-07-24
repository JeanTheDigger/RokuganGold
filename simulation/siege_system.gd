class_name SiegeSystem
## Siege mechanics: starvation, storm assault, sortie, honor cowardice,
## and siege event resolution per GDD s11.7. Pure static functions.


# -- Siege Phase -----------------------------------------------------------------

enum SiegePhase { EARLY, MID, LATE }


# -- Constants -------------------------------------------------------------------

const CIVILIAN_RICE_PER_PU_PER_TICK: float = 0.0028
const MILITARY_RICE_PER_PU_PER_TICK: float = 0.0039

const FORTIFICATION_DEFENSE_BONUS: int = 5

const HONOR_COWARDICE_DEFAULT_THRESHOLD: int = 30
const HONOR_COWARDICE_AGGRESSIVE_THRESHOLD: int = 20
const HONOR_COWARDICE_PRAGMATIC_THRESHOLD: int = 45
const HONOR_LOSS_INTERVAL: int = 10
const HONOR_LOSS_PER_INTERVAL: float = 1.0

const EARLY_PHASE_END: int = 30
const MID_PHASE_END: int = 60

const EVENT_INTERVAL_EARLY: int = 10
const EVENT_INTERVAL_MID: int = 7
const EVENT_INTERVAL_LATE: int = 5

const STORM_URBAN_DEFENSE_BONUS: int = 3
# s34 Drawing on the Mountain (Earth 5): the GDD "doubles the structure's Wounds and Reduction" maps
# onto our abstracted siege defense (owner 2026-06-25) — a defending shugenja hardens the wall, adding
# a storm-assault defense bonus. Set to FORTIFICATION_DEFENSE_BONUS = doubling the fortification's own
# defensive contribution (PROVISIONAL — the Wounds/Reduction → flat-bonus mapping is owner-defined).
const DRAWING_ON_MOUNTAIN_DEFENSE_BONUS: int = FORTIFICATION_DEFENSE_BONUS


# -- Siege Event Definitions -----------------------------------------------------

const ATTACKER_EVENTS: Array[String] = [
	"A1_SMUGGLING_RING",
	"A2_SECRET_PASSAGE",
	"A3_DESERTERS",
	"A4_RELIEF_FORCE",
	"A5_SUPPLY_TETHER_RAID",
	"A6_CONTAMINATE_WATER",
]

const DEFENDER_EVENTS: Array[String] = [
	"D1_MIDNIGHT_RESUPPLY",
	"D2_MESSAGE_FOR_RELIEF",
	"D3_TACTICAL_SORTIE",
	"D4_CIVILIAN_MORALE_CRISIS",
]

const MUTUAL_EVENTS: Array[String] = [
	"M1_TREACHERY_WITHIN",
]

const EVENT_DEFINITIONS: Dictionary = {
	"A1_SMUGGLING_RING": {
		"skill": "Perception", "trait": "Stealth", "tn": 20,
		"success_ticks": -10, "failure_ticks": 0,
		"side": "attacker",
	},
	"A2_SECRET_PASSAGE": {
		"skill": "Investigation", "trait": "Intelligence", "tn": 25,
		"success_ticks": -15, "failure_ticks": 0,
		"failure_effect": "concealment_plus_1",
		"side": "attacker",
	},
	"A3_DESERTERS": {
		"skill": "Courtier", "trait": "Awareness", "tn": 15,
		"success_ticks": -5, "failure_ticks": 0,
		"success_effect": "reveal_food_stores",
		"failure_effect": "garrison_morale_plus_5",
		"side": "attacker",
	},
	"A4_RELIEF_FORCE": {
		"skill": "", "trait": "", "tn": 0,
		"success_ticks": 0, "failure_ticks": 0,
		"is_strategic_decision": true,
		"side": "attacker",
	},
	"A5_SUPPLY_TETHER_RAID": {
		"skill": "Battle", "trait": "Agility", "tn": 20,
		"success_ticks": 0, "failure_ticks": 0,
		"failure_effect": "attacker_loses_rice_0_5",
		"side": "attacker",
	},
	"A6_CONTAMINATE_WATER": {
		"skill": "Engineering", "trait": "Intelligence", "tn": 30,
		"success_ticks": -20, "failure_ticks": 0,
		"honor_cost": -0.5,
		"personality_block": ["JIN", "GI"],
		"side": "attacker",
	},
	"D1_MIDNIGHT_RESUPPLY": {
		"skill": "Stealth", "trait": "Agility", "tn": 25,
		"success_ticks": 15, "failure_ticks": 0,
		"success_effect": "garrison_gains_rice_0_5",
		"side": "defender",
	},
	"D2_MESSAGE_FOR_RELIEF": {
		"skill": "Horsemanship", "trait": "Reflexes", "tn": 20,
		"success_ticks": 0, "failure_ticks": 0,
		"success_effect": "trigger_relief_force",
		"failure_effect": "attacker_learns_food_stores",
		"side": "defender",
	},
	"D3_TACTICAL_SORTIE": {
		"skill": "Battle", "trait": "Agility", "tn": 20,
		"success_ticks": 0, "failure_ticks": 0,
		"success_effect": "attacker_loses_arms_and_debuff",
		"failure_effect": "garrison_loses_pu_0_1",
		"side": "defender",
	},
	"D4_CIVILIAN_MORALE_CRISIS": {
		"skill": "Courtier", "trait": "Awareness", "tn": 20,
		"success_ticks": 0, "failure_ticks": 0,
		"failure_effect": "garrison_morale_minus_10",
		"jin_free_raise": true,
		"side": "defender",
	},
	"M1_TREACHERY_WITHIN": {
		"skill": "", "trait": "", "tn": 0,
		"success_ticks": -30, "failure_ticks": 0,
		"honor_cost": -0.5,
		"is_special": true,
		"side": "mutual",
	},
}


# -- Siege State Factory ---------------------------------------------------------

static func create_siege_state(
	settlement_id: int,
	attacker_army_id: int,
	defender_army_id: int,
	garrison_rice_stockpile: float,
	civilian_pu: float,
	garrison_pu: float,
) -> Dictionary:
	return {
		"settlement_id": settlement_id,
		"attacker_army_id": attacker_army_id,
		"defender_army_id": defender_army_id,
		"rice_stockpile": garrison_rice_stockpile,
		"civilian_pu": civilian_pu,
		"garrison_pu": garrison_pu,
		"ticks_elapsed": 0,
		"ticks_since_sortie": 0,
		"honor_loss_accumulated": 0.0,
		"garrison_starved": false,
		"siege_ended": false,
		"end_reason": "",
		"events_fired": [],
		"concealment_bonus": 0,
		"food_stores_revealed": false,
	}


# -- Starvation Mechanics -------------------------------------------------------

static func compute_daily_consumption(
	civilian_pu: float,
	garrison_pu: float,
) -> float:
	return (civilian_pu * CIVILIAN_RICE_PER_PU_PER_TICK) + (garrison_pu * MILITARY_RICE_PER_PU_PER_TICK)


static func compute_ticks_until_starvation(
	rice_stockpile: float,
	civilian_pu: float,
	garrison_pu: float,
) -> int:
	var daily: float = compute_daily_consumption(civilian_pu, garrison_pu)
	if daily <= 0.0:
		return 9999
	return floori(rice_stockpile / daily)


static func process_starvation_tick(
	siege_state: Dictionary,
	surrender_grace_ticks: int = 0,
) -> Dictionary:
	var consumption: float = compute_daily_consumption(
		siege_state["civilian_pu"],
		siege_state["garrison_pu"],
	)
	siege_state["rice_stockpile"] -= consumption
	siege_state["rice_stockpile"] = maxf(siege_state["rice_stockpile"], 0.0)
	siege_state["ticks_elapsed"] += 1
	siege_state["ticks_since_sortie"] += 1

	# s4.3 Kisada (Minor Fortune): a besieged province blessed by Kisada "holds one/
	# two extra seasons before forced surrender under siege." surrender_grace_ticks
	# (extra_seasons x DAYS_PER_SEASON, computed by the caller) delays the starvation
	# surrender: when rice first runs out, a grace countdown starts; garrison_starved
	# only fires once it expires. No Kisada -> grace 0 -> surrender immediately (default).
	var out_of_food: bool = siege_state["rice_stockpile"] <= 0.0
	var starved: bool = false
	if out_of_food:
		if surrender_grace_ticks > 0:
			if not siege_state.get("starvation_grace_started", false):
				siege_state["starvation_grace_started"] = true
				siege_state["starvation_grace_remaining"] = surrender_grace_ticks
			else:
				siege_state["starvation_grace_remaining"] = maxi(
					0, int(siege_state.get("starvation_grace_remaining", 0)) - 1,
				)
			starved = int(siege_state.get("starvation_grace_remaining", 0)) <= 0
		else:
			starved = true
	if starved:
		siege_state["garrison_starved"] = true

	return {
		"consumption": consumption,
		"rice_remaining": siege_state["rice_stockpile"],
		"starved": starved,
		"ticks_elapsed": siege_state["ticks_elapsed"],
		"starvation_grace_remaining": int(siege_state.get("starvation_grace_remaining", 0)),
	}


# -- Siege Phase -----------------------------------------------------------------

static func get_siege_phase(ticks_elapsed: int) -> SiegePhase:
	if ticks_elapsed <= EARLY_PHASE_END:
		return SiegePhase.EARLY
	elif ticks_elapsed <= MID_PHASE_END:
		return SiegePhase.MID
	return SiegePhase.LATE


static func get_event_interval(phase: SiegePhase) -> int:
	match phase:
		SiegePhase.EARLY:
			return EVENT_INTERVAL_EARLY
		SiegePhase.MID:
			return EVENT_INTERVAL_MID
		SiegePhase.LATE:
			return EVENT_INTERVAL_LATE
	return EVENT_INTERVAL_EARLY


static func should_fire_event(ticks_elapsed: int) -> bool:
	var phase: SiegePhase = get_siege_phase(ticks_elapsed)
	var interval: int = get_event_interval(phase)
	return ticks_elapsed > 0 and ticks_elapsed % interval == 0


# -- Siege Event Selection -------------------------------------------------------

static func select_event(
	dice: DiceEngine,
	side: String,
) -> String:
	var pool: Array
	if side == "attacker":
		pool = ATTACKER_EVENTS.duplicate()
	else:
		pool = DEFENDER_EVENTS.duplicate()
	pool.append_array(MUTUAL_EVENTS)
	var idx: int = dice.rand_int_range(0, pool.size() - 1)
	return pool[idx]


static func resolve_siege_event(
	dice: DiceEngine,
	event_id: String,
	trait_value: int,
	skill_rank: int,
	bonus: int = 0,
) -> Dictionary:
	var def: Dictionary = EVENT_DEFINITIONS[event_id]

	if def.get("is_strategic_decision", false):
		return {
			"event_id": event_id,
			"is_strategic_decision": true,
			"success": false,
			"tick_change": 0,
			"effects": [],
		}

	if def.get("is_special", false):
		return {
			"event_id": event_id,
			"is_special": true,
			"success": false,
			"tick_change": 0,
			"effects": [],
		}

	var tn: int = def["tn"]
	var roll_result: Dictionary = dice.roll_skill_check(
		trait_value, skill_rank, tn, 0, bonus,
	)
	var success: bool = roll_result["success"]

	var tick_change: int = 0
	var effects: Array = []

	if success:
		tick_change = def["success_ticks"]
		if def.has("success_effect"):
			effects.append(def["success_effect"])
	else:
		tick_change = def["failure_ticks"]
		if def.has("failure_effect"):
			effects.append(def["failure_effect"])

	var honor_cost: float = def.get("honor_cost", 0.0)

	return {
		"event_id": event_id,
		"success": success,
		"roll": roll_result.get("total", 0),
		"tn": tn,
		"tick_change": tick_change,
		"effects": effects,
		"honor_cost": honor_cost,
	}


static func apply_event_tick_change(
	siege_state: Dictionary,
	tick_change: int,
) -> void:
	if tick_change == 0:
		return
	if tick_change > 0:
		siege_state["rice_stockpile"] += tick_change * compute_daily_consumption(
			siege_state["civilian_pu"], siege_state["garrison_pu"],
		)
	else:
		siege_state["rice_stockpile"] += tick_change * compute_daily_consumption(
			siege_state["civilian_pu"], siege_state["garrison_pu"],
		)
		siege_state["rice_stockpile"] = maxf(siege_state["rice_stockpile"], 0.0)


# -- Storm Assault ---------------------------------------------------------------

static func get_storm_defense_bonus(
	has_fortification: bool = true, drawing_on_the_mountain: bool = false,
) -> int:
	var total: int = STORM_URBAN_DEFENSE_BONUS
	if has_fortification:
		total += FORTIFICATION_DEFENSE_BONUS
	# s34 Drawing on the Mountain: a defending shugenja's wall-hardening (owner 2026-06-25).
	if drawing_on_the_mountain:
		total += DRAWING_ON_MOUNTAIN_DEFENSE_BONUS
	return total


static func compute_garrison_effective_defense(
	base_defense: int,
	has_fortification: bool = true,
) -> int:
	var total: int = base_defense + STORM_URBAN_DEFENSE_BONUS
	if has_fortification:
		total += FORTIFICATION_DEFENSE_BONUS
	return total


# -- Honor Cowardice System -----------------------------------------------------

static func get_cowardice_threshold(personality_tag: String) -> int:
	match personality_tag:
		"aggressive":
			return HONOR_COWARDICE_AGGRESSIVE_THRESHOLD
		"pragmatic":
			return HONOR_COWARDICE_PRAGMATIC_THRESHOLD
	return HONOR_COWARDICE_DEFAULT_THRESHOLD


static func compute_honor_loss(
	ticks_since_sortie: int,
	personality_tag: String,
	character: L5RCharacterData = null,
) -> float:
	var threshold: int = get_cowardice_threshold(personality_tag)
	if ticks_since_sortie <= threshold:
		return 0.0
	var ticks_past: int = ticks_since_sortie - threshold
	var intervals: int = int(ticks_past / float(HONOR_LOSS_INTERVAL))
	var base: float = float(intervals) * HONOR_LOSS_PER_INTERVAL
	if character != null:
		return CrimeSystem.scale_honor_by_rank(-base, character)
	return base


static func process_honor_cowardice(
	siege_state: Dictionary,
	personality_tag: String,
) -> Dictionary:
	var loss: float = compute_honor_loss(
		siege_state["ticks_since_sortie"], personality_tag,
	)
	var new_loss: float = loss - siege_state["honor_loss_accumulated"]
	if new_loss > 0.0:
		siege_state["honor_loss_accumulated"] = loss
	return {
		"total_honor_loss": loss,
		"new_honor_loss": maxf(new_loss, 0.0),
		"ticks_since_sortie": siege_state["ticks_since_sortie"],
	}


static func reset_sortie_counter(siege_state: Dictionary) -> void:
	siege_state["ticks_since_sortie"] = 0
	siege_state["honor_loss_accumulated"] = 0.0


# -- Sortie Mechanics ------------------------------------------------------------

static func compute_sortie_terrain_bonus() -> Dictionary:
	return {
		"defender_defense_bonus": STORM_URBAN_DEFENSE_BONUS,
		"fortification_bonus": 0,
	}


# -- Tether Collapse Detection --------------------------------------------------

static func check_tether_ends_siege(
	tether_state: SupplyTetherSystem.TetherState,
) -> bool:
	## Returns true when the attacker's supply tether is fully broken, collapsing
	## the siege per GDD s11.7: "if that tether is cut... the siege collapses."
	return tether_state == SupplyTetherSystem.TetherState.BROKEN


# -- Siege Resolution ------------------------------------------------------------

static func check_siege_end(siege_state: Dictionary) -> Dictionary:
	if siege_state["garrison_starved"]:
		siege_state["siege_ended"] = true
		siege_state["end_reason"] = "starvation"
		return {"ended": true, "reason": "starvation"}
	return {"ended": false, "reason": ""}


static func end_siege(
	siege_state: Dictionary,
	reason: String,
) -> void:
	siege_state["siege_ended"] = true
	siege_state["end_reason"] = reason


# -- Full Tick Processing --------------------------------------------------------

static func process_siege_tick(
	siege_state: Dictionary,
	_dice: DiceEngine,
	personality_tag: String,
	surrender_grace_ticks: int = 0,
) -> Dictionary:
	if siege_state["siege_ended"]:
		return {"already_ended": true}

	var starve_result: Dictionary = process_starvation_tick(siege_state, surrender_grace_ticks)
	var honor_result: Dictionary = process_honor_cowardice(
		siege_state, personality_tag,
	)
	var end_check: Dictionary = check_siege_end(siege_state)

	var event_fired: Dictionary = {}
	if not end_check["ended"] and should_fire_event(siege_state["ticks_elapsed"]):
		event_fired = {"should_fire": true, "ticks_elapsed": siege_state["ticks_elapsed"]}
	else:
		event_fired = {"should_fire": false}

	return {
		"starvation": starve_result,
		"honor": honor_result,
		"ended": end_check["ended"],
		"end_reason": end_check["reason"],
		"event": event_fired,
	}
