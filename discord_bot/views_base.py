"""Approval views that survive a bot restart.

discord.py only dispatches button clicks to views it knows about, and a
restart forgets every live view. A PersistentView subclass declares a KIND;
when the view is attached to a message (persist()), its constructor
arguments and the auto-generated custom_ids of its buttons are saved. On
startup restore_all() rebuilds each saved view with the same arguments,
re-applies the custom_ids and registers it against its message id, so the
buttons keep working after a deploy. A resolved view (_disable()) deletes
its row; rows older than MAX_AGE_SECONDS are purged at startup.
"""

from __future__ import annotations

import inspect
import json
import logging
import time

import discord

log = logging.getLogger(__name__)

MAX_AGE_SECONDS = 7 * 24 * 3600

_REGISTRY: dict[str, type] = {}
_store = None


def init(store) -> None:
    global _store
    _store = store


class PersistentView(discord.ui.View):
    KIND: str = ""

    def __init_subclass__(cls, **kwargs) -> None:
        super().__init_subclass__(**kwargs)
        if not cls.KIND:
            return
        _REGISTRY[cls.KIND] = cls
        orig_init = cls.__init__
        sig = inspect.signature(orig_init)

        def __init__(self, *args, **kwargs):
            bound = sig.bind(self, *args, **kwargs)
            bound.apply_defaults()
            captured = dict(bound.arguments)
            captured.pop("self", None)
            orig_init(self, *args, **kwargs)
            self._persist_args = captured

        cls.__init__ = __init__

    def __init__(self, *, timeout: float | None = None) -> None:
        # Persistent views never time out; stale rows are purged by age instead.
        super().__init__(timeout=None)
        self._persist_args: dict = {}
        self._persist_message_id: int | None = None

    def _disable(self) -> None:
        for child in self.children:
            child.disabled = True
        self.stop()
        self.forget()

    async def persist(self, message: discord.Message | None) -> None:
        if not self.KIND or _store is None or message is None:
            return
        self._persist_message_id = message.id
        payload = {
            "args": self._persist_args,
            "custom_ids": [getattr(child, "custom_id", None) for child in self.children],
        }
        try:
            state = json.dumps(payload, default=lambda o: None)
        except (TypeError, ValueError):
            log.warning("Could not serialise %s view state; it will not survive a restart", self.KIND)
            return
        guild_id = str(message.guild.id) if message.guild else ""
        channel = getattr(message, "channel", None)
        channel_id = str(channel.id) if channel is not None and getattr(channel, "id", None) else ""
        _store.save_pending_view(str(message.id), guild_id, self.KIND, state, channel_id)

    def forget(self) -> None:
        if self._persist_message_id is not None and _store is not None:
            _store.delete_pending_view(str(self._persist_message_id))
            self._persist_message_id = None


def restore_all(client: discord.Client) -> int:
    """Rebuild every saved view and re-attach it to its message. Returns the count."""
    if _store is None:
        return 0
    _store.purge_pending_views(time.time() - MAX_AGE_SECONDS)
    restored = 0
    for message_id, kind, state in _store.load_pending_views():
        cls = _REGISTRY.get(kind)
        if cls is None:
            _store.delete_pending_view(message_id)
            continue
        try:
            payload = json.loads(state)
            view = cls(**payload["args"])
            for child, custom_id in zip(view.children, payload["custom_ids"]):
                if custom_id:
                    child.custom_id = custom_id
            view._persist_message_id = int(message_id)
            client.add_view(view, message_id=int(message_id))
            restored += 1
        except Exception:
            log.warning("Dropping unrestorable %s view for message %s", kind, message_id, exc_info=True)
            _store.delete_pending_view(message_id)
    return restored
