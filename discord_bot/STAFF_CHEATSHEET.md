# Rokugan Bot: Staff Cheat Sheet

For Fortune (game masters) and Kami (administrators). Each section fits in one Discord message, so paste them one by one into a staff channel.

**Roles and habits**
Kami can do everything. Fortune can do everything not tagged [Kami] in a command's description.
Most commands take `member:` (pick a player) or `character:` (type any character or NPC name, from any channel). The `character:` list autocompletes for staff only.
`/dm wizard` is a menu of every staff action, grouped by category. Start there if you forget a command.
Most replies are private to you. Players get a private notice in their character channel when you change their sheet, grant XP, deal damage, heal or give items.
The bot never adds Honor or Glory on its own, and it never applies damage to NPCs or creatures by itself. You do both with the commands below.

---

**First-time server setup (Kami)**
`/setup server` Build the roles and channel layout. Run once, as an administrator.
`/dm approval_channel` Where character submissions arrive for approval.
`/dm damage_channel` Where damage, heal and Medicine cards arrive.
`/dm log_channel` Combat event log. `/dm xp_log_channel` A Kami-only log of XP grants, spends and rank-up spells.
`/dm date_channel` The pinned in-game date. Most have a clear twin, like `/dm clear_log`. `/dm xp_log_channel` with no channel clears itself.
`/rumor channel` The notice board for public rumors.
`/stipend set`, `/stipend view`, `/stipend clear` Monthly pay per clan, paid on a new month.
`/dm roles` Who holds the Fortune and Kami roles.
`/sync` Re-register the slash commands with Discord if they ever look stale.
`/location area fix-permissions` Repair who can see the location areas.

---

**Running a session**
`/dm party` Every active PC at a glance. `/dm pending` Approvals still waiting, with jump links.
`/dm new_day` Advance one day: Heal everyone, refresh Void and spell slots.
`/dm setdate` Set the calendar. `/dm announce` Post a session with RSVP reactions.
`/weather set` Choose the weather. Players use `/weather now`.
`/dm influence` Track Influence Points in a court scene.
`/dm undo` Roll back the last change to a character or creature. Use `preview:` first.
`/dm revive` Undo a death caused by a bug. PC death is otherwise permanent.
`/dm taint` View or change Shadowlands Taint.

---

**Approvals**
Character submissions land in the approval channel. Press Approve, or Deny to send the wizard back to the player so they can adjust and resubmit.
Damage, healing and Medicine cards land in the damage channel. Press Roll & Apply Damage or Deny. Players are shown only the wound level.
`/dm damage`, `/dm heal` Send a card for a character.
`/dm treat` A healer rolls Medicine and you approve the result.
`/edit wound`, `/edit heal` Change wounds directly, with no card.
Spell condition requests and `/fight condition` requests also come to you for a yes or no.

---

**Editing characters**
`/edit trait` Set a Trait or Void. `/edit skill` Set one skill or many, like `Kenjutsu 3, Courtier 2`.
`/edit field` Set honor, glory, status, infamy, taint, koku, bu, zeni, age, school_rank, void points, armor bonuses, `spell_ranks_learned`.
`/edit identity` Clan, family and school. A catalogue family adds its +1 Trait.
`/edit feature` Add or remove an advantage, disadvantage, technique, kata, kiho, owned weapon, weapon quality, emphasis, tattoo or spell.
`/edit spell` Add or remove a spell. It warns you when the spell is above their Mastery limit.
`/edit elements` Set Affinity and Deficiency. Do this for Isawa, who choose theirs.
`/edit equip`, `/edit activate`, `/edit mount`, `/edit rename`, `/edit notes` Gear, active kata or kiho or tattoo, mounted state, name, freeform notes.
`/sheet view`, `/sheet list`, `/sheet owner`, `/sheet delete`, `/sheet data import`, `/sheet learn` With `member:` or `character:`.

---

