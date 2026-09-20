"""Weather system: Multi-axis season-driven daily weather for the game world.

Weather rolls automatically when /dm new_day advances the calendar.
Four independent axes (cloud cover, precipitation, wind, temperature) are
rolled from per-season weighted tables.  Precipitation renders as rain or
snow based on temperature.  Special combinations (blizzard, thunderstorm,
etc.) override the display title.
The current weather is stored in the DB and displayed in a pinned embed
in #weather.  DMs can override individual axes with /weather set.
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
# Axis definitions
# ---------------------------------------------------------------------------

CLOUD_LEVELS = ("clear", "partly_cloudy", "mostly_cloudy", "overcast")

CLOUD_LABELS = {
    "clear": "Clear Skies",
    "partly_cloudy": "Partly Cloudy",
    "mostly_cloudy": "Mostly Cloudy",
    "overcast": "Overcast",
}

PRECIP_LEVELS = ("none", "drizzle", "light", "moderate", "heavy")

PRECIP_LABELS_RAIN = {
    "none": "No Precipitation",
    "drizzle": "Drizzle",
    "light": "Light Rain",
    "moderate": "Rain",
    "heavy": "Heavy Rain",
}

PRECIP_LABELS_SNOW = {
    "none": "No Precipitation",
    "drizzle": "Light Flurries",
    "light": "Light Snow",
    "moderate": "Snowfall",
    "heavy": "Heavy Snow",
}

WIND_LEVELS = ("calm", "light_breeze", "breezy", "strong", "gale")

WIND_LABELS = {
    "calm": "Calm",
    "light_breeze": "Light Breeze",
    "breezy": "Breezy",
    "strong": "Strong Winds",
    "gale": "Gale",
}

TEMP_LEVELS = ("freezing", "cold", "cool", "mild", "warm", "scorching")

TEMP_LABELS = {
    "freezing": "Freezing",
    "cold": "Cold",
    "cool": "Cool",
    "mild": "Mild",
    "warm": "Warm",
    "scorching": "Scorching",
}


# ---------------------------------------------------------------------------
# Seasonal probability tables  (value, weight)
# ---------------------------------------------------------------------------

SEASON_CLOUD: dict[str, list[tuple[str, int]]] = {
    "Spring": [("clear", 25), ("partly_cloudy", 30), ("mostly_cloudy", 25), ("overcast", 20)],
    "Summer": [("clear", 35), ("partly_cloudy", 30), ("mostly_cloudy", 20), ("overcast", 15)],
    "Autumn": [("clear", 20), ("partly_cloudy", 25), ("mostly_cloudy", 30), ("overcast", 25)],
    "Winter": [("clear", 15), ("partly_cloudy", 20), ("mostly_cloudy", 30), ("overcast", 35)],
}

SEASON_PRECIP: dict[str, list[tuple[str, int]]] = {
    "Spring": [("none", 40), ("drizzle", 20), ("light", 20), ("moderate", 15), ("heavy", 5)],
    "Summer": [("none", 50), ("drizzle", 10), ("light", 15), ("moderate", 15), ("heavy", 10)],
    "Autumn": [("none", 35), ("drizzle", 20), ("light", 20), ("moderate", 15), ("heavy", 10)],
    "Winter": [("none", 30), ("drizzle", 15), ("light", 25), ("moderate", 20), ("heavy", 10)],
}

SEASON_WIND: dict[str, list[tuple[str, int]]] = {
    "Spring": [("calm", 25), ("light_breeze", 35), ("breezy", 25), ("strong", 12), ("gale", 3)],
    "Summer": [("calm", 35), ("light_breeze", 30), ("breezy", 20), ("strong", 12), ("gale", 3)],
    "Autumn": [("calm", 20), ("light_breeze", 25), ("breezy", 30), ("strong", 18), ("gale", 7)],
    "Winter": [("calm", 15), ("light_breeze", 20), ("breezy", 30), ("strong", 25), ("gale", 10)],
}

SEASON_TEMP: dict[str, list[tuple[str, int]]] = {
    "Spring": [("freezing", 2), ("cold", 10), ("cool", 35), ("mild", 40), ("warm", 12), ("scorching", 1)],
    "Summer": [("freezing", 0), ("cold", 1), ("cool", 5), ("mild", 25), ("warm", 45), ("scorching", 24)],
    "Autumn": [("freezing", 3), ("cold", 15), ("cool", 35), ("mild", 35), ("warm", 10), ("scorching", 2)],
    "Winter": [("freezing", 25), ("cold", 35), ("cool", 25), ("mild", 12), ("warm", 3), ("scorching", 0)],
}


# ---------------------------------------------------------------------------
# Embed colors per temperature
# ---------------------------------------------------------------------------

TEMP_COLORS = {
    "freezing": discord.Color.from_rgb(160, 190, 220),
    "cold": discord.Color.from_rgb(180, 210, 230),
    "cool": discord.Color.from_rgb(150, 190, 160),
    "mild": discord.Color.from_rgb(180, 200, 160),
    "warm": discord.Color.from_rgb(220, 190, 100),
    "scorching": discord.Color.from_rgb(230, 150, 50),
}


# ---------------------------------------------------------------------------
# Special combo detection
# ---------------------------------------------------------------------------

def _detect_special(cloud: str, precip: str, wind: str, temp: str) -> str | None:
    is_cold = temp in ("freezing", "cold")
    is_snow = is_cold and precip not in ("none",)
    if is_snow and precip == "heavy" and wind in ("strong", "gale"):
        return "Blizzard"
    if precip in ("moderate", "heavy") and wind in ("strong", "gale") and temp in ("warm", "scorching"):
        return "Thunderstorm"
    if precip == "heavy" and wind in ("strong", "gale") and is_cold:
        return "Ice Storm"
    if cloud in ("overcast", "mostly_cloudy") and precip == "none" and wind == "calm" and is_cold:
        return "Frost"
    if cloud in ("overcast", "mostly_cloudy") and precip == "none" and wind in ("calm", "light_breeze"):
        if temp in ("cool", "mild"):
            return "Fog"
    return None


# ---------------------------------------------------------------------------
# Flavor text per axis
# ---------------------------------------------------------------------------

CLOUD_FLAVOR: dict[str, list[str]] = {
    "clear": [
        "The sky stretches cloudless and bright above the Empire.",
        "Not a single cloud mars the vast expanse of blue.",
    ],
    "partly_cloudy": [
        "White clouds drift lazily across an otherwise blue sky.",
        "Shadows chase patches of sunlight across the landscape.",
    ],
    "mostly_cloudy": [
        "A thick layer of clouds covers most of the sky, letting only occasional light through.",
        "Grey clouds dominate the heavens, with rare breaks of pale blue.",
    ],
    "overcast": [
        "A grey blanket of cloud covers the sky from horizon to horizon.",
        "The sun hides behind a uniform grey ceiling. The light is flat and muted.",
    ],
}

PRECIP_FLAVOR_RAIN: dict[str, list[str]] = {
    "none": [],
    "drizzle": [
        "A fine mist of rain hangs in the air, barely dampening the ground.",
        "Tiny droplets drift down, scarcely enough to darken the stones.",
    ],
    "light": [
        "A gentle rain falls, pattering softly on tile rooftops and garden stones.",
        "Fine rain drifts through the air. The earth drinks gratefully.",
    ],
    "moderate": [
        "Steady rain drums on the rooftops. Puddles form in the courtyards.",
        "Rain falls in curtains across the land. Travelers pull their straw cloaks tight.",
    ],
    "heavy": [
        "Rain hammers the ground in sheets. Streams swell and roads turn to mud.",
        "The heavens open. Water cascades from every eave and gutter.",
    ],
}

PRECIP_FLAVOR_SNOW: dict[str, list[str]] = {
    "none": [],
    "drizzle": [
        "A few stray flurries drift down, vanishing as they touch the ground.",
        "Sparse snowflakes wander through the cold air, barely dusting the rooftops.",
    ],
    "light": [
        "Snow falls gently, muffling the world in soft white silence.",
        "Snowflakes drift down like scattered petals, blanketing the Empire.",
    ],
    "moderate": [
        "Snow falls steadily, piling on rooftops and blanketing the roads.",
        "The snowfall thickens, turning the landscape into a white canvas.",
    ],
    "heavy": [
        "Snow falls thick and fast, burying the landscape. Visibility is poor.",
        "A heavy snowfall buries the landscape. The world becomes a white void.",
    ],
}

WIND_FLAVOR: dict[str, list[str]] = {
    "calm": [],
    "light_breeze": [
        "A gentle breeze stirs the banners on the castle walls.",
    ],
    "breezy": [
        "A steady wind tugs at robes and rustles through the trees.",
    ],
    "strong": [
        "A fierce wind tears at banners and robes. Dust swirls through the streets.",
        "The wind howls around corners and through corridors. Shutters rattle.",
    ],
    "gale": [
        "A howling gale batters the land. Walking against it is an effort.",
        "The wind screams across the rooftops, tearing loose tiles and scattering debris.",
    ],
}

TEMP_FLAVOR: dict[str, list[str]] = {
    "freezing": [
        "The cold bites to the bone. Breath hangs in thick white clouds.",
        "A bitter, penetrating cold grips the land. Ice forms on every surface.",
    ],
    "cold": [
        "The air is sharp and cold. Servants stoke the braziers against the chill.",
        "A hard chill settles over the land. Frost rimes the grass at dawn.",
    ],
    "cool": [
        "The air is crisp and refreshing, carrying a pleasant coolness.",
        "A cool touch lingers in the air, neither uncomfortable nor unwelcome.",
    ],
    "mild": [
        "The temperature is pleasant and mild, neither hot nor cold.",
        "A comfortable warmth fills the air, inviting folk outdoors.",
    ],
    "warm": [
        "The warmth of the day settles over the land. Shade is welcome.",
        "Heat builds through the day, making the shade of gardens appealing.",
    ],
    "scorching": [
        "The sun blazes mercilessly. The air shimmers and the stones burn to the touch.",
        "The heat is oppressive. Even the cicadas fall silent in the midday blaze.",
    ],
}

SPECIAL_FLAVOR: dict[str, list[str]] = {
    "Blizzard": [
        "A howling blizzard reduces visibility to nothing. The world is wind and ice.",
        "The blizzard screams across the land. Only fools or heroes venture out.",
    ],
    "Thunderstorm": [
        "Thunder cracks across the sky. Lightning illuminates the clouds from within.",
        "A violent storm rages. Thunder shakes the walls and lightning splits the darkness.",
    ],
    "Ice Storm": [
        "Ice coats every surface. The roads are treacherous, the trees encased in glass.",
        "An ice storm has transformed the land into a glittering, deadly landscape.",
    ],
    "Frost": [
        "Frost rimes the grass and rooftops at dawn. Breath clouds in the cold air.",
        "A hard frost grips the land. Ice crystals glitter on every surface.",
    ],
    "Fog": [
        "Thick fog blankets the land. Shapes appear and vanish like ghosts.",
        "The world disappears into white. Sound travels strangely in the dense fog.",
    ],
}


# ---------------------------------------------------------------------------
# Weather rolling
# ---------------------------------------------------------------------------

def _roll_axis(table: list[tuple[str, int]]) -> str:
    values = [v for v, _w in table]
    weights = [w for _v, w in table]
    total = sum(weights)
    if total == 0:
        return values[0]
    return random.choices(values, weights=weights, k=1)[0]


def roll_weather(season: str) -> dict[str, str]:
    cloud = _roll_axis(SEASON_CLOUD.get(season, SEASON_CLOUD["Spring"]))
    precip = _roll_axis(SEASON_PRECIP.get(season, SEASON_PRECIP["Spring"]))
    wind = _roll_axis(SEASON_WIND.get(season, SEASON_WIND["Spring"]))
    temp = _roll_axis(SEASON_TEMP.get(season, SEASON_TEMP["Spring"]))

    if precip != "none" and cloud == "clear":
        cloud = "mostly_cloudy"

    return {"cloud": cloud, "precip": precip, "wind": wind, "temperature": temp}


def _precip_label(precip: str, temp: str) -> str:
    is_cold = temp in ("freezing", "cold")
    labels = PRECIP_LABELS_SNOW if is_cold else PRECIP_LABELS_RAIN
    return labels.get(precip, precip.title())


def _build_flavor(cloud: str, precip: str, wind: str, temp: str) -> str:
    special = _detect_special(cloud, precip, wind, temp)
    if special and special in SPECIAL_FLAVOR:
        return random.choice(SPECIAL_FLAVOR[special])

    parts: list[str] = []
    temp_opts = TEMP_FLAVOR.get(temp, [])
    if temp_opts:
        parts.append(random.choice(temp_opts))
    cloud_opts = CLOUD_FLAVOR.get(cloud, [])
    if cloud_opts:
        parts.append(random.choice(cloud_opts))

    is_cold = temp in ("freezing", "cold")
    precip_map = PRECIP_FLAVOR_SNOW if is_cold else PRECIP_FLAVOR_RAIN
    precip_opts = precip_map.get(precip, [])
    if precip_opts:
        parts.append(random.choice(precip_opts))
    wind_opts = WIND_FLAVOR.get(wind, [])
    if wind_opts:
        parts.append(random.choice(wind_opts))

    return " ".join(parts) if parts else "The weather is unremarkable."


def _weather_title(cloud: str, precip: str, wind: str, temp: str) -> str:
    special = _detect_special(cloud, precip, wind, temp)
    if special:
        return special
    is_cold = temp in ("freezing", "cold")
    if precip != "none":
        return _precip_label(precip, temp)
    return CLOUD_LABELS.get(cloud, "Weather")


def _weather_type_key(cloud: str, precip: str, wind: str, temp: str) -> str:
    special = _detect_special(cloud, precip, wind, temp)
    if special:
        return special.lower().replace(" ", "_")
    if precip != "none":
        is_cold = temp in ("freezing", "cold")
        if is_cold:
            return f"snow_{precip}"
        return f"rain_{precip}"
    return cloud


# ---------------------------------------------------------------------------
# Embed builders
# ---------------------------------------------------------------------------

def _weather_embed(
    cloud: str, precip: str, wind: str, temp: str,
    date_str: str | None = None,
) -> discord.Embed:
    title = _weather_title(cloud, precip, wind, temp)
    flavor = _build_flavor(cloud, precip, wind, temp)
    color = TEMP_COLORS.get(temp, discord.Color.dark_gold())

    embed = discord.Embed(
        title=title,
        description=flavor,
        color=color,
    )
    embed.add_field(name="Temperature", value=TEMP_LABELS.get(temp, temp.title()), inline=True)
    embed.add_field(name="Sky", value=CLOUD_LABELS.get(cloud, cloud.title()), inline=True)
    embed.add_field(name="Wind", value=WIND_LABELS.get(wind, wind.title()), inline=True)
    embed.add_field(name="Precipitation", value=_precip_label(precip, temp), inline=True)

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

    cloud = w.get("cloud", "clear")
    precip = w.get("precip", "none")
    wind = w.get("wind", "calm")
    temp = w.get("temperature", "mild")

    if not cloud:
        cloud = "clear"
    if not precip:
        precip = "none"
    if not wind:
        wind = "calm"
    if not temp:
        temp = "mild"

    from bot import ROKUGANI_MONTHS
    cal = _d.store.get_calendar(guild_id)
    date_str = None
    if cal:
        year, month, day = cal
        month_name, season = ROKUGANI_MONTHS[month - 1]
        date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {year}"

    embed = _weather_embed(cloud, precip, wind, temp, date_str)
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# /weather set - manual override per axis
# ---------------------------------------------------------------------------

@weather.command(
    name="set",
    description="Manually set the weather (any combination of axes). [Fortune]",
)
@app_commands.describe(
    temperature="Temperature level.",
    cloud="Cloud cover level.",
    wind_level="Wind level.",
    precipitation="Precipitation level (renders as rain or snow based on temperature).",
)
@app_commands.choices(
    temperature=[
        app_commands.Choice(name=v, value=k) for k, v in TEMP_LABELS.items()
    ],
    cloud=[
        app_commands.Choice(name=v, value=k) for k, v in CLOUD_LABELS.items()
    ],
    wind_level=[
        app_commands.Choice(name=v, value=k) for k, v in WIND_LABELS.items()
    ],
    precipitation=[
        app_commands.Choice(name="None", value="none"),
        app_commands.Choice(name="Drizzle / Flurries", value="drizzle"),
        app_commands.Choice(name="Light", value="light"),
        app_commands.Choice(name="Moderate", value="moderate"),
        app_commands.Choice(name="Heavy", value="heavy"),
    ],
)
async def weather_set(
    interaction: discord.Interaction,
    temperature: app_commands.Choice[str] | None = None,
    cloud: app_commands.Choice[str] | None = None,
    wind_level: app_commands.Choice[str] | None = None,
    precipitation: app_commands.Choice[str] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if not await _d.require_dm_role(interaction):
        return

    if temperature is None and cloud is None and wind_level is None and precipitation is None:
        await interaction.response.send_message(
            "Provide at least one axis to set: `temperature`, `cloud`, `wind_level`, or `precipitation`.",
            ephemeral=True,
        )
        return

    guild_id = str(interaction.guild_id)

    current = _d.store.get_weather(guild_id) or {}
    c_cloud = current.get("cloud", "clear") or "clear"
    c_precip = current.get("precip", "none") or "none"
    c_wind = current.get("wind", "calm") or "calm"
    c_temp = current.get("temperature", "mild") or "mild"

    new_cloud = cloud.value if cloud else c_cloud
    new_precip = precipitation.value if precipitation else c_precip
    new_wind = wind_level.value if wind_level else c_wind
    new_temp = temperature.value if temperature else c_temp

    type_key = _weather_type_key(new_cloud, new_precip, new_wind, new_temp)
    _d.store.set_weather(
        guild_id, type_key, str(interaction.user.id),
        cloud=new_cloud, precip=new_precip, wind=new_wind, temperature=new_temp,
    )

    from bot import ROKUGANI_MONTHS
    cal = _d.store.get_calendar(guild_id)
    date_str = None
    if cal:
        year, month, day = cal
        month_name, season = ROKUGANI_MONTHS[month - 1]
        date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {year}"

    embed = _weather_embed(new_cloud, new_precip, new_wind, new_temp, date_str)
    embed.set_footer(text=f"Set by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed)

    await _update_weather_display(
        interaction.guild, new_cloud, new_precip, new_wind, new_temp, date_str,
    )


# ---------------------------------------------------------------------------
# /weather forecast - show per-axis probability tables
# ---------------------------------------------------------------------------

@weather.command(
    name="forecast",
    description="Show the seasonal probability tables for each weather axis.",
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
    color = SEASON_COLORS.get(season, discord.Color.dark_gold())

    embed = discord.Embed(
        title=f"{season} Weather Forecast",
        color=color,
    )

    def _format_table(
        table: list[tuple[str, int]], labels: dict[str, str],
    ) -> str:
        total = sum(w for _, w in table)
        lines: list[str] = []
        for key, weight in table:
            if weight <= 0:
                continue
            pct = (weight / total * 100) if total > 0 else 0
            lines.append(f"**{labels.get(key, key.title())}** - {pct:.0f}%")
        return "\n".join(lines)

    cloud_table = SEASON_CLOUD.get(season, [])
    embed.add_field(
        name="Cloud Cover",
        value=_format_table(cloud_table, CLOUD_LABELS),
        inline=True,
    )

    temp_table = SEASON_TEMP.get(season, [])
    embed.add_field(
        name="Temperature",
        value=_format_table(temp_table, TEMP_LABELS),
        inline=True,
    )

    embed.add_field(name="​", value="​", inline=True)

    precip_table = SEASON_PRECIP.get(season, [])
    precip_labels = {
        "none": "None", "drizzle": "Drizzle / Flurries",
        "light": "Light", "moderate": "Moderate", "heavy": "Heavy",
    }
    embed.add_field(
        name="Precipitation",
        value=_format_table(precip_table, precip_labels),
        inline=True,
    )

    wind_table = SEASON_WIND.get(season, [])
    embed.add_field(
        name="Wind",
        value=_format_table(wind_table, WIND_LABELS),
        inline=True,
    )

    embed.set_footer(text="Each axis rolls independently when a new day dawns.")
    await interaction.response.send_message(embed=embed, ephemeral=True)


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

async def _update_weather_display(
    guild: discord.Guild,
    cloud: str, precip: str, wind: str, temp: str,
    date_str: str | None,
) -> None:
    guild_id = str(guild.id)
    info = _d.store.get_weather_channel(guild_id)
    if info is None:
        return
    channel_id, message_id = info
    channel = guild.get_channel(int(channel_id))
    if channel is None:
        return
    embed = _weather_embed(cloud, precip, wind, temp, date_str)
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

    axes = roll_weather(season)
    cloud = axes["cloud"]
    precip = axes["precip"]
    wind = axes["wind"]
    temp = axes["temperature"]

    guild_id = str(guild.id)
    type_key = _weather_type_key(cloud, precip, wind, temp)
    _d.store.set_weather(
        guild_id, type_key, "system",
        cloud=cloud, precip=precip, wind=wind, temperature=temp,
    )

    date_str = f"Day {day}, Month of the {month_name} ({season}) - Year {_year}"
    await _update_weather_display(guild, cloud, precip, wind, temp, date_str)
