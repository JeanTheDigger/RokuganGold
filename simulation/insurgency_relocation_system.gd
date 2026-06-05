class_name InsurgencyRelocationSystem
## s56.13 Relocation Mechanics --- LOCKED
## Handles insurgency relocation when a player mission compromises the position.
## Pure simulation — no map tiles.

# -- Mission outcome classification (s56.13.1) ---------------------------------

enum MissionOutcome {
	FULL_SUCCESS    = 0,  # Always triggers relocation if survivors remain.
	PARTIAL_SUCCESS = 1,  # Player reached objective space — triggers relocation.
	RETREAT_INSIDE  = 2,  # Player spotted inside objective space — triggers relocation.
	RETREAT_OUTSIDE = 3,  # Player never reached objective space — no relocation.
	FAILURE         = 4,  # Defenders held — no relocation.
}

# -- Template-specific constants (s56.13.2) ------------------------------------

const STOCKADE_DELAY_SEASONS: int = 1  # Makeshift Stockade: delays same-province relocation 1 season.
const STOCKADE_TEMPLATE: String = "MakeshiftStockadeMapData"
const RUIN_TEMPLATE: String = "RuinedStructureMapData"

# -- Adjacent relocation probability (s56.13.2) --------------------------------
# "Exact probability values pending playtest."
# Returns 0.0 until playtest data is available — always same-province by default.
static func adjacent_relocation_chance(_missions_conducted: int) -> float:
	return 0.0  # PROVISIONAL: pending playtest per s56.13.2

# -- Trigger check (s56.13.1) --------------------------------------------------

static func triggers_relocation(outcome: int) -> bool:
	return outcome == MissionOutcome.FULL_SUCCESS \
		or outcome == MissionOutcome.PARTIAL_SUCCESS \
		or outcome == MissionOutcome.RETREAT_INSIDE

# -- Province ruin check (s56.13.2) --------------------------------------------
# Ruined Structure template can only reappear if another ruin exists in the province.
# province_history: Array of String event type tags on the province.
# Returns true if at least one ruin-producing event tag is present.
static func province_has_ruin(province_history: Array) -> bool:
	for tag in province_history:
		var t: String = str(tag)
		if t == "war_damage" or t == "famine" or t == "taint_corruption" \
				or t == "peasant_revolt" or t == "natural_decay":
			return true
	return false

# -- Roster attrition on relocation (s56.13.3) ---------------------------------
# "Only Bandit Rabble attrite during the move."
# Attrition formula PROVISIONAL: GDD specifies Bandit Rabble peel off
# proportional to destination Stability. Returns strength reduction.
# dest_stability: 0–100 int.
static func compute_rabble_attrition(_strength: int, _dest_stability: int) -> int:
	return 0  # PROVISIONAL: formula not specified in GDD s56.13.3

# -- Main relocation handler (s56.13.1, s56.13.2) ------------------------------
# Returns a result dict describing the relocation decision.
# Does NOT mutate insurgency — caller applies the dict.
#
# Parameters:
#   insurgency      — InsurgencyData
#   outcome         — MissionOutcome int
#   kills           — int: enemies killed in mission
#   template_used   — String: class_name of the map template used
#   same_province   — bool: caller decision (based on adjacent_relocation_chance)
#   dest_province   — ProvinceData or null (only used when same_province=false)
#
# Returns dict keys:
#   "triggers"            bool
#   "same_province"       bool
#   "delay_seasons"       int  (>0 when Stockade delay applies)
#   "strength_after"      int
#   "rabble_attrition"    int  (PROVISIONAL=0)
#   "template_restricted" bool  (Ruined Structure restriction; caller checks separately)
#   "reset_province"      bool  (true when province changes — caller resets missions_conducted)
static func evaluate_relocation(
		insurgency: InsurgencyData,
		outcome: int,
		kills: int,
		template_used: String,
		same_province: bool,
		dest_province_history: Array
) -> Dictionary:
	var result: Dictionary = {
		"triggers": false,
		"same_province": same_province,
		"delay_seasons": 0,
		"strength_after": insurgency.strength,
		"rabble_attrition": 0,
		"template_restricted": false,
		"reset_province": false,
	}

	if not triggers_relocation(outcome):
		return result

	var survivors: int = maxi(0, insurgency.strength - kills)
	if survivors == 0:
		result["strength_after"] = 0
		return result

	result["triggers"] = true

	result["strength_after"] = survivors

	# Makeshift Stockade: delay 1 season before relocation (same-province only).
	if template_used == STOCKADE_TEMPLATE and same_province:
		result["delay_seasons"] = STOCKADE_DELAY_SEASONS

	# Ruined Structure: restricted if no ruin in destination province.
	if template_used == RUIN_TEMPLATE and not province_has_ruin(dest_province_history):
		result["template_restricted"] = true

	# Adjacent relocation: reset missions counter when province changes.
	if not same_province:
		result["reset_province"] = true

	return result

# -- Apply adjacent province effects (s56.13.3) --------------------------------
# Generates the political consequence topic and computes roster changes.
# Returns dict:
#   "rabble_attrition"    int
#   "strength_transferred" int
#   "topic_tier"          int  (TopicData.Tier.TIER_4)
#   "topic_category"      String  ("POLITICAL")
#   "topic_title"         String
#   "topic_subject_clan"  String
static func apply_adjacent_effects(
		insurgency: InsurgencyData,
		kills: int,
		origin_clan: String,
		dest_clan: String,
		dest_stability: int
) -> Dictionary:
	var survivors: int = maxi(0, insurgency.strength - kills)
	var attrition: int = compute_rabble_attrition(survivors, dest_stability)
	var transferred: int = maxi(0, survivors - attrition)

	return {
		"rabble_attrition": attrition,
		"strength_transferred": transferred,
		"topic_tier": 3,          # TopicData.Tier.TIER_4 = 3
		"topic_category": "POLITICAL",
		"topic_title": "Bandits from " + origin_clan + " territory enter " + dest_clan + " lands",
		"topic_subject_clan": origin_clan,
	}

# -- Apply origin province recovery (s56.13.4) ---------------------------------
# Returns dict describing what the origin province regains.
#   "insurgency_stability_penalty_removed" bool
static func apply_origin_recovery(_insurgency: InsurgencyData) -> Dictionary:
	return {
		"insurgency_stability_penalty_removed": true,
	}
