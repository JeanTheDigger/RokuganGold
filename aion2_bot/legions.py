"""Legion management: remove a member, transfer command, rename, disband.

Two button panels drive it:
  - one in each Legion's private channel, for that Legion's commander;
  - one in the legion-control channel (Head Admin category) for every Legion.
Each action may be done by the Legion's commander or by the Head Admin.

Rules:
  - Removing a member takes their Legion role and approval (Legion Member /
    Legion Commander role), and their Siege Alerts role.
  - Removing the commander, or the commander leaving the server, disbands the
    Legion.
  - A member who leaves the server is removed from their Legion; coming back,
    they must apply again.
  - Transfer: the new commander must be a member of the Legion; the old
    commander stays on as a regular member.
  - Disband: everyone in the Legion loses its role and their approval, its
    pending member applications are denied, and its channel's transcript goes
    to the bot log before the channel and role are deleted.
  - Anyone who loses their approval is also taken out of the Faction Commander
    race, and if they hold the Faction Commander role it passes to the
    runner-up (see siege.py).
"""

from __future__ import annotations

import logging
import re

import discord

import applications
import colors
import layout
import roles
import siege
import ui_errors
from storage import Legion, Store
from ui_errors import SafeView

log = logging.getLogger("aion2_bot.legions")

CONTROL_KEY = "msg:legion_control"


def store_of(interaction: discord.Interaction) -> Store:
    return interaction.client.store  # type: ignore[attr-defined]


def panel_key(legion_id: int) -> str:
    return f"msg:legion_panel:{legion_id}"


def may_manage(member: discord.Member, legion: Legion) -> bool:
    return roles.is_head_admin(member) or member.id == legion.commander_id


async def _reply(interaction: discord.Interaction, text: str, view: discord.ui.View | None = None) -> None:
    kwargs: dict[str, object] = {"ephemeral": True}
    if view is not None:
        kwargs["view"] = view
    if interaction.response.is_done():
        await interaction.followup.send(text, **kwargs)  # type: ignore[arg-type]
    else:
        await interaction.response.send_message(text, **kwargs)  # type: ignore[arg-type]


async def _legion_channel_say(guild: discord.Guild, legion: Legion, text: str) -> None:
    channel = guild.get_channel(legion.channel_id or 0)
    if isinstance(channel, discord.TextChannel):
        try:
            await channel.send(text, allowed_mentions=discord.AllowedMentions.none())
        except discord.HTTPException:
            pass


# --- the core actions (call with applications._lock held) ---------------------
async def _strip_approval(guild: discord.Guild, store: Store, user_id: int, legion: Legion, why: str) -> None:
    """Take away everything approval gave this person."""
    member = guild.get_member(user_id)
    if member is not None:
        take = [roles.find_role(guild, name) for name in
                (layout.COMMANDER_ROLE, layout.MEMBER_ROLE, layout.SIEGE_ALERTS_ROLE)]
        take.append(guild.get_role(legion.role_id or 0))
        held = [r for r in take if r is not None and r in member.roles]
        if held:
            try:
                await member.remove_roles(*held, reason=why)
            except discord.HTTPException:
                log.warning("Could not remove roles from %s", user_id)
    store.withdraw_everywhere(guild.id, user_id)
    async with siege._lock:
        term = siege._current_term(store, guild, user_id)
        if term is not None:
            await siege.hand_over(guild, store, term, f"<@{user_id}> is no longer approved")


async def remove_member(guild: discord.Guild, store: Store, legion: Legion, user_id: int, why: str) -> str:
    if user_id == legion.commander_id:
        return await disband(guild, store, legion, f"{why}; that was its commander")
    store.remove_membership(guild.id, user_id)
    await _strip_approval(guild, store, user_id, legion, f"Removed from Legion {legion.name}")
    text = f"<@{user_id}> was removed from **{legion.name}** ({why})."
    await _legion_channel_say(guild, legion, text)
    await applications.bot_log(guild, store, text)
    member = guild.get_member(user_id)
    if member is not None:
        await applications.dm(member, f"**{guild.name}**: you were removed from the Legion **{legion.name}** "
                                      "and are no longer approved. You can apply again.")
    return text


