"""Reference catalog commands: /ref and all subcommands.

Extracted from bot.py to reduce file size.  All commands are pure
read-only lookups into the L5R rules data modules - no character
mutations.  The module is initialised by bot.py calling ``init()``,
which injects the shared state and wires up autocompletes.
"""

from __future__ import annotations

from collections import Counter
from typing import TYPE_CHECKING

import discord
from discord import app_commands

from l5r_rules import (
    advantages, combat, creature, enums, families,
    heritage, kata, kiho, schools, spells, stats,
    tattoo_catalog,
)
from l5r_rules.character import Character

if TYPE_CHECKING:
    import storage as _storage_mod
    from encounter import Encounter


class _Deps:
    """Shared dependencies injected by init()."""

    store: _storage_mod.Store
    encounters: dict[int, Encounter]
    require_guild: ...
    require_dm_role: ...
    is_dm: ...
    find_any_character: ...
    paginate: ...
    PaginatorView: type
    ELEMENT_COLORS: dict[str, discord.Color]
    NPC_OWNER: str
    ROLE_FORTUNE: str
    ROLE_KAMI: str


_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    encounters: dict,
    require_guild,
    require_dm_role,
    is_dm,
    find_any_character,
    paginate,
    PaginatorView,
    element_colors: dict,
    npc_owner: str,
    role_fortune: str,
    role_kami: str,
    weapon_autocomplete,
    armor_autocomplete,
    school_autocomplete,
    kata_autocomplete,
    kiho_autocomplete,
    anyadv_autocomplete,
) -> None:
    _d.store = store
    _d.encounters = encounters
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.is_dm = is_dm
    _d.find_any_character = find_any_character
    _d.ROLE_FORTUNE = role_fortune
    _d.ROLE_KAMI = role_kami
    _d.paginate = paginate
    _d.PaginatorView = PaginatorView
    _d.ELEMENT_COLORS = element_colors
    _d.NPC_OWNER = npc_owner
    # Wire autocompletes (must happen after commands are defined)
    weapon_view.autocomplete("name")(weapon_autocomplete)
    armor_view.autocomplete("name")(armor_autocomplete)
    school_view.autocomplete("name")(school_autocomplete)
    kata_view.autocomplete("name")(kata_autocomplete)
    kiho_view.autocomplete("name")(kiho_autocomplete)
    advantage_view.autocomplete("name")(anyadv_autocomplete)


# ---------------------------------------------------------------------------
# Group definitions
# ---------------------------------------------------------------------------

ref = app_commands.Group(
    name="ref",
    description="Browse L5R rules reference: Weapons, armor, schools, and more.",
)
ref_weapon = app_commands.Group(name="weapon", description="Weapon catalog (damage, skill, size).", parent=ref)
ref_armor = app_commands.Group(name="armor", description="Armor catalog (TN bonus, Reduction).", parent=ref)
ref_advantage = app_commands.Group(name="advantage", description="Advantages & Disadvantages.", parent=ref)
ref_kata = app_commands.Group(name="kata", description="Kata by element and mastery.", parent=ref)
ref_kiho = app_commands.Group(name="kiho", description="Kiho by element and mastery.", parent=ref)
ref_school = app_commands.Group(name="school", description="School catalog: Benefit, skills, techniques.", parent=ref)
ref_family = app_commands.Group(name="family", description="Family catalog (character creation bonuses).", parent=ref)
ref_heritage = app_commands.Group(name="heritage", description="Heritage table rolls (L5R 4e).", parent=ref)
ref_tattoo = app_commands.Group(name="tattoo", description="Togashi tattoo abilities.", parent=ref)


# ---------------------------------------------------------------------------
# Ref-only helpers and constants
# ---------------------------------------------------------------------------

_SCHOOL_CATEGORY_LABEL = {
    "basic": "school", "advanced": "Advanced School", "alternate": "Alternate Path",
}


def build_school_embed(s: dict) -> discord.Embed:
    kw = f" [{', '.join(s['keywords'])}]" if s["keywords"] else ""
    embed = discord.Embed(title=f"{s['name']}{kw}", color=discord.Color.dark_teal())
    cat = _SCHOOL_CATEGORY_LABEL.get(s.get("category", "basic"), "school")
    embed.description = f"{s['clan']} {cat}"
    eff_skills, eff_honor, eff_outfit = schools.effective_fields(s)
    benefit_display = s["benefit"].split("|")[0].strip() if s["benefit"] else ""
    meta = []
    if benefit_display:
        meta.append(f"**Benefit: ** {benefit_display}")
    if eff_honor:
        meta.append(f"**Honor: ** {eff_honor}")
    if meta:
        embed.add_field(name="​", value="  ·  ".join(meta), inline=False)
    if eff_skills:
        embed.add_field(name="Skills", value=eff_skills[:1024], inline=False)
    if eff_outfit:
        embed.add_field(name="Outfit", value=eff_outfit[:1024], inline=False)
    if s["affinity"]:
        embed.add_field(name="Affinity/Deficiency", value=s["affinity"][:1024], inline=False)
    if s["prereq"]:
        embed.add_field(name="Prerequisites", value=s["prereq"][:1024], inline=False)
    for t in s["techniques"][:12]:
        rank_label = f"Rank {t['rank']}" if t["rank"] else "Technique"
        title = f"{rank_label}: {t['name']}" if t["name"] else rank_label
        effect = t["effect"]
        if len(effect) > 1024:
            effect = effect[:1021] + "..."
        embed.add_field(name=title[:256], value=effect, inline=False)
    return embed


def _build_armor_embed(name: str, s: dict) -> discord.Embed:
    embed = discord.Embed(title=f"{name}", color=discord.Color.blue())
    tn_val = f"+{s['tn_bonus']}"
    if s.get("tn_bonus_mounted"):
        tn_val = f"+{s['tn_bonus']} (on foot) / +{s['tn_bonus_mounted']} (mounted)"
    embed.add_field(name="Armor TN Bonus", value=tn_val, inline=True)
    embed.add_field(name="Reduction", value=str(s["reduction"]), inline=True)
    embed.add_field(name="Cost", value=f"{s['cost']} koku", inline=True)
    embed.add_field(name="Type", value="Heavy" if s["is_heavy"] else "Light", inline=True)
    if s.get("special"):
        embed.add_field(name="Special", value=s["special"][:1024], inline=False)
    return embed


