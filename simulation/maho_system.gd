class_name MahoSystem
## Maho (blood magic) casting costs and consequences per GDD s43 and s57.47.7.
## Handles: taint gain, at-act honor loss, PTL increment, crime record creation.
## Does NOT resolve the spell effect or compute a cast roll TN —
## the GDD (s43) specifies those are caller responsibilities.


# -- Blood Cost Helpers -------------------------------------------------------

## Minimum blood required to cast (per GDD s43: 2 × Mastery Level).
static func base_blood_cost(mastery_level: int) -> int:
	return mastery_level * 2


## Additional blood needed to purchase a given number of Raises beyond the base
## cast (per GDD s43: one Raise per additional 2 × ML increment).
static func raise_blood_cost(mastery_level: int, raises: int) -> int:
	return mastery_level * 2 * raises


## Total blood cost for the cast including purchased Raises.
static func total_blood_cost(mastery_level: int, raises: int) -> int:
	return base_blood_cost(mastery_level) + raise_blood_cost(mastery_level, raises)


# -- Taint Cost ---------------------------------------------------------------

## Taint Points gained by the caster per s43: ML − 1, minimum 1.
static func taint_gain(mastery_level: int) -> int:
	return max(1, mastery_level - 1)


# -- Core Resolution ----------------------------------------------------------

## Apply all GDD-specified costs and consequences for casting a maho spell.
##
## Parameters:
##   caster        — the maho-tsukai
##   province      — province where the casting occurred (PTL is incremented)
##   mastery_level — the spell's Mastery Level (1–6)
##   raises_purchased — number of extra blood increments beyond base cost
##                      caller already validated blood availability
##   next_case_id  — world-level case ID for the new CrimeRecord
##   ic_day        — current IC day
##   location      — province/zone string for the CrimeRecord
##   witnesses     — character IDs present who observed the act (may be empty)
##
## Returns a dict with:
##   taint_gained    : int    — Taint Points added to caster.taint
##   honor_delta     : float  — Honor change from at-act consequences
##   ptl_delta       : float  — PTL change applied to province
##   raises_available: int    — Raises the caller may spend on spell effects
##   crime_record    : CrimeRecord — the newly created record (caller must store it)
static func resolve_cast(
	caster: L5RCharacterData,
	province: ProvinceData,
	mastery_level: int,
	raises_purchased: int,
	next_case_id: int,
	ic_day: int,
	location: String,
	witnesses: Array[int] = [],
) -> Dictionary:
	# 1. Taint gain (s43)
	var gain: int = taint_gain(mastery_level)
	caster.taint += float(gain)

	# 2. At-act Honor loss (s57.47.7 → Table 2.3 "blasphemous")
	var at_act: Dictionary = CrimeSystem.apply_at_act_consequences(
		caster, Enums.CrimeType.MAHO
	)

	# 3. PTL increment (project rule: any maho use raises PTL whether detected or not)
	province.province_taint_level += PTL_PER_CAST

	# 4. Crime record (s57.47.7 — Capital, CrimeType.MAHO, seppuku never offered)
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		next_case_id,
		Enums.CrimeType.MAHO,
		caster.character_id,
		location,
		ic_day,
		-1,
		0,
		witnesses,
	)

	return {
		"taint_gained":     gain,
		"honor_delta":      at_act.get("honor_delta", 0.0),
		"ptl_delta":        PTL_PER_CAST,
		"raises_available": raises_purchased,
		"crime_record":     record,
	}


# -- Constants ----------------------------------------------------------------

## PTL increment per maho cast. Any maho use raises PTL regardless of detection
## per the project rule established in CLAUDE.md Hard Constraints and s57.47.7.
const PTL_PER_CAST: float = 1.0
