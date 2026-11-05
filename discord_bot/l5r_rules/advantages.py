"""Access helpers over the generated advantages/disadvantages catalog (GDD s45).

Data (l5r_rules/advantages_catalog.py) is produced verbatim by
tools/extract_advantages.py. This module indexes and queries it.
"""

from __future__ import annotations

import re

from .advantages_catalog import ADVANTAGES_DATA

ALL = ADVANTAGES_DATA

# (Disadvantages keep their top tier: it is the XP they give back.)
# A tiered cost such as "2/4/6 pts" (Magic Resistance) is stored with its top tier as `points`.
# Buying the entry gets Rank 1, so charge the first tier; later ranks are bought one at a time.
for _r in ADVANTAGES_DATA:
    _m = re.match(r"^\s*(\d+)\s*/\s*\d+", _r.get("cost_text") or "")
    if _m and _r.get("points") is not None and _r["kind"] == "advantage":
        _r["points"] = int(_m.group(1))


def get(name: str, kind: str | None = None) -> dict | None:
    n = name.lower().strip()
    for r in ADVANTAGES_DATA:
        if r["name"].lower() == n and (kind is None or r["kind"] == kind):
            return r
    return None


def search(query: str, kind: str | None = None) -> list[dict]:
    q = query.lower().strip()
    return [
        r for r in ADVANTAGES_DATA
        if (kind is None or r["kind"] == kind)
        and (q in r["name"].lower() or q in (r.get("category") or "").lower())
    ]


def by_kind(kind: str) -> list[dict]:
    return [r for r in ADVANTAGES_DATA if r["kind"] == kind]


# --- Clan and school-type price adjustments ------------------------------------
# The entries print them in their own text: "Lion pay 6 pts", "Crab and bushi pay 2 pts",
# "Worth 4 pts to Lion", "Worth 1 additional pt to courtiers".
_PAY_SPLIT = re.compile(r",\s+(?=[A-Z][\w' -]*\s+pay\b)")
_PAY_RE = re.compile(r"^(?P<who>[A-Z][\w' ,-]*?)\s+pays?\s+(?P<n>\d+)\s+pts?(?P<less>\s+less)?(?P<tail>\s+total)?\b")
_WORTH_RE = re.compile(r"Worth\s+(?P<n>\d+)\s+(?P<add>additional\s+)?pts?\s+to\s+(?P<who>[^.]+)")
_CLASS_WORDS = {"bushi": "bushi", "courtier": "courtier", "courtiers": "courtier", "shugenja": "shugenja",
                "monk": "monk", "monks": "monk", "ninja": "ninja"}


def _who_matches(who: str, clan: str, school_type: str, family: str) -> bool:
    who = re.sub(r"\bcharacters?\b", "", who, flags=re.IGNORECASE)
    stype = (school_type or "").lower()
    for tok in re.split(r",|\band\b|\bor\b", who):
        t = tok.strip().lower()
        if not t:
            continue
        cls = _CLASS_WORDS.get(t)
        if cls is not None:
            if cls in stype:
                return True
        elif t in ((clan or "").lower(), (family or "").lower()):
            return True
    return False


def price_delta(entry: dict | None, clan: str = "", school_type: str = "", family: str = "") -> int:
    """How much the points of an Advantage (negative) or Disadvantage (positive) change for a character
    of this Clan, school type and family, from the price line in the entry's own text.
    0 when the text names nobody who matches."""
    if not entry or entry.get("points") is None:
        return 0
    text = entry.get("effect") or ""
    base = entry["points"]
    best = base
    if entry["kind"] == "advantage":
        for sentence in re.split(r"\.\s+(?=[A-Z])", text):
            for clause in _PAY_SPLIT.split(sentence):
                m = _PAY_RE.match(clause.strip())
                if not m or m["tail"]:
                    continue
                if _who_matches(m["who"], clan, school_type, family):
                    price = base - int(m["n"]) if m["less"] else int(m["n"])
                    best = min(best, price)
        return max(0, best) - base
    for m in _WORTH_RE.finditer(text):
        if _who_matches(m["who"], clan, school_type, family):
            worth = base + int(m["n"]) if m["add"] else int(m["n"])
            best = max(best, worth)
    return best - base


def base_entry(name: str, kind: str | None = None) -> dict | None:
    """The catalog entry behind a name stored on a sheet, such as "Debt (4 points)" or "Friend of the Elements (Fire)"."""
    hit = get(name, kind)
    if hit is not None:
        return hit
    stripped = re.sub(r"\s*\(.*$", "", name).strip()
    return get(stripped, kind) if stripped and stripped != name else None
