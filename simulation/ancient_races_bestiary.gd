class_name AncientRacesBestiary
## The Five Ancient Races (GDD s54.6): Kenku, Ningyo, Kitsu, Tsuno, Zokujin. Pure
## simulation class (no Node). Faithful transcription of the LOCKED stat blocks — no
## invented values. Reuses SpiritCreatureData (combat-ready via SpiritCombatant).
##
## "human-type Wound Ranks" creatures are stored with wounds_dead = 0, so SpiritCombatant
## falls back to the PC Earth-derived wound track — which IS the human-type track, so this
## is faithful (not a gap). realm: most are NINGEN_DO (mortal-realm races); Tsuno →
## TOSHIGOKU (cast into the Realm of Slaughter; Spirit quality). The Trolls have no stat
## block in s54.6 (only the narrative King of Trolls), so none is transcribed.
##
## Tag notes: Zokujin "Mineral Resistance" (Reduction only vs metal/stone) is carried as a
## descriptive `mineral_resistance` tag — the wired Reduction applies generally (faithful
## for the typical steel weapon; the wood-ignores-it nuance is unwired). Other abilities
## are descriptive tags pending a wiring tranche.

const _N: int = Enums.SpiritRealm.NINGEN_DO
const _TOSHI: int = Enums.SpiritRealm.TOSHIGOKU


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Kenku (s54.6) — human-type wounds (wounds_dead = 0) ----------------
	c["kenku_swordsman"] = _make("kenku_swordsman", "Kenku Swordsman", SpiritCreatureData.Tier.MID,
		4, 3, 3, 3, {"void": 4, "willpower": 4, "agility": 4, "strength": 4},
		7, 4, "Katana", 10, 4, 7, 2, 30, 3, [], 0, 0,
		["kenku", "illusion", "wings", "human_wounds", "weapon_user"], 0, _N)

	c["kenku_kensei"] = _make("kenku_kensei", "Kenku Kensei", SpiritCreatureData.Tier.BOSS,
		5, 4, 5, 3, {"void": 5, "strength": 5},
		10, 5, "Katana", 10, 7, 8, 2, 35, 3, [], 0, 0,
		["kenku", "illusion", "wings", "magic", "human_wounds", "weapon_user"], 0, _N)

	# --- Ningyo (s54.6) -----------------------------------------------------
	c["ningyo_feral"] = _make("ningyo_feral", "Feral Ningyo", SpiritCreatureData.Tier.MID,
		2, 3, 3, 3, {"reflexes": 3},
		4, 3, "Bite", 5, 3, 4, 1, 20, 2, [16, 32], 48, 0,
		["ningyo", "aquatic"], 0, _N)

	c["ningyo_pearl_diver"] = _make("ningyo_pearl_diver", "Ningyo Pearl-Diver", SpiritCreatureData.Tier.MID,
		4, 3, 4, 3, {},
		7, 4, "Yari", 8, 4, 5, 2, 20, 2, [], 0, 0,
		["ningyo", "aquatic", "human_wounds", "pearl_magic_r1", "weapon_user"], 0, _N)

	# --- Kitsu (s54.6) — historical / spirit-realm encounters ---------------
	c["kitsu"] = _make("kitsu", "Kitsu (Historical)", SpiritCreatureData.Tier.HEAVY,
		3, 3, 4, 5, {"void": 5},
		6, 3, "Claws", 6, 4, 5, 3, 25, 5, [18, 36, 54], 72, 0,
		["kitsu", "spirit", "shapeshifting", "cross_the_realms", "void_usage"], 0, _N)

	# --- Tsuno (s54.6) — realm TOSHIGOKU; human-type wounds -----------------
	c["tsuno_ravager"] = _make("tsuno_ravager", "Tsuno Ravager (Rank 3)", SpiritCreatureData.Tier.HEAVY,
		3, 5, 3, 3, {"reflexes": 5, "agility": 4, "strength": 4},
		8, 5, "Tsuno Blade", 10, 4, 7, 3, 35, 8, [], 0, 2,
		["tsuno", "spirit", "ravager", "human_wounds", "weapon_user", "tsuno_blade"], 3, _TOSHI)

	c["tsuno_soultwister"] = _make("tsuno_soultwister", "Tsuno Tainted Soultwister (Rank 3)", SpiritCreatureData.Tier.HEAVY,
		4, 4, 4, 4, {"reflexes": 5, "intelligence": 5},
		8, 5, "Tsuno Blade", 9, 4, 7, 3, 35, 8, [], 0, 2,
		["tsuno", "spirit", "soultwister", "tainted", "spellcaster", "human_wounds",
			"weapon_user", "tsuno_blade"], 3, _TOSHI)

	# --- Zokujin (s54.6) — Mineral Resistance (descriptive) -----------------
	c["zokujin_miner"] = _make("zokujin_miner", "Zokujin Miner", SpiritCreatureData.Tier.MID,
		3, 3, 2, 4, {"reflexes": 4, "agility": 3},
		5, 4, "Claws", 5, 3, 4, 1, 25, 10, [18, 36], 64, 0,
		["zokujin", "burrowing", "earthshaping", "mineral_resistance"], 0, _N)

	c["zokujin_stonehunter"] = _make("zokujin_stonehunter", "Zokujin Stonehunter", SpiritCreatureData.Tier.HEAVY,
		4, 4, 4, 4, {"reflexes": 5, "strength": 5},
		8, 5, "Claws", 9, 4, 5, 2, 30, 20, [24, 48], 72, 0,
		["zokujin", "armor_break", "weapon_break", "burrowing", "earthshaping", "mineral_resistance"], 0, _N)

	c["zokujin_shaman"] = _make("zokujin_shaman", "Zokujin Shaman", SpiritCreatureData.Tier.BOSS,
		4, 5, 4, 4, {"reflexes": 5, "intelligence": 5, "strength": 5},
		9, 5, "Claws", 7, 4, 5, 2, 30, 20, [32, 64], 80, 0,
		["zokujin", "spellcaster_earth", "armor_break", "weapon_break", "burrowing",
			"earthshaping", "mineral_resistance"], 0, _N)

	return c


static func race_ids() -> Array:
	return catalog().keys()


static func get_creature(id: String) -> SpiritCreatureData:
	return catalog().get(id, null)


static func _make(
		id: String, name: String, tier: int,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, dmg_r: int, dmg_k: int,
		atn: int, reduction: int, thresholds: Array, dead: int, fear: int,
		tags: Array, swift: int = 0, realm: int = _N) -> SpiritCreatureData:
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
