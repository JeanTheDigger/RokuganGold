"""Rokugan L5R 4e Discord bot — entry point.

Phase 1: the bot comes online and exposes Roll & Keep as a slash command.
Later phases add character sheets, tables/rooms, combat, and NPC templates.

This file deliberately contains only the Discord plumbing. All game math lives
in `l5r_rules/` so the rules stay testable without Discord and portable if the
front-end ever changes.

Run locally:  see README.md (create a bot token, put it in .env, `python bot.py`)
"""

from __future__ import annotations

import logging
import os

import discord
from discord import app_commands

from l5r_rules.dice import DiceEngine, DiceResult

try:
    # Optional: load a local .env file during development. In production the
    # token is provided by the environment (e.g. systemd), so dotenv is optional.
    from dotenv import load_dotenv

    load_dotenv()
except ModuleNotFoundError:
    pass

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("rokugan-bot")

TOKEN = os.environ.get("DISCORD_BOT_TOKEN")
# Optional: set DISCORD_GUILD_ID to your server's ID during development so new
# slash commands appear instantly instead of after Discord's ~1h global sync.
GUILD_ID = os.environ.get("DISCORD_GUILD_ID")

# Slash commands need no privileged intents — default intents are enough. This
# keeps setup simple (no "Message Content Intent" approval needed from Discord).
intents = discord.Intents.default()

# One shared, real-randomness engine for the whole process.
engine = DiceEngine()


class RokuganBot(discord.Client):
    def __init__(self) -> None:
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self) -> None:
        # Register the slash commands with Discord.
        if GUILD_ID:
            guild = discord.Object(id=int(GUILD_ID))
            self.tree.copy_global_to(guild=guild)
            synced = await self.tree.sync(guild=guild)
            log.info("Synced %d commands to dev guild %s", len(synced), GUILD_ID)
        else:
            synced = await self.tree.sync()
            log.info("Synced %d global commands (may take up to ~1h to appear)", len(synced))

    async def on_ready(self) -> None:
        log.info("Logged in as %s (id=%s). Ready.", self.user, getattr(self.user, "id", "?"))


client = RokuganBot()


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------
def _format_dice(result: DiceResult) -> str:
    kept = ", ".join(str(d) for d in result.kept_dice) or "—"
    line = f"**Kept:** {kept}"
    if result.dropped_dice:
        line += f"   ·   *dropped: {', '.join(str(d) for d in result.dropped_dice)}*"
    extras = []
    if result.explosions:
        extras.append(f"💥 {result.explosions} explosion{'s' if result.explosions != 1 else ''}")
    if result.overflow_bonus:
        extras.append(f"+{result.overflow_bonus} overflow (10-dice cap)")
    if extras:
        line += "\n" + "   ·   ".join(extras)
    return line


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
@client.tree.command(name="ping", description="Check that the bot is alive.")
async def ping(interaction: discord.Interaction) -> None:
    latency_ms = round(client.latency * 1000)
    await interaction.response.send_message(f"🎋 Alive. Gateway latency {latency_ms} ms.", ephemeral=True)


@client.tree.command(
    name="roll",
    description="Roll & Keep (L5R 4e). Example: rolled=7 kept=3, optionally against a TN.",
)
@app_commands.describe(
    rolled="Number of dice to ROLL (the X in XkY).",
    kept="Number of dice to KEEP (the Y in XkY).",
    tn="Optional Target Number to test against.",
    raises="Called Raises — each adds +5 to the TN (default 0).",
    bonus="Flat modifier added to the total (default 0).",
    emphasis="Emphasis: reroll any initial 1 once (default off).",
    unskilled="Unskilled roll: dice do NOT explode (default off).",
    reason="Optional label shown with the roll (e.g. 'Kenjutsu attack').",
)
async def roll(
    interaction: discord.Interaction,
    rolled: app_commands.Range[int, 1, 100],
    kept: app_commands.Range[int, 1, 100],
    tn: app_commands.Range[int, 1, 200] | None = None,
    raises: app_commands.Range[int, 0, 10] = 0,
    bonus: app_commands.Range[int, -100, 100] = 0,
    emphasis: bool = False,
    unskilled: bool = False,
    reason: str | None = None,
) -> None:
    explodes = not unskilled

    title = "🎲 Roll & Keep"
    if reason:
        title += f" — {reason}"

    if tn is not None:
        outcome = engine.roll_check(rolled, kept, tn, raises, bonus, explodes, emphasis)
        result = outcome["dice"]
        success = outcome["success"]
        color = discord.Color.green() if success else discord.Color.red()
        embed = discord.Embed(title=title, color=color)
        embed.add_field(name="Request", value=f"`{rolled}k{kept}`" + (f" + {bonus}" if bonus else ""), inline=True)
        embed.add_field(
            name="Target",
            value=f"TN {tn}" + (f" + {raises}×5 = **{outcome['tn']}**" if raises else ""),
            inline=True,
        )
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        verdict = "✅ **Success**" if success else "❌ **Failure**"
        embed.add_field(
            name="Total",
            value=f"**{outcome['total']}** vs TN {outcome['tn']} — {verdict} (margin {outcome['margin']:+d})",
            inline=False,
        )
    else:
        result = engine.roll_and_keep(rolled, kept, explodes, emphasis)
        total = result.total + bonus
        embed = discord.Embed(title=title, color=discord.Color.blurple())
        embed.add_field(name="Request", value=f"`{rolled}k{kept}`" + (f" + {bonus}" if bonus else ""), inline=True)
        embed.add_field(name="Result", value=_format_dice(result), inline=False)
        total_str = f"**{total}**"
        if bonus:
            total_str += f"  (dice {result.total} {'+' if bonus >= 0 else '−'} {abs(bonus)})"
        embed.add_field(name="Total", value=total_str, inline=False)

    flags = []
    if emphasis:
        flags.append("Emphasis")
    if unskilled:
        flags.append("Unskilled (no explode)")
    if flags:
        embed.set_footer(text=" · ".join(flags))

    await interaction.response.send_message(embed=embed)


def main() -> None:
    if not TOKEN:
        raise SystemExit(
            "DISCORD_BOT_TOKEN is not set. Copy .env.example to .env and paste your "
            "bot token, or export DISCORD_BOT_TOKEN in the environment. See README.md."
        )
    client.run(TOKEN)


if __name__ == "__main__":
    main()
