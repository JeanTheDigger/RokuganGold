class_name WorldGenerator
## Factory methods for seeding initial world state.
## Generates L5RCharacterData and ProvinceData from clan/family/school
## parameters using GDD s22.4 generation templates and s4.3 resource rules.
## Coordinate system and adjacency are deferred — not set here.


# === FAMILY TRAIT BONUSES ===

const FAMILY_TRAIT_BONUS: Dictionary = {
	"Hida": "stamina",
	"Hiruma": "agility",
	"Kaiu": "intelligence",
	"Kuni": "intelligence",
	"Toritaka": "perception",
	"Yasuki": "awareness",
	"Doji": "awareness",
	"Daidoji": "agility",
	"Kakita": "reflexes",
	"Asahina": "intelligence",
	"Mirumoto": "agility",
	"Kitsuki": "perception",
	"Togashi": "reflexes",
	"Tamori": "awareness",
	"Akodo": "intelligence",
	"Matsu": "strength",
	"Ikoma": "awareness",
	"Kitsu": "intelligence",
	"Yoritomo": "strength",
	"Moshi": "awareness",
	"Tsuruchi": "reflexes",
	"Shiba": "perception",
	"Isawa": "intelligence",
	"Asako": "intelligence",
	"Agasha": "intelligence",
	"Bayushi": "agility",
	"Shosuro": "awareness",
	"Soshi": "intelligence",
	"Yogo": "willpower",
	"Shinjo": "reflexes",
	"Ide": "awareness",
	"Iuchi": "willpower",
	"Moto": "perception",
	"Utaku": "stamina",
	"Horiuchi": "perception",
	"Otomo": "awareness",
	"Seppun": "reflexes",
	"Miya": "intelligence",
	"Ichiro": "stamina",
	"Tonbo": "awareness",
	"Kitsune": "willpower",
	"Usagi": "agility",
	"Toku": "stamina",
	"Morito": "strength",
	"Suzume": "awareness",
	"Kasuga": "awareness",
}


# === SCHOOL DATA ===
# benefit: school benefit trait (+1). honor: starting honor.
# skills: starting skill list at rank 1. wildcards: category pools for
# the "any one X" slots. focus_rings: primary rings for trait advancement.
# skill_rank_2: skills that start at rank 2 instead of 1.

