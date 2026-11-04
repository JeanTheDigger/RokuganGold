"""Heritage results as structured, fully applicable perks.

Every Heritage Table result carries more than its `grants`: XP discounts, free
skill ranks the player chooses, choices between two options, restrictions and a
long tail of "Fortune determines ..." details. This module turns each result
into a list of perks (plain JSON-safe dicts, so they live in the creation
wizard's saved state) and resolves them against the answers given so far.

Perk shape:  {"id", "who": "auto" | "player" | "staff", "label", "ask", "actions",
              "condition", optional "grants"}

`ask` describes the question: {"kind": "clan" | "element" | "skill" | "weapon" |
"choice" | "trait" | "tattoo" | "text", ...}. `actions` run once the question is
answered (or at once for "auto" perks); templates use {v} (the answer), {d} (its
detail text), {c} (a clan's short name), {opp} (an element's opposite) and {perkid}
(any other perk's answer).

Nothing here touches Discord. `resolve()` is pure; the apply_* helpers mutate a
Character.
"""

from __future__ import annotations

import re
from typing import Any

from . import advantages as _advantages
from .character import normalise_purse

GREAT_CLANS: tuple[str, ...] = ("Crab", "Crane", "Dragon", "Lion", "Mantis", "Phoenix", "Scorpion", "Unicorn")
MINOR_CLANS: tuple[str, ...] = (
    "Badger", "Bat", "Boar", "Centipede", "Dragonfly", "Fox", "Hare", "Monkey",
    "Oriole", "Ox", "Sparrow", "Tiger", "Tortoise", "Wasp",
)
ELEMENTS: tuple[str, ...] = ("Air", "Earth", "Fire", "Water")
OPPOSING: dict[str, str] = {"Air": "Earth", "Earth": "Air", "Fire": "Water", "Water": "Fire"}
TENETS: tuple[str, ...] = ("Compassion", "Courage", "Courtesy", "Duty", "Honesty", "Honor", "Sincerity")
TRAITS: tuple[str, ...] = (
    "Agility", "Awareness", "Intelligence", "Perception", "Reflexes", "Stamina", "Strength", "Willpower",
)
FORTUNES: tuple[str, ...] = ("Benten", "Bishamon", "Daikoku", "Ebisu", "Fukurokujin", "Hotei", "Jurojin")

# Advantages whose cost the catalog leaves variable, so the wizard's menus cannot sell them.
SPECIAL_BASES: tuple[str, ...] = ("Sacred Weapon", "Luck", "Gentry", "Blackmail")

# Discount targets with no entry in the advantage catalog: recorded for staff, never priced.
_NO_CATALOG_ENTRY: tuple[str, ...] = ("Lion Ancestor", "Phoenix Clan Ancestor", "Unicorn Ancestor")


def clan_display(clan: str) -> str:
    return "Imperial families" if clan == "Imperial" else f"{clan} Clan"


def all_clans() -> tuple[str, ...]:
    return GREAT_CLANS + MINOR_CLANS + ("Imperial",)


# --------------------------------------------------------------------------
#  Catalog-derived costs for the advantages the wizard cannot sell directly
# --------------------------------------------------------------------------

def _sacred_weapons() -> dict[str, tuple[str, int]]:
    rec = _advantages.get("Sacred Weapon", "advantage")
    out: dict[str, tuple[str, int]] = {}
    if rec:
        for m in re.finditer(r"(\w+): ([^():]+?) \((\d+) pts\)", rec["effect"]):
            out[m.group(1)] = (m.group(2).strip(), int(m.group(3)))
    return out


def _gentry_holdings() -> list[tuple[str, int]]:
    rec = _advantages.get("Gentry", "advantage")
    out: list[tuple[str, int]] = []
    if rec:
        for m in re.finditer(r"([A-Za-z/ ]+?) \((\d+) pts\)", rec["effect"]):
            out.append((m.group(1).strip(), int(m.group(2))))
    return out


def _luck_first_rank_cost() -> int:
    rec = _advantages.get("Luck", "advantage")
    m = re.match(r"\s*(\d+)", (rec or {}).get("cost_text", ""))
    return int(m.group(1)) if m else 3


SACRED_WEAPONS = _sacred_weapons()


# --------------------------------------------------------------------------
#  Perk construction
# --------------------------------------------------------------------------

def _perk(who: str, label: str, ask: dict | None = None, actions: list[dict] | None = None,
          condition: dict | None = None, pid: str | None = None) -> dict:
    return {"id": pid, "who": who, "label": label, "ask": ask, "actions": actions or [], "condition": condition}


def _text_ask(prompt: str, maxlen: int = 100) -> dict:
    return {"kind": "text", "prompt": prompt, "max": maxlen}


def _narrative(title: str, note: str) -> dict:
    """A "Fortune determines ..." detail with no mechanical hook: Staff write it, the sheet keeps it."""
    return _perk("staff", note, _text_ask(f"{title}: What did Fortune decide?", 300),
                 [{"op": "detail", "text": f"{title}: {{v}}"}])


def _opt(value: str, label: str, actions: list[dict] | None = None, detail: str | None = None) -> dict:
    o: dict[str, Any] = {"value": value, "label": label, "actions": actions or []}
    if detail:
        o["detail"] = detail
    return o


def _clan_fill_actions(*, grudge: bool = False) -> list[dict]:
    acts = [
        {"op": "sub", "old": "another clan", "new": "{v}"},
        {"op": "sub", "old": "former clan", "new": "{v}"},
    ]
    if grudge:
        acts.append({"op": "rename", "old": "Sworn Enemy", "new": "Sworn Enemy ({v})"})
    return acts


