"""`/setup server`: build the roles, categories and channels from `layout.py`.

Who may run it: members with the Head Admin role. If no Head Admin role exists
yet (a brand-new server), the server owner may run it once; that run creates the
role and gives it to the owner, and from then on only Head Admin may run it.

Setup is safe to run again. It only *creates* what is missing, matched by name
(or, for a channel the bot uses, by the ID it remembered, so a channel renamed
by hand is still found). It never deletes, renames, moves or re-permissions
anything that already exists, so hand-made channels and edits are left alone.
It also records which channel serves which purpose and posts (or refreshes) the
application buttons.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass

import discord
from discord import app_commands

import applications
import layout
import roles
from layout import ADMIN, APPROVED, PUBLIC, READ_ONLY, Category, Channel
from storage import Store

log = logging.getLogger("aion2_bot.setup")

Overwrites = dict[discord.Role | discord.Member, discord.PermissionOverwrite]

REASON = "Server setup (/setup server)"

# One setup run per server at a time, so two runs cannot both create a channel.
_locks: dict[int, asyncio.Lock] = {}


@dataclass(frozen=True)
class ServerRoles:
    head_admin: discord.Role
    commander: discord.Role
    member: discord.Role


def overwrites_for(access: str, guild: discord.Guild, r: ServerRoles) -> Overwrites:
    """Permission overwrites for one access level."""
    bot = guild.me
    if access == PUBLIC:
        return {bot: roles.bot_overwrite()}
    if access == READ_ONLY:
        return {
            guild.default_role: discord.PermissionOverwrite(
                view_channel=True, send_messages=False, create_public_threads=False,
                create_private_threads=False, send_messages_in_threads=False,
            ),
            r.head_admin: discord.PermissionOverwrite(view_channel=True, send_messages=True),
            bot: roles.bot_overwrite(),
        }
    if access == APPROVED:
        seen = discord.PermissionOverwrite(view_channel=True, connect=True)
        return {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
            r.commander: seen,
            r.member: seen,
            r.head_admin: seen,
            bot: roles.bot_overwrite(),
        }
    if access == ADMIN:
        return {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
            r.head_admin: discord.PermissionOverwrite(view_channel=True, connect=True),
            bot: roles.bot_overwrite(),
        }
    raise ValueError(f"Unknown access level: {access!r}")


def _find_category(guild: discord.Guild, name: str) -> discord.CategoryChannel | None:
    wanted = name.strip().casefold()
    return next((c for c in guild.categories if c.name.strip().casefold() == wanted), None)


def _find_channel(category: discord.CategoryChannel, ch: Channel) -> discord.abc.GuildChannel | None:
    wanted = layout.normalize_channel_name(ch.name, ch.kind)
    pool = category.text_channels if ch.kind == "text" else category.voice_channels
    return next((c for c in pool if layout.normalize_channel_name(c.name, ch.kind) == wanted), None)


def _remembered(guild: discord.Guild, store: Store, purpose: str | None, cls: type) -> object | None:
    """The channel/category the bot recorded for a purpose, if it still exists."""
    if purpose is None:
        return None
    found = guild.get_channel(store.get_config_id(guild.id, purpose) or 0)
    return found if isinstance(found, cls) else None


async def build_layout(
    guild: discord.Guild, r: ServerRoles, store: Store
) -> tuple[list[str], list[str]]:
    """Create every missing category and channel. Returns (created, already_there)."""
    created: list[str] = []
    existing: list[str] = []
    for cat in layout.LAYOUT:
        category = _remembered(guild, store, cat.purpose, discord.CategoryChannel) \
            or _find_category(guild, cat.name)
        if category is None:
            category = await guild.create_category(
                cat.name, overwrites=overwrites_for(cat.access, guild, r), reason=REASON,
            )
            created.append(f"📁 {cat.name}")
        else:
            existing.append(f"📁 {category.name}")
        assert isinstance(category, discord.CategoryChannel)
        if cat.purpose is not None:
            store.set_config(guild.id, cat.purpose, category.id)
        await _build_channels(guild, r, store, cat, category, created, existing)
    return created, existing


async def _build_channels(
    guild: discord.Guild,
    r: ServerRoles,
    store: Store,
    cat: Category,
    category: discord.CategoryChannel,
    created: list[str],
    existing: list[str],
) -> None:
    for ch in cat.channels:
        label = f"#{ch.name}" if ch.kind == "text" else f"🔊 {ch.name}"
        found = _remembered(guild, store, ch.purpose, discord.TextChannel) or _find_channel(category, ch)
        if found is None:
            # A channel with its own access gets its own overwrites; otherwise it is
            # created with the category's, which keeps it synced to the category.
            overwrites = overwrites_for(ch.access or cat.access, guild, r)
            if ch.kind == "text":
                found = await category.create_text_channel(
                    ch.name, topic=ch.topic or None, overwrites=overwrites, reason=REASON,
                )
            else:
                found = await category.create_voice_channel(ch.name, overwrites=overwrites, reason=REASON)
            created.append(f"{label} ({cat.name})")
        else:
            existing.append(f"{label} ({cat.name})")
        if ch.purpose is not None:
            store.set_config(guild.id, ch.purpose, found.id)


async def _ensure_roles(
    guild: discord.Guild, owner: discord.Member, head_admin: discord.Role | None, notes: list[str]
) -> ServerRoles:
    if head_admin is None:
        head_admin = roles.find_role(guild, layout.HEAD_ADMIN_ROLE)
    if head_admin is None:
        head_admin = await _create_head_admin(guild, owner, notes)
    found: list[discord.Role] = []
    for name in (layout.COMMANDER_ROLE, layout.MEMBER_ROLE):
        role = roles.find_role(guild, name)
        if role is None:
            role = await guild.create_role(name=name, hoist=True, reason=REASON)
            notes.append(f"Created the **{name}** role.")
        found.append(role)
    return ServerRoles(head_admin=head_admin, commander=found[0], member=found[1])


async def _create_head_admin(guild: discord.Guild, owner: discord.Member, notes: list[str]) -> discord.Role:
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
    notes.append(note)
    return role


def _missing_bot_permissions(guild: discord.Guild) -> list[str]:
    perms = guild.me.guild_permissions
    # Manage Roles/Channels to create things; the rest because setting a
    # permission overwrite (allow or deny) requires the bot to hold it itself.
    needed = (
        ("Manage Roles", perms.manage_roles), ("Manage Channels", perms.manage_channels),
        ("View Channels", perms.view_channel), ("Send Messages", perms.send_messages),
        ("Manage Messages", perms.manage_messages), ("Read Message History", perms.read_message_history),
        ("Embed Links", perms.embed_links), ("Attach Files", perms.attach_files),
        ("Connect", perms.connect), ("Create Public Threads", perms.create_public_threads),
        ("Create Private Threads", perms.create_private_threads),
        ("Send Messages in Threads", perms.send_messages_in_threads),
    )
    return [name for name, ok in needed if not ok]


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


setup_group = app_commands.Group(
    name="setup", description="Server setup commands. [Head Admin]", guild_only=True,
)


@setup_group.command(
    name="server",
    description="Create the server's roles, categories and channels. Only adds what is missing. [Head Admin]",
)
async def setup_server(interaction: discord.Interaction) -> None:
    guild = interaction.guild
    member = interaction.user
    if guild is None or not isinstance(member, discord.Member):
        await interaction.response.send_message("Run this inside the server.", ephemeral=True)
        return
    store: Store = interaction.client.store  # type: ignore[attr-defined]

    head_admin = roles.find_role(guild, layout.HEAD_ADMIN_ROLE)
    if head_admin is None:
        if member.id != guild.owner_id:
            await interaction.response.send_message(
                f"There is no **{layout.HEAD_ADMIN_ROLE}** role on this server yet. "
                "The server owner must run `/setup server` first; that creates the role.",
                ephemeral=True,
            )
            return
    elif not roles.is_head_admin(member):
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

    missing = _missing_bot_permissions(guild)
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
            server_roles = await _ensure_roles(guild, member, head_admin, notes)
            created, existing = await build_layout(guild, server_roles, store)
            notes += await applications.ensure_panels(guild, store)
    except discord.Forbidden as exc:
        log.warning("Setup forbidden in %s: %s", guild.id, exc)
        await interaction.followup.send(
            f"Discord refused one of the bot's actions: `{exc.text}`\n"
            "Anything created before that point was kept. Check that the bot's role has the "
            "permissions above and sits **above** the "
            f"**{layout.HEAD_ADMIN_ROLE}**, **{layout.COMMANDER_ROLE}** and **{layout.MEMBER_ROLE}** "
            "roles in **Server Settings → Roles**, then run `/setup server` again: it picks up "
            "where it stopped.",
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
    await applications.bot_log(
        guild, store, f"🛠️ {member.mention} ran `/setup server`: {len(created)} item(s) created.",
    )
