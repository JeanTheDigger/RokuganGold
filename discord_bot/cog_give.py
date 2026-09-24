"""Staff-only money commands and monthly clan stipends.

/givekoku, /givebu, /givezeni: Additive money transfers (Fortune+).
/stipend set, /stipend view, /stipend clear: Clan stipend config (Kami only).
pay_monthly_stipends(): Called by dm_new_day on IC month change.
"""

from __future__ import annotations

import discord
from discord import app_commands

import storage as _storage_mod
from l5r_rules.character import Character, format_purse


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

    givekoku.autocomplete("npc")(_d.npc_autocomplete)
    givebu.autocomplete("npc")(_d.npc_autocomplete)
    givezeni.autocomplete("npc")(_d.npc_autocomplete)


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


# ---------------------------------------------------------------------------
# Normalise purse: roll up excess zeni/bu into larger denominations
# ---------------------------------------------------------------------------

def _normalise_purse(c: Character) -> None:
    total = c.koku * 50 + c.bu * 10 + c.zeni
    if total < 0:
        total = 0
    c.koku = total // 50
    remainder = total % 50
    c.bu = remainder // 10
    c.zeni = remainder % 10


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
# Core give logic
# ---------------------------------------------------------------------------

async def _give(
    interaction: discord.Interaction,
    denomination: str,
    amount: int,
    member: discord.Member | None,
    npc: str | None,
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
    old_purse = format_purse(c)

    current = getattr(c, denomination)
    setattr(c, denomination, current + amount)
    _normalise_purse(c)

    changed = _d.store.save(rec)
    await _d.audit_stat(interaction, rec, f"give {denomination}", changed)

    verb = "Gave" if amount >= 0 else "Took"
    abs_amount = abs(amount)
    await interaction.response.send_message(
        f"{verb} **{abs_amount} {denomination}** {'to' if amount >= 0 else 'from'} "
        f"**{c.name}**.\n"
        f"Purse: {old_purse} → {format_purse(c)}",
        ephemeral=True,
    )


# ---------------------------------------------------------------------------
# Give commands
# ---------------------------------------------------------------------------

@app_commands.command(name="givekoku", description="Give or take koku (staff only)")
@app_commands.describe(
    amount="Amount of koku to give (negative to take)",
    member="Target player character",
    npc="Target NPC name",
)
async def givekoku(
    interaction: discord.Interaction,
    amount: int,
    member: discord.Member | None = None,
    npc: str | None = None,
) -> None:
    await _give(interaction, "koku", amount, member, npc)


@app_commands.command(name="givebu", description="Give or take bu (staff only)")
@app_commands.describe(
    amount="Amount of bu to give (negative to take)",
    member="Target player character",
    npc="Target NPC name",
)
async def givebu(
    interaction: discord.Interaction,
    amount: int,
    member: discord.Member | None = None,
    npc: str | None = None,
) -> None:
    await _give(interaction, "bu", amount, member, npc)


@app_commands.command(name="givezeni", description="Give or take zeni (staff only)")
@app_commands.describe(
    amount="Amount of zeni to give (negative to take)",
    member="Target player character",
    npc="Target NPC name",
)
async def givezeni(
    interaction: discord.Interaction,
    amount: int,
    member: discord.Member | None = None,
    npc: str | None = None,
) -> None:
    await _give(interaction, "zeni", amount, member, npc)


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
    clan: str,
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
    clan: str,
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
        clan = c.clan.strip().title()
        if clan not in stipends:
            continue
        koku, bu, zeni = stipends[clan]
        c.koku += koku
        c.bu += bu
        c.zeni += zeni
        _normalise_purse(c)
        _d.store.save(rec, note="monthly stipend")
        lines.append(f"**{c.name}** ({clan}): +{_format_amount(koku, bu, zeni)} → {format_purse(c)}")
    await _d.combat_log(guild_id, f"STIPEND: Monthly stipends paid to {len(lines)} character(s)")
    return lines