_NARRATIVE_NOTES: dict[str, str] = {
    "Fortune determines exactly how the Shosuro Infiltrators will assist when the debt is called in.":
        "Shosuro Infiltrators' debt (usable once)",
    "Fortune determines the consequences of being considered junshin by the Scorpion Clan.": "Junshin",
    "Fortune determines the nature and properties of this nemuranai.": "Nemuranai",
    "Fortune determines the nature and properties of this strange foreign artifact.": "Foreign artifact",
    "Fortune determines the nature and timing of this ancestral threat.": "Ancestral threat",
    "Fortune determines the nature and timing of this oni haunting.": "Oni haunting",
    "Fortune determines the nature of the jinn's lingering influence on your bloodline.": "Jinn's influence",
    "Fortune determines the nature of this ancestor's disgrace.": "Ancestor's disgrace",
    "Fortune determines the nature of this ancestral battlefield item and the spirit within it.":
        "Battlefield item and its spirit",
    "Fortune determines the nature of this mysterious item and its power.": "Mysterious item",
    "Fortune determines the nature of this superior-quality item and which Great Clan family wants it returned.":
        "Superior-quality item and the family that wants it back",
    "Fortune determines which Asahina fetish was passed down.": "Asahina fetish",
    "The Shadow is looking for you. Fortune determines the nature of this pursuit.": "Pursuit by the Shadow",
    "The blade is afflicted with a curse determined by the Fortune.": "The blade's curse",
    "You possess a small crystal item (pendant, earring, or necklace). Fortune determines its properties.":
        "Crystal item",
}

_SKILL_POOL_NOTES: dict[str, str] = {
    "Gain +1 rank in a weapon Skill of your choice.": "weapon",
    "Gain 1 free Rank in a Weapon Skill of your choice.": "weapon",
    "Gain 1 free Rank in a Bugei Skill of your choice.": "bugei",
    "Gain 1 free Rank in a Craft Skill of your choice.": "craft",
    "Gain 1 free Rank in a High Skill of your choice.": "high",
    "Gain 1 free Rank in a Low Skill of your choice.": "low",
    "Gain 1 free Rank in either Battle or a Weapon Skill of your choice.": "battle_weapon",
    "Gain 1 free Rank in either Sailing or Navigation (your choice).": "sailing_nav",
    "Gain 1 free Rank in either Lore: Shugenja or Spellcraft (your choice).": "lore_spell",
    "Gain 1 free Rank in any one Skill which is not a School Skill for you.": "any_nonschool",
    "Gain 1 free Rank in an iconic School Skill for your school.": "school",
}

_POOL_LABEL: dict[str, str] = {
    "weapon": "a Weapon Skill", "bugei": "a Bugei Skill", "craft": "a Craft Skill", "high": "a High Skill",
    "low": "a Low Skill", "battle_weapon": "Battle or a Weapon Skill", "sailing_nav": "Sailing or Navigation",
    "lore_spell": "Lore: Shugenja or Spellcraft", "any_nonschool": "a Skill that is not a School Skill",
    "school": "one of your School Skills",
}


def _discount_target_specs(name: str) -> list[dict] | None:
    """Targets for a "May take X for N less XP" note, or None when X is not a catalog advantage."""
    n = name.replace(" Advantage", "").strip()
    n = re.sub(r"^(?:either |a |an |the )", "", n)
    n = re.sub(r"^Rank of (?:the )?", "", n)
    if n in _NO_CATALOG_ENTRY:
        return None
    if n.startswith("Sacred Weapon"):
        clan = "Lion" if "Lion" in n else "Unicorn"
        weapon = SACRED_WEAPONS.get(clan, (clan, 0))[0]
        return [{"base": "Sacred Weapon", "contains": weapon.lower()}]
    if n.startswith("Seven Fortunes Blessing:"):
        return [{"base": "Seven Fortunes' Blessing", "contains": n.split(":", 1)[1].split("'")[0].strip().lower()}]
    n = re.sub(r"\s*\([^)]*\)", "", n).strip()
    if n.startswith("Paragon of "):
        return [{"base": "Paragon", "contains": n[len("Paragon of "):].lower()}]
    out: list[dict] = []
    for part in re.split(r" or (?:the )?", n):
        part = part.strip()
        if not part:
            continue
        spec: dict[str, Any] = {"base": part}
        if part == "Friendly Kami":
            spec["school_type"] = ["shugenja"]
        out.append(spec)
    return out


_DISCOUNT_RE = re.compile(
    r"^May take (?:a |an |the |either the )?(?P<name>.+?) for (?:(?:(?P<n>\d+) less)|(?:only (?P<fixed>\d+))) "
    r"(?:XP|points)(?: \(reduced cost\))?\.(?P<rest>.*)$"
)


