"""Siege countdown and the Faction Commander election.

Countdown: one message in the siege-timer channel says when the next siege
starts. The bot edits it every minute.

Election, one per siege (times in `schedule.py`):
  1. Applications open when the previous siege's Faction Commander term ends.
     Any approved person (Legion Commander, Legion Member or Head Admin) may
     apply, and may withdraw, until the poll opens.
  2. 24 hours before the siege the poll opens with the applicants' names.
     Every approved person may vote once, for anyone on the list (themselves
     included). A vote is final. Counts are hidden until the poll closes.
  3. 30 minutes before the siege the poll closes. The most votes wins; a tie
     is broken at random among the tied. The winner gets the Faction Commander
     role. Nobody applied, or nobody voted: no Faction Commander this siege.
  4. 2 hours after the siege starts the role is removed, and applications for
     the next siege open.

During the term the Faction Commander may step down with the button in the
step-down channel. The role passes to the runner-up: the next applicant by
votes (zero votes included), ties broken at random, skipping anyone who already
stepped down or left the server. Nobody left: no Faction Commander for the rest
of the siege. The role itself is what opens the Faction Command category and
lets its holder speak in the command voice channel, so access moves with it.

A background loop runs once a minute and drives all of it, so the steps happen
on time without anyone pressing anything, and catch up after a restart.
"""

from __future__ import annotations

import asyncio
import datetime as dt
import logging
import random
import re

import discord

import alerts
import layout
import roles
import schedule
from storage import Election, Store

log = logging.getLogger("aion2_bot.siege")

# Serialises every election change (apply, withdraw, vote, poll steps).
_lock = asyncio.Lock()

# A select menu holds at most 25 choices, so a siege takes at most 25 applicants.
MAX_CANDIDATES = 25

TIMER_KEY = "msg:siege_timer"
PANEL_KEY = "msg:election_panel"
STEP_DOWN_KEY = "msg:step_down"

STEP_DOWN_TEXT = (
    "## Step down\n"
    "If you can't lead this siege for any reason, click **Step down**. Your Faction Commander "
    "role goes to the runner-up: the applicant with the next most votes. You can't take it "
    "back for this siege."
)

# Last text posted per message, so the loop only edits when something changed.
_last_text: dict[int, str] = {}


def store_of(interaction: discord.Interaction) -> Store:
    return interaction.client.store  # type: ignore[attr-defined]


def is_approved(member: discord.Member) -> bool:
    return (roles.has_role(member, layout.COMMANDER_ROLE) or roles.has_role(member, layout.MEMBER_ROLE)
            or roles.is_head_admin(member))


def _channel(guild: discord.Guild, store: Store, purpose: str) -> discord.TextChannel | None:
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found if isinstance(found, discord.TextChannel) else None


async def _reply(interaction: discord.Interaction, text: str) -> None:
    if interaction.response.is_done():
        await interaction.followup.send(text, ephemeral=True)
    else:
        await interaction.response.send_message(text, ephemeral=True)


async def _log(guild: discord.Guild, store: Store, text: str) -> None:
    channel = _channel(guild, store, layout.BOT_LOG)
    if channel is not None:
        try:
            await channel.send(text, allowed_mentions=discord.AllowedMentions.none())
        except discord.HTTPException:
            pass


# --- texts ----------------------------------------------------------------------
def next_running_siege(guild: discord.Guild, store: Store, now: dt.datetime) -> tuple[dt.datetime, list[dt.datetime]]:
    """The next siege that isn't skipped, and the skipped ones before it."""
    skipped: list[dt.datetime] = []
    nxt = schedule.next_siege(now)
    while store.is_skipped(guild.id, nxt) and len(skipped) < 30:
        skipped.append(nxt)
        nxt = schedule.next_siege(nxt)
    return nxt, skipped


