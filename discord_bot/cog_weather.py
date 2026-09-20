"""Weather system: Season-driven daily weather for the game world.

Weather rolls automatically when /dm new_day advances the calendar.
Each season has a weighted table of weather types.  The current weather
is stored in the DB and displayed in a pinned embed in #weather.
DMs can override the weather manually with /weather set.
"""

from __future__ import annotations

import random

import discord
from discord import app_commands


# ---------------------------------------------------------------------------
# Dependency injection
# ---------------------------------------------------------------------------

class _Deps:
    store = None
    bot_client: discord.Client = None
    require_guild = None
    require_dm_role = None
    is_dm = None

_d = _Deps()


def init(
    *,
    store,
    bot_client: discord.Client,
    require_guild,
    require_dm_role,
    is_dm,
) -> None:
    _d.store = store
    _d.bot_client = bot_client
    _d.require_guild = require_guild
    _d.require_dm_role = require_dm_role
    _d.is_dm = is_dm


# ---------------------------------------------------------------------------
# Weather data
# ---------------------------------------------------------------------------

WEATHER_TYPES: dict[str, dict] = {
    "clear": {
        "name": "Clear Skies",
        "color": discord.Color.from_rgb(135, 206, 235),
    },
    "partly_cloudy": {
        "name": "Partly Cloudy",
        "color": discord.Color.from_rgb(180, 200, 220),
    },
    "overcast": {
        "name": "Overcast",
        "color": discord.Color.from_rgb(140, 150, 160),
    },
    "light_rain": {
        "name": "Light Rain",
        "color": discord.Color.from_rgb(100, 140, 180),
    },
    "rain": {
        "name": "Rain",
        "color": discord.Color.from_rgb(70, 110, 160),
    },
    "heavy_rain": {
        "name": "Heavy Rain",
        "color": discord.Color.from_rgb(50, 80, 130),
    },
    "thunderstorm": {
        "name": "Thunderstorm",
        "color": discord.Color.from_rgb(60, 60, 90),
    },
    "fog": {
        "name": "Fog",
        "color": discord.Color.from_rgb(190, 190, 190),
    },
    "wind": {
        "name": "Strong Winds",
        "color": discord.Color.from_rgb(160, 190, 170),
    },
    "hot": {
        "name": "Scorching Heat",
        "color": discord.Color.from_rgb(230, 150, 50),
    },
    "humid": {
        "name": "Hot and Humid",
        "color": discord.Color.from_rgb(200, 180, 100),
    },
    "cool": {
        "name": "Cool Breeze",
        "color": discord.Color.from_rgb(150, 190, 160),
    },
    "frost": {
        "name": "Frost",
        "color": discord.Color.from_rgb(180, 210, 230),
    },
    "snow": {
        "name": "Snowfall",
        "color": discord.Color.from_rgb(200, 215, 230),
    },
    "heavy_snow": {
        "name": "Heavy Snow",
        "color": discord.Color.from_rgb(170, 190, 210),
    },
    "blizzard": {
        "name": "Blizzard",
        "color": discord.Color.from_rgb(140, 160, 190),
    },
    "ice": {
        "name": "Ice Storm",
        "color": discord.Color.from_rgb(160, 180, 200),
    },
    "mist": {
        "name": "Morning Mist",
        "color": discord.Color.from_rgb(200, 200, 190),
    },
}

SEASON_WEATHER: dict[str, list[tuple[str, int]]] = {
    "Spring": [
        ("clear", 25),
        ("partly_cloudy", 20),
        ("overcast", 10),
        ("light_rain", 15),
        ("rain", 10),
        ("fog", 8),
        ("mist", 5),
        ("thunderstorm", 4),
        ("wind", 3),
    ],
    "Summer": [
        ("clear", 20),
        ("hot", 15),
        ("humid", 15),
        ("partly_cloudy", 15),
        ("thunderstorm", 10),
        ("rain", 8),
        ("heavy_rain", 5),
        ("overcast", 7),
        ("wind", 5),
    ],
    "Autumn": [
        ("clear", 20),
        ("partly_cloudy", 15),
        ("cool", 15),
        ("overcast", 12),
        ("light_rain", 10),
        ("fog", 8),
        ("mist", 8),
        ("wind", 7),
        ("rain", 5),
    ],
    "Winter": [
        ("overcast", 18),
        ("frost", 15),
        ("snow", 15),
        ("clear", 12),
        ("partly_cloudy", 10),
        ("heavy_snow", 10),
        ("wind", 8),
        ("fog", 5),
        ("blizzard", 4),
        ("ice", 3),
    ],
}

