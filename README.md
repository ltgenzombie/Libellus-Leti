# Libellus Leti

**A companion addon for Animation Necromancers on Ascension WoW.**

*Libellus Leti* (“little book of death”) helps you see your resources, track your undead army, and make smarter talent and gearing choices — without digging through spreadsheets.

> **Early access (pre-1.0)** — Libellus Leti is still in active development. Features, numbers, and UI will change; you may hit bugs or rough edges while we work toward a 1.0 release.

---

## How do you pronounce it?

For the poll voters, the Latin pedants, and anyone who just wants to sound like they cast a spell:

| | |
|---|---|
| **Correct Latin** | **lih-BELL-us LET-ee** |
| **In guild voice** | “Libellus Letty” |
| **After two pulls** | “Little book, go” |
| **Wrong but funny** | “Libellus Lettuce” |
| **Acceptable** | Point at the minimap icon and grunt |

---

## What does it do?

### On-screen bars and feedback
- **Arc bars** around your character for mana and health
- **Floating numbers** when you regen mana or health (optional)
- **Animate bar** — see when your Animate spells are ready
- **Proc bar** and **zombie counter** — handy if you run Unrelenting Army or similar proc minions
- **Advisor alerts** — missing minions, ready Animates, stance reminders, and Life Force at a glance

Everything can be moved, resized, and turned on or off from **Setup** (opens the Display window).

### Your undead army
- Tracks **Life Force** and which minions you have out (ghouls, abominations, animates, etc.)
- **Alerts** when something important is missing or ready (e.g. Bone Wraith off cooldown)
- **Undead stance** reminders — Assault, Protect, or Pacify when it matters
- **Minion sheet** (Hub → **Minions**) — live guardian stats, melee/paper auto estimates, and a 3D model; cycle guardians with `</>`; temporarily enables friendly nameplates while open so live stats resolve faster

### Combat helpers (Hub → Combat)
- **ST vs AoE** — plain-English guide for bosses vs packs, shown inline in the Hub
- **LF Combo** — suggested Life Force army for single-target fights (uses saved fight data)
- **DPS** — minion and player damage from the last fight, with expandable spell rows and icons; auto-records in combat
- **Save DPS** — export the last fight to clipboard or a `.txt` file; also commits training-dummy pulls so LF Combo has data
- **Install Macros** — one-click character macros for key spells + **Grave March** (skips macros that already exist)

### Build guides (Hub → Guides)
- **Stat Priority** — gearing ladder with live % bars (hit, haste, intellect, crit, and soft caps)
- **Paper** — rough DPS estimate from your current stats and minion sheet data
- **Buffs** — preferred Animation buff picks (Grim Mandate, Razorice, Bone Ward, Chill of the Tomb)

### Talent tree overlay
When your Character Advancement tree is open, Libellus Leti can **highlight the next suggested talent** on your Animation leveling route. Use **Show Route / Hide Route** on the talent frame (off by default).

### Quality-of-life
- **Stack duplicate buffs** — one icon with a count instead of a long row of the same buff
- **Minion DPS tooltips** — extra info on spell tooltips when relevant
- **Minimap button** — quick access to the Hub (can be hidden in Setup)

---

## Installation

1. Download this repository (green **Code** button → **Download ZIP**), or clone it if you use Git.
2. Open your WoW addons folder:
   - On Ascension, use the **Interface\AddOns** folder for the client you play on.
3. Copy the **`LibellusLeti`** folder from the download into `AddOns`.
   - You should end up with: `AddOns\LibellusLeti\LibellusLeti.toc` (and the other `.lua` files inside).
   - Do not nest an extra folder (e.g. `AddOns\LibellusLeti\LibellusLeti\` — that will not load).
4. Restart WoW or type `/reload` in chat.
5. At the character select screen, click **AddOns** and make sure **Libellus Leti** is enabled.

> **Upgrading from Mancer?** Remove the old `Mancer` folder from `AddOns` so you do not load two copies. Your settings stay in `MancerDB` (SavedVariables) — no reset needed.

---

## Getting started

| Action | How |
|--------|-----|
| Open the main window | Type **`/leti`**, or click the **necromancer icon** on your minimap |
| Move bars and icons | Hub → **Setup** → **Show** (move mode), then drag; mousewheel to resize some icons |
| Change what appears | Hub → **Setup** — tick options for mana ticks, health bar, zombie counter, etc. |
| See minion status | Hub → **Combat** or **Minions** |
| Plan talents | Open Character Advancement and use the **talent overlay** |

Settings are saved per character automatically.

---

## Who is it for?

Libellus Leti is built for players running **Animation Necromancer** on **Ascension** (3.3.5a client). Some features only appear when you’re on that spec; other parts (bars, buff stacking) work more broadly.

Expect frequent updates while we’re still pre-1.0 — check back for new versions, and `/reload` after replacing the addon folder.

If you’re leveling, turn on the **talent overlay** when you open the Character Advancement tree.

If you’re gearing or pushing damage, use **Stat Priority**, **Paper**, and **Combat → DPS** to see how changes affect your army.

---

## Troubleshooting

**Addon doesn’t show up in the list**  
Check that `LibellusLeti.toc` is directly inside `AddOns\LibellusLeti\`, not nested in an extra folder.

**Bars are in the wrong place**  
Hub → Setup → **Show** to enter move mode, drag them back, then **Reset Bars** if needed.

**Minion tracking looks wrong**  
Try `/reload` after a big talent change or spec swap. Open Hub → Combat and use the status tools there; training dummies sometimes need **Save DPS** to commit a pull for LF Combo.

**Something broke after an update**  
Delete your saved settings (optional nuclear option): in WTF, look for `MancerDB.lua` under SavedVariables — only do this if you’re okay resetting all options.

---

## Bugs & requests

Found a bug or have a feature idea? Please [open a GitHub issue](issues) on this repository.

---

## Credits

**Author:** Mortuus (Discord: **LtGenZombie**)

Built with help from necromancers who tested builds, reported bugs, and shared feedback on Ascension’s Animation spec.

If Libellus Leti helped your character, share it with another undead friend.

---

## License

Libellus Leti is released under the [MIT License](LICENSE). You may use, modify, and share the addon freely; keep the copyright notice when redistributing.

**Third-party assets** — This is a fan-made addon, not affiliated with Blizzard Entertainment or Ascension. WoW client textures, icons, spell data, and models referenced at runtime belong to their respective owners. Bundled fonts and aura media in `LibellusLeti/Media/` and `LibellusLeti/PowerAurasMedia/` remain under their original licenses.
