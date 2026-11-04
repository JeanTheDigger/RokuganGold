"""Access helpers over the generated spell catalog (GDD s32-s37).

Data (l5r_rules/spells_catalog.py) is produced verbatim by
tools/extract_spells.py. This module indexes and queries it.
"""

from __future__ import annotations

from .spells_catalog import SPELLS_DATA

ALL = SPELLS_DATA

# The extracted catalog kept a markdown escape in two names ("Wisdom ****&**** Clarity"). Show the
# real name, and still find a spell stored on an older sheet under the escaped one.
_JUNK = "****&****"
_BY_NAME = {}
for _s in SPELLS_DATA:
    _old = _s["name"]
    _s["name"] = _old.replace(_JUNK, "&")
    _BY_NAME[_s["name"].lower()] = _s
    _BY_NAME[_old.lower()] = _s


def get(name: str) -> dict | None:
    return _BY_NAME.get(name.lower().strip())


def search(query: str) -> list[dict]:
    q = query.lower().strip()
    return [
        s for s in SPELLS_DATA
        if q in s["name"].lower() or q in s["element"].lower() or q in s["keyword"].lower()
    ]


def by_element(element: str) -> list[dict]:
    return [s for s in SPELLS_DATA if s["element"].lower() == element.lower()]


def elements() -> list[str]:
    return sorted({s["element"] for s in SPELLS_DATA})
