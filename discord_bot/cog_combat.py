"""Combat slash commands (/combat group and /attack).

Extracted from bot.py - all combat group commands, attack command, DamageView,
and combat-only constants/helpers.  Shared helpers (guards, autocompletes,
format_dice, combat_log, encounter save/load) are injected via init().
"""

from __future__ import annotations

import re
import time as _time

import discord
from discord import app_commands

import encounter
import storage as _storage_mod
import views_base
from l5r_rules import (
    advantage_effects, advantages, combat, condition_effects, creature,
    declarable_techniques, enums,
    kata, kata_effects, kiho, kiho_effects, mass_battle, skill_mastery,
    spells, stats, tattoo_effects, technique_effects,
)
from l5r_rules.character import Character


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store: _storage_mod.Store
    engine: object  # DiceEngine
    encounters: dict
    NPC_OWNER: str
    ROLE_FORTUNE: str
    ROLE_KAMI: str
    bot_client: discord.Client
    is_dm: object
    refuse_if_dead: object
    refuse_if_cannot_act: object
    on_death: object
    dm_ping: object
    tally: object
    require_guild: object
    require_dm_role: object
    require_encounter: object
    resolve_combatant_record: object
    resolve_duelist: object
    format_dice: object
    combat_log: object
    save_encounter: object
    delete_encounter: object
    npc_autocomplete: object
    weapon_autocomplete: object
    creature_instance_autocomplete: object
    category_autocomplete: object


_d = _Deps()
_PING_MENTIONS = discord.AllowedMentions(roles=True, users=True, everyone=False)


def init(
    *,
    store: _storage_mod.Store,
    engine: object,
    encounters: dict,
    npc_owner: str,
    role_fortune: str,
    role_kami: str,
    bot_client: discord.Client,
    is_dm,
    refuse_if_dead,
    refuse_if_cannot_act,
    on_death,
    dm_ping,
    tally,
    require_guild,
    require_dm_role,
    require_encounter,
    resolve_combatant_record,
    resolve_duelist,
    format_dice,
    combat_log,
    save_encounter,
    delete_encounter,
    npc_autocomplete,
    weapon_autocomplete,
    creature_instance_autocomplete,
    category_autocomplete,
) -> None:
    _d.store = store
    _d.engine = engine
    _d.encounters = encounters
    _d.NPC_OWNER = npc_owner
    _d.ROLE_FORTUNE = role_fortune
    _d.ROLE_KAMI = role_kami
    _d.bot_client = bot_client
    _d.is_dm = is_dm
    _d.refuse_if_dead = refuse_if_dead
    _d.refuse_if_cannot_act = refuse_if_cannot_act
    _d.on_death = on_death
    _d.dm_ping = dm_ping
    _d.tally = tally
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.require_encounter = require_encounter
    _d.resolve_combatant_record = resolve_combatant_record
    _d.resolve_duelist = resolve_duelist
    _d.format_dice = format_dice
    _d.combat_log = combat_log
    _d.save_encounter = save_encounter
    _d.delete_encounter = delete_encounter
    _d.npc_autocomplete = npc_autocomplete
    _d.weapon_autocomplete = weapon_autocomplete
    _d.creature_instance_autocomplete = creature_instance_autocomplete
    _d.category_autocomplete = category_autocomplete

    # Wire autocompletes programmatically (injected functions can't be used in decorators)
    attack.autocomplete("attacker_npc")(npc_autocomplete)
    attack.autocomplete("weapon")(weapon_autocomplete)
    attack.autocomplete("target_npc")(npc_autocomplete)
    attack.autocomplete("target_creature")(creature_instance_autocomplete)
    combat_creature.autocomplete("name")(creature_instance_autocomplete)
    combat_category.autocomplete("category")(category_autocomplete)
    combat_npc.autocomplete("name")(npc_autocomplete)


# ---------------------------------------------------------------------------
# Combat-only autocomplete
# ---------------------------------------------------------------------------

async def _combatant_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    enc = _d.encounters.get(interaction.channel_id)
    if enc is None or not enc.combatants:
        return []
    cur = current.lower().strip()
    names = [c.name for c in enc.combatants if cur in c.name.lower()]
    return [app_commands.Choice(name=n, value=n) for n in names[:25]]


def _is_own_combatant(interaction: discord.Interaction, cb) -> bool:
    """True if the combatant belongs to the invoking user (their active character)."""
    if cb.owner_id and cb.owner_id == str(interaction.user.id) and not cb.is_npc:
        return True
    return False


# ===========================================================================
# /attack: combat with DM-authorized damage
# ===========================================================================
_ATTACKER_STANCES = [
    app_commands.Choice(name="Attack", value="attack"),
    app_commands.Choice(name="Full Attack (+2k1 to hit, -10 own Armor TN)", value="full_attack"),
    app_commands.Choice(name="Center", value="center"),
]
_DEFENDER_STANCES = [
    app_commands.Choice(name="Attack", value="attack"),
    app_commands.Choice(name="Full Attack (-10 Armor TN)", value="full_attack"),
    app_commands.Choice(name="Defense (+Air + Defense skill to Armor TN)", value="defense"),
]
_MANEUVER_APPLY_LABEL = {
    "none": "Roll & Apply Damage",
    "feint": "Roll & Apply Damage (Feint)",
    "increased_damage": "Roll & Apply Damage",
    "disarm": "Resolve Disarm (2k1 + Strength)",
    "knockdown": "Roll Damage + Knockdown",
    "called_shot": "Roll & Apply Damage (Called Shot)",
    "extra_attack": "Roll & Apply Damage (1st Attack)",
}