def _cannot_add(guild: discord.Guild, store: Store, user_id: int) -> str | None:
    member = guild.get_member(user_id)
    if member is None or member.bot:
        return "Pick a person who is on the server."
    if store.membership(guild.id, user_id) is not None:
        return f"<@{user_id}> already belongs to a Legion."
    pending = store.open_application_for(guild.id, user_id)
    if pending is not None:
        return (f"<@{user_id}> has an application waiting in <#{pending.channel_id}>; decide that "
                "instead.")
    return None


async def add_member(guild: discord.Guild, store: Store, legion: Legion, user_id: int) -> str:
    """Head Admin tool: put someone straight into a Legion, no ticket."""
    problem = _cannot_add(guild, store, user_id)
    if problem:
        return problem
    member = guild.get_member(user_id)
    assert member is not None
    give = [r for r in (roles.find_role(guild, layout.MEMBER_ROLE), guild.get_role(legion.role_id or 0))
            if r is not None]
    await member.add_roles(*give, reason=f"Added to Legion {legion.name} by the Head Admin")
    store.add_member(guild.id, user_id, legion.id)
    text = f"<@{user_id}> was added to **{legion.name}** by the Head Admin."
    await _legion_channel_say(guild, legion, f"Welcome to **{legion.name}**, <@{user_id}>.")
    await applications.bot_log(guild, store, text)
    await applications.dm(member, f"**{guild.name}**: the Head Admin added you to the Legion **{legion.name}**.")
    return text


async def transfer(guild: discord.Guild, store: Store, legion: Legion, new_id: int, why: str) -> str:
    membership = store.membership(guild.id, new_id)
    if membership is None or membership.legion_id != legion.id:
        return f"<@{new_id}> isn't a member of **{legion.name}**."
    if new_id == legion.commander_id:
        return f"<@{new_id}> already commands **{legion.name}**."
    new = guild.get_member(new_id)
    if new is None:
        return f"<@{new_id}> isn't on the server."
    old_id = legion.commander_id
    store.set_commander(legion.id, new_id, old_id)
    commander_role = roles.find_role(guild, layout.COMMANDER_ROLE)
    member_role = roles.find_role(guild, layout.MEMBER_ROLE)
    old = guild.get_member(old_id)
    reason = f"Command of {legion.name} transferred"
    if old is not None:
        if commander_role is not None and commander_role in old.roles:
            await old.remove_roles(commander_role, reason=reason)
        if member_role is not None:
            await old.add_roles(member_role, reason=reason)
    if member_role is not None and member_role in new.roles:
        await new.remove_roles(member_role, reason=reason)
    if commander_role is not None:
        await new.add_roles(commander_role, reason=reason)
    # The new commander joins this Legion's open member tickets (they must approve them).
    for app in store.pending_member_applications(legion.id):
        ticket = guild.get_channel(app.channel_id or 0)
        if isinstance(ticket, discord.TextChannel):
            try:
                await ticket.set_permissions(new, view_channel=True, send_messages=True,
                                             read_message_history=True, reason=reason)
                await ticket.send(f"{new.mention} now commands **{legion.name}** and can approve here.",
                                  allowed_mentions=discord.AllowedMentions(users=[new]))
            except discord.HTTPException:
                pass
            refreshed = store.get_application(app.id)
            if refreshed is not None:
                await applications._refresh(guild, store, refreshed)
    updated = store.get_legion(legion.id)
    if updated is not None:
        await ensure_legion_panel(guild, store, updated)
    text = f"Command of **{legion.name}** passed from <@{old_id}> to <@{new_id}> ({why})."
    await _legion_channel_say(guild, legion, text)
    await applications.bot_log(guild, store, text)
    return text


async def set_color(guild: discord.Guild, store: Store, legion: Legion, color: int | None, why: str) -> str:
    """Recolor the Legion's role (None removes the color). Warns, doesn't refuse, if it's close to another's."""
    role = guild.get_role(legion.role_id or 0)
    if role is None:
        return f"The **{roles.legion_role_name(legion.name)}** role is missing, so its color can't be set."
    await role.edit(colour=discord.Colour(color or 0), reason=f"Legion {legion.name} color changed")
    store.set_legion_color(legion.id, color)
    updated = store.get_legion(legion.id)
    if updated is not None:
        await ensure_legion_panel(guild, store, updated)
    text = (f"**{legion.name}** no longer has a color ({why})." if color is None else
            f"**{legion.name}**'s color is now {colors.describe(color)} ({why}).")
    await _legion_channel_say(guild, legion, text)
    await applications.bot_log(guild, store, text)
    near = colors.close_to(color, store.legion_colors(guild.id, exclude_id=legion.id))
    if near:
        text += f"\nWarning: that's very close to the color of: {', '.join(near)}. Members may be hard to tell apart."
    return text


