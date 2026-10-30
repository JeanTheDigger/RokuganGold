"""Head Admin siege controls: a button panel in the siege-control channel.

Buttons (Head Admin only):
  Appoint commander  pick any approved person as Faction Commander for the
                     current or next siege. Cancels an open vote; replaces
                     whoever holds the role. Appointed ahead of time, they get
                     the role when the term begins (30 min before the siege).
  Remove commander   take the role from the current Faction Commander; the
                     runner-up takes over, exactly like a step-down.
  Skip / un-skip     pick one of the next 4 sieges. A skipped siege has no vote,
                     no reminders and no Faction Commander; its open vote is
                     cancelled and its role taken back. Picking it again un-skips.
  Cancel vote        while a vote is open: reopen it fresh (votes wiped, same
                     applicants, same closing time) or end it with no commander.
"""

from __future__ import annotations

import datetime as dt
import logging

import discord

import layout
import roles
import schedule
import siege
from storage import Election, Store

log = logging.getLogger("aion2_bot.controls")

PANEL_KEY = "msg:siege_control"
SKIP_CHOICES = 4

STATUS_TEXT = {
    "collecting": "applications open",
    "polling": "vote open",
    "decided": "decided",
    "finished": "over",
}
OUTCOME_TEXT = {
    "no_applicants": "nobody applied",
    "no_votes": "nobody voted",
    "skipped": "skipped",
    "cancelled": "vote cancelled by the Head Admin",
    "stepped_down": "no commander left after step-downs",
    "appointed": "appointed by the Head Admin",
}


def store_of(interaction: discord.Interaction) -> Store:
    return interaction.client.store  # type: ignore[attr-defined]


async def _reply(interaction: discord.Interaction, text: str, view: discord.ui.View | None = None) -> None:
    kwargs: dict[str, object] = {"ephemeral": True}
    if view is not None:
        kwargs["view"] = view
    if interaction.response.is_done():
        await interaction.followup.send(text, **kwargs)  # type: ignore[arg-type]
    else:
        await interaction.response.send_message(text, **kwargs)  # type: ignore[arg-type]


async def _head_admin(interaction: discord.Interaction) -> tuple[discord.Guild, discord.Member] | None:
    guild = interaction.guild
    member = interaction.user
    if guild is None or not isinstance(member, discord.Member):
        return None
    if not roles.is_head_admin(member):
        await _reply(interaction, "Only the Head Admin can use the siege controls.")
        return None
    return guild, member


async def _announce(guild: discord.Guild, store: Store, text: str, ping: discord.Member | None = None) -> None:
    room = siege._channel(guild, store, layout.ELECTION)
    if room is not None:
        await room.send(text, allowed_mentions=discord.AllowedMentions(users=[ping] if ping else False))
    await siege._log(guild, store, text)


async def _after(guild: discord.Guild, store: Store) -> None:
    """Apply the change right away instead of waiting for the next minute's tick."""
    await siege.tick_guild(guild, store, schedule.now_utc())


def _current(guild: discord.Guild, store: Store, now: dt.datetime) -> tuple[dt.datetime, Election | None]:
    s = schedule.current_term_siege(now)
    return s, store.election_for(guild.id, s)


# --- the panel ------------------------------------------------------------------
def control_text(guild: discord.Guild, store: Store, now: dt.datetime) -> str:
    s, e = _current(guild, store, now)
    skipped = store.is_skipped(guild.id, s)
    lines = ["## 🛠️ Siege control", "Only the Head Admin can use these buttons.", ""]
    lines.append(f"**Current / next siege:** {schedule.fmt_local(s)}" + (" ⏭️ **skipped**" if skipped else ""))
    if e is None:
        lines.append("**Election:** no applications yet")
    else:
        state = STATUS_TEXT[e.status]
        if e.outcome in OUTCOME_TEXT:
            state += f" ({OUTCOME_TEXT[e.outcome]})"
        lines.append(f"**Election:** {state}, {len(store.candidates(e.id))} applicant(s)")
        lines.append(f"**Faction Commander:** {f'<@{e.winner_id}>' if e.winner_id else 'none'}")
    upcoming = _upcoming(now)
    marked = [schedule.fmt_local(x) for x in upcoming if store.is_skipped(guild.id, x)]
    lines.append(f"**Skipped sieges ahead:** {', '.join(marked) if marked else 'none'}")
    return "\n".join(lines)


def _upcoming(now: dt.datetime) -> list[dt.datetime]:
    out = [schedule.current_term_siege(now)]
    while len(out) < SKIP_CHOICES:
        out.append(schedule.next_siege(out[-1]))
    return out