def build_advantage_embed(r: dict) -> discord.Embed:
    is_adv = r["kind"] == "advantage"
    embed = discord.Embed(
        title=f"{'' if is_adv else ''} {r['name']}",
        color=discord.Color.green() if is_adv else discord.Color.dark_red(),
    )
    meta = [r["kind"].capitalize()]
    if r["category"]:
        meta.append(r["category"])
    meta.append(f"{r['cost_text']}" + (" pts" if r["points"] is not None else ""))
    if r["tags"]:
        meta.append(", ".join(r["tags"]))
    embed.description = " · ".join(meta)
    if r["effect"]:
        embed.add_field(name="Effect", value=r["effect"][:1024], inline=False)
    return embed


def build_kata_embed(k: dict) -> discord.Embed:
    color = _d.ELEMENT_COLORS.get(k["element"].lower(), discord.Color.teal())
    embed = discord.Embed(title=f"{k['name']}", color=color)
    embed.description = f"**{k['element']} {k['mastery']}**"
    if k.get("schools"):
        embed.add_field(name="Schools", value=k["schools"][:1024], inline=False)
    if k.get("effect"):
        embed.add_field(name="Effect", value=k["effect"][:1024], inline=False)
    return embed


def build_kiho_embed(k: dict) -> discord.Embed:
    color = _d.ELEMENT_COLORS.get(k["element"].lower(), discord.Color.teal())
    atemi = " · Atemi" if k.get("atemi") else ""
    embed = discord.Embed(title=f"{k['name']}{atemi}", color=color)
    meta = f"**{k['element']} {k['mastery']}**"
    if k.get("type"):
        meta += f" · {k['type']}"
    embed.description = meta
    if k.get("effect"):
        embed.add_field(name="Effect", value=k["effect"][:1024], inline=False)
    return embed


ANCESTOR_EFFECTS: dict[str, str] = {
    "ancestor: hida": "+1k0 vs Shadowlands creatures.",
    "ancestor: hiruma": "+1k0 on Hunting and Stealth checks.",
    "ancestor: kaiu": "+1k0 on Engineering and Craft checks.",
    "ancestor: kuni": "+1k0 on Lore: Shadowlands checks.",
    "ancestor: doji": "+1k0 on Etiquette and Courtier checks.",
    "ancestor: kakita": "+1k0 on Iaijutsu checks.",
    "ancestor: daidoji": "+1k0 on Battle checks.",
    "ancestor: mirumoto": "+1k0 on Kenjutsu checks when wielding two weapons.",
    "ancestor: kitsuki": "+1k0 on Investigation checks.",
    "ancestor: togashi": "+1k0 on Meditation checks.",
    "ancestor: akodo": "+1k0 on Battle checks.",
    "ancestor: matsu": "+1k0 on attack rolls when at Hurt or worse.",
    "ancestor: ikoma": "+1k0 on Lore: History checks.",
    "ancestor: bayushi": "+1k0 on Stealth and Sincerity checks.",
    "ancestor: shosuro": "+1k0 on Acting and Disguise checks.",
    "ancestor: soshi": "+1k0 on spell casting rolls for Air spells.",
    "ancestor: shinjo": "+1k0 on Horsemanship checks.",
    "ancestor: moto": "+1k0 on attack rolls while Mounted.",
    "ancestor: ide": "+1k0 on Commerce and Etiquette checks.",
    "ancestor: isawa": "+1k0 on spell casting rolls.",
    "ancestor: shiba": "+1k0 on Defense rolls.",
}

TRAVEL_SPEEDS: dict[str, dict] = {
    "foot": {"name": "On Foot", "miles_per_day": 20, "description": "Standard travel pace. Can force-march for 30 (Stamina TN 15 or gain Fatigued)."},
    "horse": {"name": "Mounted", "miles_per_day": 40, "description": "Standard mounted pace. Can push for 60 (Horsemanship TN 15)."},
    "forced_march": {"name": "Forced March", "miles_per_day": 30, "description": "Stamina check TN 15 each day or gain Fatigued condition."},
    "cart": {"name": "Cart/Wagon", "miles_per_day": 15, "description": "Slow but can carry heavy loads."},
    "ship": {"name": "Ship (coastal)", "miles_per_day": 50, "description": "Coastal sailing. Open-sea routes may be faster or slower depending on winds."},
    "river": {"name": "River Barge", "miles_per_day": 25, "description": "Downstream travel. Upstream is half speed."},
}

TERRAIN_MODIFIERS: list[tuple[str, str]] = [
    ("Light Cover (foliage, fence)", "+10 Armor TN"),
    ("Heavy Cover (wall, fortification)", "+20 Armor TN"),
    ("Concealment (fog, darkness, smoke)", "+10 Armor TN (partial) / +20 (total)"),
    ("Higher Ground (attacker above)", "+1k0 on attack rolls"),
    ("Darkness (total)", "Blinded: All rolls −3k0, TN +10"),
    ("Narrow Footing (bridge, ledge)", "Agility TN 20 or fall; no Full Attack"),
    ("Mounted vs. Foot", "+1k0 to mounted attacker; unmounted −1k0 to attack"),
    ("Prone Target (melee)", "−10 Armor TN"),
    ("Prone Target (ranged)", "+10 Armor TN"),
]

RANGE_INCREMENTS: list[tuple[str, str]] = [
    ("Within first increment", "Normal TN"),
    ("2nd increment", "+10 TN"),
    ("3rd increment", "+20 TN"),
    ("4th increment", "+30 TN"),
    ("5th increment", "+40 TN (maximum range)"),
]


# ---------------------------------------------------------------------------
# /ref search - cross-catalog search
# ---------------------------------------------------------------------------

