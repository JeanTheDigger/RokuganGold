"""L5R 4e Heritage Tables: random character background rolls.

Core Rulebook p.109-115: Each clan has a Heritage Table. Player rolls 1d10
on their clan table, gaining a mixed-blessing result (some purely beneficial,
some with drawbacks). The DM may allow or require a heritage roll at creation.

Tables reproduced from L5R 4e Core Rulebook.
"""

from __future__ import annotations

import random

HERITAGE_TABLES: dict[str, list[dict]] = {
    "Crab": [
        {"roll": 1, "name": "Famous Deed", "effect": "Ancestor once performed a heroic defense of the Wall. +3 Glory."},
        {"roll": 2, "name": "Glorious Battle", "effect": "Ancestor died gloriously fighting the Shadowlands. +1 Honor Rank."},
        {"roll": 3, "name": "Mixed Blessing: Jade Hand", "effect": "Ancestor was touched by jade. +1k0 vs Shadowlands creatures, but skin has a faint green tint (Social TN +5 outside Crab lands)."},
        {"roll": 4, "name": "Tainted Past", "effect": "Ancestor fell to the Taint. Family is watched carefully. −0.5 Glory, +1 Willpower for Taint resistance."},
        {"roll": 5, "name": "Siege Master", "effect": "Ancestor designed a key section of the Wall. +1 rank in Engineering (free)."},
        {"roll": 6, "name": "Dark Secret", "effect": "Ancestor used maho to defend the Wall. If discovered: −3 Honor, −5 Glory."},
        {"roll": 7, "name": "Wealthy", "effect": "Family holdings are prosperous. +1 koku per month (starting koku +5)."},
        {"roll": 8, "name": "Diplomatic Heritage", "effect": "Ancestor served as ambassador to another clan. +1 rank in Etiquette (free)."},
        {"roll": 9, "name": "Ancestral Weapon", "effect": "A Fine-quality ancestral weapon has been passed down. Choose one weapon: +1k0 damage."},
        {"roll": 10, "name": "Prophecy", "effect": "A fortune-teller foretold great deeds. Once per session, reroll a single die (before knowing the result)."},
    ],
    "Crane": [
        {"roll": 1, "name": "Artisan Legacy", "effect": "Ancestor was a legendary artisan. +1 rank in one Artisan skill (free)."},
        {"roll": 2, "name": "Political Marriage", "effect": "Family has strong political ties. +3 Status."},
        {"roll": 3, "name": "Dueling Prodigy", "effect": "Ancestor was a famous duelist. +1 rank in Iaijutsu (free)."},
        {"roll": 4, "name": "Bitter Rival", "effect": "Family has a longstanding feud with another Crane family. −1 Glory when interacting with that family."},
        {"roll": 5, "name": "Courtier's Grace", "effect": "Ancestor was a renowned courtier. +1 rank in Courtier (free)."},
        {"roll": 6, "name": "Scandal", "effect": "An ancestor caused a scandal. −0.5 Glory, but family is resilient: +1 Willpower."},
        {"roll": 7, "name": "Imperial Favor", "effect": "Family once held Imperial favor. +0.5 Status."},
        {"roll": 8, "name": "Patron of the Arts", "effect": "Family is known for patronage. Starting koku +3."},
        {"roll": 9, "name": "Blessed Lineage", "effect": "Fortune-blessed bloodline. +1 Void Point maximum."},
        {"roll": 10, "name": "Tactical Mind", "effect": "Ancestor served with distinction in battle. +1 rank in Battle (free)."},
    ],
    "Dragon": [
        {"roll": 1, "name": "Tattooed Ancestor", "effect": "Ancestor bore powerful tattoos. +1 rank in Lore: Theology (free)."},
        {"roll": 2, "name": "Mountain Hermit", "effect": "Family tradition of meditation retreats. +1 rank in Meditation (free)."},
        {"roll": 3, "name": "Twin Sword Legacy", "effect": "Ancestor mastered niten. +1 rank in Kenjutsu (free)."},
        {"roll": 4, "name": "Eccentric Reputation", "effect": "Family is known for eccentricity. −5 TN for Social at Crane/Scorpion courts, +5 TN for Social at Dragon courts."},
        {"roll": 5, "name": "Investigator's Eye", "effect": "Ancestor served as a magistrate. +1 rank in Investigation (free)."},
        {"roll": 6, "name": "Enigmatic Past", "effect": "Something in the family's past is hidden. DM determines a secret the character doesn't know."},
        {"roll": 7, "name": "Mountain Holdings", "effect": "Family controls mountain passes. Starting koku +3."},
        {"roll": 8, "name": "Spiritual Sensitivity", "effect": "Heightened spiritual awareness. +1k0 on rolls to sense supernatural phenomena."},
        {"roll": 9, "name": "Ancient Scroll", "effect": "Family possesses an old scroll of wisdom. +1 rank in Lore: History (free)."},
        {"roll": 10, "name": "Prophetic Dreams", "effect": "Character has vivid, sometimes prophetic dreams. Once per session, DM may provide a cryptic hint."},
    ],
    "Lion": [
        {"roll": 1, "name": "War Hero", "effect": "Ancestor was a legendary general. +3 Glory."},
        {"roll": 2, "name": "Tactical Genius", "effect": "Family tradition of strategy. +1 rank in Battle (free)."},
        {"roll": 3, "name": "Berserker Blood", "effect": "Ancestor fought with terrifying fury. +1k0 damage when at Hurt or worse, but must make Honor Roll TN 15 to retreat from battle."},
        {"roll": 4, "name": "Dishonored Ancestor", "effect": "An ancestor was stripped of honor. −0.5 Honor, but character is driven: +1 Willpower."},
        {"roll": 5, "name": "Historian's Legacy", "effect": "Family keeps meticulous records. +1 rank in Lore: History (free)."},
        {"roll": 6, "name": "Kitsu Bloodline", "effect": "Distant Kitsu blood. Occasional spiritual sensitivity. +1k0 on Commune rolls."},
        {"roll": 7, "name": "Martial Discipline", "effect": "Family drills are legendary. +1 rank in one Bugei skill (free)."},
        {"roll": 8, "name": "Political Connections", "effect": "Family has ties to the Imperial Court. +0.5 Status."},
        {"roll": 9, "name": "Ancestral Armor", "effect": "A suit of Light Armor handed down through generations (already equipped, free)."},
        {"roll": 10, "name": "Destined for Glory", "effect": "The stars aligned at birth. +1 Void Point maximum."},
    ],
    "Mantis": [
        {"roll": 1, "name": "Sea Raider", "effect": "Ancestor was a legendary pirate-hunter. +1 rank in Sailing (free)."},
        {"roll": 2, "name": "Storm Blessed", "effect": "Family survived a great storm. +1k0 on Sailing checks in storms."},
        {"roll": 3, "name": "Merchant Prince", "effect": "Family has trade connections. Starting koku +5."},
        {"roll": 4, "name": "Questionable Methods", "effect": "Ancestor used dishonorable tactics. −0.5 Honor, but +1 rank in Commerce (free)."},
        {"roll": 5, "name": "Island Holdings", "effect": "Family holds small islands. +1 rank in Navigation (free)."},
        {"roll": 6, "name": "Archery Champion", "effect": "Ancestor won an archery tournament. +1 rank in Kyujutsu (free)."},
        {"roll": 7, "name": "Kitsune Blood", "effect": "Distant fox-spirit blood. Animals are calmer around you. +1k0 Animal Handling."},
        {"roll": 8, "name": "Resourceful", "effect": "Family thrives in adversity. Once per session, find a useful mundane item."},
        {"roll": 9, "name": "Great Navigator", "effect": "Ancestor charted unknown waters. +1 rank in Lore: Navigation (free)."},
        {"roll": 10, "name": "Tempest Fury", "effect": "Born during a typhoon. +1 Stamina for endurance checks at sea."},
    ],
    "Phoenix": [
        {"roll": 1, "name": "Elemental Master", "effect": "Ancestor was an Elemental Master. +1 rank in Spellcraft (free)."},
        {"roll": 2, "name": "Peaceful Scholar", "effect": "Family tradition of scholarship. +1 rank in Lore: Theology (free)."},
        {"roll": 3, "name": "Ishiken Blood", "effect": "Distant Void magic bloodline. +1k0 on Void spell casting (if shugenja)."},
        {"roll": 4, "name": "Pacifist Tradition", "effect": "Family avoids violence. −1k0 on attack rolls, but +1 Honor Rank."},
        {"roll": 5, "name": "Library Access", "effect": "Family maintains a great library. +1 rank in any one Lore skill (free)."},
        {"roll": 6, "name": "Haunted", "effect": "An ancestor's spirit lingers. Occasional spiritual disturbances. DM provides occasional ghostly hints or complications."},
        {"roll": 7, "name": "Healing Tradition", "effect": "Family is known for medicine. +1 rank in Medicine (free)."},
        {"roll": 8, "name": "Temple Holdings", "effect": "Family maintains a prominent temple. +0.5 Status."},
        {"roll": 9, "name": "Ancient Texts", "effect": "Family possesses rare scrolls. +1 rank in Calligraphy (free)."},
        {"roll": 10, "name": "Blessed by the Kami", "effect": "+1 Void Point maximum."},
    ],
    "Scorpion": [
        {"roll": 1, "name": "Master Spy", "effect": "Ancestor was a legendary spy. +1 rank in Stealth (free)."},
        {"roll": 2, "name": "Poison Expert", "effect": "Family knows poisons well. +1 rank in Medicine (Poison emphasis, free)."},
        {"roll": 3, "name": "Blackmail Network", "effect": "Family has leverage. +1 rank in Intimidation (free)."},
        {"roll": 4, "name": "Double Agent", "effect": "Ancestor was a double agent. Family is distrusted even within Scorpion. −0.5 Glory, +1 rank in Sincerity (free)."},
        {"roll": 5, "name": "Seductress/Seductor", "effect": "Ancestor was legendarily charming. +1 rank in Temptation (free)."},
        {"roll": 6, "name": "Hidden Wealth", "effect": "Family has secret caches. Starting koku +5."},
        {"roll": 7, "name": "Assassin's Blood", "effect": "Ancestor was a notorious assassin. +1 rank in Knives (free)."},
        {"roll": 8, "name": "Political Maneuverer", "effect": "Family excels at court. +1 rank in Courtier (free)."},
        {"roll": 9, "name": "Mask of Secrets", "effect": "An ancestral mask with a hidden compartment. Can conceal a small item."},
        {"roll": 10, "name": "Fortune's Favor", "effect": "Ancestor struck a bargain with fate. Once per session, force one opponent to reroll a die."},
    ],
    "Unicorn": [
        {"roll": 1, "name": "Gaijin Blood", "effect": "Foreign ancestry. +1 rank in one Gaijin skill (free). Distinct features (Social TN +5 in conservative courts)."},
        {"roll": 2, "name": "Horse Lord", "effect": "Family raises the finest horses. Start with a Utaku steed. +1 rank in Horsemanship (free)."},
        {"roll": 3, "name": "Desert Survivor", "effect": "Ancestor crossed the Burning Sands. +1 Stamina for endurance checks."},
        {"roll": 4, "name": "Outsider's Perspective", "effect": "Family keeps foreign customs. −0.5 Honor in traditional Rokugani eyes, +1 rank in Investigation (free)."},
        {"roll": 5, "name": "Cavalry Tradition", "effect": "Family excels at mounted combat. +1k0 on attack rolls while Mounted."},
        {"roll": 6, "name": "Trade Routes", "effect": "Family controls trade routes. Starting koku +5, +1 rank in Commerce (free)."},
        {"roll": 7, "name": "War Dog Breeder", "effect": "Family breeds war dogs. Start with a trained war dog companion."},
        {"roll": 8, "name": "Meishodo Practitioner", "effect": "Ancestor practiced name magic. +1 rank in Lore: Theology (free)."},
        {"roll": 9, "name": "Nomadic Heritage", "effect": "Family keeps nomadic traditions. +1 rank in Hunting (free)."},
        {"roll": 10, "name": "Battle Hardened", "effect": "Family has fought in many wars. +1 rank in Battle (free)."},
    ],
}

