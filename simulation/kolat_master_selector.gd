class_name KolatMasterSelector
## Kolat Master selection at world generation (GDD s54.7a, locked s54.7j2).
## Pure simulation class — no Node inheritance. Selects one Master per Sect from
## the named-NPC pool via a weighted-tier draw, in a fixed processing order that
## doubles as conflict resolution. Applies Sect skill boosts and the hidden
## Master fields. Special rules (koku reserves, world-start sleeper/contact
## counts) are surfaced as flags for the world generator to act on.
##
## Tier criteria from s54.7a are mapped to queryable character data (clan,
## school_name, role_position, skills, status, glory, school_type, lord-tier via
## role_position). Criteria that the data model cannot express (e.g. "institutional
## access to isolated people") are relaxed to the Sect's skill thresholds —
## flagged PROVISIONAL in the per-Sect notes.

const TIER_WEIGHTS: Dictionary = {1: 5, 2: 2, 3: 1}

# Processing order = conflict-resolution priority (s54.7a). Roc has no profile
# (standard agent); it still gets a seat via the generic min/tier path.
const PROCESSING_ORDER: Array[int] = [
	Enums.KolatSect.TIGER,
	Enums.KolatSect.CHRYSANTHEMUM,
	Enums.KolatSect.SILK,
	Enums.KolatSect.COIN,
	Enums.KolatSect.CLOUD,
	Enums.KolatSect.JADE,
	Enums.KolatSect.DREAM,
	Enums.KolatSect.LOTUS,
	Enums.KolatSect.ROC,
	Enums.KolatSect.STEEL,
]

# Sect-specific skill boosts (max rule — never lowers a skill). s54.7a.
const SECT_BOOSTS: Dictionary = {
	Enums.KolatSect.TIGER: {"Courtier (Manipulation)": 8, "Investigation": 7, "Intimidation (Control)": 7, "Sincerity (Deceit)": 7},
	Enums.KolatSect.CHRYSANTHEMUM: {"Courtier": 8, "Etiquette": 8, "Sincerity (Deceit)": 7, "Investigation (Notice)": 6},
	Enums.KolatSect.SILK: {"Acting": 8, "Sincerity (Deceit)": 8, "Courtier (Manipulation)": 7, "Forgery": 6},
	Enums.KolatSect.COIN: {"Commerce (Appraisal)": 8, "Commerce (Mathematics)": 8, "Courtier": 7, "Sincerity (Deceit)": 6, "Forgery": 6},
	Enums.KolatSect.CLOUD: {"Spellcraft": 8, "Lore: History": 7, "Calligraphy (Cipher)": 7, "Meditation": 6},
	Enums.KolatSect.JADE: {"Investigation": 8, "Lore: Shadowlands": 7, "Medicine": 6, "Spellcraft": 6},
	Enums.KolatSect.DREAM: {"Temptation": 8, "Intimidation (Control)": 8, "Medicine": 7, "Sincerity (Deceit)": 6},
	Enums.KolatSect.LOTUS: {"Stealth (Sneaking)": 8, "Acting": 7, "Knives": 6, "Ninjutsu": 5},
	Enums.KolatSect.STEEL: {"Battle": 8, "Defense": 7, "Intimidation (Bullying)": 6},
	Enums.KolatSect.ROC: {},
}

const WEAPON_SKILLS: Array[String] = [
	"Kenjutsu", "Iaijutsu", "Polearms", "Heavy Weapons", "Kyujutsu",
	"Knives", "Jiujutsu", "War Fan", "Ninjutsu", "Staves", "Spears",
]


# === PUBLIC ENTRY ============================================================

## Select Masters from `npcs` (Array of L5RCharacterData). Mutates selected
## characters (applies boosts + hidden fields). Returns a Dictionary mapping
## KolatSect → npc_id (or -1 for a seat left vacant when no eligible candidate
## exists). Deterministic given the DiceEngine seed.
static func select_masters(npcs: Array, dice: DiceEngine) -> Dictionary:
	var taken: Dictionary = {}        # npc_id → true
	var result: Dictionary = {}
	var tiger_id: int = -1
	for sect: int in PROCESSING_ORDER:
		var pool: Array = []          # weighted draw pool of npc_ids
		for npc: L5RCharacterData in npcs:
			if npc == null or taken.has(npc.character_id) or CharacterStats.is_dead(npc):
				continue
			if not _meets_minimums(sect, npc):
				continue
			var tier: int = _classify_tier(sect, npc)
			for _w: int in range(TIER_WEIGHTS.get(tier, 1)):
				pool.append(npc.character_id)
		if pool.is_empty():
			result[sect] = -1
			continue
		var pick_id: int = pool[dice.rand_int_range(0, pool.size() - 1)]
		taken[pick_id] = true
		result[sect] = pick_id
		var master: L5RCharacterData = _find(npcs, pick_id)
		if sect == Enums.KolatSect.TIGER:
			tiger_id = pick_id
		_apply_master(master, sect)
		_apply_special_rules(master, sect, dice)
	# Wire the Kolat chain: every Master reports to Tiger; Tiger reports to none.
	for sect: int in result.keys():
		var nid: int = result[sect]
		if nid < 0:
			continue
		var m: L5RCharacterData = _find(npcs, nid)
		if m == null:
			continue
		m.kolat_superior_id = -1 if sect == Enums.KolatSect.TIGER else tiger_id
	return result


