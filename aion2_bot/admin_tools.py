"""Head Admin tools: a button panel in the admin-tools channel.

  Edit rules          the rules live in one message in #rules; this opens a text box
                      with the current rules and replaces them.
  Post announcement   write a title and message, preview it, then post it in
                      #announcements with or without pinging everyone approved.
  Create a Legion     pick the commander, then name and color: the Legion is made
                      at once (role, channel, panel) with no ticket.
  Add a member        pick a Legion and a person: they join it at once, no ticket.
  Lift a cooldown     let someone who was denied apply again before 24 h are up.
"""

from __future__ import annotations

import datetime as dt
import logging

import discord

import applications
import colors
import layout
import legions
import roles
from storage import Store
from ui_errors import SafeView

log = logging.getLogger("aion2_bot.admin_tools")

PANEL_KEY = "msg:admin_tools"
RULES_KEY = "msg:rules"
RULES_TEXT_KEY = "rules_text"

PANEL_TEXT = (
    "## 🧰 Head Admin tools\n"
    "Only the Head Admin can use these buttons.\n"
    "• **Edit rules**: replace the rules shown in #rules.\n"
    "• **Post announcement**: write, preview, then post in #announcements (with or without a ping).\n"
    "• **Create a Legion**: make a Legion directly (commander, name, color), no ticket.\n"
    "• **Add a member**: put someone straight into a Legion, no ticket.\n"
    "• **Lift a cooldown**: let a denied person apply again now."
)


def store_of(interaction: discord.Interaction) -> Store:
    return interaction.client.store  # type: ignore[attr-defined]


def _channel(guild: discord.Guild, store: Store, purpose: str) -> discord.TextChannel | None:
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found if isinstance(found, discord.TextChannel) else None


async def _reply(interaction: discord.Interaction, text: str, view: discord.ui.View | None = None,
                 embed: discord.Embed | None = None) -> None:
    kwargs: dict[str, object] = {"ephemeral": True}
    if view is not None:
        kwargs["view"] = view
    if embed is not None:
        kwargs["embed"] = embed
    if interaction.response.is_done():
        await interaction.followup.send(text, **kwargs)  # type: ignore[arg-type]
    else:
        await interaction.response.send_message(text, **kwargs)  # type: ignore[arg-type]


async def _head_admin(interaction: discord.Interaction) -> discord.Guild | None:
    member = interaction.user
    if interaction.guild is None or not isinstance(member, discord.Member):
        return None
    if not roles.is_head_admin(member):
        await _reply(interaction, "Only the Head Admin can use these tools.")
        return None
    return interaction.guild


# --- panel and rules message ---------------------------------------------------
async def ensure_panel(guild: discord.Guild, store: Store) -> list[str]:
    notes: list[str] = []
    channel = _channel(guild, store, layout.ADMIN_TOOLS)
    if channel is not None:
        import siege  # the shared "edit or post" helper
        if await siege._upsert(channel, store, PANEL_KEY, PANEL_TEXT, ToolsPanel(), force=True):
            notes.append(f"Posted the Head Admin tools in {channel.mention}.")
    notes += await ensure_rules(guild, store)
    return notes


def rules_embed(guild: discord.Guild, store: Store) -> discord.Embed:
    text = store.get_config(guild.id, RULES_TEXT_KEY) or "_The Head Admin hasn't written the rules yet._"
    return discord.Embed(title=f"📜 {guild.name}: rules", description=text, colour=discord.Colour.gold())


async def ensure_rules(guild: discord.Guild, store: Store) -> list[str]:
    channel = _channel(guild, store, layout.RULES)
    if channel is None:
        return []
    message_id = store.get_config_id(guild.id, RULES_KEY)
    if message_id is not None:
        try:
            await channel.get_partial_message(message_id).edit(embed=rules_embed(guild, store))
            return []
        except discord.NotFound:
            pass
    message = await channel.send(embed=rules_embed(guild, store))
    store.set_config(guild.id, RULES_KEY, message.id)
    return [f"Posted the rules message in {channel.mention}."]


