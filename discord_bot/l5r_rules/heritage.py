"""L5R 4e Heritage Tables: random character background rolls.

Core Rulebook p.109-115: Each clan has a Heritage Table. Player rolls 1d10
on their clan table, gaining a mixed-blessing result (some purely beneficial,
some with drawbacks). The DM may allow or require a heritage roll at creation.

Tables reproduced from L5R 4e Core Rulebook.
"""

from __future__ import annotations

import random
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from l5r_rules.character import Character

HERITAGE_TABLES: dict[str, list[dict]] = {
    "Crab": [
        {"roll": 1, "name": "Famous Deed", "effect": "Ancestor once performed a heroic defense of the Wall. +3 Glory points.", "grants": {"glory": 3.0}},
        {"roll": 2, "name": "Glorious Battle", "effect": "Ancestor died gloriously fighting the Shadowlands. +1 Honor Rank.", "grants": {"honor": 1.0}},
        {"roll": 3, "name": "Mixed Blessing: Jade Hand", "effect": "Ancestor was touched by jade. +1k0 vs Shadowlands creatures, but skin has a faint green tint (Social TN +5 outside Crab lands).", "grants": {}},
        {"roll": 4, "name": "Tainted Past", "effect": "Ancestor fell to the Taint. Family is watched carefully. −5 Glory points, +1 Willpower for Taint resistance.", "grants": {"glory": -5.0, "willpower": 1}},
        {"roll": 5, "name": "Siege Master", "effect": "Ancestor designed a key section of the Wall. +1 rank in Engineering (free).", "grants": {"skills": {"Engineering": 1}}},
        {"roll": 6, "name": "Dark Secret", "effect": "Ancestor used maho to defend the Wall. If discovered: −3 Honor points, −5 Glory points.", "grants": {}},
        {"roll": 7, "name": "Wealthy", "effect": "Family holdings are prosperous. +1 koku per month (starting koku +5).", "grants": {"koku": 5}},
        {"roll": 8, "name": "Diplomatic Heritage", "effect": "Ancestor served as ambassador to another clan. +1 rank in Etiquette (free).", "grants": {"skills": {"Etiquette": 1}}},
        {"roll": 9, "name": "Ancestral Weapon", "effect": "A Fine-quality ancestral weapon has been passed down. Choose one weapon: +1k0 damage.", "grants": {}},
        {"roll": 10, "name": "Prophecy", "effect": "A fortune-teller foretold great deeds. Once per session, reroll a single die (before knowing the result).", "grants": {}},
    ],
    "Crane": [
        {"roll": 1, "name": "Artisan Legacy", "effect": "Ancestor was a legendary artisan. +1 rank in one Artisan skill (free).", "grants": {}},
        {"roll": 2, "name": "Political Marriage", "effect": "Family has strong political ties. +3 Status points.", "grants": {"status": 3.0}},
        {"roll": 3, "name": "Dueling Prodigy", "effect": "Ancestor was a famous duelist. +1 rank in Iaijutsu (free).", "grants": {"skills": {"Iaijutsu": 1}}},
        {"roll": 4, "name": "Bitter Rival", "effect": "Family has a longstanding feud with another Crane family. −1 Glory point when interacting with that family.", "grants": {}},
        {"roll": 5, "name": "Courtier's Grace", "effect": "Ancestor was a renowned courtier. +1 rank in Courtier (free).", "grants": {"skills": {"Courtier": 1}}},
        {"roll": 6, "name": "Scandal", "effect": "An ancestor caused a scandal. −5 Glory points, but family is resilient: +1 Willpower.", "grants": {"glory": -5.0, "willpower": 1}},
        {"roll": 7, "name": "Imperial Favor", "effect": "Family once held Imperial favor. +5 Status points.", "grants": {"status": 5.0}},
        {"roll": 8, "name": "Patron of the Arts", "effect": "Family is known for patronage. Starting koku +3.", "grants": {"koku": 3}},
        {"roll": 9, "name": "Blessed Lineage", "effect": "Fortune-blessed bloodline. +1 Void Point maximum.", "grants": {"void": 1}},
        {"roll": 10, "name": "Tactical Mind", "effect": "Ancestor served with distinction in battle. +1 rank in Battle (free).", "grants": {"skills": {"Battle": 1}}},
    ],
    "Dragon": [
        {"roll": 1, "name": "Tattooed Ancestor", "effect": "Ancestor bore powerful tattoos. +1 rank in Lore: Theology (free).", "grants": {"skills": {"Lore: Theology": 1}}},
        {"roll": 2, "name": "Mountain Hermit", "effect": "Family tradition of meditation retreats. +1 rank in Meditation (free).", "grants": {"skills": {"Meditation": 1}}},
        {"roll": 3, "name": "Twin Sword Legacy", "effect": "Ancestor mastered niten. +1 rank in Kenjutsu (free).", "grants": {"skills": {"Kenjutsu": 1}}},
        {"roll": 4, "name": "Eccentric Reputation", "effect": "Family is known for eccentricity. −5 TN for Social at Crane/Scorpion courts, +5 TN for Social at Dragon courts.", "grants": {}},
        {"roll": 5, "name": "Investigator's Eye", "effect": "Ancestor served as a magistrate. +1 rank in Investigation (free).", "grants": {"skills": {"Investigation": 1}}},
        {"roll": 6, "name": "Enigmatic Past", "effect": "Something in the family's past is hidden. DM determines a secret the character doesn't know.", "grants": {}},
        {"roll": 7, "name": "Mountain Holdings", "effect": "Family controls mountain passes. Starting koku +3.", "grants": {"koku": 3}},
        {"roll": 8, "name": "Spiritual Sensitivity", "effect": "Heightened spiritual awareness. +1k0 on rolls to sense supernatural phenomena.", "grants": {}},
        {"roll": 9, "name": "Ancient Scroll", "effect": "Family possesses an old scroll of wisdom. +1 rank in Lore: History (free).", "grants": {"skills": {"Lore: History": 1}}},
        {"roll": 10, "name": "Prophetic Dreams", "effect": "Character has vivid, sometimes prophetic dreams. Once per session, DM may provide a cryptic hint.", "grants": {}},
    ],
    "Lion": [
        {"roll": 1, "name": "War Hero", "effect": "Ancestor was a legendary general. +3 Glory points.", "grants": {"glory": 3.0}},
        {"roll": 2, "name": "Tactical Genius", "effect": "Family tradition of strategy. +1 rank in Battle (free).", "grants": {"skills": {"Battle": 1}}},
        {"roll": 3, "name": "Berserker Blood", "effect": "Ancestor fought with terrifying fury. +1k0 damage when at Hurt or worse, but must make Honor Roll TN 15 to retreat from battle.", "grants": {}},
        {"roll": 4, "name": "Dishonored Ancestor", "effect": "An ancestor was stripped of honor. −5 Honor points, but character is driven: +1 Willpower.", "grants": {"honor": -5.0, "willpower": 1}},
        {"roll": 5, "name": "Historian's Legacy", "effect": "Family keeps meticulous records. +1 rank in Lore: History (free).", "grants": {"skills": {"Lore: History": 1}}},
        {"roll": 6, "name": "Kitsu Bloodline", "effect": "Distant Kitsu blood. Occasional spiritual sensitivity. +1k0 on Commune rolls.", "grants": {}},
        {"roll": 7, "name": "Martial Discipline", "effect": "Family drills are legendary. +1 rank in one Bugei skill (free).", "grants": {}},
        {"roll": 8, "name": "Political Connections", "effect": "Family has ties to the Imperial Court. +5 Status points.", "grants": {"status": 5.0}},
        {"roll": 9, "name": "Ancestral Armor", "effect": "A suit of Light Armor handed down through generations (already equipped, free).", "grants": {}},
        {"roll": 10, "name": "Destined for Glory", "effect": "The stars aligned at birth. +1 Void Point maximum.", "grants": {"void": 1}},
    ],
    "Mantis": [
        {"roll": 1, "name": "Sea Raider", "effect": "Ancestor was a legendary pirate-hunter. +1 rank in Sailing (free).", "grants": {"skills": {"Sailing": 1}}},
        {"roll": 2, "name": "Storm Blessed", "effect": "Family survived a great storm. +1k0 on Sailing checks in storms.", "grants": {}},
        {"roll": 3, "name": "Merchant Prince", "effect": "Family has trade connections. Starting koku +5.", "grants": {"koku": 5}},
        {"roll": 4, "name": "Questionable Methods", "effect": "Ancestor used dishonorable tactics. −5 Honor points, but +1 rank in Commerce (free).", "grants": {"honor": -5.0, "skills": {"Commerce": 1}}},
        {"roll": 5, "name": "Island Holdings", "effect": "Family holds small islands. +1 rank in Navigation (free).", "grants": {"skills": {"Navigation": 1}}},
        {"roll": 6, "name": "Archery Champion", "effect": "Ancestor won an archery tournament. +1 rank in Kyujutsu (free).", "grants": {"skills": {"Kyujutsu": 1}}},
        {"roll": 7, "name": "Kitsune Blood", "effect": "Distant fox-spirit blood. Animals are calmer around you. +1k0 Animal Handling.", "grants": {}},
        {"roll": 8, "name": "Resourceful", "effect": "Family thrives in adversity. Once per session, find a useful mundane item.", "grants": {}},
        {"roll": 9, "name": "Great Navigator", "effect": "Ancestor charted unknown waters. +1 rank in Lore: Navigation (free).", "grants": {"skills": {"Lore: Navigation": 1}}},
        {"roll": 10, "name": "Tempest Fury", "effect": "Born during a typhoon. +1 Stamina for endurance checks at sea.", "grants": {"stamina": 1}},
    ],
    "Phoenix": [
        {"roll": 1, "name": "Elemental Master", "effect": "Ancestor was an Elemental Master. +1 rank in Spellcraft (free).", "grants": {"skills": {"Spellcraft": 1}}},
        {"roll": 2, "name": "Peaceful Scholar", "effect": "Family tradition of scholarship. +1 rank in Lore: Theology (free).", "grants": {"skills": {"Lore: Theology": 1}}},
        {"roll": 3, "name": "Ishiken Blood", "effect": "Distant Void magic bloodline. +1k0 on Void spell casting (if shugenja).", "grants": {}},
        {"roll": 4, "name": "Pacifist Tradition", "effect": "Family avoids violence. −1k0 on attack rolls, but +1 Honor Rank.", "grants": {"honor": 1.0}},
        {"roll": 5, "name": "Library Access", "effect": "Family maintains a great library. +1 rank in any one Lore skill (free).", "grants": {}},
        {"roll": 6, "name": "Haunted", "effect": "An ancestor's spirit lingers. Occasional spiritual disturbances. DM provides occasional ghostly hints or complications.", "grants": {}},
        {"roll": 7, "name": "Healing Tradition", "effect": "Family is known for medicine. +1 rank in Medicine (free).", "grants": {"skills": {"Medicine": 1}}},
        {"roll": 8, "name": "Temple Holdings", "effect": "Family maintains a prominent temple. +5 Status points.", "grants": {"status": 5.0}},
        {"roll": 9, "name": "Ancient Texts", "effect": "Family possesses rare scrolls. +1 rank in Calligraphy (free).", "grants": {"skills": {"Calligraphy": 1}}},
        {"roll": 10, "name": "Blessed by the Kami", "effect": "+1 Void Point maximum.", "grants": {"void": 1}},
    ],
    "Scorpion": [
        {"roll": 1, "name": "Master Spy", "effect": "Ancestor was a legendary spy. +1 rank in Stealth (free).", "grants": {"skills": {"Stealth": 1}}},
        {"roll": 2, "name": "Poison Expert", "effect": "Family knows poisons well. +1 rank in Medicine (Poison emphasis, free).", "grants": {"skills": {"Medicine": 1}}},
        {"roll": 3, "name": "Blackmail Network", "effect": "Family has leverage. +1 rank in Intimidation (free).", "grants": {"skills": {"Intimidation": 1}}},
        {"roll": 4, "name": "Double Agent", "effect": "Ancestor was a double agent. Family is distrusted even within Scorpion. −5 Glory points, +1 rank in Sincerity (free).", "grants": {"glory": -5.0, "skills": {"Sincerity": 1}}},
        {"roll": 5, "name": "Seductress/Seductor", "effect": "Ancestor was legendarily charming. +1 rank in Temptation (free).", "grants": {"skills": {"Temptation": 1}}},
        {"roll": 6, "name": "Hidden Wealth", "effect": "Family has secret caches. Starting koku +5.", "grants": {"koku": 5}},
        {"roll": 7, "name": "Assassin's Blood", "effect": "Ancestor was a notorious assassin. +1 rank in Knives (free).", "grants": {"skills": {"Knives": 1}}},
        {"roll": 8, "name": "Political Maneuverer", "effect": "Family excels at court. +1 rank in Courtier (free).", "grants": {"skills": {"Courtier": 1}}},
        {"roll": 9, "name": "Mask of Secrets", "effect": "An ancestral mask with a hidden compartment. Can conceal a small item.", "grants": {}},
        {"roll": 10, "name": "Fortune's Favor", "effect": "Ancestor struck a bargain with fate. Once per session, force one opponent to reroll a die.", "grants": {}},
    ],
    "Unicorn": [
        {"roll": 1, "name": "Gaijin Blood", "effect": "Foreign ancestry. +1 rank in one Gaijin skill (free). Distinct features (Social TN +5 in conservative courts).", "grants": {}},
        {"roll": 2, "name": "Horse Lord", "effect": "Family raises the finest horses. Start with a Utaku steed. +1 rank in Horsemanship (free).", "grants": {"skills": {"Horsemanship": 1}}},
        {"roll": 3, "name": "Desert Survivor", "effect": "Ancestor crossed the Burning Sands. +1 Stamina for endurance checks.", "grants": {"stamina": 1}},
        {"roll": 4, "name": "Outsider's Perspective", "effect": "Family keeps foreign customs. −5 Honor points in traditional Rokugani eyes, +1 rank in Investigation (free).", "grants": {"honor": -5.0, "skills": {"Investigation": 1}}},
        {"roll": 5, "name": "Cavalry Tradition", "effect": "Family excels at mounted combat. +1k0 on attack rolls while Mounted.", "grants": {}},
        {"roll": 6, "name": "Trade Routes", "effect": "Family controls trade routes. Starting koku +5, +1 rank in Commerce (free).", "grants": {"koku": 5, "skills": {"Commerce": 1}}},
        {"roll": 7, "name": "War Dog Breeder", "effect": "Family breeds war dogs. Start with a trained war dog companion.", "grants": {}},
        {"roll": 8, "name": "Meishodo Practitioner", "effect": "Ancestor practiced name magic. +1 rank in Lore: Theology (free).", "grants": {"skills": {"Lore: Theology": 1}}},
        {"roll": 9, "name": "Nomadic Heritage", "effect": "Family keeps nomadic traditions. +1 rank in Hunting (free).", "grants": {"skills": {"Hunting": 1}}},
        {"roll": 10, "name": "Battle Hardened", "effect": "Family has fought in many wars. +1 rank in Battle (free).", "grants": {"skills": {"Battle": 1}}},
    ],
}