# === ELIGIBILITY (universal filters + Sect minimums, s54.7a) =================

static func _meets_minimums(sect: int, npc: L5RCharacterData) -> bool:
	# Universal: Insight 3+, not the Emperor. ("Not already selected" handled by caller.)
	if CharacterStats.get_insight_rank(npc) < 3:
		return false
	if npc.role_position == "Emperor":
		return false
	match sect:
		Enums.KolatSect.TIGER:
			return _skill(npc, "Courtier (Manipulation)") >= 3 and _skill(npc, "Investigation") >= 3
		Enums.KolatSect.CHRYSANTHEMUM:
			return npc.status >= 5.0 and _skill(npc, "Courtier") >= 4 and _skill(npc, "Etiquette") >= 3
		Enums.KolatSect.SILK:
			return _skill(npc, "Acting") >= 3 and _skill(npc, "Courtier") >= 3 and npc.awareness >= 3
		Enums.KolatSect.COIN:
			return _skill(npc, "Commerce") >= 4 and _is_lord(npc)
		Enums.KolatSect.CLOUD:
			return npc.school_type == Enums.SchoolType.SHUGENJA \
				and _skill(npc, "Spellcraft") >= 3 and _skill(npc, "Calligraphy") >= 3 \
				and _lore_count_at(npc, 3) >= 2
		Enums.KolatSect.JADE:
			return (npc.school_type == Enums.SchoolType.SHUGENJA or _is_witch_hunter(npc)) \
				and _skill(npc, "Lore: Shadowlands") >= 3 and _skill(npc, "Investigation") >= 3
		Enums.KolatSect.DREAM:
			return _skill(npc, "Temptation") >= 3 and _skill(npc, "Intimidation (Control)") >= 2 \
				and _skill(npc, "Medicine") >= 2
		Enums.KolatSect.LOTUS:
			return _skill(npc, "Stealth") >= 3 and _best_weapon_skill(npc) >= 4
		Enums.KolatSect.STEEL:
			return _skill(npc, "Battle") >= 3 and _best_weapon_skill(npc) >= 4
		Enums.KolatSect.ROC:
			# No profile; standard agent. Generic floor: a capable named samurai.
			return true
	return false


# === TIER CLASSIFICATION (s54.7a) ============================================
# Returns 1 (Ideal), 2 (Acceptable), or 3 (Last Resort). Assumes minimums met.

