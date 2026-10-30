"""How the server works: posted in #how-it-works and shown privately by /help.

Written from what the bot actually does; keep it in step with the code. Channel
names become clickable links when the channel exists.
"""

from __future__ import annotations

import discord
from discord import app_commands

import layout
import schedule
from storage import Store

GUIDE_KEY = "msg:guide"
COLOUR = discord.Colour.dark_purple()


def _ch(guild: discord.Guild, store: Store, purpose: str, fallback: str) -> str:
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found.mention if isinstance(found, discord.TextChannel) else f"#{fallback}"


def embeds(guild: discord.Guild, store: Store) -> list[discord.Embed]:
    c = lambda purpose, name: _ch(guild, store, purpose, name)  # noqa: E731
    days = "Monday, Thursday and Saturday"
    term_h = int(schedule.COMMANDER_TERM.total_seconds() // 3600)
    close_m = int(schedule.POLL_CLOSES_BEFORE.total_seconds() // 60)
    sections = [
        ("👋 Getting in", (
            f"Read {c(layout.RULES, 'rules')} first.\n\n"
            f"**Legion commanders:** apply in {c(layout.COMMANDER_APPLY, 'commander-applications')} with "
            "your character, your Legion's name and (optionally) its color. A private ticket opens "
            "with the Head Admin. Approval approves you **and** your Legion.\n\n"
            f"**Legion members:** apply in {c(layout.MEMBER_APPLY, 'member-applications')} and pick "
            "your Legion. Your commander **and** the Head Admin both confirm you.\n\n"
            "One application at a time. If you're denied, you can apply again after 24 hours."
        )),
        ("⚔️ Sieges", (
            f"Artifact Sieges run **{days} at 9 PM Eastern**. "
            f"{c(layout.SIEGE_TIMER, 'siege-timer')} counts down to the next one, in your own time "
            f"zone too. Want a ping before each siege? Turn on alerts in "
            f"{c(layout.SIEGE_ALERTS, 'siege-alerts')}: 1 h, 30 min and 15 min before, at the "
            "start, and when the Faction Commander vote opens and is about to close."
        )),
        ("👑 Faction Commander", (
            "Each siege has one shot caller, elected by the faction in "
            f"{c(layout.ELECTION, 'faction-commander')}.\n"
            f"• **Apply** any time after the previous siege's commander term ends, until voting opens.\n"
            "• **Vote** opens 24 h before the siege. One vote each, final; you may vote for yourself. "
            "Counts stay hidden until the end.\n"
            f"• Voting ends **{close_m} min before** the siege. Most votes wins; ties are broken at random.\n"
            f"• The winner holds the **Faction Commander** role until {term_h} h after the siege starts: "
            "a private room with the Head Admin, a room with every Legion Commander, and the "
            "**War Room** voice channel, where only the Faction Commander speaks.\n"
            "• Can't make it? **Step down** and the runner-up takes over."
        )),
        ("🛡️ Legions", (
            "Each Legion has its own role, color and private channel. Its commander manages it from "
            "the panel in that channel: remove a member, hand over command, rename, change the "
            "color, or disband. If the commander leaves the server, the Legion is disbanded; a "
            "member who leaves must apply again.\n\n"
            "`/legion list` shows every approved Legion."
        )),
        ("🧭 Staff", (
            "The **Head Admin** runs the server: approvals, Legions, sieges and announcements in "
            f"{c(layout.ANNOUNCEMENTS, 'announcements')}. **Officers** help with tickets but "
            "don't approve. Questions? Ask in the chat."
        )),
    ]
    out = []
    for title, text in sections:
        out.append(discord.Embed(title=title, description=text, colour=COLOUR))
    out[0].set_author(name="How this server works")
    return out


async def ensure_posted(guild: discord.Guild, store: Store) -> list[str]:
    """Post the guide in #how-it-works, or refresh it if already posted."""
    channel = guild.get_channel(store.get_config_id(guild.id, layout.GUIDE) or 0)
    if not isinstance(channel, discord.TextChannel):
        return []
    message_id = store.get_config_id(guild.id, GUIDE_KEY)
    if message_id is not None:
        try:
            await channel.get_partial_message(message_id).edit(content=None, embeds=embeds(guild, store))
            return []
        except discord.NotFound:
            pass
    message = await channel.send(embeds=embeds(guild, store))
    store.set_config(guild.id, GUIDE_KEY, message.id)
    return [f"Posted the guide in {channel.mention}."]


@app_commands.command(name="help", description="How this server works: applications, sieges, the vote, Legions.")
@app_commands.guild_only()
async def help_command(interaction: discord.Interaction) -> None:
    if interaction.guild is None:
        return
    store: Store = interaction.client.store  # type: ignore[attr-defined]
    await interaction.response.send_message(embeds=embeds(interaction.guild, store), ephemeral=True)
