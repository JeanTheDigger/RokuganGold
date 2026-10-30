"""`/setup server`: build the categories and channels from `layout.py`.

Who may run it: members with the Head Admin role. If no Head Admin role exists
yet (a brand-new server), the server owner may run it once; that run creates the
role and gives it to the owner, and from then on only Head Admin may run it.

Setup is safe to run again. It only *creates* what is missing, matched by name.
It never deletes, renames, moves or re-permissions anything that already exists,
so channels and permissions edited by hand are left alone.
"""

from __future__ import annotations

import asyncio
import logging

import discord
from discord import app_commands

import layout
from layout import ADMIN, PUBLIC, READ_ONLY, Category, Channel

log = logging.getLogger("aion2_bot.setup")

Overwrites = dict[discord.Role | discord.Member, discord.PermissionOverwrite]

REASON = "Server setup (/setup server)"

# One setup run per server at a time, so two runs cannot both create a channel.
_locks: dict[int, asyncio.Lock] = {}


def find_head_admin_role(guild: discord.Guild) -> discord.Role | None:
    wanted = layout.HEAD_ADMIN_ROLE.casefold()
    return next((r for r in guild.roles if r.name.casefold() == wanted), None)


def is_head_admin(member: discord.Member) -> bool:
    wanted = layout.HEAD_ADMIN_ROLE.casefold()
    return any(r.name.casefold() == wanted for r in member.roles)


def overwrites_for(
    access: str, guild: discord.Guild, head_admin: discord.Role
) -> Overwrites:
    """Permission overwrites for one access level."""
    bot = guild.me
    bot_ow = discord.PermissionOverwrite(
        view_channel=True, send_messages=True, manage_channels=True,
        manage_messages=True, connect=True,
    )
    if access == PUBLIC:
        return {bot: bot_ow}
    if access == READ_ONLY:
        return {
            guild.default_role: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, create_public_threads=False, create_private_threads=False,
                send_messages_in_threads=False,
            ),
            head_admin: discord.PermissionOverwrite(view_channel=True, send_messages=True),
            bot: bot_ow,
        }
    if access == ADMIN:
        return {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
            head_admin: discord.PermissionOverwrite(view_channel=True, connect=True),
            bot: bot_ow,
        }
    raise ValueError(f"Unknown access level: {access!r}")


def _find_category(guild: discord.Guild, name: str) -> discord.CategoryChannel | None:
    wanted = name.strip().casefold()
    return next((c for c in guild.categories if c.name.strip().casefold() == wanted), None)


def _find_channel(category: discord.CategoryChannel, ch: Channel) -> discord.abc.GuildChannel | None:
    wanted = layout.normalize_channel_name(ch.name, ch.kind)
    pool = category.text_channels if ch.kind == "text" else category.voice_channels
    return next((c for c in pool if layout.normalize_channel_name(c.name, ch.kind) == wanted), None)


async def build_layout(
    guild: discord.Guild, head_admin: discord.Role
) -> tuple[list[str], list[str]]:
    """Create every missing category and channel. Returns (created, already_there)."""
    created: list[str] = []
    existing: list[str] = []
    for cat in layout.LAYOUT:
        category = _find_category(guild, cat.name)
        if category is None:
            category = await guild.create_category(
                cat.name, overwrites=overwrites_for(cat.access, guild, head_admin), reason=REASON,
            )
            created.append(f"📁 {cat.name}")
        else:
            existing.append(f"📁 {cat.name}")
        await _build_channels(guild, head_admin, cat, category, created, existing)
    return created, existing


async def _build_channels(
    guild: discord.Guild,
    head_admin: discord.Role,
    cat: Category,
    category: discord.CategoryChannel,
    created: list[str],
    existing: list[str],
) -> None:
    for ch in cat.channels:
        label = f"#{ch.name}" if ch.kind == "text" else f"🔊 {ch.name}"
        if _find_channel(category, ch) is not None:
            existing.append(f"{label} ({cat.name})")
            continue
        # A channel with its own access gets its own overwrites; otherwise it is
        # created with the category's, which keeps it synced to the category.
        access = ch.access or cat.access
        overwrites = overwrites_for(access, guild, head_admin)
        if ch.kind == "text":
            await category.create_text_channel(
                ch.name, topic=ch.topic or None, overwrites=overwrites, reason=REASON,
            )
        else:
            await category.create_voice_channel(ch.name, overwrites=overwrites, reason=REASON)
        created.append(f"{label} ({cat.name})")


def _missing_bot_permissions(guild: discord.Guild, need_roles: bool) -> list[str]:
    perms = guild.me.guild_permissions
    missing: list[str] = []
    if not perms.manage_channels:
        missing.append("Manage Channels")
    if need_roles and not perms.manage_roles:
        missing.append("Manage Roles")
    # Setting a permission overwrite (allow or deny) requires the bot to hold
    # that permission itself, so it needs every one `overwrites_for` touches.
    for name, ok in (
        ("View Channels", perms.view_channel), ("Send Messages", perms.send_messages),
        ("Manage Messages", perms.manage_messages), ("Connect", perms.connect),
        ("Create Public Threads", perms.create_public_threads),
        ("Create Private Threads", perms.create_private_threads),
        ("Send Messages in Threads", perms.send_messages_in_threads),
    ):
        if not ok:
            missing.append(name)
    return missing


