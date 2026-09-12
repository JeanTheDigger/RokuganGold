"""L5R 4th Edition rules, reimplemented in pure Python for the Discord bot.

This package is a standalone translation of the rules logic found in the
Godot project's `/simulation/` and `/shared/` GDScript. It has NO dependency
on Godot and NO dependency on Discord: it is plain, testable Python.

The GDScript remains the authoritative reference implementation; every module
here names the GDScript file it was ported from so the two can be kept in sync
by hand. Game values are never invented here: they are copied from the GDD or
from the existing GDScript, per the project's "do not invent mechanics" rule.
"""
