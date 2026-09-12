#!/usr/bin/env python3
"""Transcribe every School AND path from the GDD s29 markdown into
`l5r_rules/schools_catalog.py`, verbatim.

Three kinds of entry are captured, each tagged with a `category`:

  * "basic"     — a starting School: has a "- Skills:" line, a Benefit, Honor,
                  an Outfit and a Rank 1–5 Technique ladder.
  * "advanced"  — an Advanced School (under an **ADVANCED SCHOOLS:** heading):
                  prerequisites in prose + a short Rank Technique ladder.
  * "alternate" — an Alternate Path / Rank-N Path (under **ALTERNATE PATHS:** or
                  **RANK n PATHS:**): a "Replaces: … Requires: …" prose line that
                  usually carries a single inline "Technique — Name: effect".

Technique line shapes handled:
    - Rank N — Name: effect         (dash; basic & advanced ladders)
    - Technique — Name: effect      (dash; some paths)
    Technique — Name: effect        (inline, mid-prose; clan-file paths)

The category of a non-basic entry comes from the most recent section heading;
an entry with a Skills line is always "basic". Section headings
(**BASIC SCHOOLS:**, **ADVANCED SCHOOLS:**, **ALTERNATE PATHS:**, **RANK n
PATHS:**) are recognised and never emitted as schools.

s29.15 (the LOCKED courtier implementation framework) is skipped: it uses bold
`**Rank n — …:**` technique headers that would mis-parse as schools, and its two
schools (Children of Doji, Scorpion Instigator) already appear in the clan files.
Nothing is invented — text is copied as-is.

Usage (from discord_bot/):  python3 tools/extract_schools.py [path-to-gdd]
"""

from __future__ import annotations

import os
import re
import sys

CLAN_BY_FILE = {
    "s29.1_": "Crab", "s29.2_": "Crane", "s29.3_": "Dragon", "s29.4_": "Lion",
    "s29.5_": "Phoenix", "s29.6_": "Scorpion", "s29.7_": "Unicorn",
    "s29.8_": "Imperial", "s29.9_": "Mantis", "s29.10_": "Mantis",
    "s29.11_": "Minor Clan", "s29.12_": "Ronin", "s29.13_": "Brotherhood",
    "s29.14_": "Miscellaneous",
}

HEADER = re.compile(r"^\*\*(.+?):\*\*\s*$")
RANK_TECH = re.compile(r"^-\s*Rank\s*(\d+)\s*[—–-]\s*(.+?):\s*(.+)$")
ALT_TECH = re.compile(r"^-\s*Technique\s*[—–-]\s*(.+?):\s*(.+)$")
ALT_TECH2 = re.compile(r"^-\s*Technique:\s*(.+?)\s*[—–-]\s*(.+)$")  # "- Technique: Name — effect"
PROSE_TECH = re.compile(r"Technique\s*[—–-]\s*(.+?):\s*(.+)$")
# Compressed ladder some shugenja/monk schools use, all ranks on one line with
# no technique name: "Rank 1: … Rank 2: … Rank 3: …".
COMPRESSED_HEAD = re.compile(r"^Rank\s*\d+:", re.I)
COMPRESSED = re.compile(r"Rank\s*(\d+):\s*(.*?)(?=\s*Rank\s*\d+:|$)", re.S)

SECTION_CAT = [
    (re.compile(r"^ADVANCED SCHOOLS", re.I), "advanced"),
    (re.compile(r"^BASIC SCHOOLS", re.I), "basic"),
    (re.compile(r"^ALTERNATE PATHS", re.I), "alternate"),
    (re.compile(r"^RANK\s*\d+\s*PATHS", re.I), "alternate"),
]
_CAT_ORDER = {"basic": 0, "advanced": 1, "alternate": 2}


def _clan_for(fname: str) -> str:
    for prefix, clan in CLAN_BY_FILE.items():
        if fname.startswith(prefix):
            return clan
    return ""


def _section_category(name: str) -> str | None:
    for pat, cat in SECTION_CAT:
        if pat.match(name.strip()):
            return cat
    return None


def _split_name(header_inner: str) -> tuple[str, list[str]]:
    tags = re.findall(r"\[([^\]]+)\]", header_inner)
    name = re.sub(r"\s*\[[^\]]+\]", "", header_inner).strip()
    return name, tags


