"""/whoami: the character hub. The quick status card plus buttons and menus for
the things a player does with their own sheet between fights: spend or refresh
Void, set the active Kata, Kiho and tattoo, open the inventory panel, view the
full sheet, export it. Rules live in the bot's shared helpers; nothing here
changes a value the commands would not.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Awaitable, Callable

import discord
from discord import app_commands

import portraits
import storage
from l5r_rules import stats, taint, tattoo_catalog

HUB_IDLE_SECONDS: float = 900.0


@dataclass
class _Deps:
    store: Any
    require_guild: Callable[[discord.Interaction], Awaitable[bool]]
    build_sheet_embed: Callable[[storage.CharacterRecord], discord.Embed]
    whoami_lines: Callable[[discord.Interaction, storage.CharacterRecord], list[str]]
    activate_kata: Callable[[Any, str | None], tuple[bool, str]]
    activate_kiho: Callable[[Any, str, bool], tuple[bool, str]]
    tally: Callable[..., None]
    export_callback: Callable[..., Awaitable[None]]
    fight_status_callback: Callable[..., Awaitable[None]]
    inventory_callback: Callable[..., Awaitable[None]]
    is_dm: Callable[[discord.Interaction], bool]


_d: _Deps = None  # type: ignore[assignment]


def hub_embed(interaction: discord.Interaction, rec: storage.CharacterRecord) -> discord.Embed:
    lines = _d.whoami_lines(interaction, rec)
    embed = discord.Embed(description="\n".join(lines)[:4096], color=discord.Color.gold())
    portraits.apply(embed, rec)
    return embed


class _VoidReasonModal(discord.ui.Modal, title="Spend a Void Point"):
    reason = discord.ui.TextInput(label="What for?", placeholder="+1k1 on Investigation check", max_length=100)

    def __init__(self, hub: "CharacterHub") -> None:
        super().__init__()
        self.hub = hub

    async def on_submit(self, interaction: discord.Interaction) -> None:
        rec = self.hub.reload()
        if rec is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        c = rec.character
        if stats.is_dead(c):
            await interaction.response.send_message(
                f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{c.name}** has no Void Points remaining (0/{taint.void_point_cap(c)}).", ephemeral=True)
            return
        c.current_void_points -= 1
        _d.tally(interaction.channel_id, c.name, "void")
        _d.store.save(rec)
        if not await self.hub.refresh(interaction):
            return
        await interaction.followup.send(
            f"**{c.name}** spends a Void Point: {self.reason.value.strip()}\n"
            f"  VP remaining: **{c.current_void_points}/{taint.void_point_cap(c)}**",
            ephemeral=True)


class _Pick(discord.ui.Select):
    def __init__(self, placeholder: str, options: list[discord.SelectOption], handler, row: int) -> None:
        super().__init__(placeholder=placeholder[:150], options=options[:25], row=row)
        self._handler = handler

    async def callback(self, interaction: discord.Interaction) -> None:
        value = self.values[0] if self.values else ""
        # Discord rejects empty option values, so "none" options carry a sentinel.
        await self._handler(interaction, "" if value == "__none__" else value)


class CharacterHub(discord.ui.View):
    def __init__(self, rec: storage.CharacterRecord, user_id: int) -> None:
        super().__init__(timeout=HUB_IDLE_SECONDS)
        self.rec = rec
        self.user_id = user_id
        self.build()

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.user_id:
            await interaction.response.send_message("That is someone else's card. Run `/whoami` for yours.", ephemeral=True)
            return False
        return True

    def reload(self) -> storage.CharacterRecord | None:
        fresh = _d.store.get_by_id(self.rec.id)
        if fresh is not None:
            self.rec = fresh
        return fresh

    async def refresh(self, interaction: discord.Interaction) -> bool:
        if self.reload() is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return False
        self.build()
        await interaction.response.edit_message(content=None, embed=hub_embed(interaction, self.rec), view=self)
        return True

    def build(self) -> None:
        self.clear_items()
        c = self.rec.character
        for label, style, cb, emoji in (
            ("Full sheet", discord.ButtonStyle.primary, self._on_sheet, None),
            ("Inventory", discord.ButtonStyle.primary, self._on_inventory, None),
            ("Spend Void", discord.ButtonStyle.secondary, self._on_void, None),
            ("Rest: Refresh Void", discord.ButtonStyle.secondary, self._on_rest, None),
            ("Fight status", discord.ButtonStyle.secondary, self._on_fight, None),
        ):
            b = discord.ui.Button(label=label, style=style, row=0, emoji=emoji)
            b.callback = cb
            self.add_item(b)
        row = 1
        if c.katas:
            opts = [discord.SelectOption(label="(drop the active Kata)", value="__none__", default=not c.active_kata)] + [
                discord.SelectOption(label=k[:100], value=k[:100], default=k == c.active_kata) for k in c.katas]
            self.add_item(_Pick("Active Kata...", opts, self._on_kata, row)); row += 1
        if c.kiho:
            opts = [discord.SelectOption(label=(("[+] " if k in c.active_kiho else "") + k)[:100], value=k[:100],
                                         description="active: Pick to end" if k in c.active_kiho else None) for k in c.kiho]
            self.add_item(_Pick("Kiho: Pick to activate, pick again to end...", opts, self._on_kiho, row)); row += 1
        if c.tattoos:
            opts = [discord.SelectOption(label="(deactivate tattoo)", value="__none__", default=not c.active_tattoo)] + [
                discord.SelectOption(label=t[:100], value=t[:100], default=t.lower() == (c.active_tattoo or "").lower()) for t in c.tattoos]
            self.add_item(_Pick("Active tattoo...", opts, self._on_tattoo, row)); row += 1
        for label, cb in (("Export JSON", self._on_export), ("Refresh", self._on_refresh), ("Done", self._on_done)):
            b = discord.ui.Button(label=label, style=discord.ButtonStyle.secondary, row=4)
            b.callback = cb
            self.add_item(b)

    # -- handlers ------------------------------------------------------------
    async def _on_sheet(self, interaction: discord.Interaction) -> None:
        if self.reload() is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        await interaction.response.send_message(embed=_d.build_sheet_embed(self.rec), ephemeral=True)

    async def _on_inventory(self, interaction: discord.Interaction) -> None:
        await _d.inventory_callback(interaction)

    async def _on_fight(self, interaction: discord.Interaction) -> None:
        await _d.fight_status_callback(interaction)

    async def _on_export(self, interaction: discord.Interaction) -> None:
        await _d.export_callback(interaction)

    async def _on_void(self, interaction: discord.Interaction) -> None:
        await interaction.response.send_modal(_VoidReasonModal(self))

    async def _on_rest(self, interaction: discord.Interaction) -> None:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(
                "Resting requires a **Fortune** (or **Kami**) to authorise. "
                "Use Meditation (via `/void refresh mode:meditation`) to recover 1 VP on your own.",
                ephemeral=True)
            return
        rec = self.reload()
        if rec is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        c = rec.character
        if stats.is_dead(c):
            await interaction.response.send_message(
                f"**{c.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        cap = taint.void_point_cap(c)
        old = c.current_void_points
        c.current_void_points = cap
        _d.store.save(rec)
        cap_note = f" (Taint Rank {taint.taint_rank(c)}: Max VP -1)" if cap < c.max_void_points else ""
        if not await self.refresh(interaction):
            return
        await interaction.followup.send(
            f"**{c.name}** rests and recovers all Void Points.\n  VP: {old} → **{c.current_void_points}/{cap}**{cap_note}",
            ephemeral=True)

    async def _apply(self, interaction: discord.Interaction, ok: bool, msg: str) -> None:
        if not ok:
            await interaction.response.send_message(msg, ephemeral=True)
            return
        _d.store.save(self.rec)
        if not await self.refresh(interaction):
            return
        await interaction.followup.send(msg, ephemeral=True)

    async def _on_kata(self, interaction: discord.Interaction, value: str) -> None:
        if self.reload() is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        if stats.is_dead(self.rec.character):
            await interaction.response.send_message(
                f"**{self.rec.character.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        ok, msg = _d.activate_kata(self.rec.character, value or None)
        await self._apply(interaction, ok, msg)

    async def _on_kiho(self, interaction: discord.Interaction, value: str) -> None:
        if self.reload() is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        if stats.is_dead(self.rec.character):
            await interaction.response.send_message(
                f"**{self.rec.character.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        c = self.rec.character
        off = value.lower() in [x.lower() for x in c.active_kiho]
        ok, msg = _d.activate_kiho(c, value, off)
        await self._apply(interaction, ok, msg)

    async def _on_tattoo(self, interaction: discord.Interaction, value: str) -> None:
        if self.reload() is None:
            await interaction.response.send_message("That character no longer exists.", ephemeral=True)
            return
        if stats.is_dead(self.rec.character):
            await interaction.response.send_message(
                f"**{self.rec.character.name}** is dead. PC death is permanent.", ephemeral=True)
            return
        c = self.rec.character
        if not value:
            old = c.active_tattoo or "(none)"
            c.active_tattoo, c.bear_tattoo_choice, c.lion_tattoo_skill = "", "", ""
            await self._apply(interaction, True, f"**{c.name}** deactivates the **{old}** tattoo.")
            return
        key = value.lower().strip()
        if key in ("bear", "lion"):
            await interaction.response.send_message(
                f"The {value} tattoo needs a choice: Use `/sheet tattoo activate name:{value}` with "
                f"`{'choice' if key == 'bear' else 'skill'}:`.", ephemeral=True)
            return
        t = tattoo_catalog.get_tattoo(key)
        label = t["name"] if t else key.title()
        c.active_tattoo, c.bear_tattoo_choice, c.lion_tattoo_skill = label, "", ""
        effect = f"\n> {t['effect']}" if t else ""
        await self._apply(interaction, True, f"**{c.name}** activates the **{label}** tattoo.{effect}")

    async def _on_refresh(self, interaction: discord.Interaction) -> None:
        await self.refresh(interaction)

    async def _on_done(self, interaction: discord.Interaction) -> None:
        self.stop()
        await interaction.response.edit_message(content=None, embed=hub_embed(interaction, self.rec), view=None)


@app_commands.command(name="whoami", description="Your character hub: Status card with buttons for Void, Kata, Kiho, tattoos, inventory, sheet.")
async def whoami(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    rec = _d.store.get_active(str(interaction.guild_id), str(interaction.user.id))
    if rec is None:
        await interaction.response.send_message("You have no active character. Use `/sheet create` first.", ephemeral=True)
        return
    hub = CharacterHub(rec, interaction.user.id)
    await interaction.response.send_message(embed=hub_embed(interaction, rec), view=hub, ephemeral=True, **portraits.send_kwargs(rec))


def init(*, tree: app_commands.CommandTree, store, require_guild, build_sheet_embed, whoami_lines, activate_kata,
         activate_kiho, tally, export_callback, fight_status_callback, inventory_callback, is_dm) -> None:
    global _d
    _d = _Deps(store=store, require_guild=require_guild, build_sheet_embed=build_sheet_embed, whoami_lines=whoami_lines,
               activate_kata=activate_kata, activate_kiho=activate_kiho, tally=tally, export_callback=export_callback,
               fight_status_callback=fight_status_callback, inventory_callback=inventory_callback, is_dm=is_dm)
    tree.add_command(whoami)
