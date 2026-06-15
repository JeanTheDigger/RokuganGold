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
