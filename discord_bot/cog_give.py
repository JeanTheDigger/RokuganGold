"""Staff hand-outs and monthly clan stipends.

/give, /take: One command each for catalog weapons, armor, money and plain items
(Fortune+). The player is told in their support channel.
/stipend set, /stipend view, /stipend clear: Clan stipend config (Kami only).
pay_monthly_stipends(): Called by dm_new_day on IC month change.
"""

from __future__ import annotations

import discord
from discord import app_commands

import storage as _storage_mod
from cog_inventory import build_inventory_embed
from helpers import find_support_channel
from l5r_rules import combat as _combat
from l5r_rules import stats as _stats
from l5r_rules.character import Character, format_purse, normalise_purse


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store: _storage_mod.Store
    NPC_OWNER: str
    ROLE_KAMI: str
    require_guild: object
    require_dm_role: object
    is_kami: object
    resolve_active: object
    audit_stat: object
    npc_autocomplete: object
    combat_log: object
    is_dm: object
    modify_inventory: object
    CAT_PLAYER_SUPPORT: str

_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    npc_owner: str,
    role_kami: str,
    require_guild,
    require_dm_role,
    is_kami,
    resolve_active,
    audit_stat,
    npc_autocomplete,
    combat_log,
    is_dm,
    modify_inventory,
    cat_player_support: str,
) -> None:
    _d.store = store
    _d.NPC_OWNER = npc_owner
    _d.ROLE_KAMI = role_kami
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.is_kami = is_kami
    _d.resolve_active = resolve_active
    _d.audit_stat = audit_stat
    _d.npc_autocomplete = npc_autocomplete
    _d.combat_log = combat_log
    _d.is_dm = is_dm
    _d.modify_inventory = modify_inventory
    _d.CAT_PLAYER_SUPPORT = cat_player_support

    give.autocomplete("npc")(_d.npc_autocomplete)
    take.autocomplete("npc")(_d.npc_autocomplete)
    give.autocomplete("what")(_give_what_ac)
    take.autocomplete("what")(_take_what_ac)


# ---------------------------------------------------------------------------
# Shared target resolution (PC or NPC)
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


def _format_amount(koku: int, bu: int, zeni: int) -> str:
    parts: list[str] = []
    if koku:
        parts.append(f"{koku} koku")
    if bu:
        parts.append(f"{bu} bu")
    if zeni:
        parts.append(f"{zeni} zeni")
    return ", ".join(parts) if parts else "0 zeni"


# ---------------------------------------------------------------------------
# /give and /take: One command for weapons, armor, money and items
# ---------------------------------------------------------------------------

_MONEY: tuple[str, ...] = ("koku", "bu", "zeni")
_ZENI_PER: dict[str, int] = {"koku": 50, "bu": 10, "zeni": 1}


def _parse_what(what: str) -> tuple[str, str]:
    """Return (kind, key) for a give/take target: kind is weapon, armor, money or item.
    Autocomplete submits 'kind:key'; text typed by hand is matched against the
    catalogs and money names, and anything else is a plain item."""
    kind, sep, key = what.partition(":")
    kind, key = kind.strip().lower(), key.strip()
    if sep and key:
        if kind == "weapon" and key.lower() in _combat.WEAPON_CATALOG:
            return "weapon", key.lower()
        if kind == "armor" and _combat.get_armor(key.lower()) is not None:
            return "armor", key.lower()
        if kind == "money" and key.lower() in _MONEY:
            return "money", key.lower()
        if kind == "item":
            return "item", key
    text = what.strip()
    slug = text.lower().replace(" ", "_")
    if slug in _combat.WEAPON_CATALOG:
        return "weapon", slug
    if _combat.get_armor(slug) is not None:
        return "armor", slug
    if slug in _MONEY:
        return "money", slug
    return "item", text


def _label(kind: str, key: str) -> str:
    if kind == "weapon":
        w = _combat.WEAPON_CATALOG[key]
        return f"{key.replace('_', ' ')} (weapon, {w['skill']}, DR {w['rolled']}k{w['kept']})"
    if kind == "armor":
        a = _combat.get_armor(key) or {}
        return f"{key.replace('_', ' ')} (armor, TN +{a.get('tn_bonus', 0)}, Reduction {a.get('reduction', 0)})"
    if kind == "money":
        return key
    return key


