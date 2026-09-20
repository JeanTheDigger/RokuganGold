"""Rumor Board: Targeted and public in-world information delivery.

DMs post rumors that reach specific characters based on clan, family,
school, school_type, or direct name targeting.  Public rumors go to a
designated notice board channel visible to everyone.
"""

from __future__ import annotations

import discord
from discord import app_commands

# ---------------------------------------------------------------------------
# Dependency injection (same pattern as cog_checks / cog_combat / etc.)
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


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

TIER_OFFICIAL = "official"
TIER_HEARSAY = "hearsay"
TIER_WHISPER = "whisper"

TIER_LABELS = {
    TIER_OFFICIAL: "Official",
    TIER_HEARSAY: "Hearsay",
    TIER_WHISPER: "Whisper",
}

TIER_COLORS = {
    TIER_OFFICIAL: discord.Color.gold(),
    TIER_HEARSAY: discord.Color.dark_gold(),
    TIER_WHISPER: discord.Color.dark_purple(),
}

TIER_ICONS = {
    TIER_OFFICIAL: "\U0001f4dc",   # scroll
    TIER_HEARSAY: "\U0001f5e3️",  # speaking head
    TIER_WHISPER: "\U0001f90b",    # ear (whisper)
}

FILTER_TYPES = ("clan", "family", "school", "school_type", "character")


# ---------------------------------------------------------------------------
# Command group
# ---------------------------------------------------------------------------

