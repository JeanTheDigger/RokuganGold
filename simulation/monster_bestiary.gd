class_name MonsterBestiary
## The core Monsters & Nonhuman Races catalogue (GDD s54.2). Pure simulation class (no Node).
## Faithful transcription of the LOCKED stat blocks — no invented values. Reuses
## SpiritCreatureData so every monster is combat-ready via SpiritCombatant.to_character_data()
## and spawnable by id through SpiritCombatant.spawn_by_id.
##
## SCOPE — only the s54.2 entries NOT already transcribed elsewhere are here:
##   • Shozai-Gaki and Kappa already live in SpiritBestiary (the s56.16 realm roster) — omitted.
##   • Ghost (Yorei) has NO fixed stat block (the GDD says GMs build it from the deceased's own
##     Rings/Traits/Skills) — nothing to transcribe.
##   • The five Nezumi Colony "Force Roster" blocks are Company stat blocks (Health 153, Attack/
##     Defense/Morale) for the s11.7 Army Combat System, NOT SpiritCreatureData — omitted.
##   • The four Nezumi warren archetypes (Scout/Archer/Broodmother/Chieftain) give only Rings/
##     traits/skills/equipment/morale — no explicit Init/Attack/Damage/Armor-TN/Reduction lines —
##     so they cannot be built as combat SpiritCreatureData without inventing those numbers. Only
##     the complete base Ratling stat block (= "Nezumi Warrior") is transcribed here.
##
## realm: the Shadowlands monsters (Bog Hag, Bakemono, Ogre, Ugulu, Revenant, Zombie) are Tainted →
## JIGOKU. The Nezumi are a Taint-IMMUNE mortal race → NINGEN_DO. The Tsuno adapted to Toshigoku →
## TOSHIGOKU (matching the s54.6 tsuno_ravager/soultwister entries). (realm is a classification
## field; combat reads the stat block, not the realm.)
##
## Tag/field mapping (mirrors the s54.5/s54.6/s54.9/s54.10/s54.11/s54.12 bestiaries):
##  - "Invulnerable" / "Invulnerability" (only jade/crystal/obsidian/magic wound) → wired
##    `partial_invuln` (Bog Hag — weaker ones lack it, but this potent example has it).
##  - Reduction "(X against jade, crystal, or obsidian)" → reduction_jade/crystal/obsidian = X
##    (Ugulu no Oni: 24 → 12 vs sacred).
##  - "Human-type Wound Ranks" (Nezumi, Tsuno) → wounds_dead 0 + empty thresholds + a `human_wounds`
##    tag, so SpiritCombatant applies the PC Earth-derived wound track (the s54.6 convention).
##  - Nezumi "Name" trait (a Void-equivalent) → void_rank (SpiritCombatant maps it to the Void Ring
##    + Void Points, per the GDD "functions mechanically in the same manner as the Void Ring").
##  - Ugulu "immune to all arrows except armor-piercing" is a bespoke ranged immunity with no
##    arrow-type field → descriptive `immune_arrows` (unwired); "immune to two spells" → descriptive
##    `spell_immunity`. Bog Hag Disease (1-in-5 chance, weekly Stamina drain) has a different cadence
##    from the wired DiseaseSystem tags → descriptive `disease_wasting`. Beheading (called-shot
##    instant-kill), Skin Wearing, Swift, Fear, Special Weapon → the established descriptive-tag
##    pattern pending each ability's combat-layer consumer.
##
## Wound track: `wound_thresholds` = the numbers before each "+X" penalty step; `wounds_dead`
## = the terminal "Dead" total. Reduction 0 where the stat block lists "None".