DEFAULT_TABLE: list[dict] = [
    {"roll": 1, "name": "Noble Heritage", "effect": "+3 Glory points.", "grants": {"glory": 3.0}},
    {"roll": 2, "name": "Military Tradition", "effect": "+1 rank in one Bugei skill (free).", "grants": {}},
    {"roll": 3, "name": "Scholarly Lineage", "effect": "+1 rank in one Lore skill (free).", "grants": {}},
    {"roll": 4, "name": "Dark Secret", "effect": "Family harbors a secret. DM determines details.", "grants": {}},
    {"roll": 5, "name": "Wealthy Holdings", "effect": "Starting koku +3.", "grants": {"koku": 3}},
    {"roll": 6, "name": "Political Ties", "effect": "+5 Status points.", "grants": {"status": 5.0}},
    {"roll": 7, "name": "Spiritual Connection", "effect": "+1 rank in Meditation (free).", "grants": {"skills": {"Meditation": 1}}},
    {"roll": 8, "name": "Mixed Blessing", "effect": "+1 to one Trait, −1 to another (DM chooses).", "grants": {}},
    {"roll": 9, "name": "Ancestral Item", "effect": "Inherit a Fine-quality item of DM's choice.", "grants": {}},
    {"roll": 10, "name": "Destiny", "effect": "+1 Void Point maximum.", "grants": {"void": 1}},
]


