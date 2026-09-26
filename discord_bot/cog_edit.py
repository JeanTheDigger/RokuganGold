"""Unified staff editing commands: /edit group.

Consolidates /stat, /npc-edit, and scattered staff-only commands from /sheet,
/npc, and /dm into a single group that works on any character (PC or NPC).
Every subcommand accepts either a ``member:`` (PC) or ``npc:`` (NPC name)
target.  Omitting both targets the caller's own active character.
"""

from __future__ import annotations

import re

import discord
from discord import app_commands

import storage as _storage_mod
from l5r_rules import (
    advantage_effects, advantages, combat, enums, families, kata, kiho,
    schools, stats, taint,
)
from l5r_rules.character import Character


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store: _storage_mod.Store
    NPC_OWNER: str
    require_guild: object
    require_dm_role: object
    resolve_active: object
    refuse_if_dead: object
    on_death: object
    on_rename: object
    audit_stat: object
    build_sheet_embed: object
    check_insight: object
    parse_advdis_name: object
    npc_autocomplete: object
    armor_autocomplete: object
    advantage_autocomplete: object
    disadvantage_autocomplete: object
    kata_autocomplete: object
    kiho_autocomplete: object
    tattoo_autocomplete: object
    quality_autocomplete: object

_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    npc_owner: str,
    require_guild,
    require_dm_role,
    resolve_active,
    refuse_if_dead,
    on_death,
    on_rename,
    audit_stat,
    build_sheet_embed,
    check_insight,
    parse_advdis_name,
    npc_autocomplete,
    armor_autocomplete,
    advantage_autocomplete,
    disadvantage_autocomplete,
    kata_autocomplete,
    kiho_autocomplete,
    tattoo_autocomplete,
    quality_autocomplete,
) -> None:
    _d.store = store
    _d.NPC_OWNER = npc_owner
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.resolve_active = resolve_active
    _d.refuse_if_dead = refuse_if_dead
    _d.on_death = on_death
    _d.on_rename = on_rename
    _d.audit_stat = audit_stat
    _d.build_sheet_embed = build_sheet_embed
    _d.check_insight = check_insight
    _d.parse_advdis_name = parse_advdis_name
    _d.npc_autocomplete = npc_autocomplete
    _d.armor_autocomplete = armor_autocomplete
    _d.advantage_autocomplete = advantage_autocomplete
    _d.disadvantage_autocomplete = disadvantage_autocomplete
    _d.kata_autocomplete = kata_autocomplete
    _d.kiho_autocomplete = kiho_autocomplete
    _d.tattoo_autocomplete = tattoo_autocomplete
    _d.quality_autocomplete = quality_autocomplete

    edit_trait.autocomplete("npc")(_d.npc_autocomplete)
    edit_skill.autocomplete("npc")(_d.npc_autocomplete)
    edit_field.autocomplete("npc")(_d.npc_autocomplete)
    edit_identity.autocomplete("npc")(_d.npc_autocomplete)
    edit_equip.autocomplete("npc")(_d.npc_autocomplete)
    edit_equip.autocomplete("armor")(_d.armor_autocomplete)
    edit_feature.autocomplete("npc")(_d.npc_autocomplete)
    edit_elements.autocomplete("npc")(_d.npc_autocomplete)
    edit_wound.autocomplete("npc")(_d.npc_autocomplete)
    edit_heal.autocomplete("npc")(_d.npc_autocomplete)
    edit_activate.autocomplete("npc")(_d.npc_autocomplete)
    edit_rename.autocomplete("npc")(_d.npc_autocomplete)
    edit_notes.autocomplete("npc")(_d.npc_autocomplete)
    edit_mount.autocomplete("npc")(_d.npc_autocomplete)
    edit_spell.autocomplete("npc")(_d.npc_autocomplete)


# ---------------------------------------------------------------------------
# Shared target resolution
# ---------------------------------------------------------------------------

async def _resolve_target(
    interaction: discord.Interaction,
    member: discord.Member | None,
    npc: str | None,
) -> tuple[_storage_mod.CharacterRecord | None, str | None]:
    if member is not None and npc is not None:
        return None, "Provide `member:` or `npc:`, not both."
    if npc is not None:
        if interaction.guild_id is None:
            return None, "Please use this in a server channel."
        rec = _d.store.get_by_name(str(interaction.guild_id), _d.NPC_OWNER, npc)
        if rec is None:
            return None, f"No NPC named **{npc}**."
        return rec, None
    return await _d.resolve_active(interaction, member)


def _is_npc(rec: _storage_mod.CharacterRecord) -> bool:
    return rec.owner_id == _d.NPC_OWNER