def _summary(created: list[str], existing: list[str], notes: list[str]) -> str:
    lines: list[str] = ["**Server setup complete.**"]
    lines += notes
    if created:
        lines.append(f"\n**Created ({len(created)}):**")
        lines += [f"• {item}" for item in created]
    else:
        lines.append("\nNothing was missing; nothing was created.")
    if existing:
        lines.append(f"\n**Already there, left untouched ({len(existing)}):** "
                     + ", ".join(existing))
    text = "\n".join(lines)
    return text if len(text) <= 1900 else text[:1890] + "\n…"


async def _post_to_bot_log(guild: discord.Guild, user: discord.abc.User, created: list[str]) -> None:
    """Note the run in #bot-log, if the layout has one and it exists."""
    for cat in layout.LAYOUT:
        if not any(ch.name == "bot-log" for ch in cat.channels):
            continue
        category = _find_category(guild, cat.name)
        target = category and _find_channel(category, Channel("bot-log"))
        if isinstance(target, discord.TextChannel):
            try:
                await target.send(
                    f"🛠️ {user.mention} ran `/setup server`: "
                    f"{len(created)} item(s) created.",
                    allowed_mentions=discord.AllowedMentions.none(),
                )
            except discord.HTTPException:
                log.warning("Could not post to #bot-log in %s", guild.id)
        return


async def _create_head_admin(guild: discord.Guild, owner: discord.Member) -> tuple[discord.Role, str]:
    """First run: create the Head Admin role and give it to the server owner.

    The role gets Administrator when the bot can grant it; Discord forbids a
    bot from creating a role with a permission it does not hold itself.
    """
    can_grant_admin = guild.me.guild_permissions.administrator
    role = await guild.create_role(
        name=layout.HEAD_ADMIN_ROLE,
        permissions=discord.Permissions(administrator=can_grant_admin),
        hoist=True,
        reason=f"{REASON}: first run by the server owner",
    )
    await owner.add_roles(role, reason=f"{REASON}: server owner becomes Head Admin")
    note = f"Created the **{role.name}** role and gave it to you."
    if not can_grant_admin:
        note += (" The bot is not an Administrator, so it could not give the role Administrator; "
                 "turn that on yourself in **Server Settings → Roles** if you want it.")
    return role, note


setup_group = app_commands.Group(
    name="setup", description="Server setup commands. [Head Admin]", guild_only=True,
)


@setup_group.command(
    name="server",
    description="Create the server's categories and channels. Only adds what is missing. [Head Admin]",
)
async def setup_server(interaction: discord.Interaction) -> None:
    guild = interaction.guild
    member = interaction.user
    if guild is None or not isinstance(member, discord.Member):
        await interaction.response.send_message("Run this inside the server.", ephemeral=True)
        return

    head_admin = find_head_admin_role(guild)
    bootstrapping = head_admin is None
    if bootstrapping:
        if member.id != guild.owner_id:
            await interaction.response.send_message(
                f"There is no **{layout.HEAD_ADMIN_ROLE}** role on this server yet. "
                "The server owner must run `/setup server` first; that creates the role.",
                ephemeral=True,
            )
            return
    elif not is_head_admin(member):
        await interaction.response.send_message(
            f"Only members with the **{head_admin.name}** role can run server setup.",
            ephemeral=True,
        )
        return

    problems = layout.validate()
    if problems:
        await interaction.response.send_message(
            "The server layout in `layout.py` has problems; nothing was changed:\n"
            + "\n".join(f"• {p}" for p in problems),
            ephemeral=True,
        )
        return

    missing = _missing_bot_permissions(guild, need_roles=bootstrapping)
    if missing:
        await interaction.response.send_message(
            "The bot is missing permissions it needs for setup:\n"
            + "\n".join(f"• **{p}**" for p in missing)
            + "\n\nGive the bot's role those permissions in **Server Settings → Roles** "
            "(or re-invite it with **Administrator**), then run `/setup server` again.",
            ephemeral=True,
        )
        return

    lock = _locks.setdefault(guild.id, asyncio.Lock())
    if lock.locked():
        await interaction.response.send_message(
            "Server setup is already running here; wait for it to finish.", ephemeral=True,
        )
        return

    await interaction.response.defer(ephemeral=True, thinking=True)
    notes: list[str] = []
    try:
        async with lock:
            if head_admin is None:
                head_admin = find_head_admin_role(guild)
            if head_admin is None:
                head_admin, note = await _create_head_admin(guild, member)
                notes.append(note)
            created, existing = await build_layout(guild, head_admin)
    except discord.Forbidden as exc:
        log.warning("Setup forbidden in %s: %s", guild.id, exc)
        await interaction.followup.send(
            f"Discord refused one of the bot's actions: `{exc.text}`\n"
            "Anything created before that point was kept. Check that the bot's role has "
            "**Manage Channels** and **Manage Roles** and sits above the "
            f"**{layout.HEAD_ADMIN_ROLE}** role in **Server Settings → Roles**, then run "
            "`/setup server` again: it picks up where it stopped.",
            ephemeral=True,
        )
        return
    except discord.HTTPException as exc:
        log.exception("Setup failed in %s", guild.id)
        await interaction.followup.send(
            f"Setup stopped on a Discord error: `{exc}`\n"
            "Anything created before that point was kept; run `/setup server` again to finish.",
            ephemeral=True,
        )
        return

    log.info("Setup in %s by %s: created %d, existing %d", guild.id, member.id, len(created), len(existing))
    await interaction.followup.send(_summary(created, existing, notes), ephemeral=True)
    await _post_to_bot_log(guild, member, created)