**XP, items and portraits**
`/xp grant amount: member:` Give XP. A negative amount corrects it. Add `reason:` and the player sees it. `/xp balance` shows a total.
Players spend XP themselves in their own character channel. You can run `/xp trait` and friends with `member:` for them.
`/give what:` Hand a character a catalogue weapon, armor, money or any item name. `/take what:` removes one. Arrows go to the quiver.
`/inventory character:` Open anyone's gear panel, NPCs included, with armor and weapon quality controls.
`/portrait set character:` Set or clear another character's picture.
Rank-ups are automatic. The new technique lands on the sheet, and a shugenja gets a spell picker for three spells.

---

**NPCs**
`/npc create` Step-by-step builder with exact stats. `/npc form` One typed stat block. `/npc generate` Fast random NPC from clan, family, school and rank.
`/npc edit`, `/npc view`, `/npc list`, `/npc clone`, `/npc delete` Manage stored NPCs.
`/npc template save`, `spawn`, `list`, `view`, `delete` Reusable templates, `spawn` makes several copies.
`/npc place` and `/npc dismiss` Put an NPC in a room or remove it. `/npc say` Speak as an NPC in their own name.
`/letter sendas` Send a letter as any character. `/letter delete` Remove one from the log.

---

**Creatures and categories**
`/creature catalog`, `search`, `info`, `compare` Browse the bestiary without spawning.
`/creature spawn` Make one from a template, `randomize:` for stat variety. `/creature create` Build a custom one.
`/creature list`, `view`, `delete`, `wound`, `heal`, `attack` Manage and use spawned creatures.
`/category create`, `delete`, `rename`, `add`, `remove`, `bulk_add`, `bulk_remove`, `list`, `view` Group NPCs and creatures, such as "Bandit Camp".
`/category spawn` Spawn every creature template in a group at once.

---

**Running combat**
`/combat start` or `/combat setup`, then add people. A player may add themself with `/combat join`.
`/combat npc`, `/combat creature`, `/combat category`, `/combat room`, `/combat add` Bring in NPCs, creatures, a whole category, everyone in a room, or a quick Reflexes-only monster.
`/combat next`, `/combat board`, `/combat status`, `/combat summary`, `/combat recap` Run the order and review it.
`/combat turn init`, `hold`, `delay`, `act`, `surprise` Adjust the initiative order.
`/combat condition set`, `clear`, `list` Apply conditions such as Dazed or Grappled for a number of rounds.
`/fight env cover`, `notes`, `damage` Terrain bonuses, environment notes and hazards.
`/combat remove`, `/combat end` Take someone out or finish. Players can end a fight with only PCs in it.
NPC hits do not auto-apply. Use `/creature wound`, `/edit wound` or a `/dm damage` card.

---

**Attacks, checks and magic for others**
`/fight attack attacker_npc:` An NPC attacks. `/creature attack` A creature does, with its fixed stat block.
`/engage battle start`, `status`, `roll`, `damage`, `table` Mass battle.
`/engage duel` and `/engage grapple` Run the same boards as players. The NPC and member options let you name NPCs or other players' characters.
`/check contest` A contested roll between two characters. `/check cooperative` Helpers aid a roll.
Most `/check` commands take `name:` plus `is_npc:` to roll for an NPC, or `member:` for another player.
`/spell cast attacker_npc:` An NPC casts. `/spell resist`, `/spell interrupt`, `/spell damage` Resistance, mid-cast interruption and damage dice.
`/dm craft_extended` A multi-step crafting project.
`/ref heritage roll` Roll on a clan's Heritage Table.

---

**World, rumors and places**
`/rumor post` Send a rumor to characters by clan, family, school or name. Tiers: Official, Hearsay, Whisper.
`/rumor public` Post a notice to the board. `/rumor broadcast` Do both.
`/rumor list`, `/rumor delete` See all rumors and remove one.
`/location area create`, `delete` Make or remove a location area with its permissions.
`/location create` Add a location channel to an area, optionally private.
`/room close` Close any room, not just your own.
`/stipend` Clan stipends. `/weather set` Weather. `/dm date_channel` The date display.