def timer_text(guild: discord.Guild, store: Store, now: dt.datetime) -> str:
    nxt, skipped = next_running_siege(guild, store, now)
    lines: list[str] = []
    for s in skipped:
        lines.append(f"⏭️ The {schedule.fmt_local(s)} siege is **skipped**.")
    if skipped:
        lines.append("")
    underway = schedule.siege_underway(now)
    if underway is not None and not store.is_skipped(guild.id, underway):
        e = store.election_for(guild.id, underway)
        cmdr = f"<@{e.winner_id}>" if e and e.winner_id and e.status == "decided" else "none"
        lines += [f"🔥 **Siege underway** since {schedule.tag(underway, 't')}. "
                  f"Faction Commander: {cmdr}.", ""]
    lines += [
        "## ⚔️ Next Artifact Siege",
        f"**{schedule.fmt_local(nxt)}**",
        f"Your time: {schedule.tag(nxt, 'F')}",
        f"Starts in **{schedule.humanize(nxt - now)}**",
        "",
        _election_line(guild, store, nxt, now),
        "",
        f"-# Sieges: Monday, Thursday and Saturday at 9 PM {schedule.TZ_LABEL}. "
        f"Updated {schedule.tag(now, 't')}.",
    ]
    return "\n".join(lines)


def _election_line(guild: discord.Guild, store: Store, siege: dt.datetime, now: dt.datetime) -> str:
    """One line on where the Faction Commander election for `siege` stands."""
    where = _channel(guild, store, layout.ELECTION)
    room = where.mention if where else "the Faction Commander channel"
    e = store.election_for(guild.id, siege)
    if now < schedule.applications_open(siege):
        return (f"🗳️ Faction Commander applications for this siege open "
                f"{schedule.tag(schedule.applications_open(siege), 'R')} in {room}.")
    if now < schedule.poll_opens(siege):
        n = len(store.candidates(e.id)) if e else 0
        return (f"🗳️ Faction Commander applications are open in {room} ({n} so far); "
                f"voting starts {schedule.tag(schedule.poll_opens(siege), 'R')}.")
    if e is not None and e.status == "polling":
        return f"🗳️ Vote for the Faction Commander in {room}; voting ends {schedule.tag(schedule.poll_closes(siege), 'R')}."
    if e is not None and e.winner_id and e.status == "decided":
        return f"👑 Faction Commander: <@{e.winner_id}>."
    if e is not None and (e.outcome in ("no_applicants", "no_votes", "cancelled", "skipped")
                          or (e.status == "decided" and not e.winner_id)):
        return "No Faction Commander for this siege."
    return "🗳️ Counting the Faction Commander votes…"


def panel_text(guild: discord.Guild, store: Store, now: dt.datetime) -> str:
    target = schedule.application_target(now)
    opens = schedule.applications_open(target)
    head = f"## 👑 Faction Commander: siege of {schedule.fmt_local(target)}"
    if store.is_skipped(guild.id, target):
        return f"{head}\n⏭️ The Head Admin has **skipped** this siege, so there is no vote for it."
    if now < opens:
        return (f"{head}\nApplications open {schedule.tag(opens, 'R')} ({schedule.tag(opens, 'f')}), "
                "when the current Faction Commander's term ends.")
    e = store.election_for(guild.id, target)
    names = store.candidates(e.id) if e else []
    listing = "\n".join(f"{i}. <@{uid}>" for i, uid in enumerate(names, 1)) or "_Nobody yet._"
    closes = schedule.poll_opens(target)
    return (f"{head}\nWant to lead the Asmodians in this siege? Click **Apply**. You can withdraw "
            f"until applications close {schedule.tag(closes, 'R')} ({schedule.tag(closes, 'f')}); "
            "then the vote opens here.\n\n"
            f"**Applicants ({len(names)}/{MAX_CANDIDATES}):**\n{listing}")


