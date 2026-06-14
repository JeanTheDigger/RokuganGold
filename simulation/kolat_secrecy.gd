class_name KolatSecrecy
## Kolat secrecy, Imperial counter-response, and win condition (GDD s54.7i, LOCKED).
## Pure simulation class — no Node inheritance. Operates on two world-state scalars
## (kolat_exposure_level, imperial_awareness_level) and Tiger's candidate pipeline.
## All numeric deltas and thresholds are taken verbatim from s54.7i.

# === Exposure deltas (s54.7i, public/PC knowledge) ===========================
const EXPOSURE_TRACED_MERCHANT_NETWORK: int = 5     # operation traced to a named merchant net
const EXPOSURE_COVER_IDENTITY_CRIMINAL: int = 10    # a Master's cover tied to crime publicly
const EXPOSURE_ORG_ASSASSINATION: int = 15          # assassination attributed to an organisation
const EXPOSURE_PLAYER_PUBLISH_MIN: int = 10         # PC community publishes evidence (scope-scaled)
const EXPOSURE_PLAYER_PUBLISH_MAX: int = 25
const EXPOSURE_LOTUS_ELIMINATE: int = -5            # investigator silenced before reporting
const EXPOSURE_COIN_BRIBE: int = -3                 # report buried by the right magistrate
const EXPOSURE_CLOUD_RESURRECT: int = -5            # cover topics muddy the evidence
const EXPOSURE_NATURAL_DECAY_PER_SEASON: int = -2   # no fresh evidence

# === Imperial awareness deltas (s54.7i, private throne knowledge) =============
const AWARENESS_JADE_INTERNAL: int = 5              # Jade Magistrate reports a Kolat operative
const AWARENESS_PLAYER_EVIDENCE_MIN: int = 10       # PC presents evidence to Imperial authority
const AWARENESS_PLAYER_EVIDENCE_MAX: int = 30
const AWARENESS_MASTER_INTERROGATED: int = 20       # captured Master interrogated by Seppun
const AWARENESS_KEY_DISCOVERED: int = 40            # tiger_succession_key / master identities found

# === Imperial response thresholds (s54.7i) ===================================
const RESPONSE_ACTIVE_THRESHOLD: int = 30           # imperial_response_active fires

enum ResponseTier { UNAWARE, SUSPICIOUS, CONFIRMED_THREAT, PARTIALLY_MAPPED, SIGNIFICANTLY_MAPPED, FULL_KNOWLEDGE }

# === Win condition (s54.7i) ==================================================
const WIN_AWARENESS_CEILING: int = 70               # Empire cannot act decisively below this
const WIN_HOLD_DAYS: int = TimeSystem.IC_DAYS_PER_YEAR  # one full IC year undiscovered

# NPC court roles with direct, unchecked proximity to the Emperor (s54.7i win (a)).
const IMPERIAL_PROXIMITY_ROLES: Array[String] = [
	"Regent", "Imperial Advisor", "Voice of the Emperor", "Imperial Chancellor",
]


# === SCALAR APPLICATION ======================================================

## Clamp any 0–100 secrecy scalar after a delta.
static func apply_delta(current: int, delta: int) -> int:
	return clampi(current + delta, 0, 100)


# === EVENT → DELTA DISPATCH (s54.7i) =========================================
# A single tested entry point the future operation/investigation executors call
# instead of hand-coding deltas. All values are verbatim from s54.7i.

enum ExposureEvent {
	TRACED_MERCHANT_NETWORK, COVER_IDENTITY_CRIMINAL, ORG_ASSASSINATION,
	PLAYER_PUBLISH, LOTUS_ELIMINATE, COIN_BRIBE, CLOUD_RESURRECT, NATURAL_DECAY,
}

enum AwarenessEvent { JADE_INTERNAL, PLAYER_EVIDENCE, MASTER_INTERROGATED, KEY_DISCOVERED }