async def rename(guild: discord.Guild, store: Store, legion: Legion, new_name: str, why: str) -> str:
    clean = " ".join(new_name.split())
    if not clean:
        return "The new name can't be empty."
    if clean == legion.name:
        return f"**{legion.name}** already has that name."
    taken = store.legion_by_name(guild.id, clean)
    if taken is not None and taken.id != legion.id:
        return f"There is already a Legion named **{taken.name}**."
    reason = f"Legion {legion.name} renamed to {clean}"
    role = guild.get_role(legion.role_id or 0)
    if role is not None:
        await role.edit(name=roles.legion_role_name(clean), reason=reason)
    channel = guild.get_channel(legion.channel_id or 0)
    if isinstance(channel, discord.TextChannel):
        await channel.edit(name=applications.slug(clean, f"legion-{legion.id}"),
                           topic=f"Private channel of the Legion {clean}.", reason=reason)
    store.rename_legion(legion.id, clean)
    updated = store.get_legion(legion.id)
    if updated is not None:
        await ensure_legion_panel(guild, store, updated)
    text = f"**{legion.name}** is now called **{clean}** ({why})."
    await _legion_channel_say(guild, legion, text)
    await applications.bot_log(guild, store, text)
    return text


async def disband(guild: discord.Guild, store: Store, legion: Legion, why: str) -> str:
    members = store.legion_members(legion.id)
    for m in members:
        store.remove_membership(guild.id, m.user_id)
        await _strip_approval(guild, store, m.user_id, legion, f"Legion {legion.name} disbanded")
    for app in store.pending_member_applications(legion.id):
        app = store.decide(app.id, "denied", guild.me.id, f"The Legion {legion.name} was disbanded.")
        applicant = guild.get_member(app.applicant_id)
        await applications._after_decision(guild, store, app, [applicant] if applicant else [])
        await applications._announce(guild, store, app, applicant,
                                     f"The Legion **{legion.name}** was disbanded, so this application closed.")
    channel = guild.get_channel(legion.channel_id or 0)
    text = (f"The Legion **{legion.name}** was disbanded ({why}). {len(members)} member(s) lost "
            "their approval.")
    if isinstance(channel, discord.TextChannel):
        try:
            transcript = await applications.transcript_file(channel, f"legion-{legion.id}.txt")
            await applications.bot_log(guild, store, text, file=transcript)
        except discord.HTTPException:
            await applications.bot_log(guild, store, text + " (Transcript failed.)")
        try:
            await channel.delete(reason=f"Legion {legion.name} disbanded")
        except discord.HTTPException:
            log.warning("Could not delete channel of Legion %s", legion.id)
    else:
        await applications.bot_log(guild, store, text)
    role = guild.get_role(legion.role_id or 0)
    if role is not None:
        try:
            await role.delete(reason=f"Legion {legion.name} disbanded")
        except discord.HTTPException:
            log.warning("Could not delete role of Legion %s", legion.id)
    store.delete_legion(legion.id)
    for m in members:
        person = guild.get_member(m.user_id)
        if person is not None:
            await applications.dm(person, f"**{guild.name}**: the Legion **{legion.name}** was disbanded, "
                                          "so you are no longer approved.")
    await ensure_control_panel(guild, store)
    return text


async def member_left(member: discord.Member, store: Store) -> None:
    """Someone left the server: take them out of their Legion (disband if commander)."""
    guild = member.guild
    membership = store.membership(guild.id, member.id)
    async with applications._lock:
        if membership is not None:
            legion = store.get_legion(membership.legion_id)
            if legion is not None:
                await remove_member(guild, store, legion, member.id, f"{member} left the server")
                return
        # Not in a Legion, but may still be in the Faction Commander race.
        store.withdraw_everywhere(guild.id, member.id)
        async with siege._lock:
            term = siege._current_term(store, guild, member.id)
            if term is not None:
                await siege.hand_over(guild, store, term, f"<@{member.id}> left the server")


