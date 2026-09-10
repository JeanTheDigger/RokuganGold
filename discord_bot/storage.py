"""SQLite persistence for characters, active-character links, and DM roles.

One small local database file (default ``rokugan.db`` in this folder, override
with the ``DB_PATH`` env var). SQLite means there is no separate database server
to install or run — the whole store is a single file that is trivial to back up
(just copy it).

Scope is per Discord server ("guild"): a character, an active-character choice,
and DM status are all keyed by ``guild_id`` so one bot can serve many servers
without them seeing each other's sheets.

The character's game data is stored as a JSON blob in the ``data`` column, so
the sheet model can grow in later phases without a schema migration; the few
fields the bot queries on (owner, name) are real indexed columns.
"""

from __future__ import annotations

import json
import sqlite3
import threading
import time
from dataclasses import dataclass

from l5r_rules.character import Character

_SCHEMA = """
CREATE TABLE IF NOT EXISTS characters (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id    TEXT NOT NULL,
    owner_id    TEXT NOT NULL,
    name        TEXT NOT NULL,
    data        TEXT NOT NULL,
    created_at  REAL NOT NULL,
    updated_at  REAL NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_char_unique
    ON characters (guild_id, owner_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS active_characters (
    guild_id     TEXT NOT NULL,
    user_id      TEXT NOT NULL,
    character_id INTEGER NOT NULL,
    PRIMARY KEY (guild_id, user_id)
);

CREATE TABLE IF NOT EXISTS dm_users (
    guild_id TEXT NOT NULL,
    user_id  TEXT NOT NULL,
    PRIMARY KEY (guild_id, user_id)
);

CREATE TABLE IF NOT EXISTS rooms (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id          TEXT NOT NULL,
    parent_channel_id TEXT NOT NULL,
    thread_id         TEXT NOT NULL UNIQUE,
    name              TEXT NOT NULL,
    host_id           TEXT NOT NULL,
    created_at        REAL NOT NULL,
    closed            INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS room_members (
    room_id INTEGER NOT NULL,
    user_id TEXT NOT NULL,
    PRIMARY KEY (room_id, user_id)
);
"""


@dataclass
class CharacterRecord:
    """A stored character plus its ownership metadata."""

    id: int
    guild_id: str
    owner_id: str
    character: Character


@dataclass
class RoomRecord:
    """A play room backed by a Discord private thread."""

    id: int
    guild_id: str
    parent_channel_id: str
    thread_id: str
    name: str
    host_id: str
    closed: bool


class DuplicateNameError(Exception):
    """Raised when a player already owns a character with the same name."""


