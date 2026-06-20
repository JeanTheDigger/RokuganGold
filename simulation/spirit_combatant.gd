class_name SpiritCombatant
## s56.16 live-encounter adapter: converts a SpiritCreatureData stat block into a
## combat-ready L5RCharacterData "puppet" the AsciiMapCombatOrchestrator can use as
## a participant. Pure simulation class (no Node). PC-only encounter context.
##
## FAITHFUL (the existing combat math reads these directly): the four Rings (via
## their paired traits, ring = min of the pair), the named traits (Reflexes/Agility/
## Strength/… used by initiative, attack-trait, damage-trait), Armor TN (back-calc
## into armor_tn_bonus so get_armor_tn returns the creature's value), natural
## Reduction (armor_reduction), and the natural-weapon DAMAGE dice.
##
## APPROXIMATED until the orchestrator override layer (the next, runtime-verified
## tranche): the to-HIT roll (PC math is trait+skill; the creature's fixed Xk Y is
## stored on `spirit_creature` for the override) and the WOUND track (PC capacity is
## Earth-derived; the creature's explicit `wounds_dead`/thresholds are on
## `spirit_creature`). Special abilities come from SpiritAbilitySystem via the tags.
##
## Instance ids: callers MUST pass a unique negative character_id (e.g. -(10000 + n))
## so puppets never collide with real characters.

## Builds a combat puppet for one creature instance. instance_id MUST be unique
## (negative, by convention). The SpiritCreatureData is stored on the puppet for
## the ability/override layer; the original is not mutated.
static func to_character_data(creature: SpiritCreatureData, instance_id: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = instance_id
	c.character_name = creature.display_name
	c.spirit_creature = creature

	# Rings via paired traits (ring = min of the pair): Air=(Reflexes,Awareness),
	# Earth=(Stamina,Willpower), Fire=(Agility,Intelligence), Water=(Strength,Perception).
	c.reflexes = creature.air
	c.awareness = creature.air
	c.stamina = creature.earth
	c.willpower = creature.earth
	c.agility = creature.fire
	c.intelligence = creature.fire
	c.strength = creature.water
	c.perception = creature.water
	# Spirits have no Void Ring, except the rare Void users (s54.12 Akeru no Oni) whose
	# stat block sets void_rank.
	c.void_ring = creature.void_rank
	c.current_void_points = creature.void_rank

	# Named-trait overrides from the stat block (always ≥ their Ring in s54.10, so the
	# Ring stays the min of its pair while the named trait drives attack/init/damage).
	for tname in creature.traits:
		_set_trait(c, String(tname), int(creature.traits[tname]))

	# Defense — faithful: natural Reduction, and Armor TN back-calculated so
	# CharacterStats.get_armor_tn (= Reflexes×5 + 5 + bonus) returns creature.armor_tn.
	c.armor_reduction = creature.reduction
	c.armor_tn_bonus = creature.armor_tn - (c.reflexes * 5 + 5)

	# Natural weapon: DAMAGE dice are faithful (strength_adds=false — the creature's
	# damage is fixed, not Strength-augmented). The to-HIT roll is the PC trait+skill
	# approximation until the override layer reads spirit_creature.attack_rolled/kept.
	if creature.damage_rolled > 0 or creature.attack_rolled > 0:
		var w := WeaponData.new()
		w.weapon_name = creature.attack_name if creature.attack_name != "" else "natural"
		w.rolled = maxi(1, creature.damage_rolled)
		w.kept = maxi(1, creature.damage_kept)
		w.strength_adds = false
		w.skill = "Jiujutsu"
		w.melee = not (creature.has_tag("ranged") or creature.has_tag("flying"))
		w.attack_trait = "agility"
		var wlist: Array[WeaponData] = [w]
		c.weapons = wlist

	return c


## Returns the SpiritBestiary catalogue for a realm (id → SpiritCreatureData).
static func catalog_for_realm(realm: int) -> Dictionary:
	match realm:
		Enums.SpiritRealm.GAKI_DO:
			return SpiritBestiary.gaki_do_catalog()
		Enums.SpiritRealm.TOSHIGOKU:
			return SpiritBestiary.toshigoku_catalog()
		Enums.SpiritRealm.SAKKAKU:
			return SpiritBestiary.sakkaku_catalog()
		Enums.SpiritRealm.CHIKUSHUDO:
			return SpiritBestiary.chikushudo_catalog()
		_:
			return {}   # Meido / Yume-do have no roster


## Spawns a puppet for `creature_id` in `realm`. Returns null if the id is not in
## the realm's catalogue. The combat loop calls this on demand (escalation, s56.16.5e).
static func spawn(realm: int, creature_id: String, instance_id: int) -> L5RCharacterData:
	var cat: Dictionary = catalog_for_realm(realm)
	var cr: SpiritCreatureData = cat.get(creature_id, null)
	if cr == null:
		return null
	return to_character_data(cr, instance_id)


## Finds a creature by id across EVERY bestiary (spirit realms, oni, undead, elemental
## terrors + additional creatures, the Five Ancient Races). Returns a fresh
## SpiritCreatureData instance, or null if no bestiary holds the id. The realm-agnostic
## lookup the Shadowlands / Kaiu-Wall-horde / mission consumers use — every transcribed
## s54 creature is spawnable by id without knowing which bestiary it lives in.
static func find_creature(creature_id: String) -> SpiritCreatureData:
	for realm: int in [Enums.SpiritRealm.GAKI_DO, Enums.SpiritRealm.TOSHIGOKU,
			Enums.SpiritRealm.SAKKAKU, Enums.SpiritRealm.CHIKUSHUDO]:
		var cr: SpiritCreatureData = catalog_for_realm(realm).get(creature_id, null)
		if cr != null:
			return cr
	for cat: Dictionary in [OniBestiary.catalog(), UndeadBestiary.catalog(),
			AdditionalCreaturesBestiary.catalog(), AncientRacesBestiary.catalog()]:
		var cr2: SpiritCreatureData = cat.get(creature_id, null)
		if cr2 != null:
			return cr2
	return null


## Spawns a combat puppet for any creature id from any bestiary (see find_creature).
## Returns null if the id is unknown. instance_id MUST be unique negative (by convention).
static func spawn_by_id(creature_id: String, instance_id: int) -> L5RCharacterData:
	var cr: SpiritCreatureData = find_creature(creature_id)
	if cr == null:
		return null
	return to_character_data(cr, instance_id)


# ── internal ──────────────────────────────────────────────────────────────────

static func _set_trait(c: L5RCharacterData, tname: String, value: int) -> void:
	match tname:
		"reflexes":     c.reflexes = value
		"awareness":    c.awareness = value
		"stamina":      c.stamina = value
		"willpower":    c.willpower = value
		"agility":      c.agility = value
		"intelligence": c.intelligence = value
		"strength":     c.strength = value
		"perception":   c.perception = value
		"void":         c.void_ring = value
