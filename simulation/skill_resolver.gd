class_name SkillResolver
## Resolves skill checks by looking up the correct trait for a skill,
## pulling the character's rank and emphases, applying wound penalties,
## and calling DiceEngine. All skill-based rolling goes through here.

# Skill -> default Trait mapping per L5R4e Section 24.
# Macro-skills (Lore, Perform, Craft, etc.) share one entry — sub-skills
# use the same trait unless overridden below.
const SKILL_TRAITS: Dictionary = {
	# -- High Skills --
	"Acting": Enums.Trait.AWARENESS,
	"Artisan": Enums.Trait.AWARENESS,
	"Calligraphy": Enums.Trait.INTELLIGENCE,
	"Courtier": Enums.Trait.AWARENESS,
	"Divination": Enums.Trait.INTELLIGENCE,
	"Etiquette": Enums.Trait.AWARENESS,
	"Games": Enums.Trait.AWARENESS,
	"Investigation": Enums.Trait.PERCEPTION,
	"Lore": Enums.Trait.INTELLIGENCE,
	"Medicine": Enums.Trait.INTELLIGENCE,
	"Meditation": Enums.Trait.VOID,
	"Perform": Enums.Trait.AWARENESS,
	"Sincerity": Enums.Trait.AWARENESS,
	"Spellcraft": Enums.Trait.INTELLIGENCE,
	"Tea Ceremony": Enums.Trait.VOID,
	# -- Bugei Skills --
	"Athletics": Enums.Trait.STRENGTH,
	"Battle": Enums.Trait.PERCEPTION,
	"Defense": Enums.Trait.REFLEXES,
	"Horsemanship": Enums.Trait.AGILITY,
	"Hunting": Enums.Trait.PERCEPTION,
	"Iaijutsu": Enums.Trait.REFLEXES,
	"Jiujutsu": Enums.Trait.AGILITY,
	"Kenjutsu": Enums.Trait.AGILITY,
	"Kyujutsu": Enums.Trait.REFLEXES,
	"Spears": Enums.Trait.AGILITY,
	"Polearms": Enums.Trait.AGILITY,
	"Heavy Weapons": Enums.Trait.AGILITY,
	"Knives": Enums.Trait.AGILITY,
	"War Fan": Enums.Trait.AGILITY,
	"Chain Weapons": Enums.Trait.AGILITY,
	"Staves": Enums.Trait.AGILITY,
	"Ninjutsu": Enums.Trait.AGILITY,
	# -- Merchant Skills --
	"Animal Handling": Enums.Trait.AWARENESS,
	"Commerce": Enums.Trait.INTELLIGENCE,
	"Craft": Enums.Trait.INTELLIGENCE,
	"Engineering": Enums.Trait.INTELLIGENCE,
	"Sailing": Enums.Trait.INTELLIGENCE,
	# -- Low Skills --
	"Forgery": Enums.Trait.AGILITY,
	"Intimidation": Enums.Trait.WILLPOWER,
	"Sleight of Hand": Enums.Trait.AGILITY,
	"Stealth": Enums.Trait.AGILITY,
	"Temptation": Enums.Trait.AWARENESS,
}

# Sub-skills that use a different trait than their parent macro-skill.
const SUB_SKILL_TRAIT_OVERRIDES: Dictionary = {
	# Perform sub-skills using Agility
	"Perform: Biwa": Enums.Trait.AGILITY,
	"Perform: Dance": Enums.Trait.AGILITY,
	"Perform: Drums": Enums.Trait.AGILITY,
	"Perform: Flute": Enums.Trait.AGILITY,
	"Perform: Puppeteer": Enums.Trait.AGILITY,
	"Perform: Samisen": Enums.Trait.AGILITY,
	# Perform sub-skills using Awareness (default, listed for completeness)
	"Perform: Oratory": Enums.Trait.AWARENESS,
	"Perform: Song": Enums.Trait.AWARENESS,
	"Perform: Storytelling": Enums.Trait.AWARENESS,
	# Games sub-skills
	"Games: Go": Enums.Trait.INTELLIGENCE,
	"Games: Shogi": Enums.Trait.INTELLIGENCE,
	"Games: Kemari": Enums.Trait.AGILITY,
	# Sailing can use Agility for physical maneuvers
	"Sailing: Knot-work": Enums.Trait.AGILITY,
	# Athletics throwing offensively uses Agility
	"Athletics: Throwing": Enums.Trait.AGILITY,
}


