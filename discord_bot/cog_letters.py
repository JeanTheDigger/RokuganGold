"""IC Letters: In-character correspondence between player characters.

Players send sealed letters to other PCs, delivered to the recipient's
Player Support channel.  Staff can send letters as any character or NPC,
and can read a log of all letters sent in the guild.
"""

from __future__ import annotations

import discord
from discord import app_commands
from helpers import find_support_channel
from l5r_rules import stats


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store = None
    bot_client: discord.Client = None
    require_guild = None
    require_dm_role = None
    is_dm = None
    npc_owner: str = "npc"
    role_fortune: str = "Fortune"
    role_kami: str = "Kami"
    cat_player_support: str = "Player Support"
    pc_autocomplete = None

_d = _Deps()


def init(
    *,
    store,
    bot_client: discord.Client,
    require_guild,
    require_dm_role,
    is_dm,
    npc_owner: str,
    role_fortune: str,
    role_kami: str,
    cat_player_support: str,
    pc_autocomplete,
) -> None:
    _d.store = store
    _d.bot_client = bot_client
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.is_dm = is_dm
    _d.npc_owner = npc_owner
    _d.role_fortune = role_fortune
    _d.role_kami = role_kami
    _d.cat_player_support = cat_player_support
    _d.pc_autocomplete = pc_autocomplete


# ---------------------------------------------------------------------------
# Command group
# ---------------------------------------------------------------------------

