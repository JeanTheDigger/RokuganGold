class_name AnimalCombatant
## s57.39.7 — converts a trained-animal COMPANION record (a Dictionary on
## L5RCharacterData.trained_companions) into a combat-ready L5RCharacterData
## "puppet" the AsciiMapCombatOrchestrator uses as a participant, reusing the
## verified SpiritCombatant puppet plumbing (to-hit / damage / wound-track
## overrides via the attached SpiritCreatureData). Pure simulation class (no Node).
##
## SPECIES → STAT BLOCK MAPPING (owner-confirmed 2026-06-30): each s57.39 species
## uses a Section 54.1 natural-creature stat block, transcribed WHOLE per s57.39.7
## ("using its species stat block (Section 54 creature entries)"):
##   DOG          → Dog (Inu)                 RIDING_HORSE → Horse, Rokugani Pony
##   WAR_DOG      → Dog, Unicorn War Dog      WARHORSE     → Horse, Unicorn Riding Horse
##   FALCON       → Falcon                    WARCAT       → Lion
##   PIGEON       → (no combat block — a message bird, never a combatant)
## The combat WOUND TRACK is the s54.1 track (wound_thresholds + wounds_dead) per
## s57.39.7 / s57.39.9 ("following the standard creature wound track rules (Section
## 54)"); s57.39.6's per-species wound_threshold remains the world-sim companion-
## record value (it also drives the Rank-5 Hurt-flee rule, s57.39.7), a separate field.
##
## FLAGGED TENSION (owner to review): s57.39.9 says "the companion's Armor TN
## (default 15 for most trained animals; warcats and warhorses have higher values
## per their Section 54 entries)". That conflicts with the varied s54.1 Armor TN
## (Dog 20, Falcon 30, …). This file follows s57.39.7's "use the Section 54 stat
## block" and transcribes the s54.1 Armor TN whole. If the owner prefers the flat-15
## companion rule, set USE_S57_39_9_FLAT_ARMOR_TN = true (warcat/warhorse keep s54.1).

# Set true to apply s57.39.9's flat-15 companion Armor TN (warcat/warhorse excepted)
# instead of the s54.1 per-species value. Default false = s54.1 whole (s57.39.7).
const USE_S57_39_9_FLAT_ARMOR_TN: bool = false
const COMPANION_FLAT_ARMOR_TN: int = 15
# Species that keep their s54.1 Armor TN even under the flat rule (s57.39.9: "warcats
# and warhorses have higher values per their Section 54 entries").
const FLAT_ARMOR_TN_EXEMPT: Array[String] = ["WARCAT", "WARHORSE"]


## Build the species combat catalogue (species_str → SpiritCreatureData). Pure s54.1
## transcription per the owner-confirmed mapping. PIGEON has no entry (non-combatant).
static func catalog() -> Dictionary:
	return {
		# Dog (Inu) — s54.1.
		"DOG": _make("DOG", "Dog", 1, 2, 1, 1,
			{"reflexes": 3, "agility": 3, "perception": 3},
			4, 3, "bite", 3, 3, 2, 1, 20, 0, [12], 24, 2),
		# Dog, Unicorn War Dog — s54.1.
		"WAR_DOG": _make("WAR_DOG", "War Dog", 2, 3, 2, 3,
			{"reflexes": 4, "agility": 4},
			5, 4, "bite", 5, 4, 3, 2, 25, 3, [18], 36, 2),
		# Falcon — s54.1.
		"FALCON": _make("FALCON", "Falcon", 1, 1, 1, 1,
			{"reflexes": 4, "agility": 4, "perception": 3},
			5, 5, "claw/beak", 5, 4, 3, 2, 30, 0, [5], 10, 5, ["flying"]),
		# Horse, Rokugani Pony — s54.1 (the generic RIDING_HORSE).
		"RIDING_HORSE": _make("RIDING_HORSE", "Riding Horse", 2, 2, 1, 2,
			{"stamina": 4, "agility": 2, "strength": 4},
			3, 2, "kick", 3, 2, 4, 2, 15, 3, [16, 32], 48, 3, ["huge"]),
		# Horse, Unicorn Riding Horse — s54.1 (the war-trained WARHORSE; Utaku Battle
		# Steed stays school-only).
		"WARHORSE": _make("WARHORSE", "Warhorse", 2, 3, 1, 2,
			{"stamina": 4, "agility": 3, "strength": 5},
			4, 2, "kick", 4, 3, 5, 2, 15, 3, [12, 24, 36], 48, 3, ["huge"]),
		# Lion — s54.1 (the WARCAT; uses the Simple Claws attack as its primary strike).
		"WARCAT": _make("WARCAT", "Warcat", 2, 4, 1, 2,
			{"reflexes": 3, "stamina": 4, "agility": 3, "strength": 6},
			4, 3, "claws", 5, 3, 4, 3, 20, 3, [12, 24, 36], 48, 0, [], 1),
	}