static func get_trait_for_skill(skill_name: String) -> Enums.Trait:
	if SUB_SKILL_TRAIT_OVERRIDES.has(skill_name):
		return SUB_SKILL_TRAIT_OVERRIDES[skill_name]

	# Check for "Parent: Sub" format — look up the parent
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		var parent: String = skill_name.substr(0, colon_pos).strip_edges()
		if SKILL_TRAITS.has(parent):
			return SKILL_TRAITS[parent]

	if SKILL_TRAITS.has(skill_name):
		return SKILL_TRAITS[skill_name]

	# Unknown skill — default to Awareness (least harmful fallback)
	return Enums.Trait.AWARENESS


static func get_skill_rank(character: L5RCharacterData, skill_name: String) -> int:
	if character.skills.has(skill_name):
		return character.skills[skill_name]

	# Check parent macro-skill for "Parent: Sub" format
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		var parent: String = skill_name.substr(0, colon_pos).strip_edges()
		if character.skills.has(parent):
			return character.skills[parent]

	return 0


static func has_emphasis(character: L5RCharacterData, skill_name: String, emphasis_name: String) -> bool:
	# Check exact skill name first, then parent
	var check_names: Array[String] = [skill_name]
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		check_names.append(skill_name.substr(0, colon_pos).strip_edges())

	for name: String in check_names:
		if character.emphases.has(name):
			var emph_list: Array = character.emphases[name]
			if emphasis_name in emph_list:
				return true
	return false


# -- School Technique Free Raises (s29.15) -------------------------------------

const DOJI_HONOR_THRESHOLD: float = 6.0
const DOJI_FREE_RAISE_SKILLS: Array[String] = ["Courtier", "Sincerity", "Etiquette"]
const FREE_RAISE_VALUE: int = 5

static func get_technique_free_raises(character: L5RCharacterData, skill_name: String) -> int:
	var free_raises: int = 0
	var base_skill: String = skill_name
	var colon_pos: int = skill_name.find(":")
	if colon_pos >= 0:
		base_skill = skill_name.substr(0, colon_pos).strip_edges()

	if character.school.begins_with("Doji Courtier") and character.honor >= DOJI_HONOR_THRESHOLD:
		if base_skill in DOJI_FREE_RAISE_SKILLS:
			free_raises += 1
	if character.school.begins_with("Yasuki Courtier") and base_skill == "Commerce":
		free_raises += 1
	if character.school.begins_with("Kitsuki Investigator") and base_skill == "Investigation":
		free_raises += 1
	if character.school.begins_with("Asako Loremaster") and base_skill == "Lore":
		free_raises += 1
	return free_raises


# -- Deception Defense TN Modifier (s29.15.6 Kitsuki R2, s29.15.2 Yasuki R4) --

const DECEPTION_TN_PER_RANK: int = 5

const DECEPTIVE_ACTION_IDS: Array[String] = [
	"GOSSIP", "FABRICATE_SECRET", "FORGE_IMPERSONATION_LETTER", "FORGE_ORDER",
]

static func get_deception_defense_bonus(defender: L5RCharacterData) -> int:
	var school_rank: int = CharacterStats.get_insight_rank(defender)
	if defender.school.begins_with("Kitsuki Investigator") and school_rank >= 2:
		return DECEPTION_TN_PER_RANK * school_rank
	if defender.school.begins_with("Yasuki Courtier") and school_rank >= 4:
		return DECEPTION_TN_PER_RANK * school_rank
	return 0


# -- The main entry point: resolve a full skill check --------------------------

