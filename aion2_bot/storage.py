"""SQLite persistence: per-server config, approved Legions, memberships, applications.

One file (default `aion2.db` next to this script; override with AION2_DB). All
access goes through `Store`; nothing else touches SQL.
"""

from __future__ import annotations

import datetime
import sqlite3
from dataclasses import dataclass

SCHEMA = """
CREATE TABLE IF NOT EXISTS config (
    guild_id INTEGER NOT NULL,
    key      TEXT    NOT NULL,
    value    TEXT    NOT NULL,
    PRIMARY KEY (guild_id, key)
);
CREATE TABLE IF NOT EXISTS legions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id     INTEGER NOT NULL,
    name         TEXT    NOT NULL,
    commander_id INTEGER NOT NULL,
    role_id      INTEGER,
    channel_id   INTEGER,
    created_at   TEXT    NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS legions_name ON legions (guild_id, name COLLATE NOCASE);
CREATE TABLE IF NOT EXISTS memberships (
    guild_id  INTEGER NOT NULL,
    user_id   INTEGER NOT NULL,
    legion_id INTEGER NOT NULL REFERENCES legions (id),
    rank      TEXT    NOT NULL CHECK (rank IN ('commander', 'member')),
    joined_at TEXT    NOT NULL,
    PRIMARY KEY (guild_id, user_id)
);
CREATE TABLE IF NOT EXISTS applications (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id              INTEGER NOT NULL,
    kind                  TEXT    NOT NULL CHECK (kind IN ('commander', 'member')),
    applicant_id          INTEGER NOT NULL,
    character_name        TEXT    NOT NULL,
    about                 TEXT    NOT NULL DEFAULT '',
    legion_name           TEXT,              -- commander: the Legion they claim to lead
    legion_id             INTEGER,           -- member: the Legion they apply to
    status                TEXT    NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'approved', 'denied')),
    commander_approved_by INTEGER,           -- member applications: the commander's yes
    admin_approved_by     INTEGER,           -- the Head Admin's yes
    decided_by            INTEGER,
    reason                TEXT    NOT NULL DEFAULT '',
    channel_id            INTEGER,
    message_id            INTEGER,
    created_at            TEXT    NOT NULL,
    decided_at            TEXT,
    closed_at             TEXT
);
-- One Faction Commander election per siege.
CREATE TABLE IF NOT EXISTS elections (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id        INTEGER NOT NULL,
    siege_start     TEXT    NOT NULL,       -- UTC ISO timestamp
    status          TEXT    NOT NULL DEFAULT 'collecting'
                            CHECK (status IN ('collecting', 'polling', 'decided', 'finished')),
    poll_message_id INTEGER,
    winner_id       INTEGER,
    outcome         TEXT    NOT NULL DEFAULT '',  -- 'won', 'no_applicants', 'no_votes'
    created_at      TEXT    NOT NULL,
    UNIQUE (guild_id, siege_start)
);
CREATE TABLE IF NOT EXISTS candidates (
    election_id INTEGER NOT NULL REFERENCES elections (id),
    user_id     INTEGER NOT NULL,
    applied_at  TEXT    NOT NULL,
    PRIMARY KEY (election_id, user_id)
);
CREATE TABLE IF NOT EXISTS votes (
    election_id  INTEGER NOT NULL REFERENCES elections (id),
    voter_id     INTEGER NOT NULL,
    candidate_id INTEGER NOT NULL,
    voted_at     TEXT    NOT NULL,
    PRIMARY KEY (election_id, voter_id)       -- one vote per person, final
);
-- Siege reminders already sent, so each goes out once.
CREATE TABLE IF NOT EXISTS alerts_sent (
    guild_id    INTEGER NOT NULL,
    siege_start TEXT    NOT NULL,
    kind        TEXT    NOT NULL,
    sent_at     TEXT    NOT NULL,
    PRIMARY KEY (guild_id, siege_start, kind)
);
"""


def _now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


@dataclass(frozen=True)
class Legion:
    id: int
    guild_id: int
    name: str
    commander_id: int
    role_id: int | None
    channel_id: int | None
    created_at: str


@dataclass(frozen=True)
class Membership:
    guild_id: int
    user_id: int
    legion_id: int
    rank: str
    joined_at: str


@dataclass(frozen=True)
class Application:
    id: int
    guild_id: int
    kind: str
    applicant_id: int
    character_name: str
    about: str
    legion_name: str | None
    legion_id: int | None
    status: str
    commander_approved_by: int | None
    admin_approved_by: int | None
    decided_by: int | None
    reason: str
    channel_id: int | None
    message_id: int | None
    created_at: str
    decided_at: str | None
    closed_at: str | None


@dataclass(frozen=True)
class Election:
    id: int
    guild_id: int
    siege_start: str
    status: str
    poll_message_id: int | None
    winner_id: int | None
    outcome: str
    created_at: str

    @property
    def siege(self) -> datetime.datetime:
        return datetime.datetime.fromisoformat(self.siege_start)


