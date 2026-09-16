"""NPC builder: a staff wizard with exact stats, a typed stat-block form, and
saveable NPC templates.

Wired into the /npc group by init(): /npc create (wizard), /npc form (typed
stat block) and the /npc template sub-group (save, spawn, list, view, delete).
Family and school bonuses, school skills, techniques and outfits come from the
same reference data the player wizard uses; nothing here invents a number.
"""

from __future__ import annotations

import copy
import re
from dataclasses import dataclass
from typing import Any, Awaitable, Callable

import discord
from discord import app_commands

import storage
from l5r_rules import advantages, combat, enums, families, schools, spells
from l5r_rules.character import Character

WIZARD_IDLE_SECONDS: float = 3600.0
MAX_SPAWN: int = 10

TRAIT_ORDER: list[str] = list(enums.TRAITS)  # ends with "void"
_TRAIT_ALIASES: dict[str, str] = {
    "sta": "stamina", "wil": "willpower", "will": "willpower", "str": "strength",
    "per": "perception", "ref": "reflexes", "awa": "awareness", "agi": "agility",
    "int": "intelligence", "void": "void", "v": "void",
}
for _t in enums.TRAITS:
    _TRAIT_ALIASES[_t] = _t

SKILL_CATEGORIES: dict[str, list[str]] = {
    "Bugei": [
        "Athletics", "Battle", "Defense", "Horsemanship", "Hunting", "Iaijutsu", "Jiujutsu",
        "Kenjutsu", "Knives", "Kyujutsu", "Naginatajutsu", "Polearms", "Spears", "Staves",
        "War Fan", "Chain Weapons", "Heavy Weapons", "Ninjutsu",
    ],
    "High": [
        "Artisan", "Calligraphy", "Courtier", "Divination", "Etiquette", "Games", "Investigation",
        "Lore", "Medicine", "Meditation", "Perform", "Sincerity", "Spellcraft", "Tea Ceremony", "Theology",
    ],
    "Low": [
        "Acting", "Commerce", "Engineering", "Forgery", "Intimidation", "Locksmith",
        "Sleight of Hand", "Stealth", "Temptation",
    ],
    "Merchant": ["Animal Handling", "Craft", "Sailing"],
}
# Skills that take a specialty in their name ("Lore: Shadowlands").
SPECIALTY_SKILLS: tuple[str, ...] = ("Artisan", "Craft", "Lore", "Perform", "Games")
ADV_CATEGORIES: list[str] = ["Physical", "Mental", "Social", "Material", "Spiritual", "Mystical"]


@dataclass
class _Deps:
    store: Any
    npc_owner: str
    require_guild: Callable[[discord.Interaction], Awaitable[bool]]
    require_dm_role: Callable[[discord.Interaction], Awaitable[bool]]
    is_dm: Callable[[discord.Interaction], bool]
    build_sheet_embed: Callable[[storage.CharacterRecord], discord.Embed]
    npc_autocomplete: Callable[..., Awaitable[list[app_commands.Choice[str]]]]


_d: _Deps = None  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Building a Character from a wizard/form state
# ---------------------------------------------------------------------------
def new_state(user_id: int, guild_id: int, name: str, notes: str = "") -> dict:
    return {
        "user_id": user_id, "guild_id": guild_id, "name": name, "notes": notes,
        "clan": "", "family": "", "school": "", "rank": 1,
        "traits": {},          # explicit overrides: trait -> value (void included)
        "skills": {},          # skill -> rank (explicit; school skills come from the school)
        "advantages": [], "disadvantages": [],
        "weapon": "", "off_hand": "", "armor": "",
        "honor": None, "glory": None, "status": None, "koku": None,
        "step": 0, "pending_trait": "", "skill_category": "", "adv_category": "", "disadv_category": "",
        "weapon_group": "",
    }


def state_from_record(rec: storage.CharacterRecord, user_id: int, guild_id: int) -> dict:
    """Seed the wizard with an existing NPC so every step shows its current values."""
    c = rec.character
    state = new_state(user_id, guild_id, c.name, c.notes or "")
    state.update({
        "edit_id": rec.id, "original": c.to_dict(),
        "clan": c.clan, "family": c.family, "school": c.school, "rank": c.school_rank,
        "traits": {t: (c.void_ring if t == "void" else c.get_trait(t)) for t in TRAIT_ORDER},
        "skills": dict(c.skills), "emphases": {k: list(v) for k, v in c.emphases.items()},
        "advantages": list(c.advantages), "disadvantages": list(c.disadvantages),
        "weapon": c.equipped_weapon, "off_hand": c.off_hand_weapon, "armor": c.armor_name or "none",
        "honor": c.honor, "glory": c.glory, "status": c.status, "koku": c.koku,
        "spells": list(c.spells_known), "school_type": c.school_type,
    })
    return state


def base_character(state: dict) -> Character:
    """Family + school applied, no explicit overrides. Defaults are the RAW 2s.
    When editing an existing NPC the base is the NPC as it is now."""
    if state.get("original"):
        c = Character.from_dict(copy.deepcopy(state["original"]))
        c.name = state["name"]
        return c
    c = Character(name=state["name"], is_npc=True)
    fam = families.get(state["family"]) if state.get("family") else None
    if fam:
        families.apply_to_character(c, fam)
        c.clan = fam["clan"]
    if state.get("clan"):
        c.clan = state["clan"]
    sch = schools.get(state["school"]) if state.get("school") else None
    if sch:
        schools.apply_to_character(c, sch)
    return c


