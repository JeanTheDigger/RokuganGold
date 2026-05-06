class_name TravelCommitment
## Travel commitment and oscillation prevention per GDD s55.29.
## Three subsystems:
##   1. Travel frustration counter — penalizes repeated redirects
##   2. Sublocation access — gates entry to courts/private/restricted areas
##   3. Objective stall detection — fires REASSESS_OBJECTIVE on stalled goals


# =============================================================================
# 55.29.1 — Travel Frustration Counter
# =============================================================================

const REDIRECT_PENALTIES: Array[int] = [0, -5, -15, -30]


static func get_redirect_penalty(travel_redirects: int) -> int:
	if travel_redirects <= 0:
		return 0
	var idx: int = mini(travel_redirects, REDIRECT_PENALTIES.size() - 1)
	return REDIRECT_PENALTIES[idx]


static func increment_redirects(objective: Dictionary) -> void:
	var current: int = objective.get("travel_redirects", 0)
	objective["travel_redirects"] = current + 1


static func reset_redirects(objective: Dictionary) -> void:
	objective["travel_redirects"] = 0


static func should_reset_redirects(context_flag: Enums.ContextFlag) -> bool:
	return context_flag in [
		Enums.ContextFlag.AT_COURT,
		Enums.ContextFlag.AT_OWN_HOLDINGS,
		Enums.ContextFlag.VISITING,
		Enums.ContextFlag.ON_CAMPAIGN,
	]


# =============================================================================
# 55.29.2 — Sublocation Access
# =============================================================================

static func can_access_sublocation(
	ctx: NPCDataStructures.ContextSnapshot,
	target_sublocation: Enums.Sublocation,
	court_min_status: float = 3.0,
	court_open_session: bool = false,
	has_court_invitation: bool = false,
	is_household_member: bool = false,
	has_guest_status: bool = false,
	has_qualifying_role: bool = false,
	has_access_flags: bool = false,
) -> bool:
	match target_sublocation:
		Enums.Sublocation.PUBLIC:
			return true
		Enums.Sublocation.COURT:
			if has_court_invitation:
				return true
			if ctx.status >= court_min_status:
				return true
			if court_open_session:
				return true
			return false
		Enums.Sublocation.PRIVATE:
			return is_household_member or has_guest_status
		Enums.Sublocation.RESTRICTED:
			return has_qualifying_role or has_access_flags
	return false


static func get_denial_reason(
	target_sublocation: Enums.Sublocation,
	ctx: NPCDataStructures.ContextSnapshot,
	court_min_status: float = 3.0,
	has_court_invitation: bool = false,
	is_household_member: bool = false,
	has_guest_status: bool = false,
	has_qualifying_role: bool = false,
) -> Enums.AccessDenialReason:
	match target_sublocation:
		Enums.Sublocation.COURT:
			if not has_court_invitation and ctx.status < court_min_status:
				return Enums.AccessDenialReason.INSUFFICIENT_STATUS
			return Enums.AccessDenialReason.NO_INVITATION
		Enums.Sublocation.PRIVATE:
			if not is_household_member and not has_guest_status:
				return Enums.AccessDenialReason.NO_INVITATION
			return Enums.AccessDenialReason.HOST_REFUSAL
		Enums.Sublocation.RESTRICTED:
			return Enums.AccessDenialReason.RESTRICTED_ROLE
	return Enums.AccessDenialReason.INSUFFICIENT_STATUS


const DENIAL_FALLBACK_ACTIONS: Dictionary = {
	Enums.AccessDenialReason.INSUFFICIENT_STATUS: ["SEND_LETTER", "ACQUIRE_LEVERAGE", "ATTEND_COURT"],
	Enums.AccessDenialReason.NO_INVITATION: ["RAISE_DISPOSITION", "SEND_LETTER", "ACQUIRE_LEVERAGE"],
	Enums.AccessDenialReason.HOSTILE_CLAN: ["RAISE_DISPOSITION", "DISGUISE"],
	Enums.AccessDenialReason.RESTRICTED_ROLE: ["SEND_LETTER", "REASSESS_OBJECTIVE"],
	Enums.AccessDenialReason.HOST_REFUSAL: ["ACQUIRE_LEVERAGE", "SEND_LETTER", "REST"],
}


static func get_fallback_actions(reason: Enums.AccessDenialReason) -> Array:
	return DENIAL_FALLBACK_ACTIONS.get(reason, ["REST"])


# =============================================================================
# 55.29.3 — Objective Stall Detection
# =============================================================================

# Personality thresholds: seasons without progress before REASSESS fires.
# Key = BushidoVirtue or ShouridoVirtue, Value = threshold in seasons.
const BUSHIDO_STALL_THRESHOLDS: Dictionary = {
	Enums.BushidoVirtue.YU: 5,
	Enums.BushidoVirtue.JIN: 2,
	Enums.BushidoVirtue.GI: 2,
	Enums.BushidoVirtue.CHUGI: 3,
	Enums.BushidoVirtue.REI: 3,
	Enums.BushidoVirtue.MEIYO: 3,
	Enums.BushidoVirtue.MAKOTO: 3,
	Enums.BushidoVirtue.NONE: 3,
}

const SHOURIDO_STALL_THRESHOLDS: Dictionary = {
	Enums.ShouridoVirtue.KETSUI: 5,
	Enums.ShouridoVirtue.KYORYOKU: 5,
	Enums.ShouridoVirtue.DOSATSU: 3,
	Enums.ShouridoVirtue.SEIGYO: 3,
	Enums.ShouridoVirtue.CHISHIKI: 3,
	Enums.ShouridoVirtue.KANPEKI: 3,
	Enums.ShouridoVirtue.ISHI: 3,
	Enums.ShouridoVirtue.NONE: 3,
}

const DEFAULT_STALL_THRESHOLD: int = 3


static func get_stall_threshold(character: L5RCharacterData) -> int:
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return SHOURIDO_STALL_THRESHOLDS.get(
			character.shourido_virtue, DEFAULT_STALL_THRESHOLD
		)
	return BUSHIDO_STALL_THRESHOLDS.get(
		character.bushido_virtue, DEFAULT_STALL_THRESHOLD
	)


static func update_progress(
	objective: Dictionary,
	new_progress: float,
) -> void:
	var old: float = objective.get("last_measured_progress", 0.0)
	objective["last_measured_progress"] = new_progress
	if new_progress > old + 0.001:
		objective["seasons_without_progress"] = 0
	else:
		var stalled: int = objective.get("seasons_without_progress", 0)
		objective["seasons_without_progress"] = stalled + 1


static func is_stalled(
	objective: Dictionary,
	character: L5RCharacterData,
) -> bool:
	var seasons: int = objective.get("seasons_without_progress", 0)
	var threshold: int = get_stall_threshold(character)

	# Lord-assigned objectives with CHUGI never self-abandon
	if character.bushido_virtue == Enums.BushidoVirtue.CHUGI:
		if objective.get("lord_assigned", false):
			return false

	return seasons >= threshold


static func make_reassess_need(
	objective: Dictionary,
) -> NPCDataStructures.ImmediateNeed:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REASSESS_OBJECTIVE"
	need.source = "stall_detection"
	need.target_intent = objective.get("need_type", "")
	return need
