class_name ArmorSystem
## s40 Armor catalog + special-rule TN penalties. Pure functions — no Node, no state.
## Stats transcribed from the L5R 4e Equipment armor table (owner-provided 2026-06-29);
## zero invention. The Armor TN bonus and damage Reduction are consumed via the
## character's armor_tn_bonus / armor_reduction fields (CharacterStats.get_armor_tn,
## IndividualCombat.total_defender_reduction). The skill-TN penalties are applied in
## SkillResolver.resolve_skill_check / resolve_contested_check via get_skill_tn_penalty().

const PENALTY_AMOUNT: int = 5        # the standard +5 TN special-rule penalty
const IRON_PENALTY_AMOUNT: int = 10  # Tetsu-do +10 (or +5 if Strength >= 5)
const IRON_STRENGTH_RELIEF: int = 5  # Strength threshold that halves the iron penalty

# name -> {tn_bonus, reduction, is_heavy, penalty_kind}. Penalty kinds: see ArmorData.
const ARMOR_CATALOG: Dictionary = {
	"bogu":          {"tn_bonus": 0,  "reduction": 1, "is_heavy": false, "penalty_kind": "none"},
	"ashigaru":      {"tn_bonus": 3,  "reduction": 1, "is_heavy": false, "penalty_kind": "none"},
	"tatami":        {"tn_bonus": 4,  "reduction": 1, "is_heavy": false, "penalty_kind": "none"},
	"light":         {"tn_bonus": 5,  "reduction": 3, "is_heavy": false, "penalty_kind": "athletics_stealth"},
	"heavy":         {"tn_bonus": 10, "reduction": 5, "is_heavy": true,  "penalty_kind": "agi_ref"},
	# Tetsu-do (iron): counts as heavy armor for mechanical effects.
	"tetsu_do":      {"tn_bonus": 13, "reduction": 8, "is_heavy": true,  "penalty_kind": "agi_ref_iron"},
	# Riding armor: Armor TN +12 on horseback / +4 otherwise. The off-horseback bonus
	# (+4) is stored; the mounted +12 is a combat/mount detail not modeled here.
	"riding":        {"tn_bonus": 4,  "reduction": 4, "is_heavy": false, "penalty_kind": "agi_ref_not_mounted"},
}


# Build a typed ArmorData from the catalog (null for an unknown name).
static func make_armor(armor_name: String) -> ArmorData:
	if not ARMOR_CATALOG.has(armor_name):
		return null
	var spec: Dictionary = ARMOR_CATALOG[armor_name]
	var a := ArmorData.new()
	a.armor_name = armor_name
	a.tn_bonus = int(spec["tn_bonus"])
	a.reduction = int(spec["reduction"])
	a.is_heavy = bool(spec["is_heavy"])
	a.penalty_kind = String(spec["penalty_kind"])
	return a


# Equip armor on a character: sets armor_worn and mirrors tn_bonus / reduction onto the
# fast-lookup fields the combat math reads. Passing "" / unknown clears worn armor.
static func equip(character: L5RCharacterData, armor_name: String) -> void:
	var a: ArmorData = make_armor(armor_name)
	character.armor_worn = a
	if a == null:
		character.armor_tn_bonus = 0
		character.armor_reduction = 0
	else:
		character.armor_tn_bonus = a.tn_bonus
		character.armor_reduction = a.reduction


# The +TN penalty the worn armor imposes on a specific skill roll (0 if none). POSITIVE =
# harder; SkillResolver SUBTRACTS this from the roll total (matching the wound-penalty
# convention). on_horseback exempts Riding armor.
static func get_skill_tn_penalty(
	character: L5RCharacterData, skill_name: String, trait_used: Enums.Trait, on_horseback: bool = false
) -> int:
	var a: ArmorData = character.armor_worn
	if a == null:
		return 0
	match a.penalty_kind:
		"athletics_stealth":
			return PENALTY_AMOUNT if _base_skill(skill_name) in ["Athletics", "Stealth"] else 0
		"agi_ref":
			return PENALTY_AMOUNT if _is_agi_ref(trait_used) else 0
		"agi_ref_iron":
			if not _is_agi_ref(trait_used):
				return 0
			return IRON_STRENGTH_RELIEF if character.strength >= IRON_STRENGTH_RELIEF else IRON_PENALTY_AMOUNT
		"agi_ref_not_mounted":
			if on_horseback:
				return 0
			return PENALTY_AMOUNT if _is_agi_ref(trait_used) else 0
	return 0


static func _is_agi_ref(trait_used: Enums.Trait) -> bool:
	return trait_used == Enums.Trait.AGILITY or trait_used == Enums.Trait.REFLEXES


static func _base_skill(skill_name: String) -> String:
	var c: int = skill_name.find(":")
	if c >= 0:
		return skill_name.substr(0, c).strip_edges()
	return skill_name
