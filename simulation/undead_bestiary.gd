class_name UndeadBestiary
## The Undead catalogue (GDD s54.11). Pure simulation class (no Node). Faithful
## transcription of the LOCKED stat blocks — no invented values. Reuses
## SpiritCreatureData so undead are combat-ready via SpiritCombatant.to_character_data().
##
## realm: physical undead (zombies, ghuls, pennaggolan, etc.) → JIGOKU (kansen-animated);
## gaki → GAKI_DO; slaughter spirits → TOSHIGOKU. All carry the "undead" tag.
##
## Tag mapping: oni-style "Invulnerability" (resists mundane weapons) → wired `partial_invuln`.
## Gaki "Superior Invulnerability" is IMMUNITY TO ILLUSION + MIND effects (NOT mundane-weapon
## invuln), so it gets DESCRIPTIVE `immune_illusion`/`immune_mind` tags — using the wired
## superior_invuln would wrongly zero mundane weapons. Other special abilities carry
## descriptive (unwired) tags pending a combat-wiring tranche.

const _R: int = Enums.SpiritRealm.JIGOKU
const _GAKI: int = Enums.SpiritRealm.GAKI_DO
const _TOSHI: int = Enums.SpiritRealm.TOSHIGOKU


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Physical undead (s54.11) -------------------------------------------
	c["ghul"] = _make("ghul", "Ghul", SpiritCreatureData.Tier.MID,
		1, 2, 1, 2, {"reflexes": 3, "stamina": 4, "agility": 3, "strength": 4},
		4, 3, "Claw", 4, 3, 5, 2, 20, 5, [], 72, 3,
		["undead", "throat_attack", "pack_hunter"])
	c["ghul"].followup_wound_threshold = 15  # Throat Attack: 15+ Wound claw -> free bite (s54.11)
	c["ghul"].followup_rolled = 5
	c["ghul"].followup_kept = 3
	c["ghul"].followup_dmg_rolled = 4
	c["ghul"].followup_dmg_kept = 1

	c["harionago"] = _with2(_make("harionago", "Harionago", SpiritCreatureData.Tier.MID,
		3, 3, 3, 3, {"willpower": 5, "agility": 4, "perception": 4},
		3, 3, "Claws", 8, 4, 3, 3, 20, 10, [], 80, 0,
		["undead", "hook_grapple", "reduction_vs_jade", "deceiver", "multi_attack"], 1),
		"Hair Hooks", 4, 4, 3, 1)

	c["hyakuhei"] = _make("hyakuhei", "Hyakuhei", SpiritCreatureData.Tier.MID,
		1, 4, 2, 3, {"reflexes": 3, "agility": 3, "strength": 4},
		4, 3, "Claws", 4, 3, 4, 1, 20, 5, [], 80, 4,
		["undead", "intelligent", "pack_tactics", "weapon_user"])

	c["kekkai"] = _make("kekkai", "Kekkai", SpiritCreatureData.Tier.SWARM,
		1, 1, 1, 1, {},
		2, 1, "Fist", 1, 1, 1, 1, 10, 5, [], 16, 4,
		["undead", "partial_invuln", "purification_vulnerable", "tiny"])

	c["nukekubi"] = _make("nukekubi", "Nukekubi", SpiritCreatureData.Tier.MID,
		1, 2, 1, 2, {"reflexes": 4, "agility": 3},
		3, 3, "Bite", 4, 3, 3, 2, 25, 5, [], 36, 3,
		["undead", "partial_invuln", "flying_head", "vulnerable_body"], 2)

	c["nuppeppo"] = _make("nuppeppo", "Nuppeppo", SpiritCreatureData.Tier.MID,
		1, 1, 0, 1, {"stamina": 3, "agility": 2, "strength": 2},
		2, 1, "Bludgeon", 2, 2, 3, 2, 10, 15, [], 24, 3,
		["undead", "abominable_stench", "reduction_vs_jade_crystal_fire", "reanimates"])

	c["pennaggolan"] = _with2(_make("pennaggolan", "Pennaggolan", SpiritCreatureData.Tier.HEAVY,
		3, 3, 3, 3, {"reflexes": 4, "stamina": 4, "agility": 4, "perception": 4},
		5, 4, "Bite", 4, 4, 2, 2, 25, 15, [], 72, 3,
		["undead", "partial_invuln", "deceptive_taint", "entrail_constriction", "flying_head",
			"vulnerable_body", "reduction_vs_jade_crystal", "multi_attack"], 2),
		"Entrails", 9, 4, 3, 1)

	c["plague_zombie"] = _make("plague_zombie", "Plague Zombie", SpiritCreatureData.Tier.MID,
		0, 3, 0, 1, {"reflexes": 1, "stamina": 4, "agility": 2, "strength": 3},
		1, 1, "Fist", 4, 2, 3, 1, 10, 5, [], 72, 3,
		["undead", "beheading", "plague_carrier"])

	# --- Gaki (s54.11) — realm GAKI_DO; "Superior Invulnerability" = immune to
	# illusion + mind effects (descriptive tags, NOT the mundane-weapon wired tag) ----
	c["gakimushi"] = _make("gakimushi", "Gaki, Gakimushi", SpiritCreatureData.Tier.HEAVY,
		2, 5, 3, 3, {"reflexes": 4, "stamina": 4, "agility": 5, "strength": 5},
		6, 4, "Stinger", 6, 6, 5, 3, 25, 10, [25, 60], 95, 4,
		["undead", "gaki", "spirit", "gaki_immortality", "immune_illusion", "immune_mind",
			"poisonous_stinger", "shapeshift_insect", "reduction_vs_jade_crystal"], 0, _GAKI)

	c["kwaku_shin_gaki"] = _make("kwaku_shin_gaki", "Gaki, Kwaku-shin Gaki", SpiritCreatureData.Tier.MID,
		2, 3, 3, 2, {"reflexes": 3, "stamina": 5, "agility": 4, "strength": 4},
		4, 3, "Slam", 6, 4, 4, 3, 20, 5, [32, 64], 96, 3,
		["undead", "gaki", "spirit", "gaki_immortality", "immune_illusion", "immune_mind",
			"cauldron_belch", "flame_immune", "water_vulnerable"], 0, _GAKI)

	c["shikko_gaki"] = _make("shikko_gaki", "Gaki, Shikko-gaki", SpiritCreatureData.Tier.MID,
		2, 3, 2, 2, {"reflexes": 3, "stamina": 5, "agility": 3, "strength": 4},
		5, 3, "Claw", 4, 2, 4, 2, 20, 5, [32], 64, 4,
		["undead", "gaki", "spirit", "gaki_immortality", "immune_illusion", "immune_mind",
			"diseased_touch", "ghoulish_regeneration"], 2, _GAKI)

	c["skull_tide"] = _make("skull_tide", "Gaki, Skull Tide", SpiritCreatureData.Tier.BOSS,
		1, 1, 3, 3, {"reflexes": 3, "stamina": 5, "strength": 6},
		3, 3, "Biting", 8, 4, 6, 3, 20, 5, [25, 50, 75], 100, 5,
		["undead", "gaki", "spirit", "gaki_immortality", "immune_illusion", "immune_mind",
			"bound_to_water"], 0, _GAKI)

	# --- Slaughter spirits (s54.11) — realm TOSHIGOKU -----------------------
	c["slaughter_spirit"] = _make("slaughter_spirit", "Slaughter Spirit (Toshigokujin)", SpiritCreatureData.Tier.MID,
		1, 1, 1, 2, {"reflexes": 4, "stamina": 4, "agility": 4, "strength": 4},
		5, 4, "Weapon", 8, 4, 4, 1, 25, 0, [30, 60], 90, 0,
		["undead", "spirit", "slaughter_spirit", "immune_mind", "relentless_aggression"], 3, _TOSHI)

	# --- Notable undead villains (s54.11) -----------------------------------
	c["kitsune_gohei"] = _make("kitsune_gohei", "Kitsune Gohei, the Walking Horror of Fu Leng", SpiritCreatureData.Tier.BOSS,
		4, 8, 5, 5, {"reflexes": 6, "strength": 7},
		10, 6, "Claw", 10, 5, 7, 2, 40, 13, [], 172, 6,
		["undead", "named", "lost", "partial_invuln", "reduction_vs_jade_crystal",
			"shadowlands_powers", "weapon_user"])

	c["fatina_ghul_lord"] = _make("fatina_ghul_lord", "Fatina, Ghul Lord", SpiritCreatureData.Tier.BOSS,
		4, 5, 3, 2, {"agility": 4, "strength": 4},
		5, 4, "Claw", 6, 3, 4, 2, 25, 5, [], 92, 3,
		["undead", "named", "ghul_lord", "sahir_magic_r3"])

	c["yogo_junzo"] = _make("yogo_junzo", "Yogo Junzo, Undead Sorcerer", SpiritCreatureData.Tier.BOSS,
		7, 5, 3, 4, {"stamina": 4, "intelligence": 5},
		10, 8, "Claw", 5, 3, 4, 1, 40, 10, [], 95, 5,
		["undead", "named", "lost", "shugenja_r5", "reduction_vs_jade_crystal",
			"shadowlands_powers"])

	return c


static func undead_ids() -> Array:
	return catalog().keys()


static func get_undead(id: String) -> SpiritCreatureData:
	return catalog().get(id, null)


static func _with2(s: SpiritCreatureData, name: String, ar: int, ak: int, dr: int, dk: int) -> SpiritCreatureData:
	s.attack2_name = name
	s.attack2_rolled = ar
	s.attack2_kept = ak
	s.damage2_rolled = dr
	s.damage2_kept = dk
	return s


static func _make(
		id: String, name: String, tier: int,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
		atn: int, reduction: int, thresholds: Array, dead: int, fear: int,
		tags: Array, swift: int = 0, realm: int = _R) -> SpiritCreatureData:
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
