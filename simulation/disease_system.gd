class_name DiseaseSystem
## s54.5 / s54.11 contagious diseases that drain physical Traits over days/weeks. A disease
## is SET on a creature's hit (Byoki Plague Bearer, Shikko Diseased Touch, plague-zombie
## Plague Carrier) and processed in the world-sim daily (cross-encounter), mirroring the
## possession/death-touch affliction pattern. Pure simulation class (no Node).
##
## Faithful to the LOCKED stat blocks — no invented values. Physical Traits = Stamina,
## Reflexes, Agility, Strength (drained, floored at 0).

enum Type { PLAGUE_BEARER, DISEASED_TOUCH, PLAGUE_CARRIER }

const PLAGUE_BEARER_TN: int = 15   # Byoki: daily Earth roll
const DISEASED_TOUCH_TN: int = 20  # Shikko: weekly Stamina roll
const CURE_CONSECUTIVE: int = 3    # Byoki: 3 consecutive saves cures
const WEEK: int = 7

const _PHYSICAL := ["stamina", "reflexes", "agility", "strength"]


## Seeds the disease on a victim (one disease at a time — re-infection is ignored while
## already diseased). source_id = the creature that infected them.
static func contract(victim: L5RCharacterData, type: int, source_id: int, ic_day: int = -1) -> void:
	if not victim.disease_affliction.is_empty():
		return
	# ic_day == -1 when seeded in tile combat (the orchestrator has no IC day); the first
	# world-sim process_daily initialises last_tick/onset to the real IC day.
	victim.disease_affliction = {
		"type": type, "source_id": source_id, "last_tick": ic_day, "cures": 0, "onset": ic_day,
	}


static func is_diseased(victim: L5RCharacterData) -> bool:
	return not victim.disease_affliction.is_empty()


## Magic / Medicine cure — clears the disease.
static func cure(victim: L5RCharacterData) -> void:
	victim.disease_affliction = {}


## Daily processing (called once per IC day per diseased character). Returns a status dict:
## {drained:bool, cured:bool, died:bool, type:int}. Empty dict if not diseased.
static func process_daily(victim: L5RCharacterData, ic_day: int, dice: DiceEngine) -> Dictionary:
	if victim.disease_affliction.is_empty():
		return {}
	var a: Dictionary = victim.disease_affliction
	var t: int = int(a.get("type", Type.PLAGUE_BEARER))
	# First world-sim tick after a combat-seeded infection: anchor the cadence clocks.
	if int(a.get("last_tick", -1)) < 0:
		a["last_tick"] = ic_day
		a["onset"] = ic_day
		return {"type": t}
	match t:
		Type.PLAGUE_BEARER:
			# Daily Earth roll TN 15 or lose 1 Rank in ALL physical Traits; 3 consecutive
			# successes cure it (Medicine has no effect — magic-only otherwise).
			var earth: int = cursed_resist_pool(victim, maxi(1, mini(victim.stamina, victim.willpower)))
			var roll: int = dice.roll_and_keep(earth, earth, true).total
			if roll >= PLAGUE_BEARER_TN:
				a["cures"] = int(a.get("cures", 0)) + 1
				if int(a["cures"]) >= CURE_CONSECUTIVE:
					cure(victim)
					return {"cured": true, "type": t}
				return {"type": t}
			a["cures"] = 0
			_drain(victim, _PHYSICAL, 1)
			return {"drained": true, "type": t}
		Type.DISEASED_TOUCH:
			# Weekly Stamina TN 20: success recovers; failure loses 1 Stamina + 1 Strength.
			if ic_day - int(a.get("last_tick", ic_day)) < WEEK:
				return {"type": t}
			a["last_tick"] = ic_day
			var sta_d: int = cursed_resist_pool(victim, maxi(1, victim.stamina + _earths_touch_stamina_bonus(victim)))
			var roll2: int = dice.roll_and_keep(sta_d, sta_d, true).total
			if roll2 >= DISEASED_TOUCH_TN:
				cure(victim)
				return {"cured": true, "type": t}
			_drain(victim, ["stamina", "strength"], 1)
			return {"drained": true, "type": t}
		Type.PLAGUE_CARRIER:
			# Weekly automatic Stamina −1 until cured (Medicine) or Stamina 0 → dies (and
			# would reanimate as a plague zombie — reanimation deferred). No save.
			if ic_day - int(a.get("last_tick", ic_day)) < WEEK:
				return {"type": t}
			a["last_tick"] = ic_day
			victim.stamina = maxi(0, victim.stamina - 1)
			if victim.stamina <= 0:
				return {"died": true, "type": t}
			return {"drained": true, "type": t}
	return {"type": t}