const _J: int = Enums.SpiritRealm.JIGOKU
const _N: int = Enums.SpiritRealm.NINGEN_DO
const _TOSHI: int = Enums.SpiritRealm.TOSHIGOKU


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Bog Hag (s54.2) — Jigoku, Shadowlands infiltrator ------------------
	# Air 3 Earth 3 Fire 3 Water 2, Str 3; Init 5k3; Claws 5k3 dmg 3k2; ATN 20 Red 5;
	# Wounds 16;+5;32;+10;48;+15;72:Dead; Taint 4. Aquatic, Disease, Invulnerable, Skin Wearing.
	c["bog_hag"] = _make("bog_hag", "Bog Hag", SpiritCreatureData.Tier.HEAVY,
		3, 3, 3, 2, {"strength": 3},
		5, 3, "Claws", 5, 3, 3, 2, 20, 5, [16, 32, 48], 72, 0,
		["shadowlands", "aquatic", "disease_wasting", "partial_invuln", "skin_wearing", "seducer"])
	c["bog_hag"].taint_rank = 4

	# --- Goblin / Bakemono (s54.2) — the typical Shadowlands goblin ----------
	# Air 1 Earth 2 Fire 1 Water 1, Refl/Agi/Str 2; Init 4k2; Attack 4k2 dmg 4k2 (knife/stick);
	# ATN 15 Red 3; Wounds 9;+5;18:Dead; Taint 2; Swift 2.
	c["goblin_bakemono"] = _make("goblin_bakemono", "Goblin (Bakemono)", SpiritCreatureData.Tier.SWARM,
		1, 2, 1, 1, {"reflexes": 2, "agility": 2, "strength": 2},
		4, 2, "Knife", 4, 2, 4, 2, 15, 3, [9], 18, 0,
		["shadowlands", "goblin", "pack_instinct", "imitation"], 2)
	c["goblin_bakemono"].taint_rank = 2

	# --- Ogre (s54.2) — the base Tainted ogre -------------------------------
	# Air 1 Earth 3 Fire 3 Water 2, Refl 3 Sta 6 Str 6; Init 4k3; Club 5k4 dmg 8k2;
	# ATN 25 Red 10; Wounds 20;+5;40;+10;60;+15;80:Dead; Taint 3; Fear 2; Huge.
	c["ogre_base"] = _make("ogre_base", "Ogre", SpiritCreatureData.Tier.HEAVY,
		1, 3, 3, 2, {"reflexes": 3, "stamina": 6, "strength": 6},
		4, 3, "Club", 5, 4, 8, 2, 25, 10, [20, 40, 60], 80, 2,
		["shadowlands", "ogre", "huge", "weapon_user"])
	c["ogre_base"].taint_rank = 3

	# --- Ugulu no Oni (s54.2) — a powerful oni the Wall Crab dread ----------
	# Air 1 Earth 6 Fire 2 Water 2, Agi 4 Str 8; Init 3k1; Claws 7k4 dmg 9k3; ATN 10;
	# Red 24 (12 vs jade/crystal/obsidian); Wounds 32;+5;64;+10;96;+15;124:Dead; Taint 6; Fear 3.
	c["ugulu_no_oni"] = _make("ugulu_no_oni", "Ugulu no Oni", SpiritCreatureData.Tier.BOSS,
		1, 6, 2, 2, {"agility": 4, "strength": 8},
		3, 1, "Claws", 7, 4, 9, 3, 10, 24, [32, 64, 96], 124, 3,
		["shadowlands", "oni", "huge", "immune_arrows", "spell_immunity",
			"reduction_vs_jade_crystal_obsidian"])
	c["ugulu_no_oni"].taint_rank = 6
	c["ugulu_no_oni"].reduction_jade = 12
	c["ugulu_no_oni"].reduction_crystal = 12
	c["ugulu_no_oni"].reduction_obsidian = 12

	# --- Ratling / Nezumi (s54.2) — the complete base Ratling stat block ----
	# ( = "Nezumi Warrior"). Taint-IMMUNE mortal race → NINGEN_DO; human-type wounds; Name → Void.
	# Air 1 Earth 2 Fire 2 Water 2 Name 1, Refl 3 Agi 3; Init 4k3; Crude spear 4k3 dmg 4k2;
	# ATN 20 Red None; Swift 2.
	c["nezumi_warrior"] = _make("nezumi_warrior", "Ratling (Nezumi)", SpiritCreatureData.Tier.MID,
		1, 2, 2, 2, {"reflexes": 3, "agility": 3},
		4, 3, "Crude Spear", 4, 3, 4, 2, 20, 0, [], 0, 0,
		["nezumi", "ratling", "taint_immune", "name_trait", "human_wounds"], 2, _N)
	c["nezumi_warrior"].void_rank = 1

	# --- Tsuno Warrior (s54.2) — the base Tsuno (Toshigoku, self-Tainted) ----
	# Air 2 Earth 4 Fire 2 Water 3, Refl 4 Agi 3; Init 5k4; Tsuno blade 7k3 dmg 6k3 (primary);
	# ATN 30 (5 light armor) Red 8 (3 light armor); human-type wounds; Taint 4; Fear 2; Swift 3.
	c["tsuno_warrior"] = _make("tsuno_warrior", "Tsuno Warrior", SpiritCreatureData.Tier.HEAVY,
		2, 4, 2, 3, {"reflexes": 4, "agility": 3},
		5, 4, "Tsuno Blade", 7, 3, 6, 3, 30, 8, [], 0, 2,
		["tsuno", "spirit", "tainted", "weapon_user", "tsuno_blade", "human_wounds"], 3, _TOSHI)
	c["tsuno_warrior"].taint_rank = 4

	# --- Undead Revenant (s54.2) — a stronger, maho-made zombie -------------
	# Air 0 Earth 3 Fire 1 Water 2, Refl/Agi/Str 3; Init 3k3; Sword 5k3 dmg 5k2 (primary);
	# ATN 15 Red 5; Wounds 72:Dead; Taint 3; Fear 3; Undead; Beheading (called shot, 18+ Wounds).
	c["undead_revenant"] = _make("undead_revenant", "Undead Revenant", SpiritCreatureData.Tier.MID,
		0, 3, 1, 2, {"reflexes": 3, "agility": 3, "strength": 3},
		3, 3, "Sword", 5, 3, 5, 2, 15, 5, [], 72, 3,
		["undead", "revenant", "beheading", "weapon_user"], 0, _J)
	c["undead_revenant"].taint_rank = 3

	# --- Zombie (s54.2) — the canonical Tainted-corpse base zombie ----------
	# Air 0 Earth 3 Fire 0 Water 1, Refl 1 Agi 2 Str 3; Init 1k1; Club 4k2 dmg 3k2 (primary);
	# ATN 10 Red 5; Wounds 72:Dead; Taint 3; Fear 3; Undead; Beheading.
	c["zombie"] = _make("zombie", "Zombie", SpiritCreatureData.Tier.MID,
		0, 3, 0, 1, {"reflexes": 1, "agility": 2, "strength": 3},
		1, 1, "Club", 4, 2, 3, 2, 10, 5, [], 72, 3,
		["undead", "zombie", "beheading"], 0, _J)
	c["zombie"].taint_rank = 3

	return c