class DamageView(views_base.PersistentView):
    """DM-only buttons attached to a landed attack: resolve the hit, or waive it.

    Handles the plain hit and the Feint / Disarm / Knockdown maneuvers."""

    KIND = "attack_damage"

    def __init__(
        self,
        attacker_id: int,
        target_id: int | None,
        weapon: str,
        increased_damage: int,
        attacker_name: str,
        target_name: str,
        maneuver: str = "none",
        attack_margin: int = 0,
        target_creature_id: int | None = None,
        defender_stance: str = "attack",
        called_shot_raises: int = 0,
        channel_id: int = 0,
        source_channel_id: int = 0,
        weapon_material: str = "normal",
        void_damage: bool = False,
        attacker_stance: str = "",
        atk_init: int | None = None,
        def_init: int | None = None,
        duel_strike_reduction: int = 0,
    ) -> None:
        super().__init__()
        self.attacker_id = attacker_id
        self.target_id = target_id
        self.target_creature_id = target_creature_id
        self.weapon = weapon
        self.increased_damage = increased_damage
        self.attacker_name = attacker_name
        self.target_name = target_name
        self.maneuver = maneuver
        self.attack_margin = attack_margin
        self.defender_stance = defender_stance
        self.called_shot_raises = called_shot_raises
        self.channel_id = channel_id
        self.source_channel_id = source_channel_id
        self.weapon_material = weapon_material
        self.void_damage = void_damage
        self.attacker_stance = attacker_stance
        self.atk_init = atk_init
        self.def_init = def_init
        self.duel_strike_reduction = duel_strike_reduction
        # Relabel the primary button to match the maneuver, and hide the Void
        # button when it would be nonsensical (knockdown has no damage roll;
        # creature targets have no VP pool).
        hide_void = target_creature_id is not None
        to_remove = []
        for child in self.children:
            if isinstance(child, discord.ui.Button) and child.style == discord.ButtonStyle.danger:
                child.label = _MANEUVER_APPLY_LABEL.get(maneuver, "Roll & Apply Damage")
            if isinstance(child, discord.ui.Button) and child.style == discord.ButtonStyle.primary and hide_void:
                to_remove.append(child)
        for child in to_remove:
            self.remove_item(child)

    async def _post_result(self, interaction: discord.Interaction, embed: discord.Embed, text: str = "") -> None:
        """Post result to source channel when using approval routing, or inline."""
        if self.source_channel_id:
            src = _d.bot_client.get_channel(self.source_channel_id)
            if src:
                await src.send(content=text or None, embed=embed)
            await interaction.followup.send(f"Resolved in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(content=text or None, embed=embed)

    def _wound_status(self, target_rec: _storage_mod.CharacterRecord, applied: dict) -> str:
        c = target_rec.character
        if applied["level_changed"]:
            status = (
                f"{self.target_name}: {applied['old_wound_level']} → "
                f"**{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
            )
        else:
            status = f"{self.target_name}: **{applied['new_wound_level']}** ({c.wounds_taken} wounds)"
        if applied["is_dead"]:
            status += "  💀 **DEAD**"
        return status

    def _rate_limited_damage(self, interaction: discord.Interaction, attacker: Character):
        """Enforce once-per-Turn/Round damage-side kata against the live tracker.
        Returns (scorpion_bonus, scorpion_note, tsunami_ignore, tsunami_note); an
        effect fires only while an encounter is tracking the attacker."""
        enc = _d.encounters.get(self.channel_id)
        combatant = enc.find(attacker.name) if enc else None
        scorp_bonus, scorp_note = 0, ""
        val, note = kata_effects.scorpion_feint_damage(attacker, self.maneuver)
        if val and _rate_status(combatant, "scorpion", "turn") == "apply":
            scorp_bonus, scorp_note = val, note
        tsu_ignore, tsu_note = 0, ""
        val, note = kata_effects.tsunami_ignore_reduction(attacker)
        if val and _rate_status(combatant, "tsunami", "round") == "apply":
            tsu_ignore, tsu_note = val, note
        return scorp_bonus, scorp_note, tsu_ignore, tsu_note

    @discord.ui.button(label="Roll & Apply Damage", style=discord.ButtonStyle.danger, emoji="⚔️")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _d.require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        await self._resolve_damage(interaction, void_reduce=False)

    @discord.ui.button(label="Void Reduce (−10 wounds)", style=discord.ButtonStyle.primary, emoji="🔮")
    async def void_reduce_apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _d.require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        await self._resolve_damage(interaction, void_reduce=True)

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _d.require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        msg = (
            f"🛡️ {interaction.user.display_name} denied the effect: "
            f"no damage applied to **{self.target_name}**."
        )
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = _d.bot_client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"Denied - posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

    async def _resolve_damage(self, interaction: discord.Interaction, void_reduce: bool = False) -> None:
        """Shared damage resolution for both normal and Void-reduced paths."""

        # Creature target: apply the attacker's weapon damage to the creature's
        # own wound track (plain hit or Feint only; disarm/knockdown are blocked
        # against creatures at /attack).
        if self.target_creature_id is not None:
            attacker_rec = _d.store.get_by_id(self.attacker_id)
            cre_rec = _d.store.get_creature_by_id(self.target_creature_id)
            if cre_rec is None or attacker_rec is None:
                self._disable()
                await interaction.response.edit_message(view=self)
                who = "creature" if cre_rec is None else "attacker"
                await interaction.followup.send(f"The {who} no longer exists.", ephemeral=True)
                return
            attacker = attacker_rec.character
            wp = combat.get_weapon_profile(self.weapon)
            extra_rolled, waves_note = kata_effects.attacker_damage_rolled_bonus(attacker, wp)
            bg_roll, _, bg_note = combat.blowgun_damage_bonus(attacker, self.weapon)
            extra_rolled += bg_roll
            tp_roll, tp_kept, tp_note = combat.teppoudo_damage_bonus(attacker, self.weapon)
            extra_rolled += tp_roll
            t_roll, t_kept, t_flat, t_dmg_notes = technique_effects.attacker_damage(
                attacker, wp, self.weapon, self.attacker_stance, self.atk_init, self.def_init,
            )
            extra_rolled += t_roll
            t_kept += tp_kept
            if bg_note:
                t_dmg_notes = [bg_note] + t_dmg_notes
            if tp_note:
                t_dmg_notes = [tp_note] + t_dmg_notes
            m_roll, m_kept, m_flat, m_dmg_notes = skill_mastery.attacker_damage(attacker, wp, self.weapon)
            extra_rolled += m_roll
            t_kept += m_kept
            t_flat += m_flat
            t_dmg_notes = t_dmg_notes + m_dmg_notes
            a_roll, a_kept, a_flat, a_dmg_notes = advantage_effects.attacker_damage(attacker, wp, self.weapon)
            extra_rolled += a_roll
            t_kept += a_kept
            t_flat += a_flat
            t_dmg_notes = t_dmg_notes + a_dmg_notes
            k_roll, k_kept, k_flat, k_dmg_notes = kiho_effects.attacker_damage(attacker, self.weapon)
            extra_rolled += k_roll
            t_kept += k_kept
            t_flat += k_flat
            t_dmg_notes = t_dmg_notes + k_dmg_notes
            tt_roll, tt_kept, tt_flat, tt_dmg_notes = tattoo_effects.attacker_damage(attacker, self.weapon)
            extra_rolled += tt_roll
            t_kept += tt_kept
            t_flat += tt_flat
            t_dmg_notes = t_dmg_notes + tt_dmg_notes
            bish_roll, bish_notes = advantage_effects.increased_damage_bonus(attacker, self.increased_damage)
            extra_rolled += bish_roll
            t_dmg_notes = t_dmg_notes + bish_notes
            if self.void_damage and attacker.current_void_points > 0:
                attacker.current_void_points -= 1
                _d.tally(self.channel_id, attacker.name, "void")
                extra_rolled += 1
                t_kept += 1
                t_dmg_notes.append(f"Katana: Void +1k1 damage ({attacker.current_void_points} VP left)")
                _d.store.save(attacker_rec, note="Void Point spent (katana damage)")
            elif self.void_damage:
                t_dmg_notes.append("Katana: No Void Points for +1k1 damage")
            ignore, sos_note = kata_effects.attacker_reduction_ignored(attacker, wp)
            t_ignore, t_ign_notes = technique_effects.attacker_reduction_ignored(attacker, wp, self.weapon)
            ignore += t_ignore
            enc = _d.encounters.get(self.channel_id)
            enc_round = enc.round if enc else None
            m_ignore, m_ign_notes = skill_mastery.attacker_reduction_ignored(attacker, wp, enc_round)
            ignore += m_ignore
            t_dmg_notes = t_dmg_notes + t_ign_notes + m_ign_notes
            explode_9, e9_note = skill_mastery.attacker_explode_9(attacker, wp)
            force_explode, fe_note = skill_mastery.attacker_ninjutsu_can_explode(attacker, wp)
            if e9_note:
                t_dmg_notes.append(e9_note)
            if fe_note:
                t_dmg_notes.append(fe_note)
            cre_decl_dmg_explode = False
            cre_decl_reduction_ignore = 0
            cre_decl_on_hit_condition = ""
            atk_cb_cre = enc.find(attacker.name) if enc else None
            if atk_cb_cre and atk_cb_cre.declared_techniques:
                for tkey, tentry in list(atk_cb_cre.declared_techniques.items()):
                    if tentry.get("manual"):
                        continue
                    efx = tentry.get("effects", {})
                    if not efx:
                        continue
                    t_display = tentry.get("display", tkey)
                    if efx.get("dmg_rolled"):
                        extra_rolled += efx["dmg_rolled"]
                    if efx.get("dmg_kept"):
                        t_kept += efx["dmg_kept"]
                    if efx.get("dmg_flat"):
                        t_flat += efx["dmg_flat"]
                    if efx.get("dmg_explode"):
                        cre_decl_dmg_explode = True
                    if efx.get("reduction_ignore"):
                        cre_decl_reduction_ignore += efx["reduction_ignore"]
                    if efx.get("on_hit_condition"):
                        cre_decl_on_hit_condition = efx["on_hit_condition"]
                    d_parts: list[str] = []
                    for k in ("dmg_rolled", "dmg_kept", "dmg_flat", "dmg_explode",
                               "reduction_ignore", "on_hit_condition"):
                        if efx.get(k):
                            d_parts.append(f"{k}={efx[k]}")
                    if d_parts:
                        t_dmg_notes.append(f"{t_display}: {', '.join(d_parts)}")
            if cre_decl_dmg_explode:
                force_explode = True
            dmg = combat.resolve_damage(
                attacker, self.weapon, _d.engine, self.increased_damage,
                extra_rolled, t_kept, t_flat, explode_9=explode_9, force_explode=force_explode,
            )
            raw = dmg["raw_damage"]
            feint_line = ""
            if self.maneuver == "feint":
                uncapped, uncap_note = technique_effects.feint_uncapped(attacker)
                if uncapped:
                    fb = self.attack_margin // 2
                    feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, uncapped)"
                else:
                    fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker))
                    feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, cap 5×Insight Rank)"
                raw += fb
                if uncap_note:
                    feint_line += f"\n⚑ {uncap_note}"
            scorp_bonus, scorp_note, tsu_ignore, tsu_note = self._rate_limited_damage(interaction, attacker)
            raw += scorp_bonus
            cre_base_red = cre_rec.creature.reduction
            bokken_note = ""
            bohiya_note = ""
            firearm_red_note = ""
            if wp.get("ignore_all_reduction"):
                bohiya_note = f"Bo-Hiya: Ignores all Reduction ({cre_base_red} → 0)"
                cre_base_red = 0
            elif wp.get("ignore_creature_reduction"):
                firearm_red_note = f"Firearm: Ignores natural toughness ({cre_base_red} → 0)"
                cre_base_red = 0
            elif wp.get("double_reduction"):
                bokken_note = f"Bokken: Reduction doubled ({cre_base_red} → {cre_base_red * 2})"
                cre_base_red *= 2
            true_note = ""
            if combat.has_weapon_quality(attacker, self.weapon, "true") and cre_base_red > 0:
                true_sub = min(cre_base_red, attacker.strength)
                if true_sub > 0:
                    true_note = f"True: Reduction −{true_sub} (wielder Strength {attacker.strength})"
                    cre_base_red = max(0, cre_base_red - attacker.strength)
            kata_line = "".join(f"\n⚑ {n}" for n in (waves_note, sos_note, scorp_note, tsu_note, bokken_note, bohiya_note, firearm_red_note, true_note, *t_dmg_notes) if n)
            reduction = max(0, cre_base_red - ignore - tsu_ignore - cre_decl_reduction_ignore)
            radiant = combat.has_weapon_quality(attacker, self.weapon, "radiant")
            bypasses = radiant or self.weapon_material in ("jade", "crystal", "obsidian", "nemuranai")
            applied = creature.apply_damage_to_creature(cre_rec.creature, raw, reduction, bypasses_invuln=bypasses)
            heal_line = ""
            if applied["is_dead"]:
                heal_amt, heal_notes = advantage_effects.post_kill_heal(attacker)
                if heal_amt:
                    attacker.wounds_taken = max(0, attacker.wounds_taken - heal_amt)
                    _d.store.save(attacker_rec, note="post-kill heal")
                    heal_line = f"\n⚑ {heal_notes[0]} ({attacker.wounds_taken} wounds remaining)"
            _d.store.save_creature(cre_rec, note="attack damage")
            _d.tally(self.channel_id, self.attacker_name, "dealt", applied["final_damage"])
            _d.tally(self.channel_id, self.target_name, "taken", applied["final_damage"])
            if applied["is_dead"]:
                _d.tally(self.channel_id, self.attacker_name, "kills")
                await _d.on_death(str(interaction.guild_id), cre_rec.creature.name, None, None)
            cr = cre_rec.creature
            cre_cs_line = ""
            if self.maneuver == "called_shot" and self.called_shot_raises > 0:
                part = combat.CALLED_SHOT_PARTS.get(
                    min(self.called_shot_raises, 4), "specific part"
                )
                cre_cs_line = f"\n🎯 Called Shot: **{part}** ({self.called_shot_raises} raise{'s' if self.called_shot_raises != 1 else ''})"
            mat_line = ""
            if self.weapon_material != "normal":
                mat_line = f"\n🔶 Weapon material: **{self.weapon_material.title()}**"
            if radiant:
                mat_line += "\n🔶 Radiant: Counts as Jade (bypasses Invulnerability)"
            special_line = "".join(f"\n🛡️ {n}" for n in applied.get("special_notes", []))
            break_line = ""
            brk = wp.get("break_threshold")
            if brk and raw >= brk:
                if combat.has_weapon_quality(attacker, self.weapon, "unbreakable"):
                    break_line = f"\n🛡️ Unbreakable: Weapon survives {raw} damage (threshold {brk})"
                else:
                    break_line = f"\n💥 **WEAPON BROKEN** - {self.weapon.replace('_', ' ').title()} inflicted {raw} damage (threshold {brk}+)"
            embed = discord.Embed(
                title="⚔️ Damage applied",
                color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
            )
            dmg_text = (
                f"{self.attacker_name} → **{self.target_name}** with {self.weapon.replace('_', ' ').title()}\n"
                f"{_d.format_dice(dmg['dice'])}{feint_line}{kata_line}{cre_cs_line}{mat_line}\n"
                f"Raw **{raw}** − reduction {applied['reduction']} = "
                f"**{applied['final_damage']}** wounds{special_line}{break_line}"
            )
            if len(dmg_text) > 1024:
                dmg_text = dmg_text[:1021] + "..."
            embed.add_field(name="Damage", value=dmg_text, inline=False)
            if applied["level_changed"]:
                status = (
                    f"{self.target_name}: {applied['old_wound_level']} → "
                    f"**{applied['new_wound_level']}** ({cr.wounds_taken}/{cr.wounds_dead})"
                )
            else:
                status = f"{self.target_name}: **{applied['new_wound_level']}** ({cr.wounds_taken}/{cr.wounds_dead})"
            if applied["is_dead"]:
                status += "  💀 **SLAIN**"
            status += heal_line
            embed.add_field(name="Result", value=status, inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await self._post_result(interaction, embed)
            dead_tag = " SLAIN" if applied["is_dead"] else ""
            await _d.combat_log(
                str(interaction.guild_id),
                f"Damage: {self.attacker_name} → {self.target_name} ({self.weapon}) "
                f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
            )
            if self.maneuver == "extra_attack" and not applied["is_dead"]:
                await self._second_attack_creature(interaction, attacker_rec, cre_rec)
            return

        attacker_rec = _d.store.get_by_id(self.attacker_id)
        target_rec = _d.store.get_by_id(self.target_id)
        if target_rec is None or attacker_rec is None:
            self._disable()
            await interaction.response.edit_message(view=self)
            who = "target" if target_rec is None else "attacker"
            await interaction.followup.send(f"The {who} no longer exists.", ephemeral=True)
            return
        attacker = attacker_rec.character
        target = target_rec.character

        if self.maneuver == "disarm":
            enc_dis = _d.encounters.get(self.channel_id)
            atk_cb = enc_dis.find(attacker.name) if enc_dis else None
            def_cb = enc_dis.find(target.name) if enc_dis else None
            a_conds = atk_cb.conditions if atk_cb else set()
            d_conds = def_cb.conditions if def_cb else set()
            ar, af, _ = condition_effects.contested_roll_modifier(a_conds)
            dr, df, _ = condition_effects.contested_roll_modifier(d_conds)
            dis = combat.resolve_disarm(attacker, target, _d.engine, ar, af, dr, df)
            applied = combat.apply_damage(target, dis["damage"], target.armor_reduction)
            void_line = ""
            if void_reduce:
                ok, reason_block = advantage_effects.can_spend_void_on_roll(target, is_wound_reduction=True)
                if not ok:
                    void_line = f"\n🔮 {reason_block}"
                elif target.current_void_points > 0:
                    void_saved = min(10, applied["final_damage"])
                    target.wounds_taken = max(0, target.wounds_taken - void_saved)
                    target.current_void_points -= 1
                    _d.tally(self.channel_id, target.name, "void")
                    applied["final_damage"] -= void_saved
                    applied["new_wound_level"] = stats.wound_level_name(target)
                    applied["is_dead"] = stats.is_dead(target)
                    applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
                    void_line = f"\n🔮 Void Point spent: **−{void_saved}** wounds ({target.current_void_points} VP remaining)"
                else:
                    void_line = "\n🔮 No Void Points available: Full damage applied"
            _d.store.save(target_rec, note="attack damage")
            _d.tally(self.channel_id, self.attacker_name, "dealt", applied["final_damage"])
            _d.tally(self.channel_id, self.target_name, "taken", applied["final_damage"])
            if applied["is_dead"]:
                _d.tally(self.channel_id, self.attacker_name, "kills")
                await _d.on_death(str(interaction.guild_id), target.name, target_rec.owner_id, target_rec.id)
            embed = discord.Embed(
                title="🗡️ Disarm",
                color=discord.Color.green() if dis["disarmed"] else discord.Color.orange(),
            )
            dis_armor_label = f" ({target.armor_name.replace('_', ' ').title()})" if target.armor_name else ""
            dis_value = (
                f"{_d.format_dice(dis['damage_dice'])}\nRaw **{dis['damage']}** − reduction "
                f"{applied['reduction']}{dis_armor_label} = **{applied['final_damage']}** wounds{void_line}"
            )
            embed.add_field(
                name="Damage (2k1)",
                value=dis_value[:1024],
                inline=False,
            )
            embed.add_field(
                name="Contested Strength",
                value=f"{self.attacker_name} **{dis['attacker_roll']}** vs "
                f"{self.target_name} **{dis['defender_roll']}**",
                inline=False,
            )
            verdict = (
                f"**{self.target_name} is disarmed!**" if dis["disarmed"]
                else f"{self.target_name} holds their weapon."
            )
            embed.add_field(name="Result", value=f"{verdict}\n{self._wound_status(target_rec, applied)}", inline=False)
            embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
            self._disable()
            await interaction.response.edit_message(view=self)
            await self._post_result(interaction, embed)
            disarm_tag = "disarmed" if dis["disarmed"] else "held"
            await _d.combat_log(
                str(interaction.guild_id),
                f"Disarm: {self.attacker_name} → {self.target_name} ({disarm_tag}, "
                f"{applied['final_damage']} wounds [{applied['new_wound_level']}])",
            )
            return

        # Plain hit or Feint: weapon damage (+ feint bonus, + active-kata, Technique & Mastery mods).
        wp = combat.get_weapon_profile(self.weapon)
        extra_rolled, waves_note = kata_effects.attacker_damage_rolled_bonus(attacker, wp)
        bg_roll, _, bg_note = combat.blowgun_damage_bonus(attacker, self.weapon)
        extra_rolled += bg_roll
        tp_roll, tp_kept, tp_note = combat.teppoudo_damage_bonus(attacker, self.weapon)
        extra_rolled += tp_roll
        t_roll, t_kept, t_flat, t_dmg_notes = technique_effects.attacker_damage(
            attacker, wp, self.weapon, self.attacker_stance, self.atk_init, self.def_init,
            defender=target,
        )
        extra_rolled += t_roll
        t_kept += tp_kept
        if bg_note:
            t_dmg_notes = [bg_note] + t_dmg_notes
        if tp_note:
            t_dmg_notes = [tp_note] + t_dmg_notes
        m_roll, m_kept, m_flat, m_dmg_notes = skill_mastery.attacker_damage(attacker, wp, self.weapon)
        extra_rolled += m_roll
        t_kept += m_kept
        t_flat += m_flat
        t_dmg_notes = t_dmg_notes + m_dmg_notes
        a_roll, a_kept, a_flat, a_dmg_notes = advantage_effects.attacker_damage(attacker, wp, self.weapon)
        extra_rolled += a_roll
        t_kept += a_kept
        t_flat += a_flat
        t_dmg_notes = t_dmg_notes + a_dmg_notes
        k_roll, k_kept, k_flat, k_dmg_notes = kiho_effects.attacker_damage(attacker, self.weapon)
        extra_rolled += k_roll
        t_kept += k_kept
        t_flat += k_flat
        t_dmg_notes = t_dmg_notes + k_dmg_notes
        tt_roll, tt_kept, tt_flat, tt_dmg_notes = tattoo_effects.attacker_damage(attacker, self.weapon)
        extra_rolled += tt_roll
        t_kept += tt_kept
        t_flat += tt_flat
        t_dmg_notes = t_dmg_notes + tt_dmg_notes
        bish_roll, bish_notes = advantage_effects.increased_damage_bonus(attacker, self.increased_damage)
        extra_rolled += bish_roll
        t_dmg_notes = t_dmg_notes + bish_notes
        if self.void_damage and attacker.current_void_points > 0:
            attacker.current_void_points -= 1
            _d.tally(self.channel_id, attacker.name, "void")
            extra_rolled += 1
            t_kept += 1
            t_dmg_notes.append(f"Katana: Void +1k1 damage ({attacker.current_void_points} VP left)")
            _d.store.save(attacker_rec, note="Void Point spent (katana damage)")
        elif self.void_damage:
            t_dmg_notes.append("Katana: No Void Points for +1k1 damage")
        ignore, sos_note = kata_effects.attacker_reduction_ignored(attacker, wp)
        t_ignore, t_ign_notes = technique_effects.attacker_reduction_ignored(attacker, wp, self.weapon, defender=target)
        ignore += t_ignore
        enc = _d.encounters.get(self.channel_id)
        enc_round = enc.round if enc else None
        m_ignore, m_ign_notes = skill_mastery.attacker_reduction_ignored(attacker, wp, enc_round)
        ignore += m_ignore
        t_dmg_notes = t_dmg_notes + t_ign_notes + m_ign_notes
        explode_9, e9_note = skill_mastery.attacker_explode_9(attacker, wp)
        force_explode, fe_note = skill_mastery.attacker_ninjutsu_can_explode(attacker, wp)
        if e9_note:
            t_dmg_notes.append(e9_note)
        if fe_note:
            t_dmg_notes.append(fe_note)
        decl_dmg_explode = False
        decl_reduction_ignore = 0
        decl_target_red_penalty = 0
        decl_on_hit_condition = ""
        atk_cb = enc.find(attacker.name) if enc else None
        if atk_cb and atk_cb.declared_techniques:
            for tkey, tentry in list(atk_cb.declared_techniques.items()):
                if tentry.get("manual"):
                    continue
                efx = tentry.get("effects", {})
                if not efx:
                    continue
                t_display = tentry.get("display", tkey)
                if efx.get("dmg_rolled"):
                    extra_rolled += efx["dmg_rolled"]
                if efx.get("dmg_kept"):
                    t_kept += efx["dmg_kept"]
                if efx.get("dmg_flat"):
                    t_flat += efx["dmg_flat"]
                if efx.get("dmg_explode"):
                    decl_dmg_explode = True
                if efx.get("reduction_ignore"):
                    decl_reduction_ignore += efx["reduction_ignore"]
                if efx.get("target_reduction_penalty"):
                    decl_target_red_penalty += efx["target_reduction_penalty"]
                if efx.get("on_hit_condition"):
                    decl_on_hit_condition = efx["on_hit_condition"]
                d_parts: list[str] = []
                for k in ("dmg_rolled", "dmg_kept", "dmg_flat", "dmg_explode",
                           "reduction_ignore", "target_reduction_penalty", "on_hit_condition"):
                    if efx.get(k):
                        d_parts.append(f"{k}={efx[k]}")
                if d_parts:
                    t_dmg_notes.append(f"{t_display}: {', '.join(d_parts)}")
        if decl_dmg_explode:
            force_explode = True
        dmg = combat.resolve_damage(
            attacker, self.weapon, _d.engine, self.increased_damage,
            extra_rolled, t_kept, t_flat, explode_9=explode_9, force_explode=force_explode,
        )
        raw = dmg["raw_damage"]
        feint_line = ""
        if self.maneuver == "feint":
            uncapped, uncap_note = technique_effects.feint_uncapped(attacker)
            if uncapped:
                fb = self.attack_margin // 2
                feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, uncapped)"
            else:
                fb = combat.compute_feint_bonus(self.attack_margin, stats.insight_rank(attacker))
                feint_line = f"\nFeint bonus **+{fb}** (½ margin {self.attack_margin}, cap 5×Insight Rank)"
            raw += fb
            if uncap_note:
                feint_line += f"\n⚑ {uncap_note}"
        crab_bonus, crab_note = kata_effects.defender_reduction_bonus(target, self.defender_stance)
        tech_red, tech_red_notes = technique_effects.defender_reduction_bonus(target, self.defender_stance)
        kiho_red, kiho_red_notes = kiho_effects.defender_reduction_bonus(target)
        tat_red, tat_red_notes = tattoo_effects.defender_reduction_bonus(target)
        scorp_bonus, scorp_note, tsu_ignore, tsu_note = self._rate_limited_damage(interaction, attacker)
        raw += scorp_bonus
        base_red = target.armor_reduction
        bokken_note = ""
        bohiya_note = ""
        firearm_red_note = ""
        if wp.get("ignore_all_reduction"):
            bohiya_note = f"Bo-Hiya: Ignores all Reduction ({base_red} → 0)"
            base_red = 0
        elif wp.get("ignore_armor_reduction"):
            firearm_red_note = f"Firearm: Ignores armor Reduction ({base_red} → 0)"
            base_red = 0
        elif wp.get("double_reduction"):
            bokken_note = f"Bokken: Reduction doubled ({base_red} → {base_red * 2})"
            base_red *= 2
        true_note = ""
        if combat.has_weapon_quality(attacker, self.weapon, "true") and base_red > 0:
            true_sub = min(base_red, attacker.strength)
            if true_sub > 0:
                true_note = f"True: Reduction −{true_sub} (wielder Strength {attacker.strength})"
                base_red = max(0, base_red - attacker.strength)
        duel_red_note = f"Warrior of Earth +{self.duel_strike_reduction} Reduction (duel Strike)" if self.duel_strike_reduction else ""
        kata_line = "".join(
            f"\n⚑ {n}" for n in (waves_note, sos_note, crab_note, scorp_note, tsu_note, bokken_note, bohiya_note, firearm_red_note, true_note, duel_red_note, *t_dmg_notes, *tech_red_notes, *kiho_red_notes, *tat_red_notes) if n
        )
        reduction = max(0, base_red - ignore - tsu_ignore - decl_reduction_ignore - decl_target_red_penalty + crab_bonus + tech_red + kiho_red + tat_red + self.duel_strike_reduction)
        if wp.get("ignore_all_reduction"):
            reduction = 0
        applied = combat.apply_damage(target, raw, reduction)
        void_line = ""
        if void_reduce:
            ok, reason_block = advantage_effects.can_spend_void_on_roll(target, is_wound_reduction=True)
            if not ok:
                void_line = f"\n🔮 {reason_block}"
            elif target.current_void_points > 0:
                void_saved = min(10, applied["final_damage"])
                target.wounds_taken = max(0, target.wounds_taken - void_saved)
                target.current_void_points -= 1
                _d.tally(self.channel_id, target.name, "void")
                applied["final_damage"] -= void_saved
                applied["new_wound_level"] = stats.wound_level_name(target)
                applied["is_dead"] = stats.is_dead(target)
                applied["level_changed"] = applied["old_wound_level"] != applied["new_wound_level"]
                void_line = f"\n🔮 Void Point spent: **−{void_saved}** wounds ({target.current_void_points} VP remaining)"
            else:
                void_line = "\n🔮 No Void Points available: Full damage applied"
        heal_line = ""
        if applied["is_dead"]:
            heal_amt, heal_notes = advantage_effects.post_kill_heal(attacker)
            if heal_amt:
                attacker.wounds_taken = max(0, attacker.wounds_taken - heal_amt)
                _d.store.save(attacker_rec, note="post-kill heal")
                heal_line = f"\n⚑ {heal_notes[0]} ({attacker.wounds_taken} wounds remaining)"
        phoenix_line = ""
        if applied["new_wound_level"] in ("Down", "Out", "Dead"):
            phx = tattoo_effects.phoenix_heal_reminder(target)
            if phx:
                phoenix_line = f"\n🔥 {phx}"
        _d.store.save(target_rec, note="attack damage")
        _d.tally(self.channel_id, self.attacker_name, "dealt", applied["final_damage"])
        _d.tally(self.channel_id, self.target_name, "taken", applied["final_damage"])
        if applied["is_dead"]:
            _d.tally(self.channel_id, self.attacker_name, "kills")
            await _d.on_death(str(interaction.guild_id), target.name, target_rec.owner_id, target_rec.id)

        knockdown_line = ""
        kd_result = None
        if self.maneuver == "knockdown":
            enc_kd = _d.encounters.get(self.channel_id)
            atk_cb = enc_kd.find(attacker.name) if enc_kd else None
            def_cb = enc_kd.find(target.name) if enc_kd else None
            a_conds = atk_cb.conditions if atk_cb else set()
            d_conds = def_cb.conditions if def_cb else set()
            ar, af, _ = condition_effects.contested_roll_modifier(a_conds)
            dr, df, _ = condition_effects.contested_roll_modifier(d_conds)
            kd_result = combat.resolve_knockdown(
                attacker, target, _d.engine, atk_rolled_mod=ar, atk_flat_mod=af,
                def_rolled_mod=dr, def_flat_mod=df,
            )
            if kd_result["knocked_down"] and enc_kd:
                def_c = enc_kd.find(target.name)
                if def_c:
                    def_c.conditions.add("prone")
                    _d.save_encounter(str(interaction.guild_id), enc_kd)
            kd_verdict = (
                f"**{self.target_name} is knocked prone!**" if kd_result["knocked_down"]
                else f"{self.target_name} keeps their feet."
            )
            knockdown_line = (
                f"\n🥋 Contested Strength: {self.attacker_name} **{kd_result['attacker_roll']}** vs "
                f"{self.target_name} **{kd_result['defender_roll']}**: {kd_verdict}"
            )

        decl_cond_line = ""
        if decl_on_hit_condition and applied["final_damage"] > 0 and not applied["is_dead"]:
            enc_dc = _d.encounters.get(self.channel_id)
            def_cb = enc_dc.find(target.name) if enc_dc else None
            if def_cb and decl_on_hit_condition in encounter.VALID_CONDITIONS:
                def_cb.set_condition(decl_on_hit_condition, 0, enc_dc.round if enc_dc else 0)
                _d.save_encounter(str(interaction.guild_id), enc_dc)
                decl_cond_line = f"\n⚑ **{decl_on_hit_condition.title()}** inflicted by technique"

        called_shot_line = ""
        if self.maneuver == "called_shot" and self.called_shot_raises > 0:
            part = combat.CALLED_SHOT_PARTS.get(
                min(self.called_shot_raises, 4), "specific part"
            )
            called_shot_line = f"\n🎯 Called Shot: **{part}** ({self.called_shot_raises} raise{'s' if self.called_shot_raises != 1 else ''})"
        break_line = ""
        brk = wp.get("break_threshold")
        if brk and raw >= brk:
            if combat.has_weapon_quality(attacker, self.weapon, "unbreakable"):
                break_line = f"\n🛡️ Unbreakable: Weapon survives {raw} damage (threshold {brk})"
            else:
                break_line = f"\n💥 **WEAPON BROKEN** - {self.weapon.replace('_', ' ').title()} inflicted {raw} damage (threshold {brk}+)"

        embed = discord.Embed(
            title="⚔️ Damage applied",
            color=discord.Color.dark_red() if applied["is_dead"] else discord.Color.red(),
        )
        armor_label = f" ({target.armor_name.replace('_', ' ').title()})" if target.armor_name else ""
        dmg_text = (
            f"{self.attacker_name} → **{self.target_name}** with {self.weapon.replace('_', ' ').title()}\n"
            f"{_d.format_dice(dmg['dice'])}{feint_line}{kata_line}{called_shot_line}\n"
            f"Raw **{raw}** − reduction {applied['reduction']}{armor_label} = "
            f"**{applied['final_damage']}** wounds{void_line}{decl_cond_line}{break_line}"
        )
        if len(dmg_text) > 1024:
            dmg_text = dmg_text[:1021] + "..."
        embed.add_field(name="Damage", value=dmg_text, inline=False)
        embed.add_field(name="Result", value=self._wound_status(target_rec, applied) + heal_line + phoenix_line + knockdown_line, inline=False)
        embed.set_footer(text=f"Authorized by {interaction.user.display_name}")
        self._disable()
        await interaction.response.edit_message(view=self)
        await self._post_result(interaction, embed)
        dead_tag = " DEAD" if applied["is_dead"] else ""
        man_tag = f" ({self.maneuver})" if self.maneuver not in ("none", "called_shot") else ""
        cs_tag = ""
        if self.maneuver == "called_shot" and self.called_shot_raises > 0:
            part = combat.CALLED_SHOT_PARTS.get(min(self.called_shot_raises, 4), "specific part")
            cs_tag = f" (Called Shot: {part})"
        await _d.combat_log(
            str(interaction.guild_id),
            f"Damage: {self.attacker_name} → {self.target_name} ({self.weapon}){man_tag}{cs_tag} "
            f"{applied['final_damage']} wounds [{applied['new_wound_level']}]{dead_tag}",
        )

        if self.maneuver == "knockdown" and kd_result is not None:
            kd_tag = "knocked prone" if kd_result["knocked_down"] else "resisted"
            await _d.combat_log(
                str(interaction.guild_id),
                f"Knockdown: {self.attacker_name} → {self.target_name} ({kd_tag})",
            )

        if self.maneuver == "extra_attack" and not applied["is_dead"]:
            await self._second_attack(interaction, attacker_rec, target_rec)

    async def _second_attack(
        self,
        interaction: discord.Interaction,
        attacker_rec: _storage_mod.CharacterRecord,
        target_rec: _storage_mod.CharacterRecord,
    ) -> None:
        """Roll the free second attack granted by Extra Attack (s40).

        Applies all passive/always-on combat modifiers (techniques, kata,
        tattoos, kiho, advantages, conditions, armor penalty, weapon quality)
        to both attacker and defender. Skips one-shot/rate-limited effects
        (center stance, void spend, striking as fire, strength in arms)."""
        attacker = attacker_rec.character
        target = target_rec.character
        wp = combat.get_weapon_profile(self.weapon)
        is_melee = wp.get("melee", True)
        enc = _d.encounters.get(self.channel_id)
        atk_combatant = enc.find(attacker.name) if enc else None
        def_combatant = enc.find(target.name) if enc else None
        atk_init = self.atk_init
        def_init = self.def_init
        a_stance = self.attacker_stance
        d_stance = self.defender_stance
        notes: list[str] = []

        # --- Defender TN modifiers ---
        def_conds = def_combatant.conditions if def_combatant else set()
        def_bonus = 0
        def_kata_b, def_kata_n = kata_effects.defender_armor_tn_bonus(target, d_stance)
        def_bonus += def_kata_b
        if def_kata_n:
            notes.append(def_kata_n)
        def_tech_b, def_tech_n = technique_effects.defender_armor_tn_bonus(
            target, d_stance, atk_init, def_init, attacker=attacker)
        def_bonus += def_tech_b; notes.extend(def_tech_n)
        def_mast_b, def_mast_n = skill_mastery.defender_armor_tn_bonus(target)
        def_bonus += def_mast_b; notes.extend(def_mast_n)
        def_adv_b, def_adv_n = advantage_effects.defender_armor_tn_mod(target)
        def_bonus += def_adv_b; notes.extend(def_adv_n)
        def_kiho_b, def_kiho_n = kiho_effects.defender_armor_tn_bonus(target)
        def_bonus += def_kiho_b; notes.extend(def_kiho_n)
        def_tat_b, def_tat_n = tattoo_effects.defender_armor_tn_bonus(target)
        def_bonus += def_tat_b; notes.extend(def_tat_n)
        cond_def_mod, cond_def_n = condition_effects.defender_armor_tn_mod(def_conds, is_melee)
        notes.extend(cond_def_n)
        guard_mod2 = 0
        fd_bonus2 = def_combatant.full_defense_bonus if def_combatant else 0
        void_tn_bonus2 = def_combatant.void_armor_tn_bonus if def_combatant else 0
        cover_mod2 = def_combatant.cover_bonus if def_combatant else 0
        if enc:
            for gc in enc.combatants:
                if gc.guarding.lower() == target.name.lower():
                    guard_mod2 += 10
            if def_combatant and def_combatant.guarding:
                guard_mod2 -= 5
        dw_def_bonus2 = 0
        if target.equipped_weapon and target.off_hand_weapon:
            dw_def_bonus2 = stats.insight_rank(target)
        arrow_tn_adj2, _ = combat.arrow_armor_tn_mod(self.weapon, target.armor_tn_bonus)
        tn_extras = cond_def_mod + guard_mod2 + fd_bonus2 + void_tn_bonus2 + cover_mod2 + arrow_tn_adj2 + dw_def_bonus2
        cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
            def_conds, target.reflexes, target.armor_tn_bonus, is_melee)
        if cond_tn_ovr is not None:
            tn = cond_tn_ovr + tn_extras
            notes.extend(cond_tn_notes)
        else:
            tn = combat.armor_tn(target, d_stance, def_bonus + tn_extras)

        # --- Attacker modifiers ---
        bonus_rolled = bonus_kept = atk_flat = 0
        t_r, t_k, t_f, t_n = technique_effects.attacker_attack_dice(
            attacker, wp, self.weapon, a_stance, atk_init, def_init,
            defender=target, maneuver="none", defender_stance=d_stance)
        bonus_rolled += t_r; bonus_kept += t_k; atk_flat += t_f; notes.extend(t_n)
        tat_r, tat_k, tat_f, tat_n = tattoo_effects.attacker_attack_dice(attacker, wp)
        bonus_rolled += tat_r; bonus_kept += tat_k; atk_flat += tat_f; notes.extend(tat_n)
        adv_r, adv_k, adv_f, adv_n = advantage_effects.attacker_attack_dice(attacker, wp)
        bonus_rolled += adv_r; bonus_kept += adv_k; atk_flat += adv_f; notes.extend(adv_n)
        for mod_fn in (advantage_effects.attacker_wound_penalty_mod,
                       kiho_effects.attacker_wound_penalty_mod,
                       tattoo_effects.attacker_wound_penalty_mod,
                       technique_effects.attacker_wound_penalty_mod):
            wp_mod, wp_n = mod_fn(attacker)
            if wp_mod:
                atk_flat += wp_mod; notes.extend(wp_n)
        atk_conds = atk_combatant.conditions if atk_combatant else set()
        cr, ck, cf, cn = condition_effects.attacker_attack_dice(atk_conds, wp)
        bonus_rolled += cr; bonus_kept += ck; atk_flat += cf; notes.extend(cn)
        arm_pen, arm_note = combat.armor_attack_penalty(attacker)
        if arm_pen:
            atk_flat += arm_pen; notes.append(arm_note)
        if combat.has_weapon_quality(attacker, self.weapon, "balanced"):
            bonus_rolled += 1; notes.append("Balanced: +1k0 attack")
        # Technique trait override (e.g. Falcon's Strike: Perception for bow).
        trait_ovr, trait_ovr_name = None, ""
        to_val, to_name, to_note = technique_effects.attacker_trait_override(attacker, wp)
        if to_val is not None:
            trait_ovr, trait_ovr_name = to_val, to_name
            notes.append(to_note)

        outcome = combat.resolve_attack(
            attacker, self.weapon, tn, 0, _d.engine,
            attacker_stance=a_stance,
            bonus_rolled=bonus_rolled, bonus_kept=bonus_kept, extra_flat=atk_flat,
            trait_override=trait_ovr, trait_override_name=trait_ovr_name,
            emphasis=bool(combat.weapon_emphasis(attacker, self.weapon)),
        )
        hit = outcome["hit"]
        embed2 = discord.Embed(
            title="⚔️ Extra Attack: 2nd strike",
            color=discord.Color.green() if hit else discord.Color.light_grey(),
        )
        detail = (f"{self.attacker_name} → **{self.target_name}** with {self.weapon.replace('_', ' ').title()}\n"
                  f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
                  f": {'**HIT**' if hit else 'miss'}")
        if notes:
            detail += "\n" + " · ".join(notes)
        embed2.add_field(name="Attack Roll", value=detail, inline=False)
        if hit:
            view2 = DamageView(
                attacker_rec.id, target_rec.id, self.weapon, 0,
                self.attacker_name, self.target_name,
                maneuver="none", attack_margin=outcome["margin"],
                defender_stance=self.defender_stance,
                channel_id=self.channel_id,
                source_channel_id=self.source_channel_id,
                weapon_material=self.weapon_material,
                attacker_stance=self.attacker_stance,
                atk_init=self.atk_init, def_init=self.def_init,
            )
            await view2.persist(await interaction.followup.send(
                content=f"{_d.dm_ping(interaction.guild)}A DM can authorize the 2nd attack's damage below.",
                allowed_mentions=_PING_MENTIONS,
                embed=embed2, view=view2,
            ))
            await _d.combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) HIT")
            _d.tally(self.channel_id, self.attacker_name, "attacks"); _d.tally(self.channel_id, self.attacker_name, "hits")
        else:
            await interaction.followup.send(embed=embed2)
            await _d.combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) MISS")
            _d.tally(self.channel_id, self.attacker_name, "attacks")

    async def _second_attack_creature(
        self,
        interaction: discord.Interaction,
        attacker_rec: _storage_mod.CharacterRecord,
        cre_rec: _storage_mod.CreatureRecord,
    ) -> None:
        """Roll the free second attack against a creature (Extra Attack, s40)."""
        attacker = attacker_rec.character
        wp = combat.get_weapon_profile(self.weapon)
        enc2 = _d.encounters.get(self.channel_id)
        atk_combatant = enc2.find(attacker.name) if enc2 else None
        dc2 = enc2.find(cre_rec.creature.name) if enc2 else None
        notes: list[str] = []

        tn = cre_rec.creature.armor_tn + (dc2.cover_bonus if dc2 else 0)

        # --- Attacker modifiers ---
        bonus_rolled = bonus_kept = atk_flat = 0
        t_r, t_k, t_f, t_n = technique_effects.attacker_attack_dice(
            attacker, wp, self.weapon, self.attacker_stance,
            self.atk_init, self.def_init, defender=None, maneuver="none")
        bonus_rolled += t_r; bonus_kept += t_k; atk_flat += t_f; notes.extend(t_n)
        tat_r, tat_k, tat_f, tat_n = tattoo_effects.attacker_attack_dice(attacker, wp)
        bonus_rolled += tat_r; bonus_kept += tat_k; atk_flat += tat_f; notes.extend(tat_n)
        adv_r, adv_k, adv_f, adv_n = advantage_effects.attacker_attack_dice(attacker, wp)
        bonus_rolled += adv_r; bonus_kept += adv_k; atk_flat += adv_f; notes.extend(adv_n)
        for mod_fn in (advantage_effects.attacker_wound_penalty_mod,
                       kiho_effects.attacker_wound_penalty_mod,
                       tattoo_effects.attacker_wound_penalty_mod,
                       technique_effects.attacker_wound_penalty_mod):
            wp_mod, wp_n = mod_fn(attacker)
            if wp_mod:
                atk_flat += wp_mod; notes.extend(wp_n)
        atk_conds = atk_combatant.conditions if atk_combatant else set()
        cr, ck, cf, cn = condition_effects.attacker_attack_dice(atk_conds, wp)
        bonus_rolled += cr; bonus_kept += ck; atk_flat += cf; notes.extend(cn)
        arm_pen, arm_note = combat.armor_attack_penalty(attacker)
        if arm_pen:
            atk_flat += arm_pen; notes.append(arm_note)
        if combat.has_weapon_quality(attacker, self.weapon, "balanced"):
            bonus_rolled += 1; notes.append("Balanced: +1k0 attack")
        trait_ovr, trait_ovr_name = None, ""
        to_val, to_name, to_note = technique_effects.attacker_trait_override(attacker, wp)
        if to_val is not None:
            trait_ovr, trait_ovr_name = to_val, to_name
            notes.append(to_note)

        outcome = combat.resolve_attack(
            attacker, self.weapon, tn, 0, _d.engine,
            attacker_stance=self.attacker_stance,
            bonus_rolled=bonus_rolled, bonus_kept=bonus_kept, extra_flat=atk_flat,
            trait_override=trait_ovr, trait_override_name=trait_ovr_name,
            emphasis=bool(combat.weapon_emphasis(attacker, self.weapon)),
        )
        hit = outcome["hit"]
        embed2 = discord.Embed(
            title="⚔️ Extra Attack: 2nd strike",
            color=discord.Color.green() if hit else discord.Color.light_grey(),
        )
        detail = (f"{self.attacker_name} → **{self.target_name}** with {self.weapon.replace('_', ' ').title()}\n"
                  f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
                  f": {'**HIT**' if hit else 'miss'}")
        if notes:
            detail += "\n" + " · ".join(notes)
        embed2.add_field(name="Attack Roll", value=detail, inline=False)
        if hit:
            view2 = DamageView(
                attacker_rec.id, None, self.weapon, 0,
                self.attacker_name, self.target_name,
                maneuver="none", attack_margin=outcome["margin"],
                target_creature_id=cre_rec.id,
                channel_id=self.channel_id,
                source_channel_id=self.source_channel_id,
                weapon_material=self.weapon_material,
                attacker_stance=self.attacker_stance,
                atk_init=self.atk_init, def_init=self.def_init,
            )
            await view2.persist(await interaction.followup.send(
                content=f"{_d.dm_ping(interaction.guild)}A DM can authorize the 2nd attack's damage below.",
                allowed_mentions=_PING_MENTIONS,
                embed=embed2, view=view2,
            ))
            await _d.combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) HIT")
            _d.tally(self.channel_id, self.attacker_name, "attacks"); _d.tally(self.channel_id, self.attacker_name, "hits")
        else:
            await interaction.followup.send(embed=embed2)
            await _d.combat_log(str(interaction.guild_id), f"Extra Attack: {self.attacker_name} → {self.target_name} ({self.weapon}) MISS")
            _d.tally(self.channel_id, self.attacker_name, "attacks")

    @discord.ui.button(label="No Effect", style=discord.ButtonStyle.secondary, emoji="🛡️")
    async def waive(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not await _d.require_dm_role(interaction):
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        msg = (
            f"🛡️ {interaction.user.display_name} ruled **no effect** on "
            f"{self.attacker_name}'s hit against {self.target_name}."
        )
        self._disable()
        await interaction.response.edit_message(view=self)
        if self.source_channel_id:
            src = _d.bot_client.get_channel(self.source_channel_id)
            if src:
                await src.send(msg)
            await interaction.followup.send(f"No effect - posted in <#{self.source_channel_id}>.")
        else:
            await interaction.followup.send(msg)

def _rate_status(combatant, key: str, scope: str) -> str:
    """Gate a once-per-Turn/Round kata against the live encounter tracker.

    Returns 'apply' (available: And marks it spent), 'used' (already spent this
    Turn/Round), or 'untracked' (no encounter is tracking this attacker, so the
    limit can't be enforced and the effect stays a DM-adjudicated reminder)."""
    if combatant is None:
        return "untracked"
    return "apply" if combatant.consume_once(key, scope) else "used"


def _active_ability_reminders(c: Character, role: str, drop_rate_limited: bool = False) -> list[str]:
    """DM reminder lines for a combatant's active kata/kiho that the bot does NOT
    auto-apply (rate-limited, positional, tradeoff, or every kiho). The
    deterministic kata are folded into the roll instead and shown separately.
    `drop_rate_limited` skips the kata line when a rate-limited kata was already
    enforced against the live tracker (the roll shows the enforced note instead)."""
    lines: list[str] = []
    kata_text = kata_effects.active_kata_reminder(c)
    if kata_text and not (drop_rate_limited and kata_effects.is_rate_limited(c.active_kata)):
        active = c.active_kata
        lines.append(f"**{role.capitalize()} kata: {active}: ** {kata_text}")
    for name in getattr(c, "active_kiho", []) or []:
        if kiho_effects.is_auto(name):
            continue
        rec = kiho.get(name)
        effect = rec["effect"] if rec else ""
        lines.append(f"**{role.capitalize()} kiho: {name}: ** {effect}")
    tat_reminder = tattoo_effects.active_tattoo_reminder(c)
    if tat_reminder:
        lines.append(f"**{role.capitalize()} tattoo:** {tat_reminder}")
    return lines


_MANEUVER_CHOICES = [
    app_commands.Choice(name="None", value="none"),
    app_commands.Choice(name="Feint (2 raises → bonus damage)", value="feint"),
    app_commands.Choice(name="Disarm (3 raises → 2k1 + contested Strength)", value="disarm"),
    app_commands.Choice(name="Knockdown (2 raises → contested Strength)", value="knockdown"),
    app_commands.Choice(name="Called Shot (1-4 raises → target body part)", value="called_shot"),
    app_commands.Choice(name="Extra Attack (5 raises → second attack)", value="extra_attack"),
]

_WEAPON_MATERIAL_CHOICES = [
    app_commands.Choice(name="Normal (steel/wood)", value="normal"),
    app_commands.Choice(name="Jade", value="jade"),
    app_commands.Choice(name="Crystal", value="crystal"),
    app_commands.Choice(name="Obsidian", value="obsidian"),
    app_commands.Choice(name="Nemuranai (magical)", value="nemuranai"),
]
# ===========================================================================
# Combat Board: persistent initiative display with player action buttons
# ===========================================================================

_BOARD_STANCE_OPTIONS = [
    discord.SelectOption(label="Attack (standard)", value="attack"),
    discord.SelectOption(label="Full Attack (+2k1 hit, -10 ATN)", value="full_attack"),
    discord.SelectOption(label="Defense (+Air+Defense to ATN)", value="defense"),
    discord.SelectOption(label="Center (forfeit actions, +1k1+Void next)", value="center"),
]


def _build_board_embed(enc: encounter.Encounter, guild_id: str) -> discord.Embed:
    tracker = _render_encounter(enc, guild_id)
    embed = discord.Embed(
        title="Combat Board",
        description=tracker,
        color=discord.Color.dark_red(),
    )
    cur = enc.current()
    if enc.started and cur is not None:
        owner_tag = f"<@{cur.owner_id}>" if cur.owner_id and not cur.is_npc else cur.name
        embed.set_footer(text=f"Current turn: {cur.name}  |  Attacks: /fight attack")
    elif not enc.started:
        embed.set_footer(text="Waiting to start  |  /combat next to begin")
    else:
        embed.set_footer(text="Attacks: /fight attack")
    return embed


_CAST_ELEMENTS = ("air", "earth", "fire", "water", "void")


def _best_element_for_all_spell(c: Character) -> str | None:
    """For 'All' element spells, pick the element with the highest ring that has slots."""
    best: str | None = None
    best_ring = -1
    slots_tracked = bool(c.spell_slots)
    for elem in _CAST_ELEMENTS:
        if elem == "void":
            continue
        if slots_tracked:
            slot = c.spell_slots.get(elem, 0)
            if slot <= 0 and c.void_spell_bonus <= 0:
                continue
        ring = stats.ring_value(c, elem)
        if ring > best_ring:
            best_ring = ring
            best = elem
    return best


def _build_castable_spells(c: Character) -> list[tuple[str, dict, str]]:
    """Return (spell_name, spell_data, element_key) for each castable known spell."""
    result: list[tuple[str, dict, str]] = []
    slots_tracked = bool(c.spell_slots)
    for name in c.spells_known:
        s = spells.get(name)
        if s is None:
            continue
        elem = s["element"].lower()
        if elem not in _CAST_ELEMENTS:
            elem_pick = _best_element_for_all_spell(c)
            if elem_pick is None:
                continue
            elem = elem_pick
        if slots_tracked:
            slot = c.spell_slots.get(elem, 0)
            if slot <= 0 and c.void_spell_bonus <= 0:
                continue
        affinity = c.affinity_element.lower() == elem if c.affinity_element else False
        deficiency = c.deficiency_element.lower() == elem if c.deficiency_element else False
        effective = c.school_rank + (1 if affinity else 0) + (-1 if deficiency else 0)
        if effective <= 0:
            continue
        result.append((s["name"], s, elem))
    return result


def _slot_display(c: Character, element: str) -> str:
    slot = c.spell_slots.get(element)
    if slot is None:
        return "slots: untracked"
    mx = stats.spell_slot_max(c, element)
    bonus = c.void_spell_bonus
    if slot > 0:
        return f"{slot}/{mx} {element.title()}"
    if bonus > 0:
        return f"0/{mx} {element.title()}, {bonus} bonus"
    return f"0/{mx} {element.title()}"


class CombatBoardView(views_base.PersistentView):
    KIND = "combat_board"

    def __init__(self, guild_id: str, channel_id: int) -> None:
        super().__init__()
        self.guild_id = guild_id
        self.channel_id = channel_id

    def _get_enc(self) -> encounter.Encounter | None:
        return _d.encounters.get(self.channel_id)

    def _is_active_player(self, user_id: str, enc: encounter.Encounter) -> bool:
        if not enc.started:
            return False
        cur = enc.current()
        return cur is not None and cur.owner_id == user_id and not cur.is_npc

    @staticmethod
    def _find_owned_combatant(user_id: str, enc: encounter.Encounter) -> encounter.Combatant | None:
        for cb in enc.combatants:
            if cb.owner_id == user_id and not cb.is_npc:
                return cb
        return None

    @discord.ui.button(label="Stance", style=discord.ButtonStyle.primary, row=0)
    async def stance_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        if not self._is_active_player(uid, enc) and not _d.is_dm(interaction):
            cur = enc.current()
            name = cur.name if cur else "unknown"
            await interaction.response.send_message(
                f"It is **{name}**'s turn, not yours.", ephemeral=True
            )
            return
        cur = enc.current()
        view = _BoardStanceSelect(self.guild_id, self.channel_id, cur.name)
        await interaction.response.send_message(
            f"Select stance for **{cur.name}**:", view=view, ephemeral=True,
        )

    @discord.ui.button(label="End Turn", style=discord.ButtonStyle.secondary, row=0)
    async def end_turn_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        if not enc.started:
            await interaction.response.send_message(
                "Encounter has not started yet. Use `/combat next` to begin.", ephemeral=True,
            )
            return
        if not enc.combatants:
            await interaction.response.send_message("No combatants.", ephemeral=True)
            return
        cur = enc.current()
        if cur is None:
            await interaction.response.send_message("No current combatant.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        if not self._is_active_player(uid, enc) and not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"It is **{cur.name}**'s turn, not yours.", ephemeral=True,
            )
            return
        ended_name = cur.name
        prev_round = enc.round
        next_cb = enc.advance()
        guild = self.guild_id
        _d.save_encounter(guild, enc)
        mention = f"<@{next_cb.owner_id}> " if next_cb.owner_id and not next_cb.is_npc else ""
        desc_parts: list[str] = [f"**{ended_name}**'s turn is done."]
        expiry = _expiry_notes(enc)
        if expiry:
            desc_parts.extend(expiry)
        if next_cb.center_bonus_available:
            rec = _d.resolve_combatant_record(guild, next_cb)
            vr = rec.character.void_ring if rec else "?"
            desc_parts.append(
                f"**Center Stance bonus active**: +1k1 + {vr} (Void Ring) on one roll this turn. "
                "+10 Initiative this Round."
            )
        reminders = condition_effects.condition_reminders(next_cb.conditions)
        if reminders:
            desc_parts.append("\n".join(reminders))
        embed = discord.Embed(
            title=f">> {next_cb.name}'s Turn",
            color=discord.Color.green(),
            description="\n".join(desc_parts),
        )
        embed.set_footer(text=f"Round {enc.round}")
        await interaction.response.send_message(
            content=mention, embed=embed,
            allowed_mentions=_PING_MENTIONS,
        )
        if enc.round != prev_round:
            await _d.combat_log(guild, f"--- Round {enc.round} ---")
        await _d.combat_log(guild, f"Turn done: {ended_name}")
        cond_str = f" [{', '.join(sorted(next_cb.conditions))}]" if next_cb.conditions else ""
        await _d.combat_log(guild, f"Turn: {next_cb.name}{cond_str}")
        await _refresh_board(enc, guild)

    @discord.ui.button(label="End Combat", style=discord.ButtonStyle.danger, row=0)
    async def end_combat_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"Only **{_d.ROLE_FORTUNE}** or **{_d.ROLE_KAMI}** can end combat.", ephemeral=True,
            )
            return
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        guild = self.guild_id
        embed, logs = _render_summary(enc, guild, final=True)
        await _close_roster_message(enc, guild, "Encounter ended.")
        _d.encounters.pop(self.channel_id, None)
        _d.delete_encounter(self.channel_id)
        self._disable()
        enc.board_message_id = 0
        await interaction.response.send_message(content="Encounter ended.", embed=embed)
        await _d.combat_log(guild, "--- Encounter ended --- " + (" | ".join(logs) if logs else ""))

    @discord.ui.button(label="Techniques", style=discord.ButtonStyle.blurple, row=1)
    async def technique_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        if not enc.started:
            await interaction.response.send_message(
                "Encounter has not started yet.", ephemeral=True,
            )
            return
        cur = enc.current()
        if cur is None:
            await interaction.response.send_message("No current combatant.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        if not self._is_active_player(uid, enc) and not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"It is **{cur.name}**'s turn, not yours.", ephemeral=True,
            )
            return
        rec = _d.resolve_combatant_record(self.guild_id, cur)
        if rec is None:
            await interaction.response.send_message(
                f"Cannot resolve sheet for **{cur.name}**.", ephemeral=True,
            )
            return
        available = declarable_techniques.known_declarable(rec.character.techniques)
        if not available:
            await interaction.response.send_message(
                f"**{cur.name}** has no declarable techniques.", ephemeral=True,
            )
            return
        active_keys = set(cur.declared_techniques.keys())
        usable: list[dict] = []
        for entry in available:
            key = entry["display"].lower()
            if key in active_keys:
                continue
            limit = entry.get("limit", "none")
            max_uses = entry.get("max_uses", 1)
            if limit in ("encounter", "skirmish"):
                if cur.technique_uses_enc.get(key, 0) >= max_uses:
                    continue
            elif limit == "turn":
                if key in cur.used_this_turn:
                    continue
            elif limit == "round":
                if key in cur.used_this_round:
                    continue
            usable.append(entry)
        if not usable:
            active_names = [e.get("display", k) for k, e in cur.declared_techniques.items()]
            msg = f"**{cur.name}** has no more techniques available this turn."
            if active_names:
                msg += f"\nActive: {', '.join(active_names)}"
            await interaction.response.send_message(msg, ephemeral=True)
            return
        options = []
        for entry in usable[:25]:
            cost_str = ""
            if entry.get("cost") == 1:
                cost_str = "[1 VP] "
            elif isinstance(entry.get("cost"), int) and entry["cost"] > 1:
                cost_str = f"[{entry['cost']} VP] "
            elif entry.get("cost") == "slot":
                cost_str = "[Spell slot] "
            limit_str = ""
            lim = entry.get("limit", "none")
            if lim != "none":
                limit_str = f" (1x/{lim})"
            label = f"{entry['display']}"[:100]
            desc_text = f"{cost_str}{entry.get('desc', '')}{limit_str}"[:100]
            options.append(discord.SelectOption(
                label=label,
                value=entry["display"],
                description=desc_text,
            ))
        view = _BoardTechniqueSelect(self.guild_id, self.channel_id, cur.name, options)
        await interaction.response.send_message(
            f"Declare a technique for **{cur.name}**:", view=view, ephemeral=True,
        )

    @discord.ui.button(label="Attack", style=discord.ButtonStyle.success, row=1)
    async def attack_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        if not enc.started:
            await interaction.response.send_message(
                "Encounter has not started yet. Use `/combat next` to begin.", ephemeral=True,
            )
            return
        cur = enc.current()
        if cur is None:
            await interaction.response.send_message("No current combatant.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        if not self._is_active_player(uid, enc) and not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"It is **{cur.name}**'s turn, not yours.", ephemeral=True,
            )
            return
        targets = [c for c in enc.combatants if c.name.lower() != cur.name.lower()]
        if not targets:
            await interaction.response.send_message("No valid targets in this encounter.", ephemeral=True)
            return
        options = [
            discord.SelectOption(label=t.name[:100], value=t.name[:100])
            for t in targets[:25]
        ]
        view = _BoardAttackTargetSelect(self.guild_id, self.channel_id, cur.name, options)
        await interaction.response.send_message(
            f"Select a target for **{cur.name}**'s attack:", view=view, ephemeral=True,
        )

    @discord.ui.button(label="Void Armor", style=discord.ButtonStyle.secondary, row=2)
    async def void_armor_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        cb = self._find_owned_combatant(uid, enc)
        if cb is None and _d.is_dm(interaction):
            cur = enc.current()
            if cur is not None:
                cb = cur
        if cb is None:
            await interaction.response.send_message(
                "You have no combatant in this encounter. Use `/fight void armor` instead.", ephemeral=True,
            )
            return
        rec = _d.resolve_combatant_record(self.guild_id, cb)
        if rec is None:
            await interaction.response.send_message(f"Cannot resolve sheet for **{cb.name}**.", ephemeral=True)
            return
        c = rec.character
        ok, reason = advantage_effects.can_spend_void_on_roll(c)
        if not ok:
            await interaction.response.send_message(reason, ephemeral=True)
            return
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{cb.name}** has no Void Points (0/{c.max_void_points}).", ephemeral=True,
            )
            return
        if not cb.consume_once("void_combat", "round"):
            await interaction.response.send_message(
                f"**{cb.name}** has already spent a Void Point this Round (one per Round limit).", ephemeral=True,
            )
            return
        c.current_void_points -= 1
        _d.tally(self.channel_id, cb.name, "void")
        cb.void_armor_tn_bonus += 10
        _d.store.save(rec)
        guild = str(self.guild_id)
        _d.save_encounter(guild, enc)
        await interaction.response.send_message(
            f"**{cb.name}**: +10 Armor TN this Round ({c.current_void_points}/{c.max_void_points} VP left).",
            ephemeral=True,
        )
        ch = _d.bot_client.get_channel(self.channel_id)
        if ch is not None:
            embed = discord.Embed(
                title=f"{cb.name}: Void Armor",
                color=discord.Color.purple(),
                description=(
                    f"**+10 Armor TN** for this Round\n"
                    f"Armor TN bonus: +{cb.void_armor_tn_bonus} | VP remaining: {c.current_void_points}/{c.max_void_points}\n"
                    f"Clears at the start of the next Round."
                ),
            )
            embed.set_footer(text=f"Spent by {interaction.user.display_name}")
            try:
                await ch.send(embed=embed)
            except discord.HTTPException:
                pass
        await _d.combat_log(guild, f"Void Armor: {cb.name} (+10 ATN, {c.current_void_points} VP left)")
        await _refresh_board(enc, guild)

    @discord.ui.button(label="Void Init", style=discord.ButtonStyle.secondary, row=2)
    async def void_init_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        cb = self._find_owned_combatant(uid, enc)
        if cb is None and _d.is_dm(interaction):
            cur = enc.current()
            if cur is not None:
                cb = cur
        if cb is None:
            await interaction.response.send_message(
                "You have no combatant in this encounter. Use `/fight void initiative` instead.", ephemeral=True,
            )
            return
        rec = _d.resolve_combatant_record(self.guild_id, cb)
        if rec is None:
            await interaction.response.send_message(f"Cannot resolve sheet for **{cb.name}**.", ephemeral=True)
            return
        c = rec.character
        ok, reason = advantage_effects.can_spend_void_on_roll(c)
        if not ok:
            await interaction.response.send_message(reason, ephemeral=True)
            return
        if c.current_void_points <= 0:
            await interaction.response.send_message(
                f"**{cb.name}** has no Void Points (0/{c.max_void_points}).", ephemeral=True,
            )
            return
        if not cb.consume_once("void_combat", "round"):
            await interaction.response.send_message(
                f"**{cb.name}** has already spent a Void Point this Round (one per Round limit).", ephemeral=True,
            )
            return
        c.current_void_points -= 1
        _d.tally(self.channel_id, cb.name, "void")
        cb.void_initiative_boost += 10
        cur_before = enc.current() if enc.started else None
        enc._sort()
        if cur_before is not None:
            enc.turn_index = enc.combatants.index(cur_before)
        _d.store.save(rec)
        guild = str(self.guild_id)
        _d.save_encounter(guild, enc)
        await interaction.response.send_message(
            f"**{cb.name}**: +10 Initiative ({c.current_void_points}/{c.max_void_points} VP left).",
            ephemeral=True,
        )
        ch = _d.bot_client.get_channel(self.channel_id)
        if ch is not None:
            embed = discord.Embed(
                title=f"{cb.name}: Void Initiative",
                color=discord.Color.purple(),
                description=(
                    f"**+10 Initiative** for the skirmish\n"
                    f"Effective initiative: **{cb.effective_initiative}** | VP remaining: {c.current_void_points}/{c.max_void_points}\n"
                    f"Persists until the encounter ends."
                ),
            )
            embed.set_footer(text=f"Spent by {interaction.user.display_name}")
            try:
                await ch.send(embed=embed)
            except discord.HTTPException:
                pass
        await _d.combat_log(guild, f"Void Init: {cb.name} (+10, now {cb.effective_initiative}, {c.current_void_points} VP left)")
        await _refresh_board(enc, guild)

    @discord.ui.button(label="Cast Spell", style=discord.ButtonStyle.blurple, row=3)
    async def cast_spell_btn(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = self._get_enc()
        if enc is None:
            await interaction.response.send_message("No active encounter.", ephemeral=True)
            return
        if not enc.started:
            await interaction.response.send_message(
                "Encounter has not started yet. Use `/combat next` to begin.", ephemeral=True,
            )
            return
        cur = enc.current()
        if cur is None:
            await interaction.response.send_message("No current combatant.", ephemeral=True)
            return
        uid = str(interaction.user.id)
        if not self._is_active_player(uid, enc) and not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"It is **{cur.name}**'s turn, not yours.", ephemeral=True,
            )
            return
        rec = _d.resolve_combatant_record(self.guild_id, cur)
        if rec is None:
            await interaction.response.send_message(
                f"Cannot resolve sheet for **{cur.name}**.", ephemeral=True,
            )
            return
        c = rec.character
        if not c.spells_known:
            await interaction.response.send_message(
                f"**{c.name}** knows no spells.", ephemeral=True,
            )
            return
        castable = _build_castable_spells(c)
        if not castable:
            await interaction.response.send_message(
                f"**{c.name}** has no castable spells (no slots remaining or deficiency blocks all).\n"
                f"A DM must call `/dm new_day` to refresh spell slots.",
                ephemeral=True,
            )
            return
        options: list[discord.SelectOption] = []
        for spell_name, s, elem in castable[:25]:
            tn = combat.spell_casting_tn(s["mastery"])
            slot_info = _slot_display(c, elem)
            label = spell_name[:100]
            desc = f"{s['element']} M{s['mastery']} TN {tn} | {slot_info}"[:100]
            options.append(discord.SelectOption(label=label, value=spell_name, description=desc))
        view = _BoardSpellSelect(self.guild_id, self.channel_id, cur.name, interaction.user.id, options)
        await interaction.response.send_message(
            f"Select a spell for **{cur.name}** to cast:", view=view, ephemeral=True,
        )