## --- Poison / venom (s54.11/s54.12) -----------------------------------------------------
## An immediate Trait drain per hit (Strength for stingers, Stamina for bites), restored in
## the world-sim. GDD recovery is sub-day (1hr/dose) to 24h, which collapses to a next-tick
## full restore at the daily granularity. Multiple toxins coexist: poison_affliction holds a
## per-Trait drained-Rank tally `{"traits": {trait: count}}`, so a stinger (Strength) and an
## escalating Shikage poison (Willpower/Reflexes) each get restored independently.
static func apply_poison(victim: L5RCharacterData, trait_name: String, ranks: int = 1) -> void:
	for _i in range(ranks):
		if _get_trait(victim, trait_name) > 0:  # only count ranks actually removed
			_drain(victim, [trait_name], 1)
			_bank_poison(victim, trait_name, 1)


## Daily world-sim restore: returns the drained Traits (recovery < 1 day). Clears the poison.
static func process_poison_daily(victim: L5RCharacterData) -> Dictionary:
	if victim.poison_affliction.is_empty():
		return {}
	var by: Dictionary = victim.poison_affliction.get("traits", {})
	var recovered: Dictionary = {}
	for tr in by.keys():
		var n: int = int(by[tr])
		_restore(victim, str(tr), n)
		recovered[tr] = n
	victim.poison_affliction = {}
	return {"recovered": recovered}


static func is_poisoned(victim: L5RCharacterData) -> bool:
	return not victim.poison_affliction.is_empty()


## Centralized poison/toxin resist save. Rolls the victim's Stamina vs `tn`; returns whether the
## save SUCCEEDS. Jurojin's Balm (s34 Earth 1): while the "jurojins_balm" day buff is active, a
## FAILED poison save is re-rolled with +2k0 (Stamina + 2 rolled) — if the re-roll also fails the
## poison has full effect. Disease saves (Shikko's diseased touch) do NOT route here — Jurojin's
## Balm drives out poisons/toxins, not disease (which has its own Medicine cure path).
static func resolve_poison_resist_roll(victim: L5RCharacterData, tn: int, dice: DiceEngine) -> bool:
	var sta: int = cursed_resist_pool(victim, maxi(1, victim.stamina + _earths_touch_stamina_bonus(victim)))
	if dice.roll_and_keep(sta, sta, true).total >= tn:
		return true
	if not victim.has_day_buff("jurojins_balm"):
		return false
	return dice.roll_and_keep(sta + 2, sta, true).total >= tn


## Jurojin's Curse (s34 Earth 2): the target's Earth reads 3 Ranks lower (min 1) for resisting
## disease or poison. Lowers the Stamina/Earth resist pool by 3 while the "jurojins_curse" day
## buff is active — applied to every poison and disease save (poison helper + process_disease_daily).
const JUROJINS_CURSE_PENALTY: int = 3
static func cursed_resist_pool(victim: L5RCharacterData, base: int) -> int:
	if victim.has_day_buff("jurojins_curse"):
		return maxi(1, base - JUROJINS_CURSE_PENALTY)
	return base


## s34 Earth's Touch (Earth 1, Stamina option) AND Stone's Endurance (Earth 1) both make
## Stamina-keyed poison/disease resist saves read Stamina +1 — for Stone's Endurance this is its
## GDD-named signature use ("poison resistance, drowning duration"). Non-stacking (+1 from this
## family, not +2). NOT applied to the PLAGUE_BEARER save (an Earth-RING roll — neither spell
## raises the Ring) nor the escalating-poison tick (Earth's Touch never reached it either).
static func _earths_touch_stamina_bonus(victim: L5RCharacterData) -> int:
	return 1 if (victim.has_day_buff("earths_touch_stamina") \
		or victim.has_day_buff("stones_endurance")) else 0


## Banks `n` drained Ranks of `trait_name` into poison_affliction for the world-sim restore.
static func _bank_poison(victim: L5RCharacterData, trait_name: String, n: int) -> void:
	if n <= 0:
		return
	var a: Dictionary = victim.poison_affliction
	var by: Dictionary = a.get("traits", {})
	by[trait_name] = int(by.get(trait_name, 0)) + n
	a["traits"] = by
	victim.poison_affliction = a