def _classify(note: str) -> list[dict] | None:
    """Perk templates for one note, or None when the note is not recognised."""
    if note in _NARRATIVE_NOTES:
        return [_narrative(_NARRATIVE_NOTES[note], note)]

    pool = _SKILL_POOL_NOTES.get(note)
    if pool:
        return [_perk("player", note, {"kind": "skill", "pool": pool},
                      [{"op": "skill", "skill": "{v}", "ranks": 1}])]

    exact: dict[str, list[dict]] = {
        "Gain 1 free Rank in an Artisan skill (Fortune determines which).": [
            _perk("staff", note, {"kind": "skill", "pool": "artisan"}, [{"op": "skill", "skill": "{v}", "ranks": 1}])],
        "Gain 1 free Rank in the Lore Skill for the defeated duelist's clan (Fortune determines which).": [
            _perk("staff", note, {"kind": "clan", "scope": "others"},
                  [{"op": "skill", "skill": "Lore: {c} Clan", "ranks": 1}])],
        "Also receive a weapon of your choice.": [
            _perk("player", note, {"kind": "weapon"}, [{"op": "weapon", "key": "{v}"}])],
        "Bushi gain Friend of the Elements free. Shugenja gain Friend of the Brotherhood of Shinsei free.": [
            _perk("player", note, {"kind": "element"}, [{"op": "adv", "name": "Friend of the Elements ({v})"}],
                  {"school_type": ["bushi"]}),
            _perk("auto", note, None, [{"op": "adv", "name": "Friend of the Brotherhood"}],
                  {"school_type": ["shugenja"]})],
        "Cannot purchase Way of the Land, Hero of the People, or Ally Advantages.": [
            _perk("auto", note, None, [{"op": "block", "names": ["Way of the Land", "Hero of the People", "Ally", "Allies"]}])],
        "You may never take the Gentry Advantage.": [
            _perk("auto", note, None, [{"op": "block", "names": ["Gentry"]}])],
        "Choose a Skill: Gain either 2 free Ranks or 1 free Emphasis in that Skill. Jealousy applies to the same Skill.": [
            _perk("player", note, {"kind": "skill", "pool": "any"}, [{"op": "sub", "old": "chosen Skill", "new": "{v}"}],
                  pid="jealousy_skill"),
            _perk("player", "Take 2 free Ranks or 1 free Emphasis in that Skill.",
                  {"kind": "choice", "options": [
                      _opt("ranks", "2 free Ranks", [{"op": "skill", "skill": "{jealousy_skill}", "ranks": 2}]),
                      _opt("emphasis", "1 free Emphasis",
                           [{"op": "emph", "skill": "{jealousy_skill}", "emphasis": "{d}"}], "Which emphasis?")]},
                  pid="jealousy_mode")],
        "Choose another clan: Gain a 2-point Ally and 1 Rank in that clan's Lore Skill.": [
            _perk("player", note, {"kind": "clan", "scope": "others"},
                  _clan_fill_actions() + [{"op": "skill", "skill": "Lore: {c} Clan", "ranks": 1}])],
        "Choose which clan the Ally belongs to.": [
            _perk("player", note, {"kind": "clan", "scope": "others"}, _clan_fill_actions())],
        "Choose either Seven Fortune's Blessing or Inari's Blessing. Fortune determines the Driven form.": [
            _perk("player", "Choose a Fortune's Blessing.",
                  {"kind": "choice", "options": [
                      _opt(f.lower(), f"Seven Fortunes' Blessing: {f}",
                           [{"op": "adv", "name": f"Seven Fortunes' Blessing ({f})"}]) for f in FORTUNES]
                   + [_opt("inari", "Inari's Blessing", [{"op": "adv", "name": "Inari's Blessing"}])]}),
            _perk("staff", "Fortune determines the form of the Driven Disadvantage.",
                  _text_ask("What is the Driven goal, tied to the chosen Fortune?"),
                  [{"op": "rename", "old": "Driven", "new": "Driven ({v})"}])],
        "Choose either the Disbeliever or the Infamy Disadvantage (for no points).": [
            _perk("player", note, {"kind": "choice", "options": [
                _opt("disbeliever", "Disbeliever", [{"op": "dis", "name": "Disbeliever"}]),
                _opt("infamy", "Infamous", [{"op": "dis", "name": "Infamous"}])]})],
        "Choose either the True Love or Lost Love Disadvantage.": [
            _perk("player", note, {"kind": "choice", "options": [
                _opt("true", "True Love", [{"op": "dis", "name": "True Love ({d})"}], "Who is your true love?"),
                _opt("lost", "Lost Love", [{"op": "dis", "name": "Lost Love ({d})"}], "Who did you lose?")]})],
        "Choose one tenet of Bushido for the Paragon Advantage and a different tenet for the Failure of Bushido Disadvantage. This overrides normal restrictions on taking these together.": [
            _perk("player", "Choose the tenet for your Paragon Advantage.",
                  {"kind": "choice", "options": [_opt(t.lower(), t, [{"op": "adv", "name": f"Paragon ({t})"}]) for t in TENETS]},
                  pid="tenet_paragon"),
            _perk("player", "Choose a different tenet for your Failure of Bushido Disadvantage.",
                  {"kind": "choice", "differs_from": "tenet_paragon",
                   "options": [_opt(t.lower(), t, [{"op": "dis", "name": f"Failure of Bushido ({t})"}]) for t in TENETS]})],
        "Choose: Gain either 2 free Ranks in Lore: Underworld or a 2-point Ally in the criminal classes.": [
            _perk("player", note, {"kind": "choice", "options": [
                _opt("lore", "2 free Ranks in Lore: Underworld", [{"op": "skill", "skill": "Lore: Underworld", "ranks": 2}]),
                _opt("ally", "A 2-point Ally in the criminal classes", [{"op": "adv", "name": "Ally (2 points, criminal classes)"}])]})],
        "Fortune determines the nature of the Forbidden Knowledge and who holds the Obligation.": [
            _perk("staff", "Fortune determines the nature of the Forbidden Knowledge.",
                  _text_ask("What is the Forbidden Knowledge about?"),
                  [{"op": "rename", "old": "Forbidden Knowledge", "new": "Forbidden Knowledge ({v})"}]),
            _perk("staff", "Fortune determines who holds the Obligation.",
                  _text_ask("To which samurai is the Obligation owed?"),
                  [{"op": "rename", "old": "Obligation (3 points)", "new": "Obligation (3 points, {v})"}])],
        "Fortune determines the specific form of the Consumed Disadvantage.": [
            _perk("staff", note, _text_ask("What form does the Consumed Disadvantage take?"),
                  [{"op": "rename", "old": "Consumed", "new": "Consumed ({v})"}])],
        "Fortune determines two 2-point ronin Allies.": [
            _perk("auto", note, None, [{"op": "adv", "name": "Ally (2 points, ronin)"},
                                       {"op": "adv", "name": "Ally (2 points, ronin, second)"}]),
            _narrative("The two 2-point ronin Allies", note)],
        "Fortune determines up to three 3-point Allies.": [
            _perk("staff", note, {"kind": "choice", "options": [
                _opt("1", "One Ally", [{"op": "adv", "name": "Ally (3 points)"}], "Who is the Ally?"),
                _opt("2", "Two Allies", [{"op": "adv", "name": "Ally (3 points)"},
                                         {"op": "adv", "name": "Ally (3 points, second)"}], "Who are the Allies?"),
                _opt("3", "Three Allies", [{"op": "adv", "name": "Ally (3 points)"},
                                           {"op": "adv", "name": "Ally (3 points, second)"},
                                           {"op": "adv", "name": "Ally (3 points, third)"}], "Who are the Allies?")]},
                  [{"op": "detail", "text": "3-point Allies: {d}"}])],
        "Also gain an Ally Advantage. Fortune determines True Love or Lost Love and their details.": [
            _perk("staff", "Fortune determines the Ally Advantage.", _text_ask("Who is the Ally, and how many points?"),
                  [{"op": "adv", "name": "Ally ({v})"}]),
            _perk("staff", "Fortune determines True Love or Lost Love.", {"kind": "choice", "options": [
                _opt("true", "True Love", [{"op": "dis", "name": "True Love ({d})"}], "Who is the true love?"),
                _opt("lost", "Lost Love", [{"op": "dis", "name": "Lost Love ({d})"}], "Who was lost?")]})],
        "Fortune determines which Element the Elemental Blessing applies to.": [
            _perk("staff", note, {"kind": "element"}, [{"op": "rename", "old": "Elemental Blessing", "new": "Elemental Blessing ({v})"}])],
        "Fortune determines which Trait the Weakness applies to.": [
            _perk("staff", note, {"kind": "trait"}, [{"op": "rename", "old": "Weakness", "new": "Weakness ({v})"}])],
        "Fortune determines which Great Clan the Ally belongs to.": [
            _perk("staff", note, {"kind": "clan", "scope": "great"}, [{"op": "sub", "old": "Great Clan", "new": "{v}"}])],
        "Fortune determines which Great Clan family holds the Obligation.": [
            _perk("staff", note, _text_ask("Which Great Clan family holds the Obligation?"),
                  [{"op": "sub", "old": "Great Clan family", "new": "{v}"}])],
        "Fortune determines which Great Clan family holds the grudge.": [
            _perk("staff", note, _text_ask("Which Great Clan family holds the grudge?"),
                  [{"op": "rename", "old": "Sworn Enemy", "new": "Sworn Enemy ({v})"}])],
        "Fortune determines which family holds the blood feud.": [
            _perk("staff", note, _text_ask("Which family holds the blood feud?"),
                  [{"op": "rename", "old": "Sworn Enemy", "new": "Sworn Enemy ({v})"}])],
        "Fortune determines which clan holds the grudge.": [
            _perk("staff", note, {"kind": "clan", "scope": "others"}, _clan_fill_actions(grudge=True))],
        "Fortune determines which clan's family holds the grudge.": [
            _perk("staff", note, _text_ask("Which clan's family holds the grudge?"),
                  [{"op": "sub", "old": "another clan", "new": "{v}"}])],
        "Fortune determines which clan holds the Obligation.": [
            _perk("staff", note, {"kind": "clan", "scope": "others"}, _clan_fill_actions())],
        "Fortune determines which clan the Ally belongs to.": [
            _perk("staff", note, {"kind": "clan", "scope": "others"}, _clan_fill_actions())],
        "Fortune determines: Gain either 1 Rank of Shadowlands Taint or 1 Shadow Rank.": [
            _perk("staff", note, {"kind": "choice", "options": [
                _opt("taint", "1 Rank of Shadowlands Taint", [{"op": "taint", "amount": 1.0}]),
                _opt("shadow", "1 Shadow Rank", [{"op": "detail", "text": "Gained 1 Shadow Rank"}])]})],
        "Gain a Togashi tattoo (Fortune determines which). The Enlightened Madness is connected to the tattoo.": [
            _perk("staff", note, {"kind": "tattoo"}, [
                {"op": "tattoo", "name": "{v}"},
                {"op": "rename", "old": "Enlightened Madness", "new": "Enlightened Madness ({v} tattoo)"}])],
        "May call in a favor from another clan (Fortune determines which), but doing so creates an Obligation to that clan.": [
            _perk("staff", note, {"kind": "clan", "scope": "others"},
                  [{"op": "detail", "text": "May call in one favor from the {v}; doing so creates an Obligation to them"}])],
        "May purchase the Child of Chikushudo Advantage.": [
            _perk("auto", note, None, [{"op": "detail", "text": "May purchase the Child of Chikushudo Advantage"}])],
        "Fortune may approve purchase of a Sacred Weapon.": [
            _perk("auto", note, None, [{"op": "unlock", "base": "Sacred Weapon"}]),
            _perk("staff", "Fortune decides whether the Sacred Weapon the player bought is approved.",
                  {"kind": "choice", "options": [
                      _opt("yes", "Approve the Sacred Weapon", [{"op": "detail", "text": "Sacred Weapon approved by Fortune"}]),
                      _opt("no", "Decline it (the purchase is refunded)", [{"op": "remove_purchase", "base": "Sacred Weapon"}])]},
                  condition={"has_purchase": "Sacred Weapon"})],
        "Fortune may grant access to a higher-rank ronin Technique.": [
            _perk("staff", note, {"kind": "choice", "options": [
                _opt("none", "No higher-rank Technique", []),
                _opt("2", "Rank 2 Technique", [{"op": "technique_rank", "rank": 2}]),
                _opt("3", "Rank 3 Technique", [{"op": "technique_rank", "rank": 3}]),
                _opt("4", "Rank 4 Technique", [{"op": "technique_rank", "rank": 4}]),
                _opt("5", "Rank 5 Technique", [{"op": "technique_rank", "rank": 5}])]})],
        "Starting Glory is set to 0.0 regardless of school.": [
            _perk("auto", note, None, [{"op": "glory_zero"}])],
        "Starting Glory is set to 0.0 regardless of school. Reaching Glory Rank 1 requires 20 Glory Points (double normal).": [
            _perk("auto", note, None, [{"op": "glory_zero"},
                                       {"op": "detail", "text": "Reaching Glory Rank 1 requires 20 Glory Points (double normal)"}])],
        "Tortoise characters gain a 4-point Ally instead. Fortune determines which Great Clan holds the Sworn Enemy.": [
            _perk("auto", "Tortoise characters gain a 4-point Ally instead.", None,
                  [{"op": "sub", "old": "Ally (3 points, Imperial families)", "new": "Ally (4 points, Imperial families)"}],
                  {"clan": "Tortoise"}),
            _perk("staff", "Fortune determines which Great Clan holds the Sworn Enemy.",
                  {"kind": "clan", "scope": "great"}, [{"op": "sub", "old": "Great Clan", "new": "{v}"}])],
    }
    if note in exact:
        return exact[note]

    # Notes that end in a discount and then add a Fortune detail.
    if note == "May take the Paragon of Duty Advantage for 2 less XP. Fortune determines which clan holds the Nemesis.":
        return [_discount_perk("Paragon of Duty", 2, None, note),
                _perk("staff", "Fortune determines which clan holds the Nemesis.", {"kind": "clan", "scope": "others"},
                      _clan_fill_actions())]
    if note == "May take Friend of the Elements (choose Element) for 1 less XP. Wrath of the Kami applies to the opposing Element.":
        return [_perk("player", "Choose the Element for Friend of the Elements. Wrath of the Kami applies to its opposite.",
                      {"kind": "element"},
                      [{"op": "sub", "old": "opposing Element", "new": "{opp}"},
                       {"op": "discount", "targets": [{"base": "Friend of the Elements", "contains": "{v}"}],
                        "amount": 1, "label": "Friend of the Elements ({v})"}])]

    m = _DISCOUNT_RE.match(note)
    if m and not m.group("rest").strip():
        targets = _discount_target_specs(m.group("name"))
        raw = m.group("name")
        if targets is None:
            return [_perk("auto", note, None, [{"op": "detail",
                                                "text": note[:-1] + " (staff applies the discount at purchase)"}])]
        amount = int(m.group("n")) if m.group("n") else 0
        fixed = int(m.group("fixed")) if m.group("fixed") else None
        label = re.sub(r"\s*\([^)]*\)", "", raw.replace(" Advantage", "")).strip()
        label = re.sub(r"^(?:either |a |an |the )", "", label)
        label = re.sub(r"^Rank of (?:the )?", "", label)
        return [{"id": None, "who": "auto", "label": note, "ask": None, "condition": None,
                 "actions": [{"op": "discount", "targets": targets, "amount": amount, "fixed": fixed, "label": label}]}]
    return None


