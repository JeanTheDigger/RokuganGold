"""Seasonal Flavor: Atmospheric posts when the calendar changes month or season.

When /dm new_day crosses into a new month or season, the bot posts
thematic flavor text to all location channels, making the world feel
alive and responsive to the passage of time.
"""

from __future__ import annotations

import random

import discord


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store = None
    bot_client: discord.Client = None

_d = _Deps()


def init(*, store, bot_client: discord.Client) -> None:
    _d.store = store
    _d.bot_client = bot_client


# ---------------------------------------------------------------------------
# Season / month data
# ---------------------------------------------------------------------------

SEASON_COLORS = {
    "Spring": discord.Color.from_rgb(180, 220, 140),
    "Summer": discord.Color.from_rgb(240, 200, 80),
    "Autumn": discord.Color.from_rgb(200, 130, 60),
    "Winter": discord.Color.from_rgb(160, 190, 220),
}

SEASON_ARRIVAL: dict[str, list[str]] = {
    "Spring": [
        "The snows retreat and the first cherry blossoms appear on the branches. Spring has come to Rokugan.",
        "Birdsong fills the morning air as green returns to the fields. The season of renewal begins.",
        "The rivers swell with snowmelt, and farmers prepare the paddies. Spring breathes life into the Empire.",
    ],
    "Summer": [
        "The sun beats down with growing intensity. The roads are dry and the cicadas sing. Summer has arrived.",
        "Heat shimmers rise from the stone courtyards. Servants unfurl parasols and seek the shade. Summer is here.",
        "The days stretch long and warm. Thunder clouds gather on distant horizons. The season of fire begins.",
    ],
    "Autumn": [
        "The leaves turn crimson and gold across the Empire. Harvest begins. Autumn has come.",
        "A cool wind carries the scent of ripe grain. The maples blaze with color. The season of reflection begins.",
        "Morning mists cling to the valleys. Geese fly south overhead. Autumn settles over Rokugan.",
    ],
    "Winter": [
        "The first frost silvers the rooftops at dawn. Winter has come to Rokugan.",
        "Cold winds howl down from the mountains. Servants stoke the braziers. The season of endurance begins.",
        "Snow dusts the castle walls. The courts draw inward. Winter closes its grip on the Empire.",
    ],
}

MONTH_FLAVOR: dict[str, list[str]] = {
    "Hare": [
        "The Month of the Hare begins. New growth pushes through the thawing earth.",
        "Under the sign of the Hare, the Empire stirs from its winter slumber.",
    ],
    "Dragon": [
        "The Month of the Dragon begins. Thunder rumbles in distant mountains.",
        "Under the sign of the Dragon, storms gather strength on the horizon.",
    ],
    "Serpent": [
        "The Month of the Serpent begins. The air grows warm and the gardens bloom.",
        "Under the sign of the Serpent, the rivers run full and clear.",
    ],
    "Horse": [
        "The Month of the Horse begins. The roads are busy with travelers.",
        "Under the sign of the Horse, caravans and patrols fill the highways.",
    ],
    "Goat": [
        "The Month of the Goat begins. The heat of summer is at its peak.",
        "Under the sign of the Goat, the countryside drowses in the midday sun.",
    ],
    "Monkey": [
        "The Month of the Monkey begins. The harvest approaches and the markets swell.",
        "Under the sign of the Monkey, festivals and performances enliven the towns.",
    ],
    "Rooster": [
        "The Month of the Rooster begins. The first cool breezes hint at change.",
        "Under the sign of the Rooster, the harvest is gathered and counted.",
    ],
    "Dog": [
        "The Month of the Dog begins. Leaves drift from the branches like prayers.",
        "Under the sign of the Dog, loyalty is tested as the courts convene.",
    ],
    "Boar": [
        "The Month of the Boar begins. The last warmth fades from the land.",
        "Under the sign of the Boar, preparations for winter begin in earnest.",
    ],
    "Rat": [
        "The Month of the Rat begins. The first snows fall in the northern provinces.",
        "Under the sign of the Rat, whispers travel faster than the cold wind.",
    ],
    "Ox": [
        "The Month of the Ox begins. The deep cold settles over the Empire.",
        "Under the sign of the Ox, endurance is the greatest virtue.",
    ],
    "Tiger": [
        "The Month of the Tiger begins. The winter reaches its coldest depths.",
        "Under the sign of the Tiger, only the bold venture far from the hearth.",
    ],
}


# ---------------------------------------------------------------------------
# Public API: called by dm_new_day after advancing the calendar
# ---------------------------------------------------------------------------

async def on_day_advanced(
    guild: discord.Guild,
    old_cal: tuple[int, int, int] | None,
    new_cal: tuple[int, int, int] | None,
) -> None:
    """Post seasonal flavor when the month or season changes.

    old_cal / new_cal are (year, month, day) tuples from the Rokugani calendar.
    Either may be None if the calendar was not set.
    """
    if old_cal is None or new_cal is None:
        return

    old_year, old_month, _old_day = old_cal
    new_year, new_month, _new_day = new_cal

    if old_month == new_month and old_year == new_year:
        return

    from bot import ROKUGANI_MONTHS
    new_month_name, new_season = ROKUGANI_MONTHS[new_month - 1]
    old_month_name, old_season = ROKUGANI_MONTHS[old_month - 1]

    embeds: list[discord.Embed] = []

    if old_season != new_season:
        color = SEASON_COLORS.get(new_season, discord.Color.dark_gold())
        flavor = random.choice(SEASON_ARRIVAL.get(new_season, ["A new season begins."]))
        embed = discord.Embed(
            title=f"{new_season} Has Come",
            description=flavor,
            color=color,
        )
        embeds.append(embed)

    month_flavor = random.choice(MONTH_FLAVOR.get(new_month_name, [f"The Month of the {new_month_name} begins."]))
    month_embed = discord.Embed(
        description=month_flavor,
        color=SEASON_COLORS.get(new_season, discord.Color.dark_gold()),
    )
    embeds.append(month_embed)

    if not embeds:
        return

    guild_id = str(guild.id)
    areas = _d.store.list_location_areas(guild_id)
    for area in areas:
        cat = guild.get_channel(int(area.category_id))
        if cat is None or not isinstance(cat, discord.CategoryChannel):
            continue
        for ch in cat.text_channels:
            if ch.name == "description":
                continue
            for embed in embeds:
                try:
                    await ch.send(embed=embed)
                except discord.Forbidden:
                    pass
