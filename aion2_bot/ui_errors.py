"""Turning a failed button, menu or form into a message for the person who used it.

Without this, an error inside a button handler (most often Discord refusing an
action because of the bot's role position or permissions) is only logged: the
person sees "This interaction failed", or a "Working…" message that never moves.
"""

from __future__ import annotations

import logging
from typing import Any

import discord

log = logging.getLogger("aion2_bot.ui")


async def report(interaction: discord.Interaction, error: Exception) -> None:
    log.exception("Interaction failed", exc_info=error)
    if isinstance(error, discord.HTTPException):
        text = (f"Discord refused part of that: `{error}`. Anything done before that point was kept. "
                "Ask the Head Admin to check the bot's permissions, and that its role is above the roles "
                "it hands out, then try again.")
    else:
        text = "Something went wrong; the error has been logged. Please try again."
    try:
        if interaction.response.is_done():
            await interaction.followup.send(text, ephemeral=True)
        else:
            await interaction.response.send_message(text, ephemeral=True)
    except discord.HTTPException:
        pass


class SafeView(discord.ui.View):
    """A View whose button/menu errors are reported to the person who clicked."""

    async def on_error(self, interaction: discord.Interaction, error: Exception, item: Any, /) -> None:
        await report(interaction, error)