# --- panels -----------------------------------------------------------------------
ACTIONS = {
    "remove": ("Remove a member", discord.ButtonStyle.secondary, "🚪"),
    "transfer": ("Transfer command", discord.ButtonStyle.secondary, "👑"),
    "rename": ("Rename", discord.ButtonStyle.secondary, "✏️"),
    "color": ("Change color", discord.ButtonStyle.secondary, "🎨"),
    "disband": ("Disband", discord.ButtonStyle.danger, "🏴"),
}


def legion_panel_text(legion: Legion) -> str:
    return (f"## {legion.name}: Legion management\n"
            f"Commander: <@{legion.commander_id}>\n"
            f"Color: {colors.describe(legion.color)}\n"
            "The commander (or the Head Admin) can remove members, hand over command, rename, "
            "change the Legion's color or disband it with the buttons below.")


class LegionButton(
    discord.ui.DynamicItem[discord.ui.Button],
    template=r"aion2:lg:(?P<legion_id>[0-9]+):(?P<action>remove|transfer|rename|color|disband)",
):
    def __init__(self, legion_id: int, action: str) -> None:
        label, style, emoji = ACTIONS[action]
        super().__init__(discord.ui.Button(
            label=label, style=style, emoji=emoji, custom_id=f"aion2:lg:{legion_id}:{action}",
        ))
        self.legion_id = legion_id
        self.action = action

    @classmethod
    async def from_custom_id(
        cls, interaction: discord.Interaction, item: discord.ui.Button, match: re.Match[str], /
    ) -> LegionButton:
        return cls(int(match["legion_id"]), match["action"])

    async def callback(self, interaction: discord.Interaction) -> None:
        try:
            await start_action(interaction, self.legion_id, self.action)
        except Exception as exc:
            await ui_errors.report(interaction, exc)


def legion_view(legion_id: int) -> discord.ui.View:
    view = discord.ui.View(timeout=None)
    for action in ACTIONS:
        view.add_item(LegionButton(legion_id, action))
    return view


async def ensure_legion_panel(guild: discord.Guild, store: Store, legion: Legion, force: bool = False) -> bool:
    await ensure_control_panel(guild, store)  # keeps its Legion count current
    channel = guild.get_channel(legion.channel_id or 0)
    if not isinstance(channel, discord.TextChannel):
        return False
    return await siege._upsert(channel, store, panel_key(legion.id), legion_panel_text(legion),
                               legion_view(legion.id), force=force)


def control_text(guild: discord.Guild, store: Store) -> str:
    n = len(store.list_legions(guild.id))
    return ("## Legion control\n"
            f"{n} approved Legion(s). Pick an action, then the Legion. Commanders also have these "
            "buttons in their own Legion's channel.")


class ControlPanel(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=None)
        for action, (label, style, emoji) in ACTIONS.items():
            button = discord.ui.Button(label=label, style=style, emoji=emoji, custom_id=f"aion2:lgc:{action}")
            button.callback = self._pick_legion(action)  # type: ignore[method-assign]
            self.add_item(button)

    @staticmethod
    def _pick_legion(action: str):
        async def callback(interaction: discord.Interaction) -> None:
            member = interaction.user
            if interaction.guild is None or not isinstance(member, discord.Member):
                return
            if not roles.is_head_admin(member):
                await _reply(interaction, "Only the Head Admin can use the Legion control panel.")
                return
            legions = store_of(interaction).list_legions(interaction.guild.id)
            if not legions:
                await _reply(interaction, "No Legion has been approved yet.")
                return
            await _reply(interaction, f"{ACTIONS[action][0]}: which Legion?", LegionChooser(legions, action))
        return callback


