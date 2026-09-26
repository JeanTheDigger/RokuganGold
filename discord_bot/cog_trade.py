"""Player-to-player money and item transfers.

/pay @member koku: bu: zeni:    -- transfer money from your purse to theirs.
/trade @member item: quantity:  -- give items from your inventory to theirs.
"""

from __future__ import annotations

import discord
from discord import app_commands

import storage as _storage_mod
from l5r_rules.character import format_purse, normalise_purse


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store: _storage_mod.Store
    require_guild: object
    combat_log: object

_d = _Deps()


def init(
    *,
    store: _storage_mod.Store,
    require_guild,
    combat_log,
) -> None:
    _d.store = store
    _d.require_guild = require_guild
    _d.combat_log = combat_log


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
# /pay -- player-to-player money transfer
# ---------------------------------------------------------------------------

@app_commands.command(name="pay", description="Give money from your character to another player's character.")
@app_commands.describe(
    member="The player to pay.",
    koku="Koku to give (0 if omitted).",
    bu="Bu to give (0 if omitted).",
    zeni="Zeni to give (0 if omitted).",
)
async def pay(
    interaction: discord.Interaction,
    member: discord.Member,
    koku: app_commands.Range[int, 0, 9999] = 0,
    bu: app_commands.Range[int, 0, 9999] = 0,
    zeni: app_commands.Range[int, 0, 9999] = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return

    if koku == 0 and bu == 0 and zeni == 0:
        await interaction.response.send_message(
            "Specify at least one denomination to pay.", ephemeral=True,
        )
        return

    if member.id == interaction.user.id:
        await interaction.response.send_message(
            "You cannot pay yourself.", ephemeral=True,
        )
        return

    guild = str(interaction.guild_id)
    sender_rec = _d.store.get_active(guild, str(interaction.user.id))
    if sender_rec is None:
        await interaction.response.send_message(
            "You have no active character. Use `/sheet create` first.", ephemeral=True,
        )
        return

    receiver_rec = _d.store.get_active(guild, str(member.id))
    if receiver_rec is None:
        await interaction.response.send_message(
            f"{member.display_name} has no active character.", ephemeral=True,
        )
        return

    sender = sender_rec.character
    receiver = receiver_rec.character

    transfer_zeni = koku * 50 + bu * 10 + zeni
    sender_total = sender.koku * 50 + sender.bu * 10 + sender.zeni
    if sender_total < transfer_zeni:
        await interaction.response.send_message(
            f"**{sender.name}** only has {format_purse(sender)}. "
            f"Cannot afford {_format_amount(koku, bu, zeni)}.",
            ephemeral=True,
        )
        return

    sender_old = format_purse(sender)
    receiver_old = format_purse(receiver)

    sender.koku -= koku
    sender.bu -= bu
    sender.zeni -= zeni
    normalise_purse(sender)

    receiver.koku += koku
    receiver.bu += bu
    receiver.zeni += zeni
    normalise_purse(receiver)

    _d.store.save(sender_rec, note=f"pay {_format_amount(koku, bu, zeni)} to {receiver.name}")
    _d.store.save(receiver_rec, note=f"received {_format_amount(koku, bu, zeni)} from {sender.name}")

    amount_str = _format_amount(koku, bu, zeni)
    await interaction.response.send_message(
        f"**{sender.name}** paid **{amount_str}** to **{receiver.name}**.\n"
        f"{sender.name}: {sender_old} → {format_purse(sender)}\n"
        f"{receiver.name}: {receiver_old} → {format_purse(receiver)}",
        ephemeral=True,
    )
    await _d.combat_log(
        guild,
        f"PAY: {sender.name} → {receiver.name}: {amount_str}",
    )


# ---------------------------------------------------------------------------
# /trade -- player-to-player item transfer
# ---------------------------------------------------------------------------

@app_commands.command(name="trade", description="Give an item from your inventory to another player's character.")
@app_commands.describe(
    member="The player to give the item to.",
    item="Item name (must be in your inventory).",
    quantity="How many to give (default 1).",
)
async def trade(
    interaction: discord.Interaction,
    member: discord.Member,
    item: app_commands.Range[str, 1, 80],
    quantity: app_commands.Range[int, 1, 9999] = 1,
) -> None:
    if not await _d.require_guild(interaction):
        return

    if member.id == interaction.user.id:
        await interaction.response.send_message(
            "You cannot trade with yourself.", ephemeral=True,
        )
        return

    guild = str(interaction.guild_id)
    sender_rec = _d.store.get_active(guild, str(interaction.user.id))
    if sender_rec is None:
        await interaction.response.send_message(
            "You have no active character. Use `/sheet create` first.", ephemeral=True,
        )
        return

    receiver_rec = _d.store.get_active(guild, str(member.id))
    if receiver_rec is None:
        await interaction.response.send_message(
            f"{member.display_name} has no active character.", ephemeral=True,
        )
        return

    sender = sender_rec.character
    receiver = receiver_rec.character

    match_key = next(
        (k for k in sender.inventory if k.lower() == item.lower()), None,
    )
    if match_key is None:
        await interaction.response.send_message(
            f"**{sender.name}** doesn't have **{item}** in their inventory.",
            ephemeral=True,
        )
        return

    held = sender.inventory[match_key]
    if held < quantity:
        await interaction.response.send_message(
            f"**{sender.name}** only has {held}× **{match_key}**.",
            ephemeral=True,
        )
        return

    remaining = held - quantity
    if remaining <= 0:
        del sender.inventory[match_key]
    else:
        sender.inventory[match_key] = remaining

    recv_key = next(
        (k for k in receiver.inventory if k.lower() == match_key.lower()),
        match_key,
    )
    receiver.inventory[recv_key] = receiver.inventory.get(recv_key, 0) + quantity

    _d.store.save(sender_rec, note=f"traded {quantity}x {match_key} to {receiver.name}")
    _d.store.save(receiver_rec, note=f"received {quantity}x {match_key} from {sender.name}")

    qty_str = f"{quantity}× " if quantity > 1 else ""
    sender_left = f" ({remaining} left)" if remaining > 0 else " (none left)"
    recv_total = receiver.inventory.get(recv_key, 0)
    recv_has = f" (now has {recv_total})"

    await interaction.response.send_message(
        f"**{sender.name}** gave {qty_str}**{match_key}** to **{receiver.name}**.\n"
        f"{sender.name}{sender_left} • {receiver.name}{recv_has}",
        ephemeral=True,
    )
    await _d.combat_log(
        guild,
        f"TRADE: {sender.name} → {receiver.name}: {qty_str}{match_key}",
    )


# ---------------------------------------------------------------------------
# Autocomplete for /trade item parameter
# ---------------------------------------------------------------------------

async def _inventory_autocomplete(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    guild = str(interaction.guild_id) if interaction.guild_id else ""
    rec = _d.store.get_active(guild, str(interaction.user.id))
    if rec is None:
        return []
    inv = rec.character.inventory
    choices: list[app_commands.Choice[str]] = []
    for name, qty in sorted(inv.items()):
        if current.lower() not in name.lower():
            continue
        label = f"{name} ({qty})"[:100]
        choices.append(app_commands.Choice(name=label, value=name[:100]))
        if len(choices) >= 25:
            break
    return choices