# --- the persistent messages -------------------------------------------------
async def _upsert(
    channel: discord.TextChannel, store: Store, key: str, text: str, view: discord.ui.View | None = None
) -> bool:
    """Edit the remembered message, or post it if missing. True if newly posted."""
    message_id = store.get_config_id(channel.guild.id, key)
    if message_id is not None:
        if _last_text.get(message_id) == text:
            return False
        try:
            kwargs: dict[str, object] = {"content": text, "allowed_mentions": discord.AllowedMentions.none()}
            if view is not None:
                kwargs["view"] = view
            await channel.get_partial_message(message_id).edit(**kwargs)  # type: ignore[arg-type]
            _last_text[message_id] = text
            return False
        except discord.NotFound:
            pass
    kwargs = {"allowed_mentions": discord.AllowedMentions.none()}
    if view is not None:
        kwargs["view"] = view
    message = await channel.send(text, **kwargs)  # type: ignore[arg-type]
    store.set_config(channel.guild.id, key, message.id)
    _last_text[message.id] = text
    return True


async def ensure_messages(guild: discord.Guild, store: Store) -> list[str]:
    """Post (or refresh) the countdown and the application panel. Used by setup and the loop."""
    notes: list[str] = []
    now = schedule.now_utc()
    timer = _channel(guild, store, layout.SIEGE_TIMER)
    if timer is not None and await _upsert(timer, store, TIMER_KEY, timer_text(guild, store, now)):
        notes.append(f"Posted the siege countdown in {timer.mention}.")
    room = _channel(guild, store, layout.ELECTION)
    if room is not None and await _upsert(room, store, PANEL_KEY, panel_text(guild, store, now), ApplyPanel()):
        notes.append(f"Posted the Faction Commander panel in {room.mention}.")
    desk = _channel(guild, store, layout.STEP_DOWN)
    if desk is not None and await _upsert(desk, store, STEP_DOWN_KEY, STEP_DOWN_TEXT, StepDownPanel()):
        notes.append(f"Posted the step-down button in {desk.mention}.")
    import controls  # here, not at the top: controls imports this module
    notes += await controls.ensure_panel(guild, store)
    return notes