def materialize(state: dict) -> Character:
    c = base_character(state)
    if state.get("original"):
        # Editing: identity fields are set directly; techniques follow the school and rank.
        c.clan = state.get("clan", "")
        c.family = state.get("family", "")
        c.school = state.get("school", "")
        c.skills = {}
        c.emphases = {}
        c.weapons = list(state.get("original", {}).get("weapons", []))
        c.spells_known = []
    c.school_rank = int(state.get("rank") or 1)
    if c.school and (not state.get("original") or c.school != state["original"].get("school")
                     or c.school_rank != state["original"].get("school_rank")):
        c.techniques = [t["name"] for t in schools.techniques_up_to(c.school, c.school_rank)]
    for trait, value in state.get("traits", {}).items():
        if trait == "void":
            c.void_ring = int(value)
            c.max_void_points = c.void_ring
            c.current_void_points = c.void_ring
        else:
            c.set_trait(trait, int(value))
    for skill, rank in state.get("skills", {}).items():
        if int(rank) <= 0:
            c.skills.pop(skill, None)
        else:
            c.skills[skill] = int(rank)
    for skill, emph in state.get("emphases", {}).items():
        if skill in c.skills:
            lst = c.emphases.setdefault(skill, [])
            for e in emph:
                if e not in lst:
                    lst.append(e)
    c.advantages = list(state.get("advantages", []))
    c.disadvantages = list(state.get("disadvantages", []))
    for key in ("weapon", "off_hand"):
        w = (state.get(key) or "").strip()
        if w:
            if w not in c.weapons:
                c.weapons.append(w)
            if key == "weapon":
                c.equipped_weapon = w
            else:
                c.off_hand_weapon = w
    if not c.equipped_weapon and not state.get("original"):
        # Nothing picked for the hand: wield the first catalog weapon from the school outfit,
        # because a character with nothing in hand attacks unarmed.
        for w in c.weapons:
            if w.lower() in combat.WEAPON_CATALOG:
                c.equipped_weapon = w.lower()
                break
    armor = (state.get("armor") or "").strip().lower()
    if armor and armor != "none":
        spec = combat.get_armor(armor)
        c.armor_name = armor
        if spec is not None:
            c.armor_tn_bonus = spec["tn_bonus"]
            c.armor_reduction = spec["reduction"]
    elif armor == "none":
        c.armor_name, c.armor_tn_bonus, c.armor_reduction = "", 0, 0
    for field in ("honor", "glory", "status", "koku"):
        if state.get(field) is not None:
            setattr(c, field, float(state[field]))
    for spell_name in state.get("spells", []):
        if spell_name not in c.spells_known:
            c.spells_known.append(spell_name)
    if state.get("school_type"):
        c.school_type = state["school_type"]
    c.notes = state.get("notes", "") or ""
    c.wounds_taken = int(state["original"].get("wounds_taken", 0)) if state.get("original") else 0
    return c


def preview_record(state: dict) -> storage.CharacterRecord:
    return storage.CharacterRecord(0, str(state["guild_id"]), _d.npc_owner, materialize(state))


def effective_trait(state: dict, trait: str) -> int:
    if trait in state.get("traits", {}):
        return int(state["traits"][trait])
    base = base_character(state)
    return base.void_ring if trait == "void" else base.get_trait(trait)


def _fmt_traits(state: dict) -> str:
    parts = []
    base = base_character(state)
    for t in TRAIT_ORDER:
        v = effective_trait(state, t)
        base_v = base.void_ring if t == "void" else base.get_trait(t)
        mark = "**" if v != base_v else ""
        parts.append(f"{mark}{'Void' if t == 'void' else t[:3].capitalize()} {v}{mark}")
    return " · ".join(parts)


# ---------------------------------------------------------------------------
# Saving: NPC and template
# ---------------------------------------------------------------------------
def _save_npc(guild_id: str, char: Character) -> tuple[storage.CharacterRecord | None, str]:
    try:
        rec = _d.store.create_character(guild_id, _d.npc_owner, char)
    except storage.DuplicateNameError:
        return None, f"An NPC named **{char.name}** already exists. Pick another name or delete it first."
    return rec, ""


def _save_template(guild_id: str, name: str, char: Character, created_by: str) -> bool:
    """Store a clean copy (no wounds) under the template name. True if it replaced an existing one."""
    tpl = copy.deepcopy(char)
    tpl.wounds_taken = 0
    existed = _d.store.get_npc_template(guild_id, name) is not None
    _d.store.save_npc_template(guild_id, name, tpl.to_dict(), created_by)
    return existed