class _BoardAttackTargetSelect(discord.ui.View):
    def __init__(self, guild_id: str, channel_id: int, attacker_name: str,
                 options: list[discord.SelectOption]) -> None:
        super().__init__(timeout=60)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.attacker_name = attacker_name
        self.target_select.options = options

    @discord.ui.select(placeholder="Choose target...")
    async def target_select(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        target_name = select.values[0]
        enc = _d.encounters.get(self.channel_id)
        if enc is None:
            await interaction.response.edit_message(content="No active encounter.", view=None)
            return
        atk_cb = enc.find(self.attacker_name)
        if atk_cb is None:
            await interaction.response.edit_message(
                content=f"**{self.attacker_name}** is no longer in initiative.", view=None,
            )
            return
        tgt_cb = enc.find(target_name)
        if tgt_cb is None:
            await interaction.response.edit_message(
                content=f"**{target_name}** is no longer in initiative.", view=None,
            )
            return
        guild = self.guild_id
        attacker_rec = _d.resolve_combatant_record(guild, atk_cb)
        if attacker_rec is None:
            await interaction.response.edit_message(
                content=f"Cannot resolve sheet for **{self.attacker_name}**.", view=None,
            )
            return
        target_rec = None
        target_creature_rec = None
        if tgt_cb.is_npc:
            target_rec = _d.store.get_by_name(guild, _d.NPC_OWNER, tgt_cb.name)
            if target_rec is None:
                target_creature_rec = _d.store.get_creature_by_name(guild, tgt_cb.name)
        else:
            if tgt_cb.owner_id:
                target_rec = _d.store.get_active(guild, tgt_cb.owner_id)
        if target_rec is None and target_creature_rec is None:
            await interaction.response.edit_message(
                content=f"Cannot resolve sheet or creature record for **{target_name}**.", view=None,
            )
            return
        weapon = attacker_rec.character.equipped_weapon or "unarmed"
        await interaction.response.edit_message(
            content=f"Rolling **{self.attacker_name}** attack on **{target_name}** with **{weapon.replace('_', ' ').title()}**...",
            view=None,
        )
        await _execute_attack(
            interaction, guild, attacker_rec, target_rec, target_creature_rec,
            weapon, raises=0, increased_damage=0, man="none",
            spend_void=False, void_damage=False,
            a_stance_explicit=None, d_stance_explicit=None,
            bonus_tn=0, mat="normal", off_hand=False,
            response_used=True,
        )


class _BoardStanceSelect(discord.ui.View):
    def __init__(self, guild_id: str, channel_id: int, combatant_name: str) -> None:
        super().__init__(timeout=60)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.combatant_name = combatant_name

    @discord.ui.select(
        placeholder="Choose a stance...",
        options=_BOARD_STANCE_OPTIONS,
    )
    async def pick(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        stance_val = select.values[0]
        enc = _d.encounters.get(self.channel_id)
        if enc is None:
            await interaction.response.edit_message(content="No active encounter.", view=None)
            return
        cb = enc.find(self.combatant_name)
        if cb is None:
            await interaction.response.edit_message(
                content=f"**{self.combatant_name}** is no longer in initiative.", view=None,
            )
            return
        if stance_val == "full_defense":
            await interaction.response.edit_message(
                content="Use `/fight full_defense` instead: Full Defense requires a Defense/Reflexes roll.",
                view=None,
            )
            return
        blocked, block_reason = condition_effects.invalid_stance(cb.conditions, stance_val)
        if blocked:
            await interaction.response.edit_message(
                content=f"**{cb.name}** cannot use that stance: {block_reason}", view=None,
            )
            return
        cb.stance = stance_val
        if stance_val == "center":
            cb.center_bonus_available = False
            cb.center_init_boost = 0
        _d.save_encounter(self.guild_id, enc)
        label = stance_val.replace("_", " ").title()
        effects = combat.stance_effects(stance_val)
        msg = f"**{cb.name}**: {label} Stance"
        if effects:
            msg += f"\n{effects}"
        await interaction.response.edit_message(content=msg, view=None)
        await _d.combat_log(self.guild_id, f"Stance: {cb.name} >> {label}")
        await _refresh_board(enc, self.guild_id)


class _BoardTechniqueSelect(discord.ui.View):
    def __init__(self, guild_id: str, channel_id: int, combatant_name: str,
                 options: list[discord.SelectOption]) -> None:
        super().__init__(timeout=120)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.combatant_name = combatant_name
        self.tech_select.options = options

    @discord.ui.select(placeholder="Choose a technique to declare...")
    async def tech_select(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        tech_name = select.values[0]
        entry = declarable_techniques.get(tech_name)
        if entry is None:
            await interaction.response.edit_message(
                content=f"Unknown technique: {tech_name}", view=None,
            )
            return
        enc = _d.encounters.get(self.channel_id)
        if enc is None:
            await interaction.response.edit_message(content="No active encounter.", view=None)
            return
        cb = enc.find(self.combatant_name)
        if cb is None:
            await interaction.response.edit_message(
                content=f"**{self.combatant_name}** is no longer in initiative.", view=None,
            )
            return
        key = tech_name.lower()
        cost = entry.get("cost", 0)
        if isinstance(cost, int) and cost > 0:
            rec = _d.resolve_combatant_record(self.guild_id, cb)
            if rec is None:
                await interaction.response.edit_message(
                    content=f"Cannot resolve sheet for **{cb.name}**.", view=None,
                )
                return
            c = rec.character
            ok, reason_block = advantage_effects.can_spend_void_on_roll(c)
            if not ok:
                await interaction.response.edit_message(
                    content=f"**{cb.name}** cannot spend Void Points: {reason_block}", view=None,
                )
                return
            if c.current_void_points < cost:
                await interaction.response.edit_message(
                    content=f"**{cb.name}** needs {cost} VP but has {c.current_void_points}.", view=None,
                )
                return
            c.current_void_points -= cost
            _d.store.save(rec)
            _d.tally(self.channel_id, cb.name, "void")
        if not cb.declare_technique(key, entry):
            limit = entry.get("limit", "none")
            await interaction.response.edit_message(
                content=f"**{tech_name}** already used this {limit}.", view=None,
            )
            return
        _d.save_encounter(self.guild_id, enc)
        cost_note = ""
        if isinstance(cost, int) and cost > 0:
            rec = _d.resolve_combatant_record(self.guild_id, cb)
            vp_left = rec.character.current_void_points if rec else "?"
            cost_note = f" ({cost} VP spent, {vp_left} remaining)"
        elif cost == "slot":
            cost_note = " (spell slot consumed)"
        effects_str = ""
        efx = entry.get("effects", {})
        if efx and not entry.get("manual"):
            parts: list[str] = []
            if efx.get("atk_rolled") or efx.get("atk_kept") or efx.get("atk_flat"):
                r = efx.get("atk_rolled", 0)
                k = efx.get("atk_kept", 0)
                f_val = efx.get("atk_flat", 0)
                bits = []
                if r or k:
                    bits.append(f"+{r}k{k}")
                if f_val:
                    bits.append(f"+{f_val}")
                parts.append(f"Attack {' '.join(bits)}")
            if efx.get("dmg_rolled") or efx.get("dmg_kept") or efx.get("dmg_flat"):
                r = efx.get("dmg_rolled", 0)
                k = efx.get("dmg_kept", 0)
                f_val = efx.get("dmg_flat", 0)
                bits = []
                if r or k:
                    bits.append(f"+{r}k{k}")
                if f_val:
                    bits.append(f"+{f_val}")
                parts.append(f"Damage {' '.join(bits)}")
            if efx.get("dmg_explode"):
                parts.append("Damage dice explode")
            if efx.get("reduction_ignore"):
                val = efx["reduction_ignore"]
                parts.append("Ignore all Reduction" if val >= 999 else f"Ignore {val} Reduction")
            if efx.get("target_reduction_penalty"):
                parts.append(f"Target Reduction -{efx['target_reduction_penalty']}")
            if efx.get("on_hit_condition"):
                parts.append(f"Inflict {efx['on_hit_condition'].title()} on hit")
            if efx.get("ignore_wound_penalties"):
                parts.append("Ignore wound penalties")
            if efx.get("simple_action_attack"):
                parts.append("Attacks as Simple Actions")
            if efx.get("atn_bonus"):
                parts.append(f"+{efx['atn_bonus']} Armor TN")
            if efx.get("reduction_bonus"):
                parts.append(f"+{efx['reduction_bonus']} Reduction")
            if efx.get("ignore_target_stance_atn"):
                parts.append("Ignore target stance ATN bonuses")
            if parts:
                effects_str = "\nEffects (auto-applied): " + ", ".join(parts)
        manual_note = ""
        if entry.get("manual"):
            manual_note = "\nFortune adjudicates the effects."
        duration = entry.get("duration", "attack")
        dur_label = duration.replace("_", " ").title()
        msg = (
            f"**{cb.name}** declares **{tech_name}**{cost_note}\n"
            f"*{entry.get('desc', '')}*\n"
            f"Duration: {dur_label}"
            f"{effects_str}{manual_note}"
        )
        await interaction.response.edit_message(content=msg, view=None)
        ch = _d.bot_client.get_channel(self.channel_id)
        if ch:
            announce = f"**{cb.name}** activates **{tech_name}**{cost_note}"
            if entry.get("manual"):
                announce += " -- Fortune adjudicates."
            try:
                await ch.send(announce)
            except discord.HTTPException:
                pass
        await _d.combat_log(self.guild_id, f"Technique: {cb.name} declares {tech_name}{cost_note}")
        await _refresh_board(enc, self.guild_id)


class _BoardSpellSelect(discord.ui.View):
    def __init__(self, guild_id: str, channel_id: int, caster_name: str,
                 caster_user_id: int, options: list[discord.SelectOption]) -> None:
        super().__init__(timeout=120)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.caster_name = caster_name
        self.caster_user_id = caster_user_id
        self.spell_select.options = options

    @discord.ui.select(placeholder="Choose a spell to cast...")
    async def spell_select(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        spell_name = select.values[0]
        s = spells.get(spell_name)
        if s is None:
            await interaction.response.edit_message(content=f"Unknown spell: {spell_name}", view=None)
            return
        enc = _d.encounters.get(self.channel_id)
        if enc is None:
            await interaction.response.edit_message(content="No active encounter.", view=None)
            return
        cb = enc.find(self.caster_name)
        if cb is None:
            await interaction.response.edit_message(
                content=f"**{self.caster_name}** is no longer in initiative.", view=None,
            )
            return
        rec = _d.resolve_combatant_record(self.guild_id, cb)
        if rec is None:
            await interaction.response.edit_message(
                content=f"Cannot resolve sheet for **{self.caster_name}**.", view=None,
            )
            return
        c = rec.character
        element = s["element"].lower()
        if element not in _CAST_ELEMENTS:
            element = _best_element_for_all_spell(c)
            if element is None:
                await interaction.response.edit_message(
                    content="No spell slots available for any element.", view=None,
                )
                return
        used_bonus_slot = False
        slot_remaining = c.spell_slots.get(element)
        if slot_remaining is not None and slot_remaining <= 0:
            if c.void_spell_bonus > 0:
                used_bonus_slot = True
            else:
                slot_max = stats.spell_slot_max(c, element)
                bonus_max = stats.void_bonus_max(c)
                await interaction.response.edit_message(
                    content=(
                        f"**{c.name}** has no **{element.title()}** spell slots remaining "
                        f"(0/{slot_max}) and no Void bonus slots (0/{bonus_max})."
                    ),
                    view=None,
                )
                return
        affinity = c.affinity_element.lower() == element if c.affinity_element else False
        deficiency = c.deficiency_element.lower() == element if c.deficiency_element else False
        fear_r = cb.fear_penalty
        wound_pen = stats.wound_penalty(c)
        ring_val = stats.ring_value(c, element)
        result = combat.resolve_spell_casting(
            ring_val, c.school_rank, s["mastery"], _d.engine,
            affinity=affinity, deficiency=deficiency,
            extra_rolled=-fear_r, extra_kept=0,
            raises=0, extra_flat=wound_pen,
        )
        if result.get("cannot_cast"):
            await interaction.response.edit_message(
                content=f"**{c.name}** cannot cast **{s['name']}**: {result['reason']}.",
                view=None,
            )
            return
        if used_bonus_slot:
            c.void_spell_bonus = max(0, c.void_spell_bonus - 1)
        elif element in c.spell_slots:
            c.spell_slots[element] = max(0, c.spell_slots[element] - 1)
        _d.store.save(rec)
        success = result["success"]
        embed = discord.Embed(
            title=f"{'SUCCESS' if success else 'FAILED'}: {c.name} casts {s['name']}",
            color=discord.Color.gold() if success else discord.Color.red(),
        )
        notes: list[str] = []
        if affinity:
            notes.append(f"Affinity ({element.title()}): Effective rank {result['effective_rank']}")
        if deficiency:
            notes.append(f"Deficiency ({element.title()}): Effective rank {result['effective_rank']}")
        if wound_pen:
            notes.append(f"Wound penalty: {wound_pen}")
        if fear_r:
            notes.append(f"Fear: -{fear_r}k0")
        if used_bonus_slot:
            bonus_max = stats.void_bonus_max(c)
            notes.append(f"Void bonus slot used ({c.void_spell_bonus}/{bonus_max} left)")
        elif element in c.spell_slots:
            slot_max = stats.spell_slot_max(c, element)
            notes.append(f"{element.title()} slots: {c.spell_slots[element]}/{slot_max}")
        roll_desc = (
            f"**{s['element']}** Ring {ring_val} + School Rank {result['effective_rank']}"
            f" = {result['rolled']}k{result['kept']}\n"
            f"Roll **{result['total']}** vs TN **{result['tn']}**"
            f": {'**SUCCESS**' if success else '**FAILED** (slot consumed)'}"
        )
        embed.add_field(name="Spell Casting Roll", value=roll_desc, inline=False)
        if notes:
            embed.add_field(name="Modifiers", value=" | ".join(notes), inline=False)
        if success:
            spell_info = f"**Mastery {s['mastery']}** | Range: {s['range']} | Duration: {s['duration']}"
            embed.add_field(name="Spell", value=spell_info, inline=False)
            if s.get("effect"):
                effect_text = s["effect"][:1024]
                embed.add_field(name="Effect", value=effect_text, inline=False)
        embed.set_footer(text=f"Cast by {interaction.user.display_name} | Use /spell cast for raises, Void, and concealment")
        await interaction.response.edit_message(
            content=f"**{c.name}** {'casts' if success else 'fails to cast'} **{s['name']}**.",
            view=None,
        )
        ch = _d.bot_client.get_channel(self.channel_id)
        conds = spell_conditions(s.get("effect", "")) if success else []
        if ch is not None:
            if conds:
                targets = [t for t in enc.combatants]
                if targets:
                    target_view = _SpellConditionTargetSelect(
                        self.guild_id, self.channel_id, self.caster_name,
                        self.caster_user_id, s["name"], conds, targets,
                    )
                    try:
                        await ch.send(embed=embed, view=target_view)
                    except discord.HTTPException:
                        await ch.send(embed=embed)
                else:
                    try:
                        await ch.send(embed=embed)
                    except discord.HTTPException:
                        pass
            else:
                try:
                    await ch.send(embed=embed)
                except discord.HTTPException:
                    pass
        tag = "SUCCESS" if success else "FAILED"
        await _d.combat_log(
            self.guild_id,
            f"Spell: {c.name} {tag} {s['name']} ({s['element']} M{s['mastery']}) "
            f"roll {result['total']} vs TN {result['tn']}"
        )
        await _refresh_board(enc, self.guild_id)


class _SpellConditionTargetSelect(discord.ui.View):
    """Dropdown attached to a successful spell cast: Select a target to request conditions on."""

    def __init__(self, guild_id: str, channel_id: int, caster_name: str,
                 caster_user_id: int, spell_name: str,
                 conds: list[tuple[str, int]],
                 targets: list[encounter.Combatant]) -> None:
        super().__init__(timeout=300)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.caster_name = caster_name
        self.caster_user_id = caster_user_id
        self.spell_name = spell_name
        self.conds = conds
        options = [
            discord.SelectOption(label=t.name[:100], value=t.name[:100])
            for t in targets[:25]
        ]
        self.target_select.options = options

    @discord.ui.select(placeholder="Apply conditions to...")
    async def target_select(self, interaction: discord.Interaction, select: discord.ui.Select) -> None:
        if interaction.user.id != self.caster_user_id and not _d.is_dm(interaction):
            await interaction.response.send_message("Only the caster or a DM can do this.", ephemeral=True)
            return
        target_name = select.values[0]
        enc = _d.encounters.get(self.channel_id)
        tgt_cb = enc.find(target_name) if enc else None
        if tgt_cb is None:
            await interaction.response.send_message(
                f"**{target_name}** is no longer in initiative.", ephemeral=True,
            )
            return
        prompt_view = SpellConditionPromptView(
            self.guild_id, self.channel_id, tgt_cb.name, self.caster_user_id,
            self.spell_name, self.conds,
        )
        cond_names = ", ".join(c_name.title() for c_name, _ in self.conds)
        await interaction.response.send_message(
            f"**{self.spell_name}** on **{tgt_cb.name}**: Request conditions ({cond_names})",
            view=prompt_view,
        )


async def _refresh_board(enc: encounter.Encounter, guild_id: str) -> None:
    if not enc.board_message_id:
        return
    ch = _d.bot_client.get_channel(enc.channel_id)
    if ch is None:
        return
    try:
        msg = await ch.fetch_message(enc.board_message_id)
    except discord.NotFound:
        enc.board_message_id = 0
        _d.save_encounter(guild_id, enc)
        return
    except discord.HTTPException:
        return
    embed = _build_board_embed(enc, guild_id)
    view = CombatBoardView(guild_id, enc.channel_id)
    try:
        await msg.edit(embed=embed, view=view)
    except discord.HTTPException:
        pass


async def _post_board(channel: discord.TextChannel, enc: encounter.Encounter, guild_id: str) -> None:
    embed = _build_board_embed(enc, guild_id)
    view = CombatBoardView(guild_id, enc.channel_id)
    msg = await channel.send(embed=embed, view=view)
    await view.persist(msg)
    enc.board_message_id = msg.id
    _d.save_encounter(guild_id, enc)


# ===========================================================================
# /combat group: initiative tracker
# ===========================================================================
combat_group = app_commands.Group(name="combat", description="Track combat initiative and turn order.")
combat_condition = app_commands.Group(name="condition", description="Apply, clear, or view conditions.", parent=combat_group)
combat_turn = app_commands.Group(name="turn", description="Initiative adjustments: Hold, delay, act, surprise.", parent=combat_group)
combat_void = app_commands.Group(name="void", description="Round-level Void Point combat effects.", parent=combat_group)

fight_group = app_commands.Group(name="fight", description="Attack, stance, and defense actions.")
combat_env = app_commands.Group(name="env", description="Environment effects: Cover, notes, damage.", parent=fight_group)

engage_group = app_commands.Group(name="engage", description="Grapple, duel, and mass battle subsystems.")
combat_grapple = app_commands.Group(name="grapple", description="Grappling subsystem.", parent=engage_group)
combat_duel = app_commands.Group(name="duel", description="Iaijutsu dueling.", parent=engage_group)
combat_battle = app_commands.Group(name="battle", description="Mass Battle system.", parent=engage_group)


@fight_group.command(
    name="attack",
    description="Attack another character. Rolls to hit; on a hit a DM authorizes the outcome.",
)
@app_commands.describe(
    target="The player to attack (their active character). Or use target_npc / target_creature.",
    target_npc="Attack a stored NPC by name (instead of a player).",
    target_creature="Attack a spawned creature by name (instead of a player).",
    attacker_npc="Attack WITH a stored NPC instead of your own character [Fortune]",
    weapon="Weapon for this attack. Defaults to your wielded weapon (`/inventory`), else unarmed.",
    raises="Called Raises: Each adds +5 to the target's Armor TN.",
    increased_damage="Increased Damage raises: Each adds +5 TN AND +1 damage die on a hit.",
    maneuver="A combat maneuver (its raise cost is added to the TN automatically).",
    spend_void="Spend a Void Point for +1k1 on the attack roll (RAW: Not valid on damage).",
    void_damage="(Katana only) Spend a Void Point for +1k1 on the damage roll.",
    attacker_stance="Your stance (Full Attack = +2k1 to hit).",
    defender_stance="Target's stance (affects their Armor TN).",
    bonus_tn="Situational +/- to the target's Armor TN (DM discretion).",
    weapon_material="Weapon material (jade/crystal/obsidian bypass Invulnerability; nemuranai too).",
    off_hand="Attack with your off-hand weapon instead of main hand (applies off-hand penalty).",
)
@app_commands.choices(
    attacker_stance=_ATTACKER_STANCES, defender_stance=_DEFENDER_STANCES, maneuver=_MANEUVER_CHOICES,
    weapon_material=_WEAPON_MATERIAL_CHOICES,
)
@app_commands.checks.cooldown(1, 3.0)
async def attack(
    interaction: discord.Interaction,
    target: discord.Member | None = None,
    target_npc: str | None = None,
    target_creature: str | None = None,
    attacker_npc: str | None = None,
    weapon: str | None = None,
    raises: app_commands.Range[int, 0, 10] = 0,
    increased_damage: app_commands.Range[int, 0, 10] = 0,
    maneuver: app_commands.Choice[str] | None = None,
    spend_void: bool = False,
    void_damage: bool = False,
    attacker_stance: app_commands.Choice[str] | None = None,
    defender_stance: app_commands.Choice[str] | None = None,
    bonus_tn: app_commands.Range[int, -50, 50] = 0,
    weapon_material: app_commands.Choice[str] | None = None,
    off_hand: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)

    # Resolve the attacker: a stored NPC (Fortune) or the caller's active character.
    if attacker_npc:
        if not await _d.require_dm_role(interaction):
            return
        attacker_rec = _d.store.get_by_name(guild, _d.NPC_OWNER, attacker_npc)
        if attacker_rec is None:
            await interaction.response.send_message(
                f"No NPC named **{attacker_npc}**.", ephemeral=True
            )
            return
    else:
        attacker_rec = _d.store.get_active(guild, str(interaction.user.id))
        if attacker_rec is None:
            await interaction.response.send_message(
                "You have no active character. Use `/sheet create` first.", ephemeral=True
            )
            return
    if await _d.refuse_if_cannot_act(interaction, attacker_rec.character):
        return

    # Weapon: off_hand flag overrides to off-hand weapon; else explicit, else wielded, else unarmed (Jiujutsu).
    if off_hand:
        if not attacker_rec.character.off_hand_weapon:
            await interaction.response.send_message(
                "No off-hand weapon equipped. Set one with `/inventory`.", ephemeral=True
            )
            return
        weapon = attacker_rec.character.off_hand_weapon
    else:
        weapon = (weapon or "").strip() or attacker_rec.character.equipped_weapon or "unarmed"

    # Resolve the target: a spawned creature, a stored NPC, or a player's character.
    target_rec = None
    target_creature_rec = None
    if target_creature:
        target_creature_rec = _d.store.get_creature_by_name(guild, target_creature)
        if target_creature_rec is None:
            await interaction.response.send_message(
                f"No creature named **{target_creature}**.", ephemeral=True
            )
            return
    elif target_npc:
        target_rec = _d.store.get_by_name(guild, _d.NPC_OWNER, target_npc)
        if target_rec is None:
            await interaction.response.send_message(f"No NPC named **{target_npc}**.", ephemeral=True)
            return
    elif target is not None:
        target_rec = _d.store.get_active(guild, str(target.id))
        if target_rec is None:
            await interaction.response.send_message(
                f"{target.display_name} has no active character.", ephemeral=True
            )
            return
    else:
        await interaction.response.send_message(
            "Pick a target: `target:` (player), `target_npc:`, or `target_creature:`.", ephemeral=True
        )
        return
    if target_creature_rec is not None and creature.creature_is_dead(target_creature_rec.creature):
        await interaction.response.send_message(
            f"💀 **{target_creature_rec.creature.name}** has already been slain.", ephemeral=True
        )
        return
    if target_rec is not None and await _d.refuse_if_dead(interaction, target_rec.character):
        return

    a_stance_explicit = attacker_stance.value if attacker_stance else None
    d_stance_explicit = defender_stance.value if defender_stance else None
    man = maneuver.value if maneuver else "none"
    mat = weapon_material.value if weapon_material else "normal"

    await _execute_attack(
        interaction, guild, attacker_rec, target_rec, target_creature_rec,
        weapon, raises, increased_damage, man, spend_void, void_damage,
        a_stance_explicit, d_stance_explicit, bonus_tn, mat, off_hand,
    )


async def _execute_attack(
    interaction: discord.Interaction,
    guild: str,
    attacker_rec,
    target_rec,
    target_creature_rec,
    weapon: str,
    raises: int,
    increased_damage: int,
    man: str,
    spend_void: bool,
    void_damage: bool,
    a_stance_explicit: str | None,
    d_stance_explicit: str | None,
    bonus_tn: int,
    mat: str,
    off_hand: bool,
    response_used: bool = False,
) -> None:
    async def _reply(content: str = "", *, ephemeral: bool = False, **kwargs):
        nonlocal response_used
        if response_used:
            return await interaction.followup.send(content=content, ephemeral=ephemeral, wait=True, **kwargs)
        else:
            await interaction.response.send_message(content=content, ephemeral=ephemeral, **kwargs)
            response_used = True
            return await interaction.original_response()
    # Early encounter/combatant lookup for action economy enforcement.
    enc = _d.encounters.get(interaction.channel_id)
    atk_combatant = enc.find(attacker_rec.character.name) if enc else None

    # Condition restrictions (GDD s40): some conditions prevent attacking entirely.
    if atk_combatant is not None:
        wpn_size = combat.get_weapon_profile(weapon).get("size", "Medium")
        blocked, block_reason = condition_effects.cannot_attack(atk_combatant.conditions, wpn_size)
        if blocked:
            await _reply(f"**{atk_combatant.name}** cannot attack: {block_reason}", ephemeral=True)
            return

    # Action economy (s40): attack is a Complex Action - requires full action budget.
    if atk_combatant is not None and atk_combatant.actions_used > 0:
        await _reply(
            f"**{atk_combatant.name}** has already used actions this turn ({atk_combatant.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.",
            ephemeral=True,
        )
        return

    if target_creature_rec is not None and man in ("disarm", "knockdown"):
        await _reply(
            "Disarm/Knockdown aren't supported against creatures yet: Use a plain attack or Feint.",
            ephemeral=True,
        )
        return
    if man == "called_shot" and raises < 1:
        await _reply(
            "Called Shot requires at least 1 raise (1=limb, 2=hand/foot, 3=head, 4=eye/ear/finger).",
            ephemeral=True,
        )
        return
    if man == "extra_attack":
        if atk_combatant and "extra_attack" in atk_combatant.used_this_turn:
            await _reply(
                "Extra Attack can only be used once per Turn.", ephemeral=True
            )
            return
        if atk_combatant:
            atk_combatant.used_this_turn.add("extra_attack")
    maneuver_raises = combat.MANEUVER_RAISES.get(man, 0)

    # Defender technique: extra maneuver raises (Kitsuki Wisdom the Wind Brings, s29.3).
    # Applied before free-raise reductions so mastery/tattoo/technique free raises can offset.
    kitsuki_notes: list[str] = []
    if target_creature_rec is None and target_rec is not None and man in ("feint", "disarm"):
        def_extra, kitsuki_notes = technique_effects.defender_maneuver_tn_increase(target_rec.character, man)
        if def_extra:
            maneuver_raises += def_extra

    # GDD s41: an Unskilled Roll may not benefit from Raises of any kind (called,
    # maneuver or Free), and called Raises (a maneuver's cost counts, after Free
    # Raises) may not exceed the Void Ring. Checked before any Void Point is spent.
    _atk_char = attacker_rec.character
    _atk_profile = combat.get_weapon_profile(weapon)
    _atk_skill = _atk_profile.get("skill", "Kenjutsu")
    if _atk_char.skills.get(_atk_skill, 0) == 0 and (raises or increased_damage or maneuver_raises):
        await _reply(
            f"**{_atk_char.name}** is Unskilled in {_atk_skill}: An Unskilled Roll may not benefit from "
            "Raises of any kind, called, maneuver or Free. Attack without them.",
            ephemeral=True,
        )
        return
    _free = (
        skill_mastery.maneuver_free_raises(_atk_char, _atk_profile, weapon, man)[0]
        + tattoo_effects.maneuver_free_raises(_atk_char, man)[0]
        + technique_effects.maneuver_free_raises(_atk_char, weapon, man, weapon_profile=_atk_profile)[0]
    )
    _man_called = max(0, maneuver_raises - _free)
    _called = raises + increased_damage + _man_called
    if _called > combat.max_raises(_atk_char):
        await _reply(
            f"Too many Raises: **{_called}** called (raises {raises} + increased damage {increased_damage}"
            f" + maneuver {_man_called} after Free Raises) but the maximum per roll is the Void Ring, "
            f"**{combat.max_raises(_atk_char)}**.",
            ephemeral=True,
        )
        return

    # Void Point spend: +1k1 on the attack roll (decrement the pool now).
    void_line = ""
    bonus_rolled = bonus_kept = 0
    if spend_void:
        c = attacker_rec.character
        ok, reason_block = advantage_effects.can_spend_void_on_roll(c)
        if not ok:
            void_line = f" · 🌀 {reason_block}"
        elif c.current_void_points > 0:
            c.current_void_points -= 1
            _d.tally(interaction.channel_id, c.name, "void")
            bonus_rolled = bonus_kept = 1
            _d.store.save(attacker_rec)
            void_line = f" · 🌀 Void +1k1 ({c.current_void_points} VP left)"
        else:
            void_line = " · 🌀 no Void Points to spend"

    # Katana void damage: validate weapon eligibility (VP spent at damage time).
    atk_weapon_profile = combat.get_weapon_profile(weapon)
    if void_damage and not atk_weapon_profile.get("void_damage"):
        await _reply(
            f"**{weapon}** does not support void_damage - only katana can spend VP for +1k1 damage.",
            ephemeral=True,
        )
        return

    # Active-kata combat modifiers (GDD s30; deterministic subset only).
    kata_notes: list[str] = []          # effects auto-applied to this roll
    kata_notes.extend(kitsuki_notes)
    rl_used_notes: list[str] = []       # rate-limited effects already spent this Turn/Round
    attacker = attacker_rec.character
    # Emphasis on this weapon (e.g. Kenjutsu: Katana): reroll 1s once (s04.5 / s24.0).
    atk_emphasis = combat.weapon_emphasis(attacker, weapon)
    if atk_emphasis:
        kata_notes.append(f"Emphasis ({atk_emphasis}): 1s rerolled once")
    atk_init = atk_combatant.initiative if atk_combatant else None
    def_combatant = enc.find(target_rec.character.name) if (enc and target_rec is not None) else None
    def_init = def_combatant.initiative if def_combatant else None

    # Stance resolution: explicit parameter wins; otherwise read from encounter.
    a_stance = a_stance_explicit or (atk_combatant.stance if atk_combatant else "attack")
    d_stance = d_stance_explicit or (def_combatant.stance if def_combatant else "attack")

    # A rate-limited kata is enforced by the tracker (on this roll or its damage
    # step) only while an encounter is tracking the attacker; then suppress its
    # generic reminder. Untracked -> stays a DM-adjudicated reminder.
    rate_limited_handled = atk_combatant is not None and kata_effects.is_rate_limited(attacker.active_kata)

    # Defender's active kata + known Techniques: stance-conditional Armor TN
    # bonus (players only: creatures use fixed stat blocks and carry neither).
    def_kata_bonus = 0
    if target_creature_rec is None:
        def_kata_bonus, def_note = kata_effects.defender_armor_tn_bonus(
            target_rec.character, d_stance
        )
        if def_note:
            kata_notes.append(def_note)
        def_tech_bonus, def_tech_notes = technique_effects.defender_armor_tn_bonus(
            target_rec.character, d_stance, atk_init, def_init, attacker=attacker
        )
        def_kata_bonus += def_tech_bonus
        kata_notes.extend(def_tech_notes)
        def_mastery_bonus, def_mastery_notes = skill_mastery.defender_armor_tn_bonus(target_rec.character)
        def_kata_bonus += def_mastery_bonus
        kata_notes.extend(def_mastery_notes)
        def_adv_mod, def_adv_notes = advantage_effects.defender_armor_tn_mod(target_rec.character)
        def_kata_bonus += def_adv_mod
        kata_notes.extend(def_adv_notes)
        def_kiho_tn, def_kiho_tn_notes = kiho_effects.defender_armor_tn_bonus(target_rec.character)
        def_kata_bonus += def_kiho_tn
        kata_notes.extend(def_kiho_tn_notes)
        def_tattoo_tn, def_tattoo_tn_notes = tattoo_effects.defender_armor_tn_bonus(target_rec.character)
        def_kata_bonus += def_tattoo_tn
        kata_notes.extend(def_tattoo_tn_notes)
    # Attacker's active kata: flat bonus added to the attack-roll total.
    atk_flat, atk_note = kata_effects.attacker_roll_flat_bonus(attacker, man, increased_damage)
    if atk_note:
        kata_notes.append(atk_note)
    # Rate-limited: Striking as Fire adds Fire Ring to one attack roll per Round.
    sf_val, sf_note = kata_effects.striking_as_fire_bonus(attacker, a_stance)
    if sf_val:
        status = _rate_status(atk_combatant, "striking_as_fire", "round")
        if status == "apply":
            atk_flat += sf_val
            kata_notes.append(sf_note)
        elif status == "used":
            rl_used_notes.append("Striking as Fire already used this Round.")
    # Attacker's active kata: a Trait replaced by a Ring on the attack roll.
    trait_ovr, trait_ovr_note = kata_effects.attacker_trait_override(attacker, atk_weapon_profile)
    trait_ovr_name = "Air" if trait_ovr is not None else ""
    if trait_ovr_note:
        kata_notes.append(trait_ovr_note)
    # Rate-limited: Strength in Arms uses Strength (not Agility) once per Turn (Heavy Weapon).
    if trait_ovr is None:
        sia_val, sia_note = kata_effects.strength_in_arms_override(attacker, atk_weapon_profile)
        if sia_val is not None:
            status = _rate_status(atk_combatant, "strength_in_arms", "turn")
            if status == "apply":
                trait_ovr, trait_ovr_name = sia_val, "Strength"
                kata_notes.append(sia_note)
            elif status == "used":
                rl_used_notes.append("Strength in Arms already used this Turn.")
    # Technique trait override (Falcon's Strike: Perception for bow attacks):
    # only if no kata already replaced the attack Trait.
    if trait_ovr is None:
        to_val, to_name, to_note = technique_effects.attacker_trait_override(attacker, atk_weapon_profile)
        if to_val is not None:
            trait_ovr, trait_ovr_name = to_val, to_name
            kata_notes.append(to_note)

    # Attacker's known Techniques: extra attack dice / flat bonus to the roll.
    t_rolled, t_kept, t_flat, t_notes = technique_effects.attacker_attack_dice(
        attacker, atk_weapon_profile, weapon, a_stance, atk_init, def_init,
        defender=target_rec.character if target_rec else None,
        maneuver=man, defender_stance=d_stance,
    )
    bonus_rolled += t_rolled
    bonus_kept += t_kept
    atk_flat += t_flat
    kata_notes.extend(t_notes)

    # Tattoo attack-roll modifiers (Lion: +SR rolled dice with chosen Bugei skill).
    tat_atk_rolled, tat_atk_kept, tat_atk_flat, tat_atk_notes = tattoo_effects.attacker_attack_dice(
        attacker, atk_weapon_profile
    )
    bonus_rolled += tat_atk_rolled
    bonus_kept += tat_atk_kept
    atk_flat += tat_atk_flat
    kata_notes.extend(tat_atk_notes)

    # Advantage/disadvantage attack-roll modifiers (Bad Eyesight, Blind, Touch of Jigoku).
    adv_rolled, adv_kept, adv_flat, adv_notes = advantage_effects.attacker_attack_dice(
        attacker, atk_weapon_profile
    )
    bonus_rolled += adv_rolled
    bonus_kept += adv_kept
    atk_flat += adv_flat
    kata_notes.extend(adv_notes)

    # Advantage wound-penalty modifiers (Strength of the Earth, Low Pain Threshold).
    wp_mod, wp_notes = advantage_effects.attacker_wound_penalty_mod(attacker)
    if wp_mod:
        atk_flat += wp_mod
        kata_notes.extend(wp_notes)

    # Kiho wound-penalty modifier (Grasp the Earth Dragon).
    kiho_wp_mod, kiho_wp_notes = kiho_effects.attacker_wound_penalty_mod(attacker)
    if kiho_wp_mod:
        atk_flat += kiho_wp_mod
        kata_notes.extend(kiho_wp_notes)

    # Tattoo wound-penalty modifier (Mountain).
    tat_wp_mod, tat_wp_notes = tattoo_effects.attacker_wound_penalty_mod(attacker)
    if tat_wp_mod:
        atk_flat += tat_wp_mod
        kata_notes.extend(tat_wp_notes)

    # Technique wound-penalty modifier (Toku's Lesson).
    tech_wp_mod, tech_wp_notes = technique_effects.attacker_wound_penalty_mod(attacker)
    if tech_wp_mod:
        atk_flat += tech_wp_mod
        kata_notes.extend(tech_wp_notes)

    # Condition-based attack modifiers (GDD s40: Blinded, Dazed, Fatigued, Mounted, Prone).
    atk_conds = atk_combatant.conditions if atk_combatant else set()
    cond_rolled, cond_kept, cond_flat, cond_atk_notes = condition_effects.attacker_attack_dice(
        atk_conds, atk_weapon_profile
    )
    bonus_rolled += cond_rolled
    bonus_kept += cond_kept
    atk_flat += cond_flat
    kata_notes.extend(cond_atk_notes)

    # Failed Fear check (GDD s46): -Xk0 to all rolls until the encounter ends.
    if atk_combatant is not None and atk_combatant.fear_penalty:
        bonus_rolled -= atk_combatant.fear_penalty
        kata_notes.append(f"Fear: -{atk_combatant.fear_penalty}k0 (failed Fear check)")

    # Armor attack penalty (s39: Heavy −5, Tetsu-Do −10/−5; Hida R1 exempt).
    armor_pen, armor_note = combat.armor_attack_penalty(attacker)
    if armor_pen:
        atk_flat += armor_pen
        kata_notes.append(armor_note)

    # Off-hand / dual-wield penalties (GDD s40).
    tech_oh_off, tech_oh_dom, tech_oh_notes = technique_effects.off_hand_penalty_removed(
        attacker, atk_weapon_profile, weapon
    )
    if off_hand:
        off_size = atk_weapon_profile.get("size", "Medium")
        off_pen_map = {"Small": -5, "Medium": -10, "Large": -15}
        off_pen = off_pen_map.get(off_size, -10)
        removed, rem_note = skill_mastery.off_hand_penalty_removed(attacker, atk_weapon_profile)
        if tech_oh_off:
            kata_notes.extend(tech_oh_notes)
        elif removed:
            kata_notes.append(rem_note)
        else:
            atk_flat += off_pen
            kata_notes.append(f"Off-hand penalty ({off_size}): {off_pen}")
    elif attacker.off_hand_weapon:
        if tech_oh_dom:
            kata_notes.extend(tech_oh_notes)
        else:
            atk_flat -= 5
            kata_notes.append("Dominant-hand penalty (dual-wielding): −5")

    # Weapon stance penalty (s39: bows/lance mounted/foot restrictions).
    stance_pen, stance_pen_note = combat.weapon_stance_penalty(weapon, "mounted" in atk_conds)
    if stance_pen:
        atk_flat += stance_pen
        kata_notes.append(stance_pen_note)

    # Extraordinary weapon quality: Balanced (+1k0 attack, s39 crafting).
    if combat.has_weapon_quality(attacker, weapon, "balanced"):
        bonus_rolled += 1
        kata_notes.append("Balanced: +1k0 attack")

    # Defender condition modifiers (Prone -10 Armor TN vs melee).
    # Kept separate from def_kata_bonus so it applies even when an override fires.
    def_conds = def_combatant.conditions if def_combatant else set()
    is_melee_attack = atk_weapon_profile.get("melee", True)
    cond_def_mod, cond_def_notes = condition_effects.defender_armor_tn_mod(def_conds, is_melee_attack)
    kata_notes.extend(cond_def_notes)

    # Skill mastery: free raises that reduce a maneuver's raise cost (s24).
    mastery_free, mastery_free_notes = skill_mastery.maneuver_free_raises(
        attacker, atk_weapon_profile, weapon, man
    )
    if mastery_free:
        maneuver_raises = max(0, maneuver_raises - mastery_free)
        kata_notes.extend(mastery_free_notes)

    # Tattoo: Storm free raise for Knockdown (s57.25).
    tat_free, tat_free_notes = tattoo_effects.maneuver_free_raises(attacker, man)
    if tat_free:
        maneuver_raises = max(0, maneuver_raises - tat_free)
        kata_notes.extend(tat_free_notes)

    # Technique: Kikage Zumi R4 Knockdown discount (s29.3).
    tech_free, tech_free_notes = technique_effects.maneuver_free_raises(attacker, weapon, man, weapon_profile=atk_weapon_profile)
    if tech_free:
        maneuver_raises = max(0, maneuver_raises - tech_free)
        kata_notes.extend(tech_free_notes)

    # Guard maneuver TN modifiers (s40): guarded target gets +10 per guarder, guarder gets -5.
    guard_mod = 0
    if enc and target_rec is not None:
        def_name_lower = target_rec.character.name.lower()
        for gc in enc.combatants:
            if gc.guarding.lower() == def_name_lower:
                guard_mod += 10
                kata_notes.append(f"Guarded by {gc.name}: +10 Armor TN")
        if def_combatant and def_combatant.guarding:
            guard_mod -= 5
            kata_notes.append(f"Guarding {def_combatant.guarding}: −5 Armor TN")

    # Full Defense bonus (s40): half of Defense/Reflexes roll, set by /fight full_defense.
    fd_bonus = 0
    if def_combatant and def_combatant.full_defense_bonus:
        fd_bonus = def_combatant.full_defense_bonus
        kata_notes.append(f"Full Defense: +{fd_bonus} Armor TN")

    # Void Point Armor TN bonus (s25): +10 for one Round.
    void_tn_bonus = 0
    if def_combatant and def_combatant.void_armor_tn_bonus:
        void_tn_bonus = def_combatant.void_armor_tn_bonus
        kata_notes.append(f"Void Armor: +{void_tn_bonus} Armor TN")

    # Cover/terrain bonus: DM-set persistent Armor TN modifier.
    cover_mod = 0
    if def_combatant and def_combatant.cover_bonus:
        cover_mod = def_combatant.cover_bonus
        kata_notes.append(f"Cover: {'+' if cover_mod > 0 else ''}{cover_mod} Armor TN")

    # Dual-wield Armor TN bonus (s40): defender wielding two weapons adds Insight Rank.
    dw_def_bonus = 0
    if target_creature_rec is None and target_rec is not None:
        def_char = target_rec.character
        if def_char.equipped_weapon and def_char.off_hand_weapon:
            dw_def_bonus = stats.insight_rank(def_char)
            if dw_def_bonus:
                kata_notes.append(f"Dual-wield defense: +{dw_def_bonus} Armor TN (Insight Rank)")

    # Arrow/blowgun Armor TN specials (GDD s39): modify the armor TN bonus contribution.
    arrow_tn_adj = 0
    if target_creature_rec is None:
        arrow_tn_adj, arrow_tn_note = combat.arrow_armor_tn_mod(weapon, target_rec.character.armor_tn_bonus)
        if arrow_tn_note:
            kata_notes.append(arrow_tn_note)
    if atk_weapon_profile.get("half_range"):
        kata_notes.append("⚠️ Half range - verify target is within halved bow range")

    # Staff vs armor (L5R 4e Equipment): armor TN bonus doubled against staves.
    staff_tn_adj = 0
    if target_creature_rec is None:
        staff_tn_adj, staff_tn_note = combat.staff_armor_tn_mod(
            attacker, weapon, target_rec.character.armor_tn_bonus
        )
        if staff_tn_note:
            kata_notes.append(staff_tn_note)

    # Target name + Armor TN depend on the target kind.
    if target_creature_rec is not None:
        t_name = target_creature_rec.creature.name
        tn = target_creature_rec.creature.armor_tn + bonus_tn + cover_mod
    else:
        t_name = target_rec.character.name
        # Condition Armor TN override (Stunned/Grappled/Blinded replace the formula).
        # Overrides ignore stance and kata/technique bonuses (GDD: "5 + armor bonuses").
        # Condition modifiers (Prone -10) still stack on top.
        cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
            def_conds, target_rec.character.reflexes, target_rec.character.armor_tn_bonus,
            is_melee_attack,
        )
        if cond_tn_ovr is not None:
            tn = cond_tn_ovr + cond_def_mod + guard_mod + fd_bonus + void_tn_bonus + cover_mod + bonus_tn + arrow_tn_adj + staff_tn_adj + dw_def_bonus
            kata_notes.extend(cond_tn_notes)
        else:
            tn = combat.armor_tn(target_rec.character, d_stance, bonus_tn + def_kata_bonus + cond_def_mod + guard_mod + fd_bonus + void_tn_bonus + cover_mod + arrow_tn_adj + staff_tn_adj + dw_def_bonus)

    # Declared technique effects: auto-apply bonuses from techniques the player
    # activated via the combat board Techniques button.
    decl_ignore_wound = False
    decl_reduction_ignore = 0
    decl_target_red_penalty = 0
    decl_on_hit_condition = ""
    decl_ignore_stance_atn = False
    if atk_combatant and atk_combatant.declared_techniques:
        for tkey, tentry in list(atk_combatant.declared_techniques.items()):
            if tentry.get("manual"):
                continue
            efx = tentry.get("effects", {})
            if not efx:
                continue
            t_display = tentry.get("display", tkey)
            parts: list[str] = []
            if efx.get("atk_rolled"):
                bonus_rolled += efx["atk_rolled"]
                parts.append(f"+{efx['atk_rolled']}k0 atk")
            if efx.get("atk_kept"):
                bonus_kept += efx["atk_kept"]
                parts.append(f"+0k{efx['atk_kept']} atk")
            if efx.get("atk_flat"):
                atk_flat += efx["atk_flat"]
                parts.append(f"+{efx['atk_flat']} atk flat")
            if efx.get("dmg_rolled"):
                parts.append(f"+{efx['dmg_rolled']}k0 dmg")
            if efx.get("dmg_kept"):
                parts.append(f"+0k{efx['dmg_kept']} dmg")
            if efx.get("dmg_flat"):
                parts.append(f"+{efx['dmg_flat']} dmg flat")
            if efx.get("dmg_explode"):
                parts.append("dmg dice explode")
            if efx.get("reduction_ignore"):
                decl_reduction_ignore += efx["reduction_ignore"]
                val = efx["reduction_ignore"]
                parts.append("ignore all Reduction" if val >= 999 else f"ignore {val} Reduction")
            if efx.get("target_reduction_penalty"):
                decl_target_red_penalty += efx["target_reduction_penalty"]
                parts.append(f"target Reduction -{efx['target_reduction_penalty']}")
            if efx.get("on_hit_condition"):
                decl_on_hit_condition = efx["on_hit_condition"]
                parts.append(f"inflict {efx['on_hit_condition']}")
            if efx.get("ignore_wound_penalties"):
                decl_ignore_wound = True
                parts.append("ignore wound penalties")
            if efx.get("atn_bonus"):
                def_kata_bonus += efx["atn_bonus"]
                parts.append(f"+{efx['atn_bonus']} ATN")
            if efx.get("reduction_bonus"):
                parts.append(f"+{efx['reduction_bonus']} Reduction")
            if efx.get("ignore_target_stance_atn"):
                decl_ignore_stance_atn = True
                parts.append("ignore target stance ATN")
            if parts:
                kata_notes.append(f"{t_display}: {', '.join(parts)}")
            dur = tentry.get("duration", "attack")
            if dur in ("instant", "attack"):
                del atk_combatant.declared_techniques[tkey]
    if decl_ignore_wound:
        base_wp = stats.wound_penalty(attacker)
        if base_wp:
            atk_flat -= base_wp
            kata_notes.append(f"Wound penalties ignored (technique): negated {base_wp:+d}")
    if decl_ignore_stance_atn and target_creature_rec is None and target_rec is not None:
        stance_atn_adj = 0
        d_char = target_rec.character
        if d_stance == "full_attack":
            stance_atn_adj = 10
        elif d_stance == "defense":
            stance_atn_adj = -(stats.ring_value(d_char, "air") + d_char.skills.get("Defense", 0))
        if stance_atn_adj:
            tn += stance_atn_adj
            kata_notes.append(f"Target stance ATN ignored (technique): {stance_atn_adj:+d}")

    # Center Stance bonus (s40): +1k1 + Void Ring on one roll, from centering last Round.
    center_line = ""
    if atk_combatant and atk_combatant.center_bonus_available:
        void_ring_val = attacker.void_ring if attacker else 0
        bonus_rolled += 1
        bonus_kept += 1
        atk_flat += void_ring_val
        atk_combatant.center_bonus_available = False
        center_line = f" · 🎯 Center: +1k1 +{void_ring_val} flat (Void Ring)"
        kata_notes.append(f"Center Stance: +1k1 + {void_ring_val} (Void Ring)")

    # Defense Stance warning (s40): may not attack while in Defense.
    if a_stance == "defense":
        kata_notes.append("⚠️ Defense Stance: May not attack (DM override in effect)")

    outcome = combat.resolve_attack(
        attacker, weapon, tn, raises + maneuver_raises, _d.engine,
        attacker_stance=a_stance, increased_damage=increased_damage,
        bonus_rolled=bonus_rolled, bonus_kept=bonus_kept, extra_flat=atk_flat,
        emphasis=bool(atk_emphasis),
        trait_override=trait_ovr, trait_override_name=trait_ovr_name,
    )

    a_name = attacker_rec.character.name
    hit = outcome["hit"]
    embed = discord.Embed(
        title=f"⚔️ {a_name} attacks {t_name}",
        color=discord.Color.green() if hit else discord.Color.greyple(),
    )
    atk_desc = (
        f"{outcome['skill_name']} {outcome['skill_rank']} / "
        f"{outcome['trait_name'].capitalize()} with **{weapon.replace('_', ' ').title()}**"
    )
    if mat != "normal":
        atk_desc += f"  ·  🔶 {mat.title()}"
    if a_stance != "attack":
        auto_tag = " *(enc)*" if (not a_stance_explicit and atk_combatant) else ""
        atk_desc += f"  ·  {a_stance.replace('_', ' ').title()}{auto_tag}"
    if man != "none":
        atk_desc += f"  ·  Maneuver: {man.title()}"
    atk_desc += void_line
    embed.add_field(name="Attacker", value=atk_desc[:1024], inline=False)
    embed.add_field(name="Attack roll", value=_d.format_dice(outcome["dice"])[:1024], inline=False)

    tn_note = f"Armor TN **{outcome['target_tn']}**"
    if outcome["raises"]:
        tn_note += f" ({outcome['raises']} raises)"
    if target_creature_rec is None and d_stance != "attack":
        auto_tag = " *(enc)*" if (not d_stance_explicit and def_combatant) else ""
        tn_note += f"  ·  {d_stance.replace('_', ' ').title()}{auto_tag}"
    verdict = "✅ **HIT**" if hit else "❌ **MISS**"
    embed.add_field(
        name="Result",
        value=f"Total **{outcome['roll']}** vs {tn_note}: {verdict} (margin {outcome['margin']:+d})",
        inline=False,
    )
    if outcome["unskilled"]:
        embed.set_footer(text=f"Unskilled in {outcome['skill_name']}: Dice did not explode.")

    if kata_notes:
        embed.add_field(name="⚑ Combat effects (auto-applied)", value=" · ".join(kata_notes)[:1024], inline=False)
    if rl_used_notes:
        embed.add_field(name="Rate-limited (already spent)", value="\n".join(rl_used_notes)[:1024], inline=False)
    reminders = _active_ability_reminders(attacker, "attacker", drop_rate_limited=rate_limited_handled)
    if target_creature_rec is None:
        reminders += _active_ability_reminders(target_rec.character, "defender")
    if target_creature_rec is not None:
        reminders += creature.creature_special_notes(target_creature_rec.creature)
    cond_reminders = condition_effects.condition_reminders(atk_conds)
    if def_conds:
        cond_reminders += condition_effects.condition_reminders(def_conds)
    reminders += cond_reminders
    if reminders:
        embed.add_field(
            name="Active abilities: DM adjudicates",
            value="\n".join(reminders)[:1024],
            inline=False,
        )

    if atk_combatant is not None:
        atk_combatant.actions_used = 2
    if enc and atk_combatant is not None:
        _d.save_encounter(guild, enc)

    cs_raises = raises if man == "called_shot" else 0
    if hit:
        approval_ch_id = _d.store.get_damage_approval_channel(guild) or _d.store.get_approval_channel(guild)
        approval_ch = _d.bot_client.get_channel(int(approval_ch_id)) if approval_ch_id else None
        src_ch_id = interaction.channel_id if approval_ch else 0
        if target_creature_rec is not None:
            view = DamageView(
                attacker_rec.id, None, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"],
                target_creature_id=target_creature_rec.id, defender_stance=d_stance,
                called_shot_raises=cs_raises, channel_id=interaction.channel_id,
                source_channel_id=src_ch_id, weapon_material=mat,
                void_damage=void_damage,
                attacker_stance=a_stance, atk_init=atk_init, def_init=def_init,
            )
        else:
            view = DamageView(
                attacker_rec.id, target_rec.id, weapon, increased_damage, a_name, t_name,
                maneuver=man, attack_margin=outcome["margin"], defender_stance=d_stance,
                called_shot_raises=cs_raises, channel_id=interaction.channel_id,
                source_channel_id=src_ch_id, weapon_material=mat,
                void_damage=void_damage,
                attacker_stance=a_stance, atk_init=atk_init, def_init=def_init,
            )
        prompt = {
            "disarm": "A DM can resolve the disarm below.",
            "knockdown": "A DM can resolve the knockdown below.",
        }.get(man, "A DM can authorize the damage below.")
        target_owner_id = target_rec.owner_id if target_rec is not None else None
        owner_ping = f" <@{target_owner_id}>" if target_owner_id and target_owner_id != _d.NPC_OWNER else ""
        if approval_ch:
            await _reply(
                content=f"⚔️ **{a_name}** hit **{t_name}** - damage approval pending in the DM channel.{owner_ping}",
                embed=embed,
            )
            embed.add_field(name="Requested by", value=interaction.user.mention, inline=True)
            embed.add_field(name="Room", value=f"<#{interaction.channel_id}>", inline=True)
            await view.persist(await approval_ch.send(content=f"{_d.dm_ping(interaction.guild)}{prompt}", embed=embed, view=view, allowed_mentions=_PING_MENTIONS))
        else:
            msg = await _reply(content=f"{_d.dm_ping(interaction.guild)}{prompt}{owner_ping}", embed=embed, view=view, allowed_mentions=_PING_MENTIONS)
            await view.persist(msg)
        await _d.combat_log(guild, f"Attack: {a_name} → {t_name} ({weapon}) HIT (roll {outcome['roll']} vs TN {outcome['target_tn']})")
        _d.tally(interaction.channel_id, a_name, "attacks"); _d.tally(interaction.channel_id, a_name, "hits")
    else:
        await _reply(embed=embed)
        await _d.combat_log(guild, f"Attack: {a_name} → {t_name} ({weapon}) MISS (roll {outcome['roll']} vs TN {outcome['target_tn']})")
        _d.tally(interaction.channel_id, a_name, "attacks")

def _render_encounter(enc: encounter.Encounter, guild_id: str = "") -> str:
    if not enc.combatants:
        return "No combatants yet. Add them with `/combat join` or `/combat add`."
    cur = enc.current()
    lines = []
    for i, c in enumerate(enc.combatants):
        marker = "▶️ " if (enc.started and c is cur) else f"{i + 1}. "
        tag = " *(NPC)*" if c.is_npc else ""
        wound_tag = ""
        spell_tag = ""
        if guild_id:
            rec = _d.resolve_combatant_record(guild_id, c)
            if rec is not None:
                pen = stats.wound_penalty(rec.character)
                if pen:
                    lvl = stats.wound_level_name(rec.character)
                    wound_tag = f"  ⚠️{lvl}({pen})"
                ch_rec = rec.character
                if ch_rec.spell_slots:
                    parts: list[str] = []
                    for el in _CAST_ELEMENTS:
                        sl = ch_rec.spell_slots.get(el)
                        if sl is not None:
                            mx = stats.spell_slot_max(ch_rec, el)
                            parts.append(f"{el[0].upper()}{sl}/{mx}")
                    if parts:
                        bonus = f"+{ch_rec.void_spell_bonus}V" if ch_rec.void_spell_bonus else ""
                        spell_tag = f"  **S**: {' '.join(parts)}{bonus}"
        detail = f"  ·  {c.initiative_detail}" if c.initiative_detail else ""
        stance_str = f"  ⚔️{c.stance.replace('_', ' ').title()}" if c.stance != "attack" else ""
        acts = f"  [{c.actions_used}/2 acts]" if enc.started and c.actions_used > 0 else ""
        cond_labels = [
            f"{k}({c.rounds_left(k, enc.round)}r)" if k in c.condition_expiry else k for k in sorted(c.conditions)
        ]
        cond = f"  [{', '.join(cond_labels)}]" if c.conditions else ""
        guard = f"  🛡️→{c.guarding}" if c.guarding else ""
        fd = f"  🛡️FD+{c.full_defense_bonus}" if c.full_defense_bonus else ""
        void_atn = f"  🌀ATN+{c.void_armor_tn_bonus}" if c.void_armor_tn_bonus else ""
        void_init = f"  🌀Init+{c.void_initiative_boost}" if c.void_initiative_boost else ""
        center_tag = "  🎯Center+1k1" if c.center_bonus_available else ""
        center_init = f"  🎯Init+{c.center_init_boost}" if c.center_init_boost else ""
        held = "  ⏸️HELD" if c.held else ""
        delayed = "  ⏳DELAYED" if c.delayed else ""
        cover = f"  🪨Cover{'+' if c.cover_bonus > 0 else ''}{c.cover_bonus}" if c.cover_bonus else ""
        fear = f"  😨-{c.fear_penalty}k0" if c.fear_penalty else ""
        techs = ""
        if c.declared_techniques:
            tech_names = [e.get("display", k) for k, e in c.declared_techniques.items()]
            techs = "  **T**: " + ", ".join(tech_names)
        init_val = c.effective_initiative
        lines.append(f"{marker}**{c.name}**{tag}{wound_tag}: Init **{init_val}**{detail}{stance_str}{acts}{cond}{guard}{fd}{void_atn}{void_init}{center_tag}{center_init}{cover}{fear}{held}{delayed}{techs}{spell_tag}")
    header = f"⚔️ **Round {enc.round}**"
    if enc.surprise_round:
        header += " *(Surprise)*"
    if not enc.started:
        header = "⚔️ **Not started**: Use `/combat next` to begin."
        if enc.surprise_round:
            header += " *(Surprise Round)*"
    notes_line = f"\n📍 *{enc.notes}*" if enc.notes else ""
    result = header + notes_line + "\n" + "\n".join(lines)
    if len(result) > 1700:
        result = result[:1700] + "\n*(truncated - use `/combat summary` for full view)*"
    return result
@combat_group.command(name="start", description="Start a fresh initiative tracker in this channel.")
async def combat_start(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    existing = _d.encounters.get(interaction.channel_id)
    if existing is not None and (existing.started or existing.combatants or existing.roster) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            "A fight is already set up in this channel. Only staff can restart it (`/combat end` first).", ephemeral=True,
        )
        return
    enc = encounter.Encounter(channel_id=interaction.channel_id)
    _d.encounters[interaction.channel_id] = enc
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title="⚔️ New Encounter Started",
        color=discord.Color.red(),
        description=(
            "Add combatants with `/combat join` (your character) "
            "or `/combat add` (an NPC), then `/combat next` to begin.\n"
            "Players end their turn with `/combat turn done`.\n"
            "*(For an invite-and-accept roster use `/combat setup` instead.)*"
        ),
    )
    embed.set_footer(text=f"Started by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(guild, "--- Encounter started ---")


def _get_or_create(channel_id: int) -> encounter.Encounter:
    enc = _d.encounters.get(channel_id)
    if enc is None:
        enc = encounter.Encounter(channel_id=channel_id)
        _d.encounters[channel_id] = enc
    return enc


@combat_group.command(name="join", description="Add a character to initiative (rolls initiative).")
@app_commands.describe(member="Add another player's active character [Fortune]. Omit for your own.")
async def combat_join(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not await _d.require_dm_role(interaction):
            return
        owner = member
    else:
        owner = interaction.user
    rec = _d.store.get_active(guild, str(owner.id))
    if rec is None:
        who = "You have" if owner.id == interaction.user.id else f"{owner.display_name} has"
        await interaction.response.send_message(f"{who} no active character. Use `/sheet create` first.", ephemeral=True)
        return
    if await _d.refuse_if_cannot_act(interaction, rec.character):
        return
    enc = _d.encounters.get(interaction.channel_id)
    if enc is not None and enc.find(rec.character.name) is not None and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"**{rec.character.name}** is already in initiative. Re-rolling initiative is a staff call "
            f"(`/combat join member:` by {_d.ROLE_FORTUNE}).", ephemeral=True,
        )
        return
    if enc is not None and enc.roster and not _d.is_dm(interaction) and not enc.roster_allows(str(owner.id)):
        status = enc.roster.get(str(owner.id))
        why = "declined the roster (press **Join** on it to change your mind)" if status == "declined" else \
              "have not accepted the roster yet (press **Join** on it)" if status == "pending" else \
              "are not on this encounter's roster: Ask the organizer or staff to add you"
        await interaction.response.send_message(f"You {why}.", ephemeral=True)
        return

    enc, init_total = _join_record(guild, interaction.channel_id, str(owner.id), rec)
    await interaction.response.send_message(_render_encounter(enc, guild))
    await _d.combat_log(guild, f"Joined: {rec.character.name} (Init {init_total})")
    await _refresh_board(enc, guild)


def _join_record(guild: str, channel_id: int, owner_id: str, rec: _storage_mod.CharacterRecord) -> tuple[encounter.Encounter, int]:
    """Roll initiative for a stored character and place it in the channel's
    encounter (re-joining re-rolls). Returns (encounter, initiative total)."""
    idr, idk, idn = technique_effects.initiative_dice_bonus(rec.character)
    result = combat.roll_initiative(rec.character, _d.engine, idr, idk)
    swift_bonus = 5 if "swift" in rec.character.weapon_qualities else 0
    tech_init, tech_init_notes = technique_effects.initiative_bonus(rec.character)
    init_total = result.total + swift_bonus + tech_init
    swift_detail = f" +5 Swift" if swift_bonus else ""
    tech_init_detail = "".join(f" +{n}" for n in tech_init_notes)
    dice_detail = "".join(f" [{n}]" for n in idn)
    enc = _get_or_create(channel_id)
    enc.remove(rec.character.name)  # re-join re-rolls
    enc.add(encounter.Combatant(
        name=rec.character.name,
        initiative=init_total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}{swift_detail}{tech_init_detail}{dice_detail}",
        owner_id=owner_id,
        is_npc=False,
        reflexes=rec.character.reflexes,
    ))
    enc.note_join(rec.character.name, stats.wound_level_name(rec.character))
    _d.save_encounter(guild, enc)
    return enc, init_total


# ---------------------------------------------------------------------------
# Encounter roster (/combat setup): who is in the fight, by consent or by staff
# ---------------------------------------------------------------------------

_ROSTER_ICON = {"pending": "⏳", "accepted": "✅", "declined": "❌", "forced": "🔒"}


def _render_roster(enc: encounter.Encounter) -> str:
    counts = {k: 0 for k in _ROSTER_ICON}
    lines = []
    for uid, status in enc.roster.items():
        counts[status] = counts.get(status, 0) + 1
        in_init = any(c.owner_id == uid for c in enc.combatants)
        lines.append(f"{_ROSTER_ICON.get(status, '❔')} <@{uid}> - {status}{' · in initiative' if in_init else ''}")
    head = f"🛡️ **Encounter roster** (organizer: <@{enc.organizer_id}>)"
    tally = f"✅ {counts['accepted']}  ⏳ {counts['pending']}  ❌ {counts['declined']}  🔒 {counts['forced']}"
    if enc.roster_begun:
        tail = "Begun: Accepted players are in initiative. Late **Join** rolls you in at once."
    else:
        tail = ("Invited players: Press **Join** or **Decline**. Staff: **Force** requires everyone in. "
                "Organizer/staff: **Begin** rolls initiative for all who are in.")
    return "\n".join([head, *lines, "", tally, tail])


class RosterView(views_base.PersistentView):
    """Join / Decline / Force / Begin buttons under an encounter roster message."""

    KIND = "encounter_roster"

    def __init__(self, guild_id: str, channel_id: int) -> None:
        super().__init__()
        self.guild_id = guild_id
        self.channel_id = channel_id
        enc = _d.encounters.get(channel_id) if hasattr(_d, "encounters") else None
        if enc is not None and enc.roster_begun:
            self.begin.disabled = True

    async def _enc(self, interaction: discord.Interaction) -> encounter.Encounter | None:
        enc = _d.encounters.get(self.channel_id)
        if enc is None or not enc.roster:
            self._disable()
            try:
                await interaction.response.edit_message(
                    content=(interaction.message.content if interaction.message else "") + "\n*(This roster is closed.)*",
                    view=self, allowed_mentions=discord.AllowedMentions.none(),
                )
            except discord.HTTPException:
                pass
            return None
        return enc

    async def _refresh(self, interaction: discord.Interaction, enc: encounter.Encounter, extra: str = "") -> None:
        _d.save_encounter(self.guild_id, enc)
        if enc.roster_begun:
            self.begin.disabled = True
        await interaction.response.edit_message(
            content=_render_roster(enc), view=self, allowed_mentions=discord.AllowedMentions.none(),
        )
        if extra:
            await interaction.followup.send(extra, allowed_mentions=discord.AllowedMentions.none())

    async def _roll_in(self, interaction: discord.Interaction, enc: encounter.Encounter, user_ids: list[str]) -> list[str]:
        """Roll initiative for these rostered users' active characters. Returns note lines."""
        notes: list[str] = []
        for uid in user_ids:
            if any(c.owner_id == uid for c in enc.combatants):
                continue
            rec = _d.store.get_active(self.guild_id, uid)
            if rec is None:
                notes.append(f"<@{uid}>: No active character (`/sheet create`), not added")
                continue
            if stats.is_dead(rec.character) or stats.wound_level_name(rec.character) == "Out":
                notes.append(f"<@{uid}>: **{rec.character.name}** cannot act ({stats.wound_level_name(rec.character)}), not added")
                continue
            _, total = _join_record(self.guild_id, self.channel_id, uid, rec)
            notes.append(f"**{rec.character.name}**: Init {total}")
            await _d.combat_log(self.guild_id, f"Joined: {rec.character.name} (Init {total})")
        return notes

    @discord.ui.button(label="Join", style=discord.ButtonStyle.success, emoji="✅")
    async def join(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = await self._enc(interaction)
        if enc is None:
            return
        uid = str(interaction.user.id)
        if uid not in enc.roster:
            await interaction.response.send_message(
                "You are not on this roster. Ask the organizer to set it up again with you, or staff to add you with `/combat join`.",
                ephemeral=True,
            )
            return
        if enc.roster[uid] != "forced":
            enc.roster[uid] = "accepted"
        extra = ""
        if enc.roster_begun:
            notes = await self._roll_in(interaction, enc, [uid])
            extra = "\n".join(notes) + "\n" + _render_encounter(enc, self.guild_id) if notes else ""
        await self._refresh(interaction, enc, extra)
        if enc.roster_begun:
            await _refresh_board(enc, self.guild_id)

    @discord.ui.button(label="Decline", style=discord.ButtonStyle.secondary, emoji="❌")
    async def decline(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = await self._enc(interaction)
        if enc is None:
            return
        uid = str(interaction.user.id)
        if uid not in enc.roster:
            await interaction.response.send_message("You are not on this roster; nothing to decline.", ephemeral=True)
            return
        if enc.roster[uid] == "forced":
            await interaction.response.send_message("Staff have required you to join this encounter.", ephemeral=True)
            return
        if any(c.owner_id == uid for c in enc.combatants):
            await interaction.response.send_message(
                "You are already in initiative. Staff can remove you with `/combat remove`.", ephemeral=True,
            )
            return
        enc.roster[uid] = "declined"
        await self._refresh(interaction, enc)

    @discord.ui.button(label="Force (staff)", style=discord.ButtonStyle.danger, emoji="🔒")
    async def force(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(
                f"Only **{_d.ROLE_FORTUNE}** / **{_d.ROLE_KAMI}** can force players into an encounter.", ephemeral=True,
            )
            return
        enc = await self._enc(interaction)
        if enc is None:
            return
        forced = [uid for uid, st in enc.roster.items() if st in ("pending", "declined")]
        for uid in forced:
            enc.roster[uid] = "forced"
        extra = ""
        if forced and enc.roster_begun:
            notes = await self._roll_in(interaction, enc, forced)
            extra = "\n".join(notes) + "\n" + _render_encounter(enc, self.guild_id) if notes else ""
        await self._refresh(interaction, enc, extra)
        if forced:
            await _d.combat_log(self.guild_id, f"Roster: {interaction.user.display_name} forced {len(forced)} player(s) in")
            if enc.roster_begun:
                await _refresh_board(enc, self.guild_id)

    @discord.ui.button(label="Begin", style=discord.ButtonStyle.primary, emoji="⚔️")
    async def begin(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        enc = await self._enc(interaction)
        if enc is None:
            return
        if str(interaction.user.id) != enc.organizer_id and not _d.is_dm(interaction):
            await interaction.response.send_message("Only the organizer or staff can begin the encounter.", ephemeral=True)
            return
        if enc.roster_begun:
            await interaction.response.send_message("Already begun. Late players use **Join**.", ephemeral=True)
            return
        ready = [uid for uid, st in enc.roster.items() if st in encounter.ROSTER_IN]
        if not ready:
            await interaction.response.send_message("Nobody has accepted yet.", ephemeral=True)
            return
        enc.roster_begun = True
        notes = await self._roll_in(interaction, enc, ready)
        pending = sum(1 for st in enc.roster.values() if st == "pending")
        tail = f"\n⏳ {pending} invited player(s) have not answered; they can still press **Join**." if pending else ""
        extra = ("\n".join(notes) + "\n" + _render_encounter(enc, self.guild_id)
                 + "\nStaff: Add NPCs with `/combat add`, `/combat npc` or `/combat creature`, then `/combat next`." + tail)
        await self._refresh(interaction, enc, extra)
        await _d.combat_log(self.guild_id, f"Roster begun by {interaction.user.display_name}: {len(notes)} rolled")
        await _refresh_board(enc, self.guild_id)


class _RosterPickView(discord.ui.View):
    """Ephemeral member picker shown by /combat setup."""

    def __init__(self, organizer: discord.Member, members: list[discord.Member]) -> None:
        super().__init__(timeout=600)
        self.organizer = organizer
        self._member_map: dict[str, discord.Member] = {str(m.id): m for m in members}
        options = [
            discord.SelectOption(label=m.display_name, value=str(m.id))
            for m in members
        ][:25]
        select = discord.ui.Select(
            placeholder="Who is in this encounter?",
            min_values=1, max_values=min(len(options), 25),
            options=options,
        )
        select.callback = self._pick
        self.add_item(select)

    async def _pick(self, interaction: discord.Interaction) -> None:
        if interaction.user.id != self.organizer.id:
            await interaction.response.send_message("Only the organizer can pick the roster.", ephemeral=True)
            return
        guild = str(interaction.guild_id)
        existing = _d.encounters.get(interaction.channel_id)
        if existing is not None and existing.started:
            await interaction.response.send_message("A fight is already running here. `/combat end` it first.", ephemeral=True)
            return
        enc = encounter.Encounter(channel_id=interaction.channel_id)
        enc.organizer_id = str(self.organizer.id)
        select: discord.ui.Select = self.children[0]  # type: ignore[assignment]
        for uid in select.values:
            member = self._member_map.get(uid)
            if member is None:
                continue
            enc.roster[uid] = "accepted" if member.id == self.organizer.id else "pending"
        if not enc.roster:
            await interaction.response.send_message(
                "Pick at least one player.", ephemeral=True,
            )
            return
        _d.encounters[interaction.channel_id] = enc
        _d.save_encounter(guild, enc)
        self.stop()
        await interaction.response.edit_message(content="Roster posted below.", view=None)
        view = RosterView(guild, interaction.channel_id)
        msg = await interaction.followup.send(
            _render_roster(enc), view=view, wait=True,
            allowed_mentions=discord.AllowedMentions(users=True),
        )
        await view.persist(msg)
        enc.roster_message_id = msg.id
        _d.save_encounter(guild, enc)
        await _d.combat_log(guild, f"--- Encounter roster set up by {self.organizer.display_name} ({len(enc.roster)} invited) ---")


async def _fetch_roster_message(enc: encounter.Encounter) -> discord.Message | None:
    """The roster message for this encounter, if it can still be fetched."""
    if not enc.roster_message_id:
        return None
    channel = _d.bot_client.get_channel(enc.channel_id)
    if channel is None:
        return None
    try:
        return await channel.fetch_message(enc.roster_message_id)
    except (discord.HTTPException, AttributeError):
        return None


async def _refresh_roster_message(enc: encounter.Encounter) -> None:
    msg = await _fetch_roster_message(enc)
    if msg is not None:
        try:
            await msg.edit(content=_render_roster(enc), allowed_mentions=discord.AllowedMentions.none())
        except discord.HTTPException:
            pass


async def _close_roster_message(enc: encounter.Encounter, guild: str, note: str = "Roster closed.") -> None:
    """Disable the roster message's buttons and drop its persisted view."""
    if not enc.roster or not enc.roster_message_id:
        return
    msg = await _fetch_roster_message(enc)
    view = RosterView(guild, enc.channel_id)
    view._persist_message_id = enc.roster_message_id
    view._disable()   # also forgets the pending-view row
    if msg is None:
        return
    try:
        await msg.edit(content=_render_roster(enc) + f"\n*({note})*", view=view,
                       allowed_mentions=discord.AllowedMentions.none())
    except discord.HTTPException:
        pass


async def _require_roster(interaction: discord.Interaction) -> encounter.Encounter | None:
    """The channel's rostered encounter if the user is its organizer or staff; else an error."""
    enc = _d.encounters.get(interaction.channel_id)
    if enc is None or not enc.roster:
        await interaction.response.send_message("No encounter roster here. Start one with `/combat setup`.", ephemeral=True)
        return None
    if str(interaction.user.id) != enc.organizer_id and not _d.is_dm(interaction):
        await interaction.response.send_message("Only the roster's organizer or staff can do that.", ephemeral=True)
        return None
    return enc


combat_roster = app_commands.Group(name="roster", description="Manage an encounter roster (organizer or staff).", parent=combat_group)


@combat_roster.command(name="add", description="Invite another player to this channel's encounter roster.")
@app_commands.describe(member="The player to invite (they still press Join).")
async def combat_roster_add(interaction: discord.Interaction, member: discord.Member) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _require_roster(interaction)
    if enc is None:
        return
    if member.bot:
        await interaction.response.send_message("Bots do not fight.", ephemeral=True)
        return
    perms = interaction.channel.permissions_for(member)
    if not perms.read_messages:
        await interaction.response.send_message(
            f"{member.display_name} does not have access to this channel.", ephemeral=True,
        )
        return
    uid = str(member.id)
    if enc.roster.get(uid) in encounter.ROSTER_IN:
        await interaction.response.send_message(f"{member.display_name} is already in.", ephemeral=True)
        return
    enc.roster[uid] = "pending"
    _d.save_encounter(str(interaction.guild_id), enc)
    await _refresh_roster_message(enc)
    await interaction.response.send_message(
        f"{member.mention}: You have been invited to the encounter here. Press **Join** on the roster to enter"
        + (" (it rolls your initiative at once)." if enc.roster_begun else "."),
        allowed_mentions=discord.AllowedMentions(users=[member]),
    )


@combat_roster.command(name="remove", description="Uninvite a player who is not in initiative yet.")
@app_commands.describe(member="The player to take off the roster.")
async def combat_roster_remove(interaction: discord.Interaction, member: discord.Member) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _require_roster(interaction)
    if enc is None:
        return
    uid = str(member.id)
    if uid not in enc.roster:
        await interaction.response.send_message(f"{member.display_name} is not on the roster.", ephemeral=True)
        return
    if any(c.owner_id == uid for c in enc.combatants):
        await interaction.response.send_message(
            f"{member.display_name} is already in initiative; staff can remove them with `/combat remove`.", ephemeral=True,
        )
        return
    if enc.roster[uid] == "forced" and not _d.is_dm(interaction):
        await interaction.response.send_message("Staff forced that player in; only staff can uninvite them.", ephemeral=True)
        return
    del enc.roster[uid]
    _d.save_encounter(str(interaction.guild_id), enc)
    await _refresh_roster_message(enc)
    embed = discord.Embed(
        title="🛡️ Roster updated",
        description=f"**{member.display_name}** taken off the roster.",
        color=discord.Color.greyple(),
    )
    embed.set_footer(text=f"Removed by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)


@combat_roster.command(name="close", description="Close a roster that has not begun (organizer or staff).")
async def combat_roster_close(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _require_roster(interaction)
    if enc is None:
        return
    if (enc.roster_begun or enc.combatants or enc.started) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            "This encounter has begun; only staff can end it (`/combat end`).", ephemeral=True,
        )
        return
    await _close_roster_message(enc, str(interaction.guild_id))
    _d.encounters.pop(interaction.channel_id, None)
    _d.delete_encounter(interaction.channel_id)
    embed = discord.Embed(
        title="🛡️ Encounter roster closed",
        color=discord.Color.greyple(),
    )
    embed.set_footer(text=f"Closed by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"--- Encounter roster closed by {interaction.user.display_name} ---")


@combat_group.command(name="setup", description="Set up an encounter roster: Pick who is in, players accept or decline, then begin.")
async def combat_setup(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    existing = _d.encounters.get(interaction.channel_id)
    if existing is not None and existing.started:
        await interaction.response.send_message("A fight is already running here. `/combat end` it first.", ephemeral=True)
        return
    channel = interaction.channel
    members = [m for m in channel.members if not m.bot] if hasattr(channel, "members") else []
    if not members:
        await interaction.response.send_message(
            "No players found in this channel. Make sure the bot has the Server Members intent enabled.",
            ephemeral=True,
        )
        return
    await interaction.response.send_message(
        "Pick the players for this encounter (you may include yourself). Staff add NPCs and creatures after **Begin**.",
        view=_RosterPickView(interaction.user, members), ephemeral=True,
    )


@combat_group.command(name="add", description="Add an NPC/monster to initiative by its Reflexes and Insight Rank. [Fortune]")
@app_commands.describe(
    name="NPC name.", reflexes="NPC Reflexes.", insight_rank="NPC Insight Rank (1 if unknown).",
)
async def combat_add(
    interaction: discord.Interaction,
    name: app_commands.Range[str, 1, 40],
    reflexes: app_commands.Range[int, 1, 10],
    insight_rank: app_commands.Range[int, 1, 10] = 1,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    result = _d.engine.roll_and_keep(reflexes + insight_rank, reflexes)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(name)
    enc.add(encounter.Combatant(
        name=name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=None,
        is_npc=True,
        reflexes=reflexes,
    ))
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    await interaction.response.send_message(_render_encounter(enc, guild))
    await _d.combat_log(guild, f"Added NPC: {name} (Init {result.total})")
    await _refresh_board(enc, guild)


@combat_group.command(name="next", description="Advance to the next combatant's turn.")
async def combat_next(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    if not enc.combatants:
        await interaction.response.send_message(_render_encounter(enc), ephemeral=True)
        return
    uid = str(interaction.user.id)
    cur = enc.current()
    if enc.started:
        may_advance = _d.is_dm(interaction) or (cur is not None and cur.owner_id == uid)
        why = "Only staff or the player whose turn it is can advance. End your own turn with `/combat turn done`."
    else:
        # Opening the fight: staff, the roster organizer, or anyone who has a combatant in it.
        may_advance = _d.is_dm(interaction) or enc.organizer_id == uid or any(c.owner_id == uid for c in enc.combatants)
        why = "Only staff, the roster organizer, or someone in this fight can open it."
    if not may_advance:
        await interaction.response.send_message(why, ephemeral=True)
        return
    prev_round = enc.round
    current = enc.advance()
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    mention = f"<@{current.owner_id}> " if current.owner_id and not current.is_npc else ""
    desc_parts: list[str] = []
    expiry = _expiry_notes(enc)
    if expiry:
        desc_parts.extend(expiry)
    if current.center_bonus_available:
        rec = _d.resolve_combatant_record(guild, current)
        vr = rec.character.void_ring if rec else "?"
        desc_parts.append(f"🎯 **Center Stance bonus active**: +1k1 + {vr} (Void Ring) on one roll this turn. +10 Initiative this Round.")
    reminders = condition_effects.condition_reminders(current.conditions)
    if reminders:
        desc_parts.append("\n".join(reminders))
    embed = discord.Embed(
        title=f"➡️ {current.name}'s Turn",
        color=discord.Color.green(),
        description="\n".join(desc_parts) if desc_parts else None,
    )
    embed.set_footer(text=f"Round {enc.round}")
    tracker = _render_encounter(enc, guild)
    await interaction.response.send_message(content=f"{mention}{tracker}", embed=embed)
    if enc.round != prev_round:
        await _d.combat_log(guild, f"--- Round {enc.round} ---")
    cond_str = f" [{', '.join(sorted(current.conditions))}]" if current.conditions else ""
    await _d.combat_log(guild, f"Turn: {current.name}{cond_str}")
    await _refresh_board(enc, guild)


@combat_group.command(name="status", description="Show the current initiative order.")
async def combat_status(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    await interaction.response.send_message(_render_encounter(enc, str(interaction.guild_id)))


@combat_group.command(name="board", description="Post (or refresh) the combat board with action buttons.")
async def combat_board(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    guild = str(interaction.guild_id)
    if enc.board_message_id:
        ch = interaction.channel
        try:
            old_msg = await ch.fetch_message(enc.board_message_id)
            old_view = CombatBoardView(guild, enc.channel_id)
            old_view._persist_message_id = enc.board_message_id
            old_view._disable()
            try:
                await old_msg.edit(view=old_view)
            except discord.HTTPException:
                pass
        except discord.NotFound:
            pass
        enc.board_message_id = 0
    await interaction.response.defer()
    embed = _build_board_embed(enc, guild)
    view = CombatBoardView(guild, enc.channel_id)
    msg = await interaction.followup.send(embed=embed, view=view, wait=True)
    await view.persist(msg)
    enc.board_message_id = msg.id
    _d.save_encounter(guild, enc)


@combat_group.command(name="remove", description="Remove a combatant from initiative. [Fortune]")
@app_commands.describe(name="The combatant name to remove.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_remove(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = _d.encounters.get(interaction.channel_id)
    if enc is None or not enc.remove(name):
        await interaction.response.send_message(f"No combatant named **{name}** here.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(title=f"✖️ Removed: {name}", color=discord.Color.greyple())
    embed.set_footer(text=f"Removed by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    await _refresh_board(enc, guild)


def _end_level(enc: encounter.Encounter, guild: str, name: str) -> str:
    """Current wound level of a fight participant, from their sheet or creature record."""
    if name.lower() in (d.lower() for d in enc.deaths):
        return "Dead"
    cb = enc.find(name)
    rec = _d.resolve_combatant_record(guild, cb) if cb else None
    if rec is None:
        rec = _d.store.get_by_name_guild(guild, name)
    if rec is not None:
        return stats.wound_level_name(rec.character)
    cre = _d.store.get_creature_by_name(guild, name)
    if cre is not None:
        return creature.creature_wound_level(cre.creature)
    return "?"


def _render_summary(enc: encounter.Encounter, guild: str, final: bool) -> tuple[discord.Embed, list[str]]:
    """The fight summary embed and compact log lines (one per participant)."""
    names = [c.name for c in enc.combatants] + [n for n in enc.tally if enc.find(n) is None]
    elapsed = ""
    if enc.started_at:
        mins = int((_time.time() - enc.started_at) // 60)
        elapsed = f" · {mins // 60}h {mins % 60}m" if mins >= 60 else f" · {mins} min"
    head = f"Rounds: **{enc.round if enc.started else 0}**{elapsed} · {len(names)} participant(s)"
    if enc.deaths:
        head += f" · 💀 {len(enc.deaths)} dead"
    lines: list[str] = []
    logs: list[str] = []
    most_dealt = most_taken = best_acc = None
    for name in names:
        row = enc.tally.get(name) or enc.tally_for(name)
        dead = name.lower() in (d.lower() for d in enc.deaths)
        end = _end_level(enc, guild, name)
        arc = f"{row['join_level']} → {end}" if row["join_level"] else end
        parts = [f"{row['hits']}/{row['attacks']} hits" if row["attacks"] else "no attacks",
                 f"dealt {row['dealt']}", f"taken {row['taken']}"]
        if row["healed"]:
            parts.append(f"healed {row['healed']}")
        if row["kills"]:
            parts.append(f"kills {row['kills']}")
        if row["void"]:
            parts.append(f"Void {row['void']}")
        lines.append(f"{'💀 ' if dead else '• '}**{name}**: {' · '.join(parts)} · {arc}")
        logs.append(f"{name}: {row['hits']}/{row['attacks']} hits, dealt {row['dealt']}, taken {row['taken']}, {arc}")
        if row["dealt"] and (most_dealt is None or row["dealt"] > most_dealt[1]):
            most_dealt = (name, row["dealt"])
        if row["taken"] and (most_taken is None or row["taken"] > most_taken[1]):
            most_taken = (name, row["taken"])
        if row["attacks"] >= 3:
            acc = row["hits"] / row["attacks"]
            if best_acc is None or acc > best_acc[1]:
                best_acc = (name, acc, row["hits"], row["attacks"])
    callouts = []
    if most_dealt:
        callouts.append(f"🗡️ Most damage dealt: **{most_dealt[0]}** ({most_dealt[1]})")
    if most_taken:
        callouts.append(f"🩸 Most damage taken: **{most_taken[0]}** ({most_taken[1]})")
    if best_acc:
        callouts.append(f"🎯 Most accurate: **{best_acc[0]}** ({best_acc[2]}/{best_acc[3]})")
    embed = discord.Embed(
        title="🏁 Fight summary" if final else "📊 Fight so far",
        description=(head + "\n\n" + ("\n".join(lines) if lines else "*No participants recorded.*")
                     + ("\n\n" + "\n".join(callouts) if callouts else ""))[:4000],
        color=discord.Color.dark_gold() if final else discord.Color.blurple(),
    )
    if enc.deaths:
        embed.add_field(name="Fallen", value=", ".join(enc.deaths)[:1024], inline=False)
    embed.set_footer(text="Damage counts what a DM approved. /dm undo rolls back sheets, not this tally.")
    return embed, logs


@combat_group.command(name="recap", description="Fight so far: Rounds, hits, damage dealt and taken, healing, kills, Void, wound levels.")
async def combat_recap(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    embed, _ = _render_summary(enc, str(interaction.guild_id), final=False)
    await interaction.response.send_message(embed=embed)


@combat_group.command(name="end", description="End the encounter in this channel and post the fight summary. [Fortune]")
async def combat_end(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    enc = _d.encounters.get(interaction.channel_id)
    if enc is None:
        await interaction.response.send_message("No encounter here. Start one with `/combat start`.", ephemeral=True)
        return
    embed, logs = _render_summary(enc, guild, final=True)
    await _close_roster_message(enc, guild, "Encounter ended.")
    if enc.board_message_id:
        ch = _d.bot_client.get_channel(enc.channel_id)
        if ch is not None:
            try:
                board_msg = await ch.fetch_message(enc.board_message_id)
                bv = CombatBoardView(guild, enc.channel_id)
                bv._persist_message_id = enc.board_message_id
                bv._disable()
                await board_msg.edit(view=bv)
            except discord.HTTPException:
                pass
    _d.encounters.pop(interaction.channel_id, None)
    _d.delete_encounter(interaction.channel_id)
    await interaction.response.send_message(content="⚔️ Encounter ended.", embed=embed)
    await _d.combat_log(guild, "--- Encounter ended --- " + (" | ".join(logs) if logs else ""))


@combat_group.command(name="summary", description="Compact overview of all combatants' key stats. [Fortune]")
async def combat_summary(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    if not enc.combatants:
        await interaction.response.send_message(_render_encounter(enc), ephemeral=True)
        return
    guild = str(interaction.guild_id)
    title = f"⚔️ Combat Summary: Round {enc.round}"
    if enc.surprise_round:
        title += " (Surprise)"
    embed = discord.Embed(title=title, color=discord.Color.dark_red())
    if enc.notes:
        embed.description = f"📍 *{enc.notes}*"
    for cb in enc.combatants[:25]:
        rec = _d.resolve_combatant_record(guild, cb)
        if rec is not None:
            c = rec.character
            lvl = stats.wound_level_name(c)
            pen = stats.wound_penalty(c)
            cap = stats.total_wound_capacity(c)
            tn = combat.armor_tn(c, cb.stance)
            pen_str = f" ⚠️ **{pen} penalty**" if pen else ""
            vp = f"{c.current_void_points}/{c.max_void_points} VP"
            conds = ", ".join(sorted(cb.conditions)) if cb.conditions else " "
            fd = f", FD+{cb.full_defense_bonus}" if cb.full_defense_bonus else ""
            v_atn = f", 🌀ATN+{cb.void_armor_tn_bonus}" if cb.void_armor_tn_bonus else ""
            v_init = f", 🌀Init+{cb.void_initiative_boost}" if cb.void_initiative_boost else ""
            c_bonus = ", 🎯Center+1k1" if cb.center_bonus_available else ""
            c_init = f", 🎯Init+{cb.center_init_boost}" if cb.center_init_boost else ""
            guard = f", guarding {cb.guarding}" if cb.guarding else ""
            cover = f", Cover{'+' if cb.cover_bonus > 0 else ''}{cb.cover_bonus}" if cb.cover_bonus else ""
            held = ", HELD" if cb.held else ""
            delayed = ", DELAYED" if cb.delayed else ""
            stance_label = cb.stance.replace("_", " ").title()
            acts_left = 2 - cb.actions_used
            value = (
                f"Wounds: {c.wounds_taken}/{cap} **{lvl}**{pen_str}\n"
                f"ATN: **{tn}** · {vp} · Stance: **{stance_label}** · Acts: {acts_left}\n"
                f"Conditions: {conds}{fd}{v_atn}{v_init}{c_bonus}{c_init}{guard}{cover}{held}{delayed}"
            )
        else:
            conds = ", ".join(sorted(cb.conditions)) if cb.conditions else " "
            value = f"*(no sheet)* · Conditions: {conds}"
        marker = "▶️ " if (enc.started and cb is enc.current()) else ""
        embed.add_field(
            name=f"{marker}{cb.name} (init {cb.effective_initiative})",
            value=value,
            inline=True,
        )
    if len(enc.combatants) > 25:
        embed.set_footer(text=f"Showing 25 of {len(enc.combatants)} combatants.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


@combat_group.command(name="npc", description="Add a stored NPC to initiative (rolls its initiative). [Fortune]")
@app_commands.describe(name="The NPC to add.")
async def combat_npc(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec = _d.store.get_by_name(str(interaction.guild_id), _d.NPC_OWNER, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    idr, idk, idn = technique_effects.initiative_dice_bonus(rec.character)
    result = combat.roll_initiative(rec.character, _d.engine, idr, idk)
    swift_bonus = 5 if "swift" in rec.character.weapon_qualities else 0
    tech_init, tech_init_notes = technique_effects.initiative_bonus(rec.character)
    init_total = result.total + swift_bonus + tech_init
    swift_detail = f" +5 Swift" if swift_bonus else ""
    tech_init_detail = "".join(f" +{n}" for n in tech_init_notes)
    dice_detail = "".join(f" [{n}]" for n in idn)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(rec.character.name)
    enc.add(encounter.Combatant(
        name=rec.character.name,
        initiative=init_total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}{swift_detail}{tech_init_detail}{dice_detail}",
        owner_id=None,
        is_npc=True,
        reflexes=rec.character.reflexes,
    ))
    enc.note_join(rec.character.name, stats.wound_level_name(rec.character))
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    await interaction.response.send_message(_render_encounter(enc, guild))
    await _refresh_board(enc, guild)


_CONDITION_CHOICES = [
    app_commands.Choice(name=c.title(), value=c)
    for c in sorted(encounter.VALID_CONDITIONS)
]


def _expiry_notes(enc: encounter.Encounter) -> list[str]:
    """Condition-ended lines from the last round boundary, announced once."""
    notes = [f"⌛ {line} ended." for line in enc.last_expired]
    enc.last_expired = []
    return notes


@combat_condition.command(name="set", description="Apply a condition to a combatant, optionally for a number of Rounds. [Fortune]")
@app_commands.describe(
    name="The combatant to affect.",
    condition="The condition to apply.",
    rounds="How many Rounds it lasts (ends at the start of that Round). Omit = until cleared.",
)
@app_commands.choices(condition=_CONDITION_CHOICES)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_condition_set(
    interaction: discord.Interaction,
    name: str,
    condition: app_commands.Choice[str],
    rounds: app_commands.Range[int, 1, 20] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    c.set_condition(condition.value, rounds or 0, enc.round)
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    dur = f" for {rounds} Round(s)" if rounds else ""
    embed = discord.Embed(
        title=f"⚡ {c.name}: {condition.name}",
        color=discord.Color.orange(),
        description=f"Condition applied{dur}.",
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Condition: {c.name} +{condition.name}{dur}")
    await _refresh_board(enc, guild)


@combat_condition.command(name="clear", description="Remove a condition from a combatant. [Fortune]")
@app_commands.describe(
    name="The combatant to affect.",
    condition="The condition to remove.",
)
@app_commands.choices(condition=_CONDITION_CHOICES)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_condition_clear(
    interaction: discord.Interaction,
    name: str,
    condition: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    c.clear_condition(condition.value)
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"✖️ {c.name}: {condition.name} cleared",
        color=discord.Color.greyple(),
    )
    embed.set_footer(text=f"Cleared by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Condition: {c.name} -{condition.name}")
    await _refresh_board(enc, guild)


@combat_condition.command(name="list", description="Show a combatant's active conditions.")
@app_commands.describe(name="The combatant to check.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_conditions(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    c = enc.find(name)
    if c is None:
        await interaction.response.send_message(f"No combatant named **{name}**.", ephemeral=True)
        return
    if not c.conditions:
        await interaction.response.send_message(f"**{c.name}** has no active conditions.", ephemeral=True)
        return
    cond_list = ", ".join(
        f"{k} ({c.rounds_left(k, enc.round)} Round(s) left)" if k in c.condition_expiry else k for k in sorted(c.conditions)
    )
    reminders = condition_effects.condition_reminders(c.conditions)
    lines = f"**{c.name}** conditions: {cond_list}"
    if reminders:
        lines += "\n" + "\n".join(reminders)
    await interaction.response.send_message(lines, ephemeral=True)


# ---------------------------------------------------------------------------
# Condition requests: applied only when a DM approves (same pattern as damage)
# ---------------------------------------------------------------------------

_SPELL_CONDITION_WORDS = ("prone", "dazed", "stunned", "blinded", "entangled", "fatigued")
_NUM_WORDS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5}


def spell_conditions(effect_text: str) -> list[tuple[str, int]]:
    """(condition, rounds) pairs a spell's effect text states plainly; rounds 0 = unstated.
    Only conditions the tracker knows; a duration is taken only from 'for N Round(s)'
    in the same sentence."""
    found: dict[str, int] = {}
    for sentence in re.split(r"(?<=[.;])\s+", effect_text or ""):
        low = sentence.lower()
        hits = {w: [m.start() for m in re.finditer(rf"\b{w}\b", low)] for w in _SPELL_CONDITION_WORDS}
        hits = {w: pos for w, pos in hits.items() if pos}
        if not hits:
            continue
        # "for N Rounds" belongs to the condition named just before it; Prone is
        # never timed (it ends when the character stands up).
        timed: dict[str, int] = {}
        for m in re.finditer(r"for (\d+|one|two|three|four|five) rounds?", low):
            n = int(m.group(1)) if m.group(1).isdigit() else _NUM_WORDS.get(m.group(1), 0)
            before = [(max(p for p in pos if p < m.start()), w) for w, pos in hits.items() if any(p < m.start() for p in pos)]
            if before and n:
                _, w = max(before)
                if w != "prone":
                    timed.setdefault(w, n)
        for w in _SPELL_CONDITION_WORDS:
            if w in hits and w not in found:
                found[w] = timed.get(w, 0)
    return list(found.items())


class ConditionView(views_base.PersistentView):
    """Apply / Deny buttons for a requested condition; Fortune only."""

    KIND = "condition_request"

    def __init__(self, guild_id: str, channel_id: int, target_name: str, condition: str,
                 rounds: int = 0, source: str = "", requester_id: int = 0) -> None:
        super().__init__()
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.target_name = target_name
        self.condition = condition
        self.rounds = rounds
        self.source = source
        self.requester_id = requester_id

    def _label(self) -> str:
        dur = f" for {self.rounds} Round(s)" if self.rounds else ""
        return f"**{self.condition.title()}**{dur} on **{self.target_name}**"

    async def _finish(self, interaction: discord.Interaction, line: str) -> None:
        self._disable()
        try:
            await interaction.response.edit_message(content=line, view=self, allowed_mentions=discord.AllowedMentions.none())
        except discord.HTTPException:
            pass
        if interaction.channel_id != self.channel_id:
            ch = _d.bot_client.get_channel(self.channel_id)
            if ch is not None:
                try:
                    await ch.send(line, allowed_mentions=discord.AllowedMentions.none())
                except discord.HTTPException:
                    pass

    @discord.ui.button(label="Apply", style=discord.ButtonStyle.success, emoji="✅")
    async def apply(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(f"Only **{_d.ROLE_FORTUNE}** / **{_d.ROLE_KAMI}** can approve conditions.", ephemeral=True)
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        enc = _d.encounters.get(self.channel_id)
        cb = enc.find(self.target_name) if enc else None
        if cb is None:
            self._disable()
            await interaction.response.edit_message(
                content=f"⚠️ {self._label()}: **{self.target_name}** is no longer in that channel's initiative; nothing applied.",
                view=self, allowed_mentions=discord.AllowedMentions.none(),
            )
            return
        cb.set_condition(self.condition, self.rounds, enc.round)
        _d.save_encounter(self.guild_id, enc)
        src = f" ({self.source})" if self.source else ""
        dur = f" {self.rounds}r" if self.rounds else ""
        await _d.combat_log(self.guild_id, f"Condition: {cb.name} +{self.condition.title()}{dur}{src} approved by {interaction.user.display_name}")
        await self._finish(interaction, f"✅ {self._label()}{src}: Applied by {interaction.user.display_name}.")

    @discord.ui.button(label="Deny", style=discord.ButtonStyle.secondary, emoji="❌")
    async def deny(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if not _d.is_dm(interaction):
            await interaction.response.send_message(f"Only **{_d.ROLE_FORTUNE}** / **{_d.ROLE_KAMI}** can deny conditions.", ephemeral=True)
            return
        if not self.claim():
            await interaction.response.send_message("Already handled by an earlier click.", ephemeral=True)
            return
        await _d.combat_log(self.guild_id, f"Condition: {self.target_name} {self.condition.title()} denied by {interaction.user.display_name}")
        await self._finish(interaction, f"❌ {self._label()}: Denied by {interaction.user.display_name}.")


async def post_condition_request(
    guild: str, channel_id: int, requester: discord.abc.User, target_name: str, condition: str,
    rounds: int, source: str,
) -> tuple[str, discord.Embed | None, ConditionView | None]:
    """Build the approval. With a damage-approval channel configured the request is
    posted there and only a confirmation line comes back; otherwise the caller sends
    (content, embed, view) in place and persists the view."""
    view = ConditionView(guild, channel_id, target_name, condition, rounds, source, requester.id)
    dur = f" for {rounds} Round(s)" if rounds else " (until cleared)"
    embed = discord.Embed(
        title=f"🩹 Condition request: {condition.title()} on {target_name}",
        description=f"**Duration:**{dur}\n**Source:** {source or 'not given'}\n**Requested by:** {requester.mention}\n**Fight:** <#{channel_id}>",
        color=discord.Color.orange(),
    )
    prompt = f"{_d.dm_ping(_d.bot_client.get_guild(int(guild)))}A DM can apply the condition below."
    approval_ch_id = _d.store.get_damage_approval_channel(guild) or _d.store.get_approval_channel(guild)
    approval_ch = _d.bot_client.get_channel(int(approval_ch_id)) if approval_ch_id else None
    if approval_ch is not None:
        msg = await approval_ch.send(content=prompt, embed=embed, view=view, allowed_mentions=_PING_MENTIONS)
        await view.persist(msg)
        return f"🩹 Condition request ({condition.title()} on **{target_name}**) sent to the DM channel.", None, None
    return prompt, embed, view


@fight_group.command(name="condition", description="Ask a DM to apply a condition (Dazed, Prone…) to a combatant; applied on approval.")
@app_commands.describe(
    target="The combatant to affect (must be in this channel's initiative).",
    condition="The condition.",
    rounds="How many Rounds it should last. Omit = until cleared.",
    source="What causes it (spell, technique, terrain…).",
)
@app_commands.choices(condition=_CONDITION_CHOICES)
@app_commands.autocomplete(target=_combatant_autocomplete)
async def fight_condition(
    interaction: discord.Interaction,
    target: str,
    condition: app_commands.Choice[str],
    rounds: app_commands.Range[int, 1, 20] | None = None,
    source: app_commands.Range[str, 0, 100] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(target)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{target}** here.", ephemeral=True)
        return
    if condition.value in cb.conditions:
        await interaction.response.send_message(f"**{cb.name}** is already {condition.name}.", ephemeral=True)
        return
    content, embed, view = await post_condition_request(
        str(interaction.guild_id), interaction.channel_id, interaction.user, cb.name, condition.value, rounds or 0, source or "",
    )
    if view is None:
        await interaction.response.send_message(content)
        return
    await interaction.response.send_message(content=content, embed=embed, view=view, allowed_mentions=_PING_MENTIONS)
    await view.persist(await interaction.original_response())


class SpellConditionPromptView(discord.ui.View):
    """Buttons under a successful cast: request each condition the spell names."""

    def __init__(self, guild_id: str, channel_id: int, target_name: str, caster_id: int,
                 spell_name: str, conds: list[tuple[str, int]]) -> None:
        super().__init__(timeout=900)
        self.guild_id = guild_id
        self.channel_id = channel_id
        self.target_name = target_name
        self.caster_id = caster_id
        self.spell_name = spell_name
        for cond, rounds in conds[:4]:
            label = f"Request {cond.title()}" + (f" ({rounds} Round{'s' if rounds != 1 else ''})" if rounds else "")
            btn = discord.ui.Button(label=label, style=discord.ButtonStyle.primary, emoji="🩹")
            btn.callback = self._make_callback(btn, cond, rounds)
            self.add_item(btn)

    def _make_callback(self, btn: discord.ui.Button, cond: str, rounds: int):
        async def cb(interaction: discord.Interaction) -> None:
            if interaction.user.id != self.caster_id and not _d.is_dm(interaction):
                await interaction.response.send_message("Only the caster or a DM can request this.", ephemeral=True)
                return
            btn.disabled = True
            await interaction.response.edit_message(view=self)
            content, embed, view = await post_condition_request(
                self.guild_id, self.channel_id, interaction.user, self.target_name, cond, rounds, self.spell_name,
            )
            if view is None:
                await interaction.followup.send(content)
                return
            msg = await interaction.followup.send(content=content, embed=embed, view=view, allowed_mentions=_PING_MENTIONS, wait=True)
            await view.persist(msg)
        return cb


@fight_group.command(name="status", description="Your compact combat card: Wounds, penalty, Void, stance, conditions, Armor TN.")
@app_commands.describe(member="Another player's active character [Fortune]")
async def fight_status(interaction: discord.Interaction, member: discord.Member | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if member is not None and member.id != interaction.user.id:
        if not await _d.require_dm_role(interaction):
            return
        owner = member
    else:
        owner = interaction.user
    rec = _d.store.get_active(guild, str(owner.id))
    if rec is None:
        await interaction.response.send_message("No active character. Create one with `/sheet create` (staff: `/sheet activate`).", ephemeral=True)
        return
    c = rec.character
    enc = _d.encounters.get(interaction.channel_id)
    cb = enc.find(c.name) if enc else None
    level = stats.wound_level_name(c)
    lines = [
        f"❤️ Wounds **{c.wounds_taken}/{stats.total_wound_capacity(c)}** - **{level}** (penalty {stats.wound_penalty(c):+d} to rolls)",
        f"🔮 Void **{c.current_void_points}/{c.max_void_points}**",
        f"🗡️ Weapon **{c.equipped_weapon or 'katana'}**" + (f" · off-hand {c.off_hand_weapon}" if c.off_hand_weapon else ""),
    ]
    stance = cb.stance if cb else "attack"
    tn = combat.armor_tn(c, stance)
    tn_notes = [f"stance {stance}"]
    if cb:
        if cb.full_defense_bonus:
            tn += cb.full_defense_bonus; tn_notes.append(f"Full Defense +{cb.full_defense_bonus}")
        if cb.void_armor_tn_bonus:
            tn += cb.void_armor_tn_bonus; tn_notes.append(f"Void +{cb.void_armor_tn_bonus}")
        if cb.cover_bonus:
            tn += cb.cover_bonus; tn_notes.append(f"cover {cb.cover_bonus:+d}")
        if cb.guarding:
            tn -= 5; tn_notes.append(f"guarding {cb.guarding} −5")
    lines.append(f"🛡️ Armor TN **{tn}** ({', '.join(tn_notes)}; guard/condition modifiers applied per attack)")
    if cb and enc:
        acts = {0: "none used", 1: "1 Simple used", 2: "done"}.get(cb.actions_used, str(cb.actions_used))
        turn = "▶️ **your turn**" if enc.started and enc.current() is cb else f"Round {enc.round}"
        lines.append(f"⚔️ {turn} · init **{cb.effective_initiative}** · stance **{cb.stance}** · actions: {acts}")
        extras = []
        if cb.conditions:
            extras.append("conditions: " + ", ".join(sorted(cb.conditions)))
        if cb.fear_penalty:
            extras.append(f"😨 Fear −{cb.fear_penalty}k0")
        if cb.held:
            extras.append("holding")
        if cb.delayed:
            extras.append("delayed")
        if cb.center_bonus_available:
            extras.append("Center bonus ready (+1k1 + Void)")
        if extras:
            lines.append("• " + " · ".join(extras))
    else:
        lines.append("Not on this channel's initiative list.")
    if stats.is_dead(c):
        lines.append("💀 **Dead.**")
    elif level == "Out":
        lines.append("😵 **Out**: Unconscious, cannot act.")
    embed = discord.Embed(title=f"🧾 {c.name}", description="\n".join(lines), color=discord.Color.dark_gold())
    await interaction.response.send_message(embed=embed, ephemeral=True)


@fight_group.command(name="guard", description="Guard another combatant (+10 Armor TN to ward, −5 to you). Lasts until your next turn.")
@app_commands.describe(
    guarder="The combatant doing the guarding.",
    ward="The combatant being protected.",
)
@app_commands.autocomplete(guarder=_combatant_autocomplete, ward=_combatant_autocomplete)
async def combat_guard(interaction: discord.Interaction, guarder: str, ward: str) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    g = enc.find(guarder)
    if g is None:
        await interaction.response.send_message(f"No combatant named **{guarder}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, g) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only guard with your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    w = enc.find(ward)
    if w is None:
        await interaction.response.send_message(f"No combatant named **{ward}**.", ephemeral=True)
        return
    if g.name == w.name:
        await interaction.response.send_message("A combatant cannot guard themselves.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(g.conditions)
    if blocked:
        await interaction.response.send_message(f"**{g.name}** cannot act: {block_reason}", ephemeral=True)
        return
    if g.stance in ("full_attack", "full_defense", "center"):
        reasons = {
            "full_attack": "Guard is not available in Full Attack Stance.",
            "full_defense": "Only Free Actions allowed in Full Defense Stance.",
            "center": "All Actions are forfeited in Center Stance.",
        }
        await interaction.response.send_message(f"**{g.name}**: {reasons[g.stance]}", ephemeral=True)
        return
    if g.actions_used >= 2:
        await interaction.response.send_message(
            f"**{g.name}** has no actions remaining this turn ({g.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.",
            ephemeral=True,
        )
        return
    g.guarding = w.name
    g.actions_used += 1
    remaining = 2 - g.actions_used
    _d.save_encounter(str(interaction.guild_id), enc)
    embed = discord.Embed(
        title=f"🛡️ {g.name} guards {w.name}",
        color=discord.Color.blue(),
        description=(
            f"Ward ({w.name}): **+10 Armor TN**\n"
            f"Guarder ({g.name}): **-5 Armor TN**\n"
            f"Simple Action ({remaining} action{'s' if remaining != 1 else ''} remaining)\n"
            f"Expires at the start of {g.name}'s next turn."
        ),
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Guard: {g.name} guards {w.name}")


@fight_group.command(name="full_defense", description="Full Defense: Defense/Reflexes roll, half (rounded up) added to Armor TN until next turn.")
@app_commands.describe(
    combatant="The combatant entering Full Defense.",
    reflexes="Override Reflexes (for ad-hoc NPCs without a sheet).",
    defense_skill="Override Defense skill rank (for ad-hoc NPCs without a sheet).",
)
@app_commands.autocomplete(combatant=_combatant_autocomplete)
async def combat_full_defense(
    interaction: discord.Interaction,
    combatant: str,
    reflexes: app_commands.Range[int, 1, 10] | None = None,
    defense_skill: app_commands.Range[int, 0, 10] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only declare Full Defense for your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    blocked, block_reason = condition_effects.cannot_act(cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    stance_blocked, stance_reason = condition_effects.invalid_stance(cb.conditions, "full_defense")
    if stance_blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot use Full Defense: {stance_reason}", ephemeral=True)
        return
    if cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{cb.name}** has already used actions this turn ({cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.",
            ephemeral=True,
        )
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_combatant_record(guild, cb)
    ref = reflexes
    def_sk = defense_skill
    if rec is not None:
        if ref is None:
            ref = rec.character.reflexes
        if def_sk is None:
            def_sk = rec.character.skills.get("Defense", 0)
    if ref is None or def_sk is None:
        await interaction.response.send_message(
            f"Cannot resolve stats for **{cb.name}**. Provide `reflexes:` and `defense_skill:` explicitly.",
            ephemeral=True,
        )
        return
    wp = stats.wound_penalty(rec.character) if rec is not None else 0
    cr, cf, _ = condition_effects.contested_roll_modifier(cb.conditions)
    result = combat.roll_full_defense(ref, def_sk, _d.engine, wound_penalty=wp,
                                      extra_rolled=cr, extra_flat=cf)
    cb.full_defense_bonus = result["bonus"]
    cb.stance = "full_defense"
    cb.actions_used = 2
    _d.save_encounter(guild, enc)
    wp_note = f"Wound penalty: **{wp}**\n" if wp != 0 else ""
    embed = discord.Embed(
        title=f"🛡️ {cb.name}: Full Defense",
        color=discord.Color.dark_blue(),
        description=(
            f"Roll: {result['rolled']}k{result['kept']} = **{result['total']}** | "
            f"Half (rounded up) = **+{result['bonus']} Armor TN**\n"
            f"{wp_note}"
            f"Complex Action: Only Free Actions until next turn.\n"
            f"Expires at the start of {cb.name}'s next turn."
        ),
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Full Defense: {cb.name} (+{result['bonus']} Armor TN)")
    await _refresh_board(enc, guild)

# ===========================================================================
# /combat void group: round-level Void Point effects (GDD s25)
# ===========================================================================


@combat_void.command(name="armor", description="Spend a Void Point for +10 Armor TN for one Round (beginning of Round).")
@app_commands.describe(combatant="The combatant spending the Void Point.")
@app_commands.autocomplete(combatant=_combatant_autocomplete)
async def combat_void_armor(interaction: discord.Interaction, combatant: str) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only spend Void Points for your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_combatant_record(guild, cb)
    if rec is None:
        await interaction.response.send_message(f"Cannot resolve character sheet for **{cb.name}**.", ephemeral=True)
        return
    c = rec.character
    ok, reason = advantage_effects.can_spend_void_on_roll(c)
    if not ok:
        await interaction.response.send_message(f"🌀 {reason}", ephemeral=True)
        return
    if c.current_void_points <= 0:
        await interaction.response.send_message(f"🌀 **{cb.name}** has no Void Points (0/{c.max_void_points}).", ephemeral=True)
        return
    if not cb.consume_once("void_combat", "round"):
        await interaction.response.send_message(f"🌀 **{cb.name}** has already spent a Void Point this Round (one per Round limit).", ephemeral=True)
        return
    c.current_void_points -= 1
    _d.tally(interaction.channel_id, cb.name, "void")
    cb.void_armor_tn_bonus += 10
    _d.store.save(rec)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🌀 {cb.name}: Void Armor",
        color=discord.Color.purple(),
        description=(
            f"**+10 Armor TN** for this Round\n"
            f"Armor TN bonus: +{cb.void_armor_tn_bonus} · VP remaining: {c.current_void_points}/{c.max_void_points}\n"
            f"Clears at the start of the next Round."
        ),
    )
    embed.set_footer(text=f"Spent by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(guild, f"Void Armor: {cb.name} (+10 Armor TN, {c.current_void_points} VP left)")


@combat_void.command(name="initiative", description="Spend a Void Point for +10 Initiative for the remainder of the skirmish.")
@app_commands.describe(combatant="The combatant spending the Void Point.")
@app_commands.autocomplete(combatant=_combatant_autocomplete)
async def combat_void_initiative(interaction: discord.Interaction, combatant: str) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only spend Void Points for your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_combatant_record(guild, cb)
    if rec is None:
        await interaction.response.send_message(f"Cannot resolve character sheet for **{cb.name}**.", ephemeral=True)
        return
    c = rec.character
    ok, reason = advantage_effects.can_spend_void_on_roll(c)
    if not ok:
        await interaction.response.send_message(f"🌀 {reason}", ephemeral=True)
        return
    if c.current_void_points <= 0:
        await interaction.response.send_message(f"🌀 **{cb.name}** has no Void Points (0/{c.max_void_points}).", ephemeral=True)
        return
    if not cb.consume_once("void_combat", "round"):
        await interaction.response.send_message(f"🌀 **{cb.name}** has already spent a Void Point this Round (one per Round limit).", ephemeral=True)
        return
    c.current_void_points -= 1
    _d.tally(interaction.channel_id, cb.name, "void")
    cb.void_initiative_boost += 10
    cur_before = enc.current() if enc.started else None
    enc._sort()
    if cur_before is not None:
        enc.turn_index = enc.combatants.index(cur_before)
    _d.store.save(rec)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🌀 {cb.name}: Void Initiative",
        color=discord.Color.purple(),
        description=(
            f"**+10 Initiative** for the skirmish\n"
            f"Effective initiative: **{cb.effective_initiative}** · VP remaining: {c.current_void_points}/{c.max_void_points}\n"
            f"Persists until the encounter ends."
        ),
    )
    embed.set_footer(text=f"Spent by {interaction.user.display_name}")
    await interaction.response.send_message(
        content=_render_encounter(enc, guild),
        embed=embed,
    )
    await _d.combat_log(guild, f"Void Initiative: {cb.name} (+10, now {cb.effective_initiative}, {c.current_void_points} VP left)")


@combat_void.command(name="swap", description="Exchange Initiative with a willing target for the remainder of the skirmish (1 VP).")
@app_commands.describe(
    spender="The combatant spending the Void Point.",
    target="The willing target to swap Initiative with.",
)
@app_commands.autocomplete(spender=_combatant_autocomplete, target=_combatant_autocomplete)
async def combat_void_swap(interaction: discord.Interaction, spender: str, target: str) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb_s = enc.find(spender)
    if cb_s is None:
        await interaction.response.send_message(f"No combatant named **{spender}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb_s) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only spend Void Points for your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    cb_t = enc.find(target)
    if cb_t is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    if cb_s.name == cb_t.name:
        await interaction.response.send_message("Cannot swap Initiative with yourself.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_combatant_record(guild, cb_s)
    if rec is None:
        await interaction.response.send_message(f"Cannot resolve character sheet for **{cb_s.name}**.", ephemeral=True)
        return
    c = rec.character
    ok, reason = advantage_effects.can_spend_void_on_roll(c)
    if not ok:
        await interaction.response.send_message(f"🌀 {reason}", ephemeral=True)
        return
    if c.current_void_points <= 0:
        await interaction.response.send_message(f"🌀 **{cb_s.name}** has no Void Points (0/{c.max_void_points}).", ephemeral=True)
        return
    if not cb_s.consume_once("void_combat", "round"):
        await interaction.response.send_message(f"🌀 **{cb_s.name}** has already spent a Void Point this Round (one per Round limit).", ephemeral=True)
        return
    c.current_void_points -= 1
    _d.tally(interaction.channel_id, cb_s.name, "void")
    old_s = cb_s.effective_initiative
    old_t = cb_t.effective_initiative
    cb_s.initiative, cb_t.initiative = cb_t.initiative, cb_s.initiative
    cb_s.void_initiative_boost, cb_t.void_initiative_boost = cb_t.void_initiative_boost, cb_s.void_initiative_boost
    cur_before = enc.current() if enc.started else None
    enc._sort()
    if cur_before is not None:
        enc.turn_index = enc.combatants.index(cur_before)
    _d.store.save(rec)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🌀 Initiative Swap",
        color=discord.Color.purple(),
        description=(
            f"**{cb_s.name}** exchanges Initiative with **{cb_t.name}**\n"
            f"{cb_s.name}: {old_s} → **{cb_s.effective_initiative}** · "
            f"{cb_t.name}: {old_t} → **{cb_t.effective_initiative}**\n"
            f"VP remaining: {c.current_void_points}/{c.max_void_points}\n"
            f"Persists for the remainder of the skirmish."
        ),
    )
    embed.set_footer(text=f"Spent by {interaction.user.display_name}")
    await interaction.response.send_message(
        content=_render_encounter(enc, guild),
        embed=embed,
    )
    await _d.combat_log(guild, f"Void Swap: {cb_s.name} ↔ {cb_t.name} initiative ({c.current_void_points} VP left)")

@combat_grapple.command(name="initiate", description="Initiate a Grapple: Jiujutsu/Agility vs Armor TN (ignoring armor bonus). [Fortune]")
@app_commands.describe(
    attacker="The combatant initiating the grapple.",
    target="The target being grappled.",
    bonus_tn="DM situational TN modifier.",
    defender_stance="Target's stance.",
)
@app_commands.choices(defender_stance=_DEFENDER_STANCES)
async def grapple_initiate(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
    bonus_tn: int = 0,
    defender_stance: app_commands.Choice[str] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    atk_cb = enc.find(attacker)
    if atk_cb is None:
        await interaction.response.send_message(f"No combatant named **{attacker}**.", ephemeral=True)
        return
    def_cb = enc.find(target)
    if def_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(atk_cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{atk_cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    atk_rec = _d.resolve_combatant_record(guild, atk_cb)
    def_rec = _d.resolve_combatant_record(guild, def_cb)
    if atk_rec is None or def_rec is None:
        await interaction.response.send_message(
            "Both combatants need stored character sheets for grapple initiation.", ephemeral=True
        )
        return
    if await _d.refuse_if_cannot_act(interaction, atk_rec.character) or await _d.refuse_if_dead(interaction, def_rec.character):
        return
    d_stance = defender_stance.value if defender_stance else "attack"
    tn = combat.grapple_initiate_tn(def_rec.character, d_stance, bonus_tn)
    extra_tn = 0
    if def_cb.full_defense_bonus:
        extra_tn += def_cb.full_defense_bonus
    def_conds = def_cb.conditions
    cond_tn_ovr, cond_tn_notes = condition_effects.defender_armor_tn_override(
        def_conds, def_rec.character.reflexes, def_rec.character.armor_tn_bonus, True,
    )
    cond_def_mod, _ = condition_effects.defender_armor_tn_mod(def_conds, True)
    if cond_tn_ovr is not None:
        tn = cond_tn_ovr + cond_def_mod + extra_tn + bonus_tn
    else:
        tn += cond_def_mod + extra_tn
    if atk_cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{atk_cb.name}** has already used actions this turn ({atk_cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
        return
    ar, af, _ = condition_effects.contested_roll_modifier(atk_cb.conditions)
    ar -= atk_cb.fear_penalty
    outcome = combat.resolve_grapple_initiate(atk_rec.character, tn, _d.engine,
                                              extra_flat=af, extra_rolled=ar)
    hit = outcome["hit"]
    equipped = atk_rec.character.equipped_weapon
    grapple_weapon_note = ""
    if equipped:
        wp = combat.get_weapon_profile(equipped)
        if wp.get("grapple_capable"):
            grapple_weapon_note = f"\n✓ {equipped.replace('_', ' ').title()}: Can initiate grapple while armed"
        else:
            grapple_weapon_note = f"\n⚠️ {equipped.replace('_', ' ').title()} is not grapple-capable - must drop/sheathe to grapple (DM adjudicates)"
    embed = discord.Embed(
        title=f"🤼 {atk_cb.name} attempts to grapple {def_cb.name}",
        color=discord.Color.greyple(),
    )
    embed.add_field(
        name="1. Grapple Attack (Jiujutsu/Agility)",
        value=f"Roll **{outcome['roll']}** vs TN **{outcome['target_tn']}**"
              f": {'**HIT**' if hit else '**miss**'}"
              f"\n({outcome['rolled']}k{outcome['kept']}, wound penalty {outcome['wound_penalty']})"
              f"{grapple_weapon_note}",
        inline=False,
    )
    grappled = False
    if hit:
        str_a = atk_rec.character.strength
        jiu_a = atk_rec.character.skills.get("Jiujutsu", 0)
        str_b = def_rec.character.strength
        jiu_b = def_rec.character.skills.get("Jiujutsu", 0)
        wp_a = stats.wound_penalty(atk_rec.character)
        wp_b = stats.wound_penalty(def_rec.character)
        cr_a, cf_a, _ = condition_effects.contested_roll_modifier(atk_cb.conditions)
        cr_b, cf_b, _ = condition_effects.contested_roll_modifier(def_cb.conditions)
        contest = combat.resolve_grapple_control(str_a, jiu_a, str_b, jiu_b, _d.engine, wp_a, wp_b,
                                                 cr_a, cf_a, cr_b, cf_b)
        atk_wins = contest["winner"] in ("a", "tie")
        embed.add_field(
            name="2. Contested Strength (Jiujutsu/Strength)",
            value=f"{atk_cb.name}: ({str_a + jiu_a + cr_a}k{str_a}) → **{contest['total_a']}**\n"
                  f"{def_cb.name}: ({str_b + jiu_b + cr_b}k{str_b}) → **{contest['total_b']}**\n"
                  f"{'**Attacker wins** - grapple established!' if atk_wins else '**Defender resists** - grab fails!'}",
            inline=False,
        )
        if atk_wins:
            grappled = True
            atk_cb.conditions.add("grappled")
            def_cb.conditions.add("grappled")
            embed.colour = discord.Color.green()
            embed.add_field(
                name="Result",
                value=f"Both **{atk_cb.name}** and **{def_cb.name}** are now **Grappled**.\n"
                      f"{atk_cb.name} has initial control.",
                inline=False,
            )
        else:
            embed.add_field(
                name="Result",
                value=f"**{def_cb.name}** breaks the grab. {atk_cb.name}'s Complex Action is spent.",
                inline=False,
            )
    atk_cb.actions_used = 2
    _d.save_encounter(guild, enc)
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    tag = "GRAPPLED" if grappled else ("RESISTED" if hit else "MISS")
    await _d.combat_log(guild, f"Grapple: {atk_cb.name} → {def_cb.name} {tag}")


@combat_grapple.command(name="control", description="Contested Jiujutsu/Strength roll for grapple control. [Fortune]")
@app_commands.describe(
    combatant_a="First grapple participant.",
    combatant_b="Second grapple participant.",
)
async def grapple_control(
    interaction: discord.Interaction,
    combatant_a: str,
    combatant_b: str,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb_a = enc.find(combatant_a)
    cb_b = enc.find(combatant_b)
    if cb_a is None:
        await interaction.response.send_message(f"No combatant named **{combatant_a}**.", ephemeral=True)
        return
    if cb_b is None:
        await interaction.response.send_message(f"No combatant named **{combatant_b}**.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    rec_a = _d.resolve_combatant_record(guild, cb_a)
    rec_b = _d.resolve_combatant_record(guild, cb_b)
    if rec_a is None or rec_b is None:
        await interaction.response.send_message(
            "Both combatants need stored character sheets for grapple control.", ephemeral=True
        )
        return
    str_a = rec_a.character.strength
    jiu_a = rec_a.character.skills.get("Jiujutsu", 0)
    str_b = rec_b.character.strength
    jiu_b = rec_b.character.skills.get("Jiujutsu", 0)
    wp_a = stats.wound_penalty(rec_a.character)
    wp_b = stats.wound_penalty(rec_b.character)
    ar_a, af_a, _ = condition_effects.contested_roll_modifier(cb_a.conditions)
    ar_b, af_b, _ = condition_effects.contested_roll_modifier(cb_b.conditions)
    ar_a -= cb_a.fear_penalty; ar_b -= cb_b.fear_penalty
    result = combat.resolve_grapple_control(str_a, jiu_a, str_b, jiu_b, _d.engine, wp_a, wp_b,
                                            ar_a, af_a, ar_b, af_b)
    if result["winner"] == "a":
        winner, loser = cb_a.name, cb_b.name
    elif result["winner"] == "b":
        winner, loser = cb_b.name, cb_a.name
    else:
        winner = "Tie (previous controller retains)"
        loser = ""
    embed = discord.Embed(
        title="🤼 Grapple Control: Contested Jiujutsu/Strength",
        color=discord.Color.blue(),
    )
    embed.add_field(
        name=cb_a.name,
        value=f"({str_a + jiu_a + ar_a}k{str_a}) → **{result['total_a']}**",
        inline=True,
    )
    embed.add_field(
        name=cb_b.name,
        value=f"({str_b + jiu_b + ar_b}k{str_b}) → **{result['total_b']}**",
        inline=True,
    )
    if loser:
        embed.add_field(name="Control", value=f"**{winner}** has control.", inline=False)
    else:
        embed.add_field(name="Control", value=f"**{winner}**", inline=False)
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(guild, f"Grapple Control: {winner} wins")


@combat_grapple.command(name="hit", description="Grapple Hit: Unarmed damage on a grappled opponent (no attack roll). [Fortune]")
@app_commands.describe(
    attacker="The combatant in control (dealing damage).",
    target="The grapple participant receiving damage.",
)
async def grapple_hit(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    atk_cb = enc.find(attacker)
    def_cb = enc.find(target)
    if atk_cb is None:
        await interaction.response.send_message(f"No combatant named **{attacker}**.", ephemeral=True)
        return
    if def_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(atk_cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{atk_cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    if atk_cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{atk_cb.name}** has already used actions this turn ({atk_cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    atk_rec = _d.resolve_combatant_record(guild, atk_cb)
    def_rec = _d.resolve_combatant_record(guild, def_cb)
    if atk_rec is None:
        await interaction.response.send_message(f"No character sheet for **{attacker}**.", ephemeral=True)
        return
    if def_rec is None:
        await interaction.response.send_message(f"No character sheet for **{target}**.", ephemeral=True)
        return
    atk_cb.actions_used = 2
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🤼 Grapple Hit: {atk_cb.name} strikes {def_cb.name}",
        description="Unarmed damage, no attack roll (controller's Complex Action).",
        color=discord.Color.orange(),
    )
    view = DamageView(
        atk_rec.id, def_rec.id, "unarmed", 0,
        atk_cb.name, def_cb.name,
        maneuver="none", attack_margin=0,
        defender_stance="attack",
        channel_id=interaction.channel_id,
    )
    await interaction.response.send_message(
        content=f"{_d.dm_ping(interaction.guild)}A DM can authorize the damage below.",
        embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
    )
    await view.persist(await interaction.original_response())


@combat_grapple.command(name="throw", description="Grapple Throw: Target becomes Prone and leaves the grapple. [Fortune]")
@app_commands.describe(
    thrower="The combatant in control (throwing).",
    target="The combatant being thrown.",
)
async def grapple_throw(
    interaction: discord.Interaction,
    thrower: str,
    target: str,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    thrower_cb = enc.find(thrower)
    target_cb = enc.find(target)
    if thrower_cb is None:
        await interaction.response.send_message(f"No combatant named **{thrower}**.", ephemeral=True)
        return
    if target_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(thrower_cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{thrower_cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    if thrower_cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{thrower_cb.name}** has already used actions this turn ({thrower_cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
        return
    thrower_cb.conditions.discard("grappled")
    thrower_cb.conditions.add("prone")
    target_cb.conditions.discard("grappled")
    target_cb.conditions.discard("pinned")
    target_cb.conditions.add("prone")
    thrower_cb.actions_used = 2
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🤼 {thrower_cb.name} throws {target_cb.name}",
        description=(
            f"Both are now **Prone**. The grapple ends.\n"
            f"Standing up is a Simple Action."
        ),
        color=discord.Color.orange(),
    )
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(guild, f"Grapple Throw: {thrower_cb.name} throws {target_cb.name} (both prone, grapple ends)")


@combat_grapple.command(name="pin", description="Grapple Pin: Immobilize the target (Complex Action, controller only). [Fortune]")
@app_commands.describe(
    controller="The combatant in control.",
    target="The grapple participant being pinned.",
)
@app_commands.autocomplete(controller=_combatant_autocomplete, target=_combatant_autocomplete)
async def grapple_pin(
    interaction: discord.Interaction,
    controller: str,
    target: str,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    ctrl_cb = enc.find(controller)
    tgt_cb = enc.find(target)
    if ctrl_cb is None:
        await interaction.response.send_message(f"No combatant named **{controller}**.", ephemeral=True)
        return
    if tgt_cb is None:
        await interaction.response.send_message(f"No combatant named **{target}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(ctrl_cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{ctrl_cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    if ctrl_cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{ctrl_cb.name}** has already used actions this turn ({ctrl_cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
        return
    tgt_cb.conditions.add("pinned")
    ctrl_cb.actions_used = 2
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🤼 {ctrl_cb.name} pins {tgt_cb.name}",
        description=(
            f"{tgt_cb.name} is **Pinned**: Fully immobilized. "
            f"Can only speak or cast verbal-only Mastery 1 spells.\n"
            f"Pin is a prerequisite for Bind."
        ),
        color=discord.Color.orange(),
    )
    embed.set_footer(text=f"Applied by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(guild, f"Grapple Pin: {ctrl_cb.name} pins {tgt_cb.name}")


@combat_grapple.command(name="break_free", description="Break free from a grapple (controller: Simple, defender: Complex contested). [Fortune]")
@app_commands.describe(
    combatant="The combatant trying to break free.",
    opponent="The grapple opponent (required for defender break-free contested roll; omit for controller break).",
)
@app_commands.autocomplete(combatant=_combatant_autocomplete, opponent=_combatant_autocomplete)
async def grapple_break(
    interaction: discord.Interaction,
    combatant: str,
    opponent: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(combatant)
    if cb is None:
        await interaction.response.send_message(f"No combatant named **{combatant}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    guild = str(interaction.guild_id)

    if opponent is None:
        if cb.actions_used >= 2:
            await interaction.response.send_message(
                f"**{cb.name}** has already used actions this turn ({cb.actions_used}/2). "
                f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
            return
        cb.conditions.discard("grappled")
        cb.conditions.discard("pinned")
        cb.actions_used += 1
        _d.save_encounter(guild, enc)
        embed = discord.Embed(
            title=f"🤼 {cb.name} breaks free",
            description=(
                f"Controller break (Simple Action). Grappled condition removed.\n"
                f"[{cb.actions_used}/2 actions used]"
            ),
            color=discord.Color.green(),
        )
        embed.set_footer(text=f"Applied by {interaction.user.display_name}")
        await interaction.response.send_message(embed=embed)
        await _d.combat_log(guild, f"Grapple Break: {cb.name} breaks free (controller)")
        return

    opp_cb = enc.find(opponent)
    if opp_cb is None:
        await interaction.response.send_message(f"No combatant named **{opponent}**.", ephemeral=True)
        return
    if cb.actions_used > 0:
        await interaction.response.send_message(
            f"**{cb.name}** has already used actions this turn ({cb.actions_used}/2). "
            f"Use `/fight action action_type:Reset` to override.", ephemeral=True)
        return
    rec_cb = _d.resolve_combatant_record(guild, cb)
    rec_opp = _d.resolve_combatant_record(guild, opp_cb)
    if rec_cb is None or rec_opp is None:
        await interaction.response.send_message(
            "Both combatants need stored character sheets for contested break-free.", ephemeral=True)
        return
    str_def = rec_cb.character.strength
    jiu_def = rec_cb.character.skills.get("Jiujutsu", 0)
    str_ctrl = rec_opp.character.strength
    jiu_ctrl = rec_opp.character.skills.get("Jiujutsu", 0)
    wp_def = stats.wound_penalty(rec_cb.character)
    wp_ctrl = stats.wound_penalty(rec_opp.character)
    ar_def, af_def, _ = condition_effects.contested_roll_modifier(cb.conditions)
    ar_ctrl, af_ctrl, _ = condition_effects.contested_roll_modifier(opp_cb.conditions)
    result = combat.resolve_grapple_control(str_def, jiu_def, str_ctrl, jiu_ctrl, _d.engine, wp_def, wp_ctrl,
                                            ar_def, af_def, ar_ctrl, af_ctrl)
    defender_wins = result["winner"] == "a"
    cb.actions_used = 2
    embed = discord.Embed(
        title=f"🤼 {cb.name} tries to break free from {opp_cb.name}",
        color=discord.Color.green() if defender_wins else discord.Color.red(),
    )
    embed.add_field(
        name=f"{cb.name} (Jiujutsu/Strength)",
        value=f"({str_def + jiu_def}k{str_def}) → **{result['total_a']}**",
        inline=True,
    )
    embed.add_field(
        name=f"{opp_cb.name} (Jiujutsu/Strength)",
        value=f"({str_ctrl + jiu_ctrl}k{str_ctrl}) → **{result['total_b']}**",
        inline=True,
    )
    if defender_wins:
        cb.conditions.discard("grappled")
        cb.conditions.discard("pinned")
        embed.add_field(
            name="Result",
            value=f"**{cb.name}** breaks free! Grappled condition removed.",
            inline=False,
        )
    else:
        embed.add_field(
            name="Result",
            value=f"**{cb.name}** fails to escape. {opp_cb.name} retains control.",
            inline=False,
        )
    _d.save_encounter(guild, enc)
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    tag = "FREE" if defender_wins else "HELD"
    await _d.combat_log(guild, f"Grapple Break: {cb.name} vs {opp_cb.name} → {tag}")

# ===========================================================================
# /duel group: Iaijutsu dueling (s40)
# ===========================================================================



@combat_duel.command(name="assess", description="Assessment stage: Both duelists roll Iaijutsu(Assessment)/Awareness. [Fortune]")
@app_commands.describe(
    duelist_a="First duelist (combatant name or character).",
    duelist_b="Second duelist (combatant name or character).",
    a_is_npc="First duelist is a stored NPC.",
    b_is_npc="Second duelist is a stored NPC.",
    a_member="First duelist is another player's character.",
    b_member="Second duelist is another player's character.",
)
async def duel_assess(
    interaction: discord.Interaction,
    duelist_a: str,
    duelist_b: str,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _d.resolve_duelist(guild, ch, duelist_a, a_is_npc, a_member)
    rec_b = _d.resolve_duelist(guild, ch, duelist_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{duelist_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{duelist_b}**.", ephemeral=True)
        return

    ca, cb_char = rec_a.character, rec_b.character
    if await _d.refuse_if_cannot_act(interaction, ca) or await _d.refuse_if_cannot_act(interaction, cb_char):
        return

    enc = _d.encounters.get(ch)
    for duelist_char, duelist_label in ((ca, duelist_a), (cb_char, duelist_b)):
        cb_enc = enc.find(duelist_char.name) if enc else None
        if cb_enc and "dazed" in cb_enc.conditions:
            await interaction.response.send_message(
                f"**{duelist_label}** is Dazed and cannot perform an Iaijutsu duel.",
                ephemeral=True,
            )
            return

    ir_a = stats.insight_rank(ca)
    ir_b = stats.insight_rank(cb_char)
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb_char)
    cb_a_enc = enc.find(ca.name) if enc else None
    cb_b_enc = enc.find(cb_char.name) if enc else None
    conds_a = cb_a_enc.conditions if cb_a_enc else set()
    conds_b = cb_b_enc.conditions if cb_b_enc else set()
    cr_a, cf_a, _ = condition_effects.contested_roll_modifier(conds_a)
    cr_b, cf_b, _ = condition_effects.contested_roll_modifier(conds_b)

    tr_a, tk_a, tf_a, tn_a = technique_effects.iaijutsu_roll_bonus(ca, "assessment")
    tr_b, tk_b, tf_b, tn_b = technique_effects.iaijutsu_roll_bonus(cb_char, "assessment")
    ex9_a, ex9n_a = technique_effects.iaijutsu_explode_9(ca, "assessment")
    ex9_b, ex9n_b = technique_effects.iaijutsu_explode_9(cb_char, "assessment")
    tech_notes_a = tn_a + ex9n_a
    tech_notes_b = tn_b + ex9n_b
    fear_a = cb_a_enc.fear_penalty if cb_a_enc else 0
    fear_b = cb_b_enc.fear_penalty if cb_b_enc else 0
    cr_a -= fear_a; cr_b -= fear_b
    if fear_a: tech_notes_a = tech_notes_a + [f"Fear -{fear_a}k0"]
    if fear_b: tech_notes_b = tech_notes_b + [f"Fear -{fear_b}k0"]

    res_a = combat.resolve_iaijutsu_assessment(
        ca.awareness, ca.skills.get("Iaijutsu", 0), ir_b, _d.engine,
        extra_flat=wp_a + tf_a + cf_a, bonus_rolled=tr_a + cr_a, bonus_kept=tk_a,
        explode_9=ex9_a,
    )
    res_b = combat.resolve_iaijutsu_assessment(
        cb_char.awareness, cb_char.skills.get("Iaijutsu", 0), ir_a, _d.engine,
        extra_flat=wp_b + tf_b + cf_b, bonus_rolled=tr_b + cr_b, bonus_kept=tk_b,
        explode_9=ex9_b,
    )

    diff_ab = res_a["total"] - res_b["total"]
    focus_bonus = ""
    if diff_ab >= 10:
        focus_bonus = f"⚡ **{ca.name}** exceeded by {diff_ab} → **+1k1** on Focus roll."
    elif diff_ab <= -10:
        focus_bonus = f"⚡ **{cb_char.name}** exceeded by {-diff_ab} → **+1k1** on Focus roll."

    embed = discord.Embed(title=f"⚔️ Iaijutsu Duel: Assessment", color=discord.Color.gold())

    def _reveal_text(res, opponent):
        if not res["success"]:
            return "Failed: No information learned."
        reveals = res["reveals"]
        opponent_ir = stats.insight_rank(opponent)
        opponent_iaijutsu = opponent.skills.get("Iaijutsu", 0)
        available = [
            f"Void Ring: **{opponent.void_ring}**",
            f"Reflexes: **{opponent.reflexes}**",
            f"Iaijutsu Skill: **{opponent_iaijutsu}**",
            f"Iaijutsu Emphases: **{'Assessment, Focus' if opponent_iaijutsu >= 1 else 'none listed'}**",
            f"Void Points: **{opponent.current_void_points}**",
            f"Wound Level: **{stats.wound_level_name(opponent)}**",
        ]
        chosen = available[: reveals]
        return "Learned " + str(reveals) + ":\n" + "\n".join(chosen)

    def _duel_notes(wp, tech_notes):
        parts = []
        if wp:
            parts.append(f"wound penalty {wp}")
        parts.extend(tech_notes)
        return f"\n({', '.join(parts)})" if parts else ""

    embed.add_field(
        name=f"{ca.name}: Assessment",
        value=(
            f"{res_a['rolled']}k{res_a['kept']} → **{res_a['total']}** vs TN **{res_a['tn']}**"
            f": {'**SUCCESS**' if res_a['success'] else '**FAILED**'}"
            + _duel_notes(wp_a, tech_notes_a)
            + "\n" + _reveal_text(res_a, cb_char)
        ),
        inline=False,
    )
    embed.add_field(
        name=f"{cb_char.name}: Assessment",
        value=(
            f"{res_b['rolled']}k{res_b['kept']} → **{res_b['total']}** vs TN **{res_b['tn']}**"
            f": {'**SUCCESS**' if res_b['success'] else '**FAILED**'}"
            + _duel_notes(wp_b, tech_notes_b)
            + "\n" + _reveal_text(res_b, ca)
        ),
        inline=False,
    )
    if focus_bonus:
        embed.add_field(name="Focus Bonus", value=focus_bonus.strip(), inline=False)
    embed.set_footer(text="Either duelist may concede after Assessment. Otherwise: /duel focus")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Duel Assess: {ca.name} vs {cb_char.name}")


@combat_duel.command(name="focus", description="Focus stage: Contested Iaijutsu(Focus)/Void roll. [Fortune]")
@app_commands.describe(
    duelist_a="First duelist.",
    duelist_b="Second duelist.",
    a_focus_bonus="Duelist A got +1k1 from Assessment (exceeded by 10+).",
    b_focus_bonus="Duelist B got +1k1 from Assessment (exceeded by 10+).",
    a_is_npc="First duelist is a stored NPC.",
    b_is_npc="Second duelist is a stored NPC.",
    a_member="First duelist is another player's character.",
    b_member="Second duelist is another player's character.",
)
async def duel_focus(
    interaction: discord.Interaction,
    duelist_a: str,
    duelist_b: str,
    a_focus_bonus: bool = False,
    b_focus_bonus: bool = False,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _d.resolve_duelist(guild, ch, duelist_a, a_is_npc, a_member)
    rec_b = _d.resolve_duelist(guild, ch, duelist_b, b_is_npc, b_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{duelist_a}**.", ephemeral=True)
        return
    if rec_b is None:
        await interaction.response.send_message(f"No character found for **{duelist_b}**.", ephemeral=True)
        return

    ca, cb_char = rec_a.character, rec_b.character
    if await _d.refuse_if_cannot_act(interaction, ca) or await _d.refuse_if_cannot_act(interaction, cb_char):
        return

    enc = _d.encounters.get(ch)
    for duelist_char, duelist_label in ((ca, duelist_a), (cb_char, duelist_b)):
        cb_enc = enc.find(duelist_char.name) if enc else None
        if cb_enc and "dazed" in cb_enc.conditions:
            await interaction.response.send_message(
                f"**{duelist_label}** is Dazed and cannot perform an Iaijutsu duel.",
                ephemeral=True,
            )
            return
    cb_a_enc = enc.find(ca.name) if enc else None
    cb_b_enc = enc.find(cb_char.name) if enc else None
    conds_a = cb_a_enc.conditions if cb_a_enc else set()
    conds_b = cb_b_enc.conditions if cb_b_enc else set()
    cr_a, cf_a, _ = condition_effects.contested_roll_modifier(conds_a)
    cr_b, cf_b, _ = condition_effects.contested_roll_modifier(conds_b)

    bonus_r_a = 1 if a_focus_bonus else 0
    bonus_k_a = 1 if a_focus_bonus else 0
    bonus_r_b = 1 if b_focus_bonus else 0
    bonus_k_b = 1 if b_focus_bonus else 0
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb_char)

    tr_a, tk_a, tf_a, tn_a = technique_effects.iaijutsu_roll_bonus(ca, "focus")
    tr_b, tk_b, tf_b, tn_b = technique_effects.iaijutsu_roll_bonus(cb_char, "focus")
    ex9_a, ex9n_a = technique_effects.iaijutsu_explode_9(ca, "focus")
    ex9_b, ex9n_b = technique_effects.iaijutsu_explode_9(cb_char, "focus")
    wt_a, rd_a, ftn_a = technique_effects.iaijutsu_focus_thresholds(ca)
    wt_b, rd_b, ftn_b = technique_effects.iaijutsu_focus_thresholds(cb_char)
    tech_notes_a = tn_a + ex9n_a + ftn_a
    tech_notes_b = tn_b + ex9n_b + ftn_b
    fear_a = cb_a_enc.fear_penalty if cb_a_enc else 0
    fear_b = cb_b_enc.fear_penalty if cb_b_enc else 0
    cr_a -= fear_a; cr_b -= fear_b
    if fear_a: tech_notes_a = tech_notes_a + [f"Fear -{fear_a}k0"]
    if fear_b: tech_notes_b = tech_notes_b + [f"Fear -{fear_b}k0"]

    result = combat.resolve_iaijutsu_focus(
        ca.void_ring, ca.skills.get("Iaijutsu", 0),
        cb_char.void_ring, cb_char.skills.get("Iaijutsu", 0),
        _d.engine,
        bonus_rolled_a=bonus_r_a + tr_a + cr_a, bonus_kept_a=bonus_k_a + tk_a,
        bonus_rolled_b=bonus_r_b + tr_b + cr_b, bonus_kept_b=bonus_k_b + tk_b,
        extra_flat_a=wp_a + tf_a + cf_a, extra_flat_b=wp_b + tf_b + cf_b,
        explode_9_a=ex9_a, explode_9_b=ex9_b,
        win_threshold_a=wt_a, win_threshold_b=wt_b,
        raise_divisor_a=rd_a, raise_divisor_b=rd_b,
    )

    embed = discord.Embed(title="⚔️ Iaijutsu Duel: Focus", color=discord.Color.dark_gold())
    a_mods = []
    b_mods = []
    if a_focus_bonus:
        a_mods.append("+1k1 Assessment")
    if wp_a:
        a_mods.append(f"wound {wp_a}")
    a_mods.extend(tech_notes_a)
    if b_focus_bonus:
        b_mods.append("+1k1 Assessment")
    if wp_b:
        b_mods.append(f"wound {wp_b}")
    b_mods.extend(tech_notes_b)
    a_notes = f" ({', '.join(a_mods)})" if a_mods else ""
    b_notes = f" ({', '.join(b_mods)})" if b_mods else ""
    embed.add_field(
        name=f"{ca.name}: Focus (Iaijutsu/Void)",
        value=f"{result['a_rolled']}k{result['a_kept']}{a_notes} → **{result['a_total']}**",
        inline=True,
    )
    embed.add_field(
        name=f"{cb_char.name}: Focus (Iaijutsu/Void)",
        value=f"{result['b_rolled']}k{result['b_kept']}{b_notes} → **{result['b_total']}**",
        inline=True,
    )

    diff = abs(result["diff"])
    fs = result["first_striker"]
    if fs == "kharmic":
        outcome = (
            f"Margin **{diff}** - neither exceeds their threshold: **Kharmic Strike** (simultaneous).\n"
            f"Both attack at the same time; the cause is considered dropped."
        )
    else:
        winner = ca.name if fs == "a" else cb_char.name
        loser = cb_char.name if fs == "a" else ca.name
        fr = result["free_raises"]
        fr_text = f" with **{fr} Free Raise{'s' if fr != 1 else ''}**" if fr else ""
        outcome = (
            f"**{winner}** wins Focus by {diff} → strikes first{fr_text}.\n"
            f"**{loser}** may strike after if still alive."
        )
    embed.add_field(name="Result", value=outcome, inline=False)
    embed.set_footer(text="Proceed to: /duel strike")
    await interaction.response.send_message(embed=embed)
    if fs == "kharmic":
        await _d.combat_log(str(interaction.guild_id), f"Duel Focus: {ca.name} vs {cb_char.name}: Kharmic Strike")
    else:
        winner = ca.name if fs == "a" else cb_char.name
        await _d.combat_log(str(interaction.guild_id), f"Duel Focus: {winner} strikes first (margin {diff})")


@combat_duel.command(name="strike", description="Strike stage: Iaijutsu/Reflexes attack roll + damage. [Fortune]")
@app_commands.describe(
    attacker="The duelist striking.",
    target="The opponent being struck.",
    weapon="Weapon used (default: Katana).",
    free_raises="Free Raises from Focus (auto-applied to damage total).",
    bonus_tn="DM situational modifier to the target's Armor TN.",
    attacker_npc="Attacker is a stored NPC.",
    target_npc="Target is a stored NPC.",
    attacker_member="Attacker is another player's character.",
    target_member="Target is another player's character.",
)
async def duel_strike(
    interaction: discord.Interaction,
    attacker: str,
    target: str,
    weapon: str = "katana",
    free_raises: int = 0,
    bonus_tn: int = 0,
    attacker_npc: bool = False,
    target_npc: bool = False,
    attacker_member: discord.Member | None = None,
    target_member: discord.Member | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    ch = interaction.channel_id
    rec_a = _d.resolve_duelist(guild, ch, attacker, attacker_npc, attacker_member)
    rec_t = _d.resolve_duelist(guild, ch, target, target_npc, target_member)
    if rec_a is None:
        await interaction.response.send_message(f"No character found for **{attacker}**.", ephemeral=True)
        return
    if rec_t is None:
        await interaction.response.send_message(f"No character found for **{target}**.", ephemeral=True)
        return

    atk = rec_a.character
    tgt = rec_t.character
    if await _d.refuse_if_cannot_act(interaction, atk) or await _d.refuse_if_cannot_act(interaction, tgt):
        return
    wound_pen = stats.wound_penalty(atk)

    enc = _d.encounters.get(ch)
    atk_enc = enc.find(atk.name) if enc else None
    atk_conds = atk_enc.conditions if atk_enc else set()
    cr, cf, _ = condition_effects.contested_roll_modifier(atk_conds)

    tr, tk, tf, tech_notes = technique_effects.iaijutsu_roll_bonus(atk, "strike")
    fear_s = atk_enc.fear_penalty if atk_enc else 0
    cr -= fear_s
    if fear_s:
        tech_notes = tech_notes + [f"Fear -{fear_s}k0"]
    def_tn_bonus, def_tn_notes = technique_effects.defender_armor_tn_bonus(tgt, "center")
    target_tn = combat.armor_tn(tgt, "center", bonus_tn) + def_tn_bonus
    duel_red, duel_red_notes = technique_effects.iaijutsu_strike_reduction(tgt)

    result = combat.resolve_iaijutsu_strike(
        atk.reflexes, atk.skills.get("Iaijutsu", 0), target_tn, _d.engine,
        free_raises=free_raises, extra_flat=wound_pen + tf + cf,
        bonus_rolled=tr + cr, bonus_kept=tk,
    )
    hit = result["hit"]
    _d.tally(interaction.channel_id, atk.name, "attacks")
    if hit:
        _d.tally(interaction.channel_id, atk.name, "hits")
    embed = discord.Embed(
        title=f"⚔️ {atk.name} strikes at {tgt.name}",
        color=discord.Color.red() if hit else discord.Color.greyple(),
    )
    roll_text = (
        f"Iaijutsu/Reflexes: {result['rolled']}k{result['kept']} → **{result['total']}**"
        f" vs TN **{result['tn']}**: {'**HIT**' if hit else '**MISS**'}"
    )
    notes = []
    if wound_pen:
        notes.append(f"wound penalty {wound_pen}")
    if free_raises:
        notes.append(f"{free_raises} Free Raise{'s' if free_raises != 1 else ''} from Focus")
    notes.extend(tech_notes)
    notes.extend(def_tn_notes)
    notes.extend(duel_red_notes)
    if notes:
        roll_text += f"\n({', '.join(notes)})"
    embed.add_field(name="Strike Roll", value=roll_text, inline=False)

    view = None
    if hit:
        view = DamageView(
            attacker_id=rec_a.id,
            target_id=rec_t.id,
            weapon=weapon,
            increased_damage=free_raises,
            attacker_name=atk.name,
            target_name=tgt.name,
            maneuver="none",
            attack_margin=result["margin"],
            channel_id=interaction.channel_id,
            duel_strike_reduction=duel_red,
        )
    else:
        embed.set_footer(text="The strike misses.")

    if view is not None:
        await interaction.response.send_message(
            content=f"{_d.dm_ping(interaction.guild)}A DM can authorize the strike's damage below.",
            embed=embed, view=view, allowed_mentions=_PING_MENTIONS,
        )
        await view.persist(await interaction.original_response())
    else:
        await interaction.response.send_message(embed=embed)
    tag = "HIT" if hit else "MISS"
    await _d.combat_log(guild, f"Duel Strike: {atk.name} → {tgt.name} ({weapon}) {tag} (roll {result['total']} vs TN {result['tn']})")

@combat_group.command(name="creature", description="Add a spawned creature to initiative (rolls its initiative). [Fortune]")
@app_commands.describe(name="The creature to add.")
async def combat_creature(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec = _d.store.get_creature_by_name(str(interaction.guild_id), name)
    if rec is None:
        await interaction.response.send_message(f"No creature named **{name}**.", ephemeral=True)
        return
    if creature.creature_is_dead(rec.creature):
        await interaction.response.send_message(f"💀 **{rec.creature.name}** has been slain.", ephemeral=True)
        return
    result = creature.roll_creature_initiative(rec.creature, _d.engine)
    enc = _get_or_create(interaction.channel_id)
    enc.remove(rec.creature.name)
    enc.add(encounter.Combatant(
        name=rec.creature.name,
        initiative=result.total,
        initiative_detail=f"kept {result.kept_dice} = {result.total}",
        owner_id=None,
        is_npc=True,
        reflexes=rec.creature.air,
    ))
    enc.note_join(rec.creature.name, creature.creature_wound_level(rec.creature))
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    await interaction.response.send_message(_render_encounter(enc, guild), ephemeral=True)
    await _refresh_board(enc, guild)


@combat_group.command(
    name="category",
    description="Add all NPCs and creatures in a category to initiative. [Fortune]",
)
@app_commands.describe(category="Which category to add.")
async def combat_category(interaction: discord.Interaction, category: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    cat = _d.store.get_category(guild, category)
    if cat is None:
        await interaction.response.send_message(f"No category named **{category}**.", ephemeral=True)
        return
    members = _d.store.list_category_members(cat.id)
    if not members:
        await interaction.response.send_message(f"**{cat.name}** is empty.", ephemeral=True)
        return
    enc = _get_or_create(interaction.channel_id)
    added: list[str] = []
    not_found: list[str] = []
    for etype, ename in members:
        if etype == "npc":
            rec = _d.store.get_by_name(guild, _d.NPC_OWNER, ename)
            if rec is None:
                not_found.append(f"NPC {ename}")
                continue
            idr, idk, idn = technique_effects.initiative_dice_bonus(rec.character)
            result = combat.roll_initiative(rec.character, _d.engine, idr, idk)
            swift_bonus = 5 if "swift" in rec.character.weapon_qualities else 0
            ti, tin = technique_effects.initiative_bonus(rec.character)
            init_total = result.total + swift_bonus + ti
            swift_detail = f" +5 Swift" if swift_bonus else ""
            tech_init_detail = "".join(f" +{n}" for n in tin)
            dice_detail = "".join(f" [{n}]" for n in idn)
            enc.remove(rec.character.name)
            enc.add(encounter.Combatant(
                name=rec.character.name,
                initiative=init_total,
                initiative_detail=f"kept {result.kept_dice} = {result.total}{swift_detail}{tech_init_detail}{dice_detail}",
                owner_id=None,
                is_npc=True,
                reflexes=rec.character.reflexes,
            ))
            added.append(rec.character.name)
        else:
            rec_c = _d.store.get_creature_by_name(guild, ename)
            if rec_c is None:
                not_found.append(f"Creature {ename}")
                continue
            result = creature.roll_creature_initiative(rec_c.creature, _d.engine)
            enc.remove(rec_c.creature.name)
            enc.add(encounter.Combatant(
                name=rec_c.creature.name,
                initiative=result.total,
                initiative_detail=f"kept {result.kept_dice} = {result.total}",
                owner_id=None,
                is_npc=True,
                reflexes=rec_c.creature.air,
            ))
            added.append(rec_c.creature.name)
    _d.save_encounter(guild, enc)
    desc = f"Added {len(added)} creature(s) to initiative." if added else "No creatures added."
    if not_found:
        desc += f"\nNot found (skipped): {', '.join(not_found)}"
    embed = discord.Embed(
        title="⚔️ Category Join",
        color=discord.Color.green() if added else discord.Color.greyple(),
        description=desc[:4096],
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed, ephemeral=True)
    await _refresh_board(enc, guild)


@combat_group.command(
    name="room",
    description="Add all room members' active characters to initiative. [Fortune]",
)
async def combat_room(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec = _d.store.get_room_by_thread(str(interaction.channel_id))
    if rec is None:
        await interaction.response.send_message(
            "Run this inside a room's thread (open one with `/room create`).", ephemeral=True
        )
        return
    guild = str(interaction.guild_id)
    member_ids = _d.store.list_room_members(rec.id)
    enc = _get_or_create(interaction.channel_id)
    added: list[str] = []
    skipped: list[str] = []
    for uid in member_ids:
        char_rec = _d.store.get_active(guild, uid)
        if char_rec is None:
            skipped.append(f"<@{uid}>")
            continue
        idr, idk, idn = technique_effects.initiative_dice_bonus(char_rec.character)
        result = combat.roll_initiative(char_rec.character, _d.engine, idr, idk)
        swift_bonus = 5 if "swift" in char_rec.character.weapon_qualities else 0
        ti, tin = technique_effects.initiative_bonus(char_rec.character)
        init_total = result.total + swift_bonus + ti
        swift_detail = f" +5 Swift" if swift_bonus else ""
        tech_init_detail = "".join(f" +{n}" for n in tin)
        dice_detail = "".join(f" [{n}]" for n in idn)
        enc.remove(char_rec.character.name)
        enc.add(encounter.Combatant(
            name=char_rec.character.name,
            initiative=init_total,
            initiative_detail=f"kept {result.kept_dice} = {result.total}{swift_detail}{tech_init_detail}{dice_detail}",
            owner_id=uid,
            is_npc=False,
            reflexes=char_rec.character.reflexes,
        ))
        added.append(f"**{char_rec.character.name}** (init {init_total})")
    _d.save_encounter(guild, enc)
    desc_parts: list[str] = []
    if added:
        desc_parts.append("Added: " + ", ".join(added))
    if skipped:
        desc_parts.append("Skipped (no active character): " + ", ".join(skipped))
    if not added and not skipped:
        desc_parts.append("No members in this room.")
    embed = discord.Embed(
        title="⚔️ Room Join",
        color=discord.Color.green() if added else discord.Color.greyple(),
        description="\n".join(desc_parts)[:4096],
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    for entry in added:
        await _d.combat_log(guild, f"Room join: {entry}")
    await _refresh_board(enc, guild)

# ---------------------------------------------------------------------------
# Phase 42: Stance Tracking (#1)
# ---------------------------------------------------------------------------

_STANCE_CHOICES = [
    app_commands.Choice(name="Attack (standard)", value="attack"),
    app_commands.Choice(name="Full Attack (+2k1 hit, −10 ATN, no ranged)", value="full_attack"),
    app_commands.Choice(name="Defense (+Air+Defense to ATN, no attacks)", value="defense"),
    app_commands.Choice(name="Full Defense (use /fight full_defense)", value="full_defense"),
    app_commands.Choice(name="Center (forfeit actions, +1k1+Void next)", value="center"),
]


@fight_group.command(name="stance", description="Declare your stance for this turn (persists until your next turn).")
@app_commands.describe(
    name="Combatant name.",
    stance="Stance to adopt.",
)
@app_commands.choices(stance=_STANCE_CHOICES)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_stance(
    interaction: discord.Interaction,
    name: str,
    stance: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only set stance on your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    if stance.value not in encounter.VALID_STANCES:
        valid = ", ".join(s.replace("_", " ").title() for s in sorted(encounter.VALID_STANCES))
        await interaction.response.send_message(f"Invalid stance. Valid: {valid}.", ephemeral=True)
        return
    if stance.value == "full_defense":
        await interaction.response.send_message(
            f"Use `/fight full_defense combatant:{cb.name}` instead - Full Defense requires a Defense/Reflexes roll (Complex Action).",
            ephemeral=True,
        )
        return
    blocked, block_reason = condition_effects.invalid_stance(cb.conditions, stance.value)
    if blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot use that stance: {block_reason}", ephemeral=True)
        return
    cb.stance = stance.value
    if stance.value == "center":
        cb.center_bonus_available = False
        cb.center_init_boost = 0
    _d.save_encounter(str(interaction.guild_id), enc)
    label = stance.name
    effects = combat.stance_effects(stance.value)
    _STANCE_COLORS = {
        "attack": discord.Color.red(),
        "full_attack": discord.Color.dark_red(),
        "defense": discord.Color.blue(),
        "full_defense": discord.Color.dark_blue(),
        "center": discord.Color.gold(),
    }
    embed = discord.Embed(
        title=f"⚔️ {cb.name}: {label} Stance",
        color=_STANCE_COLORS.get(stance.value, discord.Color.blurple()),
    )
    if effects:
        embed.description = effects
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)
    await _d.combat_log(str(interaction.guild_id), f"Stance: {cb.name} → {label}")
    await _refresh_board(enc, str(interaction.guild_id))


@combat_turn.command(name="init", description="Adjust a combatant's initiative value. [Fortune]")
@app_commands.describe(
    name="Combatant name.",
    value="New initiative total.",
)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_init(
    interaction: discord.Interaction,
    name: str,
    value: app_commands.Range[int, -100, 200],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    old = cb.initiative
    cb.initiative = value
    enc._sort()
    if enc.started:
        cur = enc.current()
        if cur is not None:
            enc.turn_index = enc.combatants.index(cur)
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"🎲 {cb.name}: Initiative {old} → {value}",
        color=discord.Color.gold(),
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    await _refresh_board(enc, guild)


@combat_turn.command(name="hold", description="Mark a combatant as holding their action. [Fortune]")
@app_commands.describe(name="Combatant name.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_hold(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    current = enc.current()
    is_current = enc.started and current is not None and current.name.lower() == cb.name.lower()

    if cb.held:
        cb.held = False
        _d.save_encounter(guild, enc)
        embed = discord.Embed(
            title=f"▶️ {cb.name}: Hold released",
            color=discord.Color.green(),
        )
        embed.set_footer(text=f"Released by {interaction.user.display_name}")
        await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
        await _d.combat_log(guild, f"Hold: {cb.name} released")
        await _refresh_board(enc, guild)
        return

    cb.held = True
    if is_current:
        prev_round = enc.round
        next_cb = enc.advance()
        _d.save_encounter(guild, enc)
        mention = f"<@{next_cb.owner_id}> " if next_cb.owner_id and not next_cb.is_npc else ""
        desc_parts: list[str] = [f"➡️ It is now **{next_cb.name}**'s turn."]
        desc_parts.extend(_expiry_notes(enc))
        if next_cb.center_bonus_available:
            rec = _d.resolve_combatant_record(guild, next_cb)
            vr = rec.character.void_ring if rec else "?"
            desc_parts.append(f"🎯 **Center Stance bonus active**: +1k1 + {vr} (Void Ring) on one roll this turn. +10 Initiative this Round.")
        reminders = condition_effects.condition_reminders(next_cb.conditions)
        if reminders:
            desc_parts.append("\n".join(reminders))
        embed = discord.Embed(
            title=f"⏸️ {cb.name} holds their action",
            color=discord.Color.dark_gold(),
            description="\n".join(desc_parts),
        )
        embed.set_footer(text=f"Round {enc.round}")
        await interaction.response.send_message(content=f"{mention}{_render_encounter(enc, guild)}", embed=embed)
        if enc.round != prev_round:
            await _d.combat_log(guild, f"--- Round {enc.round} ---")
        await _d.combat_log(guild, f"Hold: {cb.name} held (auto-advance)")
        cond_str = f" [{', '.join(sorted(next_cb.conditions))}]" if next_cb.conditions else ""
        await _d.combat_log(guild, f"Turn: {next_cb.name}{cond_str}")
        await _refresh_board(enc, guild)
    else:
        _d.save_encounter(guild, enc)
        embed = discord.Embed(
            title=f"⏸️ {cb.name} holds their action",
            color=discord.Color.dark_gold(),
        )
        embed.set_footer(text=f"Set by {interaction.user.display_name}")
        await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
        await _d.combat_log(guild, f"Hold: {cb.name} held")
        await _refresh_board(enc, guild)


@combat_turn.command(name="delay", description="Mark a combatant as delaying. [Fortune]")
@app_commands.describe(name="Combatant name.", new_initiative="Optional new initiative value.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_delay(
    interaction: discord.Interaction,
    name: str,
    new_initiative: app_commands.Range[int, -100, 200] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    blocked, block_reason = condition_effects.cannot_act(cb.conditions)
    if blocked:
        await interaction.response.send_message(f"**{cb.name}** cannot act: {block_reason}", ephemeral=True)
        return
    guild = str(interaction.guild_id)
    current = enc.current()
    is_current = enc.started and current is not None and current.name.lower() == cb.name.lower()

    if cb.delayed:
        cb.delayed = False
        _d.save_encounter(guild, enc)
        embed = discord.Embed(
            title=f"▶️ {cb.name}: Delay released",
            color=discord.Color.green(),
        )
        embed.set_footer(text=f"Released by {interaction.user.display_name}")
        await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
        await _d.combat_log(guild, f"Delay: {cb.name} released")
        await _refresh_board(enc, guild)
        return

    cb.delayed = True
    init_note = ""

    if is_current:
        prev_round = enc.round
        next_cb = enc.advance()
        if new_initiative is not None:
            cb.initiative = new_initiative
            enc._sort()
            enc.turn_index = enc.combatants.index(next_cb)
            init_note = f" (init → {cb.initiative})"
        _d.save_encounter(guild, enc)
        mention = f"<@{next_cb.owner_id}> " if next_cb.owner_id and not next_cb.is_npc else ""
        delay_desc: list[str] = [f"➡️ It is now **{next_cb.name}**'s turn."]
        delay_desc.extend(_expiry_notes(enc))
        if next_cb.center_bonus_available:
            rec = _d.resolve_combatant_record(guild, next_cb)
            vr = rec.character.void_ring if rec else "?"
            delay_desc.append(f"🎯 **Center Stance bonus active**: +1k1 + {vr} (Void Ring) on one roll this turn. +10 Initiative this Round.")
        reminders = condition_effects.condition_reminders(next_cb.conditions)
        if reminders:
            delay_desc.append("\n".join(reminders))
        embed = discord.Embed(
            title=f"⏳ {cb.name} delays{init_note}",
            color=discord.Color.dark_gold(),
            description="\n".join(delay_desc),
        )
        embed.set_footer(text=f"Round {enc.round}")
        await interaction.response.send_message(content=f"{mention}{_render_encounter(enc, guild)}", embed=embed)
        if enc.round != prev_round:
            await _d.combat_log(guild, f"--- Round {enc.round} ---")
        await _d.combat_log(guild, f"Delay: {cb.name} delayed (auto-advance){init_note}")
        cond_str = f" [{', '.join(sorted(next_cb.conditions))}]" if next_cb.conditions else ""
        await _d.combat_log(guild, f"Turn: {next_cb.name}{cond_str}")
        await _refresh_board(enc, guild)
    else:
        if new_initiative is not None:
            cb.initiative = new_initiative
            enc._sort()
            if current is not None:
                enc.turn_index = enc.combatants.index(current)
            init_note = f" (init → {cb.initiative})"
        _d.save_encounter(guild, enc)
        embed = discord.Embed(
            title=f"⏳ {cb.name} delays{init_note}",
            color=discord.Color.dark_gold(),
        )
        embed.set_footer(text=f"Set by {interaction.user.display_name}")
        await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
        await _d.combat_log(guild, f"Delay: {cb.name} delayed{init_note}")
        await _refresh_board(enc, guild)


@combat_turn.command(name="act", description="A held/delayed combatant takes their action now. [Fortune]")
@app_commands.describe(name="Combatant name.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_act(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if not cb.held and not cb.delayed:
        await interaction.response.send_message(f"**{cb.name}** is not held or delayed.", ephemeral=True)
        return
    was = "held" if cb.held else "delayed"
    cb.held = False
    cb.delayed = False
    cb.actions_used = 0
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    embed = discord.Embed(
        title=f"▶️ {cb.name} acts now",
        color=discord.Color.green(),
        description=f"Was {was}.",
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)
    await _d.combat_log(guild, f"Act: {cb.name} (was {was})")
    await _refresh_board(enc, guild)


@combat_turn.command(name="done", description="End your turn (or a named combatant's turn). Advances to the next combatant.")
@app_commands.describe(name="Combatant whose turn to end (Fortune only). Omit to end your own character's turn.")
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_turn_done(
    interaction: discord.Interaction,
    name: str | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    if not enc.combatants:
        await interaction.response.send_message(_render_encounter(enc), ephemeral=True)
        return
    if not enc.started:
        await interaction.response.send_message("Encounter has not started yet. Use `/combat next` to begin.", ephemeral=True)
        return
    current = enc.current()
    if current is None:
        await interaction.response.send_message("No current combatant.", ephemeral=True)
        return
    is_dm = _d.is_dm(interaction)
    if name is not None:
        if not is_dm:
            await interaction.response.send_message(
                f"You need the **{_d.ROLE_FORTUNE}** (or **{_d.ROLE_KAMI}**) role to end another combatant's turn.", ephemeral=True
            )
            return
        if current.name.lower() != name.lower():
            await interaction.response.send_message(
                f"It is not **{name}**'s turn. Current turn: **{current.name}**.", ephemeral=True
            )
            return
    else:
        uid = str(interaction.user.id)
        if current.owner_id != uid and not is_dm:
            await interaction.response.send_message(
                f"It is not your turn. Current turn: **{current.name}**.", ephemeral=True
            )
            return
    ended_name = current.name
    prev_round = enc.round
    next_cb = enc.advance()
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    mention = f"<@{next_cb.owner_id}> " if next_cb.owner_id and not next_cb.is_npc else ""
    desc_parts: list[str] = [f"**{ended_name}**'s turn is done."]
    expiry = _expiry_notes(enc)
    if expiry:
        desc_parts.extend(expiry)
    if next_cb.center_bonus_available:
        rec = _d.resolve_combatant_record(guild, next_cb)
        vr = rec.character.void_ring if rec else "?"
        desc_parts.append(f"🎯 **Center Stance bonus active**: +1k1 + {vr} (Void Ring) on one roll this turn. +10 Initiative this Round.")
    reminders = condition_effects.condition_reminders(next_cb.conditions)
    if reminders:
        desc_parts.append("\n".join(reminders))
    embed = discord.Embed(
        title=f"➡️ {next_cb.name}'s Turn",
        color=discord.Color.green(),
        description="\n".join(desc_parts),
    )
    embed.set_footer(text=f"Round {enc.round}")
    tracker = _render_encounter(enc, guild)
    await interaction.response.send_message(content=f"{mention}{tracker}", embed=embed)
    if enc.round != prev_round:
        await _d.combat_log(guild, f"--- Round {enc.round} ---")
    await _d.combat_log(guild, f"Turn done: {ended_name}")
    cond_str = f" [{', '.join(sorted(next_cb.conditions))}]" if next_cb.conditions else ""
    await _d.combat_log(guild, f"Turn: {next_cb.name}{cond_str}")
    await _refresh_board(enc, guild)


@combat_turn.command(name="surprise", description="Toggle the surprise round flag on the current encounter. [Fortune]")
async def combat_surprise(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    enc.surprise_round = not enc.surprise_round
    guild = str(interaction.guild_id)
    _d.save_encounter(guild, enc)
    state = "ON" if enc.surprise_round else "OFF"
    embed = discord.Embed(
        title=f"❗ Surprise Round: {state}",
        color=discord.Color.orange() if enc.surprise_round else discord.Color.greyple(),
    )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, guild), embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Mass Battle (#3)
# ---------------------------------------------------------------------------




@combat_battle.command(name="roll", description="Battle/Perception roll to determine engagement level. [Fortune]")
@app_commands.describe(
    name="Character name.",
    tn="Battle TN set by DM (10-15 winning, 15-20 even, 20-30 losing, 30+ desperate).",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus (advantages, terrain, etc.).",
)
async def battle_roll(
    interaction: discord.Interaction,
    name: str,
    tn: app_commands.Range[int, 5, 100],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    battle_skill = c.skills.get("Battle", 0)
    wp = stats.wound_penalty(c)
    result = mass_battle.resolve_battle_roll(c.perception, battle_skill, tn, _d.engine, bonus + wp)
    info = result["engagement_info"]
    embed = discord.Embed(
        title=f"Mass Battle: {c.name}",
        color=discord.Color.red() if result["engagement"] in ("heavily_engaged", "heroic") else discord.Color.orange(),
    )
    roll_line = f"({result['rolled']}k{result['kept']}) = **{result['total']}** vs TN {tn}"
    effective_bonus = bonus + wp
    if effective_bonus != 0:
        roll_line += f" (mod {effective_bonus:+d}"
        if wp != 0:
            roll_line += f", wound {wp:+d}"
        roll_line += ")"
    embed.add_field(name="Roll", value=roll_line, inline=False)
    embed.add_field(name="Engagement", value=f"**{info['name']}**", inline=True)
    embed.add_field(name="Margin", value=f"{result['margin']:+d}", inline=True)
    embed.add_field(name="Description", value=info["description"], inline=False)
    dice_str = _d.format_dice(result["dice"])
    embed.add_field(name="Dice", value=dice_str[:1024], inline=False)
    embed.set_footer(text=f"Rolled by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)


@combat_battle.command(name="damage", description="Roll incidental damage from a mass battle round. [Fortune]")
@app_commands.describe(engagement="Engagement level from the battle roll.")
@app_commands.choices(engagement=[
    app_commands.Choice(name="Reserves (0 damage)", value="reserves"),
    app_commands.Choice(name="Disengaged (1k1)", value="disengaged"),
    app_commands.Choice(name="Engaged (2k1)", value="engaged"),
    app_commands.Choice(name="Heavily Engaged (3k2)", value="heavily_engaged"),
    app_commands.Choice(name="Heroic (4k3)", value="heroic"),
])
async def battle_damage(
    interaction: discord.Interaction,
    engagement: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    result = mass_battle.resolve_battle_turn_damage(engagement.value, _d.engine)
    if result["damage"] == 0:
        embed = discord.Embed(
            title=f"Mass Battle Damage: {engagement.name}",
            color=discord.Color.greyple(),
            description="No incidental damage this round.",
        )
        await interaction.response.send_message(embed=embed)
        return
    embed = discord.Embed(title=f"Mass Battle Damage: {engagement.name}", color=discord.Color.dark_red())
    embed.add_field(name="Damage", value=f"**{result['damage']}** ({result['rolled']}k{result['kept']})", inline=True)
    if result["dice"]:
        embed.add_field(name="Dice", value=_d.format_dice(result["dice"])[:1024], inline=False)
    embed.set_footer(text="Apply with /sheet wound or /npc wound, subtracting armor Reduction.")
    await interaction.response.send_message(embed=embed)


@combat_battle.command(name="table", description="Battle Table roll - individual experience in mass battle. [Fortune]")
@app_commands.describe(
    name="Character name.",
    army_status="Army Status for the character's side this round.",
    engagement="Character's declared engagement level this round.",
    member="Player whose character to use.",
    is_npc="Target is an NPC.",
    bonus="Flat bonus (advantages, terrain, wound penalties applied automatically).",
)
@app_commands.choices(
    army_status=[
        app_commands.Choice(name="Winning (general won contest by 5+)", value="winning"),
        app_commands.Choice(name="Stalemate (contest margin < 5)", value="stalemate"),
        app_commands.Choice(name="Losing (general lost contest by 5+)", value="losing"),
    ],
    engagement=[
        app_commands.Choice(name="Reserves (behind the lines)", value="reserves"),
        app_commands.Choice(name="Disengaged (near but not in combat)", value="disengaged"),
        app_commands.Choice(name="Engaged (in the thick of battle)", value="engaged"),
        app_commands.Choice(name="Heavily Engaged (at the very front)", value="heavily_engaged"),
    ],
)
async def battle_table(
    interaction: discord.Interaction,
    name: str,
    army_status: app_commands.Choice[str],
    engagement: app_commands.Choice[str],
    member: discord.Member | None = None,
    is_npc: bool = False,
    bonus: int = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec = _d.resolve_duelist(guild, interaction.channel_id, name, is_npc, member)
    if rec is None:
        await interaction.response.send_message(f"Character **{name}** not found.", ephemeral=True)
        return
    c = rec.character
    if await _d.refuse_if_cannot_act(interaction, c):
        return
    battle_skill = c.skills.get("Battle", 0)
    water = stats.water_ring(c)
    wp = stats.wound_penalty(c)
    result = mass_battle.resolve_battle_table(
        water, battle_skill, army_status.value, engagement.value, _d.engine, bonus + wp,
    )

    color = discord.Color.green()
    if result["event"] == "heroic":
        color = discord.Color.gold()
    elif result["event"] == "duel":
        color = discord.Color.purple()
    elif result["wounds_dice"] >= 4:
        color = discord.Color.red()
    elif result["wounds_dice"] >= 2:
        color = discord.Color.orange()

    embed = discord.Embed(title=f"Battle Table: {c.name}", color=color)

    roll_parts = f"1d10 ({result['die_result'].total}) + Water {water} + Battle {battle_skill}"
    effective_bonus = bonus + wp
    if effective_bonus != 0:
        roll_parts += f" + mod {effective_bonus:+d}"
        if wp != 0:
            roll_parts += f" (wound {wp:+d})"
    roll_parts += f" = **{result['total']}** (band {result['row_band']})"
    embed.add_field(name="Roll", value=roll_parts, inline=False)

    status_label = mass_battle.ARMY_STATUS_NAMES.get(army_status.value, army_status.value)
    eng_label = mass_battle.ENGAGEMENT_NAMES.get(engagement.value, engagement.value)
    embed.add_field(name="Army Status", value=status_label, inline=True)
    embed.add_field(name="Engagement", value=eng_label, inline=True)
    embed.add_field(name="Column", value=str(result["column"]), inline=True)

    lines: list[str] = []
    if result["wounds_dice"] > 0:
        lines.append(
            f"**{result['wounds_dice']}W** ({result['wounds_dice']}k{result['wounds_dice']}) "
            f"= **{result['wound_damage']} damage**"
        )
    else:
        lines.append("**0W** - no wounds this round")
    if result["glory"] > 0:
        lines.append(f"**+{result['glory']} Glory**")
    else:
        lines.append("No Glory")
    if result["event"] == "duel":
        lines.append("⚔️ **DUEL** - encounter an enemy of roughly equal skill!")
    elif result["event"] == "heroic":
        lines.append("✨ **HEROIC OPPORTUNITY** - a chance to change the battle!")
    embed.add_field(name="Result", value="\n".join(lines), inline=False)

    if result["wound_roll"]:
        embed.add_field(name="Wound Dice", value=_d.format_dice(result["wound_roll"])[:1024], inline=False)

    embed.set_footer(text="Apply wounds with /sheet wound or /npc wound, subtracting armor Reduction.")
    await interaction.response.send_message(embed=embed)


@combat_battle.command(name="status", description="Contested Battle/Perception between generals to determine Army Status. [Fortune]")
@app_commands.describe(
    general_a="General of Side A (character name).",
    general_b="General of Side B (character name).",
    a_is_npc="Side A general is a stored NPC.",
    b_is_npc="Side B general is a stored NPC.",
    a_member="Side A general belongs to this player.",
    b_member="Side B general belongs to this player.",
    bonus_a="Flat bonus for Side A (terrain, numbers, Heroic Opportunities, etc.).",
    bonus_b="Flat bonus for Side B (terrain, numbers, Heroic Opportunities, etc.).",
)
async def battle_status(
    interaction: discord.Interaction,
    general_a: str,
    general_b: str,
    a_is_npc: bool = False,
    b_is_npc: bool = False,
    a_member: discord.Member | None = None,
    b_member: discord.Member | None = None,
    bonus_a: int = 0,
    bonus_b: int = 0,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild = str(interaction.guild_id)
    rec_a = _d.resolve_duelist(guild, interaction.channel_id, general_a, a_is_npc, a_member)
    if rec_a is None:
        await interaction.response.send_message(f"General **{general_a}** not found.", ephemeral=True)
        return
    rec_b = _d.resolve_duelist(guild, interaction.channel_id, general_b, b_is_npc, b_member)
    if rec_b is None:
        await interaction.response.send_message(f"General **{general_b}** not found.", ephemeral=True)
        return
    ca, cb = rec_a.character, rec_b.character
    if await _d.refuse_if_cannot_act(interaction, ca) or await _d.refuse_if_cannot_act(interaction, cb):
        return
    wp_a = stats.wound_penalty(ca)
    wp_b = stats.wound_penalty(cb)
    battle_a = ca.skills.get("Battle", 0)
    battle_b = cb.skills.get("Battle", 0)
    result = mass_battle.resolve_general_contest(
        ca.perception, battle_a, cb.perception, battle_b,
        _d.engine, bonus_a + wp_a, bonus_b + wp_b,
    )

    status_a = mass_battle.ARMY_STATUS_NAMES.get(result["status_a"], result["status_a"])
    status_b = mass_battle.ARMY_STATUS_NAMES.get(result["status_b"], result["status_b"])

    if result["status_a"] == "winning":
        color = discord.Color.blue()
    elif result["status_b"] == "winning":
        color = discord.Color.red()
    else:
        color = discord.Color.greyple()

    embed = discord.Embed(title="Army Status: Contested Battle/Perception", color=color)

    a_line = f"({result['rolled_a']}k{result['kept_a']}) = **{result['total_a']}**"
    eff_a = bonus_a + wp_a
    if eff_a != 0:
        a_line += f" (mod {eff_a:+d})"
    embed.add_field(name=f"{ca.name}", value=f"{a_line}\nStatus: **{status_a}**", inline=True)

    b_line = f"({result['rolled_b']}k{result['kept_b']}) = **{result['total_b']}**"
    eff_b = bonus_b + wp_b
    if eff_b != 0:
        b_line += f" (mod {eff_b:+d})"
    embed.add_field(name=f"{cb.name}", value=f"{b_line}\nStatus: **{status_b}**", inline=True)

    embed.add_field(name="Margin", value=f"{result['diff']:+d} (need ±5 for Winning/Losing)", inline=False)

    dice_a = _d.format_dice(result["dice_a"])[:1024]
    dice_b = _d.format_dice(result["dice_b"])[:1024]
    embed.add_field(name=f"{ca.name} Dice", value=dice_a, inline=True)
    embed.add_field(name=f"{cb.name} Dice", value=dice_b, inline=True)

    embed.set_footer(text="Use the resulting status with /combat battle table for individual PCs.")
    await interaction.response.send_message(embed=embed)


def _sync_mount_to_sheet(guild: str, cb, mounting: bool) -> str:
    """Persist mounted state to the combatant's character sheet (if they have one).
    Updates is_mounted and adjusts riding armor TN bonus. Returns a note string."""
    if cb.is_npc:
        return ""
    rec = _d.store.get_by_name_guild(guild, cb.name)
    if rec is None:
        return ""
    c = rec.character
    c.is_mounted = mounting
    prof = combat.get_armor(c.armor_name) if c.armor_name else None
    if prof and prof.get("tn_bonus_mounted"):
        if mounting:
            c.armor_tn_bonus = prof["tn_bonus_mounted"]
        else:
            c.armor_tn_bonus = prof["tn_bonus"]
    _d.store.save(rec, note="mount" if mounting else "dismount")
    extra_parts = []
    if prof and prof.get("tn_bonus_mounted"):
        extra_parts.append(f" Armor TN bonus → +{c.armor_tn_bonus}.")
    return "".join(extra_parts)


# ---------------------------------------------------------------------------
# Phase 42: Mounted Combat (#10)
# ---------------------------------------------------------------------------

@fight_group.command(name="mount", description="Mount or dismount (sets/clears Mounted condition).")
@app_commands.describe(
    name="Combatant name.",
    dismount="Dismount instead of mounting.",
)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_mount(
    interaction: discord.Interaction,
    name: str,
    dismount: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only mount/dismount your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    guild = str(interaction.guild_id)
    if dismount:
        cb.conditions.discard("mounted")
        _d.save_encounter(guild, enc)
        extra = _sync_mount_to_sheet(guild, cb, False)
        embed = discord.Embed(
            title=f"🐴 {cb.name} dismounts",
            color=discord.Color.greyple(),
            description=extra or "Mounted condition cleared.",
        )
        embed.set_footer(text=f"Set by {interaction.user.display_name}")
        await interaction.response.send_message(embed=embed)
    else:
        cb.conditions.add("mounted")
        _d.save_encounter(guild, enc)
        extra = _sync_mount_to_sheet(guild, cb, True)
        embed = discord.Embed(
            title=f"🐴 {cb.name} mounts up",
            color=discord.Color.dark_gold(),
            description=(
                "+1k0 melee damage vs unmounted\n"
                "+1 rolled die on Horsemanship checks\n"
                "Mounted archery at -1k0 unless Mounted Archery emphasis"
                + (f"\n{extra}" if extra else "")
            ),
        )
        embed.set_footer(text=f"Set by {interaction.user.display_name}")
        await interaction.response.send_message(embed=embed)

# ---------------------------------------------------------------------------
# Phase 42: Multiple Attacks / Action Economy (#9)
# ---------------------------------------------------------------------------

@fight_group.command(name="action", description="Track action usage this turn (Simple or Complex).")
@app_commands.describe(
    name="Combatant name.",
    action_type="Type of action being taken.",
)
@app_commands.choices(action_type=[
    app_commands.Choice(name="Simple Action (1 of 2)", value="simple"),
    app_commands.Choice(name="Complex Action (uses both)", value="complex"),
    app_commands.Choice(name="Free Action (no cost)", value="free"),
    app_commands.Choice(name="Reset (undo)", value="reset"),
])
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_action(
    interaction: discord.Interaction,
    name: str,
    action_type: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    if not _is_own_combatant(interaction, cb) and not _d.is_dm(interaction):
        await interaction.response.send_message(
            f"You can only track actions for your own combatant, or ask a Fortune to do it.", ephemeral=True
        )
        return
    if action_type.value == "reset":
        cb.actions_used = 0
        _d.save_encounter(str(interaction.guild_id), enc)
        embed = discord.Embed(
            title=f"**{cb.name}**: Actions Reset",
            description="Actions reset to 0/2.",
            color=discord.Color.blue(),
        )
        await interaction.response.send_message(embed=embed)
        return
    if action_type.value == "free":
        embed = discord.Embed(
            title=f"**{cb.name}**: Free Action",
            color=discord.Color.blurple(),
        )
        await interaction.response.send_message(embed=embed)
        return
    if action_type.value == "complex":
        if cb.actions_used > 0:
            await interaction.response.send_message(f"**{cb.name}** has already used an action this turn.", ephemeral=True)
            return
        cb.actions_used = 2
        _d.save_encounter(str(interaction.guild_id), enc)
        embed = discord.Embed(
            title=f"**{cb.name}**: Complex Action",
            description="Turn used (2/2 actions).",
            color=discord.Color.orange(),
        )
        await interaction.response.send_message(embed=embed)
    else:
        if cb.actions_used >= 2:
            await interaction.response.send_message(f"**{cb.name}** has no actions remaining this turn.", ephemeral=True)
            return
        cb.actions_used += 1
        _d.save_encounter(str(interaction.guild_id), enc)
        remaining = 2 - cb.actions_used
        embed = discord.Embed(
            title=f"**{cb.name}**: Simple Action",
            description=f"{remaining} action{'s' if remaining != 1 else ''} remaining ({cb.actions_used}/2).",
            color=discord.Color.teal() if remaining > 0 else discord.Color.orange(),
        )
        await interaction.response.send_message(embed=embed)


# ---------------------------------------------------------------------------
# Phase 63: Combat Enhancements - cover, notes, env_damage
# ---------------------------------------------------------------------------

@combat_env.command(name="cover", description="Set a combatant's cover/terrain Armor TN bonus. [Fortune]")
@app_commands.describe(
    name="Combatant name.",
    bonus="Armor TN modifier from cover/terrain (positive = harder to hit, 0 = clear).",
)
@app_commands.autocomplete(name=_combatant_autocomplete)
async def combat_cover(
    interaction: discord.Interaction,
    name: str,
    bonus: app_commands.Range[int, -30, 30],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    cb = enc.find(name)
    if cb is None:
        await interaction.response.send_message(f"No combatant **{name}**.", ephemeral=True)
        return
    cb.cover_bonus = bonus
    _d.save_encounter(str(interaction.guild_id), enc)
    if bonus == 0:
        embed = discord.Embed(
            title=f"🏔️ {cb.name}: Cover cleared",
            color=discord.Color.greyple(),
        )
    else:
        sign = "+" if bonus > 0 else ""
        embed = discord.Embed(
            title=f"🏔️ {cb.name}: Cover {sign}{bonus} Armor TN",
            color=discord.Color.dark_teal(),
        )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, str(interaction.guild_id)), embed=embed)


@combat_env.command(name="notes", description="Set or clear environment notes for this encounter. [Fortune]")
@app_commands.describe(text="Environment description (leave blank to clear).")
async def combat_notes(
    interaction: discord.Interaction,
    text: str = "",
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    enc.notes = text.strip()
    _d.save_encounter(str(interaction.guild_id), enc)
    if enc.notes:
        embed = discord.Embed(
            title="📍 Environment",
            color=discord.Color.dark_teal(),
            description=f"*{enc.notes}*",
        )
    else:
        embed = discord.Embed(
            title="📍 Environment notes cleared",
            color=discord.Color.greyple(),
        )
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(content=_render_encounter(enc, str(interaction.guild_id)), embed=embed)


@combat_env.command(name="damage", description="Apply environmental damage to combatants. [Fortune]")
@app_commands.describe(
    amount="Raw damage to apply.",
    targets='Comma-separated combatant names, or "all".',
    reason="Source of damage (fire, falling, etc.).",
    ignore_reduction="Skip armor reduction (default: No - reduction applies).",
)
async def combat_env_damage(
    interaction: discord.Interaction,
    amount: app_commands.Range[int, 1, 500],
    targets: str,
    reason: str = "",
    ignore_reduction: bool = False,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    enc = await _d.require_encounter(interaction)
    if enc is None:
        return
    guild = str(interaction.guild_id)
    if targets.strip().lower() == "all":
        target_list = [cb.name for cb in enc.combatants]
    else:
        target_list = [t.strip() for t in targets.split(",") if t.strip()]
    if not target_list:
        await interaction.response.send_message("No targets specified.", ephemeral=True)
        return

    results: list[str] = []
    not_found: list[str] = []
    reason_tag = f" ({reason})" if reason else ""

    for tname in target_list:
        cb = enc.find(tname)
        if cb is None:
            not_found.append(tname)
            continue
        rec = _d.resolve_combatant_record(guild, cb)
        if rec is not None:
            reduction = 0 if ignore_reduction else rec.character.armor_reduction
            applied = combat.apply_damage(rec.character, amount, reduction)
            _d.store.save(rec, note="environmental damage")
            _d.tally(interaction.channel_id, rec.character.name, "taken", applied["final_damage"])
            if applied["is_dead"]:
                await _d.on_death(guild, rec.character.name, rec.owner_id, rec.id)
            dead_tag = " 💀 **DEAD**" if applied["is_dead"] else ""
            results.append(
                f"**{cb.name}**: {amount} raw − {reduction} red = "
                f"**{applied['final_damage']}** wounds → "
                f"**{applied['new_wound_level']}** ({rec.character.wounds_taken}){dead_tag}"
            )
            await _d.combat_log(
                guild,
                f"Env Damage: {cb.name}{reason_tag} "
                f"{applied['final_damage']} wounds [{applied['new_wound_level']}]"
                f"{' DEAD' if applied['is_dead'] else ''}",
            )
        else:
            cre_rec = _d.store.get_creature_by_name(guild, tname)
            if cre_rec is not None:
                cr = cre_rec.creature
                reduction = 0 if ignore_reduction else cr.reduction
                final = max(0, amount - reduction)
                cr.wounds_taken += final
                is_dead = cr.wounds_taken >= cr.wounds_dead
                _d.store.save_creature(cre_rec, note="environmental damage")
                _d.tally(interaction.channel_id, cr.name, "taken", final)
                if is_dead:
                    await _d.on_death(guild, cr.name, None, None)
                dead_tag = " 💀 **DEAD**" if is_dead else ""
                results.append(
                    f"**{cb.name}**: {amount} raw − {reduction} red = "
                    f"**{final}** wounds → {cr.wounds_taken}/{cr.wounds_dead}{dead_tag}"
                )
                await _d.combat_log(
                    guild,
                    f"Env Damage: {cb.name}{reason_tag} "
                    f"{final} wounds [{cr.wounds_taken}/{cr.wounds_dead}]"
                    f"{' DEAD' if is_dead else ''}",
                )
            else:
                results.append(f"**{cb.name}**: *(no sheet - damage not tracked)*")

    title = f"💥 Environmental Damage: {amount}{reason_tag}"
    if ignore_reduction:
        title += " (ignores reduction)"
    embed = discord.Embed(
        title=title,
        color=discord.Color.dark_red(),
        description="\n".join(results)[:4000],
    )
    if not_found:
        embed.add_field(name="Not found", value=", ".join(not_found), inline=False)
    embed.set_footer(text=f"Applied by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)