letter = app_commands.Group(
    name="letter", description="Send and manage in-character letters."
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_letter_embed(
    sender_name: str, content: str, sealed: bool = True,
) -> discord.Embed:
    embed = discord.Embed(
        title=f"Letter from {sender_name}",
        description=(content or "")[:4000],
        color=discord.Color.from_rgb(210, 180, 120),
    )
    if sealed:
        embed.set_footer(text="This letter was sealed and delivered privately.")
    return embed



def _pc_names(guild_id: str) -> list[str]:
    return [rec.character.name for _, rec in _d.store.list_active_pcs(guild_id)]


def _all_character_names(guild_id: str) -> list[str]:
    names = _pc_names(guild_id)
    for rec in _d.store.list_by_owner(guild_id, _d.npc_owner):
        names.append(rec.character.name)
    return names


def _is_npc(guild_id: str, name: str) -> bool:
    rec = _d.store.get_by_name(guild_id, _d.npc_owner, name)
    return rec is not None


# ---------------------------------------------------------------------------
# /letter send - player sends a letter to another PC
# ---------------------------------------------------------------------------

@letter.command(
    name="send",
    description="Send an in-character letter to another character (PC or NPC).",
)
@app_commands.describe(
    recipient="The character to send the letter to (PC or NPC).",
    message="The content of your letter (in character).",
)
async def letter_send(
    interaction: discord.Interaction,
    recipient: app_commands.Range[str, 1, 80],
    message: app_commands.Range[str, 1, 1500],
) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    guild = interaction.guild

    sender_rec = _d.store.get_active(guild_id, str(interaction.user.id))
    if sender_rec is None:
        await interaction.response.send_message(
            "You have no active character. Use `/sheet create` first.", ephemeral=True,
        )
        return
    if stats.is_dead(sender_rec.character):
        await interaction.response.send_message(
            f"**{sender_rec.character.name}** is dead. PC death is permanent.", ephemeral=True,
        )
        return

    all_names = _all_character_names(guild_id)
    matched = None
    for name in all_names:
        if name.lower() == recipient.lower():
            matched = name
            break
    if matched is None:
        await interaction.response.send_message(
            f"No active character named **{recipient}** found.", ephemeral=True,
        )
        return

    if matched.lower() == sender_rec.character.name.lower():
        await interaction.response.send_message(
            "You cannot send a letter to yourself.", ephemeral=True,
        )
        return

    npc_recipient = _is_npc(guild_id, matched)

    if npc_recipient:
        ch = await _get_staff_log_channel(guild)
        if ch is None:
            await interaction.response.send_message(
                f"**{matched}** is an NPC. No staff channel found to deliver the letter.",
                ephemeral=True,
            )
            return
    else:
        ch = await find_support_channel(guild, matched, _d.cat_player_support)
        if ch is None:
            await interaction.response.send_message(
                f"Could not find a support channel for **{matched}**.", ephemeral=True,
            )
            return

    await interaction.response.defer(ephemeral=True)

    sender_name = sender_rec.character.name
    embed = _build_letter_embed(sender_name, message)

    letter_id = _d.store.create_letter(
        guild_id, sender_name, matched, message, str(interaction.user.id),
    )
    embed.set_footer(text=f"Letter #{letter_id} • Sealed and delivered privately.")

    try:
        await ch.send(embed=embed)
    except discord.Forbidden:
        await interaction.followup.send(
            f"Cannot send to {matched}'s channel: Missing permissions.", ephemeral=True,
        )
        return

    confirm = discord.Embed(
        title="Letter Sent",
        description=f"Your letter to **{matched}** has been delivered.",
        color=discord.Color.green(),
    )
    confirm.set_footer(text=f"Letter #{letter_id} • Sent by {interaction.user.display_name}")
    await interaction.followup.send(embed=confirm, ephemeral=True)

    if not npc_recipient:
        staff_ch = await _get_staff_log_channel(guild)
        if staff_ch:
            log_embed = discord.Embed(
                title=f"Letter: {sender_name} to {matched}",
                description=message[:4000],
                color=discord.Color.dark_gold(),
            )
            log_embed.set_footer(text=f"Letter #{letter_id} • Player: {interaction.user.display_name}")
            try:
                await staff_ch.send(embed=log_embed)
            except discord.Forbidden:
                pass


@letter_send.autocomplete("recipient")
async def _send_recipient_ac(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    guild_id = str(interaction.guild_id)
    cur = current.lower().strip()
    pool = _all_character_names(guild_id) if _d.is_dm(interaction) else _pc_names(guild_id)
    names = [n for n in pool if cur in n.lower()]
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]


# ---------------------------------------------------------------------------
# /letter sendas - staff sends a letter as any character
# ---------------------------------------------------------------------------

@letter.command(
    name="sendas",
    description="Send a letter as any character or NPC (signed with their name). [Fortune]",
)
@app_commands.describe(
    sender_name="The name to sign the letter as (any character or NPC).",
    recipient="The character to deliver the letter to.",
    message="The content of the letter.",
)
async def letter_sendas(
    interaction: discord.Interaction,
    sender_name: app_commands.Range[str, 1, 80],
    recipient: app_commands.Range[str, 1, 80],
    message: app_commands.Range[str, 1, 1500],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    guild = interaction.guild

    all_names = _all_character_names(guild_id)
    matched = None
    for name in all_names:
        if name.lower() == recipient.lower():
            matched = name
            break
    if matched is None:
        await interaction.response.send_message(
            f"No active character named **{recipient}** found.", ephemeral=True,
        )
        return

    npc_recipient = _is_npc(guild_id, matched)

    if npc_recipient:
        ch = await _get_staff_log_channel(guild)
        if ch is None:
            await interaction.response.send_message(
                f"**{matched}** is an NPC. No staff channel found to deliver the letter.",
                ephemeral=True,
            )
            return
    else:
        ch = await find_support_channel(guild, matched, _d.cat_player_support)
        if ch is None:
            await interaction.response.send_message(
                f"Could not find a support channel for **{matched}**.", ephemeral=True,
            )
            return

    await interaction.response.defer(ephemeral=True)

    letter_id = _d.store.create_letter(
        guild_id, sender_name.strip(), matched, message, str(interaction.user.id),
    )

    embed = _build_letter_embed(sender_name.strip(), message)
    embed.set_footer(text=f"Letter #{letter_id} • Sealed and delivered privately.")

    try:
        await ch.send(embed=embed)
    except discord.Forbidden:
        await interaction.followup.send(
            f"Cannot send to {matched}'s channel: Missing permissions.", ephemeral=True,
        )
        return

    confirm = discord.Embed(
        title="Letter Sent (as Staff)",
        description=f"Letter from **{sender_name.strip()}** delivered to **{matched}**.",
        color=discord.Color.green(),
    )
    confirm.set_footer(text=f"Letter #{letter_id} • Authorized by {interaction.user.display_name}")
    await interaction.followup.send(embed=confirm, ephemeral=True)


@letter_sendas.autocomplete("recipient")
async def _sendas_recipient_ac(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    guild_id = str(interaction.guild_id)
    cur = current.lower().strip()
    names = [n for n in _all_character_names(guild_id) if cur in n.lower()]
    return [app_commands.Choice(name=n, value=n) for n in sorted(names)[:25]]


@letter_sendas.autocomplete("sender_name")
async def _sendas_sender_ac(
    interaction: discord.Interaction, current: str,
) -> list[app_commands.Choice[str]]:
    return await _d.pc_autocomplete(interaction, current)


# ---------------------------------------------------------------------------
# /letter list - view sent/received letter history
# ---------------------------------------------------------------------------

@letter.command(
    name="list",
    description="View your letter history. Staff sees all letters.",
)
@app_commands.describe(count="How many to show (default 10, max 25).")
async def letter_list(
    interaction: discord.Interaction,
    count: app_commands.Range[int, 1, 25] = 10,
) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    dm = _d.is_dm(interaction)

    if dm:
        letters = _d.store.list_letters(guild_id, limit=count)
        label = "All Letters"
    else:
        rec = _d.store.get_active(guild_id, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message(
                "You have no active character.", ephemeral=True,
            )
            return
        letters = _d.store.list_letters_for_character(
            guild_id, rec.character.name, limit=count,
        )
        label = "Your Letters"

    if not letters:
        await interaction.response.send_message("No letters found.", ephemeral=True)
        return

    lines: list[str] = []
    for lt in letters:
        lines.append(
            f"**#{lt['id']}** {lt['sender']} → {lt['recipient']} "
            f"- {lt['preview']}"
        )

    embed = discord.Embed(
        title=f"{label} ({len(letters)})",
        description="\n".join(lines)[:4000],
        color=discord.Color.from_rgb(210, 180, 120),
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /letter read - view a specific letter by ID
# ---------------------------------------------------------------------------

@letter.command(name="read", description="Read a specific letter by ID.")
@app_commands.describe(letter_id="The letter ID number.")
async def letter_read(
    interaction: discord.Interaction,
    letter_id: int,
) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    lt = _d.store.get_letter(guild_id, letter_id)
    if lt is None:
        await interaction.response.send_message(
            f"Letter **#{letter_id}** not found.", ephemeral=True,
        )
        return

    dm = _d.is_dm(interaction)
    if not dm:
        rec = _d.store.get_active(guild_id, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("No active character.", ephemeral=True)
            return
        char_name = rec.character.name.lower()
        if lt["sender"].lower() != char_name and lt["recipient"].lower() != char_name:
            await interaction.response.send_message(
                f"Letter **#{letter_id}** not found.", ephemeral=True,
            )
            return

    embed = _build_letter_embed(lt["sender"], lt["content"])
    embed.set_footer(text=f"Letter #{letter_id} • To: {lt['recipient']}")
    if dm:
        embed.add_field(name="From", value=lt["sender"], inline=True)
        embed.add_field(name="To", value=lt["recipient"], inline=True)

    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /letter delete - staff removes a letter from the log
# ---------------------------------------------------------------------------

@letter.command(name="delete", description="Delete a letter from the log. [Fortune]")
@app_commands.describe(letter_id="The letter ID to delete.")
async def letter_delete(
    interaction: discord.Interaction,
    letter_id: int,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    lt = _d.store.get_letter(guild_id, letter_id)
    if lt is None:
        await interaction.response.send_message(
            f"Letter **#{letter_id}** not found.", ephemeral=True,
        )
        return

    _d.store.delete_letter(guild_id, letter_id)
    await interaction.response.send_message(
        f"Deleted letter **#{letter_id}**: {lt['sender']} to {lt['recipient']}",
        ephemeral=True,
    )


# ---------------------------------------------------------------------------
# Staff log channel helper
# ---------------------------------------------------------------------------

async def _get_staff_log_channel(guild: discord.Guild) -> discord.TextChannel | None:
    cat = discord.utils.get(guild.categories, name="Staff Members")
    if cat is None:
        return None
    return discord.utils.get(cat.text_channels, name="dm-discussion")