def roll_heritage(clan: str) -> dict:
    """Roll 1d10 on the clan's heritage table. Returns the result dict."""
    table = HERITAGE_TABLES.get(clan, DEFAULT_TABLE)
    roll = random.randint(1, 10)
    return table[roll - 1]


def get_table(clan: str) -> list[dict]:
    """Return the heritage table for a clan (or the default)."""
    return HERITAGE_TABLES.get(clan, DEFAULT_TABLE)


def apply_heritage(char: Character, result: dict) -> list[str]:
    """Apply a heritage result's mechanical grants to a character.

    Returns a list of human-readable notes about what was applied.
    """
    grants = result.get("grants", {})
    if not grants:
        return []
    notes: list[str] = []
    if "skills" in grants:
        for skill_name, rank_bonus in grants["skills"].items():
            current = char.skills.get(skill_name, 0)
            char.skills[skill_name] = current + rank_bonus
            notes.append(f"+{rank_bonus} {skill_name}")
    if "honor" in grants:
        char.honor += grants["honor"]
        notes.append(f"Honor {grants['honor']:+.1f}")
    if "glory" in grants:
        char.glory += grants["glory"]
        notes.append(f"Glory {grants['glory']:+.1f}")
    if "status" in grants:
        char.status += grants["status"]
        notes.append(f"Status {grants['status']:+.1f}")
    if "void" in grants:
        char.void_ring += grants["void"]
        notes.append(f"+{grants['void']} Void")
    if "willpower" in grants:
        char.willpower += grants["willpower"]
        notes.append(f"+{grants['willpower']} Willpower")
    if "stamina" in grants:
        char.stamina += grants["stamina"]
        notes.append(f"+{grants['stamina']} Stamina")
    if "koku" in grants:
        char.koku += grants["koku"]
        notes.append(f"+{grants['koku']} koku")
    return notes
