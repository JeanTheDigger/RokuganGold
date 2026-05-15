class_name MahoSystem
## Maho (blood magic) casting costs and consequences per GDD s43 and s57.47.7.
##
## Maho requires no casting roll. The spell fires automatically when blood is
## spilled. The blood cost equals the wounds inflicted on the blood source
## (caster or willing/helpless victim), bypassing armor reduction.
## Extra blood purchases Raises: 1 Raise per additional 2×ML wound increment.
##
## Handles: wound application to blood source, taint gain, at-act honor loss,
## PTL increment, and crime record creation.


# -- Blood Cost Helpers -------------------------------------------------------

## Minimum wounds required to cast (per GDD s43: 2 × Mastery Level).
static func base_blood_cost(mastery_level: int) -> int:
	return mastery_level * 2


## Additional wounds needed to purchase a given number of Raises
## (per GDD s43: one Raise per additional 2 × ML increment).
static func raise_blood_cost(mastery_level: int, raises: int) -> int:
	return mastery_level * 2 * raises


## Total wounds inflicted on the blood source for this cast.
static func total_blood_cost(mastery_level: int, raises: int) -> int:
	return base_blood_cost(mastery_level) + raise_blood_cost(mastery_level, raises)


# -- Taint Cost ---------------------------------------------------------------

## Taint Points gained by the caster per s43: ML − 1, minimum 1.
static func taint_gain(mastery_level: int) -> int:
	return max(1, mastery_level - 1)


# -- Core Resolution ----------------------------------------------------------

## Apply all GDD-specified costs and consequences for casting a maho spell.
## The spell fires automatically — no casting roll is required.
##
## Parameters:
##   caster         — the maho-tsukai (always gains Taint and Honor loss)
##   blood_source   — the character whose blood is spilled; may be the caster
##                    or another (willing/helpless) character (per GDD s43)
##   province       — province where the casting occurred (PTL is incremented)
##   mastery_level  — the spell's Mastery Level (1–6)
##   raises_purchased — number of extra blood increments beyond the base cost;
##                      each costs an additional 2×ML wounds to blood_source
##   dice_engine    — for the blood evidence concealment roll (Stealth/Agility)
##   next_case_id   — world-level case ID for the new CrimeRecord
##   ic_day         — current IC day
##   location       — province/zone string for the CrimeRecord
##   witnesses      — character IDs present who observed the act (may be empty)
##
## Returns a dict with:
##   blood_wounds         : int    — total wounds inflicted on blood_source
##   blood_source_died    : bool   — true if blood_source reached Dead wound level
##   taint_gained         : int    — Taint Points added to caster.taint
##   honor_delta          : float  — Honor change from at-act consequences
##   ptl_delta            : float  — PTL change applied to province
##   raises_available     : int    — Raises the caller may spend on spell effects
##   blood_concealment_tn : int    — concealment_tn for blood evidence at site
##   crime_record         : CrimeRecord — newly created record (caller must store)
static func resolve_cast(
	caster: L5RCharacterData,
	blood_source: L5RCharacterData,
	province: ProvinceData,
	mastery_level: int,
	raises_purchased: int,
	dice_engine: DiceEngine,
	next_case_id: int,
	ic_day: int,
	location: String,
	witnesses: Array[int] = [],
) -> Dictionary:
	# 1. Apply wounds to blood source — bypasses armor (deliberate blood-letting)
	var blood_wounds: int = total_blood_cost(mastery_level, raises_purchased)
	var wound_result: Dictionary = WoundSystem.apply_damage(blood_source, blood_wounds, 0)

	# 2. Taint gain for caster (s43)
	var gain: int = taint_gain(mastery_level)
	caster.taint += float(gain)

	# 3. At-act Honor loss (s57.47.7 → Table 2.3 "blasphemous")
	var at_act: Dictionary = CrimeSystem.apply_at_act_consequences(
		caster, Enums.CrimeType.MAHO
	)

	# 4. PTL increment (project rule: any maho use raises PTL whether detected)
	province.province_taint_level += PTL_PER_CAST

	# 5. Blood evidence concealment roll — Stealth/Agility per CLAUDE.md Decision 5
	#    Pattern mirrors poison residue (s57.48.8): minimum result 5.
	var stealth_rank: int = caster.skills.get("Stealth", 0)
	var concealment_result: Dictionary = dice_engine.roll_skill_check(
		caster.agility, stealth_rank, 0
	)
	var blood_concealment_tn: int = maxi(5, concealment_result["total"])

	# 6. Crime record — concealment_tn carried here until zone_event_log is built
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		next_case_id,
		Enums.CrimeType.MAHO,
		caster.character_id,
		location,
		ic_day,
		-1,
		blood_concealment_tn,
		witnesses,
	)

	return {
		"blood_wounds":         blood_wounds,
		"blood_source_died":    wound_result.get("is_dead", false),
		"taint_gained":         gain,
		"honor_delta":          at_act.get("honor_delta", 0.0),
		"ptl_delta":            PTL_PER_CAST,
		"raises_available":     raises_purchased,
		"blood_concealment_tn": blood_concealment_tn,
		"crime_record":         record,
	}


# -- Constants ----------------------------------------------------------------

## PTL increment per maho cast. Any maho use raises PTL regardless of detection
## per the project rule established in CLAUDE.md Hard Constraints and s57.47.7.
const PTL_PER_CAST: float = 1.0