const SCHOOL_DATA: Dictionary = {
	# -- Crab --
	"Hida Bushi": {
		"clan": "Crab", "family": "Hida",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "stamina", "honor": 3.5,
		"skills": ["Athletics", "Defense", "Heavy Weapons", "Intimidation", "Kenjutsu", "Lore: Shadowlands"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Hiruma Bushi": {
		"clan": "Crab", "family": "Hiruma",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "willpower", "honor": 4.5,
		"skills": ["Athletics", "Hunting", "Kenjutsu", "Kyujutsu", "Lore: Shadowlands", "Stealth"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Kaiu Engineer": {
		"clan": "Crab", "family": "Kaiu",
		"type": Enums.SchoolType.ARTISAN,
		"benefit": "intelligence", "honor": 4.5,
		"skills": ["Battle", "Craft: Armorsmithing", "Craft: Weaponsmithing", "Defense", "Engineering", "Lore: Architecture", "War Fan"],
		"wildcards": [],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Kuni Shugenja": {
		"clan": "Crab", "family": "Kuni",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "willpower", "honor": 2.5,
		"skills": ["Calligraphy", "Defense", "Lore: Shadowlands", "Lore: Theology", "Spellcraft"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": ["Lore: Shadowlands"],
		"affinity": Enums.Ring.EARTH, "deficiency": Enums.Ring.AIR,
	},
	"Yasuki Courtier": {
		"clan": "Crab", "family": "Yasuki",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "perception", "honor": 2.5,
		"skills": ["Commerce", "Courtier", "Defense", "Etiquette", "Intimidation", "Sincerity"],
		"wildcards": ["Merchant"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	# -- Crane --
	"Kakita Bushi": {
		"clan": "Crane", "family": "Kakita",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "reflexes", "honor": 6.5,
		"skills": ["Etiquette", "Iaijutsu", "Kenjutsu", "Kyujutsu", "Sincerity", "Tea Ceremony"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Daidoji Iron Warrior": {
		"clan": "Crane", "family": "Daidoji",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "agility", "honor": 6.5,
		"skills": ["Battle", "Iaijutsu", "Kenjutsu", "Kyujutsu"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.FIRE],
		"skill_rank_2": ["Defense"],
	},
	"Doji Courtier": {
		"clan": "Crane", "family": "Doji",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "awareness", "honor": 6.5,
		"skills": ["Calligraphy", "Courtier", "Etiquette", "Perform: Storytelling", "Sincerity", "Tea Ceremony"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Asahina Shugenja": {
		"clan": "Crane", "family": "Asahina",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "awareness", "honor": 6.5,
		"skills": ["Calligraphy", "Etiquette", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High", "High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
		"affinity": Enums.Ring.AIR, "deficiency": Enums.Ring.FIRE,
	},
	# -- Dragon --
	"Mirumoto Bushi": {
		"clan": "Dragon", "family": "Mirumoto",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "agility", "honor": 4.5,
		"skills": ["Athletics", "Defense", "Iaijutsu", "Kenjutsu", "Lore: Shugenja", "Meditation"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.FIRE, Enums.Ring.AIR],
		"skill_rank_2": ["Kenjutsu"],
	},
	"Kitsuki Investigator": {
		"clan": "Dragon", "family": "Kitsuki",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "perception", "honor": 6.5,
		"skills": ["Courtier", "Etiquette", "Investigation", "Kenjutsu", "Meditation", "Sincerity"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Tamori Shugenja": {
		"clan": "Dragon", "family": "Tamori",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "stamina", "honor": 2.5,
		"skills": ["Athletics", "Calligraphy", "Defense", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.FIRE],
		"skill_rank_2": [],
		"affinity": Enums.Ring.EARTH, "deficiency": Enums.Ring.AIR,
	},
	"Togashi Tattooed Order": {
		"clan": "Dragon", "family": "Togashi",
		"type": Enums.SchoolType.MONK,
		"benefit": "reflexes", "honor": 4.5,
		"skills": ["Athletics", "Defense", "Jiujutsu", "Lore: Theology", "Meditation"],
		"wildcards": ["High", "Bugei"],
		"focus_rings": [Enums.Ring.VOID, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	# -- Lion --
	"Akodo Bushi": {
		"clan": "Lion", "family": "Akodo",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "perception", "honor": 6.5,
		"skills": ["Battle", "Defense", "Kenjutsu", "Kyujutsu", "Lore: History", "Sincerity"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Matsu Berserker": {
		"clan": "Lion", "family": "Matsu",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "strength", "honor": 6.5,
		"skills": ["Battle", "Jiujutsu", "Kenjutsu", "Kyujutsu", "Lore: History"],
		"wildcards": ["Bugei", "Bugei"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Ikoma Bard": {
		"clan": "Lion", "family": "Ikoma",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "intelligence", "honor": 6.5,
		"skills": ["Courtier", "Etiquette", "Lore: History", "Perform: Storytelling", "Sincerity"],
		"wildcards": ["High", "Bugei"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Kitsu Shugenja": {
		"clan": "Lion", "family": "Kitsu",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "perception", "honor": 6.5,
		"skills": ["Battle", "Calligraphy", "Etiquette", "Lore: History", "Lore: Theology", "Spellcraft"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.EARTH],
		"skill_rank_2": [],
		"affinity": Enums.Ring.WATER, "deficiency": Enums.Ring.FIRE,
	},
	# -- Phoenix --
	"Shiba Bushi": {
		"clan": "Phoenix", "family": "Shiba",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "perception", "honor": 5.5,
		"skills": ["Defense", "Kenjutsu", "Kyujutsu", "Meditation", "Spears", "Lore: Theology"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.EARTH],
		"skill_rank_2": [],
	},
	"Isawa Shugenja": {
		"clan": "Phoenix", "family": "Isawa",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "intelligence", "honor": 4.5,
		"skills": ["Calligraphy", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High", "High", "High"],
		"focus_rings": [Enums.Ring.FIRE, Enums.Ring.AIR],
		"skill_rank_2": [],
		"affinity": Enums.Ring.NONE, "deficiency": Enums.Ring.NONE,
	},
	"Asako Loremaster": {
		"clan": "Phoenix", "family": "Asako",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "intelligence", "honor": 6.5,
		"skills": ["Courtier", "Etiquette", "Lore: History", "Lore: Theology", "Meditation", "Sincerity"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	# -- Scorpion --
	"Bayushi Bushi": {
		"clan": "Scorpion", "family": "Bayushi",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "intelligence", "honor": 2.5,
		"skills": ["Courtier", "Defense", "Etiquette", "Iaijutsu", "Kenjutsu", "Sincerity"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Bayushi Courtier": {
		"clan": "Scorpion", "family": "Bayushi",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "awareness", "honor": 2.5,
		"skills": ["Calligraphy", "Courtier", "Etiquette", "Investigation", "Sincerity", "Temptation"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Soshi Shugenja": {
		"clan": "Scorpion", "family": "Soshi",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "awareness", "honor": 2.5,
		"skills": ["Calligraphy", "Courtier", "Etiquette", "Lore: Theology", "Spellcraft", "Stealth"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.EARTH],
		"skill_rank_2": [],
		"affinity": Enums.Ring.AIR, "deficiency": Enums.Ring.EARTH,
	},
	"Shosuro Infiltrator": {
		"clan": "Scorpion", "family": "Shosuro",
		"type": Enums.SchoolType.NINJA,
		"benefit": "reflexes", "honor": 1.5,
		"skills": ["Acting", "Athletics", "Ninjutsu", "Sincerity", "Stealth"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": ["Stealth"],
	},
	# -- Unicorn --
	"Shinjo Bushi": {
		"clan": "Unicorn", "family": "Shinjo",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "agility", "honor": 4.5,
		"skills": ["Athletics", "Defense", "Kenjutsu", "Kyujutsu"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.FIRE],
		"skill_rank_2": ["Horsemanship"],
	},
	"Moto Bushi": {
		"clan": "Unicorn", "family": "Moto",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "strength", "honor": 3.5,
		"skills": ["Athletics", "Defense", "Horsemanship", "Hunting", "Kenjutsu"],
		"wildcards": ["Bugei", "Skill"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.EARTH],
		"skill_rank_2": [],
	},
	"Ide Emissary": {
		"clan": "Unicorn", "family": "Ide",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "awareness", "honor": 5.5,
		"skills": ["Calligraphy", "Commerce", "Courtier", "Etiquette", "Horsemanship", "Sincerity"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Iuchi Shugenja": {
		"clan": "Unicorn", "family": "Iuchi",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "perception", "honor": 5.5,
		"skills": ["Battle", "Calligraphy", "Horsemanship", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.EARTH],
		"skill_rank_2": [],
		"affinity": Enums.Ring.WATER, "deficiency": Enums.Ring.FIRE,
	},
	"Utaku Battle Maiden": {
		"clan": "Unicorn", "family": "Utaku",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "reflexes", "honor": 6.5,
		"skills": ["Battle", "Defense", "Kenjutsu", "Sincerity"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": ["Horsemanship"],
	},
	# -- Mantis --
	"Yoritomo Bushi": {
		"clan": "Mantis", "family": "Yoritomo",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "strength", "honor": 3.5,
		"skills": ["Commerce", "Defense", "Jiujutsu", "Kenjutsu", "Knives", "Sailing"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Moshi Shugenja": {
		"clan": "Mantis", "family": "Moshi",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "awareness", "honor": 4.5,
		"skills": ["Calligraphy", "Divination", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High", "High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
		"affinity": Enums.Ring.AIR, "deficiency": Enums.Ring.EARTH,
	},
	"Tsuruchi Archer": {
		"clan": "Mantis", "family": "Tsuruchi",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "reflexes", "honor": 3.5,
		"skills": ["Athletics", "Defense", "Hunting", "Investigation", "Kyujutsu"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": ["Kyujutsu"],
	},
	"Toritaka Bushi": {
		"clan": "Crab", "family": "Toritaka",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "awareness", "honor": 2.5,
		"skills": ["Athletics", "Defense", "Hunting", "Intimidation", "Kenjutsu", "Lore: Spirit Realms"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.EARTH],
		"skill_rank_2": [],
	},
	"Agasha Shugenja": {
		"clan": "Phoenix", "family": "Agasha",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "intelligence", "honor": 2.5,
		"skills": ["Calligraphy", "Defense", "Craft: Alchemy", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.FIRE, Enums.Ring.EARTH],
		"skill_rank_2": [],
		"affinity": Enums.Ring.FIRE, "deficiency": Enums.Ring.AIR,
	},
	"Yogo Wardmaster": {
		"clan": "Scorpion", "family": "Yogo",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "willpower", "honor": 1.5,
		"skills": ["Calligraphy", "Defense", "Lore: Theology", "Meditation", "Spellcraft", "Stealth"],
		"wildcards": ["Low"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.FIRE],
		"skill_rank_2": [],
		"affinity": Enums.Ring.EARTH, "deficiency": Enums.Ring.AIR,
	},
	# --- Minor Clan Schools ---
	"Ichiro Bushi": {
		"clan": "Badger", "family": "Ichiro",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "stamina", "honor": 3.5,
		"skills": ["Athletics", "Defense", "Heavy Weapons", "Hunting", "Intimidation", "Jiujutsu"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Tonbo Shugenja": {
		"clan": "Dragonfly", "family": "Tonbo",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "awareness", "honor": 3.5,
		"skills": ["Calligraphy", "Etiquette", "Lore: Theology", "Meditation", "Spellcraft"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.VOID, Enums.Ring.AIR],
		"skill_rank_2": [],
		"affinity": Enums.Ring.VOID, "deficiency": Enums.Ring.FIRE,
	},
	"Kitsune Shugenja": {
		"clan": "Fox", "family": "Kitsune",
		"type": Enums.SchoolType.SHUGENJA,
		"benefit": "willpower", "honor": 2.5,
		"skills": ["Athletics", "Calligraphy", "Hunting", "Lore: Spirit Realms", "Meditation", "Spellcraft"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
		"affinity": Enums.Ring.EARTH, "deficiency": Enums.Ring.AIR,
	},
	"Usagi Bushi": {
		"clan": "Hare", "family": "Usagi",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "agility", "honor": 3.5,
		"skills": ["Athletics", "Defense", "Hunting", "Kenjutsu", "Stealth"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.WATER, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Toku Bushi": {
		"clan": "Monkey", "family": "Toku",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "stamina", "honor": 4.5,
		"skills": ["Athletics", "Defense", "Jiujutsu", "Kenjutsu", "Lore: Theology"],
		"wildcards": ["Skill"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Morito Bushi": {
		"clan": "Ox", "family": "Morito",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "strength", "honor": 2.5,
		"skills": ["Athletics", "Battle", "Defense", "Horsemanship", "Kenjutsu"],
		"wildcards": ["Bugei"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Suzume Bushi": {
		"clan": "Sparrow", "family": "Suzume",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "awareness", "honor": 4.5,
		"skills": ["Athletics", "Defense", "Kenjutsu", "Lore: History", "Storytelling"],
		"wildcards": ["Bugei", "High"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.AIR],
		"skill_rank_2": [],
	},
	"Kasuga Smuggler": {
		"clan": "Tortoise", "family": "Kasuga",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "awareness", "honor": 1.5,
		"skills": ["Commerce", "Etiquette", "Investigation", "Sincerity", "Sleight of Hand", "Stealth"],
		"wildcards": ["Low"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	# --- Imperial Schools ---
	"Otomo Courtier": {
		"clan": "Imperial", "family": "Otomo",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "awareness", "honor": 3.5,
		"skills": ["Calligraphy", "Courtier", "Etiquette", "Investigation", "Sincerity", "Temptation"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.FIRE],
		"skill_rank_2": [],
	},
	"Seppun Guardsman": {
		"clan": "Imperial", "family": "Seppun",
		"type": Enums.SchoolType.BUSHI,
		"benefit": "reflexes", "honor": 4.5,
		"skills": ["Battle", "Defense", "Iaijutsu", "Kenjutsu", "Kyujutsu", "Spellcraft"],
		"wildcards": ["High", "Bugei"],
		"focus_rings": [Enums.Ring.EARTH, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
	"Miya Herald": {
		"clan": "Imperial", "family": "Miya",
		"type": Enums.SchoolType.COURTIER,
		"benefit": "intelligence", "honor": 4.5,
		"skills": ["Calligraphy", "Courtier", "Etiquette", "Horsemanship", "Lore: History", "Sincerity"],
		"wildcards": ["High"],
		"focus_rings": [Enums.Ring.AIR, Enums.Ring.WATER],
		"skill_rank_2": [],
	},
}


# === PERSONALITY WEIGHTS ===
# Weighted distributions per GDD s22.4. Higher = more likely.
# Keys are BushidoVirtue / ShouridoVirtue int values.

const CLAN_BUSHIDO_WEIGHTS: Dictionary = {
	"Crab":    {0: 5,  1: 30, 2: 5,  3: 25, 4: 10, 5: 10, 6: 10},
	"Crane":   {0: 10, 1: 10, 2: 30, 3: 10, 4: 25, 5: 10, 6: 10},
	"Dragon":  {0: 10, 1: 10, 2: 10, 3: 10, 4: 10, 5: 25, 6: 25},
	"Lion":    {0: 5,  1: 30, 2: 10, 3: 25, 4: 10, 5: 10, 6: 10},
	"Mantis":  {0: 10, 1: 25, 2: 5,  3: 10, 4: 25, 5: 10, 6: 10},
	"Phoenix": {0: 25, 1: 5,  2: 10, 3: 10, 4: 10, 5: 25, 6: 10},
	"Scorpion":{0: 12, 1: 12, 2: 12, 3: 12, 4: 12, 5: 12, 6: 12},
	"Unicorn": {0: 10, 1: 25, 2: 10, 3: 10, 4: 10, 5: 10, 6: 25},
}

const CLAN_SHOURIDO_WEIGHTS: Dictionary = {
	"Crab":    {0: 10, 1: 25, 2: 10, 3: 10, 4: 10, 5: 25, 6: 10},
	"Crane":   {0: 10, 1: 10, 2: 25, 3: 10, 4: 25, 5: 10, 6: 10},
	"Dragon":  {0: 10, 1: 10, 2: 25, 3: 25, 4: 10, 5: 10, 6: 10},
	"Lion":    {0: 10, 1: 25, 2: 10, 3: 10, 4: 10, 5: 25, 6: 10},
	"Mantis":  {0: 25, 1: 10, 2: 10, 3: 10, 4: 10, 5: 25, 6: 10},
	"Phoenix": {0: 10, 1: 10, 2: 10, 3: 25, 4: 25, 5: 10, 6: 10},
	"Scorpion":{0: 25, 1: 10, 2: 25, 3: 10, 4: 10, 5: 10, 6: 10},
	"Unicorn": {0: 10, 1: 10, 2: 10, 3: 10, 4: 10, 5: 25, 6: 25},
}


# === SKILL POOLS ===

const BUGEI_POOL: Array[String] = [
	"Athletics", "Battle", "Defense", "Horsemanship", "Hunting",
	"Iaijutsu", "Jiujutsu", "Kenjutsu", "Kyujutsu", "Spears",
	"Polearms", "Heavy Weapons", "Knives", "War Fan", "Staves",
]

const HIGH_POOL: Array[String] = [
	"Acting", "Calligraphy", "Courtier", "Divination", "Etiquette",
	"Games: Go", "Investigation", "Lore: History", "Lore: Theology",
	"Medicine", "Meditation", "Perform: Storytelling", "Sincerity",
	"Spellcraft", "Tea Ceremony",
]

const MERCHANT_POOL: Array[String] = [
	"Animal Handling", "Commerce", "Craft: Weaponsmithing",
	"Engineering", "Sailing",
]

const LOW_POOL: Array[String] = [
	"Forgery", "Intimidation", "Sleight of Hand", "Stealth", "Temptation",
]

const ALL_SKILL_POOL: Array[String] = [
	"Athletics", "Battle", "Defense", "Horsemanship", "Hunting",
	"Iaijutsu", "Jiujutsu", "Kenjutsu", "Kyujutsu", "Spears",
	"Polearms", "Heavy Weapons", "Knives", "War Fan", "Staves",
	"Acting", "Calligraphy", "Courtier", "Divination", "Etiquette",
	"Games: Go", "Investigation", "Lore: History", "Lore: Theology",
	"Medicine", "Meditation", "Perform: Storytelling", "Sincerity",
	"Tea Ceremony", "Commerce", "Animal Handling", "Intimidation",
	"Stealth",
]


# === TERRAIN CONSTANTS ===

const TERRAIN_RICE_MULTIPLIER: Dictionary = {
	Enums.TerrainType.PLAINS: 1.0,
	Enums.TerrainType.RIVER_DELTA: 1.5,
	Enums.TerrainType.FOREST: 0.75,
	Enums.TerrainType.HILLS: 0.75,
	Enums.TerrainType.MOUNTAINS: 0.5,
}

const TERRAIN_PU_DISTRIBUTION: Dictionary = {
	Enums.TerrainType.PLAINS:      {"farming": 60, "town": 25, "mining": 5, "military": 10},
	Enums.TerrainType.RIVER_DELTA: {"farming": 65, "town": 25, "mining": 0, "military": 10},
	Enums.TerrainType.FOREST:      {"farming": 45, "town": 25, "mining": 15, "military": 15},
	Enums.TerrainType.HILLS:       {"farming": 40, "town": 25, "mining": 25, "military": 10},
	Enums.TerrainType.MOUNTAINS:   {"farming": 25, "town": 20, "mining": 40, "military": 15},
}

const KOKU_LOCATION_MODIFIERS: Dictionary = {
	"standard": 1.0,
	"castle_town": 1.2,
	"crossroads": 1.3,
	"coastal": 1.3,
	"port_city": 1.5,
	"river_town": 1.2,
	"remote": 0.7,
}


# === AGE RANGES ===
# [min_age, max_age] per insight rank index (rank 1 = index 0).

const AGE_RANGES: Array = [
	[15, 20],
	[18, 28],
	[23, 35],
	[30, 45],
	[38, 55],
]

const ALL_TRAITS: Array[String] = [
	"reflexes", "awareness", "stamina", "willpower",
	"agility", "intelligence", "strength", "perception",
]

const RING_TO_TRAITS: Dictionary = {
	Enums.Ring.AIR: ["reflexes", "awareness"],
	Enums.Ring.EARTH: ["stamina", "willpower"],
	Enums.Ring.FIRE: ["agility", "intelligence"],
	Enums.Ring.WATER: ["strength", "perception"],
}

const POINTS_PER_RANK: int = 4


# =============================================================================
# CHARACTER GENERATION
# =============================================================================

static func generate_character(
	character_id: int,
	character_name: String,
	clan: String,
	family: String,
	school: String,
	insight_rank: int,
	dice_engine: DiceEngine,
	gender: String = "",
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = character_id
	c.character_name = character_name
	c.clan = clan
	c.family = family
	c.school = school
	c.gender = gender

	var sd: Dictionary = SCHOOL_DATA.get(school, {})
	if sd.is_empty():
		return c

	c.school_type = sd["type"]

	_apply_trait_bonus(c, FAMILY_TRAIT_BONUS.get(family, ""))
	_apply_trait_bonus(c, sd["benefit"])
	_advance_traits(c, sd, insight_rank, dice_engine)

	_assign_skills(c, sd, insight_rank, dice_engine)

	if sd.has("affinity"):
		c.affinity_element = sd["affinity"]
	if sd.has("deficiency"):
		c.deficiency_element = sd["deficiency"]

	c.honor = sd["honor"] + (insight_rank - 1) * 0.25 + _float_variance(dice_engine, 0.5)
	c.honor = clampf(c.honor, 0.0, 10.0)
	c.glory = clampf(1.0 + (insight_rank - 1) * 0.5, 0.0, 10.0)
	c.status = 1.0

	_assign_personality(c, clan, dice_engine)

	c.max_void_points = c.void_ring
	c.current_void_points = c.void_ring
	c.action_points_max = 2
	c.action_points_current = 2

	c.age = _generate_age(insight_rank, dice_engine)
	c.koku = float(insight_rank) * float(dice_engine.rand_int_range(1, 10))

	SkillResolver.apply_technique_flags(c)
	return c


# =============================================================================
# PROVINCE GENERATION
# =============================================================================

static func generate_province(
	province_id: int,
	province_name: String,
	clan: String,
	family: String,
	terrain_type: Enums.TerrainType,
	total_pu: int,
	dice_engine: DiceEngine,
	is_coastal: bool = false,
) -> ProvinceData:
	var p := ProvinceData.new()
	p.province_id = province_id
	p.province_name = province_name
	p.clan = clan
	p.family = family
	p.terrain_type = terrain_type
	p.is_coastal = is_coastal

	p.stability = float(70 + dice_engine.rand_int_range(0, 20))

	return p


# =============================================================================
# SETTLEMENT GENERATION
# =============================================================================

static func generate_settlement(
	settlement_id: int,
	settlement_name: String,
	province: ProvinceData,
	settlement_type: Enums.SettlementType,
	population_pu: int,
	terrain_type: Enums.TerrainType = Enums.TerrainType.PLAINS,
	has_castle_town: bool = false,
) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = settlement_id
	s.settlement_name = settlement_name
	s.province_id = province.province_id
	s.settlement_type = settlement_type
	s.population_pu = population_pu

	var dist: Dictionary = _distribute_pu(population_pu, terrain_type)
	s.farming_pu = dist["farming"]
	s.town_pu = dist["town"]
	s.mining_pu = dist["mining"]
	s.military_pu = dist["military"]
	s.garrison_pu = maxi(1, int(population_pu / 20))

	var rice_per_season: float = float(population_pu) * 0.25
	s.rice_stockpile = rice_per_season * 2.0
	s.koku_stockpile = float(s.town_pu) * 0.5

	s.infrastructure = _default_infrastructure(settlement_type, has_castle_town)
	s.worship_locations = _default_worship_locations(settlement_type)

	return s


static func _default_infrastructure(
	settlement_type: Enums.SettlementType,
	has_castle_town: bool,
) -> Array:
	# "shrine" and "temple" are the wind-down vocabulary (s57.44). Shrine tier
	# (village/local/roadside) is tracked separately in worship_locations.
	match settlement_type:
		Enums.SettlementType.VILLAGE:
			return ["shrine", "sake_house"]

		Enums.SettlementType.TOWN:
			return [
				"shrine", "sake_house", "inn", "tea_house",
				"market", "garrison", "game_house", "bathhouse",
			]

		Enums.SettlementType.CITY:
			return [
				"shrine", "sake_house", "inn", "tea_house",
				"market", "garrison", "game_house", "bathhouse",
				"theater", "okiya", "pleasure_quarter", "forge",
			]

		Enums.SettlementType.FORTIFICATION:
			return ["garrison"]

		Enums.SettlementType.KEEP:
			return ["garrison", "shrine", "sake_house", "inn"]

		Enums.SettlementType.CASTLE:
			var inf: Array = ["garrison", "shrine", "forge"]
			if has_castle_town:
				inf.append_array([
					"sake_house", "inn", "tea_house",
					"market", "game_house", "bathhouse",
				])
			return inf

		Enums.SettlementType.FAMILY_CASTLE:
			# Castle town is always present for a kyuden.
			return [
				"garrison", "shrine", "forge", "library",
				"sake_house", "inn", "tea_house", "market",
				"game_house", "bathhouse", "okiya", "theater",
			]

		Enums.SettlementType.TEMPLE:
			return ["temple", "shrine"]

		Enums.SettlementType.SHINDEN:
			return ["temple", "shrine"]

		Enums.SettlementType.MONASTERY:
			return ["temple", "shrine"]

		Enums.SettlementType.WALL_TOWER:
			return ["garrison", "sake_house"]

	return []


static func _default_worship_locations(
	settlement_type: Enums.SettlementType,
) -> Array:
	match settlement_type:
		Enums.SettlementType.VILLAGE:
			return [{"type": "village_shrine", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.TOWN:
			return [{"type": "local_shrine", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.CITY:
			return [
				{"type": "local_shrine", "dedicated": false, "fortune": -1},
				{"type": "temple", "dedicated": false, "fortune": -1},
			]
		Enums.SettlementType.CASTLE, Enums.SettlementType.FAMILY_CASTLE:
			return [{"type": "local_shrine", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.KEEP:
			return [{"type": "village_shrine", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.TEMPLE, Enums.SettlementType.SHINDEN:
			return [{"type": "temple", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.MONASTERY:
			return [{"type": "temple", "dedicated": false, "fortune": -1}]
		Enums.SettlementType.WALL_TOWER:
			return [{"type": "roadside_shrine", "dedicated": false, "fortune": -1}]
	return []


# =============================================================================
# INTERNAL — TRAIT HELPERS
# =============================================================================

static func _apply_trait_bonus(c: L5RCharacterData, trait_name: String) -> void:
	if trait_name.is_empty():
		return
	var current: int = c.get(trait_name)
	c.set(trait_name, current + 1)


static func _advance_traits(
	c: L5RCharacterData,
	school_data: Dictionary,
	insight_rank: int,
	dice: DiceEngine,
) -> void:
	var focus_rings: Array = school_data.get("focus_rings", [])
	var is_shugenja: bool = school_data["type"] == Enums.SchoolType.SHUGENJA

	var focus_traits: Array = []
	for ring: Variant in focus_rings:
		var ring_int: int = ring as int
		if RING_TO_TRAITS.has(ring_int):
			var traits: Array = RING_TO_TRAITS[ring_int]
			for t: Variant in traits:
				focus_traits.append(t as String)

	var total_points: int = (insight_rank - 1) * POINTS_PER_RANK
	for _i: int in range(total_points):
		var trait_name: String
		if dice.rand_int_range(0, 99) < 70 and not focus_traits.is_empty():
			trait_name = focus_traits[dice.rand_int_range(0, focus_traits.size() - 1)]
		else:
			trait_name = ALL_TRAITS[dice.rand_int_range(0, ALL_TRAITS.size() - 1)]

		var current: int = c.get(trait_name)
		if current < 5:
			c.set(trait_name, current + 1)
		else:
			var fallback: String = ALL_TRAITS[dice.rand_int_range(0, ALL_TRAITS.size() - 1)]
			var fb_val: int = c.get(fallback)
			if fb_val < 5:
				c.set(fallback, fb_val + 1)

	var void_ranks: int
	if is_shugenja:
		void_ranks = insight_rank - 1
	else:
		void_ranks = int((insight_rank - 1) / 2)
	c.void_ring = 2 + void_ranks


# =============================================================================
# INTERNAL — SKILL HELPERS
# =============================================================================

static func _assign_skills(
	c: L5RCharacterData,
	school_data: Dictionary,
	insight_rank: int,
	dice: DiceEngine,
) -> void:
	var starting_skills: Array = school_data.get("skills", [])
	var rank_2_skills: Array = school_data.get("skill_rank_2", [])

	for skill: Variant in starting_skills:
		var s: String = skill as String
		if s in rank_2_skills:
			c.skills[s] = 2
		else:
			c.skills[s] = 1

	for skill: Variant in rank_2_skills:
		var s: String = skill as String
		if not c.skills.has(s):
			c.skills[s] = 2

	var wildcards: Array = school_data.get("wildcards", [])
	for category: Variant in wildcards:
		var pool: Array = _get_skill_pool(category as String)
		var pick: String = _pick_unused_skill(pool, c.skills, dice)
		if not pick.is_empty():
			c.skills[pick] = 1

	var school_skills: Array = []
	for s: String in c.skills:
		school_skills.append(s)

	for rank: int in range(2, insight_rank + 1):
		for skill: String in school_skills:
			var current: int = c.skills.get(skill, 0)
			if current < rank and dice.rand_int_range(0, 99) < 80:
				c.skills[skill] = current + 1

		var extras: int = dice.rand_int_range(2, 3)
		for _i: int in range(extras):
			var pick: String = _pick_unused_skill(ALL_SKILL_POOL, c.skills, dice)
			if not pick.is_empty():
				c.skills[pick] = 1


static func _get_skill_pool(category: String) -> Array:
	match category:
		"Bugei":
			return BUGEI_POOL.duplicate()
		"High":
			return HIGH_POOL.duplicate()
		"Merchant":
			return MERCHANT_POOL.duplicate()
		"Low":
			return LOW_POOL.duplicate()
		"Skill":
			return ALL_SKILL_POOL.duplicate()
	return ALL_SKILL_POOL.duplicate()


static func _pick_unused_skill(
	pool: Array,
	existing: Dictionary,
	dice: DiceEngine,
) -> String:
	var available: Array = []
	for s: String in pool:
		if not existing.has(s):
			available.append(s)
	if available.is_empty():
		return ""
	return available[dice.rand_int_range(0, available.size() - 1)]


# =============================================================================
# INTERNAL — PERSONALITY
# =============================================================================

static func _assign_personality(
	c: L5RCharacterData,
	clan: String,
	dice: DiceEngine,
) -> void:
	var bushido_weights: Dictionary = CLAN_BUSHIDO_WEIGHTS.get(clan, {})
	if not bushido_weights.is_empty():
		c.bushido_virtue = _weighted_pick(bushido_weights, dice) as Enums.BushidoVirtue
	else:
		c.bushido_virtue = dice.rand_int_range(0, 6) as Enums.BushidoVirtue

	var shourido_weights: Dictionary = CLAN_SHOURIDO_WEIGHTS.get(clan, {})
	if not shourido_weights.is_empty():
		c.shourido_virtue = _weighted_pick(shourido_weights, dice) as Enums.ShouridoVirtue
	else:
		c.shourido_virtue = dice.rand_int_range(0, 6) as Enums.ShouridoVirtue


static func _weighted_pick(weights: Dictionary, dice: DiceEngine) -> int:
	var total: int = 0
	for w: Variant in weights.values():
		total += w as int
	var roll: int = dice.rand_int_range(0, total - 1)
	var cumulative: int = 0
	for key: Variant in weights:
		cumulative += weights[key] as int
		if roll < cumulative:
			return key as int
	var keys: Array = weights.keys()
	return keys[keys.size() - 1] as int


# =============================================================================
# INTERNAL — PROVINCE HELPERS
# =============================================================================

static func _distribute_pu(total_pu: int, terrain: Enums.TerrainType) -> Dictionary:
	var pct: Dictionary = TERRAIN_PU_DISTRIBUTION.get(
		terrain, TERRAIN_PU_DISTRIBUTION[Enums.TerrainType.PLAINS]
	)
	var farming: int = maxi(1, int(total_pu * (pct["farming"] as int) / 100))
	var town: int = maxi(1, int(total_pu * (pct["town"] as int) / 100))
	var mining: int = int(total_pu * (pct["mining"] as int) / 100)
	var military: int = maxi(0, total_pu - farming - town - mining)
	return {"farming": farming, "town": town, "mining": mining, "military": military}


# =============================================================================
# INTERNAL — MISC HELPERS
# =============================================================================

static func _generate_age(insight_rank: int, dice: DiceEngine) -> int:
	var idx: int = clampi(insight_rank - 1, 0, AGE_RANGES.size() - 1)
	var range_arr: Array = AGE_RANGES[idx]
	return dice.rand_int_range(range_arr[0] as int, range_arr[1] as int)


static func _float_variance(dice: DiceEngine, half_range: float) -> float:
	var roll: int = dice.rand_int_range(0, 100)
	return (float(roll) / 100.0 * 2.0 - 1.0) * half_range