def _parse_block(name: str, tags: list[str], clan: str, category: str, block: list[str]) -> dict:
    rec = {
        "name": name, "clan": clan, "category": category, "keywords": tags,
        "benefit": "", "skills": "", "honor": "", "outfit": "",
        "affinity": "", "prereq": "", "techniques": [],
    }
    for line in block[1:]:
        s = line.strip()
        if not s:
            continue
        if s.startswith("-"):
            m = RANK_TECH.match(s)
            if m:
                rec["techniques"].append({"rank": int(m.group(1)), "name": m.group(2).strip(), "effect": m.group(3).strip()})
                continue
            m = ALT_TECH.match(s)
            if m:
                rec["techniques"].append({"rank": 0, "name": m.group(1).strip(), "effect": m.group(2).strip()})
                continue
            m = ALT_TECH2.match(s)
            if m:
                rec["techniques"].append({"rank": 0, "name": m.group(1).strip(), "effect": m.group(2).strip()})
                continue
            body = s[1:].strip()
            if COMPRESSED_HEAD.match(body):
                for rn, eff in COMPRESSED.findall(body):
                    rec["techniques"].append({"rank": int(rn), "name": "", "effect": eff.strip()})
                continue
            low = body.lower()
            if low.startswith("benefit:"):
                rec["benefit"] = body.split(":", 1)[1].strip()
            elif low.startswith("skills:"):
                rec["skills"] = body.split(":", 1)[1].strip()
            elif low.startswith("honor:"):
                rest = body.split(":", 1)[1].strip()
                if "|" in rest:
                    honor_part, outfit_part = rest.split("|", 1)
                    rec["honor"] = honor_part.strip()
                    rec["outfit"] = outfit_part.split(":", 1)[-1].strip()
                else:
                    rec["honor"] = rest
            elif low.startswith("outfit:"):
                if not rec["outfit"]:
                    rec["outfit"] = body.split(":", 1)[1].strip()
            elif low.startswith("affinity"):
                rec["affinity"] = body.split(":", 1)[1].strip()
            elif low.startswith("replaces:") or low.startswith("requires:"):
                rec["prereq"] = (rec["prereq"] + " " + body).strip()
        else:
            # A prose paragraph. On non-basic entries it carries the prereqs and,
            # for clan-file paths, an inline Technique. On basic schools it is
            # only flavour text and is ignored (they have structured fields).
            mt = PROSE_TECH.search(s)
            if mt:
                prefix = s[: mt.start()].strip()
                rec["techniques"].append({"rank": 0, "name": mt.group(1).strip(), "effect": mt.group(2).strip()})
                if prefix and category != "basic":
                    rec["prereq"] = (rec["prereq"] + " " + prefix).strip()
            elif category != "basic" and re.search(r"\b(Requires?|Replaces?)\b", s, re.I):
                rec["prereq"] = (rec["prereq"] + " " + s).strip()
    rec["techniques"].sort(key=lambda t: (t["rank"] if t["rank"] else 99))
    return rec


def _parse_file(path: str, clan: str) -> list[dict]:
    lines = open(path, encoding="utf-8").read().split("\n")
    heads = [i for i, l in enumerate(lines) if HEADER.match(l)]
    out: list[dict] = []
    current_cat = "basic"
    for idx, start in enumerate(heads):
        name, tags = _split_name(HEADER.match(lines[start]).group(1))
        sec = _section_category(name)
        if sec is not None:
            current_cat = sec
            continue  # a section heading, not a school
        end = heads[idx + 1] if idx + 1 < len(heads) else len(lines)
        block = lines[start:end]
        has_skills = any(l.strip().lower().startswith("- skills:") for l in block[1:])
        category = "basic" if has_skills else current_cat
        rec = _parse_block(name, tags, clan, category, block)
        # A real school/path has either a Skills line or at least one Technique.
        if has_skills or rec["techniques"]:
            out.append(rec)
    return out


def main() -> None:
    gdd = sys.argv[1] if len(sys.argv) > 1 else os.path.join("..", "gdd")
    files = sorted(
        f for f in os.listdir(gdd)
        if re.match(r"s29\.\d+_", f) and f.endswith(".md") and not f.startswith("s29.15_")
    )
    catalog: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for fname in files:
        clan = _clan_for(fname)
        for rec in _parse_file(os.path.join(gdd, fname), clan):
            key = (rec["name"].lower(), rec["category"])
            if key in seen:
                continue
            seen.add(key)
            catalog.append(rec)
    catalog.sort(key=lambda r: (r["clan"], _CAT_ORDER.get(r["category"], 9), r["name"]))
    out = os.path.join("l5r_rules", "schools_catalog.py")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write('"""AUTO-GENERATED by tools/extract_schools.py — do not edit by hand.\n\n')
        fh.write("Schools and paths (basic / advanced / alternate) with their Techniques,\n")
        fh.write("transcribed verbatim from the GDD s29 markdown. ")
        fh.write(f"{len(catalog)} entries. Re-run the extractor to refresh.\n\"\"\"\n\n")
        fh.write("SCHOOLS_DATA = [\n")
        for rec in catalog:
            fh.write("    " + repr(rec) + ",\n")
        fh.write("]\n")
    tech_total = sum(len(r["techniques"]) for r in catalog)
    from collections import Counter
    cats = Counter(r["category"] for r in catalog)
    print(f"Wrote {len(catalog)} entries ({tech_total} techniques) to {out}")
    print("by category:", dict(cats))
    print("by clan:", dict(Counter(r["clan"] for r in catalog)))


if __name__ == "__main__":
    main()