rumor = app_commands.Group(
    name="rumor", description="Post and manage in-world rumors and notices."
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_rumor_embed(
    title: str, content: str, tier: str, author_name: str, rumor_id: int | None = None,
) -> discord.Embed:
    icon = TIER_ICONS.get(tier, "")
    label = TIER_LABELS.get(tier, tier.title())
    color = TIER_COLORS.get(tier, discord.Color.dark_gold())
    embed = discord.Embed(
        title=f"{icon} {title}",
        description=content[:4000],
        color=color,
    )
    footer_parts = [f"{label}"]
    if rumor_id is not None:
        footer_parts.append(f"ID: {rumor_id}")
    footer_parts.append(f"Posted by {author_name}")
    embed.set_footer(text=" • ".join(footer_parts))
    return embed


def _match_character(char, filters: list[tuple[str, str]]) -> bool:
    """Return True if the character matches ANY of the given (type, value) filters (OR logic)."""
    for ftype, fvalue in filters:
        fval_lower = fvalue.lower()
        if ftype == "clan" and char.clan.lower() == fval_lower:
            return True
        if ftype == "family" and char.family.lower() == fval_lower:
            return True
        if ftype == "school" and char.school.lower() == fval_lower:
            return True
        if ftype == "school_type" and char.school_type.lower() == fval_lower:
            return True
        if ftype == "character" and char.name.lower() == fval_lower:
            return True
    return False


async def _find_support_channel(
    guild: discord.Guild, character_name: str,
) -> discord.TextChannel | None:
    """Find a character's private support channel in the Player Support category."""
    cat = discord.utils.get(guild.categories, name=_d.cat_player_support)
    if cat is None:
        return None
    slug = character_name.lower().replace(" ", "-")
    return discord.utils.get(cat.text_channels, name=slug)


# ---------------------------------------------------------------------------
# /rumor post - send a targeted rumor to matching characters
# ---------------------------------------------------------------------------

@rumor.command(
    name="post",
    description="Post a rumor to characters matching clan/family/school/name filters. [Fortune]",
)
@app_commands.describe(
    title="Short title for the rumor.",
    content="The rumor text.",
    tier="Reliability tier: Official, Hearsay, or Whisper.",
    clan="Target characters of this clan (OR with other filters).",
    family="Target characters of this family (OR with other filters).",
    school="Target characters of this school (OR with other filters).",
    school_type="Target characters of this school type: Bushi, Shugenja, Courtier, Monk, Ninja (OR).",
    character="Target a specific character by name (OR with other filters).",
)
@app_commands.choices(tier=[
    app_commands.Choice(name="Official (verified)", value=TIER_OFFICIAL),
    app_commands.Choice(name="Hearsay (common talk)", value=TIER_HEARSAY),
    app_commands.Choice(name="Whisper (unreliable/secret)", value=TIER_WHISPER),
])
async def rumor_post(
    interaction: discord.Interaction,
    title: str,
    content: str,
    tier: app_commands.Choice[str],
    clan: str | None = None,
    family: str | None = None,
    school: str | None = None,
    school_type: str | None = None,
    character: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    filters: list[tuple[str, str]] = []
    if clan:
        filters.append(("clan", clan.strip()))
    if family:
        filters.append(("family", family.strip()))
    if school:
        filters.append(("school", school.strip()))
    if school_type:
        filters.append(("school_type", school_type.strip()))
    if character:
        filters.append(("character", character.strip()))

    if not filters:
        await interaction.response.send_message(
            "Provide at least one filter: `clan`, `family`, `school`, `school_type`, or `character`.",
            ephemeral=True,
        )
        return

    await interaction.response.defer(ephemeral=True)

    guild_id = str(interaction.guild_id)
    guild = interaction.guild
    tier_val = tier.value

    rumor_id = _d.store.create_rumor(
        guild_id, title, content, tier_val,
        [(f, v) for f, v in filters],
        str(interaction.user.id), public=False,
    )

    embed = _build_rumor_embed(title, content, tier_val, interaction.user.display_name, rumor_id)

    filter_desc = ", ".join(f"{f}: {v}" for f, v in filters)
    embed.add_field(name="Targeting", value=filter_desc, inline=False)

    active_pcs = _d.store.list_active_pcs(guild_id)
    delivered = 0
    failed: list[str] = []

    for _owner_id, rec in active_pcs:
        if not _match_character(rec.character, filters):
            continue
        ch = await _find_support_channel(guild, rec.character.name)
        if ch is None:
            failed.append(rec.character.name)
            continue
        player_embed = _build_rumor_embed(title, content, tier_val, interaction.user.display_name, rumor_id)
        try:
            await ch.send(embed=player_embed)
            delivered += 1
        except discord.Forbidden:
            failed.append(rec.character.name)

    summary = f"Rumor **#{rumor_id}** delivered to **{delivered}** character(s)."
    if failed:
        summary += f"\nCould not deliver to: {', '.join(failed)} (no support channel found or missing permissions)."

    await interaction.followup.send(summary, ephemeral=True)


# ---------------------------------------------------------------------------
# /rumor public - post a public notice to the board channel
# ---------------------------------------------------------------------------

@rumor.command(
    name="public",
    description="Post a public notice to the notice board channel. [Fortune]",
)
@app_commands.describe(
    title="Short title for the notice.",
    content="The notice text.",
    tier="Reliability tier: Official, Hearsay, or Whisper.",
)
@app_commands.choices(tier=[
    app_commands.Choice(name="Official (verified)", value=TIER_OFFICIAL),
    app_commands.Choice(name="Hearsay (common talk)", value=TIER_HEARSAY),
    app_commands.Choice(name="Whisper (unreliable/secret)", value=TIER_WHISPER),
])
async def rumor_public(
    interaction: discord.Interaction,
    title: str,
    content: str,
    tier: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    guild = interaction.guild
    tier_val = tier.value

    board_ch_id = _d.store.get_rumor_board_channel(guild_id)
    if board_ch_id is None:
        await interaction.response.send_message(
            "No public notice board channel set. Run `/setup server` or use `/rumor channel` to set one.",
            ephemeral=True,
        )
        return

    board_ch = guild.get_channel(int(board_ch_id))
    if board_ch is None:
        await interaction.response.send_message(
            "The configured notice board channel no longer exists. Use `/rumor channel` to set a new one.",
            ephemeral=True,
        )
        return

    rumor_id = _d.store.create_rumor(
        guild_id, title, content, tier_val,
        [], str(interaction.user.id), public=True,
    )

    embed = _build_rumor_embed(title, content, tier_val, interaction.user.display_name, rumor_id)

    try:
        await board_ch.send(embed=embed)
    except discord.Forbidden:
        await interaction.response.send_message(
            f"Cannot send to {board_ch.mention}: Missing permissions.", ephemeral=True,
        )
        return

    await interaction.response.send_message(
        f"Public notice **#{rumor_id}** posted to {board_ch.mention}.",
        ephemeral=True,
    )


# ---------------------------------------------------------------------------
# /rumor broadcast - post a rumor both publicly AND to matching characters
# ---------------------------------------------------------------------------

@rumor.command(
    name="broadcast",
    description="Post a rumor publicly AND deliver to matching characters. [Fortune]",
)
@app_commands.describe(
    title="Short title for the rumor.",
    content="The rumor text.",
    tier="Reliability tier.",
    clan="Target characters of this clan (OR with other filters).",
    family="Target characters of this family (OR with other filters).",
    school="Target characters of this school (OR with other filters).",
    school_type="Target school type: Bushi, Shugenja, Courtier, Monk, Ninja (OR).",
    character="Target a specific character by name (OR with other filters).",
)
@app_commands.choices(tier=[
    app_commands.Choice(name="Official (verified)", value=TIER_OFFICIAL),
    app_commands.Choice(name="Hearsay (common talk)", value=TIER_HEARSAY),
    app_commands.Choice(name="Whisper (unreliable/secret)", value=TIER_WHISPER),
])
async def rumor_broadcast(
    interaction: discord.Interaction,
    title: str,
    content: str,
    tier: app_commands.Choice[str],
    clan: str | None = None,
    family: str | None = None,
    school: str | None = None,
    school_type: str | None = None,
    character: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    guild = interaction.guild
    tier_val = tier.value

    filters: list[tuple[str, str]] = []
    if clan:
        filters.append(("clan", clan.strip()))
    if family:
        filters.append(("family", family.strip()))
    if school:
        filters.append(("school", school.strip()))
    if school_type:
        filters.append(("school_type", school_type.strip()))
    if character:
        filters.append(("character", character.strip()))

    board_ch_id = _d.store.get_rumor_board_channel(guild_id)
    board_ch = guild.get_channel(int(board_ch_id)) if board_ch_id else None

    await interaction.response.defer(ephemeral=True)

    rumor_id = _d.store.create_rumor(
        guild_id, title, content, tier_val,
        filters, str(interaction.user.id), public=True,
    )

    embed = _build_rumor_embed(title, content, tier_val, interaction.user.display_name, rumor_id)
    parts: list[str] = []

    if board_ch:
        try:
            await board_ch.send(embed=embed)
            parts.append(f"Posted to {board_ch.mention}")
        except discord.Forbidden:
            parts.append(f"Could not post to {board_ch.mention} (permissions)")
    else:
        parts.append("No public board channel configured (skipped)")

    if filters:
        active_pcs = _d.store.list_active_pcs(guild_id)
        delivered = 0
        failed: list[str] = []
        for _owner_id, rec in active_pcs:
            if not _match_character(rec.character, filters):
                continue
            ch = await _find_support_channel(guild, rec.character.name)
            if ch is None:
                failed.append(rec.character.name)
                continue
            player_embed = _build_rumor_embed(
                title, content, tier_val, interaction.user.display_name, rumor_id,
            )
            try:
                await ch.send(embed=player_embed)
                delivered += 1
            except discord.Forbidden:
                failed.append(rec.character.name)
        parts.append(f"Delivered to **{delivered}** character(s)")
        if failed:
            parts.append(f"Failed: {', '.join(failed)}")

    await interaction.followup.send(
        f"Rumor **#{rumor_id}**: " + " | ".join(parts), ephemeral=True,
    )


# ---------------------------------------------------------------------------
# /rumor list - show recent rumors (DM sees all, players see their own)
# ---------------------------------------------------------------------------

@rumor.command(name="list", description="List recent rumors. Players see their own; staff sees all.")
@app_commands.describe(count="How many to show (default 10, max 25).")
async def rumor_list(
    interaction: discord.Interaction,
    count: app_commands.Range[int, 1, 25] = 10,
) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    dm = _d.is_dm(interaction)

    if dm:
        rumors = _d.store.list_rumors(guild_id, limit=count)
    else:
        rec = _d.store.get_active(guild_id, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message(
                "You have no active character. Use `/sheet create` first.", ephemeral=True,
            )
            return
        rumors = _d.store.list_rumors_for_character(guild_id, rec.character, limit=count)

    if not rumors:
        await interaction.response.send_message("No rumors found.", ephemeral=True)
        return

    lines: list[str] = []
    for r in rumors:
        icon = TIER_ICONS.get(r["tier"], "")
        pub = " \U0001f4e2" if r["public"] else ""
        targets = r.get("targets", "")
        target_str = f" [{targets}]" if targets and dm else ""
        lines.append(f"{icon} **#{r['id']}** {r['title']}{pub}{target_str}")

    body = "\n".join(lines)
    label = "All Rumors" if dm else "Your Rumors"
    embed = discord.Embed(
        title=f"\U0001f4dc {label} ({len(rumors)})",
        description=body[:4000],
        color=discord.Color.dark_gold(),
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /rumor view - view a specific rumor by ID
# ---------------------------------------------------------------------------

@rumor.command(name="view", description="View a specific rumor by ID.")
@app_commands.describe(rumor_id="The rumor ID number.")
async def rumor_view(
    interaction: discord.Interaction,
    rumor_id: int,
) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    r = _d.store.get_rumor(guild_id, rumor_id)
    if r is None:
        await interaction.response.send_message(f"Rumor **#{rumor_id}** not found.", ephemeral=True)
        return

    dm = _d.is_dm(interaction)
    if not dm and not r["public"]:
        rec = _d.store.get_active(guild_id, str(interaction.user.id))
        if rec is None:
            await interaction.response.send_message("No active character.", ephemeral=True)
            return
        filters = _d.store.get_rumor_filters(guild_id, rumor_id)
        if not _match_character(rec.character, filters):
            await interaction.response.send_message(f"Rumor **#{rumor_id}** not found.", ephemeral=True)
            return

    embed = _build_rumor_embed(r["title"], r["content"], r["tier"], "Staff", rumor_id)
    if dm:
        targets = r.get("targets", "")
        if targets:
            embed.add_field(name="Targeting", value=targets, inline=False)
        pub_label = "Public" if r["public"] else "Targeted"
        embed.add_field(name="Type", value=pub_label, inline=True)

    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /rumor delete - remove a rumor from the database
# ---------------------------------------------------------------------------

@rumor.command(name="delete", description="Delete a rumor by ID. [Fortune]")
@app_commands.describe(rumor_id="The rumor ID to delete.")
async def rumor_delete(
    interaction: discord.Interaction,
    rumor_id: int,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    r = _d.store.get_rumor(guild_id, rumor_id)
    if r is None:
        await interaction.response.send_message(f"Rumor **#{rumor_id}** not found.", ephemeral=True)
        return

    _d.store.delete_rumor(guild_id, rumor_id)
    await interaction.response.send_message(
        f"Deleted rumor **#{rumor_id}**: {r['title']}",
        ephemeral=True,
    )


# ---------------------------------------------------------------------------
# /rumor channel - set the public notice board channel
# ---------------------------------------------------------------------------

@rumor.command(
    name="channel",
    description="Set which channel receives public notices. [Kami]",
)
@app_commands.describe(channel="The channel to use as the public notice board.")
async def rumor_channel(
    interaction: discord.Interaction,
    channel: discord.TextChannel,
) -> None:
    if not await _d.require_guild(interaction):
        return
    kami_role = discord.utils.get(interaction.guild.roles, name=_d.role_kami)
    if kami_role is None or kami_role not in interaction.user.roles:
        await interaction.response.send_message(
            f"Only **{_d.role_kami}** can set the notice board channel.", ephemeral=True,
        )
        return

    _d.store.set_rumor_board_channel(str(interaction.guild_id), str(channel.id))
    embed = discord.Embed(
        title="\U0001f4dc Notice Board Configured",
        description=f"Public rumors will now post to {channel.mention}.",
        color=discord.Color.dark_gold(),
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
