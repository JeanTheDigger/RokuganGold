class_name SentakuTribunalSystem
## Sentaku Tribunal access-petition pipeline for Otosan Uchi (GDD s2.3.23).
##
## The Tribunal is a 5-member voting body that controls entry to the Inner City
## (ekohikei_access) and the Forbidden City (forbidden_city_access). A petition is
## distributed to all members; each votes independently via a weighted score, and
## a majority (3 of 5) grants the access flag. An explicit Imperial summons bypasses
## the vote entirely.
##
## This is a PURE mechanism: callers supply each member's precomputed clan
## disposition (member's clan → petitioner's clan, via CollectiveDisposition) and
## political_ok (false when the petitioner's clan is at war with a clan that member
## favours). All weights and thresholds are PROVISIONAL per GDD ("All threshold
## values and weight values PROVISIONAL pending balancing").

const PETITION_EKOHIKEI: String = "ekohikei"
const PETITION_FORBIDDEN: String = "forbidden_city"

# Per-member vote weights (s2.3.23 vote evaluation formula).
const WEIGHT_STATUS: float = 35.0
const WEIGHT_CLAN: float = 30.0
const WEIGHT_PERSONAL: float = 20.0
const WEIGHT_POLITICAL: float = 15.0

# Petitioner Status × 4.67, capped at the Status weight (Status 7.5 ≈ cap).
const STATUS_SCALE: float = 4.67
# Personal disposition default when the member has not met the petitioner —
# an unknown samurai receives a neutral-positive assessment, not a cold zero.
const PERSONAL_DEFAULT: float = 12.0

# Vote thresholds by petition type. Forbidden City is +10 stricter.
const THRESHOLD_EKOHIKEI: float = 50.0
const THRESHOLD_FORBIDDEN: float = 60.0

# Majority of a 5-member body (ties impossible with 5).
const VOTES_REQUIRED: int = 3
# Revoking an existing grant also takes 3 of 5 (s2.3.23 Duration).
const REVOKE_VOTES_REQUIRED: int = 3

# forbidden_city_access is per-visit; the petitioner declares a duration in IC
# days, clamped to this maximum (PROVISIONAL).
const FORBIDDEN_MAX_DURATION_DAYS: int = 7


static func threshold_for(petition_type: String) -> float:
	if petition_type == PETITION_FORBIDDEN:
		return THRESHOLD_FORBIDDEN
	return THRESHOLD_EKOHIKEI


static func clamp_forbidden_duration(days: int) -> int:
	return clampi(days, 1, FORBIDDEN_MAX_DURATION_DAYS)


# One Tribunal member's vote. clan_disposition is the member's clan-level
# disposition toward the petitioner's clan; political_ok is false when the
# petitioner's clan is at war with a clan the member favours.
static func evaluate_member_vote(
	member: L5RCharacterData,
	petitioner: L5RCharacterData,
	petition_type: String,
	clan_disposition: int,
	political_ok: bool,
) -> Dictionary:
	var status_score: float = minf(petitioner.status * STATUS_SCALE, WEIGHT_STATUS)
	var clan_score: float = clampf((float(clan_disposition) + 50.0) * 0.30, 0.0, WEIGHT_CLAN)

	var personal_score: float
	if member.met_characters.has(petitioner.character_id):
		var pd: float = float(member.disposition_values.get(petitioner.character_id, 0))
		personal_score = clampf((pd + 50.0) * 0.20, 0.0, WEIGHT_PERSONAL)
	else:
		personal_score = PERSONAL_DEFAULT

	var political_score: float = WEIGHT_POLITICAL if political_ok else 0.0
	var total: float = status_score + clan_score + personal_score + political_score
	return {"score": total, "vote": total >= threshold_for(petition_type)}


# Resolves the full petition. clan_dispositions and political_oks are aligned with
# `members`. is_summons short-circuits to a grant (Imperial summons bypass).
static func resolve_petition(
	members: Array,
	petitioner: L5RCharacterData,
	petition_type: String,
	clan_dispositions: Array,
	political_oks: Array,
	is_summons: bool = false,
) -> Dictionary:
	if is_summons:
		return {
			"granted": true, "bypass": true,
			"yes_votes": 0, "total_members": members.size(), "breakdown": [],
		}

	var yes: int = 0
	var breakdown: Array = []
	for i: int in range(members.size()):
		var cd: int = int(clan_dispositions[i]) if i < clan_dispositions.size() else 0
		var po: bool = bool(political_oks[i]) if i < political_oks.size() else true
		var v: Dictionary = evaluate_member_vote(members[i], petitioner, petition_type, cd, po)
		if v["vote"]:
			yes += 1
		breakdown.append(v)

	return {
		"granted": yes >= VOTES_REQUIRED, "bypass": false,
		"yes_votes": yes, "total_members": members.size(), "breakdown": breakdown,
	}


# ===========================================================================
# Governor Performance Review (s2.3.23 "Governor Performance Review")
# ===========================================================================
# Each seasonal tick the Tribunal evaluates every Otosan Uchi Governor. A review
# only fires when a district has shown trouble in the past season (see
# should_review_governor). When it fires, all 5 members vote on whether to
# petition the Emperor for dismissal; 3 of 5 YES votes produces a recommendation.
# The Emperor (not the Tribunal) makes the final dismissal call elsewhere.
#
# Per-member dismissal-vote weights (s2.3.23). All PROVISIONAL per the GDD's
# blanket "All threshold values and weight values PROVISIONAL pending balancing."
const REVIEW_WEIGHT_STABILITY: float = 30.0
const REVIEW_WEIGHT_CRIME: float = 20.0
const REVIEW_WEIGHT_GOV_DISPOSITION: float = 20.0
const REVIEW_WEIGHT_GOV_CLAN: float = 15.0
const REVIEW_WEIGHT_TENURE: float = 15.0