## All s54.2 monster ids (sorted).
static func monster_ids() -> Array:
	var ids: Array = catalog().keys()
	ids.sort()
	return ids


## Fresh instance of one monster by id (null if absent).
static func get_monster(id: String) -> SpiritCreatureData:
	return catalog().get(id, null)


static func _make(
		id: String, name: String, tier: int,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
		atn: int, reduction: int, thresholds: Array, dead: int, fear: int,
		tags: Array, swift: int = 0, realm: int = _J) -> SpiritCreatureData:
	var s := SpiritCreatureData.new()
	s.id = id
	s.display_name = name
	s.realm = realm
	s.tier = tier
	s.air = air
	s.earth = earth
	s.fire = fire
	s.water = water
	s.traits = traits
	s.initiative_rolled = init_r
	s.initiative_kept = init_k
	s.attack_name = atk_name
	s.attack_rolled = atk_r
	s.attack_kept = atk_k
	s.damage_rolled = dmg_r
	s.damage_kept = dmg_k
	s.armor_tn = atn
	s.reduction = reduction
	var th: Array[int] = []
	for t in thresholds:
		th.append(int(t))
	s.wound_thresholds = th
	s.wounds_dead = dead
	s.fear = fear
	s.swift = swift
	var tg: Array[String] = []
	for t in tags:
		tg.append(String(t))
	s.tags = tg
	return s
