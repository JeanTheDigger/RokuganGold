"""Which skills belong to which group (Weapon, Low, High, Social), for effects that name a group."""

from __future__ import annotations

WEAPON = frozenset({
    "chain weapons", "heavy weapons", "iaijutsu", "kenjutsu", "knives", "kyujutsu", "naginatajutsu",
    "ninjutsu", "polearms", "spears", "staves", "war fan", "jiujutsu",
})
LOW = frozenset({
    "acting", "commerce", "engineering", "forgery", "intimidation", "locksmith", "sleight of hand",
    "stealth", "temptation",
})
HIGH = frozenset({
    "artisan", "calligraphy", "courtier", "divination", "etiquette", "games", "investigation", "lore",
    "medicine", "meditation", "perform", "sincerity", "spellcraft", "tea ceremony", "theology",
})
SOCIAL = frozenset({"courtier", "etiquette", "intimidation", "temptation", "sincerity", "perform"})


def base(skill: str) -> str:
    """"Lore: History" -> "lore"; "Kenjutsu" -> "kenjutsu"."""
    return skill.split(":")[0].split("(")[0].strip().lower()


def is_weapon(skill: str) -> bool:
    return base(skill) in WEAPON


def is_low(skill: str) -> bool:
    return base(skill) in LOW


def is_high(skill: str) -> bool:
    return base(skill) in HIGH


def is_social(skill: str) -> bool:
    return base(skill) in SOCIAL
