"""Access helpers over the generated school catalog (GDD s29).

The data (l5r_rules/schools_catalog.py) is produced verbatim by
tools/extract_schools.py. This module just indexes and queries it.
"""

from __future__ import annotations

import re

from .schools_catalog import SCHOOLS_DATA


def _normalize_technique_ranks() -> None:
    """Fix rank-0 techniques left by the extraction script.

    L5R 4e has no rank 0 — every technique has a positive rank.
    Basic schools: sequential ranks 1, 2, 3, ...
    Advanced schools: sequential ranks 1, 2, 3, ... (relative to the school)
    Alternate paths: rank from 'Replaces: X N' prereq, else 1.
    """
    for school in SCHOOLS_DATA:
        techs = school.get("techniques", [])
        if not any(t["rank"] == 0 for t in techs):
            continue

        cat = school.get("category", "basic")
        prereq = school.get("prereq", "")

        if cat in ("basic", "advanced"):
            for i, t in enumerate(techs):
                if t["rank"] == 0:
                    t["rank"] = i + 1
        else:
            rank = _parse_replacement_rank(prereq)
            for t in techs:
                if t["rank"] == 0:
                    t["rank"] = rank


def _parse_replacement_rank(prereq: str) -> int:
    """Extract the technique rank an alternate path replaces.

    Patterns handled:
      'Replaces: Hida Bushi 2'          -> 2
      'Replaces: Hida Bushi Rank 2'     -> 2
      'Rank 6. Must attain ...'         -> 6
      'Replaces: Any ...'               -> 1
      '' or 'Requires: ...'             -> 1
    """
    m = re.search(r"Replaces:\s*.+?(?:Rank\s+)?(\d+)", prereq)
    if m:
        return int(m.group(1))
    m = re.match(r"Rank\s+(\d+)", prereq)
    if m:
        return int(m.group(1))
    return 1


_normalize_technique_ranks()

_TRAITS = {
    "stamina", "willpower", "strength", "perception",
    "agility", "intelligence", "reflexes", "awareness", "void",
}
_SCHOOL_TYPES = {"bushi": "Bushi", "courtier": "Courtier", "shugenja": "Shugenja",
                 "monk": "Monk", "ninja": "Ninja", "artisan": "Artisan"}

ALL = SCHOOLS_DATA
_BY_NAME = {s["name"].lower(): s for s in SCHOOLS_DATA}


def get(name: str) -> dict | None:
    """Exact (case-insensitive) match, else the one school whose name starts with
    the text before its ': Clan' tag ("Usagi Bushi" finds "Usagi Bushi: Hare Clan")."""
    key = name.lower().strip()
    hit = _BY_NAME.get(key)
    if hit is not None or not key:
        return hit
    starts = [s for k, s in _BY_NAME.items() if k.startswith(key + ":") or k.startswith(key + " (")]
    return starts[0] if len(starts) == 1 else None


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [s for s in SCHOOLS_DATA if q in s["name"].lower() or q in s["clan"].lower()]


def by_clan(clan: str) -> list[dict]:
    return [s for s in SCHOOLS_DATA if s["clan"].lower() == clan.lower()]


def by_category(category: str) -> list[dict]:
    """basic / advanced / alternate."""
    return [s for s in SCHOOLS_DATA if s.get("category") == category]


def basic() -> list[dict]:
    """Starting Schools only: the ones a character can be created with."""
    return [s for s in SCHOOLS_DATA if s.get("category", "basic") == "basic"]


def clans() -> list[str]:
    return sorted({s["clan"] for s in SCHOOLS_DATA})


# The school catalog files minor clans under one "Minor Clan" entry (and odd
# schools under "Miscellaneous"). Character creation offers real clans instead:
# every clan that has families, plus the school-only groups a character can
# belong to (Brotherhood, Imperial, Ronin).
_PSEUDO_CLANS = ("Minor Clan", "Miscellaneous")
# Owner ruling 2026-09-16: the Mantis and its former member clans (Fox, Centipede,
# Wasp) are minor clans in this setting.
GREAT_CLANS: tuple[str, ...] = ("Crab", "Crane", "Dragon", "Lion", "Phoenix", "Scorpion", "Unicorn", "Spider")


def creation_clans() -> list[str]:
    from . import families
    out = {f["clan"] for f in families.ALL}
    out |= {s["clan"] for s in basic() if s["clan"] not in _PSEUDO_CLANS}
    return sorted(out)


def great_clans() -> list[str]:
    return [c for c in creation_clans() if c in GREAT_CLANS]