@ref.command(
    name="search",
    description="Search all catalogs: Spells, schools, kata, advantages, weapons, and more.",
)
@app_commands.describe(
    query="Search term (matches names, elements, categories).",
)
async def lookup(
    interaction: discord.Interaction,
    query: str,
) -> None:
    q = query.lower().strip()
    if len(q) < 2:
        await interaction.response.send_message("Search term must be at least 2 characters.", ephemeral=True)
        return

    results: list[tuple[str, str, str]] = []

    for s in spells.search(q)[:5]:
        results.append(("Spell", s["name"], f"{s['element']} {s['mastery']}"))

    for s in schools.search(q)[:5]:
        cat = s.get("category", "")
        results.append(("School", s["name"], f"{s['clan']} {cat}"))

    for k in kata.search(q)[:5]:
        results.append(("Kata", k["name"], f"{k['element']} ML{k['mastery']}"))

    for k in kiho.search(q)[:5]:
        results.append(("Kiho", k["name"], f"{k['element']} ML{k['mastery']}"))

    for a in advantages.search(q)[:5]:
        kind = a.get("kind", "")
        pts = a.get("points", "")
        results.append(("Advt/Dis", a["name"], f"{kind} ({pts} pts)"))

    for tid, t in sorted(creature.CREATURE_CATALOG.items(), key=lambda kv: kv[1].name):
        if q in tid or q in t.name.lower() or any(q in tag for tag in t.tags):
            results.append(("Creature", t.name, f"TN {t.armor_tn}, dead {t.wounds_dead}"))
            if len([r for r in results if r[0] == "Creature"]) >= 5:
                break

    for wname, w in combat.WEAPON_CATALOG.items():
        if q in wname:
            size = w.get("size", "")
            skill = w.get("skill", "")
            results.append(("Weapon", wname.replace("_", " ").title(), f"{skill}, {size}"))

    for aname, a in combat.ARMOR_CATALOG.items():
        if q in aname:
            results.append(("Armor", aname.replace("_", " ").title(), f"TN +{a['tn_bonus']}, Red {a['reduction']}, {a['cost']} koku"))

    if not results:
        await interaction.response.send_message(f"No results for **{query}**.", ephemeral=True)
        return

    lines = [f"`{cat:10s}` **{name}**: {detail}" for cat, name, detail in results[:25]]
    extra = f"\n*…{len(results) - 25} more: Narrow your search.*" if len(results) > 25 else ""
    await interaction.response.send_message(
        f"**{len(results)} result(s) for `{query}`: **\n" + "\n".join(lines) + extra,
        ephemeral=True,
    )


# ---------------------------------------------------------------------------
# /ref school - school catalog
# ---------------------------------------------------------------------------

@ref_school.command(name="list", description="List schools (optionally by clan).")
@app_commands.describe(clan="Filter by clan (Crab, Crane, …). Omit for a summary.")
async def school_list(interaction: discord.Interaction, clan: str | None = None) -> None:
    if clan:
        matches = schools.by_clan(clan)
        if not matches:
            await interaction.response.send_message(
                f"No schools for clan **{clan}**. Clans: {', '.join(schools.clans())}", ephemeral=True
            )
            return
        lines = []
        for cat, label in (("basic", "Basic"), ("advanced", "Advanced"), ("alternate", "Alternate Paths")):
            names = [s["name"] for s in matches if s.get("category", "basic") == cat]
            if names:
                lines.append(f"**{label} ({len(names)}): ** " + ", ".join(names))
        text = f"**{clan}: {len(matches)} schools/paths**\n" + "\n".join(lines)
        await interaction.response.send_message(text[:1990], ephemeral=True)
        return
    counts = Counter(s["clan"] for s in schools.ALL)
    cats = Counter(s.get("category", "basic") for s in schools.ALL)
    summary = " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    await interaction.response.send_message(
        f"**{len(schools.ALL)} schools & paths** "
        f"({cats['basic']} basic · {cats['advanced']} advanced · {cats['alternate']} alternate). "
        f"Browse with `/ref school list clan:<clan>`, `/ref school search`, or `/ref school view`.\n{summary}",
        ephemeral=True,
    )


@ref_school.command(name="search", description="Search schools by name or clan.")
@app_commands.describe(query="Name or clan fragment.")
async def school_search(interaction: discord.Interaction, query: str) -> None:
    matches = schools.search(query)
    if not matches:
        await interaction.response.send_message(f"No schools match `{query}`.", ephemeral=True)
        return
    _abbr = {"basic": "basic", "advanced": "adv", "alternate": "path"}
    lines = [
        f"• **{s['name']}** ({s['clan']}, {_abbr.get(s.get('category', 'basic'), 'basic')})"
        for s in matches[:40]
    ]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("\n".join(lines) + extra, ephemeral=True)