WEATHER_FLAVOR: dict[str, list[str]] = {
    "clear": [
        "The sky stretches cloudless and bright above the Empire.",
        "A clear day blesses the land. The horizon is sharp as a blade.",
    ],
    "partly_cloudy": [
        "White clouds drift lazily across an otherwise blue sky.",
        "Shadows chase patches of sunlight across the landscape.",
    ],
    "overcast": [
        "A grey blanket of cloud covers the sky from horizon to horizon.",
        "The sun hides behind a uniform grey ceiling. The light is flat and muted.",
    ],
    "light_rain": [
        "A gentle rain falls, pattering softly on tile rooftops and garden stones.",
        "Fine rain drifts through the air like silk. The earth drinks gratefully.",
    ],
    "rain": [
        "Steady rain drums on the rooftops. Puddles form in the courtyards.",
        "Rain falls in curtains across the land. Travelers pull their straw cloaks tight.",
    ],
    "heavy_rain": [
        "Rain hammers the ground in sheets. Streams swell and roads turn to mud.",
        "The heavens open. Water cascades from every eave and gutter.",
    ],
    "thunderstorm": [
        "Thunder cracks across the sky. Lightning illuminates the clouds from within.",
        "A violent storm rages. Thunder shakes the walls and lightning splits the darkness.",
    ],
    "fog": [
        "Thick fog blankets the land. Shapes appear and vanish like ghosts.",
        "The world disappears into white. Sound travels strangely in the dense fog.",
    ],
    "wind": [
        "A fierce wind tears at banners and robes. Dust swirls through the streets.",
        "The wind howls around corners and through corridors. Shutters rattle.",
    ],
    "hot": [
        "The sun blazes mercilessly. The air shimmers and the stones burn to the touch.",
        "The heat is oppressive. Even the cicadas fall silent in the midday blaze.",
    ],
    "humid": [
        "The air is thick and damp, clinging like wet cloth. Sweat beads on every brow.",
        "Humidity weighs heavy on the land. Every breath feels like drinking warm water.",
    ],
    "cool": [
        "A cool breeze whispers through the trees, carrying the scent of change.",
        "The air is crisp and refreshing. A pleasant coolness settles over the land.",
    ],
    "frost": [
        "Frost rimes the grass and rooftops at dawn. Breath clouds in the cold air.",
        "A hard frost grips the land. Ice crystals glitter on every surface.",
    ],
    "snow": [
        "Snow falls gently, muffling the world in soft white silence.",
        "Snowflakes drift down like scattered petals, blanketing the Empire.",
    ],
    "heavy_snow": [
        "Snow falls thick and fast, piling on rooftops and blocking roads.",
        "A heavy snowfall buries the landscape. The world becomes a white void.",
    ],
    "blizzard": [
        "A howling blizzard reduces visibility to nothing. The world is wind and ice.",
        "The blizzard screams across the land. Only fools or heroes venture out.",
    ],
    "ice": [
        "Ice coats every surface. The roads are treacherous, the trees encased in glass.",
        "An ice storm has transformed the land into a glittering, deadly landscape.",
    ],
    "mist": [
        "Morning mist hangs in the valleys and between the trees, soft and dreamlike.",
        "A gentle mist clings to the ground, burning away slowly as the sun rises.",
    ],
}


# ---------------------------------------------------------------------------
# Weather rolling
# ---------------------------------------------------------------------------

def roll_weather(season: str) -> str:
    table = SEASON_WEATHER.get(season, SEASON_WEATHER["Spring"])
    types = [t for t, _w in table]
    weights = [w for _t, w in table]
    return random.choices(types, weights=weights, k=1)[0]


def _weather_embed(weather_key: str, date_str: str | None = None) -> discord.Embed:
    info = WEATHER_TYPES.get(weather_key, WEATHER_TYPES["clear"])
    flavor = random.choice(WEATHER_FLAVOR.get(weather_key, ["The weather is unremarkable."]))
    embed = discord.Embed(
        title=info["name"],
        description=flavor,
        color=info["color"],
    )
    if date_str:
        embed.set_footer(text=date_str)
    return embed


# ---------------------------------------------------------------------------
# Command group
# ---------------------------------------------------------------------------

weather = app_commands.Group(
    name="weather", description="View and manage the in-game weather."
)