def minor_clans() -> list[str]:
    """Every other creation clan: the minor clans plus Brotherhood, Imperial and Ronin."""
    return [c for c in creation_clans() if c not in GREAT_CLANS]


def _other_clan_tag(name: str, clan: str) -> bool:
    """True if a school name carries a ': Other Clan' tag for a different creation clan."""
    low = name.lower()
    for other in creation_clans():
        if other.lower() != clan.lower() and f"{other.lower()} clan" in low:
            return True
    return False


def basic_for_clan(clan: str) -> list[dict]:
    """Basic schools a character of this clan starts with.
    Own catalog entries first (minus ones tagged for another clan, e.g. the Fox
    schools filed under Mantis); else the entries whose name carries the clan
    ("Usagi Bushi: Hare Clan"); else the entries named after one of its families
    ("Kitsune Shugenja" for the Fox)."""
    from . import families
    own = [s for s in basic() if s["clan"].lower() == clan.lower() and not _other_clan_tag(s["name"], clan)]
    if own:
        return own
    tag = f"{clan.lower()} clan"
    tagged = [s for s in basic() if tag in s["name"].lower()]
    if tagged:
        return tagged
    fams = [f["name"].lower() for f in families.by_clan(clan)]
    return [s for s in basic() if any(s["name"].lower().startswith(f + " ") for f in fams)]


def techniques_up_to(name: str, rank: int) -> list[dict]:
    """Ranked techniques (1..rank) a character of this school is entitled to."""
    s = get(name)
    if not s:
        return []
    return [t for t in s["techniques"] if 1 <= t["rank"] <= rank]


