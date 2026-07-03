class_name SailingSystem
## Captains, passage, and voyage logic (GDD s57.42 / s57.43, locked s57.42a).
## Pure simulation class — no Node inheritance. Covers captain Sailing
## requirements, captain succession, REQUEST_PASSAGE acceptance, embarkation,
## and the pirate-interception / shipwreck-drift formulas. The ship ASCII Lesser
## Zone, AT_SHIP action availability, and voyage-event resolution are deferred
## to the UI / NPC-engine layers.

# Minimum Sailing rank to legitimately captain each ship class (s57.42.3).
# Small coastal/river = 1, oceangoing merchant = 3, heavy warship = 4.
# TORTOISE_OCEANGOING = 3 (oceangoing bucket) — PROVISIONAL (s57.42.3 silent).
const MIN_SAILING_BY_CLASS: Dictionary = {
	Enums.ShipClass.SAMPAN: 1,
	Enums.ShipClass.MERCHANT_BARGE: 1,
	Enums.ShipClass.KOBUNE: 1,
	Enums.ShipClass.SENGOKOBUNE: 3,
	Enums.ShipClass.KOUTETSUKAN: 4,
	Enums.ShipClass.ATAKEBUNE: 4,
	Enums.ShipClass.TORTOISE_OCEANGOING: 3,
}

# Owner self-captaining below the class requirement: −2k0 on Sailing rolls (s57.42.3).
const UNDERQUALIFIED_ROLLED_PENALTY: int = -2

# REQUEST_PASSAGE: Category 11, 0 AP, throttle 2 per IC day (s57.42.6).
const MAX_REQUESTS_PER_DAY: int = 2
# A refused requester may try the same captain again only after 1 IC day (s57.42.7).
const REFUSAL_COOLDOWN_DAYS: int = 1
# Owner-granted passage creates a 3-point Obligation on the requester (s57.42.7).
const OWNER_PASSAGE_OBLIGATION_POINTS: int = 3

# Acceptance personality leans (s57.42.7).
const LEAN_JIN: int = 5       # Compassion — struggling travelers
const LEAN_SEIGYO: int = 3    # Control — proper koku offered
const LEAN_REI: int = 2       # Courtesy — high-Status or polite requests
# Disposition at/above this is the baseline for free passage (Acquaintance+, s57.42.7).
const FREE_PASSAGE_DISPOSITION: int = 11
# Status at/above which Rei's courtesy lean applies (high-Status request).
const HIGH_STATUS_THRESHOLD: float = 4.0

# Pirate interception chance = Strength × 10% per ship passing (s57.43.7).
const PIRATE_INTERCEPTION_PER_STRENGTH: float = 0.10
# Shipwreck drift landfall/rescue chance by drift day (s57.43.6).
const DRIFT_LANDFALL_CHANCE: Array[float] = [0.0, 0.10, 0.25, 0.40, 0.60]
const DRIFT_LANDFALL_CAP: float = 0.60
const DRIFT_MANTIS_DAY1: float = 0.30
const DRIFT_CEILING_DAYS: int = 6
# Open-ocean Swimming roll each drift day (s57.43.6): Athletics (Swimming) + Strength
# vs TN 25; a non-swimmer (no Athletics rank) suffers +10 TN ("they cannot swim").
const DRIFT_SWIM_TN: int = 25
const DRIFT_NON_SWIMMER_PENALTY: int = 10


# === CAPTAIN REQUIREMENTS (s57.42.3) =========================================

static func min_sailing_for_class(ship_class: int) -> int:
	return MIN_SAILING_BY_CLASS.get(ship_class, 1)


static func _sailing_rank(character: L5RCharacterData) -> int:
	return character.skills.get("Sailing", 0)


## True if `captain` meets the Sailing minimum to legitimately command `ship_class`.
static func captain_meets_requirement(captain: L5RCharacterData, ship_class: int) -> bool:
	return _sailing_rank(captain) >= min_sailing_for_class(ship_class)