## --- Escalating poison (s54.5 Shikage no Oni) ------------------------------------------
## Mind-Breaking (Willpower) and Paralyzing (Reflexes) poisons: an immediate −1 Rank, then
## a per-Round Stamina TN 20 roll (+5/extra dose) that drains another Rank on a failure until
## the Stamina roll SUCCEEDS or the Trait reaches 0 (Willpower 0 → mind-controlled, Reflexes 0
## → paralyzed). The combat layer owns the `state` dict (one per victim) and applies the
## end-state incapacitation; this class runs the roll/drain math. Drained Ranks are banked into
## poison_affliction for the world-sim restore (GDD 24h/12h → next-tick restore).
const ESCALATING_POISON_TN: int = 20  # Shikage: per-Round Stamina roll
const ESCALATING_DOSE_TN: int = 5     # +5 TN per additional dose

## Initial application on a hit. `trait_name` = "willpower" (Mind-Breaking) or "reflexes"
## (Paralyzing). Drains 1 Rank now and stacks the dose. Returns the updated escalating state
## {trait, doses, drained}. A second toxin of a different trait is ignored (single slot).
static func escalating_apply(victim: L5RCharacterData, state: Dictionary, trait_name: String) -> Dictionary:
	if not state.is_empty() and str(state.get("trait", "")) != trait_name:
		return state  # already suffering a different escalating poison — ignore
	if state.is_empty():
		state = {"trait": trait_name, "doses": 0, "drained": 0}
	state["doses"] = int(state.get("doses", 0)) + 1
	if _get_trait(victim, trait_name) > 0:
		_drain(victim, [trait_name], 1)
		state["drained"] = int(state.get("drained", 0)) + 1
	return state


## Per-Round Reactions-Stage tick. Rolls Stamina vs TN 20 + 5×(doses−1). On success the drain
## STOPS (banks the drained Ranks for restore, returns ended); on failure drains 1 more Rank,
## and at Trait 0 the victim is incapacitated (mind-controlled / paralyzed) and the drain ends.
## Returns {ended, drained_more, incapacitated, trait}. `state` is cleared on end (caller drops it).
static func escalating_tick(victim: L5RCharacterData, state: Dictionary, dice: DiceEngine) -> Dictionary:
	if state.is_empty():
		return {"ended": true}
	var trait_name: String = str(state.get("trait", ""))
	var doses: int = int(state.get("doses", 1))
	if _get_trait(victim, trait_name) <= 0:
		# Already at 0 from a prior tick/application — incapacitated, end the drain.
		_bank_escalating_drain(victim, state)
		return {"ended": true, "incapacitated": true, "trait": trait_name}
	var tn: int = ESCALATING_POISON_TN + (doses - 1) * ESCALATING_DOSE_TN
	if resolve_poison_resist_roll(victim, tn, dice):
		_bank_escalating_drain(victim, state)  # fought it off — drained Ranks recover in the world-sim
		return {"ended": true, "trait": trait_name}
	_drain(victim, [trait_name], 1)
	state["drained"] = int(state.get("drained", 0)) + 1
	if _get_trait(victim, trait_name) <= 0:
		_bank_escalating_drain(victim, state)
		return {"ended": true, "drained_more": true, "incapacitated": true, "trait": trait_name}
	return {"drained_more": true, "trait": trait_name}


## Banks an ended escalating poison's drained Ranks into poison_affliction so the world-sim
## daily restore returns them (per-Trait tally — coexists with any stinger/bite poison).
static func _bank_escalating_drain(victim: L5RCharacterData, state: Dictionary) -> void:
	_bank_poison(victim, str(state.get("trait", "")), int(state.get("drained", 0)))


static func _get_trait(victim: L5RCharacterData, trait_name: String) -> int:
	match trait_name:
		"stamina":   return victim.stamina
		"reflexes":  return victim.reflexes
		"agility":   return victim.agility
		"strength":  return victim.strength
		"willpower": return victim.willpower
	return 0


static func _restore(victim: L5RCharacterData, trait_name: String, amount: int) -> void:
	match trait_name:
		"stamina":   victim.stamina += amount
		"reflexes":  victim.reflexes += amount
		"agility":   victim.agility += amount
		"strength":  victim.strength += amount
		"willpower": victim.willpower += amount


## Drains the listed Traits by `amount`, floored at 0.
static func _drain(victim: L5RCharacterData, traits: Array, amount: int) -> void:
	for tr in traits:
		match tr:
			"stamina":   victim.stamina = maxi(0, victim.stamina - amount)
			"reflexes":  victim.reflexes = maxi(0, victim.reflexes - amount)
			"agility":   victim.agility = maxi(0, victim.agility - amount)
			"strength":  victim.strength = maxi(0, victim.strength - amount)
			"willpower": victim.willpower = maxi(0, victim.willpower - amount)