class LegionChooser(SafeView):
    PAGE = 25

    def __init__(self, legions: list[Legion], action: str, page: int = 0) -> None:
        super().__init__(timeout=120)
        self.legions, self.action = legions, action
        pages = max(1, -(-len(legions) // self.PAGE))
        shown = legions[page * self.PAGE:(page + 1) * self.PAGE]
        select = discord.ui.Select(
            placeholder="Choose a Legion" + (f" (page {page + 1}/{pages})" if pages > 1 else ""),
            options=[discord.SelectOption(label=lg.name[:100], value=str(lg.id)) for lg in shown],
        )

        async def picked(interaction: discord.Interaction) -> None:
            await start_action(interaction, int(select.values[0]), action)
        select.callback = picked  # type: ignore[method-assign]
        self.add_item(select)
        if pages > 1:
            for label, target in (("◀ Previous", page - 1), ("Next ▶", page + 1)):
                button = discord.ui.Button(label=label, disabled=not 0 <= target < pages)

                async def turn(interaction: discord.Interaction, target: int = target) -> None:
                    await interaction.response.edit_message(view=LegionChooser(self.legions, self.action, target))
                button.callback = turn  # type: ignore[method-assign]
                self.add_item(button)


async def ensure_control_panel(guild: discord.Guild, store: Store, force: bool = False) -> list[str]:
    channel = siege._channel(guild, store, layout.LEGION_CONTROL)
    if channel is None:
        return []
    if await siege._upsert(channel, store, CONTROL_KEY, control_text(guild, store), ControlPanel(), force=force):
        return [f"Posted the Legion control panel in {channel.mention}."]
    return []


async def ensure_panels(guild: discord.Guild, store: Store) -> list[str]:
    """The Head Admin panel plus every Legion's own panel. Used by setup."""
    notes = await ensure_control_panel(guild, store, force=True)
    for legion in store.list_legions(guild.id):
        if await ensure_legion_panel(guild, store, legion, force=True):
            notes.append(f"Posted the management panel for **{legion.name}**.")
    return notes


# --- the action flows -----------------------------------------------------------
async def _check(interaction: discord.Interaction, legion_id: int) -> tuple[discord.Guild, discord.Member, Legion] | None:
    guild = interaction.guild
    actor = interaction.user
    if guild is None or not isinstance(actor, discord.Member):
        return None
    legion = store_of(interaction).get_legion(legion_id)
    if legion is None or legion.guild_id != guild.id:
        await _reply(interaction, "That Legion no longer exists.")
        return None
    if not may_manage(actor, legion):
        await _reply(interaction, f"Only the commander of **{legion.name}** or the Head Admin can do that.")
        return None
    return guild, actor, legion


def _who(actor: discord.Member, legion: Legion) -> str:
    return "by its commander" if actor.id == legion.commander_id else "by the Head Admin"


async def start_action(interaction: discord.Interaction, legion_id: int, action: str) -> None:
    checked = await _check(interaction, legion_id)
    if checked is None:
        return
    _, actor, legion = checked
    if action == "add":
        # Head Admin tool only (not on the commander's panel): add someone without a ticket.
        if not roles.is_head_admin(actor):
            await _reply(interaction, "Only the Head Admin can add members directly.")
            return
        await _reply(interaction, f"Who should join **{legion.name}**?", MemberPicker(legion_id, "add"))
    elif action == "rename":
        await interaction.response.send_modal(RenameModal(legion))
    elif action == "color":
        await interaction.response.send_modal(ColorModal(legion))
    elif action == "disband":
        await _reply(interaction, f"Disband **{legion.name}**? Everyone in it loses the Legion role and their "
                                  "approval, and its channel is deleted (a transcript goes to the bot log).",
                     Confirm(legion_id, "disband", None))
    else:
        verb = "remove from" if action == "remove" else "make commander of"
        await _reply(interaction, f"Who do you want to {verb} **{legion.name}**?", MemberPicker(legion_id, action))


class MemberPicker(SafeView):
    def __init__(self, legion_id: int, action: str) -> None:
        super().__init__(timeout=120)
        self.legion_id, self.action = legion_id, action

    @discord.ui.select(cls=discord.ui.UserSelect, placeholder="Choose a member of the Legion")
    async def pick(self, interaction: discord.Interaction, select: discord.ui.UserSelect) -> None:
        checked = await _check(interaction, self.legion_id)
        if checked is None:
            return
        guild, _, legion = checked
        target_id = select.values[0].id
        store = store_of(interaction)
        membership = store.membership(guild.id, target_id)
        if self.action == "add":
            problem = _cannot_add(guild, store, target_id)
            if problem:
                await _reply(interaction, problem)
                return
            await _reply(interaction, f"Add <@{target_id}> to **{legion.name}** as a member, without a ticket?",
                         Confirm(self.legion_id, "add", target_id))
            return
        if membership is None or membership.legion_id != legion.id:
            await _reply(interaction, f"<@{target_id}> isn't a member of **{legion.name}**.")
            return
        if self.action == "remove":
            if target_id == legion.commander_id:
                text = (f"<@{target_id}> is the **commander**. Removing them **disbands {legion.name}**: "
                        "everyone loses the Legion role and approval. Continue?")
            else:
                text = f"Remove <@{target_id}> from **{legion.name}**? They lose the Legion role and approval."
        else:
            if target_id == legion.commander_id:
                await _reply(interaction, f"<@{target_id}> already commands **{legion.name}**.")
                return
            text = (f"Make <@{target_id}> the commander of **{legion.name}**? <@{legion.commander_id}> stays "
                    "on as a regular member.")
        await _reply(interaction, text, Confirm(self.legion_id, self.action, target_id))


class Confirm(SafeView):
    def __init__(self, legion_id: int, action: str, target_id: int | None) -> None:
        super().__init__(timeout=60)
        self.legion_id, self.action, self.target_id = legion_id, action, target_id

    @discord.ui.button(label="Yes, do it", style=discord.ButtonStyle.danger)
    async def yes(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="Working…", view=None)
        store = store_of(interaction)
        async with applications._lock:
            checked = await _check(interaction, self.legion_id)  # still allowed, still exists?
            if checked is None:
                return
            guild, actor, legion = checked
            why = _who(actor, legion)
            if self.action == "remove":
                assert self.target_id is not None
                text = await remove_member(guild, store, legion, self.target_id, why)
            elif self.action == "transfer":
                assert self.target_id is not None
                text = await transfer(guild, store, legion, self.target_id, why)
            elif self.action == "add":
                assert self.target_id is not None
                text = await add_member(guild, store, legion, self.target_id)
            else:
                text = await disband(guild, store, legion, why)
        await _reply(interaction, text)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def no(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="Nothing changed.", view=None)


class RenameModal(discord.ui.Modal, title="Rename Legion"):
    name = discord.ui.TextInput(label="New Legion name", max_length=40)

    def __init__(self, legion: Legion) -> None:
        super().__init__()
        self.legion_id = legion.id
        self.name.default = legion.name

    async def on_submit(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer(ephemeral=True, thinking=True)
        store = store_of(interaction)
        async with applications._lock:
            checked = await _check(interaction, self.legion_id)
            if checked is None:
                return
            guild, actor, legion = checked
            text = await rename(guild, store, legion, str(self.name.value), _who(actor, legion))
        await _reply(interaction, text)

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await applications._form_failed(interaction, error)


class ColorModal(discord.ui.Modal, title="Legion color"):
    rgb = discord.ui.TextInput(
        label="Red, Green, Blue (0-255 each)", max_length=20, required=False,
        placeholder="e.g. 200, 30, 60. Leave blank to remove the color.",
    )
    brightness = discord.ui.TextInput(
        label="Brightness, 0-100 (blank = 100)", max_length=4, required=False,
        placeholder="100 = exact color, 50 = half as bright",
    )

    def __init__(self, legion: Legion) -> None:
        super().__init__()
        self.legion_id = legion.id
        if legion.color is not None:
            self.rgb.default = ", ".join(str(c) for c in colors.channels(legion.color))

    async def on_submit(self, interaction: discord.Interaction) -> None:
        color, problem = colors.parse(str(self.rgb.value or ""), str(self.brightness.value or ""))
        if problem:
            await _reply(interaction, f"{problem} Nothing was changed.")
            return
        await interaction.response.defer(ephemeral=True, thinking=True)
        store = store_of(interaction)
        async with applications._lock:
            checked = await _check(interaction, self.legion_id)
            if checked is None:
                return
            guild, actor, legion = checked
            text = await set_color(guild, store, legion, color, _who(actor, legion))
        await _reply(interaction, text)

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await applications._form_failed(interaction, error)
