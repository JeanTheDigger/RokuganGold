"""Character portraits: An image a player attaches to their character.

A portrait is either a link (http/https, hosted elsewhere) or a file the bot
keeps under PORTRAIT_DIR. Files are re-attached to every message that shows
them and referenced as attachment://, so nothing depends on Discord's expiring
attachment links. The Character stores the portrait as "https://..." or
"file:<name>".
"""

from __future__ import annotations

import os
from pathlib import Path

import discord

import storage

PORTRAIT_DIR = Path(os.environ.get("PORTRAIT_DIR", "portraits"))
MAX_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES: dict[str, str] = {
    "image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp",
}


def _file_name(rec: storage.CharacterRecord) -> str | None:
    p = rec.character.portrait or ""
    return p[5:] if p.startswith("file:") else None


def file_path(rec: storage.CharacterRecord) -> Path | None:
    """The stored portrait file, if the character has one and it still exists."""
    name = _file_name(rec)
    if not name:
        return None
    path = PORTRAIT_DIR / name
    return path if path.is_file() else None


def has_portrait(rec: storage.CharacterRecord) -> bool:
    p = rec.character.portrait or ""
    return p.startswith("http") or file_path(rec) is not None


def _attachment_name(path: Path) -> str:
    return f"portrait{path.suffix.lower()}"


def apply(embed: discord.Embed, rec: storage.CharacterRecord, *, large: bool = False) -> None:
    """Point the embed's thumbnail (or main image) at the portrait. A file portrait
    is referenced as attachment://, so the sender must also attach file(rec)."""
    p = rec.character.portrait or ""
    url: str | None = None
    if p.startswith("http"):
        url = p
    else:
        path = file_path(rec)
        if path is not None:
            url = f"attachment://{_attachment_name(path)}"
    if url is None:
        return
    if large:
        embed.set_image(url=url)
    else:
        embed.set_thumbnail(url=url)


def file(rec: storage.CharacterRecord) -> discord.File | None:
    """A fresh discord.File for a file portrait, or None. Make a new one per send."""
    path = file_path(rec)
    if path is None:
        return None
    return discord.File(path, filename=_attachment_name(path))


def send_kwargs(rec: storage.CharacterRecord) -> dict:
    """Extra keyword arguments for a send that shows this character's portrait."""
    f = file(rec)
    return {"file": f} if f is not None else {}


async def save_upload(rec: storage.CharacterRecord, attachment: discord.Attachment) -> tuple[bool, str]:
    """Store an uploaded image for the character. Returns (ok, portrait value or error)."""
    ctype = (attachment.content_type or "").split(";")[0].strip().lower()
    ext = ALLOWED_TYPES.get(ctype)
    if ext is None:
        return False, "The image must be a PNG, JPEG, GIF or WebP file."
    if attachment.size > MAX_BYTES:
        return False, f"The image is {attachment.size / (1024 * 1024):.1f} MB; the limit is {MAX_BYTES // (1024 * 1024)} MB."
    data = await attachment.read()
    PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)
    name = f"{rec.guild_id}_{rec.id}{ext}"
    remove_file(rec)
    (PORTRAIT_DIR / name).write_bytes(data)
    return True, f"file:{name}"


def remove_file(rec: storage.CharacterRecord) -> None:
    """Delete the stored file for this character, if any (the record is not changed)."""
    name = _file_name(rec)
    if not name:
        return
    path = PORTRAIT_DIR / name
    try:
        path.unlink()
    except FileNotFoundError:
        pass