static func resolve_skill_check(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_name: String,
	tn: int,
	raises: int = 0,
	emphasis_name: String = "",
	trait_override: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled: int = 0,
	bonus_kept: int = 0,
	flat_bonus: int = 0,
) -> Dictionary:
	# Determine trait
	var trait_used: Enums.Trait
	if trait_override != Enums.Trait.NONE:
		trait_used = trait_override
	else:
		trait_used = get_trait_for_skill(skill_name)

	var trait_value: int = character.get_trait_value(trait_used)
	var skill_rank: int = get_skill_rank(character, skill_name)

	# Emphasis check
	var has_emph: bool = false
	if emphasis_name != "":
		has_emph = has_emphasis(character, skill_name, emphasis_name)

	# Wound penalty applies to all Trait rolls
	var wound_penalty: int = CharacterStats.get_wound_penalty(character)

	# School technique free raises (s29.15)
	var technique_fr: int = get_technique_free_raises(character, skill_name)

	# Build the pool: (trait + skill + bonus_rolled) k (trait + bonus_kept)
	var rolled: int = trait_value + skill_rank + bonus_rolled
	var kept: int = trait_value + bonus_kept
	var total_bonus: int = flat_bonus + wound_penalty + (technique_fr * FREE_RAISE_VALUE)

	# Unskilled: no explosions
	var explodes: bool = skill_rank > 0

	var result: Dictionary = dice_engine.roll_check(
		rolled, kept, tn, raises, total_bonus, explodes, has_emph
	)

	result["skill"] = skill_name
	result["trait_used"] = trait_used
	result["skill_rank"] = skill_rank
	result["wound_penalty"] = wound_penalty
	result["emphasis_applied"] = has_emph
	result["technique_free_raises"] = technique_fr

	return result


# -- Contested skill check between two characters ------------------------------

static func resolve_contested_check(
	char_a: L5RCharacterData,
	char_b: L5RCharacterData,
	dice_engine: DiceEngine,
	skill_a: String,
	skill_b: String,
	emphasis_a: String = "",
	emphasis_b: String = "",
	trait_override_a: Enums.Trait = Enums.Trait.NONE,
	trait_override_b: Enums.Trait = Enums.Trait.NONE,
	bonus_rolled_a: int = 0,
	bonus_rolled_b: int = 0,
	flat_bonus_a: int = 0,
	flat_bonus_b: int = 0,
) -> Dictionary:
	# Character A
	var trait_a: Enums.Trait = trait_override_a if trait_override_a != Enums.Trait.NONE else get_trait_for_skill(skill_a)
	var tv_a: int = char_a.get_trait_value(trait_a)
	var sr_a: int = get_skill_rank(char_a, skill_a)
	var emph_a: bool = has_emphasis(char_a, skill_a, emphasis_a) if emphasis_a != "" else false
	var wp_a: int = CharacterStats.get_wound_penalty(char_a)
	var tfr_a: int = get_technique_free_raises(char_a, skill_a)

	# Character B
	var trait_b: Enums.Trait = trait_override_b if trait_override_b != Enums.Trait.NONE else get_trait_for_skill(skill_b)
	var tv_b: int = char_b.get_trait_value(trait_b)
	var sr_b: int = get_skill_rank(char_b, skill_b)
	var emph_b: bool = has_emphasis(char_b, skill_b, emphasis_b) if emphasis_b != "" else false
	var wp_b: int = CharacterStats.get_wound_penalty(char_b)
	var tfr_b: int = get_technique_free_raises(char_b, skill_b)

	var roll_a: DiceResult = dice_engine.roll_and_keep(
		tv_a + sr_a + bonus_rolled_a, tv_a, sr_a > 0, emph_a
	)
	var roll_b: DiceResult = dice_engine.roll_and_keep(
		tv_b + sr_b + bonus_rolled_b, tv_b, sr_b > 0, emph_b
	)

	var total_a: int = roll_a.total + flat_bonus_a + wp_a + (tfr_a * FREE_RAISE_VALUE)
	var total_b: int = roll_b.total + flat_bonus_b + wp_b + (tfr_b * FREE_RAISE_VALUE)

	var winner: String = "a"
	if total_b > total_a:
		winner = "b"
	elif total_a == total_b:
		winner = "tie"

	return {
		"winner": winner,
		"total_a": total_a,
		"total_b": total_b,
		"dice_a": roll_a,
		"dice_b": roll_b,
		"wound_penalty_a": wp_a,
		"wound_penalty_b": wp_b,
	}