def _give_candidates(guild_id: str) -> list[tuple[str, str]]:
    """(label, value) for everything /give can hand out."""
    out: list[tuple[str, str]] = []
    for k, w in _combat.WEAPON_CATALOG.items():
        out.append((f"{k.replace('_', ' ')} · weapon · {w['skill']} DR {w['rolled']}k{w['kept']}", f"weapon:{k}"))
    for k, a in _combat.ARMOR_CATALOG.items():
        out.append((f"{k.replace('_', ' ')} · armor · TN +{a['tn_bonus']}, Reduction {a['reduction']}", f"armor:{k}"))
    for m in _MONEY:
        out.append((f"{m} · money", f"money:{m}"))
    for n in _d.store.list_inventory_item_names(guild_id):
        out.append((f"{n} · item", f"item:{n}"))
    return out


def _target_candidates(c: Character) -> list[tuple[str, str]]:
    """(label, value) for everything a character currently holds."""
    out: list[tuple[str, str]] = []
    for w in c.weapons:
        out.append((f"{w.replace('_', ' ')} · weapon", f"weapon:{w}"))
    for a in {c.armor_name, c.owned_armor} - {""}:
        out.append((f"{a.replace('_', ' ')} · armor" + (" (worn)" if a == c.armor_name else ""), f"armor:{a}"))
    for m in _MONEY:
        if getattr(c, m):
            out.append((f"{m} · money · has {getattr(c, m)}", f"money:{m}"))
    for n, q in sorted(c.inventory.items()):
        out.append((f"{n} · item × {q}", f"item:{n}"))
    return out


def _choices(cands: list[tuple[str, str]], current: str, allow_new: bool) -> list[app_commands.Choice[str]]:
    cur = current.strip().lower()
    if cur:
        starts = [(l, v) for l, v in cands if l.lower().startswith(cur)]
        contains = [(l, v) for l, v in cands if cur in l.lower() and not l.lower().startswith(cur)]
        cands = starts + contains
        if allow_new and not any(l.lower().split(" · ")[0] == cur for l, _ in cands):
            cands = [(f"{current.strip()} · new item", f"item:{current.strip()}")] + cands
    return [app_commands.Choice(name=l[:100], value=v[:100]) for l, v in cands[:25]]