# score >= this = YES (petition Emperor to dismiss). 3 of 5 YES → recommendation.
const REVIEW_THRESHOLD: float = 60.0

# Review triggers (s2.3.23): any one of these in the past season fires a review.
const REVIEW_STABILITY_TRIGGER: float = 50.0
const REVIEW_CRIME_TRIGGER: int = 3          # "crime incidents exceeded 3"
const REVIEW_NEW_GOVERNOR_SEASONS: int = 1   # "in office less than 1 IC season"

# Normalization ceilings for inputs the GDD gives a weight + direction for but no
# explicit curve. Linear-to-weight, mirroring the access-petition formula above.
# PROVISIONAL — chosen to make the documented anchors land sensibly.
const REVIEW_CRIME_CAP: int = 10             # crime_count at/above this = full weight
const REVIEW_TENURE_CAP_SEASONS: int = 8     # tenure at/above this = full curve extent
# Personal disposition assumed when a member has not met the Governor — neutral.
const REVIEW_DISPOSITION_DEFAULT: float = 0.0


# True when the Governor's district has shown trouble worth a Tribunal review this
# season (s2.3.23 trigger list). stability_dropped is whether the district lost any
# Stability since taking office (the "Juramashi effect" early-failure clause).
static func should_review_governor(
	district_stability: float,
	crime_count: int,
	has_negative_topic: bool,
	in_office_seasons: int,
	stability_dropped: bool,
) -> bool:
	if district_stability < REVIEW_STABILITY_TRIGGER:
		return true
	if crime_count > REVIEW_CRIME_TRIGGER:
		return true
	if has_negative_topic:
		return true
	if in_office_seasons < REVIEW_NEW_GOVERNOR_SEASONS and stability_dropped:
		return true
	return false


# One Tribunal member's dismissal vote. District metrics (stability, crime, tenure)
# are district-scoped scalars; disposition and clan are read per-member from the
# member and governor objects (mirrors the access-petition formula). is_juramashi
# inverts the tenure curve (surviving the chaos district earns patience).
static func evaluate_governor_review_vote(
	member: L5RCharacterData,
	governor: L5RCharacterData,
	district_stability: float,
	crime_count: int,
	in_office_seasons: int,
	is_juramashi: bool,
) -> Dictionary:
	# Stability: lower Stability → more likely dismissal (below 25 near-automatic).
	var s: float = clampf(district_stability, 0.0, 100.0)
	var stability_score: float = (100.0 - s) / 100.0 * REVIEW_WEIGHT_STABILITY

	# Crime: more incidents → more likely dismissal. Linear to the crime cap.
	var crime_frac: float = clampf(float(crime_count) / float(REVIEW_CRIME_CAP), 0.0, 1.0)
	var crime_score: float = crime_frac * REVIEW_WEIGHT_CRIME

	# Governor disposition: a member who likes the Governor protects them; one who
	# dislikes them pushes for removal. Higher disposition → lower dismissal score.
	var gd: float = REVIEW_DISPOSITION_DEFAULT
	if member.met_characters.has(governor.character_id):
		gd = float(member.disposition_values.get(governor.character_id, 0))
	gd = clampf(gd, -50.0, 50.0)
	var disposition_score: float = (50.0 - gd) / 100.0 * REVIEW_WEIGHT_GOV_DISPOSITION

	# Governor clan: a same-clan member resists dismissal (contributes nothing); a
	# member of any other clan supplies the full clan-loyalty push.
	var clan_score: float = 0.0 if member.clan == governor.clan else REVIEW_WEIGHT_GOV_CLAN

	# Time in office: normally a long-serving Governor who is STILL failing is judged
	# more harshly than a newcomer (longer tenure → higher dismissal). In Juramashi
	# the curve inverts — surviving longer earns increasing patience.
	var tenure_frac: float = clampf(
		float(in_office_seasons) / float(REVIEW_TENURE_CAP_SEASONS), 0.0, 1.0
	)
	var tenure_score: float
	if is_juramashi:
		tenure_score = (1.0 - tenure_frac) * REVIEW_WEIGHT_TENURE
	else:
		tenure_score = tenure_frac * REVIEW_WEIGHT_TENURE

	var total: float = (
		stability_score + crime_score + disposition_score + clan_score + tenure_score
	)
	return {"score": total, "vote": total >= REVIEW_THRESHOLD}


# Resolves a full Governor review. members is the 5-member Tribunal. Returns
# recommend_dismiss=true when 3 of 5 vote to petition the Emperor.
static func resolve_governor_review(
	members: Array,
	governor: L5RCharacterData,
	district_stability: float,
	crime_count: int,
	in_office_seasons: int,
	is_juramashi: bool,
) -> Dictionary:
	var yes: int = 0
	var breakdown: Array = []
	for m: Variant in members:
		var member: L5RCharacterData = m as L5RCharacterData
		if member == null or CharacterStats.is_dead(member):
			continue
		var v: Dictionary = evaluate_governor_review_vote(
			member, governor, district_stability, crime_count,
			in_office_seasons, is_juramashi
		)
		if v["vote"]:
			yes += 1
		breakdown.append(v)

	return {
		"recommend_dismiss": yes >= VOTES_REQUIRED,
		"yes_votes": yes, "total_members": breakdown.size(), "breakdown": breakdown,
	}
