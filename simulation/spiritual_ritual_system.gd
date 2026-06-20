class_name SpiritualRitualSystem
## s56.16.5b–5f Restoration Ritual — shared resolution mechanics. Pure simulation
## class (no Node). PC-only: NPCs never use the ASCII map, so there is no NPC
## auto-resolver here (the prior invented NPC resolver was removed 2026-05-26).
## This is the shugenja-side ritual math + resolution spectrum + overlay
## restoration; the bushi/threat-escalation/creature-combat side is a later
## tranche (s40 integration).
##
## All values LOCKED in s56.16 except the per-round ritual TN, which the GDD
## leaves as "vs ritual TN" with no number — owner-set to 15 (2026-06-16),
## matching the arrival diagnosis roll (the only ritual-adjacent TN in s56.16).

const RITUAL_TN: int = 15          # owner-set 2026-06-16 (flat; matches diagnosis)
const DIAGNOSIS_TN: int = 15       # s56.16.5c/5d — Perception + Lore: Theology
const THEOLOGY_SKILL: String = "Lore: Theology"
const CATASTROPHIC_AFFLICTION_TN: int = 20  # s56.16.5f post-resolution Willpower roll

## Ritual duration in rounds by severity (s56.16.5b, LOCKED).
const DURATION_BY_SEVERITY: Dictionary = {
	Enums.SpiritualSeverity.MILD: 10,
	Enums.SpiritualSeverity.MODERATE: 20,
	Enums.SpiritualSeverity.SEVERE: 30,
	Enums.SpiritualSeverity.CATASTROPHIC: 50,
}

## Realm → trait for the restoration approach roll (Lore: Theology + Trait), s56.16.5c.
const REALM_TRAIT: Dictionary = {
	Enums.SpiritRealm.GAKI_DO:    Enums.Trait.AWARENESS,
	Enums.SpiritRealm.TOSHIGOKU:  Enums.Trait.WILLPOWER,
	Enums.SpiritRealm.CHIKUSHUDO: Enums.Trait.PERCEPTION,
	Enums.SpiritRealm.SAKKAKU:    Enums.Trait.INTELLIGENCE,
	Enums.SpiritRealm.MEIDO:      Enums.Trait.AWARENESS,
	Enums.SpiritRealm.YUME_DO:    Enums.Trait.WILLPOWER,
}

## Imbalanced element → countering Ring (Lore: Theology + Ring), s56.16.5d.
## VOID → NONE sentinel = shugenja's choice (any Ring grounds Void).
const ELEMENT_COUNTER: Dictionary = {
	Enums.Ring.FIRE:  Enums.Ring.WATER,
	Enums.Ring.WATER: Enums.Ring.EARTH,
	Enums.Ring.EARTH: Enums.Ring.FIRE,
	Enums.Ring.AIR:   Enums.Ring.EARTH,
	Enums.Ring.VOID:  Enums.Ring.NONE,
}

enum Outcome { FULL_SUCCESS, PARTIAL, RETREAT, FAILURE }


# ── Setup rolls ───────────────────────────────────────────────────────────────

## Total rounds the full ritual takes for this event's severity (s56.16.5b).
static func duration_for(event: SpiritualInsurgencyData) -> int:
	return DURATION_BY_SEVERITY.get(event.severity, 10)


## Rounds still needed this mission = full duration minus already-banked progress.
static func rounds_remaining(event: SpiritualInsurgencyData) -> int:
	return maxi(0, duration_for(event) - event.ritual_rounds_completed)


## Arrival diagnosis (s56.16.5c/5d): Perception + Lore: Theology vs TN 15.
## Success tells the shugenja which realm/element is present (and the approach).
static func diagnose(shugenja: L5RCharacterData, dice: DiceEngine) -> bool:
	var r: Dictionary = SkillResolver.resolve_skill_check(
		shugenja, dice, THEOLOGY_SKILL, DIAGNOSIS_TN, 0, "", Enums.Trait.PERCEPTION)
	return r.get("success", false)


## The countering Ring for an elemental imbalance (s56.16.5d). VOID returns the
## caller's chosen_ring (any Ring grounds Void); NONE if none chosen.
static func counter_ring(element: int, chosen_ring: int = Enums.Ring.NONE) -> int:
	var c: int = ELEMENT_COUNTER.get(element, Enums.Ring.NONE)
	if element == Enums.Ring.VOID:
		return chosen_ring
	return c


# ── Per-round resolution ──────────────────────────────────────────────────────

## Resolves one ritual round for one shugenja. Returns {success, progress}.
## took_damage = the shugenja was hit this round → the round auto-fails with no
## progress (s56.16.5b interruption; previous progress is preserved by the caller).
## For elemental imbalances, chosen_ring selects the Void counter (ignored otherwise).
static func resolve_ritual_round(
		shugenja: L5RCharacterData,
		event: SpiritualInsurgencyData,
		dice: DiceEngine,
		took_damage: bool = false,
		chosen_ring: int = Enums.Ring.NONE) -> Dictionary:
	if took_damage:
		return {"success": false, "progress": 0}

	var success: bool
	if event.event_type == Enums.SpiritualEventType.ELEMENTAL_IMBALANCE:
		var ring: int = counter_ring(event.element, chosen_ring)
		if ring == Enums.Ring.NONE:
			# Wrong/undeclared counter → no progress (s56.16.5d).
			return {"success": false, "progress": 0}
		# Lore: Theology + Ring → roll (Ring + skill) keep Ring (core L5R skill+ring).
		var ring_val: int = SpellSystem.get_ring_value(shugenja, ring)
		var skill_rank: int = int(shugenja.skills.get(THEOLOGY_SKILL, 0))
		var roll: DiceResult = dice.roll_and_keep(ring_val + skill_rank, ring_val, true)
		success = roll.total >= RITUAL_TN
	else:
		var trait_used: int = REALM_TRAIT.get(event.realm, Enums.Trait.AWARENESS)
		var r: Dictionary = SkillResolver.resolve_skill_check(
			shugenja, dice, THEOLOGY_SKILL, RITUAL_TN, 0, "", trait_used)
		success = r.get("success", false)

	return {"success": success, "progress": 1 if success else 0}