@weather.command(name="now", description="Show the current weather.")
async def weather_now(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    w = _d.store.get_weather(guild_id)
    if w is None:
        await interaction.response.send_message(
            "No weather has been set yet. It will roll automatically on `/dm new_day`, "
            "or a DM can set it with `/weather set`.",
            ephemeral=True,
        )
        return

    from bot import ROKUGANI_MONTHS
    cal = _d.store.get_calendar(guild_id)
    date_str = None
    if cal:
        year, month, day = cal
        month_name, season = ROKUGANI_MONTHS[month - 1]
        date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {year}"

    embed = _weather_embed(w["weather_type"], date_str)
    await interaction.response.send_message(embed=embed, ephemeral=True)


@weather.command(
    name="set",
    description="Manually set the weather. [Fortune]",
)
@app_commands.describe(
    weather_type="The weather to set.",
)
@app_commands.choices(weather_type=[
    app_commands.Choice(name=v["name"], value=k)
    for k, v in WEATHER_TYPES.items()
][:25])
async def weather_set(
    interaction: discord.Interaction,
    weather_type: app_commands.Choice[str],
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    guild_id = str(interaction.guild_id)
    wtype = weather_type.value
    _d.store.set_weather(guild_id, wtype, str(interaction.user.id))

    from bot import ROKUGANI_MONTHS
    cal = _d.store.get_calendar(guild_id)
    date_str = None
    if cal:
        year, month, day = cal
        month_name, season = ROKUGANI_MONTHS[month - 1]
        date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {year}"

    embed = _weather_embed(wtype, date_str)
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)

    await _update_weather_display(interaction.guild, wtype, date_str)
    await _post_weather_to_locations(interaction.guild, wtype)


@weather.command(
    name="forecast",
    description="Show the weather table for the current season.",
)
async def weather_forecast(interaction: discord.Interaction) -> None:
    if not await _d.require_guild(interaction):
        return

    guild_id = str(interaction.guild_id)
    cal = _d.store.get_calendar(guild_id)
    if cal is None:
        await interaction.response.send_message(
            "No calendar set. Use `/dm setdate` first.", ephemeral=True,
        )
        return

    from bot import ROKUGANI_MONTHS
    _year, month, _day = cal
    _month_name, season = ROKUGANI_MONTHS[month - 1]

    from cog_seasons import SEASON_COLORS
    table = SEASON_WEATHER.get(season, [])
    total = sum(w for _, w in table)
    lines: list[str] = []
    for wtype, weight in table:
        info = WEATHER_TYPES.get(wtype, {})
        pct = (weight / total * 100) if total > 0 else 0
        lines.append(f"**{info.get('name', wtype)}** - {pct:.0f}%")

    color = SEASON_COLORS.get(season, discord.Color.dark_gold())
    embed = discord.Embed(
        title=f"{season} Weather Forecast",
        description="\n".join(lines),
        color=color,
    )
    embed.set_footer(text="Probability of each weather type when a new day dawns.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

async def _update_weather_display(
    guild: discord.Guild, weather_key: str, date_str: str | None,
) -> None:
    guild_id = str(guild.id)
    info = _d.store.get_weather_channel(guild_id)
    if info is None:
        return
    channel_id, message_id = info
    channel = guild.get_channel(int(channel_id))
    if channel is None:
        return
    embed = _weather_embed(weather_key, date_str)
    if message_id:
        try:
            msg = await channel.fetch_message(int(message_id))
            await msg.edit(embed=embed)
            return
        except discord.NotFound:
            pass
    new_msg = await channel.send(embed=embed)
    try:
        await new_msg.pin()
    except discord.Forbidden:
        pass
    _d.store.set_weather_channel(guild_id, channel_id, str(new_msg.id))


async def _post_weather_to_locations(
    guild: discord.Guild, weather_key: str,
) -> None:
    guild_id = str(guild.id)
    info = WEATHER_TYPES.get(weather_key, WEATHER_TYPES["clear"])
    flavor = random.choice(WEATHER_FLAVOR.get(weather_key, ["The weather shifts."]))
    embed = discord.Embed(
        description=flavor,
        color=info["color"],
    )

    areas = _d.store.list_location_areas(guild_id)
    for area in areas:
        cat = guild.get_channel(int(area.category_id))
        if cat is None or not isinstance(cat, discord.CategoryChannel):
            continue
        for ch in cat.text_channels:
            if ch.name == "description":
                continue
            try:
                await ch.send(embed=embed)
            except discord.Forbidden:
                pass


# ---------------------------------------------------------------------------
# Public API: called by dm_new_day after advancing the calendar
# ---------------------------------------------------------------------------

async def on_day_advanced(
    guild: discord.Guild,
    new_cal: tuple[int, int, int],
) -> None:
    from bot import ROKUGANI_MONTHS
    _year, month, day = new_cal
    month_name, season = ROKUGANI_MONTHS[month - 1]

    weather_key = roll_weather(season)
    guild_id = str(guild.id)
    _d.store.set_weather(guild_id, weather_key, "system")

    date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {_year}"
    await _update_weather_display(guild, weather_key, date_str)
    await _post_weather_to_locations(guild, weather_key)
