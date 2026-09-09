class_name HuntSystem
## Samurai Hunting Party System per GDD s57.38.
## Handles ANNOUNCE_HUNT, REQUEST_HUNT_INVITATION, CANCEL_HUNT ActionIDs and
## NPC-only hunt resolution (beast tracking, kill check, casualty check).
## Player-involved ASCII mission generation is deferred pending s56 Quest System.

# -- Announcement window (s57.38.2) --------------------------------------------
const MIN_HUNT_DAYS_AHEAD: int = 7
const MAX_HUNT_DAYS_AHEAD: int = 21

# -- Social rules --------------------------------------------------------------
const STATUS_BAND: float = 2.0
const STATUS_DIRECTION_THRESHOLD: float = 1.0
const MIN_HUNTING_SKILL: int = 1

# -- Glory awards (s57.38.8) ---------------------------------------------------
const GLORY_KILLER: float = 0.3
const GLORY_SECOND_DAMAGE: float = 0.2
const GLORY_PARTICIPANT: float = 0.1
const GLORY_HOST_BONUS: float = 0.2
const GLORY_HOST_CANCEL: float = -0.2
const GLORY_DISASTROUS_HOST: float = -0.2
const GLORY_DISASTROUS_NONCOMBATANT_HOST: float = -0.4
const GLORY_WINTER_COURT_BONUS: float = 0.1

# -- Disposition changes (s57.38.8) --------------------------------------------
const DISP_CANCEL_PER_INVITEE: int = -1
const DISP_ACQUAINTANCE: int = 11
const DISP_FRIEND: int = 31

# -- Casualty thresholds (s57.38.6) -------------------------------------------
const CASUALTY_DOWN_MIN: int = 15
const CASUALTY_KILLED_MIN: int = 30

# -- Party defence modifier (s57.38.6) -----------------------------------------
const PARTY_SIZE_BONUS_PER_EXTRA: int = 3
const PARTY_SIZE_BONUS_CAP: int = 9

# -- Resolution constants ------------------------------------------------------
const TRACKING_TN: int = 15

# -- Outcome strings -----------------------------------------------------------
const OUTCOME_SUCCESS: String = "success"
const OUTCOME_FAILED: String = "failed"
const OUTCOME_COSTLY: String = "costly"
const OUTCOME_DISASTROUS: String = "disastrous"

# -- Hunt type strings ---------------------------------------------------------
const HUNT_TYPE_PARTY: String = "party"
const HUNT_TYPE_SOLO: String = "solo"

# -- School lean lists (Annex C, s57.38.2) ------------------------------------
const HUNT_POSITIVE_SCHOOL_PREFIXES: Array[String] = [
	"Hiruma", "Shinjo", "Matsu", "Usagi", "Hida", "Toritaka",
	"Kitsune", "Moto", "Yoritomo",
]
const HUNT_NEGATIVE_SCHOOL_PREFIXES: Array[String] = [
	"Doji", "Otomo", "Soshi", "Miya",
]
const HUNT_SCHOOL_LEAN: int = 15


# -- Beast stat blocks ---------------------------------------------------------
# wound_threshold is a hunt-specific abstraction per s57.38: "a rough proxy for
# how hard it is to land a mortal blow."
# GDD s54.1 confirms only bear and ozaru stats. Other 8 species (wolf, boar,
# stag, fox, ox, mountain_bear, goat, tiger) had interpolated stats that have
# been removed. They are blocked on s54 bestiary becoming LOCKED.
# GDD also specifies a "coastal" terrain pool (boar, wild goat, rare cliff
# predator) that is not yet implemented — blocked on coastal beast stat blocks.

const BEAST_STATS: Dictionary = {
	"bear": {"armor_tn": 20, "wound_threshold": 10, "initiative": 3, "attack_skill": 4},
	"ozaru": {"armor_tn": 30, "wound_threshold": 20, "initiative": 3, "attack_skill": 4},
}

