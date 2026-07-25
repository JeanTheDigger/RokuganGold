class_name HonorGlorySystem
## Honor, Glory, Status, and Infamy management per GDD s4.6.
## All values on 0.0–10.0 scale. 1 "point" = 0.1, 1 "rank" = 1.0.
## Changes apply immediately — no batching.


# -- Core Modification ---------------------------------------------------------

static func apply_honor_change(character: L5RCharacterData, delta: float) -> float:
	var actual_delta: float = delta
	# IDEALISTIC (s45): honor losses are 1 point larger.
	if delta < 0.0:
		actual_delta -= float(AdvantageSystem.get_honor_loss_increase(character))
	var old: float = character.honor
	character.honor = clampf(character.honor + actual_delta, 0.0, 10.0)
	return character.honor - old


static func apply_glory_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.glory
	# ASCETIC disadvantage halves all glory changes (s45)
	var scaled: float = delta * AdvantageSystem.get_glory_multiplier(character)
	character.glory = clampf(character.glory + scaled, 0.0, 10.0)
	return character.glory - old


static func apply_status_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.status
	character.status = clampf(character.status + delta, 0.0, 10.0)
	return character.status - old


static func apply_infamy_change(character: L5RCharacterData, delta: float) -> float:
	var old: float = character.infamy
	character.infamy = clampf(character.infamy + delta, 0.0, 10.0)
	return character.infamy - old


# -- Rank Queries --------------------------------------------------------------

static func get_honor_rank(character: L5RCharacterData) -> int:
	return int(character.honor)


static func get_glory_rank(character: L5RCharacterData) -> int:
	return int(character.glory)


## s45 CAST_OUT: returns 0 when observer's Brotherhood sect treats target's glory as infamy.
## Use this instead of get_glory_rank() whenever glory is displayed or scored socially.
static func get_observed_glory_rank(target: L5RCharacterData, observer: L5RCharacterData) -> int:
	if observer != null and observer.brotherhood_sect != "":
		if AdvantageSystem.is_glory_treated_as_infamy_by(target, observer.brotherhood_sect):
			return 0
	return get_glory_rank(target)


static func get_status_rank(character: L5RCharacterData) -> int:
	return int(character.status)


static func get_infamy_rank(character: L5RCharacterData) -> int:
	return int(character.infamy)


# -- Court Credibility (s4.6 Honor as Court Credibility) -----------------------
# Returns the number of Free Raises (positive) or additional Raises required
# (negative) for Public Declarations and Offer a Favor actions.

static func get_court_honor_modifier(character: L5RCharacterData) -> int:
	var rank: int = get_honor_rank(character)
	if rank >= 7:
		return 2
	if rank >= 5:
		return 1
	if rank >= 3:
		return 0
	if rank >= 2:
		return -1
	return -2


# -- Recognition ---------------------------------------------------------------
# Combined Glory + Infamy ranks determine how widely known someone is.

static func get_recognition_rank(character: L5RCharacterData) -> int:
	return get_glory_rank(character) + get_infamy_rank(character)


# -- Court Event Table Constants -----------------------------------------------
#
# ⚠ AUDIT 2026-07-25: every GLORY_* constant in this block is UNREFERENCED — nothing
# reads them. Do not assume the awards below are therefore missing; most are live
# elsewhere with their own values, so wiring these would double-apply. Verified owners:
#   * Public performance → `PerformativeArtsSystem` (SUCCESS_GLORY 0.3, +MASTERFUL_GLORY
#     0.2 = 0.5 total, CRITICAL_FAILURE_GLORY -0.3). Values agree with the three
#     performance constants here, so those three are a duplicate copy — a drift hazard.
#     ActionExecutor deliberately returns glory_change 0.0 for PUBLIC_PERFORMANCE
#     ("Already applied by PerformativeArtsSystem").
#   * PUBLIC_DEBATE decisive win → hardcoded 0.3 at 3+ Raises in ActionExecutor's
#     broadcast path (agrees with GLORY_PUBLIC_DEBATE_DECISIVE_WIN).
#   * PUBLIC_DECLARATION → hardcoded 0.1 in the same path, which does NOT match
#     GLORY_PUBLIC_DECLARATION_HONORED (0.2); the constant's name suggests it is the
#     "honored" (promise-kept) case rather than the plain success case, so the two are
#     probably different events, not a contradiction.
#
# DO NOT WIRE GLORY_DEBATE_DECISIVE_LOSS without an owner ruling: the LOCKED public
# debate spec (s15.4:255-291) defines only per-witness DISPOSITION and TOPIC-POSITION
# consequences for winning/losing — including for critical failure — and specifies no
# Glory change at all. The same applies to the remaining unsourced entries
# (GLORY_PUBLICLY_PRAISE_*, which has no corresponding ActionID; GLORY_DUEL_WON_HONORABLY,
# GLORY_INSULT_BACKFIRED, GLORY_EXPOSE_SECRET_FAIL). Applying them would be inventing
# values the GDD does not specify.

const GLORY_PUBLIC_PERFORMANCE_SUCCESS: float = 0.3
const GLORY_PUBLIC_PERFORMANCE_MASTERFUL: float = 0.5
const GLORY_PUBLIC_DEBATE_DECISIVE_WIN: float = 0.3
const GLORY_PUBLICLY_PRAISE_SELF: float = 0.1
const GLORY_PUBLICLY_PRAISE_TARGET: float = 0.2
const GLORY_PUBLIC_DECLARATION_HONORED: float = 0.2
const GLORY_DUEL_WON_HONORABLY: float = 0.5
const GLORY_PERFORM_PERSONALLY_MASTERFUL: float = 0.2

const GLORY_PERFORMANCE_CRITICAL_FAIL: float = -0.3
const GLORY_DEBATE_DECISIVE_LOSS: float = -0.2
const GLORY_INSULT_BACKFIRED: float = -0.2
const GLORY_EXPOSE_SECRET_FAIL: float = -0.3

const HONOR_PUBLIC_DECLARATION_KEPT: float = 0.2
const HONOR_FAVOR_HONORED: float = 0.1
const HONOR_VIRTUE_REFUSAL: float = 0.1

const HONOR_RENEGE_DECLARATION: float = -1.0
const HONOR_FABRICATED_SECRET_EXPOSED: float = -0.5
const HONOR_PROXY_COMMIT_ACCEPTED_LORD: float = -0.3
const HONOR_PROXY_COMMIT_ACCEPTED_PROXY: float = -0.5
const HONOR_PROXY_COMMIT_REFUSED_LORD: float = -0.2
const HONOR_PROXY_COMMIT_REFUSED_PROXY: float = -1.0
const HONOR_GOSSIP_VIRTUE_BREACH: float = -0.5

# Public Atonement
const ATONEMENT_GLORY_LOSS: float = -0.3
const ATONEMENT_CRITICAL_FAIL_GLORY_LOSS: float = -0.5
const ATONEMENT_CRITICAL_FAIL_HONOR_LOSS: float = -0.3
const ATONEMENT_HONOR_PER_RAISE: float = 0.1

const ATONEMENT_HONOR_BY_TIER: Dictionary = {
	4: 0.3,
	3: 0.5,
	2: 0.8,
	1: 1.0,
}

const ATONEMENT_TN_BY_TIER: Dictionary = {
	4: 15,
	3: 20,
	2: 25,
	1: 30,
}


static func can_atone(character: L5RCharacterData, offense_key: String) -> bool:
	return offense_key not in character.atoned_offenses


static func record_atonement(character: L5RCharacterData, offense_key: String) -> void:
	if offense_key not in character.atoned_offenses:
		character.atoned_offenses.append(offense_key)