class Store:
    def __init__(self, path: str) -> None:
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA foreign_keys = ON")
        self.db.executescript(SCHEMA)
        self.db.commit()

    # --- config -----------------------------------------------------------
    def get_config(self, guild_id: int, key: str) -> str | None:
        row = self.db.execute(
            "SELECT value FROM config WHERE guild_id = ? AND key = ?", (guild_id, key)
        ).fetchone()
        return row["value"] if row else None

    def get_config_id(self, guild_id: int, key: str) -> int | None:
        value = self.get_config(guild_id, key)
        return int(value) if value is not None else None

    def set_config(self, guild_id: int, key: str, value: str | int) -> None:
        self.db.execute(
            "INSERT INTO config (guild_id, key, value) VALUES (?, ?, ?) "
            "ON CONFLICT (guild_id, key) DO UPDATE SET value = excluded.value",
            (guild_id, key, str(value)),
        )
        self.db.commit()

    # --- legions ----------------------------------------------------------
    def create_legion(
        self, guild_id: int, name: str, commander_id: int, role_id: int, channel_id: int
    ) -> Legion:
        """Insert a Legion and its commander's membership in one transaction."""
        now = _now()
        with self.db:
            cur = self.db.execute(
                "INSERT INTO legions (guild_id, name, commander_id, role_id, channel_id, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (guild_id, name, commander_id, role_id, channel_id, now),
            )
            legion_id = int(cur.lastrowid or 0)
            self.db.execute(
                "INSERT INTO memberships (guild_id, user_id, legion_id, rank, joined_at) "
                "VALUES (?, ?, ?, 'commander', ?)",
                (guild_id, commander_id, legion_id, now),
            )
        legion = self.get_legion(legion_id)
        assert legion is not None
        return legion

    def get_legion(self, legion_id: int) -> Legion | None:
        row = self.db.execute("SELECT * FROM legions WHERE id = ?", (legion_id,)).fetchone()
        return Legion(**dict(row)) if row else None

    def legion_by_name(self, guild_id: int, name: str) -> Legion | None:
        row = self.db.execute(
            "SELECT * FROM legions WHERE guild_id = ? AND name = ? COLLATE NOCASE",
            (guild_id, name.strip()),
        ).fetchone()
        return Legion(**dict(row)) if row else None

    def list_legions(self, guild_id: int) -> list[Legion]:
        rows = self.db.execute(
            "SELECT * FROM legions WHERE guild_id = ? ORDER BY name COLLATE NOCASE", (guild_id,)
        ).fetchall()
        return [Legion(**dict(r)) for r in rows]

    def member_count(self, legion_id: int) -> int:
        row = self.db.execute(
            "SELECT COUNT(*) AS n FROM memberships WHERE legion_id = ?", (legion_id,)
        ).fetchone()
        return int(row["n"])

    # --- memberships ------------------------------------------------------
    def membership(self, guild_id: int, user_id: int) -> Membership | None:
        row = self.db.execute(
            "SELECT * FROM memberships WHERE guild_id = ? AND user_id = ?", (guild_id, user_id)
        ).fetchone()
        return Membership(**dict(row)) if row else None

    def add_member(self, guild_id: int, user_id: int, legion_id: int) -> None:
        with self.db:
            self.db.execute(
                "INSERT INTO memberships (guild_id, user_id, legion_id, rank, joined_at) "
                "VALUES (?, ?, ?, 'member', ?)",
                (guild_id, user_id, legion_id, _now()),
            )

    # --- applications -----------------------------------------------------
    def create_application(
        self,
        guild_id: int,
        kind: str,
        applicant_id: int,
        character_name: str,
        about: str,
        legion_name: str | None = None,
        legion_id: int | None = None,
    ) -> Application:
        with self.db:
            cur = self.db.execute(
                "INSERT INTO applications (guild_id, kind, applicant_id, character_name, about, "
                "legion_name, legion_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (guild_id, kind, applicant_id, character_name, about, legion_name, legion_id, _now()),
            )
        app = self.get_application(int(cur.lastrowid or 0))
        assert app is not None
        return app

    def get_application(self, app_id: int) -> Application | None:
        row = self.db.execute("SELECT * FROM applications WHERE id = ?", (app_id,)).fetchone()
        return Application(**dict(row)) if row else None

    def open_application_for(self, guild_id: int, user_id: int) -> Application | None:
        """The applicant's pending application, if any (one at a time)."""
        row = self.db.execute(
            "SELECT * FROM applications WHERE guild_id = ? AND applicant_id = ? AND status = 'pending' "
            "ORDER BY id DESC LIMIT 1",
            (guild_id, user_id),
        ).fetchone()
        return Application(**dict(row)) if row else None

    def pending_commander_claims(self, guild_id: int, legion_name: str, exclude_id: int) -> list[Application]:
        """Other pending commander applications naming the same Legion."""
        rows = self.db.execute(
            "SELECT * FROM applications WHERE guild_id = ? AND kind = 'commander' AND status = 'pending' "
            "AND legion_name = ? COLLATE NOCASE AND id != ?",
            (guild_id, legion_name.strip(), exclude_id),
        ).fetchall()
        return [Application(**dict(r)) for r in rows]

    def update_application(self, app_id: int, **fields: object) -> Application:
        allowed = {
            "status", "commander_approved_by", "admin_approved_by", "decided_by", "reason",
            "channel_id", "message_id", "decided_at", "closed_at",
        }
        bad = set(fields) - allowed
        if bad:
            raise ValueError(f"Not updatable: {sorted(bad)}")
        if fields:
            cols = ", ".join(f"{k} = ?" for k in fields)
            with self.db:
                self.db.execute(f"UPDATE applications SET {cols} WHERE id = ?", (*fields.values(), app_id))
        app = self.get_application(app_id)
        assert app is not None
        return app

    def decide(self, app_id: int, status: str, decided_by: int, reason: str = "") -> Application:
        return self.update_application(
            app_id, status=status, decided_by=decided_by, reason=reason, decided_at=_now(),
        )

    def mark_closed(self, app_id: int) -> None:
        self.update_application(app_id, closed_at=_now())

    # --- elections --------------------------------------------------------
    def election_for(self, guild_id: int, siege: datetime.datetime, create: bool = False) -> Election | None:
        key = siege.astimezone(datetime.timezone.utc).isoformat()
        if create:
            with self.db:
                self.db.execute(
                    "INSERT OR IGNORE INTO elections (guild_id, siege_start, created_at) VALUES (?, ?, ?)",
                    (guild_id, key, _now()),
                )
        row = self.db.execute(
            "SELECT * FROM elections WHERE guild_id = ? AND siege_start = ?", (guild_id, key)
        ).fetchone()
        return Election(**dict(row)) if row else None

    def get_election(self, election_id: int) -> Election | None:
        row = self.db.execute("SELECT * FROM elections WHERE id = ?", (election_id,)).fetchone()
        return Election(**dict(row)) if row else None

    def unfinished_elections(self, guild_id: int) -> list[Election]:
        rows = self.db.execute(
            "SELECT * FROM elections WHERE guild_id = ? AND status != 'finished' ORDER BY siege_start",
            (guild_id,),
        ).fetchall()
        return [Election(**dict(r)) for r in rows]

    def update_election(self, election_id: int, **fields: object) -> Election:
        allowed = {"status", "poll_message_id", "winner_id", "outcome"}
        bad = set(fields) - allowed
        if bad:
            raise ValueError(f"Not updatable: {sorted(bad)}")
        cols = ", ".join(f"{k} = ?" for k in fields)
        with self.db:
            self.db.execute(f"UPDATE elections SET {cols} WHERE id = ?", (*fields.values(), election_id))
        election = self.get_election(election_id)
        assert election is not None
        return election

    def candidates(self, election_id: int) -> list[int]:
        """Applicants' user IDs, in the order they applied."""
        rows = self.db.execute(
            "SELECT user_id FROM candidates WHERE election_id = ? ORDER BY applied_at, rowid",
            (election_id,),
        ).fetchall()
        return [int(r["user_id"]) for r in rows]

    def add_candidate(self, election_id: int, user_id: int) -> bool:
        """False if they had already applied."""
        with self.db:
            cur = self.db.execute(
                "INSERT OR IGNORE INTO candidates (election_id, user_id, applied_at) VALUES (?, ?, ?)",
                (election_id, user_id, _now()),
            )
        return cur.rowcount == 1

    def remove_candidate(self, election_id: int, user_id: int) -> bool:
        with self.db:
            cur = self.db.execute(
                "DELETE FROM candidates WHERE election_id = ? AND user_id = ?", (election_id, user_id)
            )
        return cur.rowcount == 1

    def cast_vote(self, election_id: int, voter_id: int, candidate_id: int) -> bool:
        """False if this person already voted (votes are final)."""
        with self.db:
            cur = self.db.execute(
                "INSERT OR IGNORE INTO votes (election_id, voter_id, candidate_id, voted_at) "
                "VALUES (?, ?, ?, ?)",
                (election_id, voter_id, candidate_id, _now()),
            )
        return cur.rowcount == 1

    def vote_of(self, election_id: int, voter_id: int) -> int | None:
        row = self.db.execute(
            "SELECT candidate_id FROM votes WHERE election_id = ? AND voter_id = ?", (election_id, voter_id)
        ).fetchone()
        return int(row["candidate_id"]) if row else None

    def mark_alert(self, guild_id: int, siege: datetime.datetime, kind: str) -> bool:
        """Record a reminder as sent. False if it already was."""
        key = siege.astimezone(datetime.timezone.utc).isoformat()
        with self.db:
            cur = self.db.execute(
                "INSERT OR IGNORE INTO alerts_sent (guild_id, siege_start, kind, sent_at) VALUES (?, ?, ?, ?)",
                (guild_id, key, kind, _now()),
            )
        return cur.rowcount == 1

    def tally(self, election_id: int) -> dict[int, int]:
        """Votes per candidate (only candidates with at least one vote)."""
        rows = self.db.execute(
            "SELECT candidate_id, COUNT(*) AS n FROM votes WHERE election_id = ? GROUP BY candidate_id",
            (election_id,),
        ).fetchall()
        return {int(r["candidate_id"]): int(r["n"]) for r in rows}
