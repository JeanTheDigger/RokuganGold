class_name LostBestiary
## The four Notable Lost — named boss-tier villains from GDD s54.4 "The Lost". Pure
## simulation class (no Node). Faithful transcription of the LOCKED stat blocks — no
## invented values. Reuses SpiritCreatureData so every villain is combat-ready via
## SpiritCombatant.to_character_data() and spawnable by id through SpiritCombatant.spawn_by_id.
##
## SCOPE — only the four fully-statted Notable Lost NPCs are here (Doji Nashiko, Hida
## Atarasi, Moto Tsume, Daidoji Tsukuro). The s54.4 Lost SCHOOLS (Maho-Bujin, Dark Moto
## Cavalry) are character-creation schools, not creatures; the "New Lesser/Greater
## Shadowlands Powers" + "Powers of the Akutenshi" are s44 MutationSystem-domain content.
##
## These four are the ONLY s54 creatures whose stat blocks carry flat "+X" modifiers on the
## attack roll (Nashiko +8, Atarasi/Tsume +11, Tsukuro +8) and, for two, on the damage roll
## (Tsukuro +2). SpiritCreatureData.attack_flat_bonus / damage_flat_bonus carry those, applied
## in the IndividualCombat spirit-override branches (a flat add to the roll TOTAL, per L5R
## "7k4+8" = roll 7k4 and add 8). Every other s54 creature's flat bonuses stay 0 (inert).
##
## realm: all four are akutenshi/Lost of the Realm of Evil → JIGOKU.
##
## Field/tag mapping (mirrors the sibling bestiaries):
##  - "Invulnerable" special ability (only jade/crystal/obsidian/magic wound) → wired `partial_invuln`.
##  - Void N* "(cannot spend Void points)" → void_rank 0 (no SPENDABLE Void) + descriptive
##    `void_cannot_spend`. Giving them a spendable Void pool would violate the asterisk.
##  - Init flat bonuses (Atarasi/Tsume +2) are unrepresentable: the puppet's initiative uses
##    Reflexes+Insight (a documented SpiritCombatant approximation), so init dice/flats are inert.
##  - Atarasi "By weapon +9k0": his weapon is a tetsubo (base 3k3) and Strength is 10, so the
##    final damage is 3k3 + Strength 10 (to rolled) + 9k0 = 22k3 (fixed; strength_adds=false on
##    the puppet, so the Strength is baked into the transcribed dice — no double-add).
##  - Wound track: these list only a single "Dead" total (no intermediate penalty steps), so
##    wound_thresholds = [] and wounds_dead = the Dead total (SpiritCombatant proportional
##    fallback for penalty steps).
##  - Bespoke abilities carry descriptive (unwired) tags pending their combat-layer consumer
##    (fear_power [no numeric Fear rating stated → NOT invented], Atarasi's Avalanche taint
##    touch + raise-undead-on-kill, Unearthly Regeneration [no per-round amount stated],
##    Terror of Fu Leng, Tsukuro's return-from-grave) — the established pattern.

const _J: int = Enums.SpiritRealm.JIGOKU
const _BOSS: int = SpiritCreatureData.Tier.BOSS


