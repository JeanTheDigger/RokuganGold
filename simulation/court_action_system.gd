class_name CourtActionSystem
## Court Action Menu resolution per GDD s15.4.
## Handles contested rolls, topic position shifts, session state
## (charm diminishing returns, TN reductions), and new court actions
## (PROVOKE_EMOTION, PLAY_GAME, DISCERN_NEED).


# -- Constants ----------------------------------------------------------------

# GDD s15.4: "Charm cannot push disposition above +40 (Friend tier)"
const CHARM_CEILING: int = 40
# GDD s15.4a: Charm base gain and raise bonus. Calibrated against GDD-known values
# (Play a Game +3, Gossip -5). Intentionally weaker than Negotiate to reflect
# shallowness and ceiling limitation.
const CHARM_FULL_GAIN: int = 5
const CHARM_RAISE_BONUS: int = 2
const CHARM_DIMINISHING_HALF: int = 2
const CHARM_DIMINISHING_MINIMAL: int = 3

# GDD s15.4a: Negotiate values. Position shift +8 is GDD-confirmed — s15.4 Public
# Debate text specifies "targeted actions (Negotiate: +8, Persuade: +12)".
# Disposition +6 ("Moderate" targeted), raise bonuses and TN reduction calibrated
# per s15.4a design rationale.
const NEGOTIATE_BASE_DISP: int = 6
const NEGOTIATE_RAISE_BONUS: int = 2
const NEGOTIATE_POSITION_SHIFT: float = 8.0
const NEGOTIATE_RAISE_POSITION_BONUS: float = 4.0
const NEGOTIATE_SESSION_TN_REDUCTION: int = 5

# GDD s15.4a: Persuade values. Position shift +12 is GDD-confirmed — s15.4 Public
# Debate text specifies "targeted actions (Negotiate: +8, Persuade: +12)".
# Disposition +9 ("Strong" targeted), raise bonuses calibrated per s15.4a.
# Position marked durable on success per GDD s15.4.
const PERSUADE_BASE_DISP: int = 9
const PERSUADE_RAISE_BONUS: int = 3
const PERSUADE_POSITION_SHIFT: float = 12.0
const PERSUADE_RAISE_POSITION_BONUS: float = 5.0

# GDD s15.4a: Impress values. Disposition +6 ("Moderate" targeted), raise bonus +2,
# TN reduction -5 ("slight" per s15.4). No position movement (GDD s15.4 does not
# mention position for Impress).
const IMPRESS_BASE_DISP: int = 6
const IMPRESS_RAISE_BONUS: int = 2
const IMPRESS_POSITION_SHIFT: float = 0.0
const IMPRESS_SESSION_TN_REDUCTION: int = 5

# GDD s15.4a: Listen/Reflect values. Disposition +9 ("Strong" targeted), raise bonus +3,
# TN reduction -10 (more significant than "slight" per s15.4's "opens them to future
# Persuade or Negotiate"). No position movement (GDD s15.4 does not mention position).
const LISTEN_REFLECT_BASE_DISP: int = 9
const LISTEN_REFLECT_RAISE_BONUS: int = 3
const LISTEN_REFLECT_POSITION_SHIFT: float = 0.0
const LISTEN_REFLECT_RAISE_POSITION_BONUS: float = 0.0
const LISTEN_REFLECT_SESSION_TN_REDUCTION: int = 10