# ---------------------------------------------------------------------------
# Choice lists
# ---------------------------------------------------------------------------

_TRAIT_CHOICES = [
    app_commands.Choice(name=("Void" if t == "void" else t.capitalize()), value=t)
    for t in enums.TRAITS
]

_SET_FIELDS = [
    "honor", "glory", "status", "infamy", "taint", "koku", "bu", "zeni",
    "age", "school_rank",
    "void_points_current", "void_points_max", "armor_tn_bonus", "armor_reduction",
]
_SET_CHOICES = [app_commands.Choice(name=f, value=f) for f in _SET_FIELDS]

_FEATURE_FIELDS = [
    app_commands.Choice(name="Advantage", value="advantages"),
    app_commands.Choice(name="Disadvantage", value="disadvantages"),
    app_commands.Choice(name="Technique", value="techniques"),
    app_commands.Choice(name="Kata", value="katas"),
    app_commands.Choice(name="Kiho", value="kiho"),
    app_commands.Choice(name="Weapon (owned)", value="weapons"),
    app_commands.Choice(name="Weapon Quality", value="weapon_qualities"),
    app_commands.Choice(name="Emphasis", value="_emphasis"),
    app_commands.Choice(name="Tattoo", value="tattoos"),
    app_commands.Choice(name="Spell", value="spells_known"),
]

_ELEMENT_CHOICES = [
    app_commands.Choice(name=e, value=e)
    for e in ("Air", "Earth", "Fire", "Water", "Void", "(clear)")
]

_ACTIVATE_TYPES = [
    app_commands.Choice(name="Kata", value="kata"),
    app_commands.Choice(name="Kiho", value="kiho"),
    app_commands.Choice(name="Tattoo", value="tattoo"),
]


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _apply_numeric_field(c: Character, field: str, value: float) -> None:
    if field in ("honor", "glory", "status", "infamy"):
        setattr(c, field, max(0.0, min(10.0, float(value))))
    elif field == "taint":
        c.taint = max(0.0, float(value))
        c.current_void_points = min(c.current_void_points, taint.void_point_cap(c))
    elif field == "koku":
        c.koku = max(0, int(value))
    elif field == "bu":
        c.bu = max(0, int(value))
    elif field == "zeni":
        c.zeni = max(0, int(value))
    elif field == "age":
        c.age = max(0, int(value))
    elif field == "school_rank":
        c.school_rank = max(1, min(10, int(value)))
    elif field == "void_points_max":
        c.max_void_points = max(0, int(value))
        c.current_void_points = min(c.current_void_points, taint.void_point_cap(c))
    elif field == "void_points_current":
        c.current_void_points = max(0, min(int(value), taint.void_point_cap(c)))
    elif field == "armor_tn_bonus":
        c.armor_tn_bonus = max(0, int(value))
    elif field == "armor_reduction":
        c.armor_reduction = max(0, int(value))


# ---------------------------------------------------------------------------
# /edit command group
# ---------------------------------------------------------------------------

edit_group = app_commands.Group(
    name="edit",
    description="Staff edits to any character (PC or NPC): Traits, skills, gear, features, wounds. [Fortune]",
)


# -- /edit trait -------------------------------------------------------------

