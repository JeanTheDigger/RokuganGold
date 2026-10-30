"""Finding the bot's roles by name and checking who holds them."""

from __future__ import annotations

import discord

import layout


def find_role(guild: discord.Guild, name: str) -> discord.Role | None:
    """A role by name, ignoring case."""
    wanted = name.strip().casefold()
    return next((r for r in guild.roles if r.name.strip().casefold() == wanted), None)


def has_role(member: discord.Member, name: str) -> bool:
    wanted = name.strip().casefold()
    return any(r.name.strip().casefold() == wanted for r in member.roles)


def is_head_admin(member: discord.Member) -> bool:
    return has_role(member, layout.HEAD_ADMIN_ROLE)


def legion_role_name(legion_name: str) -> str:
    return f"{layout.LEGION_ROLE_PREFIX}{legion_name}"


def bot_overwrite() -> discord.PermissionOverwrite:
    """What the bot itself needs in every channel it creates."""
    return discord.PermissionOverwrite(
        view_channel=True, send_messages=True, manage_channels=True, manage_messages=True,
        read_message_history=True, embed_links=True, attach_files=True, connect=True,
    )