# Critical failure disposition losses and Negotiate position hardening.
# GDD s15.4 describes outcomes qualitatively. Values calibrated in s15.4a:
# "Small disposition loss" (Charm/Negotiate/Impress/Listen/Reflect) = -3.
#   Anchor: Play a Game = ±3 (GDD-confirmed pleasant recreation magnitude).
#   Must be less than Gossip base damage (-5); -3 fits cleanly.
# "Disposition loss" (Persuade, no "small" qualifier) = -5.
#   Anchor: Gossip base damage (-5); a backfired Persuade that offends the
#   target warrants the same magnitude as a targeted social attack.
# Negotiate position hardening derived from Public Debate per-witness scale:
#   "hardens slightly" = ±1 (Public Debate "slight"); "significantly" = ±3 ("strong").
const CHARM_CRITICAL_FAILURE_DISP: int = -3
const NEGOTIATE_CRITICAL_FAILURE_DISP: int = -3
const NEGOTIATE_FAILURE_POSITION_HARDEN: float = -1.0
const NEGOTIATE_CRITICAL_POSITION_HARDEN: float = -3.0
const PERSUADE_CRITICAL_FAILURE_DISP: int = -5
const IMPRESS_CRITICAL_FAILURE_DISP: int = -3
const LISTEN_REFLECT_CRITICAL_FAILURE_DISP: int = -3

const PROVOKE_HONOR_LOSS: float = -0.2
const PROVOKE_GLORY_LOSS: float = -0.1
const PROVOKE_WITNESS_DISP: int = -3
const PROVOKE_CRITICAL_WITNESS_DISP: int = -5

const PLAY_GAME_BASE_DISP: int = 3
const PLAY_GAME_WINNER_BONUS: int = 1
const PLAY_GAME_DURATION_MONTHS: int = 2

const DEBATE_TIER_SCORES: Array[int] = [0, 2, 4, 6, 8]
const DEBATE_DISPOSITION_TIERS: Dictionary = {
	"blood_enemy": -3,
	"enemy": -2,
	"rival": -1,
	"stranger": 0,
	"acquaintance": 0,
	"friend": 1,
	"sworn": 2,
	"devoted": 3,
}

const GOSSIP_BASE_DISP: int = -5
const GOSSIP_RAISE_DAMAGE: int = -2

const DISCLOSE_CRITICAL_DISP: int = -5

const READ_CHARACTER_INFO_TYPES: Array[String] = [
	"personality_insight",
	"disposition_toward",
	"topic_attitude",
]

const INTELLIGENCE_RESULT_PARTIAL_MARGIN: int = 5


# -- Category 1: Negotiate (Contested) ----------------------------------------

static func resolve_negotiate(
	attacker_roll: int,
	defender_roll: int,
	raises: int,
	has_topic: bool,
	session_negotiate_count: int,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false, "disposition_change": 0}
		if margin <= -10:
			result["disposition_change"] = NEGOTIATE_CRITICAL_FAILURE_DISP
			if has_topic:
				result["position_hardened"] = true
				result["target_position_shift"] = NEGOTIATE_CRITICAL_POSITION_HARDEN
		elif has_topic:
			result["position_hardened"] = true
			result["target_position_shift"] = NEGOTIATE_FAILURE_POSITION_HARDEN
		return result

	var disp: int = NEGOTIATE_BASE_DISP + raises * NEGOTIATE_RAISE_BONUS
	var result: Dictionary = {
		"success": true,
		"disposition_change": disp,
		"session_tn_reduction": NEGOTIATE_SESSION_TN_REDUCTION,
	}

	if has_topic:
		result["target_position_shift"] = NEGOTIATE_POSITION_SHIFT + raises * NEGOTIATE_RAISE_POSITION_BONUS

	return result


# -- Category 1: Persuade (Contested) -----------------------------------------

static func resolve_persuade(
	attacker_roll: int,
	defender_roll: int,
	raises: int,
	has_topic: bool,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false, "disposition_change": 0}
		if margin <= -10:
			result["disposition_change"] = PERSUADE_CRITICAL_FAILURE_DISP
			if has_topic:
				result["position_hardened"] = true
		return result

	var disp: int = PERSUADE_BASE_DISP + raises * PERSUADE_RAISE_BONUS
	var result: Dictionary = {
		"success": true,
		"disposition_change": disp,
	}

	if has_topic:
		result["target_position_shift"] = PERSUADE_POSITION_SHIFT + raises * PERSUADE_RAISE_POSITION_BONUS
		result["position_durable"] = true

	return result


