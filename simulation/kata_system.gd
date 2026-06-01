class_name KataSystem
## Kata eligibility, acquisition, and stub effect registry per GDD s30a.
## Combat effects (Armor TN, attack rolls, stances, etc.) are blocked on s40.


# === KATA DATA TABLE ===
# Each entry: { ring, mastery, ring_alt (optional), schools, school_mode,
#               clan (optional), effect_id, effect_desc, xp_cost }
#
# school_mode values:
#   "any"          — any bushi (school_type == BUSHI)
#   "clan"         — any bushi of matching clan
#   "named"        — school_name in schools array
#   "named_or_any" — Any + katana/daisho restriction (multi-ring chain)
#
# ring_alt: second qualifying ring for multi-ring katas (Air/Fire chain)
# ring and ring_alt both default to Enums.Ring.NONE if unused

const KATA_DATA: Dictionary = {
	# -------------------------------------------------------------------------
	# AIR KATAS
	# -------------------------------------------------------------------------
	"Striking as Air": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "air_defense_armor_tn",
		"effect_desc": "In Defense Stance: Armor TN increased by Air Ring.",
		"xp_cost": 3,
	},
	"Breath of Wind Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Kakita Bushi", "Bayushi Bushi"], "clan": "",
		"effect_id": "air_initiative_stack",
		"effect_desc": "Initiative Score +2 during Reactions Stage each Combat Round (stacks; disappears if kata ends).",
		"xp_cost": 3,
	},
	"Dance of the Winds": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Daidoji Bushi", "Shiba Bushi"], "clan": "",
		"effect_id": "air_polearm_initiative",
		"effect_desc": "Wielding polearm or spear: Initiative Score +3.",
		"xp_cost": 3,
	},
	"Strength of the Mantis": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Mantis",
		"effect_id": "air_ranged_melee_penalty",
		"effect_desc": "Ranged attack penalty when opponent is in melee reduced by 3.",
		"xp_cost": 3,
	},
	"Strength of the Crane": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Crane",
		"effect_id": "air_crane_honor_armor",
		"effect_desc": "Fighting with sword or spear: +(Honor Rank−3, min 1) to Armor TN.",
		"xp_cost": 3,
	},
	"Iron Forest Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Daidoji Iron Warrior", "Heichi Bushi", "Shiba Bushi"], "clan": "",
		"effect_id": "air_spear_attack_ring",
		"effect_desc": "Spear or polearm: use Air Ring instead of Agility for attack rolls.",
		"xp_cost": 4,
	},
	"Veiled Menace Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Bayushi Bushi", "Hiruma Bushi", "Tsuruchi Archer", "Yoritomo Bushi"], "clan": "",
		"effect_id": "air_stealth_armor_once",
		"effect_desc": "Once per Turn: +Stealth Skill Rank to Armor TN against one attack.",
		"xp_cost": 4,
	},
	"North Wind Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "air_increased_damage_bonus",
		"effect_desc": "+Air Ring to attack roll total when using Increased Damage Maneuver.",
		"xp_cost": 4,
	},
	"South Wind Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "air_called_knockdown_bonus",
		"effect_desc": "+Air Ring to attack roll total when using Called Shot or Knockdown Maneuver.",
		"xp_cost": 4,
	},
	"Hidden Blade Style": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Bayushi Bushi", "Yoritomo Bushi"], "clan": "",
		"effect_id": "air_disarm_normal_damage",
		"effect_desc": "Disarm attacks deal normal damage (not 2k1); damage may not be raised.",
		"xp_cost": 4,
	},

	# -------------------------------------------------------------------------
	# EARTH KATAS
	# -------------------------------------------------------------------------
	"Striking as Earth": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "earth_full_defense_reduction",
		"effect_desc": "In Full Defense Stance: Reduction equal to Earth Ring.",
		"xp_cost": 3,
	},
	"The Power of the Mountain": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Hida Bushi", "Hiruma Bushi", "Matsu Berserker", "Ichiro Bushi"], "clan": "",
		"effect_id": "earth_trade_armor_for_damage",
		"effect_desc": "Reduce Armor TN by up to Earth Ring; all damage totals +same amount.",
		"xp_cost": 3,
	},
	"The Strength of the Mountain": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Hida Bushi", "Hiruma Scout", "Shiba Bushi", "Daidoji Iron Warrior"], "clan": "",
		"effect_id": "earth_trade_initiative_for_armor",
		"effect_desc": "Reduce Initiative by up to Earth Ring (min 0); Armor TN +same.",
		"xp_cost": 3,
	},
	"Strike as the Avalanche": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Hida Bushi", "Hiruma Bushi", "Ichiro Bushi", "Moto Bushi", "Moto Vindicator"], "clan": "",
		"effect_id": "earth_heavy_weapons_strength",
		"effect_desc": "Heavy Weapons: Strength treated one Rank higher for damage.",
		"xp_cost": 3,
	},
	"Strength of the Spider": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Spider",
		"effect_id": "earth_spider_wound_debuff",
		"effect_desc": "Once per Round: if 15+ Wounds dealt, opponent −3 to all rolls next Turn.",
		"xp_cost": 3,
	},
	"Strength of the Crab": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Crab",
		"effect_id": "earth_crab_armor_reduction",
		"effect_desc": "In Attack Stance wearing Armor: armor provides +2 Reduction.",
		"xp_cost": 3,
	},
	"Iron in the Mountains Style": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Daidoji Iron Warrior", "Hida Bushi"], "clan": "",
		"effect_id": "earth_defense_stance_ring",
		"effect_desc": "Use Earth Ring in place of Air Ring for the Defense Stance.",
		"xp_cost": 3,
	},
	"Indomitable Warrior Style": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Daigotsu Bushi", "Hida Bushi", "Ichiro Bushi", "Moto Bushi"], "clan": "",
		"effect_id": "earth_wound_tn_reduce",
		"effect_desc": "Reduce TN penalties from Wound Ranks by Earth Ring.",
		"xp_cost": 4,
	},
	"Lee of the Stone": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Hida Bushi", "Hida Pragmatist", "Shiba Bushi", "Daidoji Iron Warrior"], "clan": "",
		"effect_id": "earth_defense_extra_armor",
		"effect_desc": "In Defense or Full Defense Stance: Armor TN +Earth Ring (additional).",
		"xp_cost": 4,
	},
	"Weathered and Unbroken": {
		"ring": Enums.Ring.EARTH, "ring_alt": Enums.Ring.NONE, "mastery": 5,
		"school_mode": "named", "schools": ["Hida Bushi", "Hiruma Bushi", "Hiruma Scout", "Ichiro Bushi"], "clan": "",
		"effect_id": "earth_water_movement_penalty",
		"effect_desc": "Water Ring treated 2 Ranks lower for movement; Heavy Weapons attack gains 1 Free Raise for Knockdown only.",
		"xp_cost": 5,
	},

	# -------------------------------------------------------------------------
	# FIRE KATAS
	# -------------------------------------------------------------------------
	"Striking as Fire": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "fire_full_attack_attack_bonus",
		"effect_desc": "In Full Attack Stance: +Fire Ring to one attack roll per Round.",
		"xp_cost": 3,
	},
	"Strength of the Scorpion": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Scorpion",
		"effect_id": "fire_scorpion_feint_damage",
		"effect_desc": "Once per Turn after successful Feint: damage total +3 Wounds.",
		"xp_cost": 3,
	},
	"Strength of the Dragon": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Dragon",
		"effect_id": "fire_dragon_daisho_armor",
		"effect_desc": "Katana main hand + wakizashi off-hand: +3 Armor TN.",
		"xp_cost": 3,
	},
	"Reckless Abandon Style": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Daigotsu Bushi", "Matsu Berserker", "Usagi Bushi"], "clan": "",
		"effect_id": "fire_full_attack_armor_tn",
		"effect_desc": "In Full Attack Stance: +Fire Ring to Armor TN.",
		"xp_cost": 4,
	},
	"Disappearing World Style": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Akodo Bushi", "Kakita Bushi"], "clan": "",
		"effect_id": "fire_agility_for_damage",
		"effect_desc": "Choose one opponent; once per Turn: use Agility instead of Strength for damage rolls against that opponent.",
		"xp_cost": 4,
	},
	"Spinning Blades Style": {
		"ring": Enums.Ring.FIRE, "ring_alt": Enums.Ring.NONE, "mastery": 5,
		"school_mode": "named", "schools": ["Mirumoto Bushi", "Yoritomo Bushi"], "clan": "",
		"effect_id": "fire_extra_attack_3_raises",
		"effect_desc": "Extra Attack Maneuver costs 3 Raises (not 5) while wielding two weapons; off-hand at normal damage; no Raise damage boost on either attack.",
		"xp_cost": 5,
	},

	# -------------------------------------------------------------------------
	# WATER KATAS
	# -------------------------------------------------------------------------
	"Striking as Water": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "water_attack_stance_movement",
		"effect_desc": "In Attack Stance: move 5 additional feet as a Free Action.",
		"xp_cost": 4,
	},
	"Strength of the Lion": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Lion",
		"effect_id": "water_lion_ally_initiative",
		"effect_desc": "Once per Round (Reactions Stage): +3 to Initiative Score of one ally in skirmish (stacks; ends if kata ends).",
		"xp_cost": 3,
	},
	"Son of Storms": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Akodo Bushi", "Shosuro Infiltrator", "Yoritomo Bushi"], "clan": "",
		"effect_id": "water_small_weapon_reduction",
		"effect_desc": "Small melee weapon attacks: opponent Reduction −1.",
		"xp_cost": 3,
	},
	"Strength of the Unicorn": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Unicorn",
		"effect_id": "water_unicorn_mount_bonus",
		"effect_desc": "Mounted: steed +3 Armor TN and +3 Reduction.",
		"xp_cost": 3,
	},
	"Waves upon the Breakers": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Akodo Bushi", "Kakita Bushi", "Shinjo Bushi"], "clan": "",
		"effect_id": "water_skilled_weapon_damage",
		"effect_desc": "Wielding weapon with 3+ Skill Ranks: damage +1k0.",
		"xp_cost": 3,
	},
	"Leaves in the Stream": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Bayushi Bushi", "Hiruma Bushi", "Mirumoto Bushi", "Shiba Bushi"], "clan": "",
		"effect_id": "water_trade_armor_for_movement",
		"effect_desc": "Reduce Armor TN by up to 5×Water Ring (min 5); max movement distance +same amount.",
		"xp_cost": 3,
	},
	"Power of the Tsunami": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Daigotsu Bushi", "Hida Bushi", "Moto Bushi"], "clan": "",
		"effect_id": "water_ignore_reduction",
		"effect_desc": "Once per Round when attacking: ignore Reduction equal to Water Ring.",
		"xp_cost": 4,
	},
	"Strength in Arms Style": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 4,
		"school_mode": "named", "schools": ["Hida Bushi", "Ichiro Bushi", "Moto Bushi"], "clan": "",
		"effect_id": "water_strength_for_attack",
		"effect_desc": "Once per Turn with Heavy Weapon: use Strength instead of Agility for attack roll.",
		"xp_cost": 4,
	},
	"Art of Ninjutsu": {
		"ring": Enums.Ring.WATER, "ring_alt": Enums.Ring.NONE, "mastery": 5,
		"school_mode": "named",
		"schools": ["Daigotsu Bushi", "Bayushi Bushi", "Daidoji Scout", "Shosuro Actor", "Shosuro Infiltrator", "Goju Ninja"],
		"clan": "",
		"effect_id": "water_stealth_movement",
		"effect_desc": "Once per Round: Move distance calculated as if Water Ring = Stealth Skill Rank (does not change maximum distance).",
		"xp_cost": 5,
	},

	# -------------------------------------------------------------------------
	# VOID KATAS
	# -------------------------------------------------------------------------
	"Striking as Void": {
		"ring": Enums.Ring.VOID, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "any", "schools": [], "clan": "",
		"effect_id": "void_center_stance_armor",
		"effect_desc": "In Center Stance: Armor TN +Void Ring.",
		"xp_cost": 3,
	},
	"Balance the Elements Style": {
		"ring": Enums.Ring.VOID, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Mirumoto Bushi", "Shiba Bushi"], "clan": "",
		"effect_id": "void_initiative_void_ring",
		"effect_desc": "Use Void Ring instead of Reflexes for Initiative Rolls.",
		"xp_cost": 3,
	},
	"Strength of Purity Style": {
		"ring": Enums.Ring.VOID, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "named", "schools": ["Akodo Bushi", "Kakita Bushi", "Matsu Berserker", "Utaku Battle Maiden"], "clan": "",
		"effect_id": "void_honor_damage",
		"effect_desc": "Once per Turn when rolling damage: roll Honor Rank dice, keep weapon DR dice as usual.",
		"xp_cost": 3,
	},
	"Strength of the Phoenix": {
		"ring": Enums.Ring.VOID, "ring_alt": Enums.Ring.NONE, "mastery": 3,
		"school_mode": "clan", "schools": [], "clan": "Phoenix",
		"effect_id": "void_phoenix_guard_bonus",
		"effect_desc": "Once per Turn on Guard Action: guarded ally's Armor TN +3.",
		"xp_cost": 3,
	},

	# -------------------------------------------------------------------------
	# MULTI-RING KATAS (Air OR Fire; Mirumoto/Kakita reduce requirement by 1)
	# -------------------------------------------------------------------------
	"The Empire Rests on its Edge": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.FIRE, "mastery": 3,
		"school_mode": "any", "schools": [], "clan": "",
		"mirumoto_kakita_reduce": true,
		"effect_id": "multi_empire_edge_skill_bonus",
		"effect_desc": "Choose one non-combat High Skill (costs +2 XP per Rank increase). While active: +Rank in that Skill to Kenjutsu or Iaijutsu Skill Rolls. Katana or daisho only.",
		"xp_cost": 3,
	},
	"The World Is Empty": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.FIRE, "mastery": 4,
		"school_mode": "any", "schools": [], "clan": "",
		"mirumoto_kakita_reduce": true,
		"effect_id": "multi_world_empty_void_attack",
		"effect_desc": "On activation: +Xk0 to Kenjutsu/Iaijutsu rolls (X = current Void Points); lasts Void Points Rounds; lose 1 Void Point when it ends. Katana or daisho only.",
		"xp_cost": 4,
	},
	"Victory of the River": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.FIRE, "mastery": 5,
		"school_mode": "any", "schools": [], "clan": "",
		"mirumoto_kakita_reduce": true,
		"effect_id": "multi_victory_river_armor_pierce",
		"effect_desc": "On successful strike: target Armor TN −10 vs your attacks for 3 Rounds; your own Armor TN −10 while active. One opponent at a time. Katana or daisho only.",
		"xp_cost": 5,
	},
	"Standing on the Heavens": {
		"ring": Enums.Ring.AIR, "ring_alt": Enums.Ring.FIRE, "mastery": 6,
		"school_mode": "any", "schools": [], "clan": "",
		"mirumoto_kakita_reduce": true,
		"effect_id": "multi_standing_heavens_void_reroll",
		"effect_desc": "Once per Round when struck by a successful attack: spend 1 Void Point (Free Action) to force opponent to immediately reroll the attack. Katana or daisho only.",
		"xp_cost": 6,
	},
}