static func _classify_tier(sect: int, npc: L5RCharacterData) -> int:
	match sect:
		Enums.KolatSect.TIGER:
			if (npc.clan == "Scorpion" and npc.role_position in ["Clan Champion", "Family Daimyo"]) \
				or npc.role_position in ["Emerald Champion", "Jade Champion"]:
				return 1
			if _is_magistrate(npc) and _skill(npc, "Investigation") >= 5:
				return 2
			return 3
		Enums.KolatSect.CHRYSANTHEMUM:
			if npc.family in ["Otomo", "Seppun", "Miya"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.family in ["Otomo", "Seppun", "Miya"] and _skill(npc, "Courtier") >= 4:
				return 2
			return 3
		Enums.KolatSect.SILK:
			if npc.school_name in ["Shosuro Actor", "Doji Courtier", "Kitsuki Investigator"] \
				and npc.school_rank >= 5:
				return 1
			if _skill(npc, "Acting") >= 4 and _skill(npc, "Sincerity (Deceit)") >= 4:
				return 2
			return 3
		Enums.KolatSect.COIN:
			if npc.family in ["Yasuki", "Ide"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.role_position == "Family Daimyo" and _skill(npc, "Commerce") >= 4:
				return 2
			return 3
		Enums.KolatSect.CLOUD:
			if npc.family in ["Isawa", "Agasha", "Tamori"] and npc.role_position == "Family Daimyo":
				return 1
			if npc.school_rank >= 5 and _skill(npc, "Spellcraft") >= 4 and _lore_count_at(npc, 4) >= 3:
				return 2
			return 3
		Enums.KolatSect.JADE:
			if (_is_witch_hunter(npc) and npc.school_rank >= 4) or npc.role_position == "Jade Champion":
				return 1
			if _skill(npc, "Lore: Shadowlands") >= 4:
				return 2
			return 3
		Enums.KolatSect.DREAM:
			# T1 "Head Sensei / senior Abbot / Kuroiban+Medicine" — relaxed
			# (no institutional-access field): high Temptation+Medicine. PROVISIONAL.
			if _skill(npc, "Temptation") >= 5 and _skill(npc, "Medicine") >= 4:
				return 1
			if _skill(npc, "Temptation") >= 4:
				return 2
			return 3
		Enums.KolatSect.LOTUS:
			if npc.school_name in ["Shosuro Infiltrator", "Shosuro Actor"] and npc.school_rank >= 5:
				return 1
			if _skill(npc, "Stealth") >= 4 and _best_weapon_skill(npc) >= 5:
				return 2
			return 3
		Enums.KolatSect.STEEL:
			if npc.glory >= 5.0 and _best_weapon_skill(npc) >= 5:
				return 1
			if _skill(npc, "Battle") >= 4:
				return 2
			return 3
	return 3


# === MASTER APPLICATION (s54.7a "What Every Master Receives") ================

static func _apply_master(npc: L5RCharacterData, sect: int) -> void:
	if npc == null:
		return
	npc.is_kolat_master = true
	npc.kolat_sect = sect
	# Apply Sect skill boosts (max rule — never lower).
	for skill_name: String in SECT_BOOSTS.get(sect, {}).keys():
		var boosted: int = SECT_BOOSTS[sect][skill_name]
		if npc.skills.get(skill_name, 0) < boosted:
			npc.skills[skill_name] = boosted
	# Sect special-rule seed values surfaced for the world generator.
	# Coin: hidden untraceable reserves (2d10 × 10), stored as kolat_koku.
	# Dream/Silk world-start sleeper/contact counts are surfaced via
	# get_special_rule_flags(); the generator creates the registry entries.


## Apply a Master's Sect special rule at selection (s54.7a). The Coin reserve is
## a number on the Master, so it is applied directly to `kolat_koku`. The Dream
## sleeper count and Silk contact count drive a network-creation pass that needs
## NPC selection (deferred) — they are stamped into `special_data` so that pass
## knows the target count without inventing which NPCs become sleepers/contacts.
static func _apply_special_rules(npc: L5RCharacterData, sect: int, dice: DiceEngine) -> void:
	if npc == null:
		return
	var flags: Dictionary = get_special_rule_flags(sect, dice)
	if flags.has("hidden_kolat_koku"):
		npc.kolat_koku += int(flags["hidden_kolat_koku"])
	if flags.has("world_start_sleepers"):
		npc.special_data["world_start_sleepers"] = int(flags["world_start_sleepers"])
	if flags.has("preplaced_contacts"):
		npc.special_data["preplaced_contacts"] = int(flags["preplaced_contacts"])


## Special-rule flags for the world generator to act on after selection
## (s54.7a special rules). Pure description — no world mutation here.
static func get_special_rule_flags(sect: int, dice: DiceEngine) -> Dictionary:
	match sect:
		Enums.KolatSect.COIN:
			# Hidden koku reserves: 2d10 × 10 (s54.7a).
			return {"hidden_kolat_koku": (dice.rand_int_range(1, 10) + dice.rand_int_range(1, 10)) * 10}
		Enums.KolatSect.DREAM:
			# 1d6+2 world-start sleepers (s54.7a / s54.7c).
			return {"world_start_sleepers": dice.rand_int_range(1, 6) + 2}
		Enums.KolatSect.SILK:
			# 1d6+2 pre-placed conscious agent contacts (s54.7a).
			return {"preplaced_contacts": dice.rand_int_range(1, 6) + 2}
	return {}


# === QUERY HELPERS ===========================================================

static func _find(npcs: Array, npc_id: int) -> L5RCharacterData:
	for n: L5RCharacterData in npcs:
		if n != null and n.character_id == npc_id:
			return n
	return null


static func _skill(npc: L5RCharacterData, name: String) -> int:
	return npc.skills.get(name, 0)


static func _best_weapon_skill(npc: L5RCharacterData) -> int:
	var best: int = 0
	for w: String in WEAPON_SKILLS:
		best = maxi(best, npc.skills.get(w, 0))
	return best


## Count of distinct "Lore: *" skills at or above `rank`.
static func _lore_count_at(npc: L5RCharacterData, rank: int) -> int:
	var n: int = 0
	for skill_name: String in npc.skills.keys():
		if skill_name.begins_with("Lore:") and npc.skills[skill_name] >= rank:
			n += 1
	return n


## Lord-tier: holds a daimyo/champion/headman seat (proxy for "has a province").
static func _is_lord(npc: L5RCharacterData) -> bool:
	var r: String = npc.role_position
	return r.contains("Daimyo") or r.contains("Champion") or r == "Village Headman"


static func _is_magistrate(npc: L5RCharacterData) -> bool:
	return npc.role_position.contains("Magistrate")


static func _is_witch_hunter(npc: L5RCharacterData) -> bool:
	if npc.school_name.contains("Witch Hunter") or npc.school_name.contains("Witch-Hunter"):
		return true
	if npc.role_position.contains("Inquisitor"):
		return true
	return false
