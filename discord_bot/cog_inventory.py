"""/inventory: one ephemeral panel for a character's gear and purse.

Shows wielded weapons, armor, owned weapons, items and koku. Players can
wield/unwield, equip off-hand, drop weapons, remove items, and put on or
take off armor they own. Adding items/weapons, koku, assigning new armor,
and weapon qualities are staff-only.
Every change is saved with an undo snapshot and an audit line.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass
from typing import Any, Awaitable, Callable

import discord
from discord import app_commands

import storage
from l5r_rules import combat

log = logging.getLogger(__name__)

PANEL_IDLE_SECONDS: float = 900.0


@dataclass
class _Deps:
    store: Any
    npc_owner: str
    require_guild: Callable[[discord.Interaction], Awaitable[bool]]
    is_dm: Callable[[discord.Interaction], bool]
    resolve_active_for_edit: Callable[..., Awaitable[tuple[storage.CharacterRecord | None, str | None]]]
    audit_stat: Callable[..., Awaitable[None]]
    modify_inventory: Callable[..., tuple[bool, str]]
    npc_autocomplete: Callable[..., Awaitable[list[app_commands.Choice[str]]]]
    role_fortune: str
    role_kami: str


_d: _Deps = None  # type: ignore[assignment]

_BOW_SKILLS: set[str] = {"kyujutsu"}
_ARROW_KEYWORDS: set[str] = {"arrow", "arrows"}


def _weapon_label(key: str) -> str:
    spec = combat.WEAPON_CATALOG.get(key.lower())
    if spec is None:
        return f"{key} (custom)"
    return f"{key.replace('_', ' ')} · DR {spec['rolled']}k{spec['kept']} · {spec['skill']}"


def _is_arrow(key: str) -> bool:
    return any(kw in key.lower() for kw in _ARROW_KEYWORDS)


def _is_bow(key: str) -> bool:
    spec = combat.WEAPON_CATALOG.get(key.lower())
    return spec is not None and spec.get("skill", "").lower() in _BOW_SKILLS


def _armor_label(key: str) -> str:
    spec = combat.ARMOR_CATALOG.get(key)
    if spec is None:
        return key.replace("_", " ")
    return f"{key.replace('_', ' ')} (TN +{spec['tn_bonus']}, Red {spec['reduction']})"


def build_inventory_embed(rec: storage.CharacterRecord) -> discord.Embed:
    c = rec.character
    embed = discord.Embed(title=f"{c.name}: Inventory", color=discord.Color.dark_gold())
    main = c.equipped_weapon.replace("_", " ") if c.equipped_weapon else "unarmed"
    off = f" + {c.off_hand_weapon.replace('_', ' ')} (off hand)" if c.off_hand_weapon else ""
    quals = f"\nQualities: {', '.join(c.weapon_qualities)}" if c.weapon_qualities else ""
    embed.add_field(name="In Hand", value=f"{main}{off}{quals}", inline=False)
    if c.armor_name:
        armor = f"{c.armor_name.replace('_', ' ')} (Armor TN +{c.armor_tn_bonus}, Reduction {c.armor_reduction})"
    elif c.owned_armor:
        armor = f"{c.owned_armor.replace('_', ' ')} (not worn)"
    else:
        armor = "none"
    embed.add_field(name="Armor", value=armor, inline=True)
    embed.add_field(name="Koku", value=f"{c.koku:g}", inline=True)
    weapons = "\n".join(f"• {_weapon_label(w)}" for w in c.weapons) if c.weapons else "none"
    embed.add_field(name=f"Weapons owned ({len(c.weapons)})", value=weapons[:1024], inline=False)
    items = "\n".join(f"• {n} × {q}" for n, q in sorted(c.inventory.items())) if c.inventory else "none"
    embed.add_field(name=f"Items ({sum(c.inventory.values())})", value=items[:1024], inline=False)
    return embed


class _ItemModal(discord.ui.Modal, title="Add an item"):
    name = discord.ui.TextInput(label="Item", placeholder="e.g. Travel rations", max_length=60)
    quantity = discord.ui.TextInput(label="Quantity", default="1", max_length=4)

    def __init__(self, panel: "InventoryPanel") -> None:
        super().__init__()
        self.panel = panel

    async def on_submit(self, interaction: discord.Interaction) -> None:
        try:
            qty = int(self.quantity.value.strip() or "1")
        except ValueError:
            await interaction.response.send_message("Quantity must be a whole number.", ephemeral=True)
            return
        if not 1 <= qty <= 9999:
            await interaction.response.send_message("Quantity must be 1-9999.", ephemeral=True)
            return
        c = self.panel.rec.character
        ok, msg = _d.modify_inventory(c.inventory, c.name, self.name.value.strip(), qty, False)
        if not ok:
            await interaction.response.send_message(msg, ephemeral=True)
            return
        await self.panel.commit(interaction, msg)


class _KokuModal(discord.ui.Modal, title="Koku: Add or Spend"):
    amount = discord.ui.TextInput(label="Amount (negative spends)", placeholder="5 or -2.5", max_length=10)
    reason = discord.ui.TextInput(label="Reason (optional)", required=False, max_length=100)

    def __init__(self, panel: "InventoryPanel") -> None:
        super().__init__()
        self.panel = panel

    async def on_submit(self, interaction: discord.Interaction) -> None:
        try:
            amount = float(self.amount.value.strip())
        except ValueError:
            await interaction.response.send_message("Amount must be a number, e.g. 5 or -2.5.", ephemeral=True)
            return
        if not math.isfinite(amount):
            await interaction.response.send_message("Amount must be a finite number.", ephemeral=True)
            return
        c = self.panel.rec.character
        if amount < 0 and c.koku + amount < 0:
            await interaction.response.send_message(
                f"**{c.name}** only has **{c.koku:g}** koku (tried to spend {abs(amount):g}).", ephemeral=True)
            return
        c.koku = round(c.koku + amount, 2)
        label = f"Received **{amount:g}** koku" if amount >= 0 else f"Spent **{abs(amount):g}** koku"
        why = f" ({self.reason.value.strip()})" if (self.reason.value or "").strip() else ""
        await self.panel.commit(interaction, f"{label}{why}. Balance: **{c.koku:g}** koku.")


class _Pick(discord.ui.Select):
    def __init__(self, placeholder: str, options: list[discord.SelectOption], handler, row: int,
                 max_values: int = 1) -> None:
        super().__init__(placeholder=placeholder[:150], options=options[:25], row=row,
                         min_values=0 if max_values > 1 else 1, max_values=min(max_values, len(options[:25]) or 1))
        self._handler = handler

    async def callback(self, interaction: discord.Interaction) -> None:
        await self._handler(interaction, list(self.values))


class InventoryPanel(discord.ui.View):
    """Rows: 0 main hand, 1 off hand, 2 action, 3 action detail, 4 Done."""

    ACTIONS: list[tuple[str, str, bool]] = [  # (value, label, staff_only)
        ("drop", "Drop a weapon (remove from owned)", False),
        ("remove_item", "Remove items", False),
        ("wear_armor", "Put on / take off armor", False),
        ("add_item", "Add an item (staff)", True),
        ("koku", "Koku: Add or spend (staff)", True),
        ("armor", "Assign armor (staff)", True),
        ("qualities", "Weapon qualities (staff)", True),
    ]

    def __init__(self, rec: storage.CharacterRecord, user_id: int, staff: bool) -> None:
        super().__init__(timeout=PANEL_IDLE_SECONDS)
        self.rec = rec
        self.user_id = user_id
        self.staff = staff
        self.action = ""      # current action value, or "add:<group>"
        self.status = ""      # last change, shown above the embed
        self.build()

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.user_id:
            await interaction.response.send_message("This inventory panel belongs to someone else. Run `/inventory` yourself.", ephemeral=True)
            return False
        return True

    # -- rendering -----------------------------------------------------------
    def content(self) -> str:
        head = f"Inventory of **{self.rec.character.name}**. Changes save immediately."
        return f"{head}\n{self.status}" if self.status else head

    async def render(self, interaction: discord.Interaction) -> None:
        self.build()
        await interaction.response.edit_message(content=self.content(), embed=build_inventory_embed(self.rec), view=self)

    async def commit(self, interaction: discord.Interaction, status: str, note: str = "inventory") -> None:
        changed = _d.store.save(self.rec, note=note)
        await _d.audit_stat(interaction, self.rec, note, changed)
        self.status = status
        self.action = ""
        await self.render(interaction)

    def build(self) -> None:
        self.clear_items()
        c = self.rec.character
        owned = [w for w in c.weapons]
        hand_opts = [discord.SelectOption(label="unarmed", value="", default=not c.equipped_weapon)] + [
            discord.SelectOption(label=_weapon_label(w)[:100], value=w, default=w.lower() == (c.equipped_weapon or "").lower()) for w in owned
        ]
        self.add_item(_Pick("Main hand...", hand_opts, self._on_main, 0))
        off_opts = [discord.SelectOption(label="(no off-hand)", value="", default=not c.off_hand_weapon)] + [
            discord.SelectOption(label=_weapon_label(w)[:100], value=w, default=w.lower() == (c.off_hand_weapon or "").lower()) for w in owned
        ]
        self.add_item(_Pick("Off hand...", off_opts, self._on_off, 1))
        groups = sorted({w["skill"] for w in combat.WEAPON_CATALOG.values()})
        action_opts = [discord.SelectOption(label=label, value=value, default=value == self.action)
                       for value, label, staff_only in self.ACTIONS if self.staff or not staff_only]
        if self.staff:
            action_opts += [discord.SelectOption(label=f"Add weapon: {g}", value=f"add:{g}", default=self.action == f"add:{g}") for g in groups]
        self.add_item(_Pick("Action...", action_opts, self._on_action, 2))
        if self.action.startswith("add:"):
            group = self.action[4:]
            opts = [discord.SelectOption(label=_weapon_label(k)[:100], value=k) for k, w in combat.WEAPON_CATALOG.items() if w["skill"] == group]
            self.add_item(_Pick(f"{group} weapon to add...", opts, self._on_add_weapon, 3))
        elif self.action == "drop" and owned:
            self.add_item(_Pick("Weapon to drop...", [discord.SelectOption(label=_weapon_label(w)[:100], value=w) for w in owned], self._on_drop, 3))
        elif self.action == "remove_item" and c.inventory:
            opts = [discord.SelectOption(label=f"{n} × {q}"[:100], value=n[:100]) for n, q in sorted(c.inventory.items())]
            self.add_item(_Pick("Items to remove (all of each)...", opts, self._on_remove_items, 3, max_values=len(opts)))
        elif self.action == "wear_armor":
            opts: list[discord.SelectOption] = []
            if c.armor_name:
                opts.append(discord.SelectOption(label=f"Take off: {_armor_label(c.armor_name)}"[:100], value="off"))
            if c.owned_armor and not c.armor_name:
                opts.append(discord.SelectOption(label=f"Put on: {_armor_label(c.owned_armor)}"[:100], value="on"))
            if not opts:
                self.status = "You don't own any armor. Staff can assign armor with `/stat armor`."
                self.action = ""
            else:
                self.add_item(_Pick("Armor...", opts, self._on_wear_armor, 3))
        elif self.action == "armor":
            opts = [discord.SelectOption(label="none", value="none", default=not c.armor_name)] + [
                discord.SelectOption(label=k.replace("_", " "), value=k, description=f"Armor TN +{a['tn_bonus']}, Reduction {a['reduction']}",
                                     default=k == c.armor_name) for k, a in combat.ARMOR_CATALOG.items()]
            self.add_item(_Pick("Assign armor...", opts, self._on_armor, 3))
        elif self.action == "qualities":
            quals = sorted(combat.WEAPON_QUALITIES)
            opts = [discord.SelectOption(label=q.title(), value=q, default=q in c.weapon_qualities) for q in quals]
            self.add_item(_Pick("Qualities (pick all that apply, none to clear)...", opts, self._on_qualities, 3, max_values=len(opts)))
        done = discord.ui.Button(label="Done", style=discord.ButtonStyle.secondary, row=4)
        done.callback = self._on_done
        self.add_item(done)

    # -- handlers ------------------------------------------------------------
    async def _on_main(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        new_weapon = values[0].lower() if values else ""
        if not new_weapon:
            c.equipped_weapon = ""
            c.off_hand_weapon = ""
            await self.commit(interaction, f"**{c.name}** lowers their weapons (unarmed).", "wield")
            return
        if _is_arrow(new_weapon):
            has_bow = _is_bow(c.off_hand_weapon) if c.off_hand_weapon else False
            if not has_bow:
                self.status = "Arrows must be used with a bow. Equip a bow first (main or off hand)."
                await self.render(interaction)
                return
        c.equipped_weapon = new_weapon
        if c.off_hand_weapon == c.equipped_weapon:
            c.off_hand_weapon = ""
        await self.commit(interaction, f"**{c.name}** wields **{c.equipped_weapon.replace('_', ' ')}**.", "wield")

    async def _on_off(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        off = values[0].lower() if values else ""
        if off and not c.equipped_weapon:
            self.status = "Wield a main-hand weapon first."
            await self.render(interaction)
            return
        if _is_arrow(off):
            self.status = "Arrows go in the main hand with a bow in the off hand, not the other way around."
            await self.render(interaction)
            return
        c.off_hand_weapon = "" if off == c.equipped_weapon else off
        if _is_arrow(c.equipped_weapon or "") and not _is_bow(c.off_hand_weapon or ""):
            c.equipped_weapon = ""
        msg = f"Off hand: **{c.off_hand_weapon.replace('_', ' ') or 'nothing'}**." if off != c.equipped_weapon else "That weapon is already in the main hand."
        await self.commit(interaction, msg, "wield")

    async def _on_action(self, interaction: discord.Interaction, values: list[str]) -> None:
        action = values[0] if values else ""
        staff_only = {v for v, _, s in self.ACTIONS if s}
        if (action in staff_only or action.startswith("add:")) and not self.staff:
            self.status = f"Adding items, koku, assigning armor, and qualities are managed by **{_d.role_fortune}**."
            await self.render(interaction)
            return
        if action == "add_item":
            await interaction.response.send_modal(_ItemModal(self))
            return
        if action == "koku":
            await interaction.response.send_modal(_KokuModal(self))
            return
        self.action = action
        c = self.rec.character
        if action == "drop" and not c.weapons:
            self.status = "No weapons owned to drop."
            self.action = ""
        elif action == "remove_item" and not c.inventory:
            self.status = "No items to remove."
            self.action = ""
        else:
            self.status = ""
        await self.render(interaction)

    async def _on_add_weapon(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        w = values[0].lower()
        if w in [x.lower() for x in c.weapons]:
            self.status = f"**{c.name}** already owns a {w}."
            await self.render(interaction)
            return
        c.weapons.append(w)
        spec = combat.WEAPON_CATALOG[w]
        await self.commit(interaction, f"Added **{w}** (DR {spec['rolled']}k{spec['kept']}, {spec['skill']}).", "equip")

    async def _on_drop(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        w = values[0]
        c.weapons = [x for x in c.weapons if x.lower() != w.lower()]
        if (c.equipped_weapon or "").lower() == w.lower():
            c.equipped_weapon = ""
        if (c.off_hand_weapon or "").lower() == w.lower():
            c.off_hand_weapon = ""
        await self.commit(interaction, f"Dropped **{w}**.", "equip")

    async def _on_remove_items(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        if not values:
            self.action = ""
            await self.render(interaction)
            return
        removed = []
        for n in values:
            key = next((k for k in c.inventory if k == n or k[:100] == n), None)
            if key is not None:
                del c.inventory[key]
                removed.append(key)
        await self.commit(interaction, "Removed: " + ", ".join(f"**{r}**" for r in removed) + ".", "item")

    async def _on_wear_armor(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        choice = values[0] if values else ""
        if choice == "off" and c.armor_name:
            c.owned_armor = c.armor_name
            c.armor_name, c.armor_tn_bonus, c.armor_reduction = "", 0, 0
            await self.commit(interaction, f"**{c.name}** takes off **{c.owned_armor.replace('_', ' ')}**.", "armor")
        elif choice == "on" and c.owned_armor:
            spec = combat.get_armor(c.owned_armor)
            if spec is None:
                self.status = f"Armor '{c.owned_armor}' is no longer in the catalog."
                await self.render(interaction)
                return
            c.armor_name = c.owned_armor
            c.armor_tn_bonus, c.armor_reduction = spec["tn_bonus"], spec["reduction"]
            note = f"\n{spec['special']}" if spec.get("special") else ""
            await self.commit(interaction, f"**{c.name}** puts on **{c.armor_name.replace('_', ' ')}**: Armor TN +{spec['tn_bonus']}, Reduction {spec['reduction']}.{note}", "armor")
        else:
            self.action = ""
            await self.render(interaction)

    async def _on_armor(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        a = values[0]
        if a == "none":
            c.armor_name, c.armor_tn_bonus, c.armor_reduction = "", 0, 0
            c.owned_armor = ""
            await self.commit(interaction, f"Removed armor from **{c.name}**.", "armor")
            return
        spec = combat.get_armor(a)
        if spec is None:
            self.status = f"Unknown armor {a}."
            await self.render(interaction)
            return
        c.owned_armor = a
        c.armor_name, c.armor_tn_bonus, c.armor_reduction = a, spec["tn_bonus"], spec["reduction"]
        note = f"\n{spec['special']}" if spec.get("special") else ""
        await self.commit(interaction, f"**{c.name}** wears **{a.replace('_', ' ')}**: Armor TN +{spec['tn_bonus']}, Reduction {spec['reduction']}.{note}", "armor")

    async def _on_qualities(self, interaction: discord.Interaction, values: list[str]) -> None:
        c = self.rec.character
        c.weapon_qualities = sorted(set(values))
        await self.commit(interaction, f"Weapon qualities: **{', '.join(c.weapon_qualities) or 'none'}**.", "quality")

    async def _on_done(self, interaction: discord.Interaction) -> None:
        self.stop()
        await interaction.response.edit_message(content=f"Inventory of **{self.rec.character.name}** closed.",
                                                embed=build_inventory_embed(self.rec), view=None)


@app_commands.command(name="inventory", description="Your gear and purse in one panel: Wield, weapons, items, koku (staff: Any character or NPC).")
@app_commands.describe(member="Another player's character [Fortune].", npc="An NPC's inventory [Fortune].")
async def inventory(interaction: discord.Interaction, member: discord.Member | None = None, npc: str | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    staff = _d.is_dm(interaction)
    if npc:
        if not staff:
            await interaction.response.send_message(
                f"You need the **{_d.role_fortune}** (or **{_d.role_kami}**) role to open an NPC's inventory.", ephemeral=True)
            return
        rec = _d.store.get_by_name(str(interaction.guild_id), _d.npc_owner, npc)
        if rec is None:
            await interaction.response.send_message(f"No NPC named **{npc}**.", ephemeral=True)
            return
    else:
        rec, err = await _d.resolve_active_for_edit(interaction, member)
        if err:
            await interaction.response.send_message(err, ephemeral=True)
            return
    try:
        panel = InventoryPanel(rec, interaction.user.id, staff)
        embed = build_inventory_embed(rec)
    except Exception as exc:
        log.error("inventory panel build failed for %s: %s", rec.character.name, exc, exc_info=True)
        await interaction.response.send_message(
            f"Failed to build inventory for **{rec.character.name}**: {exc}",
            ephemeral=True,
        )
        return
    await interaction.response.send_message(content=panel.content(), embed=embed, view=panel, ephemeral=True)


def init(*, tree: app_commands.CommandTree, store, npc_owner: str, require_guild, is_dm, resolve_active_for_edit,
         audit_stat, modify_inventory, npc_autocomplete, role_fortune: str, role_kami: str) -> None:
    global _d
    _d = _Deps(store=store, npc_owner=npc_owner, require_guild=require_guild, is_dm=is_dm,
               resolve_active_for_edit=resolve_active_for_edit, audit_stat=audit_stat,
               modify_inventory=modify_inventory, npc_autocomplete=npc_autocomplete,
               role_fortune=role_fortune, role_kami=role_kami)
    inventory.autocomplete("npc")(npc_autocomplete)
    tree.add_command(inventory)