# === RING HELPER ===

static func _get_ring_rank(character: L5RCharacterData, ring: Enums.Ring) -> int:
	match ring:
		Enums.Ring.AIR:   return mini(character.reflexes, character.awareness)
		Enums.Ring.EARTH: return mini(character.stamina, character.willpower)
		Enums.Ring.FIRE:  return mini(character.agility, character.intelligence)
		Enums.Ring.WATER: return mini(character.strength, character.perception)
		Enums.Ring.VOID:  return character.void_ring
	return 0


# Returns true when this character's school qualifies for the given entry's
# Mirumoto/Kakita ring reduction (requirement −1).
static func _has_mirumoto_kakita_reduction(character: L5RCharacterData) -> bool:
	return character.school_name in ["Mirumoto Bushi", "Kakita Bushi"]


# === ELIGIBILITY ===

## Returns true if the character meets all requirements to learn `kata_name`.
## Does NOT check XP cost — call can_afford() separately.
## Rejects school-less characters (no school_type == BUSHI recognition without a school).
static func can_learn_kata(character: L5RCharacterData, kata_name: String) -> bool:
	if not KATA_DATA.has(kata_name):
		return false

	# Must be a bushi with an actual school designation.
	if character.school_type != Enums.SchoolType.BUSHI:
		return false
	if character.school_name.is_empty():
		return false

	# Must not already know it.
	if character.katas.has(kata_name):
		return false

	var kata: Dictionary = KATA_DATA[kata_name]
	var mastery: int = kata["mastery"]

	# Determine effective ring requirement (may be reduced for Mirumoto/Kakita).
	var effective_mastery: int = mastery
	if kata.get("mirumoto_kakita_reduce", false) and _has_mirumoto_kakita_reduction(character):
		effective_mastery = maxi(2, mastery - 1)

	# Check ring requirement (primary, or primary OR alt for multi-ring katas).
	var primary_ok: bool = _get_ring_rank(character, kata["ring"]) >= effective_mastery
	var alt_ring: Enums.Ring = kata.get("ring_alt", Enums.Ring.NONE)
	var alt_ok: bool = (alt_ring != Enums.Ring.NONE) and (_get_ring_rank(character, alt_ring) >= effective_mastery)
	if not (primary_ok or alt_ok):
		return false

	# Check school eligibility.
	return _school_eligible(character, kata)