class Store:
    def __init__(self, path: str = "rokugan.db") -> None:
        # check_same_thread=False + an explicit lock: discord.py runs one event
        # loop, but this keeps us safe if a call ever lands off-thread.
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        with self._lock, self._conn:
            self._conn.executescript(_SCHEMA)

    # -- internal helpers ------------------------------------------------------
    def _row_to_record(self, row: sqlite3.Row) -> CharacterRecord:
        return CharacterRecord(
            id=row["id"],
            guild_id=row["guild_id"],
            owner_id=row["owner_id"],
            character=Character.from_dict(json.loads(row["data"])),
        )

    # -- characters ------------------------------------------------------------
    def create_character(self, guild_id: str, owner_id: str, char: Character) -> CharacterRecord:
        now = time.time()
        payload = json.dumps(char.to_dict())
        try:
            with self._lock, self._conn:
                cur = self._conn.execute(
                    "INSERT INTO characters (guild_id, owner_id, name, data, created_at, updated_at)"
                    " VALUES (?, ?, ?, ?, ?, ?)",
                    (guild_id, owner_id, char.name, payload, now, now),
                )
                new_id = cur.lastrowid
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(char.name) from exc
        return CharacterRecord(new_id, guild_id, owner_id, char)

    def get_by_id(self, character_id: int) -> CharacterRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM characters WHERE id = ?", (character_id,)
            ).fetchone()
        return self._row_to_record(row) if row else None

    def get_by_name(self, guild_id: str, owner_id: str, name: str) -> CharacterRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM characters WHERE guild_id = ? AND owner_id = ? "
                "AND name = ? COLLATE NOCASE",
                (guild_id, owner_id, name),
            ).fetchone()
        return self._row_to_record(row) if row else None

    def list_by_owner(self, guild_id: str, owner_id: str) -> list[CharacterRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM characters WHERE guild_id = ? AND owner_id = ? "
                "ORDER BY name COLLATE NOCASE",
                (guild_id, owner_id),
            ).fetchall()
        return [self._row_to_record(r) for r in rows]

    def list_by_guild(self, guild_id: str) -> list[CharacterRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM characters WHERE guild_id = ? ORDER BY name COLLATE NOCASE",
                (guild_id,),
            ).fetchall()
        return [self._row_to_record(r) for r in rows]

    def save(self, record: CharacterRecord) -> None:
        payload = json.dumps(record.character.to_dict())
        with self._lock, self._conn:
            self._conn.execute(
                "UPDATE characters SET data = ?, name = ?, updated_at = ? WHERE id = ?",
                (payload, record.character.name, time.time(), record.id),
            )

    def delete(self, character_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM characters WHERE id = ?", (character_id,))
            self._conn.execute(
                "DELETE FROM active_characters WHERE character_id = ?", (character_id,)
            )

    # -- active-character link -------------------------------------------------
    def set_active(self, guild_id: str, user_id: str, character_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO active_characters (guild_id, user_id, character_id) "
                "VALUES (?, ?, ?) ON CONFLICT(guild_id, user_id) "
                "DO UPDATE SET character_id = excluded.character_id",
                (guild_id, user_id, character_id),
            )

    def get_active(self, guild_id: str, user_id: str) -> CharacterRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT c.* FROM active_characters a JOIN characters c "
                "ON c.id = a.character_id WHERE a.guild_id = ? AND a.user_id = ?",
                (guild_id, user_id),
            ).fetchone()
        return self._row_to_record(row) if row else None

    # -- DM roles --------------------------------------------------------------
    def grant_dm(self, guild_id: str, user_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT OR IGNORE INTO dm_users (guild_id, user_id) VALUES (?, ?)",
                (guild_id, user_id),
            )

    def revoke_dm(self, guild_id: str, user_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM dm_users WHERE guild_id = ? AND user_id = ?",
                (guild_id, user_id),
            )

    def is_dm(self, guild_id: str, user_id: str) -> bool:
        with self._lock:
            row = self._conn.execute(
                "SELECT 1 FROM dm_users WHERE guild_id = ? AND user_id = ?",
                (guild_id, user_id),
            ).fetchone()
        return row is not None

    def list_dms(self, guild_id: str) -> list[str]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT user_id FROM dm_users WHERE guild_id = ?", (guild_id,)
            ).fetchall()
        return [r["user_id"] for r in rows]

    # -- rooms -----------------------------------------------------------------
    def _row_to_room(self, row: sqlite3.Row) -> RoomRecord:
        return RoomRecord(
            id=row["id"],
            guild_id=row["guild_id"],
            parent_channel_id=row["parent_channel_id"],
            thread_id=row["thread_id"],
            name=row["name"],
            host_id=row["host_id"],
            closed=bool(row["closed"]),
        )

    def create_room(
        self, guild_id: str, parent_channel_id: str, thread_id: str, name: str, host_id: str
    ) -> RoomRecord:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "INSERT INTO rooms (guild_id, parent_channel_id, thread_id, name, host_id, "
                "created_at, closed) VALUES (?, ?, ?, ?, ?, ?, 0)",
                (guild_id, parent_channel_id, thread_id, name, host_id, time.time()),
            )
            room_id = cur.lastrowid
            self._conn.execute(
                "INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)",
                (room_id, host_id),
            )
        return RoomRecord(room_id, guild_id, parent_channel_id, thread_id, name, host_id, False)

    def get_room_by_thread(self, thread_id: str) -> RoomRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM rooms WHERE thread_id = ?", (thread_id,)
            ).fetchone()
        return self._row_to_room(row) if row else None

    def list_rooms(self, guild_id: str, include_closed: bool = False) -> list[RoomRecord]:
        query = "SELECT * FROM rooms WHERE guild_id = ?"
        if not include_closed:
            query += " AND closed = 0"
        query += " ORDER BY created_at DESC"
        with self._lock:
            rows = self._conn.execute(query, (guild_id,)).fetchall()
        return [self._row_to_room(r) for r in rows]

    def close_room(self, room_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("UPDATE rooms SET closed = 1 WHERE id = ?", (room_id,))

    def add_room_member(self, room_id: int, user_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)",
                (room_id, user_id),
            )

    def remove_room_member(self, room_id: int, user_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM room_members WHERE room_id = ? AND user_id = ?", (room_id, user_id)
            )

    def list_room_members(self, room_id: int) -> list[str]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT user_id FROM room_members WHERE room_id = ?", (room_id,)
            ).fetchall()
        return [r["user_id"] for r in rows]
