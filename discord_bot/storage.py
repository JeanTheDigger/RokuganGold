"""SQLite persistence for characters, active-character links, and DM roles.

One small local database file (default ``rokugan.db`` in this folder, override
with the ``DB_PATH`` env var). SQLite means there is no separate database server
to install or run: the whole store is a single file that is trivial to back up
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
from l5r_rules.creature import Creature

_VERSION_TABLE = """\
CREATE TABLE IF NOT EXISTS schema_version (
    id      INTEGER PRIMARY KEY CHECK (id = 1),
    version INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO schema_version (id, version) VALUES (1, 0);
"""

_MIGRATIONS: list[str] = [
    # 1: add description column to rooms
    "ALTER TABLE rooms ADD COLUMN description TEXT NOT NULL DEFAULT '';",
    # 2: date display channel with pinned message tracking
    """\
CREATE TABLE IF NOT EXISTS date_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL,
    message_id TEXT NOT NULL DEFAULT ''
);
""",
    # 3: private channels for the character creation wizard
    """\
CREATE TABLE IF NOT EXISTS creation_channels (
    guild_id   TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    PRIMARY KEY (guild_id, user_id)
);
""",
    # 4: location areas (Discord categories) and locations (text channels)
    """\
CREATE TABLE IF NOT EXISTS location_areas (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id    TEXT NOT NULL,
    category_id TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    creator_id  TEXT NOT NULL,
    created_at  REAL NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_location_area_unique
    ON location_areas (guild_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS locations (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id    TEXT NOT NULL,
    area_id     INTEGER NOT NULL,
    channel_id  TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    creator_id  TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_at  REAL NOT NULL,
    FOREIGN KEY (area_id) REFERENCES location_areas(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_location_unique
    ON locations (area_id, name COLLATE NOCASE);
""",
    # 5: approval views that survive a restart (see views_base.py)
    """\
CREATE TABLE IF NOT EXISTS pending_views (
    message_id TEXT NOT NULL PRIMARY KEY,
    guild_id   TEXT NOT NULL,
    kind       TEXT NOT NULL,
    state      TEXT NOT NULL,
    created_at REAL NOT NULL
);
""",
    # 6: undo snapshots - the state of a character/creature row before each save
    """\
CREATE TABLE IF NOT EXISTS undo_snapshots (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id    TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   INTEGER NOT NULL,
    entity_name TEXT NOT NULL,
    note        TEXT NOT NULL DEFAULT '',
    data        TEXT NOT NULL,
    created_at  REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_undo_entity ON undo_snapshots (guild_id, entity_name COLLATE NOCASE, created_at);
""",
    # 7: pending approval views remember their channel (for /dm pending jump links)
    "ALTER TABLE pending_views ADD COLUMN channel_id TEXT NOT NULL DEFAULT '';",
    # 8: character-creation wizard state, so a wizard can resume after idling or a restart
    "ALTER TABLE creation_channels ADD COLUMN state TEXT NOT NULL DEFAULT '';",
    # 9: Kami-only XP log channel (who granted Experience to whom)
    """\
CREATE TABLE IF NOT EXISTS xp_log_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL
);
""",
    # 10: reusable NPC templates (/npc template ...), one row per guild + name
    """\
CREATE TABLE IF NOT EXISTS npc_templates (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id   TEXT NOT NULL,
    name       TEXT NOT NULL,
    data       TEXT NOT NULL,
    created_by TEXT NOT NULL DEFAULT '',
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_npc_template_unique ON npc_templates (guild_id, name COLLATE NOCASE);
""",
    # 11: rumor board - targeted and public rumors
    """\
CREATE TABLE IF NOT EXISTS rumors (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id   TEXT NOT NULL,
    title      TEXT NOT NULL,
    content    TEXT NOT NULL,
    tier       TEXT NOT NULL DEFAULT 'hearsay',
    public     INTEGER NOT NULL DEFAULT 0,
    author_id  TEXT NOT NULL,
    created_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rumors_guild ON rumors (guild_id, created_at DESC);

CREATE TABLE IF NOT EXISTS rumor_filters (
    rumor_id     INTEGER NOT NULL,
    filter_type  TEXT NOT NULL,
    filter_value TEXT NOT NULL,
    FOREIGN KEY (rumor_id) REFERENCES rumors(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_rumor_filters ON rumor_filters (rumor_id);

CREATE TABLE IF NOT EXISTS rumor_board_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL
);
""",
]

# How many before-states to keep per character/creature for /dm undo.
UNDO_KEEP_PER_ENTITY: int = 20

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
    PRIMARY KEY (guild_id, user_id),
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
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
    closed            INTEGER NOT NULL DEFAULT 0,
    description       TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS room_members (
    room_id INTEGER NOT NULL,
    user_id TEXT NOT NULL,
    PRIMARY KEY (room_id, user_id),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS creatures (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id   TEXT NOT NULL,
    name       TEXT NOT NULL,
    data       TEXT NOT NULL,
    created_at REAL NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_creature_unique
    ON creatures (guild_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS combat_log_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS encounters (
    channel_id TEXT NOT NULL PRIMARY KEY,
    guild_id   TEXT NOT NULL,
    data       TEXT NOT NULL,
    updated_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS macros (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id   TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    name       TEXT NOT NULL,
    rolled     INTEGER NOT NULL,
    kept       INTEGER NOT NULL,
    modifier   INTEGER NOT NULL DEFAULT 0,
    label      TEXT NOT NULL DEFAULT ''
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_macro_unique
    ON macros (guild_id, user_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS room_npcs (
    room_id  INTEGER NOT NULL,
    npc_name TEXT NOT NULL,
    PRIMARY KEY (room_id, npc_name),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS approval_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS damage_approval_channels (
    guild_id   TEXT NOT NULL PRIMARY KEY,
    channel_id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS calendar (
    guild_id TEXT NOT NULL PRIMARY KEY,
    year     INTEGER NOT NULL,
    month    INTEGER NOT NULL,
    day      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    guild_id TEXT NOT NULL,
    name     TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_category_unique
    ON categories (guild_id, name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS category_members (
    category_id INTEGER NOT NULL,
    entity_type TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    PRIMARY KEY (category_id, entity_type, entity_name COLLATE NOCASE),
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
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
    description: str = ""


@dataclass
class CreatureRecord:
    """A spawned creature instance (mutable wounds) stored per guild."""

    id: int
    guild_id: str
    creature: Creature


@dataclass
class UndoRecord:
    """A saved before-state of a character or creature row (for /dm undo)."""

    id: int
    guild_id: str
    entity_type: str      # "character" or "creature"
    entity_id: int
    entity_name: str
    note: str
    data: dict
    created_at: float


@dataclass
class CategoryRecord:
    """A named grouping for NPCs and/or creatures."""

    id: int
    guild_id: str
    name: str


@dataclass
class MacroRecord:
    """A saved roll macro."""

    id: int
    guild_id: str
    user_id: str
    name: str
    rolled: int
    kept: int
    modifier: int
    label: str


@dataclass
class LocationAreaRecord:
    """A location area backed by a Discord category channel."""

    id: int
    guild_id: str
    category_id: str
    name: str
    creator_id: str


@dataclass
class LocationRecord:
    """A location (text channel) within a location area."""

    id: int
    guild_id: str
    area_id: int
    channel_id: str
    name: str
    creator_id: str
    description: str = ""


class DuplicateNameError(Exception):
    """Raised when a player already owns a character with the same name."""


class Store:
    def __init__(self, path: str = "rokugan.db") -> None:
        # check_same_thread=False + an explicit lock: discord.py runs one event
        # loop, but this keeps us safe if a call ever lands off-thread.
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._conn.execute("PRAGMA journal_mode = WAL")
        self._lock = threading.Lock()
        with self._lock, self._conn:
            self._conn.executescript(_SCHEMA)
            self._conn.executescript(_VERSION_TABLE)
            self._run_migrations()

    # -- migrations ------------------------------------------------------------
    def _run_migrations(self) -> None:
        row = self._conn.execute("SELECT version FROM schema_version WHERE id = 1").fetchone()
        current = row["version"]
        for i in range(current, len(_MIGRATIONS)):
            version = i + 1
            try:
                self._conn.executescript(_MIGRATIONS[i])
            except sqlite3.OperationalError:
                pass
            self._conn.execute("UPDATE schema_version SET version = ? WHERE id = 1", (version,))

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

    def get_by_name_guild(self, guild_id: str, name: str) -> CharacterRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM characters WHERE guild_id = ? "
                "AND name = ? COLLATE NOCASE",
                (guild_id, name),
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

    def save(self, record: CharacterRecord, note: str = "") -> bool:
        """Write the character. The row's previous state is kept as an undo
        snapshot (labelled `note`) when the data actually changes. Returns
        True if the data changed."""
        payload = json.dumps(record.character.to_dict())
        with self._lock, self._conn:
            changed = self._snapshot("characters", "character", record.id, record.guild_id, payload, note)
            self._conn.execute(
                "UPDATE characters SET data = ?, name = ?, updated_at = ? WHERE id = ?",
                (payload, record.character.name, time.time(), record.id),
            )
        return changed

    def delete(self, character_id: int) -> None:
        with self._lock, self._conn:
            # active_characters FK CASCADE handles cleanup automatically
            self._conn.execute("DELETE FROM characters WHERE id = ?", (character_id,))
            self._conn.execute(
                "DELETE FROM undo_snapshots WHERE entity_type = 'character' AND entity_id = ?",
                (character_id,),
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

    def clear_active(self, guild_id: str, user_id: str, character_id: int) -> None:
        """Stop `character_id` being the user's active character (no-op if it isn't)."""
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM active_characters WHERE guild_id = ? AND user_id = ? AND character_id = ?",
                (guild_id, user_id, character_id),
            )

    # -- pending approval views (views_base.py) ---------------------------------
    def save_pending_view(self, message_id: str, guild_id: str, kind: str, state: str,
                          channel_id: str = "") -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT OR REPLACE INTO pending_views (message_id, guild_id, kind, state, created_at, channel_id) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (message_id, guild_id, kind, state, time.time(), channel_id),
            )

    def list_pending_views(self, guild_id: str) -> list[tuple[str, str, str, str, float]]:
        """(message_id, channel_id, kind, state, created_at) for a guild, newest first."""
        with self._lock:
            rows = self._conn.execute(
                "SELECT message_id, channel_id, kind, state, created_at FROM pending_views "
                "WHERE guild_id = ? ORDER BY created_at DESC",
                (guild_id,),
            ).fetchall()
        return [(r["message_id"], r["channel_id"], r["kind"], r["state"], r["created_at"]) for r in rows]

    def delete_pending_view(self, message_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM pending_views WHERE message_id = ?", (message_id,))

    def load_pending_views(self) -> list[tuple[str, str, str]]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT message_id, kind, state FROM pending_views ORDER BY created_at"
            ).fetchall()
        return [(r["message_id"], r["kind"], r["state"]) for r in rows]

    def purge_pending_views(self, older_than: float) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM pending_views WHERE created_at < ?", (older_than,))

    def encounter_guild(self, channel_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT guild_id FROM encounters WHERE channel_id = ?", (channel_id,)
            ).fetchone()
        return row["guild_id"] if row else None

    def get_active(self, guild_id: str, user_id: str) -> CharacterRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT c.* FROM active_characters a JOIN characters c "
                "ON c.id = a.character_id WHERE a.guild_id = ? AND a.user_id = ?",
                (guild_id, user_id),
            ).fetchone()
        return self._row_to_record(row) if row else None

    def list_active_pcs(self, guild_id: str) -> list[tuple[str, CharacterRecord]]:
        """Return (owner_id, record) for every active PC in the guild."""
        with self._lock:
            rows = self._conn.execute(
                "SELECT a.user_id, c.* FROM active_characters a JOIN characters c "
                "ON c.id = a.character_id "
                "WHERE a.guild_id = ? AND a.user_id != ? AND c.owner_id != ? "
                "ORDER BY c.name COLLATE NOCASE",
                (guild_id, "npc", "npc"),
            ).fetchall()
        return [(r["user_id"], self._row_to_record(r)) for r in rows]

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
            description=row["description"] if "description" in row.keys() else "",
        )

    def create_room(
        self, guild_id: str, parent_channel_id: str, thread_id: str, name: str, host_id: str,
        description: str = "",
    ) -> RoomRecord:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "INSERT INTO rooms (guild_id, parent_channel_id, thread_id, name, host_id, "
                "created_at, closed, description) VALUES (?, ?, ?, ?, ?, ?, 0, ?)",
                (guild_id, parent_channel_id, thread_id, name, host_id, time.time(), description),
            )
            room_id = cur.lastrowid
            self._conn.execute(
                "INSERT OR IGNORE INTO room_members (room_id, user_id) VALUES (?, ?)",
                (room_id, host_id),
            )
        return RoomRecord(room_id, guild_id, parent_channel_id, thread_id, name, host_id, False, description)

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

    def update_room_description(self, room_id: int, description: str) -> None:
        with self._lock, self._conn:
            self._conn.execute("UPDATE rooms SET description = ? WHERE id = ?", (description, room_id))

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

    # -- room NPCs -------------------------------------------------------------
    def place_npc_in_room(self, room_id: int, npc_name: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT OR IGNORE INTO room_npcs (room_id, npc_name) VALUES (?, ?)",
                (room_id, npc_name),
            )

    def remove_npc_from_room(self, room_id: int, npc_name: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM room_npcs WHERE room_id = ? AND npc_name = ?",
                (room_id, npc_name),
            )

    def list_room_npcs(self, room_id: int) -> list[str]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT npc_name FROM room_npcs WHERE room_id = ?", (room_id,)
            ).fetchall()
        return [r["npc_name"] for r in rows]

    def clear_room_npcs(self, room_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM room_npcs WHERE room_id = ?", (room_id,))

    # -- creatures -------------------------------------------------------------
    def _row_to_creature(self, row: sqlite3.Row) -> CreatureRecord:
        return CreatureRecord(
            id=row["id"], guild_id=row["guild_id"],
            creature=Creature.from_dict(json.loads(row["data"])),
        )

    def create_creature(self, guild_id: str, cr: Creature) -> CreatureRecord:
        payload = json.dumps(cr.to_dict())
        try:
            with self._lock, self._conn:
                cur = self._conn.execute(
                    "INSERT INTO creatures (guild_id, name, data, created_at) VALUES (?, ?, ?, ?)",
                    (guild_id, cr.name, payload, time.time()),
                )
                new_id = cur.lastrowid
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(cr.name) from exc
        return CreatureRecord(new_id, guild_id, cr)

    def get_creature_by_name(self, guild_id: str, name: str) -> CreatureRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM creatures WHERE guild_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, name),
            ).fetchone()
        return self._row_to_creature(row) if row else None

    def get_creature_by_id(self, creature_id: int) -> CreatureRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM creatures WHERE id = ?", (creature_id,)
            ).fetchone()
        return self._row_to_creature(row) if row else None

    def list_creatures(self, guild_id: str) -> list[CreatureRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM creatures WHERE guild_id = ? ORDER BY name COLLATE NOCASE",
                (guild_id,),
            ).fetchall()
        return [self._row_to_creature(r) for r in rows]

    def save_creature(self, record: CreatureRecord, note: str = "") -> None:
        """Write the creature, keeping its previous state as an undo snapshot."""
        payload = json.dumps(record.creature.to_dict())
        with self._lock, self._conn:
            self._snapshot("creatures", "creature", record.id, record.guild_id, payload, note)
            self._conn.execute(
                "UPDATE creatures SET data = ?, name = ? WHERE id = ?",
                (payload, record.creature.name, record.id),
            )

    # -- undo snapshots (/dm undo) ---------------------------------------------
    def _snapshot(self, table: str, entity_type: str, entity_id: int, guild_id: str,
                  new_payload: str, note: str) -> bool:
        """Inside the caller's lock/transaction: store the row's current data as
        an undo snapshot if the new payload differs, then trim old snapshots.
        Returns True if a snapshot was taken (the data changed)."""
        row = self._conn.execute(
            f"SELECT name, data FROM {table} WHERE id = ?", (entity_id,)
        ).fetchone()
        if row is None or row["data"] == new_payload:
            return False
        self._conn.execute(
            "INSERT INTO undo_snapshots (guild_id, entity_type, entity_id, entity_name, note, data, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (guild_id, entity_type, entity_id, row["name"], note or "sheet change", row["data"], time.time()),
        )
        self._conn.execute(
            "DELETE FROM undo_snapshots WHERE entity_type = ? AND entity_id = ? AND id NOT IN ("
            "SELECT id FROM undo_snapshots WHERE entity_type = ? AND entity_id = ? "
            "ORDER BY id DESC LIMIT ?)",
            (entity_type, entity_id, entity_type, entity_id, UNDO_KEEP_PER_ENTITY),
        )
        return True

    def _row_to_undo(self, row: sqlite3.Row) -> UndoRecord:
        return UndoRecord(
            id=row["id"], guild_id=row["guild_id"], entity_type=row["entity_type"],
            entity_id=row["entity_id"], entity_name=row["entity_name"], note=row["note"],
            data=json.loads(row["data"]), created_at=row["created_at"],
        )

    def list_undo(self, guild_id: str, name: str | None = None, limit: int = 5) -> list[UndoRecord]:
        """Newest-first undo snapshots in a guild, optionally for one name (case-insensitive)."""
        with self._lock:
            if name is None:
                rows = self._conn.execute(
                    "SELECT * FROM undo_snapshots WHERE guild_id = ? ORDER BY id DESC LIMIT ?",
                    (guild_id, limit),
                ).fetchall()
            else:
                rows = self._conn.execute(
                    "SELECT * FROM undo_snapshots WHERE guild_id = ? AND entity_name = ? COLLATE NOCASE "
                    "ORDER BY id DESC LIMIT ?",
                    (guild_id, name, limit),
                ).fetchall()
        return [self._row_to_undo(r) for r in rows]

    def apply_undo(self, snapshot_id: int) -> tuple[UndoRecord | None, bool]:
        """Restore a snapshot into its character/creature row and drop the
        snapshot (no new snapshot is taken: undo is a stack, not a toggle).
        Returns (snapshot, restored); restored is False if the row is gone."""
        with self._lock, self._conn:
            row = self._conn.execute(
                "SELECT * FROM undo_snapshots WHERE id = ?", (snapshot_id,)
            ).fetchone()
            if row is None:
                return None, False
            snap = self._row_to_undo(row)
            table = "characters" if snap.entity_type == "character" else "creatures"
            name = snap.data.get("name", snap.entity_name)
            try:
                if table == "characters":
                    cur = self._conn.execute(
                        "UPDATE characters SET data = ?, name = ?, updated_at = ? WHERE id = ?",
                        (json.dumps(snap.data), name, time.time(), snap.entity_id),
                    )
                else:
                    cur = self._conn.execute(
                        "UPDATE creatures SET data = ?, name = ? WHERE id = ?",
                        (json.dumps(snap.data), name, snap.entity_id),
                    )
            except sqlite3.IntegrityError:
                # Restoring an old name that another sheet now uses: keep the
                # snapshot so the DM can rename the other sheet and retry.
                return snap, False
            self._conn.execute("DELETE FROM undo_snapshots WHERE id = ?", (snapshot_id,))
            return snap, cur.rowcount > 0

    def purge_undo(self, older_than: float) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM undo_snapshots WHERE created_at < ?", (older_than,))

    def delete_creature(self, creature_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM creatures WHERE id = ?", (creature_id,))
            self._conn.execute(
                "DELETE FROM undo_snapshots WHERE entity_type = 'creature' AND entity_id = ?",
                (creature_id,),
            )

    # -- combat log channel ----------------------------------------------------
    def set_log_channel(self, guild_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO combat_log_channels (guild_id, channel_id) VALUES (?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, channel_id),
            )

    def get_log_channel(self, guild_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM combat_log_channels WHERE guild_id = ?",
                (guild_id,),
            ).fetchone()
        return row["channel_id"] if row else None

    def clear_log_channel(self, guild_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM combat_log_channels WHERE guild_id = ?", (guild_id,)
            )

    # -- XP log channel (Kami only) --------------------------------------------
    # -- NPC templates --------------------------------------------------------
    def save_npc_template(self, guild_id: str, name: str, data: dict, created_by: str = "") -> None:
        """Insert or replace the template with this (case-insensitive) name."""
        now = time.time()
        payload = json.dumps(data)
        with self._lock, self._conn:
            row = self._conn.execute(
                "SELECT id FROM npc_templates WHERE guild_id = ? AND name = ? COLLATE NOCASE", (guild_id, name),
            ).fetchone()
            if row:
                self._conn.execute(
                    "UPDATE npc_templates SET name = ?, data = ?, created_by = ?, updated_at = ? WHERE id = ?",
                    (name, payload, created_by, now, row["id"]),
                )
            else:
                self._conn.execute(
                    "INSERT INTO npc_templates (guild_id, name, data, created_by, created_at, updated_at)"
                    " VALUES (?, ?, ?, ?, ?, ?)",
                    (guild_id, name, payload, created_by, now, now),
                )

    def get_npc_template(self, guild_id: str, name: str) -> tuple[str, dict] | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT name, data FROM npc_templates WHERE guild_id = ? AND name = ? COLLATE NOCASE", (guild_id, name),
            ).fetchone()
        return (row["name"], json.loads(row["data"])) if row else None

    def list_npc_templates(self, guild_id: str) -> list[tuple[str, dict]]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT name, data FROM npc_templates WHERE guild_id = ? ORDER BY name COLLATE NOCASE", (guild_id,),
            ).fetchall()
        return [(r["name"], json.loads(r["data"])) for r in rows]

    def delete_npc_template(self, guild_id: str, name: str) -> bool:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "DELETE FROM npc_templates WHERE guild_id = ? AND name = ? COLLATE NOCASE", (guild_id, name),
            )
        return cur.rowcount > 0

    def set_xp_log_channel(self, guild_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO xp_log_channels (guild_id, channel_id) VALUES (?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, channel_id),
            )

    def get_xp_log_channel(self, guild_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM xp_log_channels WHERE guild_id = ?", (guild_id,)
            ).fetchone()
        return row["channel_id"] if row else None

    def clear_xp_log_channel(self, guild_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM xp_log_channels WHERE guild_id = ?", (guild_id,))

    # -- DM approval channel ---------------------------------------------------
    def set_approval_channel(self, guild_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO approval_channels (guild_id, channel_id) VALUES (?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, channel_id),
            )

    def get_approval_channel(self, guild_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM approval_channels WHERE guild_id = ?",
                (guild_id,),
            ).fetchone()
        return row["channel_id"] if row else None

    def clear_approval_channel(self, guild_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM approval_channels WHERE guild_id = ?", (guild_id,)
            )

    # -- DM damage approval channel --------------------------------------------
    def set_damage_approval_channel(self, guild_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO damage_approval_channels (guild_id, channel_id) VALUES (?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, channel_id),
            )

    def get_damage_approval_channel(self, guild_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM damage_approval_channels WHERE guild_id = ?",
                (guild_id,),
            ).fetchone()
        return row["channel_id"] if row else None

    def clear_damage_approval_channel(self, guild_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM damage_approval_channels WHERE guild_id = ?", (guild_id,)
            )

    # -- date display channel --------------------------------------------------
    def set_date_channel(self, guild_id: str, channel_id: str, message_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO date_channels (guild_id, channel_id, message_id) VALUES (?, ?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id, "
                "message_id = excluded.message_id",
                (guild_id, channel_id, message_id),
            )

    def get_date_channel(self, guild_id: str) -> tuple[str, str] | None:
        """Return (channel_id, message_id) or None."""
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id, message_id FROM date_channels WHERE guild_id = ?",
                (guild_id,),
            ).fetchone()
        if row is None:
            return None
        return (row["channel_id"], row["message_id"])

    def clear_date_channel(self, guild_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM date_channels WHERE guild_id = ?", (guild_id,)
            )

    # -- creation channel (private wizard channels) ----------------------------
    def set_creation_channel(self, guild_id: str, user_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO creation_channels (guild_id, user_id, channel_id) VALUES (?, ?, ?) "
                "ON CONFLICT(guild_id, user_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, user_id, channel_id),
            )

    def get_creation_channel(self, guild_id: str, user_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM creation_channels WHERE guild_id = ? AND user_id = ?",
                (guild_id, user_id),
            ).fetchone()
        return row["channel_id"] if row else None

    def save_creation_state(self, guild_id: str, user_id: str, state_json: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "UPDATE creation_channels SET state = ? WHERE guild_id = ? AND user_id = ?",
                (state_json, guild_id, user_id),
            )

    def get_creation_state(self, guild_id: str, user_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT state FROM creation_channels WHERE guild_id = ? AND user_id = ?",
                (guild_id, user_id),
            ).fetchone()
        return row["state"] if row and row["state"] else None

    def delete_creation_channel(self, guild_id: str, user_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM creation_channels WHERE guild_id = ? AND user_id = ?",
                (guild_id, user_id),
            )


    # -- encounter persistence -------------------------------------------------
    def save_encounter(self, channel_id: str, guild_id: str, data: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO encounters (channel_id, guild_id, data, updated_at) "
                "VALUES (?, ?, ?, ?) ON CONFLICT(channel_id) "
                "DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at",
                (channel_id, guild_id, data, time.time()),
            )

    def delete_encounter(self, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM encounters WHERE channel_id = ?", (channel_id,)
            )

    def load_all_encounters(self) -> list[tuple[str, str]]:
        """Return (channel_id, data_json) for every saved encounter."""
        with self._lock:
            rows = self._conn.execute("SELECT channel_id, data FROM encounters").fetchall()
        return [(r["channel_id"], r["data"]) for r in rows]

    # -- macros (saved rolls) ---------------------------------------------------
    def _row_to_macro(self, row: sqlite3.Row) -> MacroRecord:
        return MacroRecord(
            id=row["id"], guild_id=row["guild_id"], user_id=row["user_id"],
            name=row["name"], rolled=row["rolled"], kept=row["kept"],
            modifier=row["modifier"], label=row["label"],
        )

    def save_macro(
        self, guild_id: str, user_id: str, name: str,
        rolled: int, kept: int, modifier: int = 0, label: str = "",
    ) -> MacroRecord:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO macros (guild_id, user_id, name, rolled, kept, modifier, label) "
                "VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(guild_id, user_id, name COLLATE NOCASE) "
                "DO UPDATE SET rolled = excluded.rolled, kept = excluded.kept, "
                "modifier = excluded.modifier, label = excluded.label",
                (guild_id, user_id, name, rolled, kept, modifier, label),
            )
            row = self._conn.execute(
                "SELECT * FROM macros WHERE guild_id = ? AND user_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, user_id, name),
            ).fetchone()
        return self._row_to_macro(row)

    def list_macros(self, guild_id: str, user_id: str) -> list[MacroRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM macros WHERE guild_id = ? AND user_id = ? ORDER BY name",
                (guild_id, user_id),
            ).fetchall()
        return [self._row_to_macro(r) for r in rows]

    def get_macro(self, guild_id: str, user_id: str, name: str) -> MacroRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM macros WHERE guild_id = ? AND user_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, user_id, name),
            ).fetchone()
        if row is None:
            return None
        return self._row_to_macro(row)

    def delete_macro(self, guild_id: str, user_id: str, name: str) -> bool:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "DELETE FROM macros WHERE guild_id = ? AND user_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, user_id, name),
            )
        return cur.rowcount > 0

    # -- calendar ---------------------------------------------------------------
    def get_calendar(self, guild_id: str) -> tuple[int, int, int] | None:
        """Return (year, month, day) or None if no date has been set."""
        with self._lock:
            row = self._conn.execute(
                "SELECT year, month, day FROM calendar WHERE guild_id = ?", (guild_id,)
            ).fetchone()
        if row is None:
            return None
        return (row["year"], row["month"], row["day"])

    def set_calendar(self, guild_id: str, year: int, month: int, day: int) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO calendar (guild_id, year, month, day) VALUES (?, ?, ?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET year = excluded.year, "
                "month = excluded.month, day = excluded.day",
                (guild_id, year, month, day),
            )

    # -- categories ---------------------------------------------------------------
    def create_category(self, guild_id: str, name: str) -> CategoryRecord:
        try:
            with self._lock, self._conn:
                cur = self._conn.execute(
                    "INSERT INTO categories (guild_id, name) VALUES (?, ?)",
                    (guild_id, name),
                )
                return CategoryRecord(cur.lastrowid, guild_id, name)
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(name) from exc

    def get_category(self, guild_id: str, name: str) -> CategoryRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM categories WHERE guild_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, name),
            ).fetchone()
        if row is None:
            return None
        return CategoryRecord(row["id"], row["guild_id"], row["name"])

    def list_categories(self, guild_id: str) -> list[CategoryRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM categories WHERE guild_id = ? ORDER BY name COLLATE NOCASE",
                (guild_id,),
            ).fetchall()
        return [CategoryRecord(r["id"], r["guild_id"], r["name"]) for r in rows]

    def delete_category(self, category_id: int) -> None:
        with self._lock, self._conn:
            # category_members FK CASCADE handles cleanup automatically
            self._conn.execute("DELETE FROM categories WHERE id = ?", (category_id,))

    def rename_category(self, category_id: int, new_name: str) -> None:
        try:
            with self._lock, self._conn:
                self._conn.execute(
                    "UPDATE categories SET name = ? WHERE id = ?",
                    (new_name, category_id),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(new_name) from exc

    def add_to_category(self, category_id: int, entity_type: str, entity_name: str) -> bool:
        try:
            with self._lock, self._conn:
                self._conn.execute(
                    "INSERT INTO category_members (category_id, entity_type, entity_name) "
                    "VALUES (?, ?, ?)",
                    (category_id, entity_type, entity_name),
                )
            return True
        except sqlite3.IntegrityError:
            return False

    def remove_from_category(self, category_id: int, entity_type: str, entity_name: str) -> bool:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "DELETE FROM category_members "
                "WHERE category_id = ? AND entity_type = ? AND entity_name = ? COLLATE NOCASE",
                (category_id, entity_type, entity_name),
            )
        return cur.rowcount > 0

    def list_category_members(self, category_id: int) -> list[tuple[str, str]]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT entity_type, entity_name FROM category_members "
                "WHERE category_id = ? ORDER BY entity_type, entity_name COLLATE NOCASE",
                (category_id,),
            ).fetchall()
        return [(r["entity_type"], r["entity_name"]) for r in rows]

    def category_count(self, category_id: int) -> int:
        with self._lock:
            row = self._conn.execute(
                "SELECT COUNT(*) AS cnt FROM category_members WHERE category_id = ?",
                (category_id,),
            ).fetchone()
        return row["cnt"]

    def list_entity_categories(self, guild_id: str, entity_type: str, entity_name: str) -> list[CategoryRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT c.* FROM categories c "
                "JOIN category_members m ON c.id = m.category_id "
                "WHERE c.guild_id = ? AND m.entity_type = ? AND m.entity_name = ? COLLATE NOCASE "
                "ORDER BY c.name COLLATE NOCASE",
                (guild_id, entity_type, entity_name),
            ).fetchall()
        return [CategoryRecord(r["id"], r["guild_id"], r["name"]) for r in rows]

    # -- location areas (Discord categories representing places) ----------------
    def _row_to_location_area(self, row: sqlite3.Row) -> LocationAreaRecord:
        return LocationAreaRecord(row["id"], row["guild_id"], row["category_id"], row["name"], row["creator_id"])

    def create_location_area(
        self, guild_id: str, category_id: str, name: str, creator_id: str,
    ) -> LocationAreaRecord:
        try:
            with self._lock, self._conn:
                cur = self._conn.execute(
                    "INSERT INTO location_areas (guild_id, category_id, name, creator_id, created_at) "
                    "VALUES (?, ?, ?, ?, ?)",
                    (guild_id, category_id, name, creator_id, time.time()),
                )
                return LocationAreaRecord(cur.lastrowid, guild_id, category_id, name, creator_id)
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(name) from exc

    def get_location_area(self, guild_id: str, name: str) -> LocationAreaRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM location_areas WHERE guild_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, name),
            ).fetchone()
        if row is None:
            return None
        return self._row_to_location_area(row)

    def list_location_areas(self, guild_id: str) -> list[LocationAreaRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM location_areas WHERE guild_id = ? ORDER BY name COLLATE NOCASE",
                (guild_id,),
            ).fetchall()
        return [self._row_to_location_area(r) for r in rows]

    def delete_location_area(self, area_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM location_areas WHERE id = ?", (area_id,))

    # -- locations (text channels within an area) --------------------------------
    def _row_to_location(self, row: sqlite3.Row) -> LocationRecord:
        return LocationRecord(
            row["id"], row["guild_id"], row["area_id"], row["channel_id"],
            row["name"], row["creator_id"], row["description"],
        )

    def create_location(
        self, guild_id: str, area_id: int, channel_id: str, name: str, creator_id: str,
        description: str = "",
    ) -> LocationRecord:
        try:
            with self._lock, self._conn:
                cur = self._conn.execute(
                    "INSERT INTO locations (guild_id, area_id, channel_id, name, creator_id, description, created_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (guild_id, area_id, channel_id, name, creator_id, description, time.time()),
                )
                return LocationRecord(cur.lastrowid, guild_id, area_id, channel_id, name, creator_id, description)
        except sqlite3.IntegrityError as exc:
            raise DuplicateNameError(name) from exc

    def get_location(self, guild_id: str, area_id: int, name: str) -> LocationRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM locations WHERE guild_id = ? AND area_id = ? AND name = ? COLLATE NOCASE",
                (guild_id, area_id, name),
            ).fetchone()
        if row is None:
            return None
        return self._row_to_location(row)

    def get_location_by_channel(self, channel_id: str) -> LocationRecord | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM locations WHERE channel_id = ?", (channel_id,),
            ).fetchone()
        if row is None:
            return None
        return self._row_to_location(row)

    def list_locations(self, area_id: int) -> list[LocationRecord]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT * FROM locations WHERE area_id = ? ORDER BY name COLLATE NOCASE",
                (area_id,),
            ).fetchall()
        return [self._row_to_location(r) for r in rows]

    def update_location_description(self, location_id: int, description: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "UPDATE locations SET description = ? WHERE id = ?",
                (description, location_id),
            )

    def delete_location(self, location_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute("DELETE FROM locations WHERE id = ?", (location_id,))

    # ------------------------------------------------------------------
    # Rumor board
    # ------------------------------------------------------------------

    def create_rumor(
        self,
        guild_id: str,
        title: str,
        content: str,
        tier: str,
        filters: list[tuple[str, str]],
        author_id: str,
        *,
        public: bool = False,
    ) -> int:
        with self._lock, self._conn:
            cur = self._conn.execute(
                "INSERT INTO rumors (guild_id, title, content, tier, public, author_id, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (guild_id, title, content, tier, int(public), author_id, time.time()),
            )
            rumor_id = cur.lastrowid
            for ftype, fvalue in filters:
                self._conn.execute(
                    "INSERT INTO rumor_filters (rumor_id, filter_type, filter_value) VALUES (?, ?, ?)",
                    (rumor_id, ftype, fvalue),
                )
        return rumor_id

    def list_rumors(self, guild_id: str, *, limit: int = 25) -> list[dict]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT id, title, tier, public, author_id, created_at FROM rumors "
                "WHERE guild_id = ? ORDER BY created_at DESC LIMIT ?",
                (guild_id, limit),
            ).fetchall()
            result: list[dict] = []
            for r in rows:
                filters = self._conn.execute(
                    "SELECT filter_type, filter_value FROM rumor_filters WHERE rumor_id = ?",
                    (r["id"],),
                ).fetchall()
                targets = ", ".join(f"{f['filter_type']}: {f['filter_value']}" for f in filters)
                result.append({
                    "id": r["id"],
                    "title": r["title"],
                    "tier": r["tier"],
                    "public": bool(r["public"]),
                    "targets": targets,
                })
        return result

    def list_rumors_for_character(
        self, guild_id: str, character, *, limit: int = 25,
    ) -> list[dict]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT id, title, tier, public, author_id, created_at FROM rumors "
                "WHERE guild_id = ? ORDER BY created_at DESC",
                (guild_id,),
            ).fetchall()
            result: list[dict] = []
            for r in rows:
                if r["public"]:
                    result.append({
                        "id": r["id"],
                        "title": r["title"],
                        "tier": r["tier"],
                        "public": True,
                        "targets": "",
                    })
                    if len(result) >= limit:
                        break
                    continue
                filters = self._conn.execute(
                    "SELECT filter_type, filter_value FROM rumor_filters WHERE rumor_id = ?",
                    (r["id"],),
                ).fetchall()
                filter_list = [(f["filter_type"], f["filter_value"]) for f in filters]
                if self._character_matches(character, filter_list):
                    result.append({
                        "id": r["id"],
                        "title": r["title"],
                        "tier": r["tier"],
                        "public": False,
                        "targets": "",
                    })
                    if len(result) >= limit:
                        break
        return result

    @staticmethod
    def _character_matches(char, filters: list[tuple[str, str]]) -> bool:
        for ftype, fvalue in filters:
            fval_lower = fvalue.lower()
            if ftype == "clan" and char.clan.lower() == fval_lower:
                return True
            if ftype == "family" and char.family.lower() == fval_lower:
                return True
            if ftype == "school" and char.school.lower() == fval_lower:
                return True
            if ftype == "school_type" and char.school_type.lower() == fval_lower:
                return True
            if ftype == "character" and char.name.lower() == fval_lower:
                return True
        return False

    def get_rumor(self, guild_id: str, rumor_id: int) -> dict | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT id, title, content, tier, public, author_id, created_at "
                "FROM rumors WHERE guild_id = ? AND id = ?",
                (guild_id, rumor_id),
            ).fetchone()
            if row is None:
                return None
            filters = self._conn.execute(
                "SELECT filter_type, filter_value FROM rumor_filters WHERE rumor_id = ?",
                (rumor_id,),
            ).fetchall()
        targets = ", ".join(f"{f['filter_type']}: {f['filter_value']}" for f in filters)
        return {
            "id": row["id"],
            "title": row["title"],
            "content": row["content"],
            "tier": row["tier"],
            "public": bool(row["public"]),
            "author_id": row["author_id"],
            "targets": targets,
        }

    def get_rumor_filters(self, guild_id: str, rumor_id: int) -> list[tuple[str, str]]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT filter_type, filter_value FROM rumor_filters WHERE rumor_id = ?",
                (rumor_id,),
            ).fetchall()
        return [(r["filter_type"], r["filter_value"]) for r in rows]

    def delete_rumor(self, guild_id: str, rumor_id: int) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "DELETE FROM rumor_filters WHERE rumor_id = ?", (rumor_id,),
            )
            self._conn.execute(
                "DELETE FROM rumors WHERE guild_id = ? AND id = ?",
                (guild_id, rumor_id),
            )

    def set_rumor_board_channel(self, guild_id: str, channel_id: str) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "INSERT INTO rumor_board_channels (guild_id, channel_id) VALUES (?, ?) "
                "ON CONFLICT(guild_id) DO UPDATE SET channel_id = excluded.channel_id",
                (guild_id, channel_id),
            )

    def get_rumor_board_channel(self, guild_id: str) -> str | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT channel_id FROM rumor_board_channels WHERE guild_id = ?",
                (guild_id,),
            ).fetchone()
        return row["channel_id"] if row else None
