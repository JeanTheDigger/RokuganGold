class_name TeaCeremonySystem
## Social Void recovery ceremony per GDD s57.37.
## Host spends 1 AP; up to 4 eligible guests recover VP for free.
## Zone requirement: tokonoma == true OR shrine_eligible == true.


# -- Constants (s57.37.2 and s57.37.4) -----------------------------------------

const BASE_TN: int = 15
const TN_PER_EXTRA_PARTICIPANT: int = 5
const MASTERY_RANK5: int = 5
const VP_BASE_RECOVERY: int = 1
const VP_MASTERY_RECOVERY: int = 2
const PARTICIPANT_CAP: int = 5  # host + up to 4 guests

# Acquaintance threshold (>= 11) per action_executor disposition tiers
const MIN_DISPOSITION: int = 11

# Average single die result for exploding d10 (used for 50% threshold estimate)
const L5R_DIE_AVG: float = 5.7


# -- Public API ----------------------------------------------------------------

static func get_tn(participant_count: int) -> int:
	return BASE_TN + TN_PER_EXTRA_PARTICIPANT * maxi(0, participant_count - 2)


static func max_viable_count(void_ring: int, tea_rank: int) -> int:
	## Returns max total participant count (including host) the host can attempt
	## at roughly >= 50% success probability.
	var avg: float = float(void_ring) * L5R_DIE_AVG
	for count: int in range(PARTICIPANT_CAP, 0, -1):
		if float(get_tn(count)) <= avg:
			return count
	return 1


static func select_eligible_ids(
	host_id: int,
	chars_present: Array[int],
	dispositions: Dictionary,
) -> Array[int]:
	## Returns IDs of characters eligible to participate (disp >= Acquaintance,
	## not the host). Does NOT check VP deficit — that check runs at execution.
	var result: Array[int] = []
	for char_id: int in chars_present:
		if char_id == host_id:
			continue
		var disp: int = dispositions.get(char_id, 0)
		if disp >= MIN_DISPOSITION:
			result.append(char_id)
	return result


static func zone_allows_ceremony(zone_flags: Dictionary) -> bool:
	return zone_flags.get("tokonoma", false) or zone_flags.get("shrine_eligible", false)
