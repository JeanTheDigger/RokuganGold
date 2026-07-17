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


# === WORLD-STATE BUNDLE ======================================================
# All Kolat endgame world-state lives in one mutable Dictionary passed by
# reference into the orchestrator. This is the authoritative record — Tiger's
# special_data candidate fields (s54.7i) are a courtesy mirror so the pipeline
# survives Tiger's death (a freshly-seated Tiger inherits the bundle, not the
# dead Master's sheet). Keys:
#   exposure (int 0–100), awareness (int 0–100), response_active (bool),
#   identified_ids (Array[int] — Imperial-known Kolat member ids),
#   candidate_id (int, -1 = none), backup_ids (Array[int]),
#   pipeline_stage (String), installed_ic_day (int, -1 = not installed),
#   victory_ic_day (int, -1 = win not yet fired).

## Build a fresh, fully-defaulted bundle (world generation / first load).
static func new_bundle() -> Dictionary:
	return {
		"exposure": 0,
		"awareness": 0,
		"response_active": false,
		"identified_ids": [],
		"candidate_id": -1,
		"backup_ids": [],
		"pipeline_stage": "",
		"installed_ic_day": -1,
		"victory_ic_day": -1,
		# Case ids already counted toward awareness (dedup, s54.7i +5 per operative).
		"awareness_cases": [],
		# Tier-90 emergency: identified members suspend operations and go dark.
		"go_dark": false,
		# Tier-100 catastrophic purge fired once (no re-fire; a new generation reseeds).
		"purge_done": false,
		# Tier-50 Tiger "degrade Imperial task force" priority added once.
		"task_force_flagged": false,
	}


## Ensure every key exists (heals a partial bundle loaded from an older save).
static func ensure_bundle(b: Dictionary) -> void:
	var defaults: Dictionary = new_bundle()
	for k: String in defaults:
		if not b.has(k):
			b[k] = defaults[k]


## Add `delta` to a bundle scalar ("exposure" / "awareness"), clamped 0–100.
static func bump(b: Dictionary, key: String, delta: int) -> void:
	b[key] = apply_delta(int(b.get(key, 0)), delta)


## Whether the Empire has identified this character as a Kolat member.
static func is_identified(b: Dictionary, character_id: int) -> bool:
	return character_id in (b.get("identified_ids", []) as Array)


## Record that the Empire has identified a Kolat member (dedup). Identifying a
## Master or senior operative is what the tier-90/100 purge acts on (s54.7i).
static func identify(b: Dictionary, character_id: int) -> void:
	if character_id < 0:
		return
	var ids: Array = b.get("identified_ids", [])
	if character_id not in ids:
		ids.append(character_id)
	b["identified_ids"] = ids


# === CANDIDATE SCORING (s54.7i) ==============================================
# Structural, no invented numbers: a candidate for the Regent/Advisor seat is
# scored on the levers that actually decide an Imperial court appointment —
# court standing (Status), court competence (Courtier + Etiquette), and
# proximity to the Imperial capital (already at the seat of appointment).
# A conscious Kolat member or an installed Dream sleeper is required (s54.7i:
# "a conscious Kolat member or a Dream sleeper with an appropriate command").

## True if the character is a usable candidate vehicle (conscious agent or sleeper).
static func is_candidate_eligible(c: L5RCharacterData) -> bool:
	if c == null or CharacterStats.is_dead(c) or c.is_pc:
		return false
	if c.kolat_sect != Enums.KolatSect.NONE:
		return true
	# A Dream sleeper carries an installed trigger phrase (s54.7e).
	return String(c.trigger_phrase) != ""


## Court-appointment score for a candidate. `at_capital` adds the proximity
## weight the real appointment scorer also rewards.
static func candidate_score(c: L5RCharacterData, at_capital: bool) -> float:
	var court: float = float(c.skills.get("Courtier", 0)) + float(c.skills.get("Etiquette", 0))
	var score: float = c.status * 3.0 + court
	if at_capital:
		score += 5.0
	return score