@ref_school.command(name="view", description="Show a school's benefit, skills, outfit, and techniques.")
@app_commands.describe(name="The school to view.")
async def school_view(interaction: discord.Interaction, name: str) -> None:
    s = schools.get(name)
    if s is None:
        await interaction.response.send_message(
            f"No school named **{name}**. Try `/ref school search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_school_embed(s))


# ---------------------------------------------------------------------------
# /ref weapon - weapon catalog
# ---------------------------------------------------------------------------

@ref_weapon.command(name="list", description="List all weapons, grouped by skill.")
async def weapon_list(interaction: discord.Interaction) -> None:
    by_skill: dict[str, list[str]] = {}
    for wid, w in combat.WEAPON_CATALOG.items():
        by_skill.setdefault(w["skill"], []).append(f"{wid} {w['rolled']}k{w['kept']}")
    lines = [f"**{sk}: ** " + ", ".join(sorted(v)) for sk, v in sorted(by_skill.items())]
    await interaction.response.send_message(
        f"**{len(combat.WEAPON_CATALOG)} weapons** (name DR):\n" + "\n".join(lines), ephemeral=True
    )


@ref_weapon.command(name="view", description="Show a weapon's details.")
@app_commands.describe(name="Weapon name.")
async def weapon_view(interaction: discord.Interaction, name: str) -> None:
    w = combat.WEAPON_CATALOG.get(name.lower().strip())
    if w is None:
        await interaction.response.send_message(f"No weapon named **{name}**. See `/ref weapon list`.", ephemeral=True)
        return
    dr = f"{w['rolled']}k{w['kept']}" + (" + Strength" if w.get("strength_adds") and w.get("melee") else "")
    embed = discord.Embed(title=f"{name.lower().strip()}", color=discord.Color.dark_grey())
    embed.add_field(name="Damage (DR)", value=dr, inline=True)
    embed.add_field(name="Skill", value=w["skill"], inline=True)
    embed.add_field(name="Trait", value=w["trait"].capitalize(), inline=True)
    embed.add_field(name="Size", value=w["size"], inline=True)
    embed.add_field(name="Type", value="Melee" if w.get("melee") else "Ranged", inline=True)
    if w.get("no_explode"):
        embed.set_footer(text="Damage dice do not explode.")
    await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# /ref armor - armor catalog
# ---------------------------------------------------------------------------

@ref_armor.command(name="list", description="List all armor types with TN bonus, Reduction, and cost.")
async def armor_list(interaction: discord.Interaction) -> None:
    lines = []
    for a, s in combat.ARMOR_CATALOG.items():
        tn = f"+{s['tn_bonus']}"
        if s.get("tn_bonus_mounted"):
            tn = f"+{s['tn_bonus']}/+{s['tn_bonus_mounted']} mounted"
        line = f"• **{a}**: TN {tn}, Red {s['reduction']}, {s['cost']} koku"
        if s["is_heavy"]:
            line += " · heavy"
        lines.append(line)
    await interaction.response.send_message(
        f"**Armor** ({len(combat.ARMOR_CATALOG)} types · equip with `/stat armor` or `/inventory` (staff)):\n" + "\n".join(lines), ephemeral=True
    )


@ref_armor.command(name="view", description="Show detailed info for one armor type.")
@app_commands.describe(name="Armor name.")
async def armor_view(interaction: discord.Interaction, name: str) -> None:
    key = name.lower().strip()
    s = combat.ARMOR_CATALOG.get(key)
    if s is None:
        await interaction.response.send_message(
            f"No armor named **{name}**. See `/ref armor list`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=_build_armor_embed(key, s), ephemeral=True)


@ref_armor.command(name="search", description="Search armor by name substring.")
@app_commands.describe(query="Part of the armor name to search for.")
async def armor_search(interaction: discord.Interaction, query: str) -> None:
    q = query.lower().strip()
    matches = [(a, s) for a, s in combat.ARMOR_CATALOG.items() if q in a]
    if not matches:
        await interaction.response.send_message(f"No armor matching **{query}**.", ephemeral=True)
        return
    if len(matches) == 1:
        a, s = matches[0]
        await interaction.response.send_message(embed=_build_armor_embed(a, s), ephemeral=True)
        return
    lines = []
    for a, s in matches:
        tn = f"+{s['tn_bonus']}"
        if s.get("tn_bonus_mounted"):
            tn = f"+{s['tn_bonus']}/+{s['tn_bonus_mounted']} mounted"
        lines.append(f"• **{a}**: TN {tn}, Red {s['reduction']}, {s['cost']} koku")
    await interaction.response.send_message(
        f"**Armor matching \"{query}\"** ({len(matches)} results):\n" + "\n".join(lines), ephemeral=True
    )


# ---------------------------------------------------------------------------
# /ref advantage - advantages & disadvantages
# ---------------------------------------------------------------------------

@ref_advantage.command(name="list", description="List Advantages or Disadvantages.")
@app_commands.describe(kind="advantages or disadvantages (default a summary).")
@app_commands.choices(kind=[
    app_commands.Choice(name="advantages", value="advantage"),
    app_commands.Choice(name="disadvantages", value="disadvantage"),
])
async def advantage_list(interaction: discord.Interaction, kind: app_commands.Choice[str] | None = None) -> None:
    if kind is None:
        n_adv = len(advantages.by_kind("advantage"))
        n_dis = len(advantages.by_kind("disadvantage"))
        await interaction.response.send_message(
            f" **{n_adv} Advantages**,  **{n_dis} Disadvantages**. "
            f"Use `/ref advantage list kind:` or `/ref advantage search`, `/ref advantage view`.",
            ephemeral=True,
        )
        return
    pool = sorted(advantages.by_kind(kind.value), key=lambda r: r["name"])
    icon = '' if kind.value == 'advantage' else ''
    lines = [f"• {icon} **{r['name']}** ({r['cost_text']})" for r in pool]
    pages = _d.paginate(lines, f"{icon} **{kind.name} ({len(pool)}): **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _d.PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)


@ref_advantage.command(name="search", description="Search Advantages & Disadvantages by name or category.")
@app_commands.describe(query="Name or category fragment.")
async def advantage_search(interaction: discord.Interaction, query: str) -> None:
    matches = advantages.search(query)
    if not matches:
        await interaction.response.send_message(f"No entries match `{query}`.", ephemeral=True)
        return
    lines = [
        f"{'' if r['kind'] == 'advantage' else ''} **{r['name']}** ({r['cost_text']})"
        for r in matches
    ]
    pages = _d.paginate(lines, f"**{len(matches)} match(es) for `{query}`: **\n")
    if len(pages) == 1:
        await interaction.response.send_message(pages[0], ephemeral=True)
    else:
        view = _d.PaginatorView(pages, interaction.user.id)
        await interaction.response.send_message(pages[0], view=view, ephemeral=True)


@ref_advantage.command(name="view", description="Show an Advantage or Disadvantage in full.")
@app_commands.describe(name="The entry to view.")
async def advantage_view(interaction: discord.Interaction, name: str) -> None:
    r = advantages.get(name)
    if r is None:
        await interaction.response.send_message(f"No entry named **{name}**. Try `/ref advantage search`.", ephemeral=True)
        return
    await interaction.response.send_message(embed=build_advantage_embed(r))


# ---------------------------------------------------------------------------
# /ref kata - kata catalog
# ---------------------------------------------------------------------------

@ref_kata.command(name="list", description="List Kata by element (or a summary).")
@app_commands.describe(element="Air, Earth, Fire, Water, Void. Omit for a summary.")
async def kata_list(interaction: discord.Interaction, element: str | None = None) -> None:
    if not element:
        counts = Counter(k["element"] for k in kata.ALL)
        summary = " · ".join(f"{el} {n}" for el, n in sorted(counts.items()))
        await interaction.response.send_message(
            f"**{len(kata.ALL)} Kata.** Browse with `/ref kata list element:<element>`, "
            f"`/ref kata search`, `/ref kata view`.\n{summary}", ephemeral=True
        )
        return
    matches = kata.by_element(element)
    if not matches:
        await interaction.response.send_message(
            f"No Kata for **{element}**. Elements: {', '.join(kata.elements())}", ephemeral=True
        )
        return
    by_ml: dict[int, list[str]] = {}
    for k in matches:
        by_ml.setdefault(k["mastery"], []).append(k["name"])
    lines = [f"**ML {ml}: ** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    text = f"**{element} Kata ({len(matches)}):** \n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@ref_kata.command(name="search", description="Search Kata by name or element.")
@app_commands.describe(query="Name or element fragment.")
async def kata_search(interaction: discord.Interaction, query: str) -> None:
    matches = kata.search(query)
    if not matches:
        await interaction.response.send_message(f"No Kata match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{k['name']}** ({k['element']} {k['mastery']})" for k in matches[:40]]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("\n".join(lines) + extra, ephemeral=True)


@ref_kata.command(name="view", description="Show a Kata's element, mastery, schools, and effect.")
@app_commands.describe(name="The Kata to view.")
async def kata_view(interaction: discord.Interaction, name: str) -> None:
    k = kata.get(name)
    if k is None:
        await interaction.response.send_message(
            f"No Kata named **{name}**. Try `/ref kata search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_kata_embed(k))


# ---------------------------------------------------------------------------
# /ref kiho - kiho catalog
# ---------------------------------------------------------------------------

@ref_kiho.command(name="list", description="List Kiho by element (or a summary).")
@app_commands.describe(element="Air, Earth, Fire, Water, Void. Omit for a summary.")
async def kiho_list(interaction: discord.Interaction, element: str | None = None) -> None:
    if not element:
        counts = Counter(k["element"] for k in kiho.ALL)
        summary = " · ".join(f"{el} {n}" for el, n in sorted(counts.items()))
        await interaction.response.send_message(
            f"**{len(kiho.ALL)} Kiho.** Browse with `/ref kiho list element:<element>`, "
            f"`/ref kiho search`, `/ref kiho view`.\n{summary}", ephemeral=True
        )
        return
    matches = kiho.by_element(element)
    if not matches:
        await interaction.response.send_message(
            f"No Kiho for **{element}**. Elements: {', '.join(kiho.elements())}", ephemeral=True
        )
        return
    by_ml: dict[int, list[str]] = {}
    for k in matches:
        by_ml.setdefault(k["mastery"], []).append(k["name"])
    lines = [f"**ML {ml}: ** " + ", ".join(sorted(by_ml[ml])) for ml in sorted(by_ml)]
    text = f"**{element} Kiho ({len(matches)}): **\n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@ref_kiho.command(name="search", description="Search Kiho by name, element, or type.")
@app_commands.describe(query="Name, element, or type fragment.")
async def kiho_search(interaction: discord.Interaction, query: str) -> None:
    matches = kiho.search(query)
    if not matches:
        await interaction.response.send_message(f"No Kiho match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{k['name']}** ({k['element']} {k['mastery']})" for k in matches[:40]]
    extra = f"\n…and {len(matches) - 40} more." if len(matches) > 40 else ""
    await interaction.response.send_message("" + "\n".join(lines) + extra, ephemeral=True)


@ref_kiho.command(name="view", description="Show a Kiho's element, mastery, type, and effect.")
@app_commands.describe(name="The Kiho to view.")
async def kiho_view(interaction: discord.Interaction, name: str) -> None:
    k = kiho.get(name)
    if k is None:
        await interaction.response.send_message(
            f"No Kiho named **{name}**. Try `/ref kiho search`.", ephemeral=True
        )
        return
    await interaction.response.send_message(embed=build_kiho_embed(k))


# ---------------------------------------------------------------------------
# /ref heritage - heritage table rolls
# ---------------------------------------------------------------------------

@ref_heritage.command(name="roll", description="Roll on a clan's Heritage Table (1d10). [Fortune]")
@app_commands.describe(clan="Clan name (Crab, Crane, Dragon, Lion, Mantis, Phoenix, Scorpion, Unicorn).")
async def heritage_roll(interaction: discord.Interaction, clan: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    result = heritage.roll_heritage(clan)
    embed = discord.Embed(
        title=f"Heritage Roll: {clan}",
        color=discord.Color.dark_teal(),
    )
    embed.add_field(name=f"Roll: {result['roll']}: {result['name']}", value=result["effect"][:1024], inline=False)
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)


@ref_heritage.command(name="table", description="Show a clan's full Heritage Table.")
@app_commands.describe(clan="Clan name.")
async def heritage_table(interaction: discord.Interaction, clan: str) -> None:
    if not await _d.require_guild(interaction):
        return
    table = heritage.get_table(clan)
    lines = [f"**{r['roll']}.** {r['name']}: {r['effect']}" for r in table]
    desc = "\n".join(lines)
    embed = discord.Embed(title=f"Heritage Table: {clan}", description=desc[:4000], color=discord.Color.dark_teal())
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref encumbrance - carrying capacity check
# ---------------------------------------------------------------------------

@ref.command(name="encumbrance", description="Check carrying capacity (Strength-based).")
@app_commands.describe(
    member="Player whose character to check.",
    is_npc="Target is an NPC.",
    name="NPC name (if is_npc).",
)
async def encumbrance_check(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"You need the **{_d.ROLE_FORTUNE}** (or **{_d.ROLE_KAMI}**) role to check NPC stats.", ephemeral=True
            )
            return
        rec = _d.store.get_by_name(guild, _d.NPC_OWNER, name)
    elif member is not None:
        rec = _d.store.get_active(guild, str(member.id))
    else:
        rec = _d.store.get_active(guild, str(interaction.user.id))
    if rec is None:
        label = f"No character named **{name}**." if name else "You have no active character."
        await interaction.response.send_message(label, ephemeral=True)
        return
    c = rec.character
    cap = stats.encumbrance_capacity(c)
    water = stats.water_ring(c)
    embed = discord.Embed(title=f"Encumbrance: {c.name}", color=discord.Color.greyple())
    embed.add_field(name="Strength", value=str(c.strength), inline=True)
    embed.add_field(name="Carry Capacity", value=f"**{cap}** items", inline=True)
    embed.add_field(name="Water Ring", value=str(water), inline=True)
    embed.add_field(
        name="Overloaded Penalty",
        value=f"Beyond {cap} items: −1k0 to all physical rolls per {c.strength} items over capacity.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref atn - Armor TN breakdown
# ---------------------------------------------------------------------------

@ref.command(name="armor_tn", description="Show Armor TN breakdown for your active character.")
@app_commands.describe(
    target="Character name (Fortune: Omit to see your own).",
)
async def atn_breakdown(interaction: discord.Interaction, target: str | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if target:
        if not await _d.require_dm_role(interaction):
            return
        rec = _d.find_any_character(guild, target)
        if rec is None:
            await interaction.response.send_message(f"No character named **{target}**.", ephemeral=True)
            return
    else:
        rec = _d.store.get_active(guild, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
            return
    c = rec.character
    base = c.reflexes * 5 + 5
    armor_bonus = c.armor_tn_bonus
    armor_name = c.armor_name or "None"
    reduction = c.armor_reduction
    lines = [
        f"Base (Reflexes {c.reflexes} × 5 + 5) = **{base}**",
        f"Armor: {armor_name} (+{armor_bonus} TN, Reduction {reduction})",
    ]
    total = base + armor_bonus
    enc = _d.encounters.get(interaction.channel_id)
    cb = None
    if enc:
        for comb in enc.combatants:
            if comb.name.lower() == c.name.lower():
                cb = comb
                break
    if cb is not None:
        from l5r_rules import condition_effects
        stance_mod = combat.STANCE_ARMOR_TN_BONUS.get(cb.stance, 0)
        if cb.stance == "defense":
            def_bonus = stats.ring_value(c, "air") + c.skills.get("Defense", 0)
            lines.append(f"Defense Stance: +{def_bonus} (Air {stats.ring_value(c, 'air')} + Defense {c.skills.get('Defense', 0)})")
            total += def_bonus
        elif cb.stance == "center":
            void_bonus = c.void_ring
            lines.append(f"Center Stance: +{void_bonus} (Void Ring)")
            total += void_bonus
        elif stance_mod != 0:
            stance_label = cb.stance.replace("_", " ").title()
            lines.append(f"{stance_label} Stance: {stance_mod:+d}")
            total += stance_mod
        if cb.full_defense_bonus:
            lines.append(f"Full Defense bonus: +{cb.full_defense_bonus}")
            total += cb.full_defense_bonus
        if cb.guarding:
            lines.append(f"Guarding {cb.guarding}: −5")
            total -= 5
        for other in enc.combatants:
            if other.guarding.lower() == c.name.lower():
                lines.append(f"Guarded by {other.name}: +10")
                total += 10
                break
        override, override_notes = condition_effects.defender_armor_tn_override(
            cb.conditions, c.reflexes, armor_bonus, True,
        )
        cond_mod, cond_notes = condition_effects.defender_armor_tn_mod(cb.conditions, True)
        if override is not None:
            lines.append(f"Condition override: {override_notes[0]}")
            lines.append(f"**Effective ATN = {override + cond_mod}** (overridden)")
        else:
            if cond_mod:
                lines.append(f"Condition modifier: {cond_mod:+d} ({', '.join(cond_notes)})")
                total += cond_mod
            lines.append(f"**Total ATN = {total}**")
    else:
        lines.append(f"**Total ATN = {total}** (out of combat)")
    embed = discord.Embed(title=f"ATN Breakdown: {c.name}", color=discord.Color.blue())
    embed.description = "\n".join(lines)
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref family - family catalog
# ---------------------------------------------------------------------------

@ref_family.command(name="list", description="List families by clan.")
@app_commands.describe(clan="Filter by clan (optional).")
async def family_list(interaction: discord.Interaction, clan: str | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    if clan:
        fams = families.by_clan(clan)
        if not fams:
            await interaction.response.send_message(f"No families found for clan **{clan}**.", ephemeral=True)
            return
        lines = [f"**{f['name']}**: +1 {f['bonus_trait'].capitalize()}" for f in fams]
        embed = discord.Embed(title=f"Families: {clan}", description="\n".join(lines), color=discord.Color.blue())
    else:
        clans: dict[str, list[str]] = {}
        for f in families.ALL:
            clans.setdefault(f["clan"], []).append(f"{f['name']} (+1 {f['bonus_trait'].capitalize()})")
        embed = discord.Embed(title="All Families", color=discord.Color.blue())
        for clan_name in sorted(clans):
            embed.add_field(name=clan_name, value=", ".join(clans[clan_name]), inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)


@ref_family.command(name="search", description="Search families by name or clan.")
@app_commands.describe(query="Name or clan to search for.")
async def family_search(interaction: discord.Interaction, query: str) -> None:
    if not await _d.require_guild(interaction):
        return
    results = families.search(query)
    if not results:
        await interaction.response.send_message(f"No families matching **{query}**.", ephemeral=True)
        return
    lines = [f"**{f['name']}** ({f['clan']}): +1 {f['bonus_trait'].capitalize()}" for f in results[:25]]
    embed = discord.Embed(title=f"Family Search:\"{query}\"", description="\n".join(lines), color=discord.Color.blue())
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref ancestors - ancestor advantage effects
# ---------------------------------------------------------------------------

@ref.command(name="ancestors", description="Show mechanical effects of Ancestor advantages on a character.")
@app_commands.describe(
    member="Player whose character to check.",
    is_npc="Target is an NPC.",
    name="NPC name (if is_npc).",
)
async def ancestors_check(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"You need the **{_d.ROLE_FORTUNE}** (or **{_d.ROLE_KAMI}**) role to check NPC stats.", ephemeral=True
            )
            return
        rec = _d.store.get_by_name(guild, _d.NPC_OWNER, name)
    elif member is not None:
        rec = _d.store.get_active(guild, str(member.id))
    else:
        rec = _d.store.get_active(guild, str(interaction.user.id))
    if rec is None:
        label = f"No character named **{name}**." if name else "You have no active character."
        await interaction.response.send_message(label, ephemeral=True)
        return
    c = rec.character
    found = []
    for adv in c.advantages:
        key = adv.lower().strip()
        if key in ANCESTOR_EFFECTS:
            found.append(f"**{adv}**: {ANCESTOR_EFFECTS[key]}")
    if not found:
        await interaction.response.send_message(
            f"**{c.name}** has no Ancestor advantages recorded. Use `/stat advantage` to add one.",
            ephemeral=True,
        )
        return
    embed = discord.Embed(
        title=f"Ancestor Effects: {c.name}",
        description="\n".join(found),
        color=discord.Color.gold(),
    )
    embed.set_footer(text="DM: Apply these bonuses manually to relevant rolls.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref dual_wield - dual-wielding rules
# ---------------------------------------------------------------------------

@ref.command(name="dual_wield", description="Show dual-wielding rules and penalties for a character.")
@app_commands.describe(
    member="Player whose character to check.",
    name="NPC name.",
    is_npc="Target is an NPC.",
)
async def dual_wield_info(
    interaction: discord.Interaction,
    name: str | None = None,
    member: discord.Member | None = None,
    is_npc: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if is_npc and name:
        rec = _d.store.get_by_name(guild, _d.NPC_OWNER, name)
    elif member is not None:
        rec = _d.store.get_active(guild, str(member.id))
    else:
        rec = _d.store.get_active(guild, str(interaction.user.id))
    if rec is None:
        label = f"No character named **{name}**." if name else "You have no active character."
        await interaction.response.send_message(label, ephemeral=True)
        return
    c = rec.character
    embed = discord.Embed(title=f"Dual Wielding: {c.name}", color=discord.Color.dark_blue())
    if c.equipped_weapon and c.off_hand_weapon:
        main_w = combat.get_weapon_profile(c.equipped_weapon)
        off_w = combat.get_weapon_profile(c.off_hand_weapon)
        embed.add_field(name="Main Hand", value=f"{c.equipped_weapon} ({main_w.get('rolled',2)}k{main_w.get('kept',1)})", inline=True)
        embed.add_field(name="Off Hand", value=f"{c.off_hand_weapon} ({off_w.get('rolled',2)}k{off_w.get('kept',1)})", inline=True)
        off_size = off_w.get("size", "Medium")
        if off_size == "Small":
            penalty = "−5 TN (Small off-hand weapon)"
        elif off_size == "Medium":
            penalty = "−10 TN (Medium off-hand weapon)"
        else:
            penalty = "−15 TN (Large off-hand weapon: Not normally allowed)"
        # Check skill mastery off-hand penalty removal (Knives R3, War Fan R3).
        off_skill = off_w.get("skill", "")
        off_rank = c.skills.get(off_skill, 0)
        mastery_note = ""
        if off_skill.lower() == "knives" and off_rank >= 3:
            mastery_note = "\n**Knives R3**: Off-hand penalty removed"
        elif off_skill.lower() == "war fan" and off_rank >= 3:
            mastery_note = "\n**War Fan R3**: Off-hand penalty removed"
        embed.add_field(name="Off-hand Attack Penalty", value=penalty + mastery_note, inline=False)
        embed.add_field(name="Dominant-hand Penalty", value="−5 to main-hand attacks while holding an off-hand weapon", inline=False)
        ir = stats.insight_rank(c)
        embed.add_field(name="Armor TN Bonus", value=f"+{ir} (Insight Rank {ir}) - dual-wielding covers more area", inline=False)
        embed.add_field(
            name="Usage",
            value=(
                "• `/fight attack` - main-hand attack (dominant-hand penalty auto-applied)\n"
                "• `/fight attack off_hand:True` - off-hand attack with penalty above\n"
                "• Mirumoto Two-Heavens / Niten Mastery may reduce penalties"
            ),
            inline=False,
        )
    elif c.equipped_weapon:
        embed.description = f"Only wielding **{c.equipped_weapon}** (no off-hand). Use `/inventory` to set both weapons."
    else:
        embed.description = "No weapons wielded. Use `/inventory` to wield weapons."
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref travel - travel time calculator
# ---------------------------------------------------------------------------

@ref.command(name="travel", description="Calculate travel time between locations.")
@app_commands.describe(
    distance="Distance in miles.",
    mode="Travel mode.",
    terrain="Terrain modifier (halves or quarters speed).",
)
@app_commands.choices(
    mode=[app_commands.Choice(name=v["name"], value=k) for k, v in TRAVEL_SPEEDS.items()],
    terrain=[
        app_commands.Choice(name="Road/Clear (normal)", value="normal"),
        app_commands.Choice(name="Rough/Hills (half)", value="half"),
        app_commands.Choice(name="Mountain/Swamp (quarter)", value="quarter"),
    ],
)
async def travel_calc(
    interaction: discord.Interaction,
    distance: app_commands.Range[int, 1, 10000],
    mode: app_commands.Choice[str],
    terrain: app_commands.Choice[str] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    info = TRAVEL_SPEEDS[mode.value]
    speed = info["miles_per_day"]
    terrain_name = "Road/Clear"
    if terrain and terrain.value == "half":
        speed = speed // 2
        terrain_name = "Rough/Hills"
    elif terrain and terrain.value == "quarter":
        speed = speed // 4
        terrain_name = "Mountain/Swamp"
    days = (distance + speed - 1) // speed if speed > 0 else 999
    embed = discord.Embed(title="Travel Calculator", color=discord.Color.green())
    embed.add_field(name="Distance", value=f"{distance} miles", inline=True)
    embed.add_field(name="Mode", value=info["name"], inline=True)
    embed.add_field(name="Terrain", value=terrain_name, inline=True)
    embed.add_field(name="Speed", value=f"{speed} miles/day", inline=True)
    embed.add_field(name="Travel Time", value=f"**{days} day{'s' if days != 1 else ''}**", inline=True)
    embed.add_field(name="Notes", value=info["description"], inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref modifiers - combat modifiers reference
# ---------------------------------------------------------------------------

@ref.command(name="modifiers", description="Terrain, range, and situational combat modifiers (L5R 4e).")
async def modifiers_ref(interaction: discord.Interaction) -> None:
    embed = discord.Embed(title="Combat Modifiers Reference", color=discord.Color.dark_gold())
    terrain_lines = [f"**{name}**: {effect}" for name, effect in TERRAIN_MODIFIERS]
    embed.add_field(name="Terrain & Situational", value="\n".join(terrain_lines), inline=False)
    range_lines = [f"**{name}**: {effect}" for name, effect in RANGE_INCREMENTS]
    embed.add_field(name="Range Increments (Ranged Weapons)", value="\n".join(range_lines), inline=False)
    embed.add_field(
        name="How to Apply",
        value=(
            "Use the `bonus_tn:` parameter on `/fight attack` for situational modifiers.\n"
            "Positive = harder to hit (cover, range). Negative = easier (prone target in melee)."
        ),
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref calledshot - called shot reference
# ---------------------------------------------------------------------------

@ref.command(name="calledshot", description="Called Shot: Raise costs and body part effects (L5R 4e).")
async def calledshot_ref(interaction: discord.Interaction) -> None:
    embed = discord.Embed(title="Called Shot Reference", color=discord.Color.dark_gold())
    parts_lines = []
    for raises, part in sorted(combat.CALLED_SHOT_PARTS.items()):
        parts_lines.append(f"**{raises} raise{'s' if raises != 1 else ''}**: {part.title()}")
    embed.add_field(name="Raises → Target", value="\n".join(parts_lines), inline=False)
    embed.add_field(
        name="Effects",
        value=(
            "Called Shots use the standard Raise mechanic (+5 TN per raise). "
            "On a successful hit, the DM adjudicates the effect based on the body part:\n"
            "• **Limb**: May disarm, hamper movement, or force a Stamina check\n"
            "• **Hand/Foot**: May drop weapon, reduce movement\n"
            "• **Head**: +1k1 bonus damage on this strike\n"
            "• **Eye/Ear/Finger**: Devastating: +1k1 damage, potential permanent injury"
        ),
        inline=False,
    )
    embed.add_field(
        name="Usage",
        value="Use `/fight attack maneuver: Called Shot raises: N`: The raise cost is added to TN automatically.",
        inline=False,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /ref tattoo - Togashi tattoo abilities
# ---------------------------------------------------------------------------

@ref_tattoo.command(name="list", description="List all Togashi tattoo abilities.")
async def tattoo_list(interaction: discord.Interaction) -> None:
    names = tattoo_catalog.tattoo_names()
    lines: list[str] = []
    for n in names:
        t = tattoo_catalog.TATTOO_CATALOG[n]
        tag = " (passive)" if t["passive"] else ""
        lines.append(f"• **{t['name']}**{tag}")
    text = f"**{len(names)} Togashi Tattoos**:\n" + "\n".join(lines)
    await interaction.response.send_message(text[:1990], ephemeral=True)


@ref_tattoo.command(name="view", description="View a specific tattoo ability's effect.")
@app_commands.describe(name="Tattoo name (e.g. bamboo, crane, dragon).")
async def tattoo_view(interaction: discord.Interaction, name: str) -> None:
    t = tattoo_catalog.get_tattoo(name)
    if t is None:
        await interaction.response.send_message(
            f"No tattoo named **{name}**. Use `/ref tattoo list` to see all.", ephemeral=True
        )
        return
    embed = discord.Embed(title=f"Tattoo: {t['name']}", color=discord.Color.dark_green())
    embed.add_field(name="Effect", value=t["effect"][:1024], inline=False)
    act = t["activation"].replace("_", " ").title()
    dur = t["duration"].replace("_", " ").title()
    layer = t["layer"].replace("_", " ").title()
    embed.add_field(name="Activation", value=act, inline=True)
    embed.add_field(name="Duration", value=dur, inline=True)
    embed.add_field(name="Layer", value=layer, inline=True)
    if t["passive"]:
        embed.set_footer(text="This tattoo is always active and does not block other tattoos.")
    else:
        embed.set_footer(text="Standard duration: 2 x School Rank rounds. Only one active tattoo at a time.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


@ref_tattoo.command(name="search", description="Search tattoos by keyword.")
@app_commands.describe(query="Keyword to search (name or effect text).")
async def tattoo_search(interaction: discord.Interaction, query: str) -> None:
    q = query.lower()
    matches = [
        t for t in tattoo_catalog.TATTOO_CATALOG.values()
        if q in t["name"].lower() or q in t["effect"].lower()
    ]
    if not matches:
        await interaction.response.send_message(f"No tattoos match `{query}`.", ephemeral=True)
        return
    lines = [f"• **{t['name']}**: {t['effect'][:80]}..." for t in matches]
    await interaction.response.send_message("" + "\n".join(lines), ephemeral=True)