def _discount_perk(base_label: str, amount: int, fixed: int | None, note: str) -> dict:
    targets = _discount_target_specs(base_label) or [{"base": base_label}]
    return {"id": None, "who": "auto", "label": note, "ask": None, "condition": None,
            "actions": [{"op": "discount", "targets": targets, "amount": amount, "fixed": fixed, "label": base_label}]}


# Bare grants that still need the player's own words.
_BARE_PLAYER_DETAIL: dict[str, tuple[str, str]] = {
    "Compulsion (3 points)": ("What is the Compulsion?", "Compulsion ({v}, 3 points)"),
}


def build_perks(result: dict) -> list[dict]:
    """All perks for a rolled heritage result {grants, notes, ...}."""
    grants = result.get("grants") or {}
    perks: list[dict] = [{"id": "grants", "who": "auto", "label": "Heritage grants", "ask": None,
                          "actions": [], "condition": None, "grants": grants}]
    for i, note in enumerate(result.get("notes") or []):
        made = _classify(note)
        fallback = False
        if made is None:
            fallback = True
            made = [_narrative("Heritage note", note)]
        for k, p in enumerate(made):
            if not p.get("id"):
                p["id"] = f"n{i}_{k}"
            if fallback:
                p["fallback"] = True
            perks.append(p)
    # Placeholders in the grants that no note covered still need an answer.
    covered = " ".join(a.get("old", "") for p in perks for a in p["actions"] if a.get("op") == "sub")
    flat = [s for key in ("advantages", "disadvantages") for s in grants.get(key, [])]
    text = " ".join(flat)
    if "same person" in text and "same person" not in covered:
        perks.append(_perk("staff", "Name the person the Blackmail is against.", _text_ask("Who is the target?"),
                           [{"op": "sub", "old": "Great Clan", "new": "{v}"}, {"op": "sub", "old": "same person", "new": "{v}"}],
                           pid="grant_person"))
        covered += " Great Clan same person"
    if "Great Clan" in text and "Great Clan" not in covered:
        perks.append(_perk("player", "Choose the Great Clan.", {"kind": "clan", "scope": "great"},
                           [{"op": "sub", "old": "Great Clan", "new": "{v}"}], pid="grant_great"))
    for bare, (prompt, new) in _BARE_PLAYER_DETAIL.items():
        if bare in flat:
            perks.append(_perk("player", prompt, _text_ask(prompt),
                               [{"op": "rename", "old": bare, "new": new}], pid="grant_bare"))
    return perks