## Returns the SpiritCreatureData combat stat block for a species, or null if the
## species has no combat block (PIGEON / unknown).
static func stat_block(species: String) -> SpiritCreatureData:
	return catalog().get(species, null)


## s57.39.7 Rank-5 "Hurt"-flee threshold: the wounds at which a commanded animal breaks
## off combat (unless the owner has the Rank-7 no-flee mastery). Uses the s54.1 stat
## block's FIRST wound threshold (the point the animal leaves Healthy) — which equals
## s54.1's explicit per-animal flee points where stated (Dog 12, Falcon 5). This is why
## the 8-level WoundLevel enum is NOT used: a 2-threshold creature never reaches the
## enum's HURT before Dead. Falls back to wounds_dead if a block has no thresholds.
## PROVISIONAL where s54.1 states a higher prose flee point (e.g. Rokugani Pony "32 or
## more") — the first threshold (16) is used as the "Hurt" break-off.
static func flee_wound_threshold(puppet: L5RCharacterData) -> int:
	if puppet.spirit_creature == null:
		return 9999
	var b: SpiritCreatureData = puppet.spirit_creature
	if not b.wound_thresholds.is_empty():
		return b.wound_thresholds[0]
	return b.wounds_dead if b.wounds_dead > 0 else 9999


## True if the species can take part in combat (has a stat block).
static func is_combat_species(species: String) -> bool:
	return catalog().has(species)


## Build a combat puppet for a trained-animal companion record. `companion` is the
## Dictionary from L5RCharacterData.trained_companions; instance_id MUST be unique and
## negative (by convention, never colliding with real characters). Returns null if the
## companion is dead, not alive, or its species has no combat block (e.g. PIGEON).
## The puppet carries the companion's NAME and current WOUND_TOTAL (a wounded companion
## enters combat wounded). The original companion record is not mutated.
static func to_combatant(companion: Dictionary, instance_id: int) -> L5RCharacterData:
	if not companion.get("is_alive", false):
		return null
	var species: String = companion.get("species", "")
	var block: SpiritCreatureData = stat_block(species)
	if block == null:
		return null
	var puppet: L5RCharacterData = SpiritCombatant.to_character_data(block, instance_id)
	# Companion identity + carry-over wounds (so a wounded animal fights wounded).
	var cname: String = companion.get("name", "")
	if cname != "":
		puppet.character_name = cname
	puppet.wounds_taken = maxi(0, int(companion.get("wound_total", 0)))
	return puppet


# ── internal ──────────────────────────────────────────────────────────────────

static func _make(
	id: String, dname: String,
	air: int, earth: int, fire: int, water: int,
	traits: Dictionary,
	init_r: int, init_k: int,
	atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
	armor_tn: int, reduction: int,
	wound_thresholds: Array, wounds_dead: int,
	swift: int = 0, tags: Array = [], fear: int = 0,
) -> SpiritCreatureData:
	var c := SpiritCreatureData.new()
	c.id = id
	c.display_name = dname
	c.realm = Enums.SpiritRealm.NINGEN_DO  # natural mortal-world animals
	c.air = air
	c.earth = earth
	c.fire = fire
	c.water = water
	c.traits = traits
	c.initiative_rolled = init_r
	c.initiative_kept = init_k
	c.attack_name = atk_name
	c.attack_rolled = atk_r
	c.attack_kept = atk_k
	c.damage_rolled = dmg_r
	c.damage_kept = dmg_k
	var at: int = armor_tn
	if USE_S57_39_9_FLAT_ARMOR_TN and not (id in FLAT_ARMOR_TN_EXEMPT):
		at = COMPANION_FLAT_ARMOR_TN
	c.armor_tn = at
	c.reduction = reduction
	var wt: Array[int] = []
	for t: Variant in wound_thresholds:
		wt.append(int(t))
	c.wound_thresholds = wt
	c.wounds_dead = wounds_dead
	c.swift = swift
	c.fear = fear
	var tg: Array[String] = []
	for t: Variant in tags:
		tg.append(String(t))
	c.tags = tg
	return c
