"""Access helpers over the generated school catalog (GDD s29).

The data (l5r_rules/schools_catalog.py) is produced verbatim by
tools/extract_schools.py. This module just indexes and queries it.
"""

from __future__ import annotations

import re

from .schools_catalog import SCHOOLS_DATA

_TRAITS = {
    "stamina", "willpower", "strength", "perception",
    "agility", "intelligence", "reflexes", "awareness", "void",
}
_SCHOOL_TYPES = {"bushi": "Bushi", "courtier": "Courtier", "shugenja": "Shugenja",
                 "monk": "Monk", "ninja": "Ninja", "artisan": "Artisan"}

ALL = SCHOOLS_DATA
_BY_NAME = {s["name"].lower(): s for s in SCHOOLS_DATA}


def get(name: str) -> dict | None:
    return _BY_NAME.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [s for s in SCHOOLS_DATA if q in s["name"].lower() or q in s["clan"].lower()]


def by_clan(clan: str) -> list[dict]:
    return [s for s in SCHOOLS_DATA if s["clan"].lower() == clan.lower()]


def by_category(category: str) -> list[dict]:
    """basic / advanced / alternate."""
    return [s for s in SCHOOLS_DATA if s.get("category") == category]


def basic() -> list[dict]:
    """Starting Schools only — the ones a character can be created with."""
    return [s for s in SCHOOLS_DATA if s.get("category", "basic") == "basic"]


def clans() -> list[str]:
    return sorted({s["clan"] for s in SCHOOLS_DATA})


def techniques_up_to(name: str, rank: int) -> list[dict]:
    """Ranked techniques (1..rank) a character of this school is entitled to."""
    s = get(name)
    if not s:
        return []
    return [t for t in s["techniques"] if 1 <= t["rank"] <= rank]


# --- Applying a school to a character at creation ---------------------------
def parse_benefit(benefit: str) -> tuple[str, int] | None:
    """'+1 Stamina' -> ('stamina', 1); None if not a recognised Trait bonus."""
    m = re.search(r"\+(\d+)\s+([A-Za-z]+)", benefit or "")
    if not m:
        return None
    trait = m.group(2).lower()
    return (trait, int(m.group(1))) if trait in _TRAITS else None


def parse_honor(honor: str) -> float | None:
    m = re.search(r"[\d.]+", honor or "")
    return float(m.group(0)) if m else None


def _split_commas(s: str) -> list[str]:
    out, depth, cur = [], 0, []
    for ch in s:
        if ch == "(":
            depth += 1
            cur.append(ch)
        elif ch == ")":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur))
    return out


def parse_skills(skills: str) -> tuple[list[tuple[str, int, str | None]], list[str]]:
    """Return (assigned, wildcards).

    assigned: [(skill_name, rank, emphasis|None)] — concrete starting skills.
    wildcards: ['any one Bugei Skill', ...] — player-choice slots, left for the DM.
    """
    assigned: list[tuple[str, int, str | None]] = []
    wildcards: list[str] = []
    for raw in _split_commas(skills or ""):
        p = raw.strip()
        if not p:
            continue
        low = p.lower()
        if low.startswith("any") or "any one" in low or low.startswith("choose") or low.startswith("one "):
            wildcards.append(p)
            continue
        rank = 1
        mrank = re.search(r"\s(\d+)$", p)
        if mrank:
            rank = int(mrank.group(1))
            p = p[: mrank.start()].strip()
        emph = None
        mp = re.search(r"\(([^)]+)\)", p)
        if mp:
            emph = mp.group(1).strip()
            p = re.sub(r"\s*\([^)]+\)", "", p).strip()
        if p:
            assigned.append((p, rank, emph))
    return assigned, wildcards


def _infer_type(school: dict) -> str | None:
    for kw in school.get("keywords", []):
        t = _SCHOOL_TYPES.get(kw.lower())
        if t:
            return t
    if school.get("affinity"):
        return "Shugenja"
    return None


def apply_to_character(character, school: dict) -> dict:
    """Apply a school's Benefit, Skills, Honor (and clan/name/type) to a fresh
    character. Mutates the character; returns a report of what was applied."""
    report = {"benefit": None, "honor": None, "skills": [], "emphases": [], "wildcards": []}
    character.school = school["name"]
    if school.get("clan"):
        character.clan = school["clan"]
    stype = _infer_type(school)
    if stype:
        character.school_type = stype

    ben = parse_benefit(school.get("benefit", ""))
    if ben:
        trait, amt = ben
        for _ in range(amt):
            if trait == "void":
                character.void_ring += 1
                character.max_void_points = character.void_ring
                character.current_void_points = character.void_ring
            else:
                character.set_trait(trait, character.get_trait(trait) + 1)
        report["benefit"] = f"+{amt} {'Void' if trait == 'void' else trait.capitalize()}"

    honor = parse_honor(school.get("honor", ""))
    if honor is not None:
        character.honor = honor
        report["honor"] = honor

    assigned, wildcards = parse_skills(school.get("skills", ""))
    for name, rank, emph in assigned:
        character.skills[name] = max(character.skills.get(name, 0), rank)
        report["skills"].append(f"{name} {rank}")
        if emph:
            lst = character.emphases.setdefault(name, [])
            if emph not in lst:
                lst.append(emph)
                report["emphases"].append(f"{name} ({emph})")
    report["wildcards"] = wildcards
    return report
