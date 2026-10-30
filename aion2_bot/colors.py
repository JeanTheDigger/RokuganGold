"""Legion colors: Red, Green, Blue (0-255 each) and a brightness (0-100%).

Brightness only darkens: 100% is the exact color, 50% halves each channel.
The result is the color of the Legion's role, so its members' names show in it.

Discord treats color 0 (pure black) as "no color", so a result of black is
nudged to #010101, which looks the same but still counts as a color.
"""

from __future__ import annotations

import math
import re

# Colors closer than this (straight-line distance in RGB, 0-441) count as
# "very close" and get a warning. ~40 is about where two name colors start to
# look alike in Discord's member list.
CLOSE_DISTANCE = 40

BLACK_STANDIN = 0x010101

RGB_HELP = "three numbers from 0 to 255, like `200, 30, 60`"


def parse(rgb_text: str, brightness_text: str = "") -> tuple[int | None, str | None]:
    """(color, error). An empty RGB field means no color: (None, None)."""
    rgb_text = rgb_text.strip()
    if not rgb_text:
        return None, None
    parts = [p for p in re.split(r"[\s,;/]+", rgb_text) if p]
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        return None, f"The color must be {RGB_HELP} (you wrote `{rgb_text}`)."
    r, g, b = (int(p) for p in parts)
    if not all(0 <= c <= 255 for c in (r, g, b)):
        return None, f"Each color number must be between 0 and 255 (you wrote `{rgb_text}`)."
    brightness_text = brightness_text.strip().rstrip("%").strip()
    if brightness_text and not brightness_text.isdigit():
        return None, f"Brightness must be a whole number from 0 to 100 (you wrote `{brightness_text}`)."
    brightness = int(brightness_text) if brightness_text else 100
    if not 0 <= brightness <= 100:
        return None, f"Brightness must be from 0 to 100 (you wrote `{brightness}`)."
    return apply_brightness(r, g, b, brightness), None


def apply_brightness(r: int, g: int, b: int, brightness: int) -> int:
    scale = brightness / 100
    value = (round(r * scale) << 16) | (round(g * scale) << 8) | round(b * scale)
    return value or BLACK_STANDIN


def channels(color: int) -> tuple[int, int, int]:
    return (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF


def describe(color: int | None) -> str:
    """'#C81E3C (200, 30, 60)', or 'no color'."""
    if color is None:
        return "no color"
    r, g, b = channels(color)
    return f"#{color:06X} ({r}, {g}, {b})"


def distance(a: int, b: int) -> float:
    return math.dist(channels(a), channels(b))


def close_to(color: int | None, others: list[tuple[str, int]]) -> list[str]:
    """Names of the other Legions whose color is very close to `color`."""
    if color is None:
        return []
    return [name for name, other in others if distance(color, other) < CLOSE_DISTANCE]
