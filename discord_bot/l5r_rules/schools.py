"""Access helpers over the generated school catalog (GDD s29).

The data (l5r_rules/schools_catalog.py) is produced verbatim by
tools/extract_schools.py. This module just indexes and queries it.
"""

from __future__ import annotations

from .schools_catalog import SCHOOLS_DATA

ALL = SCHOOLS_DATA
_BY_NAME = {s["name"].lower(): s for s in SCHOOLS_DATA}


def get(name: str) -> dict | None:
    return _BY_NAME.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [s for s in SCHOOLS_DATA if q in s["name"].lower() or q in s["clan"].lower()]


def by_clan(clan: str) -> list[dict]:
    return [s for s in SCHOOLS_DATA if s["clan"].lower() == clan.lower()]


def clans() -> list[str]:
    return sorted({s["clan"] for s in SCHOOLS_DATA})


def techniques_up_to(name: str, rank: int) -> list[dict]:
    """Ranked techniques (1..rank) a character of this school is entitled to."""
    s = get(name)
    if not s:
        return []
    return [t for t in s["techniques"] if 1 <= t["rank"] <= rank]
