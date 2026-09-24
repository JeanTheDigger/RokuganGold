"""Staff-only additive money commands: /givekoku, /givebu, /givezeni.

Each command adds (or removes, if negative) an amount of the specified
denomination from a target character's purse.  Works on PCs (member:) and
NPCs (npc:).  Normalizes the purse after every change.
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
    require_guild: object
    require_dm_role: object
    resolve_active: object
    audit_stat: object
    npc_autocomplete: object

_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    npc_owner: str,
    require_guild,
    require_dm_role,
    resolve_active,
    audit_stat,
    npc_autocomplete,
) -> None:
    _d.store = store
    _d.NPC_OWNER = npc_owner
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.resolve_active = resolve_active
    _d.audit_stat = audit_stat
    _d.npc_autocomplete = npc_autocomplete

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
# Commands
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