## Rolled-dice penalty a character suffers captaining a ship above their Sailing
## (owner self-captaining under-qualified): −2k0, else 0 (s57.42.3).
static func self_captain_penalty(captain: L5RCharacterData, ship_class: int) -> int:
	return 0 if captain_meets_requirement(captain, ship_class) else UNDERQUALIFIED_ROLLED_PENALTY


# === CAPTAIN SUCCESSION (s57.42.5) ===========================================

## Pick the acting captain when the captain is incapacitated at sea: the living
## crew member with the highest Sailing (tiebreak Insight, then Status). Returns
## the character_id, or -1 if no crew member has any Sailing rank (catastrophic
## peril — the caller rolls the incident check). `crew` is an Array of
## L5RCharacterData (the captain should be excluded by the caller).
static func select_acting_captain(crew: Array) -> int:
	var best_id: int = -1
	var best_sailing: int = 0
	var best_insight: int = -1
	var best_status: float = -1.0
	for c: L5RCharacterData in crew:
		if c == null or CharacterStats.is_dead(c):
			continue
		var s: int = _sailing_rank(c)
		if s <= 0:
			continue
		var ins: int = CharacterStats.get_insight_rank(c)
		var better: bool = false
		if s > best_sailing:
			better = true
		elif s == best_sailing:
			if ins > best_insight:
				better = true
			elif ins == best_insight and c.status > best_status:
				better = true
		if better:
			best_id = c.character_id
			best_sailing = s
			best_insight = ins
			best_status = c.status
	return best_id


# === REQUEST_PASSAGE ACCEPTANCE (s57.42.6–7) =================================

## Evaluate a REQUEST_PASSAGE. The decider is the captain or, for owner-override,
## the owner. Inputs:
##   disposition       — decider's disposition toward the requester
##   koku_offered      — compensation offered (>= 0)
##   schedule_compatible — ship plausibly travels toward/via the destination
##   standing_orders_refuse — owner-set hard refusal (e.g. "no Scorpion")
##   requester_status  — for Rei courtesy lean
##   polite            — request framed politely (Rei lean)
## Returns { accepted: bool, reason: String }. Standing orders are a hard refuse;
## an incompatible schedule is a hard refuse (captains make no special trips).
## Otherwise: free passage at Acquaintance+; below that, koku must be offered;
## personality leans (Jin/Seigyo/Rei) tip marginal cases.
static func evaluate_passage_request(
	decider: L5RCharacterData,
	disposition: int,
	koku_offered: float,
	schedule_compatible: bool,
	standing_orders_refuse: bool,
	requester_status: float = 1.0,
	polite: bool = false,
) -> Dictionary:
	if standing_orders_refuse:
		return {"accepted": false, "reason": "standing_orders"}
	if not schedule_compatible:
		return {"accepted": false, "reason": "schedule_incompatible"}

	var lean: int = _personality_lean(decider, koku_offered, requester_status, polite)

	# Acquaintance or higher → free passage (a polite refusal is still possible
	# only via standing orders / schedule, already handled).
	if disposition >= FREE_PASSAGE_DISPOSITION:
		return {"accepted": true, "reason": "disposition"}

	# Below Acquaintance: compensation must overcome the gap. Each lean point is
	# worth ~1 koku of goodwill; require koku + lean to bridge to the threshold.
	var gap: int = FREE_PASSAGE_DISPOSITION - disposition
	var effective: float = koku_offered + float(lean)
	if effective >= float(gap):
		return {"accepted": true, "reason": "compensation"}
	return {"accepted": false, "reason": "insufficient_offer"}


## Sum of acceptance personality leans for a decider (s57.42.7).
static func _personality_lean(
	decider: L5RCharacterData,
	koku_offered: float,
	requester_status: float,
	polite: bool,
) -> int:
	var lean: int = 0
	if decider.bushido_virtue == Enums.BushidoVirtue.JIN:
		lean += LEAN_JIN
	if decider.shourido_virtue == Enums.ShouridoVirtue.SEIGYO and koku_offered > 0.0:
		lean += LEAN_SEIGYO
	if decider.bushido_virtue == Enums.BushidoVirtue.REI \
			and (requester_status >= HIGH_STATUS_THRESHOLD or polite):
		lean += LEAN_REI
	return lean