def find_entry_by_text(clan: str, heritage_text: str) -> dict | None:
    """Locate the table entry a stored heritage_result text came from (older saved wizards)."""
    from . import heritage
    body = heritage_text.split("\n[Fortune]", 1)[0]
    effect = body.split(": ", 1)[1] if ": " in body else body
    table = heritage.get_table(clan)
    for key, sub in table.items():
        if key == "categories" or not isinstance(sub, list):
            continue
        for entry in sub:
            if entry["effect"] == effect:
                return entry
    return None


def ensure_perks(state: dict, clan: str = "") -> None:
    """Make sure state carries heritage_perks (wizards saved before this existed lack them)."""
    if "heritage_perks" in state:
        return
    text = state.get("heritage_result")
    if not text:
        state["heritage_perks"] = []
        return
    entry = find_entry_by_text(clan or state.get("clan", ""), text)
    if entry is not None:
        state["heritage_perks"] = build_perks(entry)
    else:
        state["heritage_perks"] = build_perks({"grants": state.get("heritage_grants") or {}, "notes": []})
    state.setdefault("heritage_answers", {})


# --------------------------------------------------------------------------
#  Questions and answers
# --------------------------------------------------------------------------

def skill_options(pool: str, ctx: dict) -> list[str]:
    pools = ctx.get("pools", {})
    school = list(ctx.get("school_skills", []))
    if pool in ("weapon", "bugei", "high", "low", "craft", "artisan", "any"):
        base = list(pools.get(pool, []))
    elif pool == "battle_weapon":
        base = ["Battle"] + [s for s in pools.get("weapon", []) if s != "Battle"]
    elif pool == "sailing_nav":
        base = ["Sailing", "Navigation"]
    elif pool == "lore_spell":
        base = ["Lore: Shugenja", "Spellcraft"]
    elif pool == "school":
        base = school
    elif pool == "any_nonschool":
        base = [s for s in pools.get("any", []) if s not in school]
    else:
        base = []
    seen: set[str] = set()
    out: list[str] = []
    for s in base:
        if s not in seen:
            seen.add(s)
            out.append(s)
    return out


