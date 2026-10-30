"""The server layout `/setup server` builds: roles, categories and channels.

This is the one file to edit to change what setup creates. The setup logic in
`setup_server.py` reads it and never hard-codes a channel name.

DRAFT: the categories and channels below are a placeholder until the owner
gives the real list.

Access levels (set on a category; a channel may override its category's):
  PUBLIC     everyone can see and post.
  READ_ONLY  everyone can see; only Head Admin (and the bot) can post.
  ADMIN      only Head Admin (and the bot) can see it at all.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

# The role that gates `/setup server`. Matched by name, ignoring case.
HEAD_ADMIN_ROLE = "Head Admin"

PUBLIC = "public"
READ_ONLY = "read_only"
ADMIN = "admin"

Access = Literal["public", "read_only", "admin"]
Kind = Literal["text", "voice"]


@dataclass(frozen=True)
class Channel:
    name: str
    kind: Kind = "text"
    topic: str = ""
    # None = inherit the category's access (the channel stays synced to it).
    access: Access | None = None


@dataclass(frozen=True)
class Category:
    name: str
    access: Access = PUBLIC
    channels: tuple[Channel, ...] = field(default_factory=tuple)


LAYOUT: tuple[Category, ...] = (
    Category("Information", READ_ONLY, (
        Channel("welcome", topic="Start here."),
        Channel("rules", topic="Server rules."),
        Channel("announcements", topic="News from the Head Admin."),
    )),
    Category("General", PUBLIC, (
        Channel("general"),
        Channel("screenshots"),
        Channel("off-topic"),
    )),
    Category("Aion 2", PUBLIC, (
        Channel("looking-for-group", topic="Find a party for dungeons, raids and PvP."),
        Channel("sieges"),
        Channel("raids"),
        Channel("builds-and-gear"),
    )),
    Category("Voice", PUBLIC, (
        Channel("General", kind="voice"),
        Channel("Raid 1", kind="voice"),
        Channel("Raid 2", kind="voice"),
        Channel("Siege", kind="voice"),
    )),
    Category("Head Admin", ADMIN, (
        Channel("admin-chat"),
        Channel("bot-log", topic="What the bot did, and when."),
    )),
)


def validate(layout: tuple[Category, ...] | None = None) -> list[str]:
    """Return a list of problems with a layout (empty when it is usable)."""
    if layout is None:
        layout = LAYOUT
    problems: list[str] = []
    seen_categories: set[str] = set()
    for cat in layout:
        key = cat.name.casefold()
        if key in seen_categories:
            problems.append(f"Category '{cat.name}' is listed twice.")
        seen_categories.add(key)
        seen_channels: set[tuple[str, str]] = set()
        for ch in cat.channels:
            ch_key = (ch.kind, normalize_channel_name(ch.name, ch.kind))
            if ch_key in seen_channels:
                problems.append(f"Channel '{ch.name}' is listed twice in '{cat.name}'.")
            seen_channels.add(ch_key)
            if ch.kind == "voice" and (ch.access or cat.access) == READ_ONLY:
                problems.append(
                    f"Voice channel '{ch.name}' in '{cat.name}' cannot be read-only; "
                    "use public or admin."
                )
    return problems


def normalize_channel_name(name: str, kind: Kind) -> str:
    """The name Discord will actually give a channel, for matching existing ones.

    Discord lowercases text-channel names and turns spaces into hyphens; voice
    channel names keep their case. Comparison ignores case either way.
    """
    if kind == "text":
        name = "-".join(name.strip().lower().split())
    return name.strip().casefold()
