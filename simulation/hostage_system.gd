class_name HostageSystem
## Hostage System (Hitojichi) per GDD s22.9.
## Honored guests held as political leverage. Released through court negotiation.


# -- Constants ----------------------------------------------------------------

enum CaptureSource {
	SIEGE_SURRENDER,
	BATTLE_CAPTURE,
}

const ESCAPE_TN_BY_SETTLEMENT: Dictionary = {
	"town": 20,
	"castle": 25,
	"major_castle": 30,
}

const ESCAPE_TN_PER_HALF_PU: int = 2
const ESCAPE_CRITICAL_MARGIN: int = 10
const ESCAPE_MIN_STEALTH: int = 3

const HARMED_HOSTAGE_HONOR_LOSS: float = 0.0
const ESCAPE_FAMILY_HONOR_LOSS: float = 0.0
const ESCAPE_CRITICAL_FAMILY_HONOR_LOSS: float = 0.0

const LEVERAGE_RANK3: int = 3
const LEVERAGE_RANK5: int = 8


# -- Capture ------------------------------------------------------------------

static func capture_hostage(
	character_id: int,
	captor_id: int,
	source: CaptureSource,
	settlement_id: String,
	current_ic_day: int,
) -> Dictionary:
	return {
		"character_id": character_id,
		"captor_id": captor_id,
		"source": source,
		"settlement_id": settlement_id,
		"captured_ic_day": current_ic_day,
		"released": false,
		"released_ic_day": -1,
		"escaped": false,
	}


# -- Personality Gates --------------------------------------------------------

static func can_attempt_escape(
	bushido_virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
	school_type: Enums.SchoolType,
	stealth_rank: int,
	committed_to_endure: bool = false,
) -> bool:
	if bushido_virtue == Enums.BushidoVirtue.YU:
		return false
	if shourido_virtue == Enums.ShouridoVirtue.ISHI and committed_to_endure:
		return false
	if school_type != Enums.SchoolType.BUSHI:
		return false
	if stealth_rank < ESCAPE_MIN_STEALTH:
		return false
	return true


static func get_capture_likelihood_modifier(
	bushido_virtue: Enums.BushidoVirtue,
	shourido_virtue: Enums.ShouridoVirtue,
) -> float:
	if bushido_virtue == Enums.BushidoVirtue.YU:
		return 0.0
	if shourido_virtue == Enums.ShouridoVirtue.ISHI:
		return 0.0
	return 1.0


# -- Escape Resolution -------------------------------------------------------

static func get_escape_tn(settlement_type: String, garrison_pu: float, base_garrison_pu: float) -> int:
	var base_tn: int = ESCAPE_TN_BY_SETTLEMENT.get(settlement_type, 25)
	var excess_pu: float = max(0.0, garrison_pu - base_garrison_pu)
	var bonus: int = int(excess_pu / 0.5) * ESCAPE_TN_PER_HALF_PU
	return base_tn + bonus


static func resolve_escape(roll_total: int, tn: int) -> Dictionary:
	if roll_total >= tn:
		return {
			"success": true,
			"executed": false,
			"critical_failure": false,
			"family_honor_loss": ESCAPE_FAMILY_HONOR_LOSS,
			"historical_modifier": "hostage_escape",
		}
	elif (tn - roll_total) >= ESCAPE_CRITICAL_MARGIN:
		return {
			"success": false,
			"executed": true,
			"critical_failure": true,
			"family_honor_loss": ESCAPE_CRITICAL_FAMILY_HONOR_LOSS,
		}
	else:
		return {
			"success": false,
			"executed": true,
			"critical_failure": false,
			"family_honor_loss": ESCAPE_FAMILY_HONOR_LOSS,
		}


# -- Leverage -----------------------------------------------------------------

static func get_leverage_value(insight_rank: int, is_champion_family: bool) -> int:
	if is_champion_family or insight_rank >= 5:
		return LEVERAGE_RANK5
	elif insight_rank >= 3:
		return LEVERAGE_RANK3
	return 1


# -- Release ------------------------------------------------------------------

static func release_hostage(hostage_record: Dictionary, current_ic_day: int) -> Dictionary:
	hostage_record["released"] = true
	hostage_record["released_ic_day"] = current_ic_day
	return {
		"character_id": hostage_record["character_id"],
		"released_ic_day": current_ic_day,
	}


# -- Hostage Restrictions -----------------------------------------------------

static func is_action_blocked_for_hostage(action_id: String, targets_captor: bool) -> bool:
	if targets_captor:
		return true
	var blocked_actions: Array = [
		"TRAVEL_TO", "ORDER_BATTLE", "CONDUCT_RAID",
		"LEVY_TROOPS", "DECLARE_WAR",
	]
	return action_id in blocked_actions


# -- Harm Consequences --------------------------------------------------------

static func harm_hostage_consequences() -> Dictionary:
	return {
		"honor_loss": HARMED_HOSTAGE_HONOR_LOSS,
		"historical_modifier": "harmed_hostage",
	}