# --- applying -------------------------------------------------------------------
class ApplyPanel(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Apply", style=discord.ButtonStyle.primary, emoji="👑",
                       custom_id="aion2:fc:apply")
    async def apply(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await _apply(interaction, withdraw=False)

    @discord.ui.button(label="Withdraw", style=discord.ButtonStyle.secondary,
                       custom_id="aion2:fc:withdraw")
    async def withdraw(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await _apply(interaction, withdraw=True)


async def _apply(interaction: discord.Interaction, withdraw: bool) -> None:
    guild = interaction.guild
    member = interaction.user
    if guild is None or not isinstance(member, discord.Member):
        return
    if not is_approved(member):
        await _reply(interaction, "Only approved Legion commanders and members can do that.")
        return
    store = store_of(interaction)
    now = schedule.now_utc()
    target = schedule.application_target(now)
    opens = schedule.applications_open(target)
    if now < opens:
        await _reply(interaction, f"Applications for the {schedule.fmt_local(target)} siege open "
                                  f"{schedule.tag(opens, 'R')}, when the current Faction Commander's term ends.")
        return
    if store.is_skipped(guild.id, target):
        await _reply(interaction, f"The Head Admin has skipped the {schedule.fmt_local(target)} siege.")
        return
    async with _lock:
        e = store.election_for(guild.id, target, create=True)
        assert e is not None
        if e.status != "collecting":
            await _reply(interaction, "Applications for this siege have closed.")
            return
        if withdraw:
            if store.remove_candidate(e.id, member.id):
                text = f"You withdrew from the Faction Commander race for {schedule.fmt_local(target)}."
            else:
                text = "You haven't applied for this siege."
        elif member.id in store.candidates(e.id):
            text = "You've already applied for this siege. Use **Withdraw** to take your name out."
        elif len(store.candidates(e.id)) >= MAX_CANDIDATES:
            text = f"This siege already has {MAX_CANDIDATES} applicants, the most a vote can list."
        else:
            store.add_candidate(e.id, member.id)
            text = (f"You're in the running for Faction Commander of the {schedule.fmt_local(target)} siege. "
                    f"Voting opens {schedule.tag(schedule.poll_opens(target), 'R')}.")
    await _reply(interaction, text)
    await ensure_messages(guild, store)


# --- voting ---------------------------------------------------------------------
class VoteSelect(
    discord.ui.DynamicItem[discord.ui.Select],
    template=r"aion2:fc:vote:(?P<election_id>[0-9]+)",
):
    def __init__(self, election_id: int, options: list[discord.SelectOption] | None = None,
                 select: discord.ui.Select | None = None) -> None:
        super().__init__(select or discord.ui.Select(
            custom_id=f"aion2:fc:vote:{election_id}", placeholder="Cast your vote (final)",
            options=options or [discord.SelectOption(label="-", value="0")],
        ))
        self.election_id = election_id

    @classmethod
    async def from_custom_id(
        cls, interaction: discord.Interaction, item: discord.ui.Select, match: re.Match[str], /
    ) -> VoteSelect:
        return cls(int(match["election_id"]), select=item)

    async def callback(self, interaction: discord.Interaction) -> None:
        await _vote(interaction, self.election_id, int(self.item.values[0]))


async def _vote(interaction: discord.Interaction, election_id: int, candidate_id: int) -> None:
    guild = interaction.guild
    voter = interaction.user
    if guild is None or not isinstance(voter, discord.Member):
        return
    if not is_approved(voter):
        await _reply(interaction, "Only approved Legion commanders and members can vote.")
        return
    store = store_of(interaction)
    async with _lock:
        e = store.get_election(election_id)
        if e is None or e.guild_id != guild.id or e.status != "polling":
            await _reply(interaction, "This vote is closed.")
            return
        if candidate_id not in store.candidates(e.id):
            await _reply(interaction, "That person isn't on the ballot.")
            return
        previous = store.vote_of(e.id, voter.id)
        if previous is not None:
            await _reply(interaction, f"You already voted for <@{previous}>. Votes are final.")
            return
        store.cast_vote(e.id, voter.id, candidate_id)
        cast = sum(store.tally(e.id).values())
    await _reply(interaction, f"Your vote for <@{candidate_id}> is in. It's final.")
    await _refresh_poll(guild, store, e, votes_cast=cast)


def _poll_text(guild: discord.Guild, store: Store, e: Election, votes_cast: int) -> str:
    names = store.candidates(e.id)
    listing = "\n".join(f"• <@{uid}>" for uid in names)
    closes = schedule.poll_closes(e.siege)
    return (f"## 🗳️ Vote: Faction Commander for {schedule.fmt_local(e.siege)}\n"
            f"Pick one name below. **One vote each, and it's final.** You may vote for yourself.\n"
            f"Voting ends {schedule.tag(closes, 'R')} ({schedule.tag(closes, 'f')}); counts are "
            "shown when it ends.\n\n"
            f"**On the ballot:**\n{listing}\n\n-# Votes cast so far: {votes_cast}")


def _poll_view(guild: discord.Guild, store: Store, e: Election) -> discord.ui.View:
    options: list[discord.SelectOption] = []
    for uid in store.candidates(e.id):
        m = guild.get_member(uid)
        label = (m.display_name if m else f"User {uid}")[:100]
        options.append(discord.SelectOption(label=label, value=str(uid)))
    view = discord.ui.View(timeout=None)
    view.add_item(VoteSelect(e.id, options))
    return view


async def _refresh_poll(guild: discord.Guild, store: Store, e: Election, votes_cast: int) -> None:
    room = _channel(guild, store, layout.ELECTION)
    if room is None or e.poll_message_id is None:
        return
    try:
        await room.get_partial_message(e.poll_message_id).edit(
            content=_poll_text(guild, store, e, votes_cast), allowed_mentions=discord.AllowedMentions.none(),
        )
    except discord.HTTPException:
        log.warning("Could not update poll %s", e.id)


# --- stepping down --------------------------------------------------------------
class StepDownPanel(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Step down", style=discord.ButtonStyle.danger, emoji="🏳️",
                       custom_id="aion2:fc:stepdown")
    async def step_down(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        guild = interaction.guild
        member = interaction.user
        if guild is None or not isinstance(member, discord.Member):
            return
        if _current_term(store_of(interaction), guild, member.id) is None:
            await _reply(interaction, "You aren't the Faction Commander right now.")
            return
        await interaction.response.send_message(
            "Step down as Faction Commander? The role goes to the runner-up and you can't take "
            "it back this siege.", view=ConfirmStepDown(), ephemeral=True,
        )


class ConfirmStepDown(discord.ui.View):
    def __init__(self) -> None:
        super().__init__(timeout=60)

    @discord.ui.button(label="Yes, step down", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="Stepping down…", view=None)
        await _step_down(interaction)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="You're still the Faction Commander.", view=None)


def _current_term(store: Store, guild: discord.Guild, user_id: int) -> Election | None:
    """The election whose term this person holds right now, if any."""
    now = schedule.now_utc()
    return next((e for e in store.unfinished_elections(guild.id)
                 if e.status == "decided" and e.winner_id == user_id and now < schedule.term_ends(e.siege)),
                None)


def runner_up(guild: discord.Guild, store: Store, e: Election) -> int | None:
    # Everyone who held the role (stepped down or was removed) is recorded in
    # stepdowns, so they are skipped here.
    """Next in line: most votes (zero counts), ties at random, skipping who's out."""
    counts = store.tally(e.id)
    out = store.stepped_down(e.id) | {e.winner_id or 0}
    pool = [u for u in store.candidates(e.id) if u not in out and guild.get_member(u) is not None]
    random.shuffle(pool)
    pool.sort(key=lambda u: -counts.get(u, 0))  # stable: ties stay in random order
    return pool[0] if pool else None


async def _step_down(interaction: discord.Interaction) -> None:
    guild = interaction.guild
    member = interaction.user
    if guild is None or not isinstance(member, discord.Member):
        return
    store = store_of(interaction)
    async with _lock:
        e = _current_term(store, guild, member.id)
        if e is None:
            await _reply(interaction, "You aren't the Faction Commander right now.")
            return
        await hand_over(guild, store, e, f"<@{member.id}> stepped down")
    await _reply(interaction, "You've stepped down. Thank you for letting the faction know.")
    await ensure_messages(guild, store)


async def hand_over(guild: discord.Guild, store: Store, e: Election, why: str) -> str:
    """Take the role from the current holder and pass it to the runner-up.

    Call with `_lock` held. `why` starts the announcement ("<@x> stepped down").
    The role is given now if the term has started (vote closed), otherwise the
    runner-up is recorded and gets it at the usual time.
    """
    role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
    leaving = guild.get_member(e.winner_id or 0)
    if e.winner_id:
        store.add_stepdown(e.id, e.winner_id)
    if role is not None and leaving is not None and role in leaving.roles:
        await leaving.remove_roles(role, reason="No longer Faction Commander")
    nxt = runner_up(guild, store, e)
    nxt_member = guild.get_member(nxt) if nxt else None
    if nxt_member is not None:
        if role is not None and schedule.now_utc() >= schedule.poll_closes(e.siege):
            await nxt_member.add_roles(role, reason="Runner-up becomes Faction Commander")
        store.update_election(e.id, winner_id=nxt_member.id)
        text = (f"🏳️ {why}. **{nxt_member.mention} is now the Faction Commander** as runner-up, "
                f"until {schedule.tag(schedule.term_ends(e.siege), 't')}.")
    else:
        # The term stays open with nobody holding it, so its end (and the
        # "applications are open" notice) still happens at the usual time.
        store.update_election(e.id, outcome="stepped_down", winner_id=None)
        text = (f"🏳️ {why}, and there is no runner-up left, so there is no Faction Commander "
                "for the rest of this siege.")
    room = _channel(guild, store, layout.ELECTION)
    if room is not None:
        await room.send(text, allowed_mentions=discord.AllowedMentions(users=[nxt_member] if nxt_member else False))
    await _log(guild, store, text)
    return text


# --- the election steps, driven by the loop -----------------------------------
async def _open_poll(guild: discord.Guild, store: Store, e: Election) -> Election:
    room = _channel(guild, store, layout.ELECTION)
    names = store.candidates(e.id)
    if not names:
        if room is not None:
            await room.send(f"Nobody applied to be Faction Commander for the {schedule.fmt_local(e.siege)} "
                            "siege, so there will be no Faction Commander for it.")
        await _log(guild, store, f"Election for {schedule.fmt_local(e.siege)}: no applicants.")
        return store.update_election(e.id, status="finished", outcome="no_applicants")
    message_id = None
    if room is not None:
        message = await room.send(
            _poll_text(guild, store, e, 0), view=_poll_view(guild, store, e),
            allowed_mentions=discord.AllowedMentions.none(),
        )
        message_id = message.id
    await _log(guild, store, f"Election for {schedule.fmt_local(e.siege)}: voting opened with "
                             f"{len(names)} applicant(s).")
    return store.update_election(e.id, status="polling", poll_message_id=message_id)


async def _close_poll(guild: discord.Guild, store: Store, e: Election, now: dt.datetime) -> Election:
    room = _channel(guild, store, layout.ELECTION)
    names = store.candidates(e.id)
    counts = store.tally(e.id)
    results = "\n".join(
        f"• <@{uid}>: {counts.get(uid, 0)} vote{'' if counts.get(uid, 0) == 1 else 's'}"
        for uid in sorted(names, key=lambda u: -counts.get(u, 0))
    )
    # Applicants who left the server can't take the role.
    eligible = {uid: n for uid, n in counts.items() if guild.get_member(uid) is not None}
    winner_id: int | None = None
    tie_note = ""
    if eligible:
        best = max(eligible.values())
        tied = [uid for uid, n in eligible.items() if n == best]
        winner_id = random.choice(tied)
        if len(tied) > 1:
            tie_note = (" after a tie between " + ", ".join(f"<@{u}>" for u in tied)
                        + ", broken at random")

    header = f"## 🗳️ Results: Faction Commander for {schedule.fmt_local(e.siege)}"
    if winner_id is None:
        verdict = "Nobody voted, so there will be no Faction Commander for this siege."
    else:
        verdict = (f"👑 **<@{winner_id}> is the Faction Commander**{tie_note}. The role lasts until "
                   f"{schedule.tag(schedule.term_ends(e.siege), 't')}.")
    if room is not None and e.poll_message_id is not None:
        try:
            await room.get_partial_message(e.poll_message_id).edit(
                content=f"{header}\n{results}\n\n{verdict}", view=None,
                allowed_mentions=discord.AllowedMentions.none(),
            )
        except discord.HTTPException:
            log.warning("Could not close poll message for election %s", e.id)

    if winner_id is None:
        if room is not None:
            await room.send(verdict)
        await _log(guild, store, f"Election for {schedule.fmt_local(e.siege)}: no votes.")
        return store.update_election(e.id, status="finished", outcome="no_votes")

    note = ""
    role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
    member = guild.get_member(winner_id)
    if now >= schedule.term_ends(e.siege):
        note = " (The siege is already over, so the role wasn't given.)"
    elif role is None:
        note = f" ⚠️ The **{layout.FACTION_COMMANDER_ROLE}** role is missing; run `/setup server`."
    elif member is not None:
        try:
            await member.add_roles(role, reason=f"Won the Faction Commander vote for {e.siege_start}")
        except discord.HTTPException:
            note = " ⚠️ The bot couldn't give the role; check that its role is above Faction Commander."
    if room is not None:
        await room.send(f"{verdict}{note}", allowed_mentions=discord.AllowedMentions(users=True))
    await _log(guild, store, f"Election for {schedule.fmt_local(e.siege)}: <@{winner_id}> won{tie_note}.{note}")
    status = "decided" if now < schedule.term_ends(e.siege) else "finished"
    return store.update_election(e.id, status=status, winner_id=winner_id, outcome="won")


async def _end_term(guild: discord.Guild, store: Store, e: Election) -> Election:
    role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
    member = guild.get_member(e.winner_id or 0)
    if role is not None and member is not None and role in member.roles:
        try:
            await member.remove_roles(role, reason="Faction Commander term ended")
        except discord.HTTPException:
            log.warning("Could not remove Faction Commander role from %s", member.id)
    room = _channel(guild, store, layout.ELECTION)
    nxt = schedule.application_target(schedule.term_ends(e.siege))
    ended = f"<@{e.winner_id}>'s term as Faction Commander has ended. " if e.winner_id else ""
    if room is not None:
        await room.send(
            f"{ended}Applications for the {schedule.fmt_local(nxt)} siege are now open.",
            allowed_mentions=discord.AllowedMentions.none(),
        )
    await _log(guild, store, f"Faction Commander term for the {schedule.fmt_local(e.siege)} siege ended.")
    return store.update_election(e.id, status="finished")


async def cancel_poll(guild: discord.Guild, store: Store, e: Election, why: str) -> None:
    """Strike out an open poll's message (the caller updates the election)."""
    room = _channel(guild, store, layout.ELECTION)
    if room is not None and e.poll_message_id is not None:
        try:
            await room.get_partial_message(e.poll_message_id).edit(
                content=f"## 🗳️ Vote cancelled: Faction Commander for {schedule.fmt_local(e.siege)}\n{why}",
                view=None, allowed_mentions=discord.AllowedMentions.none(),
            )
        except discord.HTTPException:
            log.warning("Could not strike out poll for election %s", e.id)


async def _apply_skip(guild: discord.Guild, store: Store, e: Election, now: dt.datetime) -> None:
    """A skipped siege: stop its vote, take back its role, close it out."""
    if e.status == "collecting" and now < schedule.poll_opens(e.siege):
        return  # may still be un-skipped before the vote would open
    if e.status == "polling":
        await cancel_poll(guild, store, e, "The Head Admin skipped this siege.")
    role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
    holder = guild.get_member(e.winner_id or 0)
    if role is not None and holder is not None and role in holder.roles:
        await holder.remove_roles(role, reason="Siege skipped by the Head Admin")
    store.update_election(e.id, status="finished", outcome="skipped")


async def advance(guild: discord.Guild, store: Store, e: Election, now: dt.datetime) -> None:
    """Move one election through every step whose time has come."""
    if store.is_skipped(guild.id, e.siege):
        await _apply_skip(guild, store, e, now)
        return
    if (e.status == "decided" and e.winner_id and e.outcome == "appointed"
            and schedule.poll_closes(e.siege) <= now < schedule.term_ends(e.siege)):
        # Appointed ahead of time: the role arrives when the term begins.
        role = roles.find_role(guild, layout.FACTION_COMMANDER_ROLE)
        holder = guild.get_member(e.winner_id)
        if role is not None and holder is not None and role not in holder.roles:
            await holder.add_roles(role, reason="Appointed Faction Commander: term begins")
    if e.status == "collecting" and now >= schedule.poll_opens(e.siege):
        e = await _open_poll(guild, store, e)
    if e.status == "polling" and now >= schedule.poll_closes(e.siege):
        e = await _close_poll(guild, store, e, now)
    if e.status == "decided" and now >= schedule.term_ends(e.siege):
        await _end_term(guild, store, e)


async def tick_guild(guild: discord.Guild, store: Store, now: dt.datetime) -> None:
    if _channel(guild, store, layout.ELECTION) is None and _channel(guild, store, layout.SIEGE_TIMER) is None:
        return  # not set up yet
    async with _lock:
        for e in store.unfinished_elections(guild.id):
            await advance(guild, store, e, now)
        # The siege whose vote should be open (or done) needs an election even if
        # nobody applied, so "nobody applied" gets announced.
        current = schedule.current_term_siege(now)
        if now >= schedule.poll_opens(current):
            e = store.election_for(guild.id, current, create=True)
            assert e is not None
            await advance(guild, store, e, now)
        await alerts.tick(guild, store, now)
    await ensure_messages(guild, store)


async def run_loop(client: discord.Client, store: Store) -> None:
    """Tick every guild at the top of each minute, forever."""
    await client.wait_until_ready()
    while not client.is_closed():
        now = schedule.now_utc()
        for guild in client.guilds:
            try:
                await tick_guild(guild, store, now)
            except Exception:
                log.exception("Siege tick failed in %s", guild.id)
        await asyncio.sleep(60 - schedule.now_utc().second + 0.5)
