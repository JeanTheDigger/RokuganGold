"""Shared helpers used by multiple cog modules.

Kept deliberately small: only functions that were duplicated across two
or more files belong here.
"""

from __future__ import annotations

import discord


def match_character(char, filters: list[tuple[str, str]]) -> bool:
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


async def find_support_channel(
    guild: discord.Guild, character_name: str, category_name: str,
) -> discord.TextChannel | None:
    """Find a character's private support channel in the given category."""
    cat = discord.utils.get(guild.categories, name=category_name)
    if cat is None:
        return None
    slug = character_name.lower().replace(" ", "-")
    return discord.utils.get(cat.text_channels, name=slug)