static func catalog() -> Dictionary:
	var c: Dictionary = {}

	# --- Doji Nashiko, the Demon Bride of Fu Leng (s54.4) -------------------
	# Air 6 Earth 5 Fire 4 Water 4, Void 3* | Awa 8 Wil 7 Int 6 Per 5.
	# Init 10k9 | Wakizashi 7k4+8 / Blackened Claws 8k4+8 | dmg 10k4 / 10k5 | ATN 35 | Wounds 95:Dead.
	# Taint 8.5. Invulnerable. Doji Courtier 4 / Maho-Bujin 2 (Insight 10).
	c["doji_nashiko"] = _with2(_make("doji_nashiko", "Doji Nashiko, the Demon Bride of Fu Leng",
		6, 5, 4, 4, {"awareness": 8, "willpower": 7, "intelligence": 6, "perception": 5},
		10, 9, "Wakizashi", 7, 4, 8, 10, 4, 0, 35, 0, 95,
		["shadowlands", "lost", "akutenshi", "multi_attack", "partial_invuln", "void_cannot_spend", "seducer"]),
		"Blackened Claws", 8, 4, 10, 5)
	c["doji_nashiko"].taint_rank = 8

	# --- Hida Atarasi, the First Akutenshi (s54.4) -------------------------
	# Air 3 Earth 7 Fire 4 Water 4, Void 5* | Refl 6 Sta 10 Agi 7 Str 10.
	# Init 10k7+2 | Heavy weapon (tetsubo) 10k9+11 | dmg "By weapon +9k0" = 22k3 | ATN 45 |
	# Reduction 15 (Maho-Bujin 3 + Heavy Armor) | Wounds 197:Dead. Taint 9. Invulnerable.
	# Hida Bushi 3 / Maho-Bujin 3 (Insight 7). Atarasi's Avalanche (unarmed taint touch) + raise-undead.
	c["hida_atarasi"] = _make("hida_atarasi", "Hida Atarasi, the First Akutenshi",
		3, 7, 4, 4, {"reflexes": 6, "stamina": 10, "agility": 7, "strength": 10},
		10, 7, "Tetsubo", 10, 9, 11, 22, 3, 0, 45, 15, 197,
		["shadowlands", "lost", "akutenshi", "partial_invuln", "void_cannot_spend",
			"fear_power", "taint_touch_unarmed", "raise_undead_on_kill", "unearthly_regeneration"])
	c["hida_atarasi"].taint_rank = 9

	# --- Moto Tsume, General of the Shadowlands (s54.4) --------------------
	# Air 6 Earth 7 Fire 5 Water 5, Void 4* | Per 6.
	# Init 10k9+2 | Katana 10k6+11 | dmg Katana 10k5 | ATN 40 | Reduction 13 (Maho-Bujin 2 + Light Armor) |
	# Wounds 157:Dead. Taint 9. Invulnerable. Moto Bushi 5 / Maho-Bujin 3 (Insight 11).
	c["moto_tsume"] = _make("moto_tsume", "Moto Tsume, General of the Shadowlands",
		6, 7, 5, 5, {"perception": 6},
		10, 9, "Katana", 10, 6, 11, 10, 5, 0, 40, 13, 157,
		["shadowlands", "lost", "akutenshi", "partial_invuln", "void_cannot_spend", "terror_of_fu_leng"])
	c["moto_tsume"].taint_rank = 9

	# --- Daidoji Tsukuro, the Fallen Crane (s54.4) ------------------------
	# Air 3 Earth 4 Fire 5 Water 4, Void 4* | Awa 4 Wil 5 Per 6.
	# Init 9k3 | Katana 10k6+8 | dmg Katana 10k4+2 | ATN 25 | Reduction 3 (Light Armor) |
	# Wounds 100:Dead. Taint 8. Invulnerable. Undead. Daidoji Iron Warrior 4 / Maho-Bujin 1 (Insight 6).
	c["daidoji_tsukuro"] = _make("daidoji_tsukuro", "Daidoji Tsukuro, the Fallen Crane",
		3, 4, 5, 4, {"awareness": 4, "willpower": 5, "perception": 6},
		9, 3, "Katana", 10, 6, 8, 10, 4, 2, 25, 3, 100,
		["shadowlands", "lost", "akutenshi", "undead", "partial_invuln", "void_cannot_spend",
			"fear_power", "returns_from_grave"])
	c["daidoji_tsukuro"].taint_rank = 8

	return c


## All Notable-Lost ids (sorted).
static func lost_ids() -> Array:
	var ids: Array = catalog().keys()
	ids.sort()
	return ids


## Fresh instance of one Notable Lost by id (null if absent).
static func get_lost(id: String) -> SpiritCreatureData:
	return catalog().get(id, null)


static func _make(
		id: String, name: String,
		air: int, earth: int, fire: int, water: int, traits: Dictionary,
		init_r: int, init_k: int,
		atk_name: String, atk_r: int, atk_k: int, atk_flat: int,
		dmg_r: int, dmg_k: int, dmg_flat: int,
		atn: int, reduction: int, dead: int,
		tags: Array) -> SpiritCreatureData:
	var s := SpiritCreatureData.new()
	s.id = id
	s.display_name = name
	s.realm = _J
	s.tier = _BOSS
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
	s.attack_flat_bonus = atk_flat
	s.damage_rolled = dmg_r
	s.damage_kept = dmg_k
	s.damage_flat_bonus = dmg_flat
	s.armor_tn = atn
	s.reduction = reduction
	s.wound_thresholds = []
	s.wounds_dead = dead
	var tg: Array[String] = []
	for t in tags:
		tg.append(String(t))
	s.tags = tg
	return s


static func _with2(s: SpiritCreatureData, name: String, ar: int, ak: int, dr: int, dk: int) -> SpiritCreatureData:
	s.attack2_name = name
	s.attack2_rolled = ar
	s.attack2_kept = ak
	s.damage2_rolled = dr
	s.damage2_kept = dk
	return s