# -- Category 1: Charm (Contested, ceiling + diminishing) ---------------------

static func resolve_charm(
	attacker_roll: int,
	defender_roll: int,
	raises: int,
	current_disposition: int,
	session_charm_count: int,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false, "disposition_change": 0}
		if margin <= -10:
			result["disposition_change"] = CHARM_CRITICAL_FAILURE_DISP
		return result

	var base_disp: int = CHARM_FULL_GAIN + raises * CHARM_RAISE_BONUS
	if session_charm_count >= CHARM_DIMINISHING_MINIMAL:
		base_disp = maxi(base_disp / 4, 0)
	elif session_charm_count >= CHARM_DIMINISHING_HALF:
		base_disp = base_disp / 2

	var new_disp: int = current_disposition + base_disp
	if new_disp > CHARM_CEILING:
		base_disp = maxi(CHARM_CEILING - current_disposition, 0)

	return {
		"success": true,
		"disposition_change": base_disp,
		"charm_ceiling_active": current_disposition >= CHARM_CEILING,
	}


# -- Category 1: Impress (Contested) -----------------------------------------

static func resolve_impress(
	attacker_roll: int,
	defender_roll: int,
	raises: int,
	has_topic: bool = false,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false, "disposition_change": 0}
		if margin <= -10:
			result["disposition_change"] = IMPRESS_CRITICAL_FAILURE_DISP
		return result

	var result: Dictionary = {
		"success": true,
		"disposition_change": IMPRESS_BASE_DISP + raises * IMPRESS_RAISE_BONUS,
		"session_tn_reduction": IMPRESS_SESSION_TN_REDUCTION,
	}

	if has_topic:
		result["target_position_shift"] = IMPRESS_POSITION_SHIFT

	return result


# -- Category 1: Listen and Reflect (Contested) -------------------------------

static func resolve_listen_reflect(
	attacker_roll: int,
	defender_roll: int,
	raises: int,
	has_topic: bool = false,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false, "disposition_change": 0}
		if margin <= -10:
			result["disposition_change"] = LISTEN_REFLECT_CRITICAL_FAILURE_DISP
		return result

	var result: Dictionary = {
		"success": true,
		"disposition_change": LISTEN_REFLECT_BASE_DISP + raises * LISTEN_REFLECT_RAISE_BONUS,
		"persuade_negotiate_tn_reduction": LISTEN_REFLECT_SESSION_TN_REDUCTION,
	}

	if has_topic:
		result["target_position_shift"] = LISTEN_REFLECT_POSITION_SHIFT + raises * LISTEN_REFLECT_RAISE_POSITION_BONUS

	return result


# -- Category 1: Offer Favor (Contested) -------------------------------------

