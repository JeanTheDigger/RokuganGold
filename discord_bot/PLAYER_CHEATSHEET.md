# Rokugan Bot: Player Cheat Sheet

Each section below fits in one Discord message, so you can paste them one by one into a pinned channel.

**How to use the bot**
Type `/` in any channel, pick a command, then fill in its options. Discord marks the required ones and leaves the rest optional.
`/help` opens the full manual with a topic menu. `/whoami` is your home screen: a status card with buttons for Void, Kata, Kiho, tattoos, gear and your sheet.
If a menu says it is no longer live, the bot restarted. Run the command again.
You have one character, so anything you do for yourself needs no name. Options tagged [Fortune] are for staff and refuse you.

---

**Getting started**
`/sheet create` Open the character creation wizard in a private channel. Fill every step, press Submit, and staff review it.
`/sheet view` Your full character sheet.
`/whoami` Your hub with quick buttons.
`/inventory` Wield or drop weapons, put armor on or off, remove items, see your purse.
`/portrait set` Attach an image or give a link as your portrait. `/portrait show` posts it for everyone, `/portrait clear` removes it.
`/players` Everyone approved on the server. `/date` The in-game date. `/weather now` Today's weather, `/weather forecast` the seasonal odds. `/ping` Checks the bot is awake.
`/sheet data export` Download your sheet as a JSON backup.

---

**Dice and checks**
`/roll rolled:7 kept:3` Roll and Keep. Options: `tn:`, `raises:`, `bonus:`, `emphasis:`, `unskilled:`, `reason:`, `secret:` (hidden by default).
`/dice 5k3` Shorthand. Also `7k2+5` or `4k2-3`.
`/macro save` Save a roll you repeat, then `/macro roll name:attack`. Also `/macro list` and `/macro delete`.
`/history` The most recent rolls in this channel.
`/check skill` Generic Skill roll against a TN your GM gives you. It needs a trait, a skill and a TN.
`/check social`, `/check stealth`, `/check investigate`, `/check lore`, `/check craft`, `/check medicine`, `/check horsemanship` Same idea, with the right trait chosen for you.
`/check fear`, `/check honor`, `/check poison` The special rolls for Fear, the once-a-session Honor re-roll and poison resistance.
On checks: `bonus:` adds a flat bonus, `spend_void:` spends a Void Point for +1k1, `emphasis:` applies an emphasis, `secret:` True keeps it private and False shows only the total, TN and outcome to everyone.

---

**Void, kata, kiho and tattoos**
`/void status` How many Void Points you have. `/sheet void` has the same three commands.
`/void spend reason:` Spend one and log why.
`/void refresh mode:Meditation` Roll Meditation/Void to recover one. A full rest refresh is done by staff.
`/sheet kata activate` Set your active Kata. Leave the name blank to drop it. Only one at a time.
`/sheet kiho activate` Turn a Kiho on or off. One Internal, one Kharmic and one Mystical at once, Martial ones stack.
`/sheet tattoo activate` Set your active tattoo. One at a time.

---

**Experience (XP)**
Staff grant XP. You spend it only in your own private character channel, the one named after your character.
`/xp balance` What you have.
`/xp spend` A menu of everything you can buy. Or buy directly:
`/xp trait`, `/xp skill`, `/xp emphasis`, `/xp kata`, `/xp kiho`, `/xp advantage`, `/xp remove_disadvantage`
`/xp spell` Memorise a spell you already know, so no scroll is needed. It never gives you a new spell.
`/xp costs` The cost table.
**Ranking up.** When your Insight crosses a School Rank threshold, the reply tells you and your school's new technique appears on your sheet. Shugenja also get a picker for three new spells, up to their rank's Mastery limit. `/sheet learn` reopens it if you stop halfway.

---

**Money and items**
`/pay member: koku: bu: zeni:` Give money to another player's character.
`/trade member: item: quantity:` Hand an item from your inventory to another player's character.
`/inventory` Shows what you carry and lets you wield, drop, wear and remove things. Arrows sit in your quiver and run out as you shoot.
Staff hand out items found in play with `/give` and take them with `/take`. You are told in your character channel.

---

**Fighting**
Start: `/combat setup` invites players with Accept buttons. Or `/combat start`, then `/combat join`. `/combat board` posts the action board. `/combat roster add`, `remove` and `close` manage an invite list that has not begun.
Turn: `/combat next` advances. `/combat turn done` ends your turn. `/combat status` shows the order. `/combat recap` shows the tally.
Ending: `/combat end` closes a fight with only player characters in it. Once an NPC is in, only staff can.
Your turn: Choose a stance first with `/fight stance`, since it locks once you act. Then `/fight attack`.
`/fight attack` Options: a target, `weapon:`, `raises:`, `increased_damage:`, `maneuver:` (Feint, Disarm, Knockdown, Called Shot, Extra Attack) and `point_blank:` for a ranged shot in melee.
`/fight action` Track Simple, Complex or Free actions. `/fight full_defense`, `/fight guard`, `/fight mount`, `/fight status`.
`/fight condition` Ask staff to apply Dazed, Prone and so on.
`/combat void armor`, `/combat void initiative`, `/combat void swap` Spend a Void Point in combat.
The board buttons do most of this: Stance, Attack, End Turn, Techniques, Kata, Kiho, Tattoo, Cast Spell, Gear, and the Void options.

---

**Grapples, duels and hits**
`/grapple` Start a grapple board by picking the two fighters from a menu. `/engage grapple start` does the same by name.
`/engage grapple initiate`, `control`, `hit`, `throw`, `pin`, `break_free` The individual steps.
`/duel` Start an Iaijutsu duel board. `/engage duel start` does the same by name. `/engage duel assess`, `focus` and `strike` are the stages.
When you hit, a damage card goes to staff. Once they apply it, the channel sees the damage and your new wound level, never the count.

---

**Magic**
`/spell list`, `/spell search`, `/spell view` Browse the spell catalogue.
`/spell cast name:` Cast a spell you know. Options: `raises:`, `spend_void:`, `target:`, `conceal:` and `cast_element:` for Universal spells like Commune and Sense.
`/spell importune name:` Ask the kami for a spell you do not know, at a harder TN.
**Limits.** You learn and cast spells up to your School Rank in Mastery. Your Affinity element counts one higher, your Deficiency one lower. Slots refresh each new day.
New spells come only from rank-ups and from staff.

---

**Rooms, letters and the world**
`/room create` Make a private play room and host it. Then `/room invite`, `/room kick`, `/room members`, `/room describe`, `/room list`, `/room close`. Run these inside the room.
`/location list` and `/location area list` See the places and areas on the server. `/location describe` and `/location close` work for whoever made one.
`/letter send recipient: message:` Send an in-character letter to a player or an NPC. `/letter list` and `/letter read` bring up old ones.
`/rumor list` and `/rumor view` Rumors that reached your character.

---

**Rules lookups**
`/ref search` Search every catalogue at once.
`/ref weapon`, `/ref armor`, `/ref advantage`, `/ref kata`, `/ref kiho`, `/ref school`, `/ref family`, `/ref tattoo` Each has `list`, `view` and `search`, except weapons (`list`, `view`) and families (`list`, `search`).
`/ref heritage table` A clan's Heritage Table.
`/ref encumbrance`, `/ref ancestors`, `/ref travel`, `/ref modifiers`, `/ref calledshot`, `/ref armor_tn`, `/ref dual_wield` Quick rules and your own numbers.
`/compare` Put two characters side by side.
