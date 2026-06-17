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
			var earth: int = mini(victim.stamina, victim.willpower)
			var roll: int = dice.roll_and_keep(maxi(1, earth), maxi(1, earth), true).total
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
			var roll2: int = dice.roll_and_keep(maxi(1, victim.stamina), maxi(1, victim.stamina), true).total
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
## full restore at the daily granularity. One poison trait at a time per victim (stacks).
static func apply_poison(victim: L5RCharacterData, trait_name: String, ranks: int = 1) -> void:
	var a: Dictionary = victim.poison_affliction
	if a.is_empty():
		a = {"trait": trait_name, "drained": 0}
	elif str(a.get("trait", "")) != trait_name:
		return  # already poisoned with a different trait — ignore the second toxin
	for _i in range(ranks):
		if _get_trait(victim, trait_name) > 0:  # only count ranks actually removed
			_drain(victim, [trait_name], 1)
			a["drained"] = int(a.get("drained", 0)) + 1
	victim.poison_affliction = a


## Daily world-sim restore: returns the drained Traits (recovery < 1 day). Clears the poison.
static func process_poison_daily(victim: L5RCharacterData) -> Dictionary:
	if victim.poison_affliction.is_empty():
		return {}
	var a: Dictionary = victim.poison_affliction
	var n: int = int(a.get("drained", 0))
	var tr: String = str(a.get("trait", ""))
	_restore(victim, tr, n)
	victim.poison_affliction = {}
	return {"recovered": n, "trait": tr}


static func is_poisoned(victim: L5RCharacterData) -> bool:
	return not victim.poison_affliction.is_empty()


static func _get_trait(victim: L5RCharacterData, trait_name: String) -> int:
	match trait_name:
		"stamina":  return victim.stamina
		"reflexes": return victim.reflexes
		"agility":  return victim.agility
		"strength": return victim.strength
	return 0


static func _restore(victim: L5RCharacterData, trait_name: String, amount: int) -> void:
	match trait_name:
		"stamina":  victim.stamina += amount
		"reflexes": victim.reflexes += amount
		"agility":  victim.agility += amount
		"strength": victim.strength += amount


## Drains the listed Traits by `amount`, floored at 0.
static func _drain(victim: L5RCharacterData, traits: Array, amount: int) -> void:
	for tr in traits:
		match tr:
			"stamina":  victim.stamina = maxi(0, victim.stamina - amount)
			"reflexes": victim.reflexes = maxi(0, victim.reflexes - amount)
			"agility":  victim.agility = maxi(0, victim.agility - amount)
			"strength": victim.strength = maxi(0, victim.strength - amount)
