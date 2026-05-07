class_name PhoenixCouncil
## Phoenix Clan governance exception per GDD s55.10.3.
##
## Implements the Council-gated Strategic Evaluation: the Shiba Champion
## proposes, the five-Master Elemental Council approves or rejects via
## majority vote (3 of 5). Per-Master temperament dominates voting behavior.
## Defiance and Overreach paths track escalation between Champion and
## Council; Schism integration is deferred until Section 53.2 lands.
##
## Pure simulation class — no Node inheritance, no scene tree.
##
## State is a plain Dictionary owned by the caller, shaped:
##   {
##     "defiance_count": int,                  # 0..4 (Champion bypassed Council)
##     "defiance_stage": int,                  # 0..4
##     "overreach_count": int,                 # 0..3 (Council abused authority)
##     "overreach_stage": int,                 # 0..4
##     "consecutive_seasons_compliant": int,
##     "phoenix_champion_authority": bool,     # post-schism Champion-victory flag
##     "tabled_proposals": Dictionary,         # decision_type -> { season_tabled, last_vote_result }
##     "consecutive_crisis_vetoes": int,
##     "consecutive_obstruction_seasons": int,
##   }


# -- Five elemental masters --------------------------------------------------

enum Master {
	FIRE,
	WATER,
	AIR,
	EARTH,
	VOID,
}


# -- Decision categorisation (s55.10.3.2) ------------------------------------

enum DecisionType {
	# Major — require Council vote.
	DECLARE_WAR,
	DEPLOY_GO_HATAMOTO,           # Phoenix military outside Phoenix territory
	SIGN_TREATY,
	MAJOR_RESOURCE_SPEND,
	GRAND_RITUAL,
	COMMIT_SHUGENJA,              # Phoenix shugenja in another clan's campaign

	# Champion-handled — no vote needed.
	INTERNAL_GOVERNANCE,
	DIPLOMATIC_REPRESENTATION,
	ROUTINE_MILITARY,
	TAX_ADJUSTMENT,
	FILL_LOW_VACANCY,             # below Family Daimyo level
}

const MAJOR_DECISIONS: Array[DecisionType] = [
	DecisionType.DECLARE_WAR,
	DecisionType.DEPLOY_GO_HATAMOTO,
	DecisionType.SIGN_TREATY,
	DecisionType.MAJOR_RESOURCE_SPEND,
	DecisionType.GRAND_RITUAL,
	DecisionType.COMMIT_SHUGENJA,
]


# -- Major-resource threshold ------------------------------------------------

const MAJOR_RESOURCE_KOKU_THRESHOLD: float = 500.0


# -- Vote thresholds (s55.10.3.3) -------------------------------------------

const REQUIRED_YES_VOTES: int = 3                # 3 of 5 majority
const COUNCIL_TOTAL_SEATS: int = 5
const SOLE_CHAMPION_AUTHORITY_THRESHOLD: int = 3 # Below this, Champion appoints replacements


# -- Per-Master vote weights -------------------------------------------------

# Each Master's elemental temperament biases votes by decision type.
# Positive favors YES, negative favors NO. Tied to s55.10.3.3 master profiles.
# Void is excluded — Void uses the omen-based random model below.

const MASTER_VOTE_BASE: Dictionary = {
	Master.FIRE: {
		DecisionType.DECLARE_WAR: 15,
		DecisionType.DEPLOY_GO_HATAMOTO: 10,
		DecisionType.GRAND_RITUAL: 10,
		DecisionType.COMMIT_SHUGENJA: 5,
		DecisionType.SIGN_TREATY: -10,
		DecisionType.MAJOR_RESOURCE_SPEND: 0,
	},
	Master.WATER: {
		DecisionType.SIGN_TREATY: 10,
		DecisionType.MAJOR_RESOURCE_SPEND: 5,
		DecisionType.DECLARE_WAR: 0,
		DecisionType.DEPLOY_GO_HATAMOTO: 0,
		DecisionType.GRAND_RITUAL: -5,
		DecisionType.COMMIT_SHUGENJA: 0,
	},
	Master.AIR: {
		DecisionType.SIGN_TREATY: 15,
		DecisionType.MAJOR_RESOURCE_SPEND: 5,
		DecisionType.DECLARE_WAR: -15,
		DecisionType.DEPLOY_GO_HATAMOTO: -10,
		DecisionType.GRAND_RITUAL: -5,
		DecisionType.COMMIT_SHUGENJA: -5,
	},
	Master.EARTH: {
		DecisionType.DECLARE_WAR: -15,
		DecisionType.DEPLOY_GO_HATAMOTO: -10,
		DecisionType.SIGN_TREATY: 5,
		DecisionType.MAJOR_RESOURCE_SPEND: -5,
		DecisionType.COMMIT_SHUGENJA: -10,
		DecisionType.GRAND_RITUAL: 5,
	},
}


