"""Legion commander and Legion member applications, handled as private tickets.

Commander: the applicant clicks "Apply as Legion Commander" in the commander
applications room and fills in who they are and which Legion they lead. A
private ticket channel opens for them and the Head Admin. The Head Admin
approves or denies. Approving approves the commander *and* their Legion: the
Legion gets its own role ("Legion: <name>") and private channel, and from then
on members can apply to it.

Member: the applicant clicks "Apply to a Legion", picks an approved Legion and
fills in who they are. A private ticket opens for them, the Head Admin and that
Legion's commander. Both the commander and the Head Admin must approve (one
person holding both counts for both); either may deny.

An approved person gets the Legion Commander or Legion Member role plus their
Legion's role, which opens the approved category and their Legion's channel.
Each person belongs to one Legion and has one open application at a time.

After the decision the ticket goes read-only for the applicant (and commander);
the Head Admin's "Close ticket" button saves a transcript to the bot log and
deletes the channel. Buttons keep working across bot restarts.
"""

from __future__ import annotations

import asyncio
import datetime as dt
import io
import logging
import re

import discord
from discord import app_commands

import colors
import layout
import roles
from storage import Application, Legion, Store
from ui_errors import SafeView

log = logging.getLogger("aion2_bot.applications")

# Serialises decisions and ticket creation, so a double click or two people
# clicking at once can never approve twice or open two tickets.
_lock = asyncio.Lock()

# Discord allows at most 50 channels in one category.
CATEGORY_LIMIT = 50

# After a denial, the applicant waits this long before applying again.
DENY_COOLDOWN = dt.timedelta(hours=24)
# A ticket still waiting gets a reminder this long after it opened, then as often again.
REMINDER_EVERY = dt.timedelta(hours=24)

COMMANDER_PANEL_TEXT = (
    "## Legion Commander applications\n"
    "Do you lead an Asmodian Legion? Click the button below and tell us who you are "
    "and which Legion you lead. A private ticket opens between you and the Head Admin.\n\n"
    "When you are approved, **your Legion is approved with you**: it gets its own role and "
    "private channel, and its members can then apply to join it."
)
MEMBER_PANEL_TEXT = (
    "## Legion Member applications\n"
    "Are you in an approved Legion? Click the button below, pick your Legion and tell us "
    "who you are. A private ticket opens between you, the Head Admin and your Legion's "
    "commander. **Both** confirm you before you are let in.\n\n"
    "Your Legion isn't in the list? Its commander has to apply and be approved first."
)


# --- small helpers ----------------------------------------------------------
def store_of(interaction: discord.Interaction) -> Store:
    return interaction.client.store  # type: ignore[attr-defined]


def configured(guild: discord.Guild, store: Store, purpose: str, cls: type) -> object | None:
    """The channel or category `/setup server` recorded for a purpose, if it still exists."""
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found if isinstance(found, cls) else None


async def bot_log(
    guild: discord.Guild, store: Store, text: str, *, file: discord.File | None = None,
    embed: discord.Embed | None = None,
) -> None:
    channel = configured(guild, store, layout.BOT_LOG, discord.TextChannel)
    if not isinstance(channel, discord.TextChannel):
        return
    kwargs: dict[str, object] = {"allowed_mentions": discord.AllowedMentions.none()}
    if file is not None:
        kwargs["file"] = file
    if embed is not None:
        kwargs["embed"] = embed
    try:
        await channel.send(text, **kwargs)  # type: ignore[arg-type]
    except discord.HTTPException:
        log.warning("Could not post to the bot log in %s", guild.id)


def slug(text: str, fallback: str) -> str:
    """A Discord-friendly channel name: lowercase words joined by hyphens."""
    s = re.sub(r"[^\w-]+", "-", text.strip().lower(), flags=re.UNICODE)
    s = re.sub(r"-{2,}", "-", s).strip("-_")
    return s[:90] or fallback


async def get_member(guild: discord.Guild, user_id: int) -> discord.Member | None:
    member = guild.get_member(user_id)
    if member is not None:
        return member
    try:
        return await guild.fetch_member(user_id)
    except discord.NotFound:
        return None


async def dm(user: discord.abc.User, text: str) -> None:
    """Best-effort direct message; people may have DMs closed."""
    try:
        await user.send(text)
    except discord.HTTPException:
        pass


async def reply(interaction: discord.Interaction, text: str) -> None:
    """An ephemeral answer, whether or not the interaction was already answered."""
    if interaction.response.is_done():
        await interaction.followup.send(text, ephemeral=True)
    else:
        await interaction.response.send_message(text, ephemeral=True)


