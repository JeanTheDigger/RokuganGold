"""The siege calendar: when sieges start and when each election step happens.

Plain time maths, no Discord. All times are timezone-aware; anything stored or
compared is UTC, and the schedule itself is defined on the US Eastern clock
(America/New_York, so it follows daylight saving: 9 PM is always 9 PM Eastern).

For a siege starting at S:
  applications open    = end of the previous siege's Faction Commander term
  poll opens           = S - 24 hours (applications close)
  poll closes          = S - 30 minutes (winner decided, role given)
  term ends            = S + 2 hours (role removed)
"""

from __future__ import annotations

import datetime as dt
from zoneinfo import ZoneInfo

UTC = dt.timezone.utc
TZ = ZoneInfo("America/New_York")
TZ_LABEL = "Eastern"

# Owner-confirmed: Monday, Thursday and Saturday at 9 PM Eastern.
SIEGE_WEEKDAYS = (0, 3, 5)  # Monday=0 … Sunday=6
SIEGE_TIME = dt.time(21, 0)

POLL_OPENS_BEFORE = dt.timedelta(hours=24)
POLL_CLOSES_BEFORE = dt.timedelta(minutes=30)
COMMANDER_TERM = dt.timedelta(hours=2)


def now_utc() -> dt.datetime:
    return dt.datetime.now(UTC)


def _sieges_between(start: dt.datetime, end: dt.datetime) -> list[dt.datetime]:
    """Siege start times (UTC) from `start` to `end`, inclusive, oldest first."""
    out: list[dt.datetime] = []
    day = start.astimezone(TZ).date() - dt.timedelta(days=1)
    last = end.astimezone(TZ).date() + dt.timedelta(days=1)
    while day <= last:
        if day.weekday() in SIEGE_WEEKDAYS:
            s = dt.datetime.combine(day, SIEGE_TIME, tzinfo=TZ).astimezone(UTC)
            if start <= s <= end:
                out.append(s)
        day += dt.timedelta(days=1)
    return out


def next_siege(after: dt.datetime) -> dt.datetime:
    """The first siege starting strictly after `after`."""
    return next(s for s in _sieges_between(after, after + dt.timedelta(days=8)) if s > after)


def previous_siege(before: dt.datetime) -> dt.datetime:
    """The last siege starting strictly before `before`."""
    return [s for s in _sieges_between(before - dt.timedelta(days=8), before) if s < before][-1]


def poll_opens(siege: dt.datetime) -> dt.datetime:
    return siege - POLL_OPENS_BEFORE


def poll_closes(siege: dt.datetime) -> dt.datetime:
    return siege - POLL_CLOSES_BEFORE


def term_ends(siege: dt.datetime) -> dt.datetime:
    return siege + COMMANDER_TERM


def applications_open(siege: dt.datetime) -> dt.datetime:
    """Applications for a siege open when the previous siege's commander term ends."""
    return term_ends(previous_siege(siege))


def application_target(now: dt.datetime) -> dt.datetime:
    """The siege people apply for right now: the first whose poll hasn't opened."""
    s = next_siege(now - POLL_OPENS_BEFORE)
    while poll_opens(s) <= now:
        s = next_siege(s)
    return s


def current_term_siege(now: dt.datetime) -> dt.datetime:
    """The siege now underway (within its commander term) or else the next one."""
    s = next_siege(now - COMMANDER_TERM)
    return s


def siege_underway(now: dt.datetime) -> dt.datetime | None:
    """The siege whose commander term covers `now`, if one has started."""
    s = current_term_siege(now)
    return s if s <= now else None


# --- display ----------------------------------------------------------------
def fmt_local(t: dt.datetime) -> str:
    """'Thursday, November 5 at 9:00 PM Eastern'."""
    local = t.astimezone(TZ)
    hour = local.strftime("%I:%M %p").lstrip("0")
    return f"{local.strftime('%A, %B')} {local.day} at {hour} {TZ_LABEL}"


def tag(t: dt.datetime, style: str = "F") -> str:
    """A Discord timestamp: shown in each reader's own time zone, updates live."""
    return f"<t:{int(t.timestamp())}:{style}>"


def humanize(delta: dt.timedelta) -> str:
    """'1 day, 4 hours, 23 minutes' (whole minutes, rounded down)."""
    minutes = int(delta.total_seconds() // 60)
    if minutes <= 0:
        return "less than a minute"
    days, rem = divmod(minutes, 24 * 60)
    hours, mins = divmod(rem, 60)
    parts = [(days, "day"), (hours, "hour"), (mins, "minute")]
    return ", ".join(f"{n} {word}{'' if n == 1 else 's'}" for n, word in parts if n)