## Summary simulator: runs up to `rounds_available` real-time rounds with the
## given shugenja, returning the rounds of PROGRESS achieved this mission. Each
## round every living shugenja contributes one resolve_ritual_round (multiple
## shugenja stack toward the same total, s56.16.5b). damage_rounds maps a
## shugenja index → an Array of round numbers on which that shugenja was hit
## (interruption). Stops early once the remaining needed rounds are met.
## The live ASCII turn loop will instead call resolve_ritual_round per round with
## real per-round damage; this is the headless/abstract path.
static func run_summary_ritual(
		shugenja_list: Array,
		event: SpiritualInsurgencyData,
		dice: DiceEngine,
		rounds_available: int,
		damage_rounds: Dictionary = {},
		chosen_ring: int = Enums.Ring.NONE) -> int:
	var needed: int = rounds_remaining(event)
	var progress: int = 0
	for round_idx in range(rounds_available):
		if progress >= needed:
			break
		for si in range(shugenja_list.size()):
			var sh = shugenja_list[si]
			if sh == null or CharacterStats.is_dead(sh):
				continue
			var hit: bool = damage_rounds.get(si, []).has(round_idx)
			var rr: Dictionary = resolve_ritual_round(sh, event, dice, hit, chosen_ring)
			progress += int(rr.get("progress", 0))
			if progress >= needed:
				break
	return progress


# ── Resolution spectrum (s56.16.5f) ───────────────────────────────────────────

## Classifies the mission outcome. cumulative_progress = banked + this mission.
## shugenja_alive = at least one ritual-capable shugenja survived.
static func classify_outcome(
		cumulative_progress: int,
		total_duration: int,
		shugenja_alive: bool) -> Outcome:
	if not shugenja_alive:
		return Outcome.FAILURE
	if cumulative_progress >= total_duration:
		return Outcome.FULL_SUCCESS
	if cumulative_progress * 2 > total_duration:   # more than half
		return Outcome.PARTIAL
	return Outcome.RETREAT


## Applies a resolved mission to the event (and the map overlay, if supplied).
## completed_this_mission = progress rounds achieved this mission. current_season
## = absolute TimeSystem season index (for the one-season retreat/failure spike).
## Returns {outcome, cumulative, resolution_type}. Mutates event (+ map palette).
##  FULL_SUCCESS : resolved; overlay fully reverts (heart-outward).
##  PARTIAL      : banks cumulative progress; overlay reverts proportionally.
##  RETREAT      : banks nothing; one-season intensity spike.
##  FAILURE      : banks nothing; one-season intensity spike (shugenja lost).
static func apply_resolution(
		event: SpiritualInsurgencyData,
		completed_this_mission: int,
		shugenja_alive: bool,
		map: AsciiMapData = null,
		current_season: int = -1) -> Dictionary:
	var total: int = duration_for(event)
	var cumulative: int = event.ritual_rounds_completed + maxi(0, completed_this_mission)
	var outcome: Outcome = classify_outcome(cumulative, total, shugenja_alive)

	match outcome:
		Outcome.FULL_SUCCESS:
			event.ritual_rounds_completed = total
			event.resolved = true
			event.resolution_type = "full_success"
			if map != null:
				SpiritualPalette.advance_restoration(map, 1.0)
		Outcome.PARTIAL:
			event.ritual_rounds_completed = cumulative
			event.resolution_type = "partial"
			if map != null and total > 0:
				SpiritualPalette.advance_restoration(map, float(cumulative) / float(total))
		Outcome.RETREAT:
			event.resolution_type = "retreat"
			if current_season >= 0:
				event.intensity_spike_until_season = current_season + 1
		Outcome.FAILURE:
			event.resolution_type = "failure"
			if current_season >= 0:
				event.intensity_spike_until_season = current_season + 1

	return {
		"outcome": outcome,
		"cumulative": cumulative,
		"resolution_type": event.resolution_type,
	}


## Post-resolution spiritual affliction check (s56.16.5f). Only Catastrophic
## severity forces it: Willpower vs TN 20, failure → a minor one-season affliction.
## Returns true when the character is afflicted (failed the roll). Pure — the
## affliction's mechanical attachment is the future encounter layer's concern.
static func post_resolution_affliction_check(
		character: L5RCharacterData,
		event: SpiritualInsurgencyData,
		dice: DiceEngine) -> bool:
	if event.severity != Enums.SpiritualSeverity.CATASTROPHIC:
		return false
	# Willpower roll keep Willpower vs TN 20.
	var wil: int = character.willpower
	var roll: DiceResult = dice.roll_and_keep(wil, wil, true)
	return roll.total < CATASTROPHIC_AFFLICTION_TN