# --- Applying a school to a character at creation ---------------------------
def effective_fields(school: dict) -> tuple[str, str, str]:
    """Return (skills, honor, outfit) with fallback to benefit-embedded values.

    Some schools (Dragon monks, ronin orders) pack Skills/Honor/Outfit into the
    benefit field as pipe-delimited segments instead of using their own fields."""
    skills = school.get("skills", "").strip()
    honor = school.get("honor", "").strip()
    outfit = school.get("outfit", "").strip()
    if skills and honor:
        return skills, honor, outfit
    benefit = school.get("benefit", "")
    if "|" not in benefit:
        return skills, honor, outfit
    for seg in benefit.split("|")[1:]:
        seg = seg.strip()
        sl = seg.lower()
        if sl.startswith("skills:") and not skills:
            skills = seg[len("Skills:"):].strip()
        elif sl.startswith("honor:") and not honor:
            honor = seg[len("Honor:"):].strip()
        elif sl.startswith("outfit:") and not outfit:
            outfit = seg[len("Outfit:"):].strip()
    return skills, honor, outfit


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

    assigned: [(skill_name, rank, emphasis|None)]: concrete starting skills.
    wildcards: ['any one Bugei Skill', ...]: player-choice slots, left for the DM.
    """
    assigned: list[tuple[str, int, str | None]] = []
    wildcards: list[str] = []
    for raw in _split_commas(skills or ""):
        p = raw.strip()
        if not p:
            continue
        low = p.lower()
        if low.startswith("any") or "any one" in low or low.startswith("choose") or low.startswith("one ") or re.search(r"\((?:pick|choose)\b", low):
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
            inner = mp.group(1).strip()
            if "/" in inner:
                wildcards.append(p)
                continue
            if re.search(r"\b(?:may|replace|after|instead|see |era)\b", inner, re.I):
                p = re.sub(r"\s*\([^)]+\)", "", p).strip()
            else:
                emph = inner
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

    eff_skills, eff_honor, eff_outfit = effective_fields(school)

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

    honor = parse_honor(eff_honor)
    if honor is not None:
        character.honor = honor
        report["honor"] = honor

    assigned, wildcards = parse_skills(eff_skills)
    for name, rank, emph in assigned:
        character.skills[name] = max(character.skills.get(name, 0), rank)
        report["skills"].append(f"{name} {rank}")
        if emph:
            lst = character.emphases.setdefault(name, [])
            if emph not in lst:
                lst.append(emph)
                report["emphases"].append(f"{name} ({emph})")
    report["wildcards"] = wildcards

    outfit_items = apply_outfit(character, eff_outfit)
    report["outfit"] = outfit_items
    return report


_ARMOR_KEYWORDS = {
    "ashigaru": "ashigaru",
    "light armor": "light",
    "heavy armor": "heavy",
    "tatami": "tatami",
    "riding armor": "riding",
    "bogu": "bogu",
    "tetsu-do": "tetsu_do",
}

_WEAPON_KEYWORDS: dict[str, str] = {
    "katana": "katana",
    "wakizashi": "wakizashi",
    "tanto": "tanto",
    "knife": "tanto",
    "kama": "kama",
    "bo staff": "bo",
    "bo": "bo",
    "sword": "katana",
    "bow": "yumi",
    "yumi": "yumi",
    "spear": "yari",
    "yari": "yari",
    "naginata": "naginata",
    "nagamaki": "nagamaki",
    "bisento": "bisento",
    "nage-yari": "nage_yari",
    "lance": "lance",
}

_WORD_NUMBERS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
    "twelve": 12, "fifteen": 15, "twenty": 20,
}


def _match_single_armor(text: str) -> str | None:
    """If text names exactly one armor type (no 'or'), return catalog key."""
    low = text.lower().strip()
    if " or " in low:
        return None
    for phrase, key in _ARMOR_KEYWORDS.items():
        if phrase in low:
            return key
    return None


def _match_weapon(text: str) -> str | None:
    """If text names exactly one weapon (no 'or'/'any'), return catalog key."""
    low = text.lower().strip()
    if " or " in low or low.startswith("any"):
        return None
    return _WEAPON_KEYWORDS.get(low)


def _weapon_display(catalog_key: str) -> str:
    """Catalog key → title-cased display name for c.weapons."""
    return catalog_key.replace("_", " ").title()


def _add_weapon(character, catalog_key: str) -> str:
    """Add a weapon to character.weapons by catalog key; return display name."""
    name = _weapon_display(catalog_key)
    if name not in character.weapons:
        character.weapons.append(name)
    return name


def _add_inventory(character, name: str, qty: int = 1) -> None:
    character.inventory[name] = character.inventory.get(name, 0) + qty


def apply_outfit(character, outfit: str) -> list[str]:
    """Parse a school outfit string and apply items to the character.
    Returns list of applied/recorded items for reporting."""
    from .combat import ARMOR_CATALOG
    if not outfit or not outfit.strip():
        return []
    applied: list[str] = []
    for raw in _split_commas(outfit):
        item = raw.strip()
        if not item:
            continue
        low = item.lower()
        m_koku = re.match(r"(\d+(?:\.\d+)?)\s+koku", low)
        if m_koku:
            character.koku += float(m_koku.group(1))
            applied.append(item)
            continue
        if low == "daisho":
            for w in ("Katana", "Wakizashi"):
                if w not in character.weapons:
                    character.weapons.append(w)
            applied.append("Daisho (Katana + Wakizashi)")
            continue
        # Compound "X and Y" (e.g. "Bow and 20 Arrows")
        if " and " in low and " or " not in low:
            parts = item.split(" and ", 1)
            left, right = parts[0].strip(), parts[1].strip()
            wk = _match_weapon(left)
            if wk:
                wname = _add_weapon(character, wk)
                m_rq = re.match(r"(\d+)\s+(.+)", right)
                if m_rq:
                    _add_inventory(character, m_rq.group(2).strip(), int(m_rq.group(1)))
                else:
                    _add_inventory(character, right)
                label = f"{wname} + {right}" if left.lower() != wname.lower() else f"{wname} + {right}"
                applied.append(label)
                continue
        armor_key = _match_single_armor(item)
        if armor_key and armor_key in ARMOR_CATALOG:
            spec = ARMOR_CATALOG[armor_key]
            character.armor_name = armor_key
            character.armor_tn_bonus = spec["tn_bonus"]
            character.armor_reduction = spec["reduction"]
            applied.append(f"{item} (TN +{spec['tn_bonus']}, Red {spec['reduction']})")
            continue
        weapon_key = _match_weapon(item)
        if weapon_key:
            wname = _add_weapon(character, weapon_key)
            if low != wname.lower():
                applied.append(f"{item} (equipped as {wname})")
            else:
                applied.append(wname)
            continue
        # "bundle of N items" (e.g. "bundle of ten nage-yari")
        m_bundle = re.match(r"bundle of (\w+)\s+(.+)", low)
        if m_bundle:
            qty = _WORD_NUMBERS.get(m_bundle.group(1), 1)
            name = m_bundle.group(2).strip()
            name = " ".join(w.capitalize() for w in name.split())
            _add_inventory(character, name, qty)
            applied.append(f"{qty}x {name}")
            continue
        m_qty = re.match(r"(\d+)\s+(.+)", item)
        if m_qty:
            qty = int(m_qty.group(1))
            name = m_qty.group(2).strip()
            _add_inventory(character, name, qty)
        else:
            _add_inventory(character, item)
        applied.append(item)
    return applied