# Default table for clans without a specific heritage table
DEFAULT_TABLE: list[dict] = [
    {"roll": 1, "name": "Noble Heritage", "effect": "+3 Glory."},
    {"roll": 2, "name": "Military Tradition", "effect": "+1 rank in one Bugei skill (free)."},
    {"roll": 3, "name": "Scholarly Lineage", "effect": "+1 rank in one Lore skill (free)."},
    {"roll": 4, "name": "Dark Secret", "effect": "Family harbors a secret. DM determines details."},
    {"roll": 5, "name": "Wealthy Holdings", "effect": "Starting koku +3."},
    {"roll": 6, "name": "Political Ties", "effect": "+0.5 Status."},
    {"roll": 7, "name": "Spiritual Connection", "effect": "+1 rank in Meditation (free)."},
    {"roll": 8, "name": "Mixed Blessing", "effect": "+1 to one Trait, −1 to another (DM chooses)."},
    {"roll": 9, "name": "Ancestral Item", "effect": "Inherit a Fine-quality item of DM's choice."},
    {"roll": 10, "name": "Destiny", "effect": "+1 Void Point maximum."},
]


def roll_heritage(clan: str) -> dict:
    """Roll 1d10 on the clan's heritage table. Returns the result dict."""
    table = HERITAGE_TABLES.get(clan, DEFAULT_TABLE)
    roll = random.randint(1, 10)
    return table[roll - 1]


def get_table(clan: str) -> list[dict]:
    """Return the heritage table for a clan (or the default)."""
    return HERITAGE_TABLES.get(clan, DEFAULT_TABLE)