def ask_options(perk: dict, ctx: dict) -> list[dict] | None:
    """Options for a question as [{"value", "label", ...}], or None for free text."""
    ask = perk.get("ask") or {}
    kind = ask.get("kind")
    if kind == "clan":
        scope = ask.get("scope", "others")
        own = ctx.get("clan", "")
        clans = GREAT_CLANS if scope == "great" else all_clans()
        if scope == "others":
            clans = tuple(c for c in clans if c != own)
        return [{"value": c, "label": clan_display(c)} for c in clans]
    if kind == "element":
        return [{"value": e, "label": e} for e in ELEMENTS]
    if kind == "trait":
        return [{"value": t, "label": t} for t in TRAITS]
    if kind == "skill":
        return [{"value": s, "label": s} for s in skill_options(ask.get("pool", ""), ctx)]
    if kind == "weapon":
        return [dict(w) for w in ctx.get("weapons", [])]
    if kind == "tattoo":
        return [{"value": t, "label": t.title()} for t in ctx.get("tattoos", [])]
    if kind == "choice":
        return [dict(o) for o in ask.get("options", [])]
    return None


def _answer_ok(perk: dict, ans: Any, ctx: dict, answers: dict) -> bool:
    if not isinstance(ans, dict):
        return False
    v = ans.get("v")
    ask = perk["ask"]
    if not isinstance(v, str) or not v.strip():
        return False
    opts = ask_options(perk, ctx)
    if opts is None:   # free text
        return len(v) <= int(ask.get("max", 100))
    chosen = next((o for o in opts if o["value"] == v), None)
    if chosen is None:
        return False
    if chosen.get("detail") and not str(ans.get("d", "")).strip():
        return False
    ref = ask.get("differs_from")
    if ref and (answers.get(ref) or {}).get("v") == v:
        return False
    return True


def _cond_ok(cond: dict | None, ctx: dict) -> bool:
    if not cond:
        return True
    st = [s.lower() for s in cond.get("school_type", [])]
    if st and str(ctx.get("school_type", "")).lower() not in st:
        return False
    if cond.get("clan") and ctx.get("clan") != cond["clan"]:
        return False
    if cond.get("has_purchase") and cond["has_purchase"].lower() not in {
            b.lower() for b in ctx.get("purchased_bases", [])}:
        return False
    return True


def _fmt(s: str, vars_: dict) -> str:
    return re.sub(r"\{(\w+)\}", lambda m: str(vars_.get(m.group(1), m.group(0))), s)