static func resolve_offer_favor(
	attacker_roll: int,
	defender_roll: int,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll

	if not success:
		return {"success": false, "disposition_change": 0}

	return {
		"success": true,
		"requires_favor_creation": true,
	}


# -- Category 1: Play a Game (Contested) -------------------------------------

static func resolve_play_game(
	player_a_roll: int,
	player_b_roll: int,
	a_id: int,
	b_id: int,
) -> Dictionary:
	var a_disp: int = PLAY_GAME_BASE_DISP
	var b_disp: int = PLAY_GAME_BASE_DISP

	if player_a_roll > player_b_roll:
		b_disp += PLAY_GAME_WINNER_BONUS
	elif player_b_roll > player_a_roll:
		a_disp += PLAY_GAME_WINNER_BONUS

	return {
		"success": true,
		"a_id": a_id,
		"b_id": b_id,
		"a_disposition_toward_b": a_disp,
		"b_disposition_toward_a": b_disp,
		"winner_id": a_id if player_a_roll > player_b_roll else (b_id if player_b_roll > player_a_roll else -1),
	}


# -- Category 3: Gossip (Split Raises) ---------------------------------------

static func resolve_gossip(
	roll_total: int,
	tn: int,
	damage_raises: int,
	concealment_raises: int,
) -> Dictionary:
	var success: bool = roll_total >= tn
	var margin: int = roll_total - tn

	if not success:
		var result: Dictionary = {"success": false}
		if margin <= -10:
			result["disposition_change"] = -5
		return result

	var disp_toward_subject: int = GOSSIP_BASE_DISP + (damage_raises * GOSSIP_RAISE_DAMAGE)
	return {
		"success": true,
		"gossip_subject_disposition": disp_toward_subject,
		"source_concealed": concealment_raises > 0,
		"concealment_depth": concealment_raises,
	}


static func compute_gossip_tn(
	subject_glory: float, gossiper_glory: float,
) -> int:
	return clampi(
		10 + int(subject_glory) * 5 - int(gossiper_glory) * 5,
		5, 60,
	)


# -- Category 3: Disclose (Contested) ----------------------------------------

static func resolve_disclose(
	attacker_roll: int,
	defender_roll: int,
	disclosed_opinion: int,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false}
		if margin <= -10:
			result["disposition_change"] = DISCLOSE_CRITICAL_DISP
		return result

	return {
		"success": true,
		"info_gained": true,
		"disclosed_opinion": disclosed_opinion,
	}


# -- Category 4: Provoke Emotion (Contested) ---------------------------------

static func resolve_provoke_emotion(
	attacker_roll: int,
	defender_roll: int,
	witness_ids: Array,
) -> Dictionary:
	var success: bool = attacker_roll >= defender_roll
	var margin: int = attacker_roll - defender_roll

	if not success:
		var result: Dictionary = {"success": false}
		if margin <= -10:
			result["witness_disposition_loss"] = PROVOKE_CRITICAL_WITNESS_DISP
			result["witnesses"] = witness_ids
		return result

	return {
		"success": true,
		"target_honor_change": PROVOKE_HONOR_LOSS,
		"target_glory_change": PROVOKE_GLORY_LOSS,
		"target_witness_disposition": PROVOKE_WITNESS_DISP,
		"witnesses": witness_ids,
	}


# -- Category 4: Public Debate (Per-Witness Position) -------------------------

static func resolve_public_debate(
	a_roll: int,
	b_roll: int,
	witness_dispositions_a: Dictionary,
	witness_dispositions_b: Dictionary,
	raises: int,
) -> Dictionary:
	var base_margin: int = a_roll - b_roll
	var a_won: bool = base_margin > 0

	var per_witness_results: Array = []
	var all_witnesses: Array = []
	for wid: int in witness_dispositions_a:
		if wid not in all_witnesses:
			all_witnesses.append(wid)
	for wid: int in witness_dispositions_b:
		if wid not in all_witnesses:
			all_witnesses.append(wid)

	for wid: int in all_witnesses:
		var tier_a: int = witness_dispositions_a.get(wid, 0)
		var tier_b: int = witness_dispositions_b.get(wid, 0)
		var combined_score: int = base_margin + tier_a - tier_b

		var winner_disp: int = 0
		var loser_disp: int = 0
		var position_shift: float = 0.0

		var abs_score: int = absi(combined_score)
		if abs_score >= 7:
			winner_disp = 4
			loser_disp = -4
		elif abs_score >= 5:
			winner_disp = 3
			loser_disp = -3
		elif abs_score >= 3:
			winner_disp = 2
			loser_disp = -2
		elif abs_score >= 1:
			winner_disp = 1
			loser_disp = -1

		if raises >= 3:
			position_shift = 8.0
		elif raises >= 2:
			position_shift = 6.0
		elif raises >= 1:
			position_shift = 4.0
		else:
			position_shift = 2.0

		var w_result: Dictionary = {
			"witness_id": wid,
			"combined_score": combined_score,
			"a_won_for_witness": combined_score > 0,
		}

		if combined_score > 0:
			w_result["a_disposition_change"] = winner_disp
			w_result["b_disposition_change"] = loser_disp
			w_result["position_shift_toward_a"] = position_shift
		elif combined_score < 0:
			w_result["a_disposition_change"] = loser_disp
			w_result["b_disposition_change"] = winner_disp
			w_result["position_shift_toward_a"] = -position_shift
		else:
			w_result["a_disposition_change"] = 0
			w_result["b_disposition_change"] = 0
			w_result["position_shift_toward_a"] = 0.0

		per_witness_results.append(w_result)

	return {
		"success": a_won,
		"base_margin": base_margin,
		"raises": raises,
		"per_witness_results": per_witness_results,
	}


# -- Category 5: Read Character (Observation) ---------------------------------

static func resolve_read_character(
	attacker_roll: int,
	defender_roll: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var margin: int = attacker_roll - defender_roll
	var success: bool = attacker_roll >= defender_roll
	var raises: int = maxi(int(margin / 5.0), 0) if success else 0

	if not success:
		if margin <= -10:
			var false_index: int = dice_engine.roll_and_keep(1, 1, 0).total % READ_CHARACTER_INFO_TYPES.size()
			return {
				"success": false,
				"critical_failure": true,
				"false_info": [READ_CHARACTER_INFO_TYPES[false_index]],
			}
		return {"success": false}

	var count: int = 1
	if raises >= 2:
		count = 3
	elif raises >= 1:
		count = 2

	if margin < INTELLIGENCE_RESULT_PARTIAL_MARGIN and raises == 0:
		return {
			"success": true,
			"partial": true,
			"info_count": 1,
			"info_types": _pick_random_info(1, dice_engine),
		}

	return {
		"success": true,
		"info_count": count,
		"info_types": _pick_random_info(count, dice_engine),
	}


# -- Category 5: Probe (Direct Conversation) ----------------------------------

static func resolve_probe(
	attacker_roll: int,
	defender_roll: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var margin: int = attacker_roll - defender_roll
	var success: bool = attacker_roll >= defender_roll
	var raises: int = maxi(int(margin / 5.0), 0) if success else 0

	var probe_types: Array = ["topic_position", "court_objective"]

	if not success:
		if margin <= -10:
			var false_index: int = dice_engine.roll_and_keep(1, 1, 0).total % probe_types.size()
			return {
				"success": false,
				"critical_failure": true,
				"false_info": [probe_types[false_index]],
				"detected": true,
			}
		return {"success": false, "detected": true}

	var count: int = 1
	if raises >= 1:
		count = 2

	if margin < INTELLIGENCE_RESULT_PARTIAL_MARGIN and raises == 0:
		return {
			"success": true,
			"partial": true,
			"info_count": 1,
			"info_types": [probe_types[dice_engine.roll_and_keep(1, 1, 0).total % probe_types.size()]],
			"detected": true,
		}

	var types: Array = []
	if count >= 2:
		types = probe_types.duplicate()
	else:
		types = [probe_types[dice_engine.roll_and_keep(1, 1, 0).total % probe_types.size()]]

	return {
		"success": true,
		"info_count": count,
		"info_types": types,
		"detected": true,
	}


# -- Category 5: Discern Need -------------------------------------------------

static func resolve_discern_need(
	attacker_roll: int,
	defender_roll: int,
) -> Dictionary:
	var margin: int = attacker_roll - defender_roll
	var success: bool = attacker_roll >= defender_roll

	if not success:
		if margin <= -10:
			return {
				"success": false,
				"critical_failure": true,
				"detected": true,
				"disposition_change": -3,
			}
		return {"success": false}

	return {
		"success": true,
		"info_gained": true,
		"info_type": "priority_objective",
		"detected": margin < INTELLIGENCE_RESULT_PARTIAL_MARGIN,
	}


# -- Contact Discovery: OBSERVE_COURT_ATTENDEES (s55.7.3 — LOCKED) ------------

const OBSERVE_COURT_TN: int = 15
const OBSERVE_COURT_MAX_ATTENDEES: int = 3

## Resolve OBSERVE_COURT_ATTENDEES per s55.7.3.
## roll_total: Perception + Investigation roll result.
## observable_count: how many unknown attendees are available to learn about.
## Returns {"success": bool, "learn_count": int} — caller picks which attendees.
static func resolve_observe_court_attendees(
	roll_total: int,
	observable_count: int,
) -> Dictionary:
	if roll_total < OBSERVE_COURT_TN:
		return {"success": false, "learn_count": 0}

	var margin: int = roll_total - OBSERVE_COURT_TN
	var raises: int = int(margin / 5.0)
	var learn_count: int = mini(1 + raises, OBSERVE_COURT_MAX_ATTENDEES)
	learn_count = mini(learn_count, observable_count)
	return {"success": true, "learn_count": learn_count}


# -- Contact Discovery: ASK_FOR_INTRODUCTION (s55.7.3 — LOCKED) ---------------

const ASK_FOR_INTRODUCTION_TN: int = 15
const ASK_FOR_INTRODUCTION_BASE_DISP: int = 3
const ASK_FOR_INTRODUCTION_KUGE_DISP: int = 2
const KUGE_STATUS_THRESHOLD: float = 7.0
const KUGE_INTERMEDIARY_MIN_STATUS: float = 4.0

## Resolve ASK_FOR_INTRODUCTION per s55.7.3.
## roll_total: pre-rolled Courtier/Awareness (normal) or Etiquette/Awareness (kuge).
## target_is_kuge: target Status >= KUGE_STATUS_THRESHOLD.
## intermediary_status: the Friend+ contact's Status (kuge gate: must be >= 4.0).
static func resolve_ask_for_introduction(
	roll_total: int,
	target_is_kuge: bool,
	intermediary_status: float,
) -> Dictionary:
	if target_is_kuge and intermediary_status < KUGE_INTERMEDIARY_MIN_STATUS:
		return {
			"success": false,
			"blocked_reason": "intermediary_insufficient_status",
		}

	if roll_total < ASK_FOR_INTRODUCTION_TN:
		return {"success": false}

	var disp_gain: int = ASK_FOR_INTRODUCTION_KUGE_DISP if target_is_kuge \
		else ASK_FOR_INTRODUCTION_BASE_DISP
	return {
		"success": true,
		"disposition_gain": disp_gain,
		"contact_added": true,
		"target_is_kuge": target_is_kuge,
	}


# -- Debate Disposition Tier Lookup -------------------------------------------

static func get_debate_disposition_tier(disposition: int) -> int:
	if disposition >= 91:
		return DEBATE_DISPOSITION_TIERS["devoted"]
	if disposition >= 61:
		return DEBATE_DISPOSITION_TIERS["sworn"]
	if disposition >= 31:
		return DEBATE_DISPOSITION_TIERS["friend"]
	if disposition >= 11:
		return DEBATE_DISPOSITION_TIERS["acquaintance"]
	if disposition >= -10:
		return DEBATE_DISPOSITION_TIERS["stranger"]
	if disposition >= -30:
		return DEBATE_DISPOSITION_TIERS["rival"]
	if disposition >= -60:
		return DEBATE_DISPOSITION_TIERS["enemy"]
	return DEBATE_DISPOSITION_TIERS["blood_enemy"]


# -- Helpers ------------------------------------------------------------------

static func _pick_random_info(count: int, dice_engine: DiceEngine) -> Array:
	var pool: Array = READ_CHARACTER_INFO_TYPES.duplicate()
	var result: Array = []
	for i: int in range(mini(count, pool.size())):
		var idx: int = dice_engine.roll_and_keep(1, 1, 0).total % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)
	return result
