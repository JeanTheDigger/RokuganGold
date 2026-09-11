"""The playable L5R 4e character sheet.

A deliberately SMALL subset of `shared/character_data.gd` — only the fields a
DM-in-the-loop tabletop bot needs (identity, the 8 Traits + Void, Void Points,
skills, honor/glory/status/infamy, wounds, armor, taint, techniques, spells,
koku). The full 600-field simulation sheet (Kolat, sleepers, ship drift, geisha
intelligence, etc.) is persistent-world state the bot does not model.

Every default value here is copied from the GDScript defaults — none invented:
Traits/Void start at 2, Honor 3.5, Glory 1.0, Status 1.0, Infamy 0.0, Void
Points 2/2, age 16.

Pure data. Serialises to/from a plain dict for JSON storage.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict, fields

from . import enums


@dataclass
class Character:
    # -- Identity (shared/character_data.gd "Identity") --
    name: str = ""
    clan: str = ""
    family: str = ""
    school: str = ""
    school_type: str = "Bushi"
    school_rank: int = 1
    age: int = 16
    gender: str = ""
    is_npc: bool = False

    # -- Traits & Void (default 2 each, per GDScript) --
    stamina: int = 2
    willpower: int = 2
    strength: int = 2
    perception: int = 2
    agility: int = 2
    intelligence: int = 2
    reflexes: int = 2
    awareness: int = 2
    void_ring: int = 2

    # -- Void Points --
    current_void_points: int = 2
    max_void_points: int = 2

    # -- Skills: {skill_name: rank}. Emphases: {skill_name: [emphasis, ...]} --
    skills: dict[str, int] = field(default_factory=dict)
    emphases: dict[str, list[str]] = field(default_factory=dict)

    # -- Techniques / kata / kiho / spells (names only) --
    techniques: list[str] = field(default_factory=list)
    katas: list[str] = field(default_factory=list)
    kiho: list[str] = field(default_factory=list)
    spells_known: list[str] = field(default_factory=list)
    affinity_element: str = ""
    deficiency_element: str = ""

    # -- Currently-active kata / kiho (GDD s30/s38). Executing a kata is a Simple
    #    Action and only ONE may be active (s30). Kiho: only one Internal, one
    #    Kharmic, one Mystical may be active; multiple Martial may (s38). Names
    #    only; the deterministic combat modifiers live in kata_effects.py. --
    active_kata: str = ""
    active_kiho: list[str] = field(default_factory=list)

    # -- Honor, Glory, Status, Infamy (0.0-10.0) --
    honor: float = 3.5
    glory: float = 1.0
    status: float = 1.0
    infamy: float = 0.0

    # -- Wounds (levels derived from Earth ring at query time) --
    wounds_taken: int = 0

    # -- Armor & equipment --
    armor_name: str = ""
    armor_tn_bonus: int = 0
    armor_reduction: int = 0
    weapons: list[str] = field(default_factory=list)
    # Currently-wielded weapons (main / off hand). Used as the default weapon for
    # /attack and to gate defender weapon-conditional kata (Strength of the
    # Crane/Dragon, s30). "" = that hand is empty.
    equipped_weapon: str = ""
    off_hand_weapon: str = ""

    # -- Shadowlands Taint --
    taint: float = 0.0

    # -- Advantages / Disadvantages (names only at this phase) --
    advantages: list[str] = field(default_factory=list)
    disadvantages: list[str] = field(default_factory=list)

    # -- Spell slots per element (L5R 4e: max = Ring + School Rank per day).
    #    DM refreshes via /dm new_day. Empty dict = not yet tracked. --
    spell_slots: dict[str, int] = field(default_factory=dict)

    # -- Money --
    koku: float = 0.0

    # -- Experience — spendable XP (DM-granted) and lifetime total spent --
    xp: float = 0.0
    xp_spent: float = 0.0

    # -- Free-form DM/player notes (bot convenience, not a game mechanic) --
    notes: str = ""

    # -- Trait access helpers (mirror get/set_trait_value in the GDScript) --
    _TRAIT_ATTR = {
        "stamina": "stamina", "willpower": "willpower", "strength": "strength",
        "perception": "perception", "agility": "agility", "intelligence": "intelligence",
        "reflexes": "reflexes", "awareness": "awareness", "void": "void_ring",
    }

    def get_trait(self, trait: str) -> int:
        return getattr(self, self._TRAIT_ATTR[trait.lower()])

    def set_trait(self, trait: str, value: int) -> None:
        setattr(self, self._TRAIT_ATTR[trait.lower()], value)

    # -- Serialisation --
    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Character":
        # Tolerate missing/extra keys so sheets stay forward-compatible as the
        # model grows in later phases.
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})