def _new_out() -> dict:
    return {
        "skills": {}, "emphases": {}, "honor": 0.0, "glory": 0.0, "status": 0.0, "infamy": 0.0,
        "taint": 0.0, "koku": 0, "void": 0, "willpower": 0, "stamina": 0, "glory_zero": False,
        "advantages": [], "disadvantages": [], "tattoos": [], "weapons": [], "blocked": [],
        "details": [], "discounts": [], "unlocks": [], "technique_ranks": [], "remove_purchases": [],
        "pending_player": [], "pending_staff": [],
    }


def _merge_grants(out: dict, g: dict) -> None:
    for k, v in (g.get("skills") or {}).items():
        out["skills"][k] = out["skills"].get(k, 0) + int(v)
    for k, lst in (g.get("emphases") or {}).items():
        out["emphases"].setdefault(k, []).extend(x for x in lst if x not in out["emphases"].get(k, []))
    for key in ("honor", "glory", "status", "infamy", "taint"):
        if key in g:
            out[key] += float(g[key])
    for key in ("koku", "void", "willpower", "stamina"):
        if key in g:
            out[key] += int(g[key])
    out["advantages"].extend(g.get("advantages", []))
    out["disadvantages"].extend(g.get("disadvantages", []))


def _run(actions: list[dict], out: dict, vars_: dict, perk_id: str) -> None:
    for a in actions:
        op = a.get("op")
        if op in ("adv", "dis"):
            out["advantages" if op == "adv" else "disadvantages"].append(_fmt(a["name"], vars_))
        elif op == "skill":
            sk = _fmt(a["skill"], vars_)
            out["skills"][sk] = out["skills"].get(sk, 0) + int(a.get("ranks", 1))
        elif op == "emph":
            sk = _fmt(a["skill"], vars_)
            em = _fmt(a["emphasis"], vars_)
            lst = out["emphases"].setdefault(sk, [])
            if em not in lst:
                lst.append(em)
        elif op == "sub":
            old, new = a["old"], _fmt(a["new"], vars_)
            for key in ("advantages", "disadvantages"):
                out[key] = [s.replace(old, new) if old in s else s for s in out[key]]
        elif op == "rename":
            old, new = a["old"], _fmt(a["new"], vars_)
            for key in ("advantages", "disadvantages"):
                out[key] = [new if s == old else s for s in out[key]]
        elif op == "detail":
            out["details"].append(_fmt(a["text"], vars_))
        elif op == "tattoo":
            t = _fmt(a["name"], vars_)
            if t not in out["tattoos"]:
                out["tattoos"].append(t)
        elif op == "weapon":
            out["weapons"].append(_fmt(a["key"], vars_))
        elif op == "taint":
            out["taint"] += float(a["amount"])
        elif op == "block":
            out["blocked"].extend(n for n in a["names"] if n not in out["blocked"])
        elif op == "glory_zero":
            out["glory_zero"] = True
        elif op == "discount":
            targets = [{**t, "contains": _fmt(t["contains"], vars_)} if t.get("contains") else dict(t)
                       for t in a["targets"]]
            out["discounts"].append({
                "perk": perk_id, "targets": targets, "amount": int(a.get("amount") or 0),
                "fixed": a.get("fixed"), "label": _fmt(a.get("label", ""), vars_),
            })
        elif op == "unlock":
            out["unlocks"].append(a["base"])
        elif op == "technique_rank":
            out["technique_ranks"].append(int(a["rank"]))
        elif op == "remove_purchase":
            out["remove_purchases"].append(a["base"])


def resolve(state: dict, ctx: dict) -> dict:
    """Everything the heritage result currently amounts to, plus the questions still open."""
    ensure_perks(state, ctx.get("clan", ""))
    perks = state.get("heritage_perks") or []
    answers = state.get("heritage_answers") or {}
    out = _new_out()
    vars_: dict[str, str] = {}
    for perk in perks:
        if not _cond_ok(perk.get("condition"), ctx):
            continue
        if perk.get("grants"):
            _merge_grants(out, perk["grants"])
        ask = perk.get("ask")
        if not ask:
            _run(perk.get("actions", []), out, dict(vars_), perk["id"])
            continue
        ans = answers.get(perk["id"])
        if not _answer_ok(perk, ans, ctx, answers):
            out["pending_staff" if perk["who"] == "staff" else "pending_player"].append(perk)
            continue
        v = ans["v"].strip()
        d = str(ans.get("d", "")).strip()
        local = dict(vars_)
        local.update({"v": v, "d": d})
        if ask["kind"] == "clan":
            local["c"] = v
            local["v"] = clan_display(v)
        elif ask["kind"] == "element":
            local["opp"] = OPPOSING.get(v, v)
        elif ask["kind"] == "choice":
            opt = next(o for o in ask["options"] if o["value"] == v)
            local["v"] = opt["label"]
        vars_[perk["id"]] = local["v"]
        acts = list(perk.get("actions", []))
        if ask["kind"] == "choice":
            acts = list(opt.get("actions", [])) + acts
        _run(acts, out, local, perk["id"])
    return out


# --------------------------------------------------------------------------
#  XP discounts and the advantages the menus cannot sell
# --------------------------------------------------------------------------

def _base_name(name: str) -> str:
    return re.split(r"\s*[(:]", name, maxsplit=1)[0].strip()


def match_target(target: dict, name: str, school_type: str) -> bool:
    if _base_name(name).lower() != target["base"].lower():
        return False
    if target.get("contains") and target["contains"].lower() not in name.lower():
        return False
    st = [s.lower() for s in target.get("school_type", [])]
    if st and school_type.lower() not in st:
        return False
    return True


