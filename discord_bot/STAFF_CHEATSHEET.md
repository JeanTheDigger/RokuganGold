# Rokugan Bot: Staff Cheat Sheet
*For Fortune and Kami.*

Fortune run the game. Kami also administer the server. Commands tagged [Kami] need Kami.

*A | B means pick one. Words after a command are its options. Most commands take member (pick a player) or character (type any name, NPCs too).*

---

## Know this first
- `/dm wizard`  A menu of every staff action. Start here if you forget a command.
> `character` takes any character or NPC by name, from any channel. It autocompletes for staff only.
> Players get a private notice when you edit their sheet, grant XP, deal damage, heal or give items.
> The bot never changes Honor or Glory by itself, and never hurts NPCs by itself. You do both.

---

## Set up once (Kami)
- `/setup server`  Build the roles and channels.
- `/dm approval_channel`  Where new characters arrive.
- `/dm damage_channel`  Where damage and healing cards arrive.
- `/dm log_channel`  The combat event log.
- `/dm xp_log_channel`  A Kami-only log of XP and rank-up spells.
- `/dm date_channel`  The pinned in-game date.
- `/rumor channel`  The notice board for public rumors.
- `/sync`  Re-register the commands if they look stale.
> Most channel commands have a clear twin, like `/dm clear_log`.

---

## Each session
- `/dm party`  Every active PC at a glance.
- `/dm pending`  Approvals still waiting, with jump links.
- `/dm new_day`  Heal everyone, refresh Void and spell slots.
- `/dm setdate`  Set the calendar. It also shows in #calendar.
- `/dm announce`  Post a session with RSVP reactions.
- `/weather set`  Choose the weather.
- `/dm undo preview`  Roll back the last change. Try preview first.
- `/dm revive`  Undo a bug death. Otherwise death is permanent.
- `/dm taint`  View or change Shadowlands Taint.
- `/dm influence`  Track Influence in a court scene.

---

## Approvals and damage
> New characters: Press Approve, or Deny to send the wizard back so the player can adjust it.
> Damage cards: Press Roll & Apply Damage or Deny. Players only see the wound level.
- `/dm damage | heal`  Send a card for a character.
- `/dm treat`  A healer rolls Medicine and you approve.
- `/edit wound | heal`  Change wounds directly, with no card.
> Condition requests from `/fight condition` and spells also come to you.

---

## Edit characters
- `/edit trait`  Set a Trait or Void.
- `/edit skill`  One skill, or many like Kenjutsu 3, Courtier 2.
- `/edit field`  Honor, glory, koku, school rank, void points and more.
- `/edit feature`  Add or remove advantages, techniques, kata, kiho, weapons, emphasis, tattoos or spells.
- `/edit spell`  Add or remove a spell. It warns you when it is above their rank.
- `/edit elements`  Set Affinity and Deficiency by hand. The wizard asks Isawa and similar schools.
- `/edit identity | equip | activate | mount | rename | notes`  Clan, gear, active abilities, name and notes.
- `/sheet view | list | owner | delete | learn`  Work on another sheet with member or character.
- `/sheet data import`  Create a character from JSON.

---

## XP, items and portraits
- `/xp grant amount member reason`  Give XP. A negative amount corrects. Add a reason.
- `/xp balance`  Check a total.
- `/give | take what`  A weapon, armor, money or any item. Arrows go to the quiver.
- `/inventory character`  Open anyone's gear, NPCs too.
- `/portrait set character`  Set or clear another character's picture.
> Rank-ups are automatic. The new technique lands on the sheet, and shugenja get a three-spell picker.

---

## NPCs
- `/npc create`  Step-by-step builder with exact stats.
- `/npc form`  One typed stat block.
- `/npc generate`  A quick NPC from clan, family, school and rank.
- `/npc edit | view | list | clone | delete`  Manage stored NPCs.
- `/npc template save | spawn | list`  Reusable templates. Spawn several at once.
- `/npc place | dismiss`  Put an NPC in a room or take them out.
- `/npc say`  Speak as an NPC.
- `/letter sendas`  Send a letter as any character.

---

## Creatures and groups
- `/creature catalog | search | info`  Browse the bestiary.
- `/creature spawn`  Make one from a template.
- `/creature create`  Build a custom creature.
- `/creature wound | heal`  Change its wounds directly.
- `/creature attack`  A creature attacks.
- `/creature list | view | delete`  Manage spawned creatures.
- `/category create | add | bulk_add | list | view`  Group NPCs and creatures.
- `/category spawn`  Spawn a whole group.

---

## Run a fight
- `/combat start | setup`  Begin a fight.
- `/combat npc | creature | category | room`  Add your side, or everyone in a room.
- `/combat add`  A quick monster from its Reflexes.
- `/combat next | board | status | summary`  Run the turn order.
- `/combat turn init | hold | delay | act | surprise`  Adjust the order.
- `/combat condition set | clear | list`  Dazed, Grappled and the rest.
- `/fight env cover | notes | damage`  Terrain and hazards.
- `/combat remove | end`  Take someone out, or finish.
> NPC hits are not applied for you. Use `/creature wound`, `/edit wound` or a `/dm damage` card.

---

## Act for NPCs
- `/fight attack attacker_npc`  An NPC attacks.
- `/spell cast attacker_npc`  An NPC casts.
- `/spell resist | interrupt | damage`  Resistance, interruption and damage dice.
- `/check contest | cooperative`  Contested rolls and team rolls.
- `/check skill name is_npc`  Roll for an NPC. Most checks take the same.
- `/engage battle start | status | roll | damage | table`  Mass battle.
- `/dm craft_extended`  A multi-step crafting project.
- `/ref heritage roll`  Roll on a clan's Heritage Table.

---

## The world
- `/rumor post | public | broadcast`  Send to characters, post a notice, or both.
- `/rumor list | delete`  Review and remove.
- `/location area create | delete`  Areas and who sees them.
- `/location create`  Add a location channel.
- `/location area fix-permissions`  Repair visibility.
- `/room close`  Close any room.
- `/stipend set | view | clear`  Monthly pay per clan.