## Returns true if the character can afford the XP cost of `kata_name`.
## Available XP = xp_total − xp_spent (the same pool used by progress bars).
static func can_afford_kata(character: L5RCharacterData, kata_name: String) -> bool:
	if not KATA_DATA.has(kata_name):
		return false
	var available: int = character.xp_total - character.xp_spent
	return available >= KATA_DATA[kata_name]["xp_cost"]


## Returns the list of kata names the character is eligible to learn (ring + school).
## Does NOT filter by XP.
static func get_eligible_katas(character: L5RCharacterData) -> Array:
	var result: Array = []
	for kata_name: String in KATA_DATA.keys():
		if can_learn_kata(character, kata_name):
			result.append(kata_name)
	return result


static func _school_eligible(character: L5RCharacterData, kata: Dictionary) -> bool:
	var mode: String = kata["school_mode"]
	match mode:
		"any":
			return true
		"clan":
			return character.clan == kata["clan"]
		"named":
			var schools: Array = kata["schools"]
			if character.school_name in schools:
				return true
			# Also check school_paths for multi-school characters.
			for path: String in character.school_paths:
				if path in schools:
					return true
			return false
		_:
			return false


# === ACQUISITION ===

## Teaches `kata_name` to the character and deducts the XP cost.
## Returns true on success, false if ineligible or insufficient XP.
static func learn_kata(character: L5RCharacterData, kata_name: String) -> bool:
	if not can_learn_kata(character, kata_name):
		return false
	if not can_afford_kata(character, kata_name):
		return false
	var xp_cost: int = KATA_DATA[kata_name]["xp_cost"]
	character.xp_spent += xp_cost
	character.katas.append(kata_name)
	return true


# === NPC SELECTION ===

## Selects the best kata for an NPC to learn this season.
## Preference: highest mastery level affordable and eligible, alpha tie-break.
## Returns "" if no kata is learnable.
static func select_kata_for_npc(character: L5RCharacterData) -> String:
	var candidates: Array = []
	for kata_name: String in KATA_DATA.keys():
		if can_learn_kata(character, kata_name) and can_afford_kata(character, kata_name):
			candidates.append(kata_name)

	if candidates.is_empty():
		return ""

	# Sort: highest mastery first, then alphabetical for determinism.
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ma: int = KATA_DATA[a]["mastery"]
		var mb: int = KATA_DATA[b]["mastery"]
		if ma != mb:
			return ma > mb
		return a < b
	)
	return candidates[0]


# === EFFECT REGISTRY (stub — all effects blocked on s40) ===

## Returns the effect stub dict for a kata.
## The "blocked_on" key signals that no mechanical change is applied.
static func get_effect_stub(kata_name: String) -> Dictionary:
	if not KATA_DATA.has(kata_name):
		return {}
	var kata: Dictionary = KATA_DATA[kata_name]
	return {
		"effect_id": kata["effect_id"],
		"blocked_on": "s40",
		"effect_desc": kata["effect_desc"],
	}