# -- Vote modifiers ----------------------------------------------------------

const FRIEND_DISPOSITION_THRESHOLD: int = 31
const RIVAL_DISPOSITION_THRESHOLD: int = -11
const DISPOSITION_VOTE_BONUS: int = 5

const TIER_1_CRISIS_BONUS: int = 15
const ELEMENT_THREATENED_BONUS: int = 20

# Void Master parameters
const VOID_BASE_YES_CHANCE: int = 40            # 40% baseline
const VOID_SPIRITUAL_CRISIS_BONUS: int = 20
const VOID_NO_SPIRITUAL_PENALTY: int = -20
const VOID_ABSTAIN_THRESHOLD: int = 10          # Roll <= this → abstain
# (PROVISIONAL — the GDD doesn't prescribe an exact abstain probability.
# 10% on a d100 keeps abstention rare but real.)


# -- Vote evaluation ---------------------------------------------------------

static func is_major_decision(decision_type: DecisionType) -> bool:
	return decision_type in MAJOR_DECISIONS


# Returns {vote: "yes"|"no"|"abstain", score: int} for a single Master.
#
# `proposal` is a dict shaped:
#   {
#     "decision_type": DecisionType,
#     "crisis_response": bool,           # addresses an active Tier 1 crisis
#     "threatens_element": Master | -1,  # element whose domain is threatened
#     "spiritual_dimension": bool,       # for Void Master only
#   }
# `disposition_to_champion` is the master's disposition value (-100..100).
# `dice_engine` is required for the Void Master's omen roll.
static func evaluate_master_vote(
	master: Master,
	proposal: Dictionary,
	disposition_to_champion: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	if master == Master.VOID:
		return _evaluate_void_vote(proposal, dice_engine)
	return _evaluate_elemental_vote(master, proposal, disposition_to_champion)


static func _evaluate_elemental_vote(
	master: Master,
	proposal: Dictionary,
	disposition_to_champion: int,
) -> Dictionary:
	var decision_type: DecisionType = proposal.get("decision_type", DecisionType.DECLARE_WAR)
	var weights: Dictionary = MASTER_VOTE_BASE.get(master, {})
	var score: int = int(weights.get(decision_type, 0))

	# Disposition modifier (s55.10.3.3 additional).
	if disposition_to_champion >= FRIEND_DISPOSITION_THRESHOLD:
		score += DISPOSITION_VOTE_BONUS
	elif disposition_to_champion <= RIVAL_DISPOSITION_THRESHOLD:
		score -= DISPOSITION_VOTE_BONUS

	# Crisis override — survival overrides temperament.
	if proposal.get("crisis_response", false):
		score += TIER_1_CRISIS_BONUS

	# Master's own element threatened — lock-in YES regardless of temperament.
	if int(proposal.get("threatens_element", -1)) == master:
		score += ELEMENT_THREATENED_BONUS

	if score > 0:
		return {"vote": "yes", "score": score}
	if score < 0:
		return {"vote": "no", "score": score}
	# Ties resolve as NO — the conservative default for major decisions.
	return {"vote": "no", "score": 0}


static func _evaluate_void_vote(
	proposal: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	# Roll d100. Lower = abstain, mid = vote per omen, high = no.
	if dice_engine == null:
		# Deterministic fallback: NO. Caller should always supply dice in
		# production; tests that don't care can omit.
		return {"vote": "no", "score": 0}
	var roll: int = dice_engine.rand_int_range(1, 100)
	if roll <= VOID_ABSTAIN_THRESHOLD:
		return {"vote": "abstain", "score": roll}
	# Apply spiritual modifiers to the YES chance.
	var yes_chance: int = VOID_BASE_YES_CHANCE
	if bool(proposal.get("spiritual_dimension", false)):
		# Crisis with spiritual nature → Void leans YES.
		if proposal.get("crisis_response", false):
			yes_chance += VOID_SPIRITUAL_CRISIS_BONUS
	else:
		yes_chance += VOID_NO_SPIRITUAL_PENALTY
	# After the abstain band, normalize the remaining 90 points around the
	# adjusted yes_chance.
	# Simpler model: re-roll inside the (abstain..100] band and compare.
	var post_abstain_roll: int = dice_engine.rand_int_range(1, 100)
	if post_abstain_roll <= yes_chance:
		return {"vote": "yes", "score": post_abstain_roll}
	return {"vote": "no", "score": post_abstain_roll}


# Tally a full Council vote. Returns:
#   {
#     "passed": bool,
#     "yes": int, "no": int, "abstain": int,
#     "deadlocked": bool,                  # 2-2 with Void abstaining
#     "votes": Dictionary[Master -> String]
#   }
static func tally_vote(
	living_masters: Array,
	proposal: Dictionary,
	dispositions_to_champion: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var votes: Dictionary = {}
	var yes_count: int = 0
	var no_count: int = 0
	var abstain_count: int = 0
	for master in living_masters:
		var disp: int = int(dispositions_to_champion.get(master, 0))
		var ev: Dictionary = evaluate_master_vote(master, proposal, disp, dice_engine)
		votes[master] = ev["vote"]
		match ev["vote"]:
			"yes": yes_count += 1
			"no": no_count += 1
			"abstain": abstain_count += 1
	var passed: bool = yes_count >= REQUIRED_YES_VOTES
	var deadlocked: bool = (
		abstain_count > 0
		and yes_count == no_count
		and not passed
	)
	return {
		"passed": passed,
		"yes": yes_count,
		"no": no_count,
		"abstain": abstain_count,
		"deadlocked": deadlocked,
		"votes": votes,
	}


# -- Deadlock handling (s55.10.3.4) ------------------------------------------

static func table_proposal(
	state: Dictionary,
	decision_type: DecisionType,
	current_season: int,
) -> void:
	var tabled: Dictionary = state.get("tabled_proposals", {})
	tabled[decision_type] = {
		"season_tabled": current_season,
		"vote_count": int(tabled.get(decision_type, {}).get("vote_count", 0)) + 1,
	}
	state["tabled_proposals"] = tabled


static func get_tabled_vote_count(
	state: Dictionary,
	decision_type: DecisionType,
) -> int:
	var tabled: Dictionary = state.get("tabled_proposals", {})
	return int(tabled.get(decision_type, {}).get("vote_count", 0))


static func champion_may_break_tie(
	state: Dictionary,
	decision_type: DecisionType,
) -> bool:
	# After two consecutive abstentions on the same proposal the Champion
	# may break the tie at the Honor cost in §55.10.3.4.
	return get_tabled_vote_count(state, decision_type) >= 2


# -- Defiance Path (s55.10.3.5) ----------------------------------------------

static func handle_unilateral_action(state: Dictionary) -> void:
	## Champion bypassed the Council on a major decision. Increments the
	## defiance counter and stage; resets compliant-season streak.
	var dc: int = int(state.get("defiance_count", 0)) + 1
	state["defiance_count"] = dc
	state["defiance_stage"] = mini(dc, 4)
	state["consecutive_seasons_compliant"] = 0


static func handle_compliant_season(state: Dictionary) -> void:
	## A full season of submitting major decisions through Council vote.
	## One season reduces the stage by one (unwinds escalation gradually).
	state["consecutive_seasons_compliant"] = (
		int(state.get("consecutive_seasons_compliant", 0)) + 1
	)
	state["defiance_stage"] = maxi(int(state.get("defiance_stage", 0)) - 1, 0)
	# defiance_count tracks lifetime defiance for "no clean slate" — does
	# not reset, mirroring s55.10.2.6's escalation scope rule.


static func is_diplomatic_suspended(state: Dictionary) -> bool:
	return int(state.get("defiance_stage", 0)) >= 2


static func is_shugenja_withdrawn(state: Dictionary) -> bool:
	return int(state.get("defiance_stage", 0)) >= 3


static func is_unfit_declaration_active(state: Dictionary) -> bool:
	return int(state.get("defiance_stage", 0)) >= 4


# -- Overreach Path (s55.10.3.6) ---------------------------------------------

# Triggers tracked by the caller; this class only owns the counter
# and stage queries.

static func handle_overreach_trigger(state: Dictionary) -> void:
	var oc: int = int(state.get("overreach_count", 0)) + 1
	state["overreach_count"] = oc
	state["overreach_stage"] = mini(oc, 4)


static func is_emperor_appeal_available(state: Dictionary) -> bool:
	return int(state.get("overreach_stage", 0)) >= 2


static func is_compact_declared_violated(state: Dictionary) -> bool:
	return int(state.get("overreach_stage", 0)) >= 3


static func is_overreach_schism_imminent(state: Dictionary) -> bool:
	return int(state.get("overreach_stage", 0)) >= 4


static func track_consecutive_crisis_veto(state: Dictionary) -> bool:
	## Increments and returns true if the threshold (3) crossed this veto.
	var n: int = int(state.get("consecutive_crisis_vetoes", 0)) + 1
	state["consecutive_crisis_vetoes"] = n
	if n >= 3:
		handle_overreach_trigger(state)
		return true
	return false


static func reset_crisis_veto_streak(state: Dictionary) -> void:
	state["consecutive_crisis_vetoes"] = 0


static func track_consecutive_obstruction(state: Dictionary) -> bool:
	## Total obstruction (Council refuses ANY proposal) for 3+ seasons → overreach.
	var n: int = int(state.get("consecutive_obstruction_seasons", 0)) + 1
	state["consecutive_obstruction_seasons"] = n
	if n >= 3:
		handle_overreach_trigger(state)
		return true
	return false


static func reset_obstruction_streak(state: Dictionary) -> void:
	state["consecutive_obstruction_seasons"] = 0


# -- phoenix_champion_authority flag (s55.10.3.7 victory) -------------------

static func grant_champion_authority(state: Dictionary) -> void:
	state["phoenix_champion_authority"] = true


static func has_champion_authority(state: Dictionary) -> bool:
	return bool(state.get("phoenix_champion_authority", false))


static func restore_council_compact(state: Dictionary) -> void:
	## RESTORE_COUNCIL_COMPACT action — only the Champion can do this.
	## Returns governance to the traditional model.
	state["phoenix_champion_authority"] = false
	state["defiance_count"] = 0
	state["defiance_stage"] = 0
	state["overreach_count"] = 0
	state["overreach_stage"] = 0
	state["consecutive_crisis_vetoes"] = 0
	state["consecutive_obstruction_seasons"] = 0


# Reincarnation hook — used during the schism path: a new Champion who
# inherited the flag may voluntarily restore it based on virtue and
# disposition.
static func reincarnated_champion_evaluates_restore(
	new_champion: L5RCharacterData,
	disposition_to_council_avg: int,
	duty_score: int,
) -> bool:
	## Returns true if the new Champion voluntarily restores the compact.
	if new_champion == null:
		return false
	# Chugi-dominant with Duty score above 60 → restores within first season.
	if new_champion.bushido_virtue == Enums.BushidoVirtue.CHUGI and duty_score >= 60:
		return true
	# Ishi-dominant or Seigyo-dominant — keep autonomous authority.
	if new_champion.shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return false
	if new_champion.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return false
	# Otherwise — disposition-driven. Friend+ toward Council → restore.
	return disposition_to_council_avg >= FRIEND_DISPOSITION_THRESHOLD


# -- Master vacancy / extinction (s55.10.3.9) -------------------------------

static func count_living_masters(living_masters: Array) -> int:
	return living_masters.size()


static func can_council_self_govern(living_masters: Array) -> bool:
	return count_living_masters(living_masters) >= SOLE_CHAMPION_AUTHORITY_THRESHOLD


static func champion_appoints_replacements(living_masters: Array) -> bool:
	## True when the Council is below quorum and the Champion gains
	## temporary appointment authority for vacant seats.
	return not can_council_self_govern(living_masters)


static func is_council_extinct(living_masters: Array) -> bool:
	return count_living_masters(living_masters) == 0


# -- Initial state factory --------------------------------------------------

static func make_initial_state() -> Dictionary:
	return {
		"defiance_count": 0,
		"defiance_stage": 0,
		"overreach_count": 0,
		"overreach_stage": 0,
		"consecutive_seasons_compliant": 0,
		"phoenix_champion_authority": false,
		"tabled_proposals": {},
		"consecutive_crisis_vetoes": 0,
		"consecutive_obstruction_seasons": 0,
	}
