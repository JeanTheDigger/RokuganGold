"""The server layout `/setup server` builds: roles, categories and channels.

This is the one file to edit to change what setup creates. The setup logic in
`setup_server.py` reads it and never hard-codes a channel name. Channels the
bot itself uses (arrivals, the application rooms, tickets, Legion channels,
the log) are found by their `purpose`, not their name, so renaming one here is
safe.

Access levels (set on a category; a channel may override its category's):
  PUBLIC     everyone can see and post, including people with no role.
  READ_ONLY  everyone can see; only Head Admin (and the bot) can post.
  APPROVED   only approved Legion commanders and members (and Head Admin).
  APPROVED_BOT_ONLY  approved people can see it, but only the bot posts.
  FACTION_COMMAND    only the current Faction Commander and Head Admin.
  FACTION_COMMAND_BOT_ONLY  the same people see it, but only the bot posts.
  FACTION_LEADERS    the Faction Commander, every Legion Commander and Head Admin.
  COMMAND_VOICE      (voice only) every approved person can join and listen; only
                     the Faction Commander can speak.
  ADMIN      only Head Admin (and the bot) can see it at all.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

# --- Roles (matched by name, ignoring case) --------------------------------
# Gates `/setup server` and approves applications.
HEAD_ADMIN_ROLE = "Head Admin"
# Given to an approved Legion commander.
COMMANDER_ROLE = "Legion Commander"
# Given to an approved Legion member.
MEMBER_ROLE = "Legion Member"
# Held by the elected Faction Commander for one siege (see siege.py).
FACTION_COMMANDER_ROLE = "Faction Commander"
# Opt-in role pinged by siege reminders (see alerts.py).
SIEGE_ALERTS_ROLE = "Siege Alerts"
# Each approved Legion gets its own role, named this prefix + the Legion's name.
LEGION_ROLE_PREFIX = "Legion: "

PUBLIC = "public"
READ_ONLY = "read_only"
APPROVED = "approved"
APPROVED_BOT_ONLY = "approved_bot_only"
FACTION_COMMAND = "faction_command"
FACTION_COMMAND_BOT_ONLY = "faction_command_bot_only"
FACTION_LEADERS = "faction_leaders"
COMMAND_VOICE = "command_voice"
ADMIN = "admin"

Access = Literal["public", "read_only", "approved", "approved_bot_only", "faction_command",
                 "faction_command_bot_only", "faction_leaders", "command_voice", "admin"]
Kind = Literal["text", "voice"]

# --- Purposes: what the bot uses a channel or category for ------------------
ARRIVALS = "arrivals"                # "<member> entered the server." posts
COMMANDER_APPLY = "commander_apply"  # holds the "Apply as Legion Commander" button
MEMBER_APPLY = "member_apply"        # holds the "Apply to a Legion" button
BOT_LOG = "bot_log"                  # what the bot did; closed-ticket transcripts
TICKETS = "tickets"                  # category: one private channel per open application
LEGIONS = "legions"                  # category: one private channel per approved Legion
SIEGE_TIMER = "siege_timer"          # the next-siege countdown, edited every minute
ELECTION = "election"                # Faction Commander applications, polls and results
SIEGE_ALERTS = "siege_alerts"        # siege reminders pinging the Siege Alerts role
STEP_DOWN = "step_down"              # the Faction Commander's "Step down" button

CHANNEL_PURPOSES = (ARRIVALS, COMMANDER_APPLY, MEMBER_APPLY, BOT_LOG, SIEGE_TIMER, ELECTION,
                    SIEGE_ALERTS, STEP_DOWN)
CATEGORY_PURPOSES = (TICKETS, LEGIONS)


@dataclass(frozen=True)
class Channel:
    name: str
    kind: Kind = "text"
    topic: str = ""
    # None = inherit the category's access (the channel stays synced to it).
    access: Access | None = None
    purpose: str | None = None


@dataclass(frozen=True)
class Category:
    name: str
    access: Access = PUBLIC
    channels: tuple[Channel, ...] = field(default_factory=tuple)
    purpose: str | None = None


LAYOUT: tuple[Category, ...] = (
    Category("Welcome", PUBLIC, (
        Channel("arrivals", topic="Who just walked in.", access=READ_ONLY, purpose=ARRIVALS),
        Channel("chat", topic="Open chat for everyone."),
        Channel("commander-applications", access=READ_ONLY, purpose=COMMANDER_APPLY,
                topic="Lead a Legion? Apply here to have you and your Legion approved."),
        Channel("member-applications", access=READ_ONLY, purpose=MEMBER_APPLY,
                topic="In an approved Legion? Apply here to join the server proper."),
    )),
    # The category name is still a draft. Siege times live in schedule.py.
    Category("Asmodian Command", APPROVED, (
        Channel("general", topic="Talk between approved commanders and Legion members."),
        Channel("questions", topic="Ask anything."),
        Channel("memes"),
        Channel("screenshots"),
        Channel("siege-timer", access=APPROVED_BOT_ONLY, purpose=SIEGE_TIMER,
                topic="When the next Artifact Siege starts. Updated every minute."),
        Channel("faction-commander", access=APPROVED_BOT_ONLY, purpose=ELECTION,
                topic="Apply to be Faction Commander for the next siege, and vote."),
        Channel("siege-alerts", access=APPROVED_BOT_ONLY, purpose=SIEGE_ALERTS,
                topic="Siege reminders. Turn pings on or off with the button."),
        Channel("Faction Commander Orders", kind="voice", access=COMMAND_VOICE),
    )),
    # Unlocked by the Faction Commander role, for the length of the term. Names are drafts.
    Category("Faction Command", FACTION_COMMAND, (
        Channel("fc-head-admin", topic="The Faction Commander and the Head Admin."),
        Channel("faction-leaders", access=FACTION_LEADERS,
                topic="The Faction Commander with every Legion Commander."),
        Channel("step-down", access=FACTION_COMMAND_BOT_ONLY, purpose=STEP_DOWN,
                topic="Can't lead this siege? Step down and the runner-up takes over."),
    )),
    Category("Legions", ADMIN, purpose=LEGIONS),
    Category("Tickets", ADMIN, purpose=TICKETS),
    Category("Head Admin", ADMIN, (
        Channel("admin-chat"),
        Channel("bot-log", topic="What the bot did, and when.", purpose=BOT_LOG),
    )),
)

# Without these the bot cannot do its job, so setup refuses a layout missing one.
REQUIRED_PURPOSES = (ARRIVALS, COMMANDER_APPLY, MEMBER_APPLY, TICKETS, LEGIONS, SIEGE_TIMER, ELECTION,
                     SIEGE_ALERTS, STEP_DOWN)


def validate(layout: tuple[Category, ...] | None = None) -> list[str]:
    """Return a list of problems with a layout (empty when it is usable)."""
    if layout is None:
        layout = LAYOUT
    problems: list[str] = []
    seen_categories: set[str] = set()
    purposes: list[str] = []
    for cat in layout:
        key = cat.name.casefold()
        if key in seen_categories:
            problems.append(f"Category '{cat.name}' is listed twice.")
        seen_categories.add(key)
        if cat.purpose is not None:
            if cat.purpose not in CATEGORY_PURPOSES:
                problems.append(f"Category '{cat.name}' has unknown purpose '{cat.purpose}'.")
            purposes.append(cat.purpose)
        seen_channels: set[tuple[str, str]] = set()
        for ch in cat.channels:
            ch_key = (ch.kind, normalize_channel_name(ch.name, ch.kind))
            if ch_key in seen_channels:
                problems.append(f"Channel '{ch.name}' is listed twice in '{cat.name}'.")
            seen_channels.add(ch_key)
            access = ch.access or cat.access
            if ch.kind == "text" and access == COMMAND_VOICE:
                problems.append(f"Channel '{ch.name}' in '{cat.name}': command_voice is for voice channels.")
            if ch.kind == "voice" and access in (READ_ONLY, APPROVED_BOT_ONLY, FACTION_COMMAND_BOT_ONLY):
                problems.append(
                    f"Voice channel '{ch.name}' in '{cat.name}' cannot be read-only; "
                    "use another access level."
                )
            if ch.purpose is not None:
                if ch.purpose not in CHANNEL_PURPOSES:
                    problems.append(f"Channel '{ch.name}' has unknown purpose '{ch.purpose}'.")
                elif ch.kind != "text":
                    problems.append(f"Channel '{ch.name}' has a purpose, so it must be a text channel.")
                purposes.append(ch.purpose)
    for p in set(purposes):
        if purposes.count(p) > 1:
            problems.append(f"Purpose '{p}' is given to more than one channel or category.")
    for p in REQUIRED_PURPOSES:
        if p not in purposes:
            problems.append(f"No channel or category has the purpose '{p}'; the bot needs one.")
    return problems


def normalize_channel_name(name: str, kind: Kind) -> str:
    """The name Discord will actually give a channel, for matching existing ones.

    Discord lowercases text-channel names and turns spaces into hyphens; voice
    channel names keep their case. Comparison ignores case either way.
    """
    if kind == "text":
        name = "-".join(name.strip().lower().split())
    return name.strip().casefold()