# Terrain → beast pool (s57.38.6 "Beast generation — terrain pools")
# Last entry is the rare beast (lower probability).
# GDD specifies 5 terrain pools: plains, forest, hills, mountain, coastal.
# Only beasts with GDD-confirmed stat blocks (bear, ozaru) are usable.
# Terrain pools referencing unconfirmed beasts are commented out — blocked
# on s54 bestiary. Coastal pool also blocked on coastal beast stats.
const TERRAIN_BEAST_POOLS: Dictionary = {
	# Enums.TerrainType.PLAINS: ["wolf", "boar", "stag", "fox", "ox"],  # blocked on s54
	Enums.TerrainType.FOREST: ["bear"],
	# Enums.TerrainType.HILLS: ["boar", "wolf", "stag", "fox", "bear"],  # blocked on s54
	Enums.TerrainType.MOUNTAINS: ["bear", "ozaru"],
	# Enums.TerrainType.COASTAL: ["boar", "goat", "cliff_predator"],  # blocked on s54
}


static func generate_beast(terrain: Enums.TerrainType, dice_engine: DiceEngine) -> Dictionary:
	var pool: Array = TERRAIN_BEAST_POOLS.get(terrain, [])
	if pool.is_empty():
		var fallback: Dictionary = BEAST_STATS["bear"].duplicate()
		fallback["beast_name"] = "bear"
		return fallback
	var pick_roll: DiceResult = dice_engine.roll_and_keep(1, 1, false, false)
	var idx: int = (pick_roll.total - 1) % pool.size()
	var beast_name: String = pool[idx]
	var stats: Dictionary = BEAST_STATS.get(beast_name, BEAST_STATS["bear"]).duplicate()
	stats["beast_name"] = beast_name
	return stats


# -- Precondition checks -------------------------------------------------------