## Disposition shift applied to the requester on a refusal (s57.42.7): none for a
## polite refusal, −1..−3 for a rude one (caller supplies the rude magnitude).
static func refusal_disposition_shift(rude: bool, rude_magnitude: int = 0) -> int:
	if not rude:
		return 0
	return -clampi(rude_magnitude, 1, 3)


# === THROTTLE / COOLDOWN (s57.42.6–7) ========================================

## True if the requester may fire REQUEST_PASSAGE now: under the daily throttle
## and past any per-captain refusal cooldown. requests_today is how many they
## have already made this IC day; last_refused_day is the IC day this captain
## last refused them (-1 = never).
static func can_request_passage(
	requests_today: int,
	current_ic_day: int,
	last_refused_day: int,
) -> bool:
	if requests_today >= MAX_REQUESTS_PER_DAY:
		return false
	if last_refused_day >= 0 and (current_ic_day - last_refused_day) < REFUSAL_COOLDOWN_DAYS:
		return false
	return true


# === DEPARTURE / EMBARKATION (s57.42.7–8) ====================================

## Fire a ship's departure: set aboard_ship_id on each accepted passenger who is
## co-located in the port settlement at departure_tick; leave the others behind
## (aboard_ship_id stays -1). `accepted` is an Array of L5RCharacterData; the
## port settlement id is a String (physical_location). Returns the boarded ids.
static func board_passengers(ship: ShipData, accepted: Array, port_settlement: String) -> Array:
	var boarded: Array = []
	for p: L5RCharacterData in accepted:
		if p == null or CharacterStats.is_dead(p):
			continue
		if p.physical_location == port_settlement:
			p.aboard_ship_id = ship.ship_id
			boarded.append(p.character_id)
	return boarded


## Disembark a passenger when the ship reaches its destination port: clear
## aboard_ship_id and place them in the destination province.
static func disembark(passenger: L5RCharacterData, destination_settlement: String) -> void:
	passenger.aboard_ship_id = -1
	passenger.physical_location = destination_settlement


# === s57.43 VOYAGE FORMULAS ==================================================

## Pirate-fleet interception chance for one ship passing a sub-tile (s57.43.7).
static func pirate_interception_chance(fleet_strength: int) -> float:
	return clampf(float(maxi(0, fleet_strength)) * PIRATE_INTERCEPTION_PER_STRENGTH, 0.0, 1.0)


## A Strength 4+ pirate fleet triggers a Naval Mass Battle; 1–3 a Deck Skirmish
## (s57.43.7). Returns "naval_mass_battle" / "deck_skirmish" / "none".
static func interception_resolution(fleet_strength: int) -> String:
	if fleet_strength <= 0:
		return "none"
	return "naval_mass_battle" if fleet_strength >= 4 else "deck_skirmish"


## Landfall/rescue chance for a shipwreck-drift character on a given drift day
## (s57.43.6). Day 1 = 10% (30% in Mantis waters), 2 = 25%, 3 = 40%, 4+ = 60%.
## Beyond the 6-day ceiling the character is lost (returns 0.0 → caller resolves
## death at sea).
static func shipwreck_landfall_chance(drift_day: int, in_mantis_waters: bool = false) -> float:
	if drift_day < 1 or drift_day > DRIFT_CEILING_DAYS:
		return 0.0
	if drift_day == 1 and in_mantis_waters:
		return DRIFT_MANTIS_DAY1
	if drift_day < DRIFT_LANDFALL_CHANCE.size():
		return DRIFT_LANDFALL_CHANCE[drift_day]
	return DRIFT_LANDFALL_CAP


## Open-ocean Swimming TN for a drifting character (s57.43.6): base 25, +10 for a
## non-swimmer (Athletics rank 0 — without Athletics rank/Swimming emphasis "they
## cannot swim").
static func drift_swim_tn(character: L5RCharacterData) -> int:
	var athletics: int = int(character.skills.get("Athletics", 0))
	return DRIFT_SWIM_TN + (DRIFT_NON_SWIMMER_PENALTY if athletics <= 0 else 0)