class _SaveView(discord.ui.View):
    """Save NPC / Save as template / Save both / Cancel, after the wizard or the form."""

    def __init__(self, state: dict, back: Callable[[discord.Interaction], Awaitable[None]] | None = None) -> None:
        super().__init__(timeout=WIZARD_IDLE_SECONDS)
        self.state = state
        self.back = back
        self._done = False
        if back is None:
            self.remove_item(self.edit)
        if state.get("edit_id"):
            self.save_npc.label = "Save changes"
            self.save_both.label = "Save changes + template"

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your NPC builder.", ephemeral=True)
            return False
        if self._done:
            await interaction.response.send_message("Already saved.", ephemeral=True)
            return False
        return True

    async def _finish(self, interaction: discord.Interaction, as_npc: bool, as_template: bool) -> None:
        guild_id = str(self.state["guild_id"])
        char = materialize(self.state)
        lines: list[str] = []
        rec = None
        if as_npc and self.state.get("edit_id"):
            rec = _d.store.get_by_id(int(self.state["edit_id"]))
            if rec is None:
                await interaction.response.send_message("That NPC no longer exists.", ephemeral=True)
                return
            char.wounds_taken = rec.character.wounds_taken  # editing stats never heals
            rec.character = char
            _d.store.save(rec, note="npc edit wizard")
            lines.append(f"🎭 Updated NPC **{char.name}**.")
        elif as_npc:
            rec, err = _save_npc(guild_id, char)
            if err:
                await interaction.response.send_message(err, ephemeral=True)
                return
            lines.append(f"🎭 Saved NPC **{char.name}**.")
        if as_template:
            replaced = _save_template(guild_id, char.name, char, str(interaction.user.id))
            lines.append(
                f"📋 {'Replaced' if replaced else 'Saved'} template **{char.name}**: spawn copies with "
                f"`/npc template spawn template:{char.name}`."
            )
        self._done = True
        for child in self.children:
            child.disabled = True
        self.stop()
        if rec is not None:
            lines.append(f"View it with `/npc view name:{char.name}`; tweak with `/npc-edit`.")
        await interaction.response.edit_message(content="\n".join(lines), embed=None, view=self)

    @discord.ui.button(label="Save NPC", style=discord.ButtonStyle.success, emoji="🎭")
    async def save_npc(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        """Creates the NPC, or overwrites it when the wizard was opened with /npc edit."""
        await self._finish(interaction, True, False)

    @discord.ui.button(label="Save as template", style=discord.ButtonStyle.primary, emoji="📋")
    async def save_template(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        await self._finish(interaction, False, True)

    @discord.ui.button(label="Save both", style=discord.ButtonStyle.primary)
    async def save_both(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        await self._finish(interaction, True, True)

    @discord.ui.button(label="Back to editing", style=discord.ButtonStyle.secondary)
    async def edit(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        if self.back is not None:
            await self.back(interaction)

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.danger)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button) -> None:
        self._done = True
        self.stop()
        await interaction.response.edit_message(content="NPC discarded.", embed=None, view=None)


# ---------------------------------------------------------------------------
# The step-by-step wizard
# ---------------------------------------------------------------------------
STEPS: list[tuple[str, str]] = [
    ("clan", "Clan"), ("family", "Family"), ("school", "School and Rank"), ("traits", "Rings and Traits"),
    ("skills", "Skills"), ("advantages", "Advantages"), ("disadvantages", "Disadvantages"),
    ("gear", "Gear and numbers"), ("review", "Review and save"),
]


def _opt(label: str, value: str | None = None, description: str | None = None, default: bool = False) -> discord.SelectOption:
    return discord.SelectOption(label=label[:100], value=(value if value is not None else label)[:100],
                                description=(description or None) and description[:100], default=default)


class _Pick(discord.ui.Select):
    """A select whose choice is handled by the wizard: handler(interaction, value)."""

    def __init__(self, placeholder: str, options: list[discord.SelectOption], handler, row: int) -> None:
        super().__init__(placeholder=placeholder[:150], options=options[:25], row=row)
        self._handler = handler

    async def callback(self, interaction: discord.Interaction) -> None:
        await self._handler(interaction, self.values[0])


class _NumbersModal(discord.ui.Modal, title="Honor, Glory, Status, Koku"):
    honor = discord.ui.TextInput(label="Honor (0-10, e.g. 4.5)", required=False, max_length=5)
    glory = discord.ui.TextInput(label="Glory (0-10)", required=False, max_length=5)
    status = discord.ui.TextInput(label="Status (0-10)", required=False, max_length=5)
    koku = discord.ui.TextInput(label="Koku", required=False, max_length=8)
    notes = discord.ui.TextInput(label="Notes", required=False, max_length=1000, style=discord.TextStyle.paragraph)

    def __init__(self, wizard: "NpcWizard") -> None:
        super().__init__()
        self.wizard = wizard
        st = wizard.state
        for field in ("honor", "glory", "status", "koku"):
            if st.get(field) is not None:
                getattr(self, field).default = str(st[field])
        self.notes.default = st.get("notes", "") or ""

    async def on_submit(self, interaction: discord.Interaction) -> None:
        errors = []
        for field, lo, hi in (("honor", 0, 10), ("glory", 0, 10), ("status", 0, 10), ("koku", 0, 1_000_000)):
            raw = (getattr(self, field).value or "").strip()
            if not raw:
                self.wizard.state[field] = None
                continue
            try:
                val = float(raw)
            except ValueError:
                errors.append(f"{field}: '{raw}' is not a number")
                continue
            if not lo <= val <= hi:
                errors.append(f"{field}: must be between {lo} and {hi}")
                continue
            self.wizard.state[field] = val
        self.wizard.state["notes"] = (self.notes.value or "").strip()
        if errors:
            await interaction.response.send_message("Not applied:\n• " + "\n• ".join(errors), ephemeral=True)
            return
        await self.wizard.render(interaction)


class _CustomSkillModal(discord.ui.Modal, title="Skill with a specialty"):
    skill = discord.ui.TextInput(label="Skill as it appears on the sheet", placeholder="Lore: Shadowlands", max_length=60)
    rank = discord.ui.TextInput(label="Rank (0 removes)", placeholder="3", max_length=2)
    emphasis = discord.ui.TextInput(label="Emphasis (optional)", required=False, max_length=40)

    def __init__(self, wizard: "NpcWizard", base_skill: str = "") -> None:
        super().__init__()
        self.wizard = wizard
        if base_skill:
            self.skill.default = f"{base_skill}: "

    async def on_submit(self, interaction: discord.Interaction) -> None:
        name = self.skill.value.strip().rstrip(":").strip()
        try:
            rank = int(self.rank.value.strip())
        except ValueError:
            await interaction.response.send_message("Rank must be a whole number.", ephemeral=True)
            return
        if not 0 <= rank <= 10 or not name:
            await interaction.response.send_message("Rank must be 0-10 and the skill needs a name.", ephemeral=True)
            return
        self.wizard.state["skills"][name] = rank
        emph = (self.emphasis.value or "").strip()
        if emph and rank > 0:
            self.wizard.state.setdefault("emphases", {}).setdefault(name, [])
            if emph not in self.wizard.state["emphases"][name]:
                self.wizard.state["emphases"][name].append(emph)
        await self.wizard.render(interaction)


class NpcWizard(discord.ui.View):
    """One view re-rendered per step. Row 4 is always the navigation row."""

    def __init__(self, state: dict) -> None:
        super().__init__(timeout=WIZARD_IDLE_SECONDS)
        self.state = state
        self.build()

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != int(self.state["user_id"]):
            await interaction.response.send_message("This isn't your NPC builder.", ephemeral=True)
            return False
        return True

    async def on_timeout(self) -> None:
        pass  # ephemeral message; nothing to clean up

    # -- rendering -----------------------------------------------------------
    def _step_key(self) -> str:
        return STEPS[self.state["step"]][0]

    def header(self) -> str:
        idx = self.state["step"]
        key, title = STEPS[idx]
        st = self.state
        mode = "Editing NPC" if st.get("edit_id") else "NPC builder"
        line = f"**{mode}: {st['name']}** · Step {idx + 1}/{len(STEPS)}: {title}"
        hints = {
            "clan": "Pick the clan (or none). It only filters families and schools.",
            "family": "The family adds its +1 Trait, like a player character.",
            "school": "The school adds its Benefit, starting skills, Honor and outfit; Rank sets the techniques known.",
            "traits": f"Pick a trait, then its value. Bold = changed from the base.\n{_fmt_traits(st)}",
            "skills": "Pick a category, a skill, then its rank (0 removes). Lore, Craft, Artisan, Perform and Games take a specialty.",
            "advantages": "Pick a category, then an advantage to add; pick it again to remove it.",
            "disadvantages": "Pick a category, then a disadvantage to add; pick it again to remove it.",
            "gear": "Weapon in hand, off-hand, armor. The Numbers button sets Honor, Glory, Status, Koku and notes.",
            "review": "Check the sheet, then save it as an NPC, as a reusable template, or both.",
        }
        return f"{line}\n{hints.get(key, '')}"

    def embed(self) -> discord.Embed:
        return _d.build_sheet_embed(preview_record(self.state))

    async def render(self, interaction: discord.Interaction) -> None:
        self.build()
        if self._step_key() == "review":
            view = _SaveView(self.state, back=self._back_from_review)
            await interaction.response.edit_message(content=self.header(), embed=self.embed(), view=view)
            return
        await interaction.response.edit_message(content=self.header(), embed=self.embed(), view=self)

    async def _back_from_review(self, interaction: discord.Interaction) -> None:
        self.state["step"] = len(STEPS) - 2
        await self.render(interaction)

    # -- components per step -------------------------------------------------
    def build(self) -> None:
        self.clear_items()
        key = self._step_key()
        st = self.state
        if key == "clan":
            clans = schools.creation_clans()[:24]
            opts = [_opt("(no clan)", "", default=not st["clan"])] + [_opt(c, default=c == st["clan"]) for c in clans]
            self.add_item(_Pick("Clan...", opts, self._on_clan, 0))
        elif key == "family":
            fams = families.by_clan(st["clan"]) if st["clan"] else []
            opts = [_opt("(no family)", "", default=not st["family"])] + [
                _opt(f["name"], description=f"+1 {f['bonus_trait'].capitalize()}", default=f["name"] == st["family"]) for f in fams
            ]
            self.add_item(_Pick("Family..." if fams else "No families for this clan", opts, self._on_family, 0))
        elif key == "school":
            pool = schools.basic_for_clan(st["clan"]) if st["clan"] else schools.basic()
            opts = [_opt("(no school)", "", default=not st["school"])] + [
                _opt(s["name"], description=(s.get("keywords") or "")[:100] or None, default=s["name"] == st["school"]) for s in pool
            ]
            self.add_item(_Pick("School...", opts, self._on_school, 0))
            self.add_item(_Pick("School Rank...", [_opt(f"Rank {r}", str(r), default=r == int(st["rank"])) for r in range(1, 6)],
                                self._on_rank, 1))
        elif key == "traits":
            opts = [_opt("Void" if t == "void" else t.capitalize(), t, description=f"now {effective_trait(st, t)}",
                         default=t == st["pending_trait"]) for t in TRAIT_ORDER]
            self.add_item(_Pick("Trait...", opts, self._on_trait, 0))
            if st["pending_trait"]:
                label = "Void" if st["pending_trait"] == "void" else st["pending_trait"].capitalize()
                self.add_item(_Pick(f"{label} value...", [_opt(str(v), str(v)) for v in range(1, 11)], self._on_trait_value, 1))
            reset = discord.ui.Button(label="Reset traits to family/school base", style=discord.ButtonStyle.secondary, row=2)
            reset.callback = self._on_trait_reset
            self.add_item(reset)
        elif key == "skills":
            cats = list(SKILL_CATEGORIES)
            self.add_item(_Pick("Skill category...", [_opt(c, default=c == st["skill_category"]) for c in cats], self._on_skill_cat, 0))
            if st["skill_category"]:
                current = materialize(st).skills
                opts = [_opt(s, description=f"rank {current[s]}" if s in current else None) for s in SKILL_CATEGORIES[st["skill_category"]]]
                self.add_item(_Pick("Skill...", opts, self._on_skill, 1))
            if st.get("pending_skill"):
                self.add_item(_Pick(f"{st['pending_skill']} rank...", [_opt(str(r), str(r)) for r in range(0, 11)], self._on_skill_rank, 2))
            custom = discord.ui.Button(label="Skill with specialty / emphasis", style=discord.ButtonStyle.secondary, row=3)
            custom.callback = self._on_custom_skill
            self.add_item(custom)
        elif key in ("advantages", "disadvantages"):
            kind = "advantage" if key == "advantages" else "disadvantage"
            cat_key = "adv_category" if key == "advantages" else "disadv_category"
            cats = [c for c in ADV_CATEGORIES if any(a.get("category") == c for a in advantages.by_kind(kind))]
            self.add_item(_Pick("Category...", [_opt(c, default=c == st[cat_key]) for c in cats], self._on_adv_cat, 0))
            if st[cat_key]:
                chosen = st[key]
                opts = [_opt(("✓ " if a["name"] in chosen else "") + a["name"], a["name"], description=a.get("cost_text") or None)
                        for a in advantages.by_kind(kind) if a.get("category") == st[cat_key]]
                self.add_item(_Pick(f"{kind.capitalize()}...", opts, self._on_adv, 1))
        elif key == "gear":
            groups = sorted({w["skill"] for w in combat.WEAPON_CATALOG.values()})
            self.add_item(_Pick("Weapon group...", [_opt(g, default=g == st["weapon_group"]) for g in groups], self._on_weapon_group, 0))
            if st["weapon_group"]:
                opts = [_opt(("✓ " if k == st["weapon"] else "") + k.replace("_", " "), k, description=f"DR {w['rolled']}k{w['kept']}")
                        for k, w in combat.WEAPON_CATALOG.items() if w["skill"] == st["weapon_group"]]
                self.add_item(_Pick("Weapon in hand...", opts, self._on_weapon, 1))
                self.add_item(_Pick("Off-hand (optional)...", [_opt("(none)", "")] + opts, self._on_off_hand, 2))
            armor_opts = [_opt("(no armor)", "none", default=st["armor"] in ("", "none"))] + [
                _opt(k.replace("_", " "), k, description=f"ATN +{a['tn_bonus']}, Reduction {a['reduction']}", default=k == st["armor"])
                for k, a in combat.ARMOR_CATALOG.items()
            ]
            self.add_item(_Pick("Armor...", armor_opts, self._on_armor, 3))
            numbers = discord.ui.Button(label="Numbers: Honor, Glory, Status, Koku, notes", style=discord.ButtonStyle.secondary, row=4)
            numbers.callback = self._on_numbers
            self.add_item(numbers)
        if key != "gear":
            self._nav_row(4)
        else:
            self._nav_row(4, compact=True)

    def _nav_row(self, row: int, compact: bool = False) -> None:
        idx = self.state["step"]
        back = discord.ui.Button(label="Back", style=discord.ButtonStyle.secondary, row=row, disabled=idx == 0)
        nxt = discord.ui.Button(label="Review" if idx == len(STEPS) - 2 else "Next", style=discord.ButtonStyle.primary, row=row)
        back.callback = self._on_back
        nxt.callback = self._on_next
        self.add_item(back)
        self.add_item(nxt)
        if not compact:
            save = discord.ui.Button(label="Skip to save", style=discord.ButtonStyle.success, row=row)
            save.callback = self._on_skip_to_save
            self.add_item(save)
            cancel = discord.ui.Button(label="Cancel", style=discord.ButtonStyle.danger, row=row)
            cancel.callback = self._on_cancel
            self.add_item(cancel)

    # -- handlers ------------------------------------------------------------
    async def _on_back(self, interaction: discord.Interaction) -> None:
        self.state["step"] = max(0, self.state["step"] - 1)
        await self.render(interaction)

    async def _on_next(self, interaction: discord.Interaction) -> None:
        self.state["step"] = min(len(STEPS) - 1, self.state["step"] + 1)
        await self.render(interaction)

    async def _on_skip_to_save(self, interaction: discord.Interaction) -> None:
        self.state["step"] = len(STEPS) - 1
        await self.render(interaction)

    async def _on_cancel(self, interaction: discord.Interaction) -> None:
        self.stop()
        await interaction.response.edit_message(content="NPC builder closed. Nothing was saved.", embed=None, view=None)

    async def _on_clan(self, interaction: discord.Interaction, value: str) -> None:
        if value != self.state["clan"]:
            self.state["family"] = ""
            self.state["school"] = ""
        self.state["clan"] = value
        self.state["step"] = 1 if value else 2
        await self.render(interaction)

    async def _on_family(self, interaction: discord.Interaction, value: str) -> None:
        self.state["family"] = value
        self.state["step"] = 2
        await self.render(interaction)

    async def _on_school(self, interaction: discord.Interaction, value: str) -> None:
        self.state["school"] = value
        await self.render(interaction)

    async def _on_rank(self, interaction: discord.Interaction, value: str) -> None:
        self.state["rank"] = int(value)
        await self.render(interaction)

    async def _on_trait(self, interaction: discord.Interaction, value: str) -> None:
        self.state["pending_trait"] = value
        await self.render(interaction)

    async def _on_trait_value(self, interaction: discord.Interaction, value: str) -> None:
        trait = self.state["pending_trait"]
        if trait:
            self.state["traits"][trait] = int(value)
        self.state["pending_trait"] = ""
        await self.render(interaction)

    async def _on_trait_reset(self, interaction: discord.Interaction) -> None:
        self.state["traits"] = {}
        self.state["pending_trait"] = ""
        await self.render(interaction)

    async def _on_skill_cat(self, interaction: discord.Interaction, value: str) -> None:
        self.state["skill_category"] = value
        self.state["pending_skill"] = ""
        await self.render(interaction)

    async def _on_skill(self, interaction: discord.Interaction, value: str) -> None:
        if value in SPECIALTY_SKILLS:
            await interaction.response.send_modal(_CustomSkillModal(self, value))
            return
        self.state["pending_skill"] = value
        await self.render(interaction)

    async def _on_skill_rank(self, interaction: discord.Interaction, value: str) -> None:
        skill = self.state.get("pending_skill", "")
        if skill:
            self.state["skills"][skill] = int(value)
        self.state["pending_skill"] = ""
        await self.render(interaction)

    async def _on_custom_skill(self, interaction: discord.Interaction) -> None:
        await interaction.response.send_modal(_CustomSkillModal(self))

    async def _on_adv_cat(self, interaction: discord.Interaction, value: str) -> None:
        key = "adv_category" if self._step_key() == "advantages" else "disadv_category"
        self.state[key] = value
        await self.render(interaction)

    async def _on_adv(self, interaction: discord.Interaction, value: str) -> None:
        lst: list[str] = self.state[self._step_key()]
        if value in lst:
            lst.remove(value)
        else:
            lst.append(value)
        await self.render(interaction)

    async def _on_weapon_group(self, interaction: discord.Interaction, value: str) -> None:
        self.state["weapon_group"] = value
        await self.render(interaction)

    async def _on_weapon(self, interaction: discord.Interaction, value: str) -> None:
        self.state["weapon"] = "" if value == self.state["weapon"] else value
        await self.render(interaction)

    async def _on_off_hand(self, interaction: discord.Interaction, value: str) -> None:
        self.state["off_hand"] = value
        await self.render(interaction)

    async def _on_armor(self, interaction: discord.Interaction, value: str) -> None:
        self.state["armor"] = value
        await self.render(interaction)

    async def _on_numbers(self, interaction: discord.Interaction) -> None:
        await interaction.response.send_modal(_NumbersModal(self))


class _NameModal(discord.ui.Modal, title="New NPC"):
    npc_name = discord.ui.TextInput(label="NPC name", placeholder="e.g. Bandit Captain Goro", min_length=1, max_length=64)
    notes = discord.ui.TextInput(label="Notes (optional)", required=False, max_length=1000, style=discord.TextStyle.paragraph)

    async def on_submit(self, interaction: discord.Interaction) -> None:
        name = self.npc_name.value.strip()
        guild_id = str(interaction.guild_id)
        if _d.store.get_by_name(guild_id, _d.npc_owner, name) is not None:
            await interaction.response.send_message(
                f"An NPC named **{name}** already exists. Pick another name or delete it first.", ephemeral=True)
            return
        state = new_state(interaction.user.id, interaction.guild_id, name, (self.notes.value or "").strip())
        wizard = NpcWizard(state)
        await interaction.response.send_message(content=wizard.header(), embed=wizard.embed(), view=wizard, ephemeral=True)


# ---------------------------------------------------------------------------
# The typed stat-block form
# ---------------------------------------------------------------------------
class ParseError(ValueError):
    pass


def _split_items(text: str) -> list[str]:
    return [p.strip() for p in re.split(r"[,;\n]+", text or "") if p.strip()]


def parse_traits(text: str) -> dict[str, int]:
    """'Sta 3 Wil 2 Str 3 ... Void 2' (names or abbreviations, ':' or '=' allowed)."""
    out: dict[str, int] = {}
    if not (text or "").strip():
        return out
    for m in re.finditer(r"([A-Za-z]+)\s*[:=]?\s*(\d+)", text):
        key = m.group(1).lower()
        trait = _TRAIT_ALIASES.get(key)
        if trait is None:
            raise ParseError(f"Unknown trait '{m.group(1)}'. Use Sta, Wil, Str, Per, Ref, Awa, Agi, Int, Void.")
        val = int(m.group(2))
        if not 1 <= val <= 10:
            raise ParseError(f"{trait.capitalize()} must be 1-10, got {val}.")
        out[trait] = val
    leftover = re.sub(r"([A-Za-z]+)\s*[:=]?\s*(\d+)", "", text)
    if re.search(r"[A-Za-z0-9]", leftover):
        raise ParseError(f"Could not read traits near '{leftover.strip()[:30]}'. Format: Sta 3 Wil 2 Str 3 Per 2 Ref 3 Awa 2 Agi 3 Int 2 Void 2")
    return out


def parse_skills(text: str) -> tuple[dict[str, int], dict[str, list[str]]]:
    """'Kenjutsu 3 (Katana), Defense 2, Lore: Shadowlands 2'."""
    skills: dict[str, int] = {}
    emphases: dict[str, list[str]] = {}
    for item in _split_items(text):
        m = re.match(r"^(.*?)\s*(?:\(([^)]*)\))?\s*(\d+)\s*(?:\(([^)]*)\))?$", item)
        if not m or not m.group(1).strip():
            raise ParseError(f"Could not read skill '{item}'. Format: Kenjutsu 3 (Katana), Lore: Shadowlands 2")
        name = m.group(1).strip().rstrip(":").strip()
        rank = int(m.group(3))
        if not 0 <= rank <= 10:
            raise ParseError(f"{name} rank must be 0-10.")
        skills[name] = rank
        emph = (m.group(2) or m.group(4) or "").strip()
        if emph:
            emphases.setdefault(name, []).extend(e.strip() for e in emph.split("/") if e.strip())
    return skills, emphases


def parse_keyed(text: str) -> dict[str, str]:
    """'weapon: katana; armor: light; adv: Large, Quick' -> {'weapon': 'katana', ...}"""
    out: dict[str, str] = {}
    for part in re.split(r"[;\n]+", text or ""):
        if not part.strip():
            continue
        if ":" not in part and "=" not in part:
            raise ParseError(f"Expected 'key: value' but got '{part.strip()[:40]}'.")
        key, val = re.split(r"[:=]", part, maxsplit=1)
        out[key.strip().lower()] = val.strip()
    return out


_GEAR_KEYS = {"weapon", "off", "off_hand", "offhand", "armor", "adv", "advantages", "advantage",
              "disadv", "disadvantages", "disadvantage", "spells", "spell"}
_DETAIL_KEYS = {"clan", "family", "school", "rank", "type", "honor", "glory", "status", "koku", "notes"}


def form_to_state(user_id: int, guild_id: int, name: str, traits_text: str, skills_text: str,
                  gear_text: str, details_text: str) -> tuple[dict, list[str]]:
    """Build a wizard state from the typed form. Returns (state, warnings). Raises ParseError."""
    warnings: list[str] = []
    state = new_state(user_id, guild_id, name)
    details = parse_keyed(details_text)
    for k in details:
        if k not in _DETAIL_KEYS:
            raise ParseError(f"Unknown detail '{k}'. Use clan, family, school, rank, type, honor, glory, status, koku, notes.")
    if details.get("clan"):
        state["clan"] = details["clan"].strip().title()
    if details.get("family"):
        fam = families.get(details["family"])
        if fam is None:
            raise ParseError(f"No family named '{details['family']}'. See /ref family list.")
        state["family"] = fam["name"]
        state["clan"] = state["clan"] or fam["clan"]
    if details.get("school"):
        sch = schools.get(details["school"])
        if sch is None:
            raise ParseError(f"No school named '{details['school']}'. See /ref school search.")
        state["school"] = sch["name"]
        state["clan"] = state["clan"] or sch["clan"]
    if details.get("rank"):
        try:
            state["rank"] = int(details["rank"])
        except ValueError:
            raise ParseError("rank must be a whole number 1-5.")
        if not 1 <= state["rank"] <= 5:
            raise ParseError("rank must be 1-5.")
    if details.get("type"):
        state["school_type"] = details["type"].strip().capitalize()
    for field, lo, hi in (("honor", 0, 10), ("glory", 0, 10), ("status", 0, 10), ("koku", 0, 1_000_000)):
        if details.get(field):
            try:
                val = float(details[field])
            except ValueError:
                raise ParseError(f"{field} must be a number.")
            if not lo <= val <= hi:
                raise ParseError(f"{field} must be between {lo} and {hi}.")
            state[field] = val
    if details.get("notes"):
        state["notes"] = details["notes"]

    # Traits in the form are final values; the family/school bonus is not added on top.
    state["traits"] = parse_traits(traits_text)
    if state["traits"] and (state["family"] or state["school"]):
        base = base_character(state)
        for t in TRAIT_ORDER:
            if t not in state["traits"]:
                state["traits"][t] = base.void_ring if t == "void" else base.get_trait(t)
    skills, emph = parse_skills(skills_text)
    state["skills"] = skills
    state["emphases"] = emph

    gear = parse_keyed(gear_text)
    for k in gear:
        if k not in _GEAR_KEYS:
            raise ParseError(f"Unknown gear key '{k}'. Use weapon, off, armor, adv, disadv, spells.")
    weapon = gear.get("weapon", "").strip().lower().replace(" ", "_")
    if weapon:
        if weapon not in combat.WEAPON_CATALOG:
            warnings.append(f"'{gear['weapon']}' is not in the weapon catalog; kept as a custom weapon name (no damage rating).")
        state["weapon"] = weapon
    off = (gear.get("off") or gear.get("off_hand") or gear.get("offhand") or "").strip().lower().replace(" ", "_")
    if off:
        if off not in combat.WEAPON_CATALOG:
            warnings.append(f"'{off}' is not in the weapon catalog; kept as a custom off-hand name.")
        state["off_hand"] = off
    armor = gear.get("armor", "").strip().lower().replace(" ", "_")
    if armor:
        if armor != "none" and combat.get_armor(armor) is None:
            raise ParseError(f"Unknown armor '{gear['armor']}'. Options: {', '.join(combat.ARMOR_CATALOG)} or none.")
        state["armor"] = armor
    for key, kind, target in (("adv", "advantage", "advantages"), ("advantages", "advantage", "advantages"),
                              ("advantage", "advantage", "advantages"), ("disadv", "disadvantage", "disadvantages"),
                              ("disadvantages", "disadvantage", "disadvantages"), ("disadvantage", "disadvantage", "disadvantages")):
        for item in _split_items(gear.get(key, "")):
            entry = advantages.get(item.split(":")[0].strip(), kind)
            canonical = item if entry is None else (entry["name"] + item[len(entry["name"]):] if item.lower().startswith(entry["name"].lower()) else item)
            if entry is None:
                warnings.append(f"'{item}' is not a catalog {kind}; kept as written.")
            if canonical not in state[target]:
                state[target].append(canonical)
    for key in ("spells", "spell"):
        for item in _split_items(gear.get(key, "")):
            sp = spells.get(item)
            if sp is None:
                warnings.append(f"'{item}' is not a catalog spell; kept as written.")
            state.setdefault("spells", []).append(sp["name"] if sp else item)
    return state, warnings


class _FormModal(discord.ui.Modal, title="NPC stat block"):
    npc_name = discord.ui.TextInput(label="Name", min_length=1, max_length=64)
    traits = discord.ui.TextInput(
        label="Traits (final values; blank = 2s)", required=False, max_length=200,
        placeholder="Sta 3 Wil 2 Str 3 Per 2 Ref 3 Awa 2 Agi 3 Int 2 Void 2",
    )
    skills = discord.ui.TextInput(
        label="Skills", required=False, max_length=1000, style=discord.TextStyle.paragraph,
        placeholder="Kenjutsu 3 (Katana), Defense 2, Lore: Shadowlands 2",
    )
    gear = discord.ui.TextInput(
        label="Gear, advantages, spells", required=False, max_length=1000, style=discord.TextStyle.paragraph,
        placeholder="weapon: katana; off: wakizashi; armor: light; adv: Large; disadv: Bad Reputation",
    )
    details = discord.ui.TextInput(
        label="Details", required=False, max_length=1000, style=discord.TextStyle.paragraph,
        placeholder="clan: Crab; family: Hida; school: Hida Bushi; rank: 2; honor: 4.5; glory: 2; status: 1; notes: ...",
    )

    async def on_submit(self, interaction: discord.Interaction) -> None:
        name = self.npc_name.value.strip()
        guild_id = str(interaction.guild_id)
        if _d.store.get_by_name(guild_id, _d.npc_owner, name) is not None:
            await interaction.response.send_message(
                f"An NPC named **{name}** already exists. Pick another name or delete it first.", ephemeral=True)
            return
        try:
            state, warnings = form_to_state(interaction.user.id, interaction.guild_id, name, self.traits.value,
                                            self.skills.value, self.gear.value, self.details.value)
        except ParseError as e:
            await interaction.response.send_message(f"Could not read the stat block: {e}\nRun `/npc form` again.", ephemeral=True)
            return
        content = f"**{name}**: check the sheet, then save."
        if warnings:
            content += "\n⚠️ " + "\n⚠️ ".join(warnings)
        view = _SaveView(state)
        await interaction.response.send_message(content=content[:2000], embed=_d.build_sheet_embed(preview_record(state)),
                                                view=view, ephemeral=True)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
async def _template_autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    if interaction.guild_id is None:
        return []
    cur = (current or "").lower().strip()
    names = [n for n, _ in _d.store.list_npc_templates(str(interaction.guild_id)) if cur in n.lower()]
    return [app_commands.Choice(name=n, value=n) for n in names[:25]]


@app_commands.command(name="create", description="Build an NPC step by step with exact stats: school, traits, skills, gear. [Fortune]")
async def npc_create(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    await interaction.response.send_modal(_NameModal())


@app_commands.command(name="form", description="Create an NPC from a typed stat block (traits, skills, gear in one form). [Fortune]")
async def npc_form(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    await interaction.response.send_modal(_FormModal())


@app_commands.command(name="edit", description="Reopen a stored NPC in the step-by-step builder and change any stat. [Fortune]")
@app_commands.describe(name="The NPC to edit.")
async def npc_edit(interaction: discord.Interaction, name: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    rec = _d.store.get_by_name(str(interaction.guild_id), _d.npc_owner, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    state = state_from_record(rec, interaction.user.id, interaction.guild_id)
    state["step"] = next(i for i, (k, _) in enumerate(STEPS) if k == "traits")
    wizard = NpcWizard(state)
    await interaction.response.send_message(content=wizard.header(), embed=wizard.embed(), view=wizard, ephemeral=True)


template_group = app_commands.Group(name="template", description="Reusable NPC templates: save one, spawn copies.")


@template_group.command(name="save", description="Save an existing NPC as a reusable template. [Fortune]")
@app_commands.describe(name="The NPC to copy.", template="Template name (defaults to the NPC's name).")
async def template_save(interaction: discord.Interaction, name: str, template: app_commands.Range[str, 1, 64] | None = None) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild_id = str(interaction.guild_id)
    rec = _d.store.get_by_name(guild_id, _d.npc_owner, name)
    if rec is None:
        await interaction.response.send_message(f"No NPC named **{name}**.", ephemeral=True)
        return
    tname = (template or rec.character.name).strip()
    replaced = _save_template(guild_id, tname, rec.character, str(interaction.user.id))
    await interaction.response.send_message(
        f"📋 {'Replaced' if replaced else 'Saved'} template **{tname}** from **{rec.character.name}**. "
        f"Spawn copies with `/npc template spawn template:{tname}`.",
        ephemeral=True,
    )


@template_group.command(name="spawn", description="Create one or more fresh NPCs from a template. [Fortune]")
@app_commands.describe(template="Template to spawn from.", name="NPC name (defaults to the template name).",
                       count="How many (2+ are numbered: 'Bandit 1', 'Bandit 2').")
@app_commands.autocomplete(template=_template_autocomplete)
async def template_spawn(interaction: discord.Interaction, template: str,
                         name: app_commands.Range[str, 1, 60] | None = None,
                         count: app_commands.Range[int, 1, MAX_SPAWN] = 1) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    guild_id = str(interaction.guild_id)
    row = _d.store.get_npc_template(guild_id, template)
    if row is None:
        await interaction.response.send_message(f"No template named **{template}**. See `/npc template list`.", ephemeral=True)
        return
    tname, data = row
    base_name = (name or tname).strip()
    names = [base_name] if count == 1 else [f"{base_name} {i}" for i in range(1, count + 1)]
    made: list[storage.CharacterRecord] = []
    skipped: list[str] = []
    for n in names:
        char = Character.from_dict(copy.deepcopy(data))
        char.name = n
        char.is_npc = True
        char.wounds_taken = 0
        rec, err = _save_npc(guild_id, char)
        if rec is None:
            skipped.append(n)
        else:
            made.append(rec)
    if not made:
        await interaction.response.send_message(
            f"Nothing spawned: {', '.join(f'**{n}**' for n in skipped)} already exist.", ephemeral=True)
        return
    text = f"🎭 Spawned from **{tname}**: " + ", ".join(f"**{r.character.name}**" for r in made) + "."
    if skipped:
        text += f" Skipped (name taken): {', '.join(skipped)}."
    await interaction.response.send_message(text, embed=_d.build_sheet_embed(made[0]))


@template_group.command(name="list", description="List the NPC templates on this server.")
async def template_list(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return
    rows = _d.store.list_npc_templates(str(interaction.guild_id))
    if not rows:
        await interaction.response.send_message(
            "No NPC templates yet. Build one with `/npc create` and press **Save as template**, "
            "or `/npc template save` an existing NPC.", ephemeral=True)
        return
    lines = []
    for n, data in rows:
        c = Character.from_dict(data)
        lines.append(f"• **{n}**: {c.clan or ' '} {c.school or c.school_type} (Rank {c.school_rank})")
    await interaction.response.send_message("📋 **NPC templates:**\n" + "\n".join(lines[:50]), ephemeral=True)


@template_group.command(name="view", description="Show a template's sheet.")
@app_commands.describe(template="Template name.")
@app_commands.autocomplete(template=_template_autocomplete)
async def template_view(interaction: discord.Interaction, template: str) -> None:
    if not await _d.require_guild(interaction):
        return
    row = _d.store.get_npc_template(str(interaction.guild_id), template)
    if row is None:
        await interaction.response.send_message(f"No template named **{template}**.", ephemeral=True)
        return
    tname, data = row
    rec = storage.CharacterRecord(0, str(interaction.guild_id), _d.npc_owner, Character.from_dict(data))
    await interaction.response.send_message(f"📋 Template **{tname}**", embed=_d.build_sheet_embed(rec), ephemeral=True)


@template_group.command(name="delete", description="Delete an NPC template (spawned NPCs are unaffected). [Fortune]")
@app_commands.describe(template="Template name.")
@app_commands.autocomplete(template=_template_autocomplete)
async def template_delete(interaction: discord.Interaction, template: str) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return
    if not _d.store.delete_npc_template(str(interaction.guild_id), template):
        await interaction.response.send_message(f"No template named **{template}**.", ephemeral=True)
        return
    await interaction.response.send_message(f"Deleted template **{template}**.", ephemeral=True)


def init(*, store, npc_owner: str, require_guild, require_dm_role, is_dm, build_sheet_embed,
         npc_autocomplete, npc_group: app_commands.Group) -> None:
    global _d
    _d = _Deps(store=store, npc_owner=npc_owner, require_guild=require_guild, require_dm_role=require_dm_role,
               is_dm=is_dm, build_sheet_embed=build_sheet_embed, npc_autocomplete=npc_autocomplete)
    template_save.autocomplete("name")(npc_autocomplete)
    npc_edit.autocomplete("name")(npc_autocomplete)
    npc_group.add_command(npc_create)
    npc_group.add_command(npc_edit)
    npc_group.add_command(npc_form)
    npc_group.add_command(template_group)