async def ensure_panel(guild: discord.Guild, store: Store) -> list[str]:
    channel = siege._channel(guild, store, layout.SIEGE_CONTROL)
    if channel is None:
        return []
    text = control_text(guild, store, schedule.now_utc())
    if await siege._upsert(channel, store, PANEL_KEY, text, ControlPanel()):
        return [f"Posted the siege control panel in {channel.mention}."]
    return []


class ControlPanel(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Appoint commander", style=discord.ButtonStyle.primary, emoji="👑",
                       custom_id="aion2:ctl:appoint")
    async def appoint(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _head_admin(interaction) is None:
            return
        await _reply(interaction, "Who should be Faction Commander for the current / next siege?",
                     AppointPicker())

    @discord.ui.button(label="Remove commander", style=discord.ButtonStyle.danger, emoji="🚫",
                       custom_id="aion2:ctl:remove")
    async def remove(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, _ = got
        _, e = _current(guild, store_of(interaction), schedule.now_utc())
        if e is None or e.status != "decided" or not e.winner_id:
            await _reply(interaction, "There is no Faction Commander to remove right now.")
            return
        await _reply(interaction, f"Remove <@{e.winner_id}> as Faction Commander? The runner-up takes over.",
                     ConfirmRemove(e.id))

    @discord.ui.button(label="Skip / un-skip a siege", style=discord.ButtonStyle.secondary, emoji="⏭️",
                       custom_id="aion2:ctl:skip")
    async def skip(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, _ = got
        await _reply(interaction, "Pick a siege to skip, or a skipped one to un-skip.",
                     SkipPicker(guild, store_of(interaction)))

    @discord.ui.button(label="Cancel vote", style=discord.ButtonStyle.secondary, emoji="🗳️",
                       custom_id="aion2:ctl:cancelvote")
    async def cancel_vote(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, _ = got
        _, e = _current(guild, store_of(interaction), schedule.now_utc())
        if e is None or e.status != "polling":
            await _reply(interaction, "No vote is open right now. After a vote closes, use "
                                      "**Appoint** or **Remove** instead.")
            return
        await _reply(interaction, "Restart the vote fresh (all votes wiped, same applicants, same closing "
                                  "time), or end it with no Faction Commander?", CancelVoteChoice(e.id))


# --- appoint ----------------------------------------------------------------------
class AppointPicker(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=120)

    @discord.ui.select(cls=discord.ui.UserSelect, placeholder="Choose a member")
    async def pick(self, interaction: discord.Interaction, select: discord.ui.UserSelect) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, actor = got
        target = select.values[0]
        if not isinstance(target, discord.Member):
            target = guild.get_member(target.id)  # type: ignore[assignment]
        if target is None or not siege.is_approved(target):
            await _reply(interaction, "Only an approved Legion Commander or Member (or Head Admin) can be "
                                      "Faction Commander.")
            return
        await interaction.response.defer(ephemeral=True)
        await _reply(interaction, await appoint(guild, store_of(interaction), target))


async def appoint(guild: discord.Guild, store: Store, target: discord.Member) -> str:
    now = schedule.now_utc()
    s = schedule.current_term_siege(now)
    if store.is_skipped(guild.id, s):
        return f"The {schedule.fmt_local(s)} siege is skipped; un-skip it first."
    role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
    async with siege._lock:
        e = store.election_for(guild.id, s, create=True)
        assert e is not None
        if e.status == "decided" and e.winner_id == target.id:
            return f"{target.mention} is already the Faction Commander for that siege."
        if e.status == "polling":
            await siege.cancel_poll(guild, store, e, f"The Head Admin appointed {target.mention} instead.")
        previous = guild.get_member(e.winner_id or 0) if e.status == "decided" else None
        if role is not None and previous is not None and role in previous.roles:
            await previous.remove_roles(role, reason="Replaced by an appointed Faction Commander")
        store.update_election(e.id, status="decided", winner_id=target.id, outcome="appointed")
        gets_now = now >= schedule.poll_closes(s)
        if role is not None and gets_now:
            await target.add_roles(role, reason="Appointed Faction Commander by the Head Admin")
    when = (f"until {schedule.tag(schedule.term_ends(s), 't')}" if gets_now else
            f"from {schedule.tag(schedule.poll_closes(s), 'f')} to {schedule.tag(schedule.term_ends(s), 't')}")
    replaced = f", replacing <@{previous.id}>" if previous is not None else ""
    await _announce(guild, store, f"👑 The Head Admin appointed **{target.mention}** Faction Commander for the "
                                  f"{schedule.fmt_local(s)} siege{replaced}, {when}.", ping=target)
    await _after(guild, store)
    return f"Done: {target.mention} is Faction Commander for the {schedule.fmt_local(s)} siege."


# --- remove -----------------------------------------------------------------------
class ConfirmRemove(discord.ui.View):
    def __init__(self, election_id: int) -> None:
        super().__init__(timeout=60)
        self.election_id = election_id

    @discord.ui.button(label="Yes, remove", style=discord.ButtonStyle.danger)
    async def yes(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, _ = got
        store = store_of(interaction)
        await interaction.response.edit_message(content="Removing…", view=None)
        async with siege._lock:
            e = store.get_election(self.election_id)
            if e is None or e.status != "decided" or not e.winner_id:
                await _reply(interaction, "There is no Faction Commander to remove any more.")
                return
            text = await siege.hand_over(guild, store, e, f"The Head Admin removed <@{e.winner_id}>")
        await _after(guild, store)
        await _reply(interaction, text)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def no(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="Nothing changed.", view=None)


# --- skip -------------------------------------------------------------------------
class SkipPicker(discord.ui.View):
    def __init__(self, guild: discord.Guild, store: Store) -> None:
        super().__init__(timeout=120)
        options = []
        for s in _upcoming(schedule.now_utc()):
            skipped = store.is_skipped(guild.id, s)
            options.append(discord.SelectOption(
                label=schedule.fmt_local(s)[:100], value=s.isoformat(),
                description="Skipped: pick to un-skip" if skipped else "Pick to skip",
                emoji="⏭️" if skipped else "⚔️",
            ))
        self.choice.options = options

    @discord.ui.select(placeholder="Choose a siege")
    async def choice(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        got = await _head_admin(interaction)
        if got is None:
            return
        guild, _ = got
        store = store_of(interaction)
        s = dt.datetime.fromisoformat(select.values[0])
        now_skipped = not store.is_skipped(guild.id, s)
        e = store.election_for(guild.id, s)
        if not now_skipped and e is not None and e.status == "finished" and e.outcome == "skipped":
            note = " Its vote was already cancelled, so it runs with no Faction Commander unless you appoint one."
        else:
            note = ""
        store.set_skipped(guild.id, s, now_skipped)
        await interaction.response.edit_message(
            content=f"The {schedule.fmt_local(s)} siege is now **{'skipped' if now_skipped else 'back on'}**.{note}",
            view=None,
        )
        await _announce(guild, store, f"⏭️ The Head Admin {'skipped' if now_skipped else 'un-skipped'} the "
                                      f"{schedule.fmt_local(s)} siege.")
        await _after(guild, store)


# --- cancel vote ------------------------------------------------------------------
class CancelVoteChoice(discord.ui.View):
    def __init__(self, election_id: int) -> None:
        super().__init__(timeout=60)
        self.election_id = election_id

    async def _load(self, interaction: discord.Interaction) -> tuple[discord.Guild, Store, Election] | None:
        got = await _head_admin(interaction)
        if got is None:
            return None
        store = store_of(interaction)
        e = store.get_election(self.election_id)
        if e is None or e.status != "polling":
            await interaction.response.edit_message(content="That vote isn't open any more.", view=None)
            return None
        return got[0], store, e

    @discord.ui.button(label="Restart fresh", style=discord.ButtonStyle.primary)
    async def restart(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        loaded = await self._load(interaction)
        if loaded is None:
            return
        guild, store, e = loaded
        await interaction.response.edit_message(content="Restarting the vote…", view=None)
        room = siege._channel(guild, store, layout.ELECTION)
        async with siege._lock:
            store.clear_votes(e.id)
            await siege.cancel_poll(guild, store, e, "Restarted by the Head Admin: every vote was wiped. "
                                                     "Vote again in the new poll below.")
            if room is not None:
                message = await room.send(
                    siege._poll_text(guild, store, e, 0), view=siege._poll_view(guild, store, e),
                    allowed_mentions=discord.AllowedMentions.none(),
                )
                store.update_election(e.id, poll_message_id=message.id)
        await siege._log(guild, store, f"The Head Admin restarted the vote for {schedule.fmt_local(e.siege)}.")
        await _after(guild, store)

    @discord.ui.button(label="End with no commander", style=discord.ButtonStyle.danger)
    async def end(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        loaded = await self._load(interaction)
        if loaded is None:
            return
        guild, store, e = loaded
        await interaction.response.edit_message(content="Ending the vote…", view=None)
        async with siege._lock:
            await siege.cancel_poll(guild, store, e, "Ended by the Head Admin: no Faction Commander for "
                                                     "this siege.")
            store.update_election(e.id, status="finished", outcome="cancelled")
        await _announce(guild, store, f"🗳️ The Head Admin ended the vote for the {schedule.fmt_local(e.siege)} "
                                      "siege: no Faction Commander for it.")
        await _after(guild, store)