async def _give_what_ac(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None or not _d.is_dm(interaction):
        return []
    return _choices(_give_candidates(str(interaction.guild_id)), current, allow_new=True)


async def _take_what_ac(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None or not _d.is_dm(interaction):
        return []
    ns = interaction.namespace
    guild = str(interaction.guild_id)
    npc = getattr(ns, "npc", None)
    member = getattr(ns, "member", None)
    if npc:
        rec = _d.store.get_by_name(guild, _d.NPC_OWNER, npc)
    else:
        rec = _d.store.get_active(guild, str(member.id if member is not None else interaction.user.id))
    if rec is None:
        return []
    return _choices(_target_candidates(rec.character), current, allow_new=False)


def _apply_give(c: Character, kind: str, key: str, qty: int) -> tuple[bool, str, str]:
    """Mutate the character. Returns (ok, what was given or why not, staff-only note)."""
    if kind == "weapon":
        if key in [w.lower() for w in c.weapons]:
            return False, f"**{c.name}** already owns a {key.replace('_', ' ')}. Each catalog weapon is owned once.", ""
        c.weapons.append(key)
        return True, _label(kind, key), ""
    if kind == "armor":
        spare = c.owned_armor if c.owned_armor != c.armor_name else ""
        c.owned_armor = key
        note = f"It replaces the spare {spare.replace('_', ' ')}." if spare and spare != key else ""
        return True, _label(kind, key), note
    if kind == "money":
        setattr(c, key, getattr(c, key) + qty)
        normalise_purse(c)
        return True, f"{qty} {key}", ""
    ok, msg = _d.modify_inventory(c.inventory, c.name, key, qty, False)
    if not ok:
        return False, msg, ""
    return True, f"{qty} × {key}", ""


def _apply_take(c: Character, kind: str, key: str, qty: int) -> tuple[bool, str, str]:
    if kind == "weapon":
        if key not in [w.lower() for w in c.weapons]:
            return False, f"**{c.name}** does not own a {key.replace('_', ' ')}.", ""
        c.weapons = [w for w in c.weapons if w.lower() != key]
        note = ""
        if (c.equipped_weapon or "").lower() == key or (c.off_hand_weapon or "").lower() == key:
            note = "It was in hand, so they are now unarmed on that side."
        if (c.equipped_weapon or "").lower() == key:
            c.equipped_weapon = ""
        if (c.off_hand_weapon or "").lower() == key:
            c.off_hand_weapon = ""
        return True, _label(kind, key), note
    if kind == "armor":
        if key not in {c.armor_name, c.owned_armor}:
            return False, f"**{c.name}** has no {key.replace('_', ' ')}.", ""
        if c.armor_name == key:
            c.armor_name, c.armor_tn_bonus, c.armor_reduction = "", 0, 0
        if c.owned_armor == key:
            c.owned_armor = ""
        return True, _label(kind, key), ""
    if kind == "money":
        cost = qty * _ZENI_PER[key]
        if c.total_zeni < cost:
            return False, f"**{c.name}** only has {format_purse(c)}.", ""
        total = c.total_zeni - cost
        c.koku, c.bu, c.zeni = total // 50, (total % 50) // 10, total % 10
        return True, f"{qty} {key}", ""
    ok, msg = _d.modify_inventory(c.inventory, c.name, key, qty, True)
    if not ok:
        return False, msg, ""
    return True, f"{qty} × {key}", ""


async def _notify_player(interaction: discord.Interaction, rec: _storage_mod.CharacterRecord, text: str) -> bool:
    """Post the change in the character's support channel. NPCs get no notice."""
    if rec.owner_id == _d.NPC_OWNER or interaction.guild is None:
        return False
    channel = await find_support_channel(interaction.guild, rec.character.name, _d.CAT_PLAYER_SUPPORT)
    if channel is None:
        return False
    try:
        await channel.send(text, allowed_mentions=discord.AllowedMentions.none())
    except (discord.Forbidden, discord.HTTPException):
        return False
    return True


async def _transfer(
    interaction: discord.Interaction, giving: bool, what: str, quantity: int,
    member: discord.Member | None, npc: str | None, reason: str | None,
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
    kind, key = _parse_what(what)
    ok, desc, note = (_apply_give if giving else _apply_take)(c, kind, key, quantity)
    if not ok:
        await interaction.response.send_message(desc, ephemeral=True)
        return
    changed = _d.store.save(rec)
    verb = "give" if giving else "take"
    await _d.audit_stat(interaction, rec, f"{verb} {kind} {key}" + (f" ({reason})" if reason else ""), changed)
    why = f" Reason: {reason}." if reason else ""
    purse = f" Purse now {format_purse(c)}." if kind == "money" else ""
    hint = {"armor": " Put it on from `/inventory`.", "weapon": " Wield it from `/inventory`."}.get(kind, " Open `/inventory` to see it.")
    staff = interaction.user.display_name
    if giving:
        player_line = f"**{staff}** gave **{c.name}**: {desc}.{why}{purse}{hint}"
    else:
        player_line = f"**{staff}** took from **{c.name}**: {desc}.{why}{purse}"
    told = await _notify_player(interaction, rec, player_line)
    extra = f" {note}" if note else ""
    if not told and rec.owner_id != _d.NPC_OWNER:
        extra += " No support channel found, so the player was not notified."
    await interaction.response.send_message(
        f"{'Gave' if giving else 'Took'} {desc} {'to' if giving else 'from'} **{c.name}**.{why}{purse}{extra}",
        embed=build_inventory_embed(rec), ephemeral=True,
    )


@app_commands.command(name="give", description="Give a character a catalog weapon, armor, money or any item. [Fortune]")
@app_commands.describe(
    what="A weapon or armor from the catalog, koku, bu or zeni, or any item name.",
    quantity="How many (default 1). For money, the amount.",
    member="Target player (default: You).",
    npc="Target NPC instead of a player.",
    reason="Shown to the player and kept in the audit log.",
)
async def give(
    interaction: discord.Interaction,
    what: app_commands.Range[str, 1, 80],
    quantity: app_commands.Range[int, 1, 9999] = 1,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
    reason: app_commands.Range[str, 1, 200] | None = None,
) -> None:
    await _transfer(interaction, True, what, quantity, member, npc, reason)


@app_commands.command(name="take", description="Take a weapon, armor, money or item away from a character. [Fortune]")
@app_commands.describe(
    what="Something the character holds: Pick from the list.",
    quantity="How many (default 1). For money, the amount.",
    member="Target player (default: You).",
    npc="Target NPC instead of a player.",
    reason="Shown to the player and kept in the audit log.",
)
async def take(
    interaction: discord.Interaction,
    what: app_commands.Range[str, 1, 80],
    quantity: app_commands.Range[int, 1, 9999] = 1,
    member: discord.Member | None = None,
    npc: app_commands.Range[str, 1, 80] | None = None,
    reason: app_commands.Range[str, 1, 200] | None = None,
) -> None:
    await _transfer(interaction, False, what, quantity, member, npc, reason)


# ---------------------------------------------------------------------------
# Stipend commands (Kami only)
# ---------------------------------------------------------------------------

stipend_group = app_commands.Group(name="stipend", description="Monthly clan stipends (Kami only)")


@stipend_group.command(name="set", description="Set a clan's monthly stipend. [Kami]")
@app_commands.describe(
    clan="Clan name (e.g. Crab, Crane, Dragon)",
    koku="Koku per month",
    bu="Bu per month",
    zeni="Zeni per month",
)
async def stipend_set(
    interaction: discord.Interaction,
    clan: app_commands.Range[str, 1, 80],
    koku: app_commands.Range[int, 0, 9999] = 0,
    bu: app_commands.Range[int, 0, 9999] = 0,
    zeni: app_commands.Range[int, 0, 9999] = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not _d.is_kami(interaction):
        await interaction.response.send_message(
            f"Only the **{_d.ROLE_KAMI}** role can configure stipends.", ephemeral=True,
        )
        return
    if koku == 0 and bu == 0 and zeni == 0:
        await interaction.response.send_message(
            "Stipend must include at least one non-zero denomination. Use `/stipend clear` to remove.",
            ephemeral=True,
        )
        return

    clan = clan.strip().title()
    _d.store.set_stipend(str(interaction.guild_id), clan, koku, bu, zeni)
    await interaction.response.send_message(
        f"Monthly stipend for **{clan}** set to **{_format_amount(koku, bu, zeni)}**.",
        ephemeral=True,
    )


@stipend_group.command(name="view", description="View all configured clan stipends. [Kami]")
async def stipend_view(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not _d.is_kami(interaction):
        await interaction.response.send_message(
            f"Only the **{_d.ROLE_KAMI}** role can view stipend configuration.", ephemeral=True,
        )
        return

    stipends = _d.store.get_stipends(str(interaction.guild_id))
    if not stipends:
        await interaction.response.send_message("No stipends configured. Use `/stipend set` to add one.", ephemeral=True)
        return

    lines = [f"**{clan}**: {_format_amount(k, b, z)}" for clan, (k, b, z) in stipends.items()]
    embed = discord.Embed(
        title="Monthly Clan Stipends",
        description="\n".join(lines),
        color=0xC4A747,
    )
    embed.set_footer(text="Paid automatically on each IC month change via /dm new_day.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


@stipend_group.command(name="clear", description="Remove a clan's monthly stipend. [Kami]")
@app_commands.describe(clan="Clan name to remove the stipend for")
async def stipend_clear(
    interaction: discord.Interaction,
    clan: app_commands.Range[str, 1, 80],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not _d.is_kami(interaction):
        await interaction.response.send_message(
            f"Only the **{_d.ROLE_KAMI}** role can configure stipends.", ephemeral=True,
        )
        return

    clan = clan.strip().title()
    removed = _d.store.delete_stipend(str(interaction.guild_id), clan)
    if removed:
        await interaction.response.send_message(f"Stipend for **{clan}** removed.", ephemeral=True)
    else:
        await interaction.response.send_message(f"No stipend was configured for **{clan}**.", ephemeral=True)


# ---------------------------------------------------------------------------
# Stipend payment (called from bot.py on IC month change)
# ---------------------------------------------------------------------------

async def pay_monthly_stipends(guild_id: str) -> list[str]:
    """Pay stipends to all active PCs whose clan has a configured stipend.

    Returns a list of human-readable lines describing what was paid.
    """
    stipends = _d.store.get_stipends(guild_id)
    if not stipends:
        return []

    active = _d.store.list_active_pcs(guild_id)
    lines: list[str] = []
    for _owner_id, rec in active:
        c = rec.character
        if _stats.is_dead(c):
            continue
        clan = c.clan.strip().title()
        if clan not in stipends:
            continue
        koku, bu, zeni = stipends[clan]
        c.koku += koku
        c.bu += bu
        c.zeni += zeni
        normalise_purse(c)
        _d.store.save(rec, note="monthly stipend")
        lines.append(f"**{c.name}** ({clan}): +{_format_amount(koku, bu, zeni)} → {format_purse(c)}")
    await _d.combat_log(guild_id, f"STIPEND: Monthly stipends paid to {len(lines)} character(s)")
    return lines