def ticket_overwrites(
    guild: discord.Guild, head_admin: discord.Role | None, people: list[discord.Member]
) -> dict[discord.Role | discord.Member, discord.PermissionOverwrite]:
    """The applicant (and commander), Head Admin and Officers can see and talk."""
    talk = discord.PermissionOverwrite(
        view_channel=True, send_messages=True, read_message_history=True,
        attach_files=True, embed_links=True,
    )
    ow: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
        guild.default_role: discord.PermissionOverwrite(view_channel=False),
        guild.me: roles.bot_overwrite(),
    }
    if head_admin is not None:
        ow[head_admin] = talk
    officer = roles.find_role(guild, layout.OFFICER_ROLE)
    if officer is not None:
        ow[officer] = talk
    for person in people:
        ow[person] = talk
    return ow


# --- panels -------------------------------------------------------------------
class CommanderPanel(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Apply as Legion Commander", style=discord.ButtonStyle.primary,
                       emoji="🛡️", custom_id="aion2:apply:commander")
    async def apply(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _refuse_new_application(interaction):
            return
        await interaction.response.send_modal(CommanderModal())


class MemberPanel(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Apply to a Legion", style=discord.ButtonStyle.primary,
                       emoji="⚔️", custom_id="aion2:apply:member")
    async def apply(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _refuse_new_application(interaction):
            return
        assert interaction.guild is not None
        legions = store_of(interaction).list_legions(interaction.guild.id)
        if not legions:
            await reply(interaction, "No Legion has been approved yet. Your commander has to apply "
                                     "in the commander applications room first.")
            return
        await interaction.response.send_message(
            "Which Legion are you in?", view=LegionPicker(legions), ephemeral=True,
        )


async def ensure_panels(guild: discord.Guild, store: Store) -> list[str]:
    """Post each application button message, or refresh it if already posted."""
    notes: list[str] = []
    for purpose, text, view in (
        (layout.COMMANDER_APPLY, COMMANDER_PANEL_TEXT, CommanderPanel()),
        (layout.MEMBER_APPLY, MEMBER_PANEL_TEXT, MemberPanel()),
    ):
        channel = configured(guild, store, purpose, discord.TextChannel)
        if not isinstance(channel, discord.TextChannel):
            continue
        key = f"panel:{purpose}"
        message_id = store.get_config_id(guild.id, key)
        if message_id is not None:
            try:
                await channel.get_partial_message(message_id).edit(content=text, view=view)
                continue
            except discord.NotFound:
                pass  # deleted by hand: post a fresh one
        message = await channel.send(text, view=view)
        store.set_config(guild.id, key, message.id)
        notes.append(f"Posted the application button in {channel.mention}.")
    return notes


async def _refuse_new_application(interaction: discord.Interaction) -> bool:
    """Answer and return True when this person may not open an application now."""
    guild = interaction.guild
    if guild is None:
        return True
    store = store_of(interaction)
    pending = store.open_application_for(guild.id, interaction.user.id)
    if pending is not None:
        where = f" <#{pending.channel_id}>" if pending.channel_id else ""
        await reply(interaction, f"You already have an application waiting for a decision:{where}")
        return True
    membership = store.membership(guild.id, interaction.user.id)
    if membership is not None:
        legion = store.get_legion(membership.legion_id)
        name = legion.name if legion else "a Legion"
        await reply(interaction, f"You are already approved in **{name}**. "
                                 "Ask the Head Admin if that needs to change.")
        return True
    until = cooldown_ends(guild, store, interaction.user.id)
    if until is not None:
        await reply(interaction, f"Your last application was denied. You can apply again "
                                 f"<t:{int(until.timestamp())}:R>.")
        return True
    if not isinstance(configured(guild, store, layout.TICKETS, discord.CategoryChannel),
                      discord.CategoryChannel):
        await reply(interaction, "Applications aren't set up yet. Ask the Head Admin to run `/setup server`.")
        return True
    return False


def cooldown_ends(guild: discord.Guild, store: Store, user_id: int) -> dt.datetime | None:
    """When this person may apply again after a denial, or None if they may now.

    Denials the bot made itself (the Legion was disbanded) don't count, and the
    Head Admin can lift a cooldown early.
    """
    denial = store.last_denial(guild.id, user_id)
    if denial is None or denial.decided_at is None or denial.decided_by == guild.me.id:
        return None
    denied_at = dt.datetime.fromisoformat(denial.decided_at)
    lifted = store.get_config(guild.id, f"cooldown_lift:{user_id}")
    if lifted is not None and dt.datetime.fromisoformat(lifted) >= denied_at:
        return None
    until = denied_at + DENY_COOLDOWN
    return until if dt.datetime.now(dt.timezone.utc) < until else None


# --- forms --------------------------------------------------------------------
async def _form_failed(interaction: discord.Interaction, error: Exception) -> None:
    """A form's handler raised: tell the person instead of leaving them on "thinking…"."""
    log.exception("Form failed", exc_info=error)
    text = (f"Discord refused part of that: `{error}`. Ask the Head Admin to check the bot's "
            "permissions and role position." if isinstance(error, discord.HTTPException)
            else "Something went wrong; the error has been logged. Please try again.")
    try:
        await reply(interaction, text)
    except discord.HTTPException:
        pass


class CommanderModal(discord.ui.Modal, title="Legion Commander application"):
    character = discord.ui.TextInput(label="Your character name", max_length=32)
    legion = discord.ui.TextInput(label="Name of the Legion you lead", max_length=40)
    about = discord.ui.TextInput(
        label="Who you are", style=discord.TextStyle.paragraph, max_length=1000,
        placeholder="Your role in the Legion, its size, anything that helps us verify you.",
    )
    rgb = discord.ui.TextInput(
        label="Legion color: Red, Green, Blue (0-255)", max_length=20, required=False,
        placeholder="e.g. 200, 30, 60. Leave blank for no color.",
    )
    brightness = discord.ui.TextInput(
        label="Color brightness, 0-100 (blank = 100)", max_length=4, required=False,
        placeholder="100 = exact color, 50 = half as bright",
    )

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await _form_failed(interaction, error)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        color, problem = colors.parse(str(self.rgb.value or ""), str(self.brightness.value or ""))
        if problem:
            # A form can't be shown again with an error, so hand back what they wrote.
            await interaction.response.send_message(
                f"{problem} Nothing was submitted; click **Apply as Legion Commander** again.\n"
                f"Your answers, to copy back:\n```\n{self.character.value}\n{self.legion.value}\n"
                f"{self.about.value}\n```", ephemeral=True,
            )
            return
        await _open_ticket(
            interaction, "commander", str(self.character.value), str(self.about.value),
            legion_name=" ".join(str(self.legion.value).split()), legion_color=color,
        )


class MemberModal(discord.ui.Modal):
    character = discord.ui.TextInput(label="Your character name", max_length=32)
    about = discord.ui.TextInput(
        label="Anything your commander should know", style=discord.TextStyle.paragraph,
        max_length=1000, required=False,
    )

    def __init__(self, legion: Legion) -> None:
        super().__init__(title=f"Join {legion.name}"[:45])
        self.legion_id = legion.id

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await _form_failed(interaction, error)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        await _open_ticket(
            interaction, "member", str(self.character.value), str(self.about.value or ""),
            legion_id=self.legion_id,
        )


class LegionPicker(SafeView):
    """Pick a Legion; pages of 25 (Discord's limit for one menu)."""

    PAGE = 25

    def __init__(self, legions: list[Legion], page: int = 0) -> None:
        super().__init__(timeout=300)
        self.legions = legions
        self.page = page
        pages = max(1, -(-len(legions) // self.PAGE))
        shown = legions[page * self.PAGE:(page + 1) * self.PAGE]
        select = discord.ui.Select(
            placeholder="Choose your Legion" + (f" (page {page + 1}/{pages})" if pages > 1 else ""),
            options=[discord.SelectOption(label=lg.name[:100], value=str(lg.id)) for lg in shown],
        )
        select.callback = self._picked  # type: ignore[method-assign]
        self.select = select
        self.add_item(select)
        if pages > 1:
            for label, target in (("◀ Previous", page - 1), ("Next ▶", page + 1)):
                button = discord.ui.Button(label=label, disabled=not 0 <= target < pages)
                button.callback = self._turn(target)  # type: ignore[method-assign]
                self.add_item(button)

    def _turn(self, target: int):
        async def callback(interaction: discord.Interaction) -> None:
            await interaction.response.edit_message(view=LegionPicker(self.legions, target))
        return callback

    async def _picked(self, interaction: discord.Interaction) -> None:
        legion = store_of(interaction).get_legion(int(self.select.values[0]))
        if legion is None:
            await reply(interaction, "That Legion no longer exists. Click the apply button again.")
            return
        await interaction.response.send_modal(MemberModal(legion))


# --- opening a ticket ---------------------------------------------------------
async def _open_ticket(
    interaction: discord.Interaction, kind: str, character: str, about: str,
    legion_name: str | None = None, legion_id: int | None = None, legion_color: int | None = None,
) -> None:
    guild = interaction.guild
    applicant = interaction.user
    if guild is None or not isinstance(applicant, discord.Member):
        return
    store = store_of(interaction)
    await interaction.response.defer(ephemeral=True, thinking=True)
    async with _lock:
        # Checked again: things may have changed while the form was open.
        if await _refuse_new_application(interaction):
            return
        people: list[discord.Member] = [applicant]
        legion: Legion | None = None
        if kind == "commander":
            assert legion_name is not None
            if not legion_name:
                await reply(interaction, "The Legion name can't be empty.")
                return
            if store.legion_by_name(guild.id, legion_name) is not None:
                await reply(interaction, f"A Legion named **{legion_name}** is already approved. "
                                         "If you are in it, apply as a member instead.")
                return
        else:
            legion = store.get_legion(legion_id or 0)
            if legion is None:
                await reply(interaction, "That Legion no longer exists. Click the apply button again.")
                return
            commander = await get_member(guild, legion.commander_id)
            if commander is None:
                await reply(interaction, f"The commander of **{legion.name}** is no longer on the server, "
                                         "so they can't confirm you. Ask the Head Admin.")
                return
            if commander.id != applicant.id:
                people.append(commander)

        category = configured(guild, store, layout.TICKETS, discord.CategoryChannel)
        assert isinstance(category, discord.CategoryChannel)
        if len(category.channels) >= CATEGORY_LIMIT:
            await reply(interaction, "There are too many open tickets right now. Try again later, "
                                     "or tell the Head Admin.")
            return

        head_admin = roles.find_role(guild, layout.HEAD_ADMIN_ROLE)
        channel = await category.create_text_channel(
            slug(f"{kind}-{applicant.display_name}", f"{kind}-{applicant.id}"),
            overwrites=ticket_overwrites(guild, head_admin, people),
            topic=f"{kind.title()} application by {applicant} ({applicant.id})",
            reason=f"{kind.title()} application",
        )
        app = store.create_application(
            guild.id, kind, applicant.id, character.strip(), about.strip(),
            legion_name=legion_name, legion_id=legion.id if legion else None, legion_color=legion_color,
        )
        pings = " ".join(p.mention for p in people)
        if head_admin is not None:
            pings += f" {head_admin.mention}"
        message = await channel.send(
            pings, embed=ticket_embed(store, app), view=ticket_view(app),
            allowed_mentions=discord.AllowedMentions(users=True, roles=True),
        )
        store.update_application(app.id, channel_id=channel.id, message_id=message.id)

    await reply(interaction, f"Your application is open: {channel.mention}. "
                             "You'll be told there when a decision is made.")
    target = f"**{legion_name}**" if kind == "commander" else f"**{legion.name if legion else '?'}**"
    await bot_log(guild, store, f"📝 {applicant.mention} applied as {kind} of {target}: {channel.mention}")


# --- the ticket message -------------------------------------------------------
def ticket_embed(store: Store, app: Application) -> discord.Embed:
    if app.kind == "commander":
        title = "Legion Commander application"
        legion_text = app.legion_name or "?"
    else:
        legion = store.get_legion(app.legion_id or 0)
        legion_text = legion.name if legion else "(Legion no longer exists)"
        title = f"Legion Member application: {legion_text}"
    colour = {"pending": discord.Colour.gold(), "approved": discord.Colour.green(),
              "denied": discord.Colour.red()}[app.status]
    embed = discord.Embed(title=title, colour=colour)
    embed.add_field(name="Applicant", value=f"<@{app.applicant_id}>")
    embed.add_field(name="Character", value=app.character_name or "-")
    embed.add_field(name="Legion", value=legion_text)
    if app.kind == "commander":
        near = colors.close_to(app.legion_color, store.legion_colors(app.guild_id))
        warn = f"\n⚠️ Very close to: {', '.join(near)}" if near else ""
        embed.add_field(name="Legion color", value=colors.describe(app.legion_color) + warn, inline=False)
    if app.about:
        embed.add_field(name="About", value=app.about[:1024], inline=False)

    if app.status == "pending":
        if app.kind == "commander":
            status = "⏳ Waiting for the Head Admin."
            others = store.pending_commander_claims(app.guild_id, app.legion_name or "", app.id)
            if others:
                status += ("\n⚠️ Another pending application also claims to lead this Legion: "
                           + ", ".join(f"<@{o.applicant_id}>" for o in others))
        else:
            legion = store.get_legion(app.legion_id or 0)
            cmdr = (f"✅ <@{app.commander_approved_by}>" if app.commander_approved_by
                    else f"⏳ waiting for <@{legion.commander_id}>" if legion else "⏳ waiting")
            admin = f"✅ <@{app.admin_approved_by}>" if app.admin_approved_by else "⏳ waiting"
            status = f"Commander: {cmdr}\nHead Admin: {admin}\nBoth must approve; either may deny."
    elif app.status == "approved" and app.kind == "member":
        status = (f"✅ Approved by the commander (<@{app.commander_approved_by}>) "
                  f"and the Head Admin (<@{app.admin_approved_by}>).")
    elif app.status == "approved":
        status = f"✅ Approved by <@{app.decided_by}>."
    else:
        status = f"❌ Denied by <@{app.decided_by}>." + (f"\nReason: {app.reason}" if app.reason else "")
    embed.add_field(name="Status", value=status, inline=False)
    embed.set_footer(text=f"Application #{app.id}")
    return embed


class TicketButton(
    discord.ui.DynamicItem[discord.ui.Button],
    template=r"aion2:app:(?P<app_id>[0-9]+):(?P<action>approve|deny|close)",
):
    STYLES = {
        "approve": ("Approve", discord.ButtonStyle.success, "✅"),
        "deny": ("Deny", discord.ButtonStyle.danger, "✖️"),
        "close": ("Close ticket", discord.ButtonStyle.secondary, "🔒"),
    }

    def __init__(self, app_id: int, action: str) -> None:
        label, style, emoji = self.STYLES[action]
        super().__init__(discord.ui.Button(
            label=label, style=style, emoji=emoji, custom_id=f"aion2:app:{app_id}:{action}",
        ))
        self.app_id = app_id
        self.action = action

    @classmethod
    async def from_custom_id(
        cls, interaction: discord.Interaction, item: discord.ui.Button, match: re.Match[str], /
    ) -> TicketButton:
        return cls(int(match["app_id"]), match["action"])

    async def callback(self, interaction: discord.Interaction) -> None:
        try:
            if self.action == "approve":
                await _approve(interaction, self.app_id)
            elif self.action == "deny":
                await _start_deny(interaction, self.app_id)
            else:
                await _close(interaction, self.app_id)
        except discord.HTTPException as exc:
            log.exception("Ticket %s failed on application %s", self.action, self.app_id)
            await reply(interaction, f"Discord refused part of that: `{exc}`. Nothing was approved "
                                     "twice; check the bot's permissions and role position, then try again.")


def ticket_view(app: Application) -> discord.ui.View:
    view = discord.ui.View(timeout=None)
    if app.status == "pending":
        view.add_item(TicketButton(app.id, "approve"))
        view.add_item(TicketButton(app.id, "deny"))
    elif app.closed_at is None:
        view.add_item(TicketButton(app.id, "close"))
    return view


async def _refresh(guild: discord.Guild, store: Store, app: Application) -> None:
    channel = guild.get_channel(app.channel_id or 0)
    if isinstance(channel, discord.TextChannel) and app.message_id:
        try:
            await channel.get_partial_message(app.message_id).edit(
                embed=ticket_embed(store, app), view=ticket_view(app),
            )
        except discord.HTTPException:
            log.warning("Could not update ticket message for application %s", app.id)


async def _load(interaction: discord.Interaction, app_id: int) -> tuple[discord.Guild, discord.Member, Application] | None:
    guild = interaction.guild
    actor = interaction.user
    app = store_of(interaction).get_application(app_id)
    if guild is None or not isinstance(actor, discord.Member) or app is None or app.guild_id != guild.id:
        await reply(interaction, "This application no longer exists.")
        return None
    return guild, actor, app


# --- approving ----------------------------------------------------------------
async def _approve(interaction: discord.Interaction, app_id: int) -> None:
    loaded = await _load(interaction, app_id)
    if loaded is None:
        return
    guild, actor, _ = loaded
    store = store_of(interaction)
    # Answer Discord now: another decision may hold the lock for a few seconds
    # (creating roles and channels), longer than Discord waits for a reply.
    await interaction.response.defer()
    async with _lock:
        app = store.get_application(app_id)
        assert app is not None
        if app.status != "pending":
            await reply(interaction, "This application has already been decided.")
            return
        if actor.id == app.applicant_id:
            await reply(interaction, "You can't approve your own application.")
            return
        if app.kind == "commander":
            if not roles.is_head_admin(actor):
                await reply(interaction, "Only the Head Admin can approve a Legion Commander.")
                return
            error = await _finalize_commander(guild, store, app, actor)
        else:
            legion = store.get_legion(app.legion_id or 0)
            if legion is None:
                await reply(interaction, "This Legion no longer exists; deny the application instead.")
                return
            is_admin = roles.is_head_admin(actor)
            is_cmdr = actor.id == legion.commander_id
            if not (is_admin or is_cmdr):
                await reply(interaction, f"Only the Head Admin and the commander of **{legion.name}** "
                                         "can approve this.")
                return
            updates: dict[str, object] = {}
            if is_admin and app.admin_approved_by is None:
                updates["admin_approved_by"] = actor.id
            if is_cmdr and app.commander_approved_by is None:
                updates["commander_approved_by"] = actor.id
            if not updates:
                await reply(interaction, "You have already approved; waiting for the other approval.")
                return
            completes = (app.admin_approved_by or updates.get("admin_approved_by")) and \
                        (app.commander_approved_by or updates.get("commander_approved_by"))
            if completes:
                error = await _finalize_member(guild, store, app, legion, actor, updates)
            else:
                app = store.update_application(app.id, **updates)
                await _refresh(guild, store, app)
                side = "the Head Admin" if "admin_approved_by" in updates else "the commander"
                waiting = "the commander" if app.commander_approved_by is None else "the Head Admin"
                await interaction.followup.send(
                    f"✅ {actor.mention} approved as {side}. Waiting for {waiting}.",
                    allowed_mentions=discord.AllowedMentions.none(),
                )
                return
    if error:
        await reply(interaction, error)


async def _finalize_commander(
    guild: discord.Guild, store: Store, app: Application, actor: discord.Member
) -> str | None:
    """Approve a commander and their Legion. Returns an error message, or None."""
    name = app.legion_name or ""
    if store.legion_by_name(guild.id, name) is not None:
        return f"A Legion named **{name}** has already been approved. Deny this application instead."
    applicant = await get_member(guild, app.applicant_id)
    if applicant is None:
        return "The applicant has left the server. Deny the application instead."
    if store.membership(guild.id, applicant.id) is not None:
        return "The applicant already belongs to a Legion."
    made = await create_legion(guild, store, name, applicant, app.legion_color, "approved")
    if isinstance(made, str):
        return made
    legion, channel = made
    app = store.update_application(app.id, admin_approved_by=actor.id)
    app = store.decide(app.id, "approved", actor.id)
    await _after_decision(guild, store, app, [applicant])
    await _announce(guild, store, app, applicant,
                    f"✅ Approved as commander of **{name}** by {actor.mention}. Your Legion is approved: "
                    f"members can now apply to it, and your Legion channel is {channel.mention}.")
    return None


async def create_legion(
    guild: discord.Guild, store: Store, name: str, commander: discord.Member, color: int | None, how: str,
) -> tuple[Legion, discord.TextChannel] | str:
    """Make a Legion: its role (colored), private channel and panel; the commander
    gets Legion Commander + the Legion role. Returns (legion, channel) or an error.
    Used by commander approval and by the Head Admin's "Create a Legion" tool.
    """
    if store.legion_by_name(guild.id, name) is not None:
        return f"A Legion named **{name}** already exists."
    if store.membership(guild.id, commander.id) is not None:
        return f"{commander.mention} already belongs to a Legion."
    commander_role = roles.find_role(guild, layout.COMMANDER_ROLE)
    head_admin = roles.find_role(guild, layout.HEAD_ADMIN_ROLE)
    category = configured(guild, store, layout.LEGIONS, discord.CategoryChannel)
    if commander_role is None or not isinstance(category, discord.CategoryChannel):
        return "The server isn't fully set up. Run `/setup server`, then try again."
    if len(category.channels) >= CATEGORY_LIMIT:
        return f"The Legions category is full ({CATEGORY_LIMIT} channels, Discord's limit)."

    reason = f"Legion {name} {how}"
    legion_role = roles.find_role(guild, roles.legion_role_name(name))
    new_role: discord.Role | None = None
    channel: discord.TextChannel | None = None
    try:
        if legion_role is None:
            legion_role = new_role = await guild.create_role(
                name=roles.legion_role_name(name), colour=discord.Colour(color or 0), reason=reason,
            )
        elif color is not None:
            await legion_role.edit(colour=discord.Colour(color), reason=reason)
        overwrites: dict[discord.Role | discord.Member, discord.PermissionOverwrite] = {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
            legion_role: discord.PermissionOverwrite(view_channel=True),
            guild.me: roles.bot_overwrite(),
        }
        if head_admin is not None:
            overwrites[head_admin] = discord.PermissionOverwrite(view_channel=True)
        channel = await category.create_text_channel(
            slug(name, f"legion-{commander.id}"), overwrites=overwrites,
            topic=f"Private channel of the Legion {name}.", reason=reason,
        )
        legion = store.create_legion(guild.id, name, commander.id, legion_role.id, channel.id, color=color)
    except Exception:
        # Undo the half-made Legion so trying again starts clean.
        for leftover in (channel, new_role):
            if leftover is not None:
                try:
                    await leftover.delete(reason="Legion creation failed")
                except discord.HTTPException:
                    pass
        raise

    await commander.add_roles(commander_role, legion_role, reason=reason)
    await channel.send(
        f"Welcome, {commander.mention}. This is the private channel of **{legion.name}**; "
        "members you approve will see it too.",
    )
    import legions  # here, not at the top: legions imports this module
    await legions.ensure_legion_panel(guild, store, legion)
    return legion, channel


async def remind_tick(guild: discord.Guild, store: Store, now: dt.datetime) -> None:
    """Remind whoever still has to decide a ticket: 24 h after it opened, then daily.

    After downtime it posts one reminder, not one per missed day.
    """
    head_admin = roles.find_role(guild, layout.HEAD_ADMIN_ROLE)
    for app in store.pending_applications(guild.id):
        waited = now - dt.datetime.fromisoformat(app.created_at)
        due = int(waited // REMINDER_EVERY)
        if due <= app.reminders_sent:
            continue
        store.update_application(app.id, reminders_sent=due)
        channel = guild.get_channel(app.channel_id or 0)
        if not isinstance(channel, discord.TextChannel):
            continue
        needed: list[str] = []
        if app.kind == "member" and not app.commander_approved_by:
            legion = store.get_legion(app.legion_id or 0)
            if legion is not None:
                needed.append(f"<@{legion.commander_id}> (the Legion's commander)")
        if not app.admin_approved_by:
            needed.append(f"{head_admin.mention if head_admin else 'the Head Admin'} (Head Admin)")
        if not needed:
            continue
        days = waited.days
        try:
            await channel.send(
                f"⏰ This application has been waiting {days} day{'s' if days != 1 else ''}. "
                f"Still needed: {', '.join(needed)}.",
                allowed_mentions=discord.AllowedMentions(users=True, roles=True),
            )
        except discord.HTTPException:
            log.warning("Could not post reminder for application %s", app.id)


async def _finalize_member(
    guild: discord.Guild, store: Store, app: Application, legion: Legion,
    actor: discord.Member, updates: dict[str, object],
) -> str | None:
    """The second approval came in: let the member in. Returns an error message, or None."""
    applicant = await get_member(guild, app.applicant_id)
    if applicant is None:
        return "The applicant has left the server. Deny the application instead."
    if store.membership(guild.id, applicant.id) is not None:
        return "The applicant already belongs to a Legion."
    member_role = roles.find_role(guild, layout.MEMBER_ROLE)
    if member_role is None:
        return "The server isn't fully set up. Run `/setup server`, then approve again."
    give: list[discord.Role] = [member_role]
    legion_role = guild.get_role(legion.role_id or 0)
    if legion_role is not None:
        give.append(legion_role)
    await applicant.add_roles(*give, reason=f"Approved member of {legion.name}")
    store.add_member(guild.id, applicant.id, legion.id)
    app = store.update_application(app.id, **updates)
    app = store.decide(app.id, "approved", actor.id)
    await _after_decision(guild, store, app, [applicant])
    note = "" if legion_role else f"\n⚠️ The **{roles.legion_role_name(legion.name)}** role is missing, so it wasn't given."
    await _announce(guild, store, app, applicant,
                    f"✅ Approved as a member of **{legion.name}** (commander and Head Admin both agreed).{note}")
    legion_channel = guild.get_channel(legion.channel_id or 0)
    if isinstance(legion_channel, discord.TextChannel):
        await legion_channel.send(f"Welcome to **{legion.name}**, {applicant.mention}.")
    return None


# --- denying ------------------------------------------------------------------
class DenyModal(discord.ui.Modal, title="Deny application"):
    reason = discord.ui.TextInput(
        label="Reason (shown to the applicant)", style=discord.TextStyle.paragraph,
        max_length=500, required=False,
    )

    def __init__(self, app_id: int) -> None:
        super().__init__()
        self.app_id = app_id

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await _form_failed(interaction, error)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        loaded = await _load(interaction, self.app_id)
        if loaded is None:
            return
        guild, actor, _ = loaded
        store = store_of(interaction)
        await interaction.response.defer()
        async with _lock:
            app = store.get_application(self.app_id)
            assert app is not None
            if app.status != "pending":
                await reply(interaction, "This application has already been decided.")
                return
            if not _may_decide(store, app, actor):
                await reply(interaction, "You can't deny this application.")
                return
            app = store.decide(app.id, "denied", actor.id, str(self.reason.value or "").strip())
            applicant = await get_member(guild, app.applicant_id)
            await _after_decision(guild, store, app, [applicant] if applicant else [])
        why = f" Reason: {app.reason}" if app.reason else ""
        await _announce(guild, store, app, applicant, f"❌ Denied by {actor.mention}.{why}")


def _may_decide(store: Store, app: Application, actor: discord.Member) -> bool:
    if roles.is_head_admin(actor):
        return True
    if app.kind == "member":
        legion = store.get_legion(app.legion_id or 0)
        return legion is not None and legion.commander_id == actor.id
    return False


async def _start_deny(interaction: discord.Interaction, app_id: int) -> None:
    loaded = await _load(interaction, app_id)
    if loaded is None:
        return
    _, actor, app = loaded
    if app.status != "pending":
        await reply(interaction, "This application has already been decided.")
        return
    if not _may_decide(store_of(interaction), app, actor):
        who = "the Head Admin" if app.kind == "commander" else "the Head Admin and the Legion's commander"
        await reply(interaction, f"Only {who} can deny this.")
        return
    await interaction.response.send_modal(DenyModal(app_id))


# --- after a decision, and closing --------------------------------------------
async def _after_decision(
    guild: discord.Guild, store: Store, app: Application, applicants: list[discord.Member]
) -> None:
    """Update the ticket message and make the ticket read-only for everyone but Head Admin."""
    await _refresh(guild, store, app)
    channel = guild.get_channel(app.channel_id or 0)
    if not isinstance(channel, discord.TextChannel):
        return
    people = list(applicants)
    if app.kind == "member":
        legion = store.get_legion(app.legion_id or 0)
        commander = guild.get_member(legion.commander_id) if legion else None
        if commander is not None and commander not in people:
            people.append(commander)
    for person in people:
        try:
            await channel.set_permissions(
                person, view_channel=True, send_messages=False, read_message_history=True,
                reason="Application decided",
            )
        except discord.HTTPException:
            log.warning("Could not lock ticket %s for %s", channel.id, person.id)


async def _announce(
    guild: discord.Guild, store: Store, app: Application, applicant: discord.Member | None, text: str
) -> None:
    channel = guild.get_channel(app.channel_id or 0)
    if isinstance(channel, discord.TextChannel):
        await channel.send(text, allowed_mentions=discord.AllowedMentions.none())
    if applicant is not None:
        await dm(applicant, f"**{guild.name}**: your application #{app.id}: {text}")
    await bot_log(guild, store, f"Application #{app.id} (<@{app.applicant_id}>, {app.kind}): {text}")


async def transcript_file(channel: discord.TextChannel, filename: str) -> discord.File:
    """The channel's whole history as a text file, oldest first."""
    lines: list[str] = []
    async for msg in channel.history(limit=None, oldest_first=True):
        stamp = msg.created_at.strftime("%Y-%m-%d %H:%M")
        body = msg.clean_content
        for e in msg.embeds:
            body += "\n" + "\n".join(
                [e.title or ""] + [f"{f.name}: {f.value}" for f in e.fields]
            )
        for a in msg.attachments:
            body += f"\n[attachment] {a.url}"
        lines.append(f"[{stamp} UTC] {msg.author}: {body}")
    return discord.File(io.BytesIO("\n".join(lines).encode("utf-8")), filename=filename)


async def _close(interaction: discord.Interaction, app_id: int) -> None:
    loaded = await _load(interaction, app_id)
    if loaded is None:
        return
    guild, actor, app = loaded
    store = store_of(interaction)
    if not (roles.is_head_admin(actor) or roles.has_role(actor, layout.OFFICER_ROLE)):
        await reply(interaction, "Only the Head Admin or an Officer can close a ticket.")
        return
    if app.status == "pending":
        await reply(interaction, "Approve or deny the application before closing the ticket.")
        return
    channel = interaction.channel
    if not isinstance(channel, discord.TextChannel):
        return
    await interaction.response.send_message("Saving the transcript and closing this ticket…")
    transcript = await transcript_file(channel, f"application-{app.id}.txt")
    await bot_log(guild, store, f"🔒 {actor.mention} closed the ticket for application #{app.id}.",
                  file=transcript, embed=ticket_embed(store, app))
    store.mark_closed(app.id)
    await channel.delete(reason=f"Ticket for application #{app.id} closed by {actor}")


# --- /legion ------------------------------------------------------------------
legion_group = app_commands.Group(name="legion", description="Approved Legions.", guild_only=True)


@legion_group.command(name="list", description="List the approved Legions, their commanders and sizes.")
async def legion_list(interaction: discord.Interaction) -> None:
    guild = interaction.guild
    if guild is None:
        return
    store = store_of(interaction)
    legions = store.list_legions(guild.id)
    if not legions:
        await reply(interaction, "No Legion has been approved yet.")
        return
    lines = [f"**Approved Legions ({len(legions)}):**"]
    for lg in legions:
        lines.append(f"• **{lg.name}**: commander <@{lg.commander_id}>, "
                     f"{store.member_count(lg.id)} approved (commander included), {colors.describe(lg.color)}")
    text = "\n".join(lines)
    await reply(interaction, text if len(text) <= 1900 else text[:1890] + "\n…")
