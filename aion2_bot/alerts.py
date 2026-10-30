"""Siege reminders in the siege-alerts channel, pinging the opt-in Siege Alerts role.

People turn the role on or off with the button on the channel's panel message.
For each siege the bot posts, pinging that role:
  - when the Faction Commander vote opens (24 h before), and 2 h before it closes;
  - 1 hour, 30 minutes and 15 minutes before the siege, and when it starts.

Each reminder is sent at most once (recorded in the database). A reminder that
is more than GRACE late (the bot was offline at the time) is skipped rather than
posted stale. Called from the once-a-minute siege loop, after the election has
advanced, so the 30-minute reminder can already name the Faction Commander.
"""

from __future__ import annotations

import datetime as dt
import logging

import discord

import layout
import roles
import schedule
from storage import Store

log = logging.getLogger("aion2_bot.alerts")

PANEL_KEY = "msg:alerts_panel"
GRACE = dt.timedelta(minutes=5)
VOTE_CLOSING_WARNING = dt.timedelta(hours=2)

PANEL_TEXT = (
    "## 🔔 Siege alerts\n"
    "Want a ping before every Artifact Siege? Click the button to turn the "
    f"**{layout.SIEGE_ALERTS_ROLE}** role on or off.\n\n"
    "You'll be pinged here 1 hour, 30 minutes and 15 minutes before each siege and when "
    "it starts, plus when the Faction Commander vote opens and 2 hours before it closes."
)


def _channel(guild: discord.Guild, store: Store, purpose: str) -> discord.TextChannel | None:
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found if isinstance(found, discord.TextChannel) else None


class AlertsPanel(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Turn siege alerts on / off", style=discord.ButtonStyle.primary,
                       emoji="🔔", custom_id="aion2:alerts:toggle")
    async def toggle(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        guild = interaction.guild
        member = interaction.user
        if guild is None or not isinstance(member, discord.Member):
            return
        role = roles.find_role(guild, layout.SIEGE_ALERTS_ROLE)
        if role is None:
            await interaction.response.send_message(
                f"The **{layout.SIEGE_ALERTS_ROLE}** role is missing; ask the Head Admin to run "
                "`/setup server`.", ephemeral=True,
            )
            return
        try:
            if role in member.roles:
                await member.remove_roles(role, reason="Turned siege alerts off")
                text = "🔕 Siege alerts are **off**. You won't be pinged for sieges."
            else:
                await member.add_roles(role, reason="Turned siege alerts on")
                text = "🔔 Siege alerts are **on**. You'll be pinged before every siege."
        except discord.HTTPException:
            text = ("The bot couldn't change your role. Ask the Head Admin to check that the bot's "
                    f"role is above **{layout.SIEGE_ALERTS_ROLE}**.")
        await interaction.response.send_message(text, ephemeral=True)


async def ensure_panel(guild: discord.Guild, store: Store) -> list[str]:
    """Post the alerts button message, or refresh it if already posted."""
    channel = _channel(guild, store, layout.SIEGE_ALERTS)
    if channel is None:
        return []
    message_id = store.get_config_id(guild.id, PANEL_KEY)
    if message_id is not None:
        try:
            await channel.get_partial_message(message_id).edit(content=PANEL_TEXT, view=AlertsPanel())
            return []
        except discord.NotFound:
            pass
    message = await channel.send(PANEL_TEXT, view=AlertsPanel())
    store.set_config(guild.id, PANEL_KEY, message.id)
    return [f"Posted the siege alerts button in {channel.mention}."]


def _commander_line(store: Store, guild: discord.Guild, siege: dt.datetime) -> str:
    e = store.election_for(guild.id, siege)
    if e is not None and e.winner_id and e.status in ("decided", "finished"):
        return f"Faction Commander: <@{e.winner_id}>."
    if e is not None and e.status == "polling":
        return ""
    return "No Faction Commander for this siege."


def _due(guild: discord.Guild, store: Store, siege: dt.datetime) -> list[tuple[str, dt.datetime, str | None]]:
    """(kind, when, text) for every reminder of one siege; text None = skip it."""
    room = _channel(guild, store, layout.ELECTION)
    where = room.mention if room else "the Faction Commander channel"
    e = store.election_for(guild.id, siege)
    polling = e is not None and e.status == "polling"
    closes = schedule.poll_closes(siege)
    cmdr = _commander_line(store, guild, siege)
    last_call = (f" Last call: Faction Commander voting in {where} ends {schedule.tag(closes, 'R')}."
                 if polling else f" {cmdr}")
    return [
        ("vote_open", schedule.poll_opens(siege),
         f"🗳️ Voting for the Faction Commander of the {schedule.fmt_local(siege)} siege is open in "
         f"{where}, until {schedule.tag(closes, 'f')}." if polling else None),
        ("vote_closing", closes - VOTE_CLOSING_WARNING,
         f"🗳️ **2 hours left** to vote for the Faction Commander in {where} "
         f"(ends {schedule.tag(closes, 't')})." if polling else None),
        ("1h", siege - dt.timedelta(hours=1),
         f"⚔️ The Artifact Siege starts in **1 hour** ({schedule.tag(siege, 't')}).{last_call}"),
        ("30m", siege - dt.timedelta(minutes=30),
         f"⚔️ The Artifact Siege starts in **30 minutes** ({schedule.tag(siege, 't')}). {cmdr}"),
        ("15m", siege - dt.timedelta(minutes=15),
         f"⚔️ The Artifact Siege starts in **15 minutes** ({schedule.tag(siege, 't')}). {cmdr}"),
        ("start", siege, f"🔥 **The Artifact Siege has begun!** {cmdr}"),
    ]


async def tick(guild: discord.Guild, store: Store, now: dt.datetime) -> None:
    channel = _channel(guild, store, layout.SIEGE_ALERTS)
    if channel is None:
        return
    role = roles.find_role(guild, layout.SIEGE_ALERTS_ROLE)
    siege = schedule.current_term_siege(now)
    for kind, when, text in _due(guild, store, siege):
        if text is None or not (when <= now < when + GRACE):
            continue
        if not store.mark_alert(guild.id, siege, kind):
            continue  # already sent
        ping = f"{role.mention} " if role is not None else ""
        try:
            await channel.send(
                f"{ping}{text}".strip(),
                allowed_mentions=discord.AllowedMentions(users=False, roles=[role] if role else False),
            )
        except discord.HTTPException:
            log.warning("Could not send %s alert in %s", kind, guild.id)