static func can_announce(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	if SkillResolver.get_skill_rank(character, "Hunting") < MIN_HUNTING_SKILL:
		return {"valid": false, "reason": "insufficient_hunting_skill"}
	var valid_contexts: Array = [
		Enums.ContextFlag.AT_OWN_HOLDINGS,
		Enums.ContextFlag.VISITING,
		Enums.ContextFlag.AT_COURT,
	]
	if not (ctx.context_flag in valid_contexts):
		return {"valid": false, "reason": "invalid_context"}
	if ctx.known_objectives.get("active_hunt_id", -1) >= 0:
		return {"valid": false, "reason": "hunt_already_active"}
	return {"valid": true}


static func can_cancel(
	_character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	if ctx.known_objectives.get("active_hunt_id", -1) < 0:
		return {"valid": false, "reason": "no_active_hunt"}
	var hunt_date: int = ctx.known_objectives.get("hunt_date_ic_day", -1)
	if hunt_date >= 0 and ctx.ic_day >= hunt_date:
		return {"valid": false, "reason": "hunt_date_passed"}
	var valid_contexts: Array = [
		Enums.ContextFlag.AT_OWN_HOLDINGS,
		Enums.ContextFlag.AT_COURT,
		Enums.ContextFlag.VISITING,
		Enums.ContextFlag.TRAVELING,
	]
	if not (ctx.context_flag in valid_contexts):
		return {"valid": false, "reason": "invalid_context"}
	return {"valid": true}


static func can_request_invitation(
	character: L5RCharacterData,
	host_status: float,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	var has_hunt_topic: bool = ctx.known_objectives.get("hunt_topic_id", -1) >= 0
	if not has_hunt_topic:
		return {"valid": false, "reason": "no_hunt_topic_known"}
	var status_diff: float = absf(character.status - host_status)
	if status_diff > STATUS_BAND:
		return {"valid": false, "reason": "status_too_far"}
	return {"valid": true}


# -- Invitation direction / response logic (s57.38.4) --------------------------

## Returns "peer", "downward" (invitee lower), or "upward" (invitee higher).
static func invitation_direction(host_status: float, invitee_status: float) -> String:
	var diff: float = host_status - invitee_status
	if absf(diff) < STATUS_DIRECTION_THRESHOLD:
		return "peer"
	elif diff >= STATUS_DIRECTION_THRESHOLD:
		return "downward"
	else:
		return "upward"


## Evaluate whether the invitee should accept a hunt invitation.
## Returns: {"should_accept": bool, "glory_change": float, "disposition_change": int}
static func evaluate_invitation_response(
	host_status: float,
	invitee_status: float,
	disposition_toward_host: int,
	is_rival: bool,
) -> Dictionary:
	var direction: String = invitation_direction(host_status, invitee_status)
	match direction:
		"downward":
			# Invitee lower-status: being honoured — default accept (s57.38.4)
			return {"should_accept": true, "glory_change": 0.1, "disposition_change": 2}
		"upward":
			# Invitee higher-status: accept only if Friend+ (s57.38.4)
			if is_rival:
				return {"should_accept": false, "glory_change": 0.0, "disposition_change": 0}
			if disposition_toward_host >= DISP_FRIEND:
				return {"should_accept": true, "glory_change": 0.0, "disposition_change": 3}
			return {"should_accept": false, "glory_change": 0.0, "disposition_change": 0}
		_:  # peer
			var accepts: bool = (disposition_toward_host >= DISP_ACQUAINTANCE) and not is_rival
			return {"should_accept": accepts, "glory_change": 0.0, "disposition_change": 0}


## Evaluate whether the HOST should accept a guest-initiated REQUEST_HUNT_INVITATION
## (s57.38.4 "Guest-initiated request" -- the mirror of, and numerically distinct
## from, evaluate_invitation_response's host-initiated rules above).
## host_status/requester_status: for direction (requester relative to host).
## host_disp_toward_requester: the HOST's disposition toward the requester -- "the
## host evaluates against disposition" (s57.38.4).
## is_rival: true when host_disp_toward_requester is Rival tier or worse (below -10,
## per s57.38.4's Rival exception). The exception text is stated for the upward case
## ("the host may decline even an upward request") -- for peer/downward it is already
## implied by their own disposition thresholds, so it is applied here only where the
## GDD text actually needs it to override a default: the upward branch.
## Returns: {"should_accept": bool, "disposition_change": int} -- applied to the
## REQUESTER's disposition toward the host on acceptance. No Glory is mentioned
## anywhere in s57.38.4's guest-initiated subsection (unlike host-initiated, which
## grants Glory in its downward/upward accept cases), so none is returned here.
static func evaluate_guest_request_response(
	host_status: float,
	requester_status: float,
	host_disp_toward_requester: int,
	is_rival: bool,
) -> Dictionary:
	var direction: String = invitation_direction(host_status, requester_status)
	match direction:
		"downward":
			# "Default accept if disposition is neutral or positive... Declining...
			# generates no disposition benefit. Accepting generates +1 disposition
			# toward the host from the requester."
			var accepts: bool = host_disp_toward_requester >= 0
			return {"should_accept": accepts, "disposition_change": (1 if accepts else 0)}
		"upward":
			# Rival exception overrides the default-accept: "the host may decline
			# even an upward request... no penalty at the host's end."
			if is_rival:
				return {"should_accept": false, "disposition_change": 0}
			# "Default accept regardless of disposition... Accepting generates +3
			# disposition toward the host from the requester."
			return {"should_accept": true, "disposition_change": 3}
		_:  # peer
			# "Default accept if disposition >= +11 (Acquaintance)... Declining...
			# carries a small disposition cost (-1) from the requester's perspective."
			var accepts: bool = (host_disp_toward_requester >= DISP_ACQUAINTANCE) and not is_rival
			return {"should_accept": accepts, "disposition_change": (0 if accepts else -1)}


# -- NPC-only hunt resolution (s57.38.6) ---------------------------------------

## Resolve an NPC-only hunt.
## participants: Array[L5RCharacterData] — host included.
## beast: Dictionary with armor_tn, wound_threshold, initiative, attack_skill.
## Returns outcome dict: {outcome, killer_id, second_id, wounded_id, killed_id, hunt_type}
static func resolve_npc_hunt(
	host: L5RCharacterData,
	participants: Array,
	beast: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var hunt_type: String = HUNT_TYPE_PARTY if participants.size() > 1 else HUNT_TYPE_SOLO
	var failed_base: Dictionary = {
		"outcome": OUTCOME_FAILED,
		"killer_id": -1,
		"second_id": -1,
		"wounded_id": -1,
		"killed_id": -1,
		"hunt_type": hunt_type,
	}

	if participants.is_empty():
		return failed_base

	# Tracking roll — leader (highest Hunting rank) rolls for the party
	var leader: L5RCharacterData = _find_hunt_leader(participants)
	if leader == null:
		leader = host
	var tracking: Dictionary = SkillResolver.resolve_skill_check(
		leader, dice_engine, "Hunting", TRACKING_TN, 0, "Tracking", Enums.Trait.PERCEPTION
	)
	if not tracking.get("success", false):
		return failed_base

	# Kill Check — only combatants (Kyujutsu or Spears >= 1) roll
	var combatants: Array = _get_combatants(participants)
	if combatants.is_empty():
		# All non-combatants: auto-failed, no casualty check
		return failed_base

	var best_hunter: L5RCharacterData = _find_best_hunter(combatants)
	var beast_tn: int = beast.get("armor_tn", 20) + (beast.get("wound_threshold", 10) / 2)
	var weapon_skill: String = _best_weapon_skill_name(best_hunter)
	# s57.38.6: "If multiple participants share the top rank, the one designated
	# as hunt leader adds their rank as a cooperative bonus per Section 41" --
	# mirrors the Tracking roll's leader-rank cooperative bonus above. "Top rank"
	# here must match how _find_best_hunter itself ranks combatants -- the higher
	# of Kyujutsu/Spears per combatant, not just their rank in best_hunter's
	# chosen weapon_skill (a Spears-5 combatant ties a Kyujutsu-5 best_hunter even
	# though their Kyujutsu rank is 0).
	var top_rank: int = SkillResolver.get_skill_rank(best_hunter, weapon_skill)
	var tie_count: int = 0
	for c_var: Variant in combatants:
		var c: L5RCharacterData = c_var as L5RCharacterData
		if c == null:
			continue
		var c_best_rank: int = maxi(
			SkillResolver.get_skill_rank(c, "Kyujutsu"),
			SkillResolver.get_skill_rank(c, "Spears")
		)
		if c_best_rank == top_rank:
			tie_count += 1
	var cooperative_bonus: int = SkillResolver.get_skill_rank(leader, weapon_skill) if tie_count > 1 else 0
	# "added to ... rolls" (Section 41 cooperative rule, mirrored from the
	# Tracking roll's identical phrasing) -> bonus_rolled, not raises or kept.
	var kill_result: Dictionary = SkillResolver.resolve_skill_check(
		best_hunter, dice_engine, weapon_skill, beast_tn, 0, "", Enums.Trait.AGILITY, cooperative_bonus
	)
	var beast_killed: bool = kill_result.get("success", false)
	var killer_id: int = best_hunter.character_id if beast_killed else -1
	var second_id: int = _find_second_hunter_id(combatants, best_hunter.character_id)

	# Casualty Check — beast attacks even if it fails or escapes
	var party_defence: int = compute_party_defence_tn(participants)
	var beast_threat: int = _roll_beast_threat(beast, dice_engine)
	var threat_excess: int = beast_threat - party_defence
	var wounded_id: int = -1
	var killed_id: int = -1
	var casualty_level: String = ""
	if threat_excess >= 1:
		var victim: L5RCharacterData = _select_casualty_victim(combatants, dice_engine)
		if victim != null:
			if threat_excess >= CASUALTY_KILLED_MIN:
				killed_id = victim.character_id
				casualty_level = "killed"
			elif threat_excess >= CASUALTY_DOWN_MIN:
				wounded_id = victim.character_id
				casualty_level = "down"
			else:
				wounded_id = victim.character_id
				casualty_level = "hurt"

	# Determine outcome
	var outcome: String
	if killed_id >= 0:
		outcome = OUTCOME_DISASTROUS
	elif casualty_level == "down" and not beast_killed:
		outcome = OUTCOME_DISASTROUS
	elif wounded_id >= 0 and beast_killed:
		outcome = OUTCOME_COSTLY
	elif wounded_id >= 0 and not beast_killed:
		# s57.38.6: "Failed hunt -- beast not found or beast escaped without killing
		# any participants." By this point casualty_level can only be "hurt" (the
		# "down" tier is already routed to DISASTROUS above) -- a mere Hurt wound on
		# a failed kill is still "escaped without killing any participants," not the
		# "serious casualties" the Disastrous definition requires.
		outcome = OUTCOME_FAILED
	elif beast_killed:
		outcome = OUTCOME_SUCCESS
	else:
		outcome = OUTCOME_FAILED

	return {
		"outcome": outcome,
		"killer_id": killer_id,
		"second_id": second_id,
		"wounded_id": wounded_id,
		"killed_id": killed_id,
		"casualty_level": casualty_level,
		"hunt_type": hunt_type,
	}


# -- Glory distribution (s57.38.8) ---------------------------------------------

## Compute glory deltas for all participants based on hunt outcome.
## participants: Array[Dictionary] — each: {character_id: int, is_noncombatant: bool}
## Returns: Dictionary {character_id(int): float glory_delta}
static func compute_glory_distribution(
	outcome: String,
	participants: Array,
	killer_id: int,
	second_id: int,
	host_id: int,
	is_noncombatant_killed: bool,
	is_winter_court: bool,
	is_solo: bool,
) -> Dictionary:
	var result: Dictionary = {}

	if is_solo:
		# Solo hunt: no glory from normal distribution; notable-beast case is caller's
		return result

	if outcome == OUTCOME_SUCCESS or outcome == OUTCOME_COSTLY:
		for p: Variant in participants:
			var pid: int = int(p.get("character_id", -1))
			if pid < 0:
				continue
			if pid == killer_id:
				result[pid] = GLORY_KILLER
			elif pid == second_id and second_id >= 0:
				result[pid] = GLORY_SECOND_DAMAGE
			else:
				result[pid] = GLORY_PARTICIPANT

		# Host bonus when they didn't land the kill
		if host_id >= 0 and host_id != killer_id:
			result[host_id] = result.get(host_id, 0.0) + GLORY_HOST_BONUS

		# Winter Court prestige bonus to host (s57.38.4c)
		if is_winter_court and host_id >= 0:
			result[host_id] = result.get(host_id, 0.0) + GLORY_WINTER_COURT_BONUS

	elif outcome == OUTCOME_DISASTROUS:
		# No success-side glory; host takes penalty
		if host_id >= 0:
			result[host_id] = (
				GLORY_DISASTROUS_NONCOMBATANT_HOST
				if is_noncombatant_killed
				else GLORY_DISASTROUS_HOST
			)

	# OUTCOME_FAILED: no glory changes

	return result


# -- School lean helpers (Annex C) ---------------------------------------------

static func has_hunt_positive_lean(school: String) -> bool:
	for prefix: String in HUNT_POSITIVE_SCHOOL_PREFIXES:
		if school.begins_with(prefix):
			return true
	return false


static func has_hunt_negative_lean(school: String) -> bool:
	for prefix: String in HUNT_NEGATIVE_SCHOOL_PREFIXES:
		if school.begins_with(prefix):
			return true
	return false


# -- Party defence (exposed for tests) -----------------------------------------

## Compute party defence TN: mean Armor TN + party-size bonus (capped).
## participants: Array[L5RCharacterData]
static func compute_party_defence_tn(participants: Array) -> int:
	if participants.is_empty():
		return 10
	var sum: int = 0
	var count: int = 0
	for p_var: Variant in participants:
		var c: L5RCharacterData = p_var as L5RCharacterData
		if c == null:
			continue
		# L5R 4e base Armor TN = Reflexes * 5 + 5, plus any armor bonus
		var armor_tn: int = c.reflexes * 5 + 5 + c.armor_tn_bonus
		sum += armor_tn
		count += 1
	if count == 0:
		return 10
	var mean_tn: int = sum / count
	var extra: int = mini(PARTY_SIZE_BONUS_PER_EXTRA * (count - 1), PARTY_SIZE_BONUS_CAP)
	return mean_tn + extra


# -- Private helpers -----------------------------------------------------------

static func _find_hunt_leader(participants: Array) -> L5RCharacterData:
	# s57.38.6: "leader is the party member with the highest Hunting Skill;
	# ties are broken by highest Perception."
	var best: L5RCharacterData = null
	var best_rank: int = -1
	for p_var: Variant in participants:
		var c: L5RCharacterData = p_var as L5RCharacterData
		if c == null:
			continue
		var rank: int = SkillResolver.get_skill_rank(c, "Hunting")
		if rank > best_rank or (rank == best_rank and best != null and c.perception > best.perception):
			best_rank = rank
			best = c
	return best


static func _get_combatants(participants: Array) -> Array:
	var result: Array = []
	for p_var: Variant in participants:
		var c: L5RCharacterData = p_var as L5RCharacterData
		if c == null:
			continue
		if SkillResolver.get_skill_rank(c, "Kyujutsu") > 0 \
				or SkillResolver.get_skill_rank(c, "Spears") > 0:
			result.append(c)
	return result


static func _find_best_hunter(combatants: Array) -> L5RCharacterData:
	var best: L5RCharacterData = null
	var best_rank: int = -1
	for c_var: Variant in combatants:
		var c: L5RCharacterData = c_var as L5RCharacterData
		if c == null:
			continue
		var rank: int = maxi(
			SkillResolver.get_skill_rank(c, "Kyujutsu"),
			SkillResolver.get_skill_rank(c, "Spears")
		)
		if rank > best_rank:
			best_rank = rank
			best = c
	return best


static func _find_second_hunter_id(combatants: Array, exclude_id: int) -> int:
	# s57.38.6: "Most-damage-dealt is assigned to the participant with the
	# second-highest rank in Kyujutsu or Spears (tiebreak: highest Agility)."
	var best: L5RCharacterData = null
	var best_rank: int = -1
	for c_var: Variant in combatants:
		var c: L5RCharacterData = c_var as L5RCharacterData
		if c == null or c.character_id == exclude_id:
			continue
		var rank: int = maxi(
			SkillResolver.get_skill_rank(c, "Kyujutsu"),
			SkillResolver.get_skill_rank(c, "Spears")
		)
		if rank > best_rank or (rank == best_rank and best != null and c.agility > best.agility):
			best_rank = rank
			best = c
	return best.character_id if best != null else -1


static func _best_weapon_skill_name(c: L5RCharacterData) -> String:
	var k: int = SkillResolver.get_skill_rank(c, "Kyujutsu")
	var s: int = SkillResolver.get_skill_rank(c, "Spears")
	return "Kyujutsu" if k >= s else "Spears"


static func _roll_beast_threat(beast: Dictionary, dice_engine: DiceEngine) -> int:
	var initiative: int = maxi(1, beast.get("initiative", 2))
	var attack_skill: int = maxi(1, beast.get("attack_skill", 2))
	var dr: DiceResult = dice_engine.roll_and_keep(
		initiative + attack_skill, initiative, true, false
	)
	return dr.total


## s57.38.6: "Victim selection: weighted random from participants, with weight
## inversely proportional to their best hunting weapon rank -- lower-skilled
## hunters are more likely to be the one the beast catches." combatants are
## already filtered to Kyujutsu/Spears >= 1 by _get_combatants, so rank is
## always >= 1 and 1.0 / rank is well-defined.
static func _select_casualty_victim(
	combatants: Array,
	dice_engine: DiceEngine,
) -> L5RCharacterData:
	var weights: Array = []
	var total_weight: float = 0.0
	for c_var: Variant in combatants:
		var c: L5RCharacterData = c_var as L5RCharacterData
		if c == null:
			continue
		var rank: int = maxi(
			SkillResolver.get_skill_rank(c, "Kyujutsu"),
			SkillResolver.get_skill_rank(c, "Spears")
		)
		var w: float = 1.0 / float(rank)
		weights.append(w)
		total_weight += w

	if total_weight <= 0.0:
		return null

	var pick: float = dice_engine.randf() * total_weight
	var cumulative: float = 0.0
	var idx: int = 0
	for c_var: Variant in combatants:
		var c: L5RCharacterData = c_var as L5RCharacterData
		if c == null:
			continue
		cumulative += weights[idx]
		if pick < cumulative:
			return c
		idx += 1
	return combatants[combatants.size() - 1] as L5RCharacterData
