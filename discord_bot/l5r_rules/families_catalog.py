"""L5R 4e Family data: trait bonuses at character creation.

Each Great Clan family grants +1 to a specific Trait. Data from L5R 4e Core
Rulebook Chapter 4 and Great Clans supplements.
"""

FAMILIES_DATA: list[dict] = [
    # Crab Clan
    {"name": "Hida", "clan": "Crab", "bonus_trait": "strength"},
    {"name": "Hiruma", "clan": "Crab", "bonus_trait": "agility"},
    {"name": "Kaiu", "clan": "Crab", "bonus_trait": "intelligence"},
    {"name": "Kuni", "clan": "Crab", "bonus_trait": "intelligence"},
    {"name": "Toritaka", "clan": "Crab", "bonus_trait": "perception"},
    {"name": "Yasuki", "clan": "Crab", "bonus_trait": "awareness"},
    # Crane Clan
    {"name": "Asahina", "clan": "Crane", "bonus_trait": "intelligence"},
    {"name": "Daidoji", "clan": "Crane", "bonus_trait": "stamina"},
    {"name": "Doji", "clan": "Crane", "bonus_trait": "awareness"},
    {"name": "Kakita", "clan": "Crane", "bonus_trait": "agility"},
    # Dragon Clan
    {"name": "Kitsuki", "clan": "Dragon", "bonus_trait": "awareness"},
    {"name": "Mirumoto", "clan": "Dragon", "bonus_trait": "agility"},
    {"name": "Tamori", "clan": "Dragon", "bonus_trait": "stamina"},
    {"name": "Togashi", "clan": "Dragon", "bonus_trait": "reflexes"},
    # Lion Clan
    {"name": "Akodo", "clan": "Lion", "bonus_trait": "intelligence"},
    {"name": "Ikoma", "clan": "Lion", "bonus_trait": "awareness"},
    {"name": "Kitsu", "clan": "Lion", "bonus_trait": "intelligence"},
    {"name": "Matsu", "clan": "Lion", "bonus_trait": "strength"},
    # Mantis Clan
    {"name": "Kitsune", "clan": "Mantis", "bonus_trait": "awareness"},
    {"name": "Moshi", "clan": "Mantis", "bonus_trait": "intelligence"},
    {"name": "Tsuruchi", "clan": "Mantis", "bonus_trait": "reflexes"},
    {"name": "Yoritomo", "clan": "Mantis", "bonus_trait": "strength"},
    # Phoenix Clan
    {"name": "Agasha", "clan": "Phoenix", "bonus_trait": "intelligence"},
    {"name": "Isawa", "clan": "Phoenix", "bonus_trait": "willpower"},
    {"name": "Shiba", "clan": "Phoenix", "bonus_trait": "perception"},
    # Scorpion Clan
    {"name": "Bayushi", "clan": "Scorpion", "bonus_trait": "agility"},
    {"name": "Shosuro", "clan": "Scorpion", "bonus_trait": "awareness"},
    {"name": "Soshi", "clan": "Scorpion", "bonus_trait": "intelligence"},
    {"name": "Yogo", "clan": "Scorpion", "bonus_trait": "willpower"},
    # Unicorn Clan
    {"name": "Ide", "clan": "Unicorn", "bonus_trait": "awareness"},
    {"name": "Iuchi", "clan": "Unicorn", "bonus_trait": "willpower"},
    {"name": "Moto", "clan": "Unicorn", "bonus_trait": "strength"},
    {"name": "Shinjo", "clan": "Unicorn", "bonus_trait": "reflexes"},
    {"name": "Utaku", "clan": "Unicorn", "bonus_trait": "stamina"},
    # Spider Clan
    {"name": "Chuda", "clan": "Spider", "bonus_trait": "intelligence"},
    {"name": "Daigotsu", "clan": "Spider", "bonus_trait": "willpower"},
    {"name": "Goju", "clan": "Spider", "bonus_trait": "agility"},
    {"name": "Ninube", "clan": "Spider", "bonus_trait": "reflexes"},
    # Minor Clans
    # Minor Clans (owner-supplied source text, 2026-09-16). Falcon families are under Crab
    # (Toritaka), Fox under Mantis (Kitsune), Snake under Spider (Chuda).
    {"name": "Ichiro", "clan": "Badger", "bonus_trait": "strength"},
    {"name": "Komori", "clan": "Bat", "bonus_trait": "intelligence"},
    {"name": "Heichi", "clan": "Boar", "bonus_trait": "willpower"},
    {"name": "Tonbo", "clan": "Dragonfly", "bonus_trait": "awareness"},
    {"name": "Usagi", "clan": "Hare", "bonus_trait": "awareness"},
    {"name": "Ujina", "clan": "Hare", "bonus_trait": "agility"},
    {"name": "Toku", "clan": "Monkey", "bonus_trait": "stamina"},
    {"name": "Fuzake", "clan": "Monkey", "bonus_trait": "perception"},
    {"name": "Tsi", "clan": "Oriole", "bonus_trait": "strength"},
    {"name": "Morito", "clan": "Ox", "bonus_trait": "stamina"},
    {"name": "Suzume", "clan": "Sparrow", "bonus_trait": "awareness"},
    {"name": "Yotsu", "clan": "Tiger", "bonus_trait": "intelligence"},
    {"name": "Kasuga", "clan": "Tortoise", "bonus_trait": "perception"},
]