def price_items(discounts: list[dict], items: list[dict], school_type: str) -> list[tuple[int, dict | None]]:
    """Cost of each {"name", "points"} item after heritage discounts, in purchase order.
    Each discount is used at most once; a discount never takes a cost below 0."""
    spent: set[int] = set()
    priced: list[tuple[int, dict | None]] = []
    for it in items:
        base = int(it["points"])
        hit: dict | None = None
        for i, d in enumerate(discounts):
            if i in spent:
                continue
            if any(match_target(t, it["name"], school_type) for t in d["targets"]):
                spent.add(i)
                hit = d
                break
        if hit is None:
            priced.append((base, None))
        elif hit.get("fixed") is not None:
            priced.append((min(base, int(hit["fixed"])), hit))
        else:
            priced.append((max(0, base - int(hit["amount"])), hit))
    return priced


def unused_discounts(discounts: list[dict], items: list[dict], school_type: str) -> list[dict]:
    spent: set[int] = set()
    for it in items:
        for i, d in enumerate(discounts):
            if i not in spent and any(match_target(t, it["name"], school_type) for t in d["targets"]):
                spent.add(i)
                break
    return [d for i, d in enumerate(discounts) if i not in spent]


def discount_hint(discounts: list[dict], name: str, points: int, school_type: str) -> str:
    """Short text for a menu entry that a heritage discount applies to, or ""."""
    for d in discounts:
        if any(match_target(t, name, school_type) for t in d["targets"]):
            cost = min(points, int(d["fixed"])) if d.get("fixed") is not None else max(0, points - int(d["amount"]))
            return f"{cost} with heritage"
    return ""


def special_options(res: dict, items: list[dict], school_type: str) -> list[dict]:
    """Advantages Heritage lets the player buy though their cost is variable:
    [{"name", "points", "base", "note", "input"}]. Names already bought are left out."""
    bought = {i["name"] for i in items}
    open_discounts = unused_discounts(res["discounts"], items, school_type)
    out: list[dict] = []

    def add(opt: dict) -> None:
        if opt["name"] not in bought and all(o["name"] != opt["name"] for o in out):
            out.append(opt)

    for d in open_discounts:
        for t in d["targets"]:
            base = t["base"]
            if base == "Sacred Weapon":
                for clan, (weapon, cost) in SACRED_WEAPONS.items():
                    if not t.get("contains") or t["contains"].lower() in weapon.lower():
                        add({"name": f"Sacred Weapon ({weapon})", "points": cost, "base": base, "input": None})
            elif base == "Luck":
                add({"name": "Luck (Rank 1)", "points": _luck_first_rank_cost(), "base": base, "input": None})
            elif base == "Gentry":
                for holding, cost in _gentry_holdings():
                    add({"name": f"Gentry ({holding})", "points": cost, "base": base, "input": None})
            elif base == "Blackmail":
                add({"name": "Blackmail", "points": None, "base": base, "input": "blackmail"})
    if "Sacred Weapon" in res["unlocks"] and not any(_base_name(i["name"]) == "Sacred Weapon" for i in items):
        for clan, (weapon, cost) in SACRED_WEAPONS.items():
            add({"name": f"Sacred Weapon ({weapon})", "points": cost, "base": "Sacred Weapon", "input": None})
    return out


def granted_base_names(res: dict) -> set[str]:
    return {_base_name(n) for n in res["advantages"] + res["disadvantages"]}


# --------------------------------------------------------------------------
#  Applying a resolved heritage to a Character
# --------------------------------------------------------------------------

def apply_skills(char: Any, res: dict) -> None:
    """Free ranks and emphases go in first, so later purchases are priced on top of them."""
    for name, ranks in res["skills"].items():
        char.skills[name] = char.skills.get(name, 0) + ranks
    for sk, lst in res["emphases"].items():
        cur = char.emphases.setdefault(sk, [])
        for e in lst:
            if e not in cur:
                cur.append(e)


def apply_rest(char: Any, res: dict) -> list[str]:
    """Everything except skills. Returns notes about what was applied."""
    notes: list[str] = []
    if res["glory_zero"]:
        char.glory = 0.0
        notes.append("Starting Glory 0.0")
    for key in ("honor", "glory", "status", "infamy", "taint"):
        if res[key]:
            setattr(char, key, getattr(char, key) + res[key])
            notes.append(f"{key.capitalize()} {res[key]:+.1f}")
    if res["koku"]:
        char.koku += int(res["koku"])
        normalise_purse(char)
        notes.append(f"{int(res['koku']):+d} koku")
    for key, attr in (("void", "void_ring"), ("willpower", "willpower"), ("stamina", "stamina")):
        if res[key]:
            setattr(char, attr, getattr(char, attr) + res[key])
            if key == "void":
                char.max_void_points = char.void_ring
                char.current_void_points = char.void_ring
    for adv in res["advantages"]:
        if adv not in char.advantages:
            char.advantages.append(adv)
            notes.append(f"Advantage: {adv}")
    for dis in res["disadvantages"]:
        if dis not in char.disadvantages:
            char.disadvantages.append(dis)
            notes.append(f"Disadvantage: {dis}")
    for t in res["tattoos"]:
        if t.lower() not in [x.lower() for x in char.tattoos]:
            char.tattoos.append(t)
    from .schools import _add_weapon
    for w in res["weapons"]:
        _add_weapon(char, w)
    for b in res["blocked"]:
        if b not in char.blocked_advantages:
            char.blocked_advantages.append(b)
    for d in res["details"]:
        if d not in char.heritage_details:
            char.heritage_details.append(d)
    return notes


def pending_summary(res: dict) -> str:
    """One line for staff about what is still open, or ""."""
    n = len(res["pending_staff"])
    return f"{n} heritage decision{'s' if n != 1 else ''} for Fortune" if n else ""