## Exposure delta for an event. `scope` (0.0–1.0) interpolates the player-publish
## range (+10..+25); ignored for fixed-value events.
static func exposure_delta(event: ExposureEvent, scope: float = 0.0) -> int:
	match event:
		ExposureEvent.TRACED_MERCHANT_NETWORK:
			return EXPOSURE_TRACED_MERCHANT_NETWORK
		ExposureEvent.COVER_IDENTITY_CRIMINAL:
			return EXPOSURE_COVER_IDENTITY_CRIMINAL
		ExposureEvent.ORG_ASSASSINATION:
			return EXPOSURE_ORG_ASSASSINATION
		ExposureEvent.PLAYER_PUBLISH:
			return _scope_lerp(EXPOSURE_PLAYER_PUBLISH_MIN, EXPOSURE_PLAYER_PUBLISH_MAX, scope)
		ExposureEvent.LOTUS_ELIMINATE:
			return EXPOSURE_LOTUS_ELIMINATE
		ExposureEvent.COIN_BRIBE:
			return EXPOSURE_COIN_BRIBE
		ExposureEvent.CLOUD_RESURRECT:
			return EXPOSURE_CLOUD_RESURRECT
		ExposureEvent.NATURAL_DECAY:
			return EXPOSURE_NATURAL_DECAY_PER_SEASON
	return 0


## Awareness delta for an event. `scope` (0.0–1.0) interpolates the player-evidence
## range (+10..+30); ignored for fixed-value events.
static func awareness_delta(event: AwarenessEvent, scope: float = 0.0) -> int:
	match event:
		AwarenessEvent.JADE_INTERNAL:
			return AWARENESS_JADE_INTERNAL
		AwarenessEvent.PLAYER_EVIDENCE:
			return _scope_lerp(AWARENESS_PLAYER_EVIDENCE_MIN, AWARENESS_PLAYER_EVIDENCE_MAX, scope)
		AwarenessEvent.MASTER_INTERROGATED:
			return AWARENESS_MASTER_INTERROGATED
		AwarenessEvent.KEY_DISCOVERED:
			return AWARENESS_KEY_DISCOVERED
	return 0


## Linear interpolation across a scope range, rounded to the nearest int.
static func _scope_lerp(lo: int, hi: int, scope: float) -> int:
	return int(round(lerpf(float(lo), float(hi), clampf(scope, 0.0, 1.0))))


## Seasonal exposure decay (s54.7i). The −2/season natural decay always applies;
## while the Empire is actively suppressing (awareness above the response
## threshold) the same decrement represents deliberate containment — s54.7i gives
## no additional numeric beyond the natural rate, so no extra amount is invented.
static func apply_seasonal_exposure_decay(exposure: int, _awareness: int) -> int:
	return apply_delta(exposure, EXPOSURE_NATURAL_DECAY_PER_SEASON)


# === IMPERIAL RESPONSE STATE =================================================

## imperial_response_active (s54.7i): true at awareness ≥ 30.
static func is_response_active(awareness: int) -> bool:
	return awareness >= RESPONSE_ACTIVE_THRESHOLD


## Map awareness to the Imperial response tier (s54.7i thresholds).
static func response_tier(awareness: int) -> ResponseTier:
	if awareness >= 100:
		return ResponseTier.FULL_KNOWLEDGE
	if awareness >= 90:
		return ResponseTier.SIGNIFICANTLY_MAPPED
	if awareness >= 70:
		return ResponseTier.PARTIALLY_MAPPED
	if awareness >= 50:
		return ResponseTier.CONFIRMED_THREAT
	if awareness >= RESPONSE_ACTIVE_THRESHOLD:
		return ResponseTier.SUSPICIOUS
	return ResponseTier.UNAWARE


# === WIN CONDITION ===========================================================

## Kolat win condition (s54.7i): the primary candidate (a) holds an Imperial-
## proximity role, (b) has held it for one full IC year without discovery, and
## (c) imperial_awareness_level is below 70. `installed_ic_day` is the day the
## candidate took the position (-1 = not installed). Pure check — no mutation.
static func check_win_condition(
	candidate: L5RCharacterData,
	installed_ic_day: int,
	current_ic_day: int,
	imperial_awareness_level: int,
) -> bool:
	if candidate == null or CharacterStats.is_dead(candidate):
		return false
	if candidate.role_position not in IMPERIAL_PROXIMITY_ROLES:
		return false
	if installed_ic_day < 0:
		return false
	if current_ic_day - installed_ic_day < WIN_HOLD_DAYS:
		return false
	if imperial_awareness_level >= WIN_AWARENESS_CEILING:
		return false
	# Discovery is expressed through the candidate's pipeline stage (s54.7i):
	# a "compromised" candidate has had their affiliation discovered.
	if String(candidate.special_data.get("kolat_candidate_pipeline_stage", "")) == "compromised":
		return false
	return true
