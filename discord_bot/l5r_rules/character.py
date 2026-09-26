"""The playable L5R 4e character sheet.

A deliberately SMALL subset of `shared/character_data.gd`: only the fields a
DM-in-the-loop tabletop bot needs (identity, the 8 Traits + Void, Void Points,
skills, honor/glory/status/infamy, wounds, armor, taint, techniques, spells,
koku). The full 600-field simulation sheet (Kolat, sleepers, ship drift, geisha
intelligence, etc.) is persistent-world state the bot does not model.

Every default value here is copied from the GDScript defaults: none invented:
Traits/Void start at 2, Honor 3.5, Glory 1.0, Status 1.0, Infamy 0.0, Void
Points 2/2, age 16.

Pure data. Serialises to/from a plain dict for JSON storage.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict, fields, MISSING

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
    owned_armor: str = ""
    armor_name: str = ""
    armor_tn_bonus: int = 0
    armor_reduction: int = 0
    is_mounted: bool = False
    weapons: list[str] = field(default_factory=list)
    # Currently-wielded weapons (main / off hand). Used as the default weapon for
    # /attack and to gate defender weapon-conditional kata (Strength of the
    # Crane/Dragon, s30). "" = that hand is empty.
    equipped_weapon: str = ""
    off_hand_weapon: str = ""
    weapon_qualities: list[str] = field(default_factory=list)

    # -- Shadowlands Taint (s42). Days since the last periodic resistance roll;
    #    advanced by /dm new_day and reset when the roll is made. --
    taint: float = 0.0
    taint_days_since_roll: int = 0

    # -- Togashi Tattoos (s57.25) --
    tattoos: list[str] = field(default_factory=list)
    active_tattoo: str = ""
    bear_tattoo_choice: str = ""
    lion_tattoo_skill: str = ""

    # -- Advantages / Disadvantages (names only at this phase) --
    advantages: list[str] = field(default_factory=list)
    disadvantages: list[str] = field(default_factory=list)

    # -- Spell slots per element (L5R 4e: max = Ring value per day).
    #    Void bonus pool (= Void Ring) is shared across all elements.
    #    DM refreshes via /dm new_day. Empty dict = not yet tracked. --
    spell_slots: dict[str, int] = field(default_factory=dict)
    void_spell_bonus: int = 0

    # -- Inventory: {item_name: quantity}. Quantity 0 means not carried. --
    inventory: dict[str, int] = field(default_factory=dict)

    # -- Money (1 koku = 5 bu = 50 zeni; 1 bu = 10 zeni) --
    koku: int = 0
    bu: int = 0
    zeni: int = 0

    # -- Experience: spendable XP (DM-granted) and lifetime total spent --
    xp: float = 0.0
    xp_spent: float = 0.0

    # -- Free-form DM/player notes (bot convenience, not a game mechanic) --
    notes: str = ""
    portrait: str = ""  # "https://..." or "file:<name>" under PORTRAIT_DIR (see portraits.py)

    # -- Heritage roll result text (includes Fortune notes for DM adjudication) --
    heritage_result: str = ""

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

    @property
    def total_zeni(self) -> int:
        return self.koku * 50 + self.bu * 10 + self.zeni

    @classmethod
    def from_dict(cls, data: dict) -> "Character":
        # Tolerate missing/extra keys so sheets stay forward-compatible as the
        # model grows in later phases.  Coerce null values to their field
        # defaults so callers never hit AttributeError on None.
        _migrate_koku(data)
        field_defaults: dict = {}
        for f in fields(cls):
            if f.default is not MISSING:
                field_defaults[f.name] = f.default
            elif f.default_factory is not MISSING:
                field_defaults[f.name] = f.default_factory
        known = {f.name for f in fields(cls)}
        cleaned = {}
        for k, v in data.items():
            if k not in known:
                continue
            if v is None and k in field_defaults:
                d = field_defaults[k]
                v = d() if callable(d) else d
            cleaned[k] = v
        return cls(**cleaned)


def _migrate_koku(data: dict) -> None:
    """Convert legacy float koku to the three-denomination system."""
    if "bu" in data or "zeni" in data:
        return
    raw = data.get("koku")
    if raw is None or raw == 0:
        data["koku"] = 0
        return
    total_zeni = round(float(raw) * 50)
    data["koku"] = total_zeni // 50
    remainder = total_zeni % 50
    data["bu"] = remainder // 10
    data["zeni"] = remainder % 10


def normalise_purse(c: Character) -> None:
    """Roll up excess zeni/bu into larger denominations; clamp to zero."""
    total = c.koku * 50 + c.bu * 10 + c.zeni
    if total < 0:
        total = 0
    c.koku = total // 50
    remainder = total % 50
    c.bu = remainder // 10
    c.zeni = remainder % 10


def format_purse(c: Character) -> str:
    """Format the character's purse as a compact string."""
    parts: list[str] = []
    if c.koku:
        parts.append(f"{c.koku} koku")
    if c.bu:
        parts.append(f"{c.bu} bu")
    if c.zeni:
        parts.append(f"{c.zeni} zeni")
    return ", ".join(parts) if parts else "0 koku"
