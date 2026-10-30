"""Aion 2 faction Discord bot: entry point.

Run:  python bot.py   (reads DISCORD_BOT_TOKEN from .env; see README.md)
"""

from __future__ import annotations

import logging
import os
import sys

import discord
from discord import app_commands

import applications
import layout
import setup_server
from storage import Store

try:
    from dotenv import load_dotenv
except ImportError:  # python-dotenv is optional if the env vars are set another way
    pass
else:
    load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("aion2_bot")

TOKEN = os.environ.get("DISCORD_BOT_TOKEN", "").strip()
GUILD_ID = os.environ.get("DISCORD_GUILD_ID", "").strip()
DB_PATH = os.environ.get("AION2_DB", "").strip() or os.path.join(os.path.dirname(os.path.abspath(__file__)), "aion2.db")


class Aion2Bot(discord.Client):
    def __init__(self) -> None:
        intents = discord.Intents.default()
        # Privileged: needed to see members join. Turn on "Server Members Intent"
        # in the Developer Portal (Bot page), or the bot will refuse to start.
        intents.members = True
        super().__init__(intents=intents)
        self.store = Store(DB_PATH)
        self.tree = app_commands.CommandTree(self)
        self.tree.on_error = self.on_app_command_error
        self.tree.add_command(setup_server.setup_group)
        self.tree.add_command(applications.legion_group)

    async def setup_hook(self) -> None:
        # Buttons that must keep working after a restart.
        self.add_view(applications.CommanderPanel())
        self.add_view(applications.MemberPanel())
        self.add_dynamic_items(applications.TicketButton)
        # With DISCORD_GUILD_ID set, commands go to that one server and appear
        # instantly (for development). Without it they sync globally, which can
        # take up to an hour to show up the first time.
        if GUILD_ID:
            guild = discord.Object(id=int(GUILD_ID))
            self.tree.copy_global_to(guild=guild)
            synced = await self.tree.sync(guild=guild)
            log.info("Synced %d command(s) to guild %s", len(synced), GUILD_ID)
        else:
            synced = await self.tree.sync()
            log.info("Synced %d command(s) globally", len(synced))

    async def on_ready(self) -> None:
        log.info("Logged in as %s (id %s) in %d server(s)", self.user, self.user.id if self.user else "?", len(self.guilds))

    async def on_member_join(self, member: discord.Member) -> None:
        """A plain "<member> entered the server." line in the arrivals room."""
        channel = applications.configured(member.guild, self.store, layout.ARRIVALS, discord.TextChannel)
        if isinstance(channel, discord.TextChannel):
            try:
                await channel.send(
                    f"{member.mention} entered the server.",
                    allowed_mentions=discord.AllowedMentions.none(),
                )
            except discord.HTTPException:
                log.warning("Could not post arrival of %s in %s", member.id, member.guild.id)

    async def on_app_command_error(
        self, interaction: discord.Interaction, error: app_commands.AppCommandError
    ) -> None:
        log.exception("Command error", exc_info=error)
        message = "Something went wrong running that command. The error has been logged."
        try:
            if interaction.response.is_done():
                await interaction.followup.send(message, ephemeral=True)
            else:
                await interaction.response.send_message(message, ephemeral=True)
        except discord.HTTPException:
            pass


def main() -> None:
    if not TOKEN:
        sys.exit("DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and fill it in.")
    Aion2Bot().run(TOKEN, log_handler=None)


if __name__ == "__main__":
    main()