@edit_group.command(name="trait", description="Set a Trait (or Void Ring) value. [Fortune]")
@app_commands.describe(
    trait="Which Trait.", value="New value (0-10).",
    member="Target player.", npc="NPC name.",
)
@app_commands.choices(trait=_TRAIT_CHOICES)
async def edit_trait(
    interaction: discord.Interaction,
    trait: app_commands.Choice[str],
    value: app_commands.Range[int, 0, 10],
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.set_trait(trait.value, value)
    if trait.value == "void":
        rec.character.max_void_points = rec.character.void_ring
        rec.character.current_void_points = min(
            rec.character.current_void_points, taint.void_point_cap(rec.character)
        )
    rank_msg = _d.check_insight(rec.character)
    changed = _d.store.save(rec, note="edit trait")
    await _d.audit_stat(interaction, rec, "edit trait", changed)
    label = "Void" if trait.value == "void" else trait.value.capitalize()
    await interaction.response.send_message(
        f"Set **{label}** to **{value}** on **{rec.character.name}**.{rank_msg}",
        embed=_d.build_sheet_embed(rec),
        ephemeral=True,
    )


# -- /edit skill -------------------------------------------------------------

@edit_group.command(
    name="skill",
    description="Set skill ranks. Single: skill='Kenjutsu' rank=3. Bulk: skill='Kenjutsu 3, Courtier 2'. [Fortune]",
)
@app_commands.describe(
    skill="Skill name, or bulk list: 'Kenjutsu 3, Courtier 2, Etiquette 1'.",
    rank="Rank 0-10 (0 removes). Omit when using bulk format.",
    member="Target player.", npc="NPC name.",
)
async def edit_skill(
    interaction: discord.Interaction,
    skill: app_commands.Range[str, 1, 200],
    rank: app_commands.Range[int, 0, 10] | None = None,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if rank is not None:
        skill_name = skill.strip().title()
        if rank == 0:
            c.skills.pop(skill_name, None)
            msg = f"Removed **{skill_name}** from **{c.name}**."
        else:
            c.skills[skill_name] = rank
            msg = f"Set **{skill_name}** to rank **{rank}** on **{c.name}**."
    else:
        parts = [p.strip() for p in skill.split(",") if p.strip()]
        changes: list[str] = []
        for p in parts:
            m = re.match(r"^(.+?)\s+(\d{1,2})$", p.strip())
            if not m:
                await interaction.response.send_message(
                    f"Could not parse **{p}**. Use format: `Kenjutsu 3, Courtier 2`.",
                    ephemeral=True,
                )
                return
            sname = m.group(1).strip().title()
            srank = int(m.group(2))
            if srank > 10:
                await interaction.response.send_message(
                    f"Rank for **{sname}** exceeds 10.", ephemeral=True,
                )
                return
            if srank == 0:
                c.skills.pop(sname, None)
                changes.append(f"removed **{sname}**")
            else:
                c.skills[sname] = srank
                changes.append(f"**{sname}** {srank}")
        msg = f"Set on **{c.name}**: {', '.join(changes)}."
    msg += _d.check_insight(c)
    changed = _d.store.save(rec, note="edit skill")
    await _d.audit_stat(interaction, rec, "edit skill", changed)
    await interaction.response.send_message(msg, embed=_d.build_sheet_embed(rec), ephemeral=True)


# -- /edit field -------------------------------------------------------------

@edit_group.command(
    name="field",
    description="Set a numeric field (honor, glory, void points, armor, etc.). [Fortune]",
)
@app_commands.describe(
    field="Which field to set.", value="New value.",
    member="Target player.", npc="NPC name.",
)
@app_commands.choices(field=_SET_CHOICES)
async def edit_field(
    interaction: discord.Interaction,
    field: app_commands.Choice[str],
    value: float,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    _apply_numeric_field(rec.character, field.value, value)
    changed = _d.store.save(rec, note="edit field")
    await _d.audit_stat(interaction, rec, "edit field", changed)
    await interaction.response.send_message(
        f"Updated **{field.value}** on **{rec.character.name}**.",
        embed=_d.build_sheet_embed(rec),
        ephemeral=True,
    )


# -- /edit identity ----------------------------------------------------------

@edit_group.command(
    name="identity",
    description="Set clan, family and/or school; a catalog family adds its +1 Trait. [Fortune]",
)
@app_commands.describe(
    clan="Clan name (free text).",
    family="Family name; a catalog match also applies its +1 Trait unless apply_bonus is false.",
    school="School name (catalog match preferred; free text allowed).",
    apply_bonus="Apply the catalog family's +1 Trait (default true). Ignored when the family is unchanged.",
    member="Target player.", npc="NPC name.",
)
async def edit_identity(
    interaction: discord.Interaction,
    clan: app_commands.Range[str, 1, 80] | None = None,
    family: app_commands.Range[str, 1, 80] | None = None,
    school: app_commands.Range[str, 1, 80] | None = None,
    apply_bonus: bool = True,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if clan is not None:
        c.clan = clan.strip()
        changes.append(f"Clan **{c.clan or '(none)'}**")
    if family is not None:
        fam = families.get(family.strip())
        new_name = fam["name"] if fam else family.strip()
        if new_name.lower() != (c.family or "").lower():
            if fam and apply_bonus:
                changes.append(f"Family **{fam['name']}** ({families.apply_to_character(c, fam)})")
                if not c.clan:
                    c.clan = fam["clan"]
            else:
                c.family = new_name
                changes.append(
                    f"Family **{new_name or '(none)'}**"
                    + (" (no bonus applied)" if fam else " (not in the catalog: No bonus)")
                )
        else:
            changes.append(f"Family already **{c.family}** (unchanged, no bonus re-applied)")
    if school is not None:
        sch = schools.get(school.strip())
        c.school = sch["name"] if sch else school.strip()
        changes.append(
            f"School **{c.school or '(none)'}**"
            + ("" if sch or not c.school else " (not in the catalog)")
        )
    if not changes:
        await interaction.response.send_message(
            "Give at least one of `clan:`, `family:` or `school:`.", ephemeral=True,
        )
        return
    changed = _d.store.save(rec, note="edit identity")
    await _d.audit_stat(interaction, rec, "edit identity", changed)
    await interaction.response.send_message(
        f"Updated **{c.name}**: " + "; ".join(changes) + ".",
        embed=_d.build_sheet_embed(rec),
        ephemeral=True,
    )


# -- /edit equip -------------------------------------------------------------

@edit_group.command(name="equip", description="Set equipped weapon, off-hand, and/or armor. [Fortune]")
@app_commands.describe(
    weapon="Equipped weapon name (empty to clear).",
    off_hand="Off-hand weapon (empty to clear).",
    armor="Armor type (bogu/ashigaru/light/heavy/etc., or 'none' to remove).",
    member="Target player.", npc="NPC name.",
)
async def edit_equip(
    interaction: discord.Interaction,
    weapon: app_commands.Range[str, 1, 80] | None = None,
    off_hand: app_commands.Range[str, 1, 80] | None = None,
    armor: app_commands.Range[str, 1, 80] | None = None,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if weapon is not None:
        c.equipped_weapon = weapon.strip()
        changes.append(f"Weapon: **{c.equipped_weapon or '(none)'}**")
    if off_hand is not None:
        c.off_hand_weapon = off_hand.strip()
        changes.append(f"Off-hand: **{c.off_hand_weapon or '(none)'}**")
    if armor is not None:
        a = armor.lower().strip()
        if a in ("none", "", "remove"):
            c.armor_name = ""
            c.owned_armor = ""
            c.armor_tn_bonus = 0
            c.armor_reduction = 0
            changes.append("Armor: **(none)**")
        else:
            spec = combat.get_armor(a)
            if spec is not None:
                c.armor_name = a
                c.owned_armor = a
                c.armor_tn_bonus = spec["tn_bonus"]
                c.armor_reduction = spec["reduction"]
                heavy = " (heavy)" if spec["is_heavy"] else ""
                cost_note = f" ({spec['cost']} koku)" if spec.get("cost") else ""
                changes.append(
                    f"Armor: **{a}**{heavy}: ATN+{spec['tn_bonus']}, Red {spec['reduction']}{cost_note}"
                )
                if spec.get("special"):
                    changes.append(spec["special"])
            else:
                c.armor_name = a
                c.owned_armor = a
                c.armor_tn_bonus = 0
                c.armor_reduction = 0
                changes.append(f"Armor: **{a}** (custom: Set ATN/Reduction with `/edit field`)")
    if not changes:
        await interaction.response.send_message(
            "Provide at least one of `weapon:`, `off_hand:`, or `armor:`.", ephemeral=True,
        )
        return
    changed = _d.store.save(rec, note="edit equip")
    await _d.audit_stat(interaction, rec, "edit equip", changed)
    await interaction.response.send_message(
        f"**{c.name}** equipment updated:\n" + "\n".join(changes),
        embed=_d.build_sheet_embed(rec),
        ephemeral=True,
    )


# -- /edit feature -----------------------------------------------------------

@edit_group.command(
    name="feature",
    description="Add or remove a sheet feature: Advantage, technique, kata, kiho, weapon, emphasis, spell. [Fortune]",
)
@app_commands.describe(
    category="Which feature list to modify.",
    entry="Name to add or remove.",
    remove="Remove instead of adding.",
    skill="Skill name (required for Emphasis only).",
    member="Target player.", npc="NPC name.",
)
@app_commands.choices(category=_FEATURE_FIELDS)
async def edit_feature(
    interaction: discord.Interaction,
    category: app_commands.Choice[str],
    entry: app_commands.Range[str, 1, 80],
    remove: bool = False,
    skill: app_commands.Range[str, 1, 80] | None = None,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    entry_name = entry.strip()

    if category.value == "_emphasis":
        if not skill:
            await interaction.response.send_message(
                "Emphasis requires the `skill:` parameter (e.g. skill: Kenjutsu).",
                ephemeral=True,
            )
            return
        skill_name = skill.strip()
        if remove:
            emph_list = c.emphases.get(skill_name, [])
            match = next((e for e in emph_list if e.lower() == entry_name.lower()), None)
            if match is None:
                await interaction.response.send_message(
                    f"**{c.name}** has no emphasis **{entry_name}** under {skill_name}.",
                    ephemeral=True,
                )
                return
            emph_list.remove(match)
            if not emph_list:
                del c.emphases[skill_name]
            msg = f"Removed emphasis **{match}** ({skill_name}) from **{c.name}**."
        else:
            emph_list = c.emphases.setdefault(skill_name, [])
            if any(e.lower() == entry_name.lower() for e in emph_list):
                await interaction.response.send_message(
                    f"**{c.name}** already has emphasis **{entry_name}** under {skill_name}.",
                    ephemeral=True,
                )
                return
            emph_list.append(entry_name)
            msg = f"Added emphasis **{entry_name}** ({skill_name}) to **{c.name}**."
    elif category.value == "weapon_qualities":
        if remove:
            match = next((q for q in c.weapon_qualities if q.lower() == entry_name.lower()), None)
            if match is None:
                await interaction.response.send_message(
                    f"**{c.name}** doesn't have weapon quality **{entry_name}**.", ephemeral=True,
                )
                return
            c.weapon_qualities.remove(match)
            msg = f"Removed weapon quality **{match}** from **{c.name}**."
        else:
            key = entry_name.lower()
            if key not in combat.WEAPON_QUALITIES:
                await interaction.response.send_message(
                    f"Unknown quality **{entry_name}**. Valid: {', '.join(sorted(combat.WEAPON_QUALITIES))}.",
                    ephemeral=True,
                )
                return
            if key in [q.lower() for q in c.weapon_qualities]:
                await interaction.response.send_message(
                    f"**{c.name}** already has weapon quality **{key}**.", ephemeral=True,
                )
                return
            c.weapon_qualities.append(key)
            c.weapon_qualities.sort()
            msg = f"Added weapon quality **{key}** to **{c.name}**."
    elif category.value in ("advantages", "disadvantages"):
        kind = "advantage" if category.value == "advantages" else "disadvantage"
        adv, canonical = _d.parse_advdis_name(entry_name, kind)
        if remove:
            old_len = len(getattr(c, category.value))
            setattr(c, category.value, [x for x in getattr(c, category.value) if x.lower() != canonical.lower()])
            if len(getattr(c, category.value)) == old_len:
                await interaction.response.send_message(
                    f"**{c.name}** doesn't have {kind} **{canonical}**.", ephemeral=True,
                )
                return
            msg = f"Removed {kind} **{canonical}** from **{c.name}**."
        else:
            lst: list = getattr(c, category.value)
            if canonical.lower() in [x.lower() for x in lst]:
                await interaction.response.send_message(
                    f"**{c.name}** already has {kind} **{canonical}**.", ephemeral=True,
                )
                return
            lst.append(canonical)
            msg = f"**{c.name}** {'gains' if kind == 'advantage' else 'takes'} the {kind} **{canonical}**."
            base = adv["name"] if adv else entry_name.split(":")[0].strip()
            lookup = (advantage_effects.PARAMETERISED_ADVANTAGES if kind == "advantage"
                      else advantage_effects.PARAMETERISED_DISADVANTAGES)
            param_hint = lookup.get(base)
            if param_hint and ":" not in entry_name:
                msg += f"\n*Hint: This {kind} can be parameterised. Use `{canonical}: <{param_hint}>`.*"
    else:
        lst = getattr(c, category.value)
        if remove:
            match = next((x for x in lst if x.lower() == entry_name.lower()), None)
            if match is None:
                await interaction.response.send_message(
                    f"**{c.name}** doesn't have {category.name} **{entry_name}**.",
                    ephemeral=True,
                )
                return
            lst.remove(match)
            msg = f"Removed {category.name} **{match}** from **{c.name}**."
        else:
            if any(x.lower() == entry_name.lower() for x in lst):
                await interaction.response.send_message(
                    f"**{c.name}** already has {category.name} **{entry_name}**.",
                    ephemeral=True,
                )
                return
            lst.append(entry_name)
            msg = f"Added {category.name} **{entry_name}** to **{c.name}**."

    changed = _d.store.save(rec, note=f"edit feature ({category.name})")
    await _d.audit_stat(interaction, rec, f"edit feature ({category.name})", changed)
    await interaction.response.send_message(msg, embed=_d.build_sheet_embed(rec), ephemeral=True)


# -- /edit elements ----------------------------------------------------------

@edit_group.command(name="elements", description="Set affinity and/or deficiency element. [Fortune]")
@app_commands.describe(
    affinity_element="Affinity element (choose '(clear)' to remove).",
    deficiency_element="Deficiency element (choose '(clear)' to remove).",
    member="Target player.", npc="NPC name.",
)
@app_commands.choices(affinity_element=_ELEMENT_CHOICES, deficiency_element=_ELEMENT_CHOICES)
async def edit_elements(
    interaction: discord.Interaction,
    affinity_element: app_commands.Choice[str] | None = None,
    deficiency_element: app_commands.Choice[str] | None = None,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    changes: list[str] = []
    if affinity_element is not None:
        c.affinity_element = "" if affinity_element.value == "(clear)" else affinity_element.value.lower()
        changes.append(f"Affinity: **{c.affinity_element or '(none)'}**")
    if deficiency_element is not None:
        c.deficiency_element = "" if deficiency_element.value == "(clear)" else deficiency_element.value.lower()
        changes.append(f"Deficiency: **{c.deficiency_element or '(none)'}**")
    if not changes:
        await interaction.response.send_message(
            "Provide at least one of `affinity_element:` or `deficiency_element:`.",
            ephemeral=True,
        )
        return
    changed = _d.store.save(rec, note="edit elements")
    await _d.audit_stat(interaction, rec, "edit elements", changed)
    await interaction.response.send_message(
        f"**{c.name}**: " + ", ".join(changes) + ".", ephemeral=True,
        embed=_d.build_sheet_embed(rec),
    )


# -- /edit wound -------------------------------------------------------------

@edit_group.command(name="wound", description="Apply wounds to a character (raw, no armor reduction). [Fortune]")
@app_commands.describe(
    amount="Wounds to apply.",
    member="Target player.", npc="NPC name.",
)
async def edit_wound(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if await _d.refuse_if_dead(interaction, c):
        return
    old = stats.wound_level_name(c)
    c.wounds_taken += amount
    _d.store.save(rec, note="wound")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    dead = ""
    if stats.is_dead(c):
        death_notes = await _d.on_death(str(interaction.guild_id), c.name, rec.owner_id, rec.id)
        dead = "  **DEAD**" + "".join(f"\n- {n}" for n in death_notes)
    await interaction.response.send_message(
        f"**{c.name}** takes **{amount}** wounds → {c.wounds_taken} total{crossed}{dead}", ephemeral=True,
        embed=_d.build_sheet_embed(rec),
    )


# -- /edit heal --------------------------------------------------------------

@edit_group.command(name="heal", description="Heal wounds on a character. [Fortune]")
@app_commands.describe(
    amount="Wounds to heal.",
    member="Target player.", npc="NPC name.",
)
async def edit_heal(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 1000],
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if stats.is_dead(c):
        await interaction.response.send_message(
            f"**{c.name}** is dead. PC death is permanent.", ephemeral=True,
        )
        return
    old = stats.wound_level_name(c)
    c.wounds_taken = max(0, c.wounds_taken - amount)
    _d.store.save(rec, note="heal")
    new = stats.wound_level_name(c)
    crossed = f"  ({old} → **{new}**)" if new != old else ""
    await interaction.response.send_message(
        f"**{c.name}** heals **{amount}** wounds → {c.wounds_taken} total{crossed}", ephemeral=True,
        embed=_d.build_sheet_embed(rec),
    )


# -- /edit activate ----------------------------------------------------------

@edit_group.command(
    name="activate",
    description="Activate or deactivate a Kata, Kiho, or Tattoo. [Fortune]",
)
@app_commands.describe(
    kind="What to activate.",
    name="Name of the Kata, Kiho, or Tattoo.",
    off="Deactivate instead.",
    bear_choice="Bear Tattoo only: 'stamina' or 'strength'.",
    lion_skill="Lion Tattoo only: Bugei skill to boost by +SR ranks.",
    member="Target player.", npc="NPC name.",
)
@app_commands.choices(
    kind=_ACTIVATE_TYPES,
    bear_choice=[
        app_commands.Choice(name="Stamina (+School Rank)", value="stamina"),
        app_commands.Choice(name="Strength (+ceil(SR/2))", value="strength"),
    ],
)
async def edit_activate(
    interaction: discord.Interaction,
    kind: app_commands.Choice[str],
    name: app_commands.Range[str, 1, 80] | None = None,
    off: bool = False,
    bear_choice: app_commands.Choice[str] | None = None,
    lion_skill: app_commands.Range[str, 1, 80] | None = None,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    if await _d.refuse_if_dead(interaction, rec.character):
        return
    c = rec.character

    if kind.value == "kata":
        if off or not name:
            prev = c.active_kata
            c.active_kata = ""
            tail = f" (**{prev}**)" if prev else ""
            msg = f"**{c.name}** drops their active Kata{tail}."
        else:
            k = kata.get(name)
            canonical = k["name"] if k else name.strip()
            if canonical.lower() not in [x.lower() for x in c.katas]:
                await interaction.response.send_message(
                    f"**{c.name}** hasn't learned the Kata **{canonical}**: "
                    f"Add it with `/edit feature category:Kata entry:{canonical}`.",
                    ephemeral=True,
                )
                return
            c.active_kata = canonical
            msg = f"**{c.name}** assumes the Kata **{canonical}**."

    elif kind.value == "kiho":
        if not name:
            await interaction.response.send_message(
                "Provide a `name:` for the Kiho to activate/deactivate.", ephemeral=True,
            )
            return
        h = kiho.get(name)
        canonical = h["name"] if h else name.strip()
        if off:
            c.active_kiho = [x for x in c.active_kiho if x.lower() != canonical.lower()]
            msg = f"**{c.name}** ends the Kiho **{canonical}**."
        else:
            if canonical.lower() not in [x.lower() for x in c.kiho]:
                await interaction.response.send_message(
                    f"**{c.name}** hasn't learned the Kiho **{canonical}**: "
                    f"Add it with `/edit feature category:Kiho entry:{canonical}`.",
                    ephemeral=True,
                )
                return
            ktype = (h["type"] if h else "").strip().lower()
            replaced = ""
            if ktype in ("internal", "kharmic", "mystical"):
                dropped = []
                kept = []
                for x in c.active_kiho:
                    xr = kiho.get(x)
                    xt = (xr["type"] if xr else "").strip().lower()
                    (dropped if xt == ktype else kept).append(x)
                c.active_kiho = kept
                if dropped:
                    replaced = f" (replaces {', '.join(dropped)})"
            if canonical.lower() not in [x.lower() for x in c.active_kiho]:
                c.active_kiho.append(canonical)
            tlabel = h["type"] if h and h.get("type") else "Kiho"
            msg = (
                f"**{c.name}** activates the {tlabel} Kiho **{canonical}**{replaced}. "
                f"*(Activation cost: A Void Point or Meditation/Void roll, and duration are "
                f"DM-adjudicated; its combat effect is shown as a reminder on attacks.)*"
            )

    else:
        if off:
            old = c.active_tattoo or "(none)"
            c.active_tattoo = ""
            c.bear_tattoo_choice = ""
            c.lion_tattoo_skill = ""
            msg = f"**{c.name}** deactivates the **{old}** tattoo."
        elif not name:
            await interaction.response.send_message(
                "Provide a `name:` to activate, or `off:true` to deactivate.", ephemeral=True,
            )
            return
        else:
            key = name.lower().strip()
            if key not in [x.lower() for x in c.tattoos]:
                await interaction.response.send_message(
                    f"**{c.name}** doesn't have a **{name}** tattoo. "
                    f"Grant it with `/edit feature category:Tattoo entry:{name}`.",
                    ephemeral=True,
                )
                return
            if key == "bear" and not bear_choice:
                await interaction.response.send_message(
                    "Bear Tattoo requires `bear_choice:` - pick **Stamina** (+SR) or **Strength** (+ceil(SR/2)).",
                    ephemeral=True,
                )
                return
            _BUGEI_SKILLS = {
                "athletics", "battle", "chain weapons", "defense", "heavy weapons",
                "horsemanship", "hunting", "iaijutsu", "jiujutsu", "kenjutsu",
                "knives", "kyujutsu", "naginatajutsu", "ninjutsu", "polearms",
                "spears", "staves", "war fan",
            }
            if key == "lion":
                if not lion_skill:
                    await interaction.response.send_message(
                        "Lion Tattoo requires `lion_skill:` - name one Bugei skill to boost by +SR ranks.",
                        ephemeral=True,
                    )
                    return
                if lion_skill.lower().strip() not in _BUGEI_SKILLS:
                    await interaction.response.send_message(
                        f"**{lion_skill}** is not a Bugei skill. Valid: {', '.join(sorted(_BUGEI_SKILLS))}.",
                        ephemeral=True,
                    )
                    return
            from l5r_rules import tattoo_catalog
            t = tattoo_catalog.get_tattoo(key)
            label = t["name"] if t else key.title()
            c.active_tattoo = label
            c.bear_tattoo_choice = bear_choice.value if bear_choice and key == "bear" else ""
            c.lion_tattoo_skill = lion_skill.strip() if lion_skill and key == "lion" else ""
            effect = f"\n> {t['effect']}" if t else ""
            extra = ""
            if key == "bear" and bear_choice:
                if bear_choice.value == "stamina":
                    extra = f"\n> Choice: **Stamina +{c.school_rank}** (locked for duration)"
                else:
                    import math as _m
                    extra = f"\n> Choice: **Strength +{_m.ceil(c.school_rank / 2)}** (locked for duration)"
            elif key == "lion" and lion_skill:
                extra = f"\n> Skill: **{lion_skill.strip().title()} +{c.school_rank}** ranks (locked for duration)"
            msg = f"**{c.name}** activates the **{label}** tattoo.{effect}{extra}"

    _d.store.save(rec)
    await interaction.response.send_message(msg, embed=_d.build_sheet_embed(rec), ephemeral=True)


# -- /edit rename ------------------------------------------------------------

@edit_group.command(name="rename", description="Rename a character (PC or NPC). [Fortune]")
@app_commands.describe(
    new_name="New character name.",
    member="Target player.", npc="NPC name.",
)
async def edit_rename(
    interaction: discord.Interaction,
    new_name: app_commands.Range[str, 1, 64],
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    guild = str(interaction.guild_id)
    owner = rec.owner_id
    clean_name = new_name.strip()
    if _d.store.get_by_name(guild, owner, clean_name) is not None:
        await interaction.response.send_message(
            f"A character named **{clean_name}** already exists for that owner.", ephemeral=True,
        )
        return
    old_name = rec.character.name
    rec.character.name = clean_name
    _d.store.save(rec)
    await interaction.response.defer(ephemeral=True)
    notes = await _d.on_rename(guild, rec, old_name)
    tail = f" ({'; '.join(notes)})" if notes else ""
    await interaction.followup.send(
        f"Renamed **{old_name}** → **{clean_name}**.{tail}", embed=_d.build_sheet_embed(rec),
        ephemeral=True,
    )


# -- /edit notes -------------------------------------------------------------

@edit_group.command(name="notes", description="Set freeform notes on a character (omit text to clear). [Fortune]")
@app_commands.describe(
    text="Notes text (omit or leave empty to clear).",
    member="Target player.", npc="NPC name.",
)
async def edit_notes(
    interaction: discord.Interaction,
    text: app_commands.Range[str, 1, 900] = "",
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    rec.character.notes = text.strip()
    _d.store.save(rec)
    if rec.character.notes:
        msg = f"Notes set on **{rec.character.name}**: *{rec.character.notes}*"
    else:
        msg = f"Notes cleared on **{rec.character.name}**."
    await interaction.response.send_message(msg, embed=_d.build_sheet_embed(rec), ephemeral=True)


# -- /edit mount -------------------------------------------------------------

@edit_group.command(name="mount", description="Toggle mounted state on a character (outside combat). [Fortune]")
@app_commands.describe(
    dismount="Dismount instead of mounting.",
    member="Target player.", npc="NPC name.",
)
async def edit_mount(
    interaction: discord.Interaction,
    dismount: bool = False,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if await _d.refuse_if_dead(interaction, c):
        return
    mounting = not dismount
    if c.is_mounted == mounting:
        state = "already mounted" if mounting else "already dismounted"
        await interaction.response.send_message(f"**{c.name}** is {state}.", ephemeral=True)
        return
    c.is_mounted = mounting
    prof = combat.get_armor(c.armor_name) if c.armor_name else None
    armor_note = ""
    if prof and prof.get("tn_bonus_mounted"):
        if mounting:
            c.armor_tn_bonus = prof["tn_bonus_mounted"]
        else:
            c.armor_tn_bonus = prof["tn_bonus"]
        armor_note = f" Armor TN bonus → +{c.armor_tn_bonus}."
    _d.store.save(rec, note="mount" if mounting else "dismount")
    if mounting:
        embed = discord.Embed(
            title=f"{c.name} mounts up",
            color=discord.Color.dark_gold(),
            description=f"Riding armor skill penalty removed while mounted.{armor_note}",
        )
    else:
        embed = discord.Embed(
            title=f"{c.name} dismounts",
            color=discord.Color.greyple(),
            description=armor_note.strip() if armor_note else "Mounted condition cleared.",
        )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# -- /edit spell -------------------------------------------------------------

@edit_group.command(name="spell", description="Add or remove a spell from a character's known spell list (free, no XP). [Fortune]")
@app_commands.describe(
    spell="Spell name to add or remove.",
    remove="Remove instead of adding.",
    member="Target player.", npc="NPC name.",
)
async def edit_spell(
    interaction: discord.Interaction,
    spell: app_commands.Range[str, 1, 80],
    remove: bool = False,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec, err = await _resolve_target(interaction, member, npc)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    spell_name = spell.strip()
    if remove:
        match = next((s for s in c.spells_known if s.lower() == spell_name.lower()), None)
        if match is None:
            await interaction.response.send_message(
                f"**{c.name}** doesn't know **{spell_name}**.", ephemeral=True,
            )
            return
        c.spells_known.remove(match)
        msg = f"Removed spell **{match}** from **{c.name}**."
    else:
        if any(s.lower() == spell_name.lower() for s in c.spells_known):
            await interaction.response.send_message(
                f"**{c.name}** already knows **{spell_name}**.", ephemeral=True,
            )
            return
        c.spells_known.append(spell_name)
        msg = f"Added spell **{spell_name}** to **{c.name}**."
    _d.store.save(rec)
    await interaction.response.send_message(msg, embed=_d.build_sheet_embed(rec), ephemeral=True)
