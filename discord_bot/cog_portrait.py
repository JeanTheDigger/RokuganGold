"""/portrait: A picture for a character, shown on the hub, the sheet, and on demand.

/portrait set: Attach an image or give a link (your active character; staff: any character).
/portrait show: Post a character's portrait in the channel for everyone.
/portrait clear: Remove it.
"""

from __future__ import annotations

import discord
from discord import app_commands

import portraits
import storage as _storage_mod


class _Deps:
    store: _storage_mod.Store
    NPC_OWNER: str
    require_guild: object
    is_dm: object
    resolve_active: object
    find_any_character: object
    any_character_autocomplete: object
    audit_stat: object


_d = _Deps()


def init(
    *, store, npc_owner: str, require_guild, is_dm, resolve_active, find_any_character,
    any_character_autocomplete, audit_stat,
) -> None:
    _d.store = store
    _d.NPC_OWNER = npc_owner
    _d.require_guild = require_guild
    _d.is_dm = is_dm
    _d.resolve_active = resolve_active
    _d.find_any_character = find_any_character
    _d.any_character_autocomplete = any_character_autocomplete
    _d.audit_stat = audit_stat
    portrait_set.autocomplete("character")(any_character_autocomplete)
    portrait_clear.autocomplete("character")(any_character_autocomplete)
    portrait_show.autocomplete("character")(_show_character_ac)


portrait_group = app_commands.Group(name="portrait", description="A picture for your character: Set it, show it, clear it.")


async def _show_character_ac(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    """Players see active player characters; staff see every character."""
    if interaction.guild_id is None:
        return []
    if _d.is_dm(interaction):
        return await _d.any_character_autocomplete(interaction, current)
    cur = current.strip().lower()
    names = sorted(rec.character.name for _, rec in _d.store.list_active_pcs(str(interaction.guild_id)))
    return [app_commands.Choice(name=n, value=n) for n in names if cur in n.lower()][:25]


async def _target(interaction: discord.Interaction, character: str | None):
    """(record, error): A named character (staff only) or the invoker's active one."""
    if character:
        if not _d.is_dm(interaction):
            return None, "Only staff can set or clear another character's portrait."
        rec = _d.find_any_character(str(interaction.guild_id), character.strip())
        if rec is None:
            return None, f"No character named **{character}**."
        return rec, None
    return await _d.resolve_active(interaction, None)


@portrait_group.command(name="set", description="Attach an image, or give a link, as your character's portrait.")
@app_commands.describe(
    image="Upload a PNG, JPEG, GIF or WebP (up to 8 MB). The bot keeps a copy.",
    url="Or a direct image link (https://...) hosted elsewhere.",
    character="Another character by name [Fortune].",
)
async def portrait_set(
    interaction: discord.Interaction,
    image: discord.Attachment | None = None,
    url: app_commands.Range[str, 1, 400] | None = None,
    character: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    if (image is None) == (url is None):
        await interaction.response.send_message("Give either an `image:` upload or a `url:` link, not both and not neither.", ephemeral=True)
        return
    rec, err = await _target(interaction, character)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if url is not None:
        link = url.strip()
        if not link.lower().startswith(("http://", "https://")):
            await interaction.response.send_message("The link must start with http:// or https://.", ephemeral=True)
            return
        portraits.remove_file(rec)
        c.portrait = link
    else:
        await interaction.response.defer(ephemeral=True)
        ok, value = await portraits.save_upload(rec, image)
        if not ok:
            await interaction.followup.send(value, ephemeral=True)
            return
        c.portrait = value
    changed = _d.store.save(rec)
    await _d.audit_stat(interaction, rec, "portrait", changed)
    embed = discord.Embed(title=f"{c.name}: Portrait set", color=discord.Color.gold())
    portraits.apply(embed, rec, large=True)
    kwargs = portraits.send_kwargs(rec)
    if interaction.response.is_done():
        await interaction.followup.send(embed=embed, ephemeral=True, **kwargs)
    else:
        await interaction.response.send_message(embed=embed, ephemeral=True, **kwargs)


@portrait_group.command(name="show", description="Post a character's portrait here for everyone to see.")
@app_commands.describe(character="Whose portrait (default: Your own character).")
async def portrait_show(
    interaction: discord.Interaction,
    character: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    guild = str(interaction.guild_id)
    if character:
        rec = _d.find_any_character(guild, character.strip())
        if rec is None:
            await interaction.response.send_message(f"No character named **{character}**.", ephemeral=True)
            return
        if rec.owner_id == _d.NPC_OWNER and not _d.is_dm(interaction):
            await interaction.response.send_message("Only staff can show an NPC's portrait.", ephemeral=True)
            return
    else:
        rec, err = await _d.resolve_active(interaction, None)
        if err:
            await interaction.response.send_message(err, ephemeral=True)
            return
    c = rec.character
    if not portraits.has_portrait(rec):
        await interaction.response.send_message(f"**{c.name}** has no portrait yet. The player sets one with `/portrait set`.", ephemeral=True)
        return
    subtitle = " · ".join(b for b in (c.clan, c.family) if b)
    embed = discord.Embed(title=c.name, description=subtitle or None, color=discord.Color.gold())
    portraits.apply(embed, rec, large=True)
    embed.set_footer(text=f"Shown by {interaction.user.display_name}")
    await interaction.response.send_message(embed=embed, **portraits.send_kwargs(rec))


@portrait_group.command(name="clear", description="Remove your character's portrait.")
@app_commands.describe(character="Another character by name [Fortune].")
async def portrait_clear(
    interaction: discord.Interaction,
    character: app_commands.Range[str, 1, 80] | None = None,
) -> None:
    if not await _d.require_guild(interaction):
        return
    rec, err = await _target(interaction, character)
    if err:
        await interaction.response.send_message(err, ephemeral=True)
        return
    c = rec.character
    if not c.portrait:
        await interaction.response.send_message(f"**{c.name}** has no portrait.", ephemeral=True)
        return
    portraits.remove_file(rec)
    c.portrait = ""
    changed = _d.store.save(rec)
    await _d.audit_stat(interaction, rec, "portrait cleared", changed)
    await interaction.response.send_message(f"Removed **{c.name}**'s portrait.", ephemeral=True)