class ToolsPanel(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(label="Edit rules", emoji="📜", style=discord.ButtonStyle.secondary,
                       custom_id="aion2:tools:rules")
    async def rules(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        guild = await _head_admin(interaction)
        if guild is not None:
            await interaction.response.send_modal(RulesModal(store_of(interaction).get_config(guild.id, RULES_TEXT_KEY)))

    @discord.ui.button(label="Post announcement", emoji="📣", style=discord.ButtonStyle.primary,
                       custom_id="aion2:tools:announce")
    async def announce(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _head_admin(interaction) is not None:
            await interaction.response.send_modal(AnnouncementModal())

    @discord.ui.button(label="Create a Legion", emoji="🛡️", style=discord.ButtonStyle.secondary,
                       custom_id="aion2:tools:create")
    async def create(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _head_admin(interaction) is not None:
            await _reply(interaction, "Who commands the new Legion?", CommanderPicker())

    @discord.ui.button(label="Add a member", emoji="➕", style=discord.ButtonStyle.secondary,
                       custom_id="aion2:tools:add")
    async def add(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        found = store_of(interaction).list_legions(guild.id)
        if not found:
            await _reply(interaction, "No Legion exists yet. Use **Create a Legion** first.")
            return
        await _reply(interaction, "Add a member: which Legion?", legions.LegionChooser(found, "add"))

    @discord.ui.button(label="Lift a cooldown", emoji="⏳", style=discord.ButtonStyle.secondary,
                       custom_id="aion2:tools:lift")
    async def lift(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        if await _head_admin(interaction) is not None:
            await _reply(interaction, "Whose cooldown should be lifted?", CooldownPicker())


# --- rules -----------------------------------------------------------------------
class RulesModal(discord.ui.Modal, title="Server rules"):
    text = discord.ui.TextInput(
        label="Rules (replaces the current ones)", style=discord.TextStyle.paragraph, max_length=4000,
        placeholder="1. Be respectful.\n2. ...",
    )

    def __init__(self, current: str | None) -> None:
        super().__init__()
        if current:
            self.text.default = current

    async def on_submit(self, interaction: discord.Interaction) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        store = store_of(interaction)
        store.set_config(guild.id, RULES_TEXT_KEY, str(self.text.value).strip())
        await interaction.response.defer(ephemeral=True, thinking=True)
        await ensure_rules(guild, store)
        where = _channel(guild, store, layout.RULES)
        await _reply(interaction, f"Rules updated{f' in {where.mention}' if where else ''}.")
        await applications.bot_log(guild, store, f"📜 {interaction.user.mention} updated the rules.")

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await applications._form_failed(interaction, error)


# --- announcements -----------------------------------------------------------------
class AnnouncementModal(discord.ui.Modal, title="Announcement"):
    heading = discord.ui.TextInput(label="Title (optional)", max_length=200, required=False)
    body = discord.ui.TextInput(label="Message", style=discord.TextStyle.paragraph, max_length=4000)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        embed = discord.Embed(title=str(self.heading.value).strip() or None, description=str(self.body.value),
                              colour=discord.Colour.blurple(), timestamp=dt.datetime.now(dt.timezone.utc))
        embed.set_footer(text=f"From {interaction.user.display_name}")
        await _reply(interaction, "Preview. Post it?", AnnouncementConfirm(embed), embed=embed)

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await applications._form_failed(interaction, error)


class AnnouncementConfirm(SafeView):
    def __init__(self, embed: discord.Embed) -> None:
        super().__init__(timeout=600)
        self.embed = embed

    async def _post(self, interaction: discord.Interaction, ping: bool) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        store = store_of(interaction)
        channel = _channel(guild, store, layout.ANNOUNCEMENTS)
        if channel is None:
            await interaction.response.edit_message(content="There's no announcements channel; run "
                                                            "`/setup server`.", embed=None, view=None)
            return
        content = None
        allowed = discord.AllowedMentions.none()
        if ping:
            pinged = [r for r in (roles.find_role(guild, layout.COMMANDER_ROLE),
                                  roles.find_role(guild, layout.MEMBER_ROLE)) if r is not None]
            content = " ".join(r.mention for r in pinged) or None
            allowed = discord.AllowedMentions(roles=pinged)
        message = await channel.send(content, embed=self.embed, allowed_mentions=allowed)
        await interaction.response.edit_message(content=f"Posted: {message.jump_url}", embed=None, view=None)
        await applications.bot_log(guild, store, f"📣 {interaction.user.mention} posted an announcement: "
                                                 f"{message.jump_url}")

    @discord.ui.button(label="Post and ping everyone approved", style=discord.ButtonStyle.primary)
    async def with_ping(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await self._post(interaction, ping=True)

    @discord.ui.button(label="Post without a ping", style=discord.ButtonStyle.secondary)
    async def without_ping(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await self._post(interaction, ping=False)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.danger)
    async def cancel(self, interaction: discord.Interaction, _: discord.ui.Button) -> None:
        await interaction.response.edit_message(content="Not posted.", embed=None, view=None)


# --- create a Legion ------------------------------------------------------------------
class CommanderPicker(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=180)

    @discord.ui.select(cls=discord.ui.UserSelect, placeholder="Choose the commander")
    async def pick(self, interaction: discord.Interaction, select: discord.ui.UserSelect) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        commander = guild.get_member(select.values[0].id)
        if commander is None or commander.bot:
            await _reply(interaction, "Pick a person who is on the server.")
            return
        store = store_of(interaction)
        if store.membership(guild.id, commander.id) is not None:
            await _reply(interaction, f"{commander.mention} already belongs to a Legion.")
            return
        await interaction.response.send_modal(CreateLegionModal(commander.id))


class CreateLegionModal(discord.ui.Modal, title="Create a Legion"):
    name = discord.ui.TextInput(label="Legion name", max_length=40)
    rgb = discord.ui.TextInput(label="Color: Red, Green, Blue (0-255)", max_length=20, required=False,
                               placeholder="e.g. 200, 30, 60. Leave blank for no color.")
    brightness = discord.ui.TextInput(label="Brightness, 0-100 (blank = 100)", max_length=4, required=False)

    def __init__(self, commander_id: int) -> None:
        super().__init__()
        self.commander_id = commander_id

    async def on_submit(self, interaction: discord.Interaction) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        name = " ".join(str(self.name.value).split())
        color, problem = colors.parse(str(self.rgb.value or ""), str(self.brightness.value or ""))
        if problem or not name:
            await _reply(interaction, (problem or "The Legion name can't be empty.") + " Nothing was created.")
            return
        await interaction.response.defer(ephemeral=True, thinking=True)
        store = store_of(interaction)
        commander = guild.get_member(self.commander_id)
        if commander is None:
            await _reply(interaction, "That person is no longer on the server.")
            return
        async with applications._lock:
            made = await applications.create_legion(guild, store, name, commander, color,
                                                    "created by the Head Admin")
        if isinstance(made, str):
            await _reply(interaction, made)
            return
        legion, channel = made
        near = colors.close_to(color, store.legion_colors(guild.id, exclude_id=legion.id))
        warn = f"\n⚠️ The color is very close to: {', '.join(near)}." if near else ""
        text = (f"🛡️ The Head Admin created the Legion **{legion.name}** ({colors.describe(color)}) "
                f"with {commander.mention} as commander: {channel.mention}.")
        await applications.bot_log(guild, store, text)
        await applications.dm(commander, f"**{guild.name}**: the Head Admin made you commander of the new "
                                         f"Legion **{legion.name}**.")
        await _reply(interaction, text + warn)

    async def on_error(self, interaction: discord.Interaction, error: Exception) -> None:
        await applications._form_failed(interaction, error)


# --- lift a cooldown ----------------------------------------------------------------
class CooldownPicker(SafeView):
    def __init__(self) -> None:
        super().__init__(timeout=180)

    @discord.ui.select(cls=discord.ui.UserSelect, placeholder="Choose the person")
    async def pick(self, interaction: discord.Interaction, select: discord.ui.UserSelect) -> None:
        guild = await _head_admin(interaction)
        if guild is None:
            return
        store = store_of(interaction)
        user_id = select.values[0].id
        if applications.cooldown_ends(guild, store, user_id) is None:
            await _reply(interaction, f"<@{user_id}> can already apply; there's no cooldown to lift.")
            return
        store.set_config(guild.id, f"cooldown_lift:{user_id}", dt.datetime.now(dt.timezone.utc).isoformat())
        await _reply(interaction, f"Done: <@{user_id}> can apply again now.")
        await applications.bot_log(guild, store, f"⏳ {interaction.user.mention} lifted <@{user_id}>'s "
                                                 "application cooldown.")
