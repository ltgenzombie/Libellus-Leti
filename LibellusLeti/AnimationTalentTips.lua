-- Animation talent tips shown on hover (player-facing advice).
-- Policy: recommend haste for player/minions; Mindless Fury before other army haste.
--
-- statScales: preferred gear stats for each Animation talent/ability (ordered best-first).
-- Shown on tooltips as stacked short tags: int / hst / crit.
--   int  — Intellect / Spell Power package
--   hst  — haste (cast/GCD/minion attack rate, or talents that grant haste)
--   crit — critical strike
-- Empty list = utility / no meaningful int/hst/crit gear preference.
Mancer.AnimationTalentTips = {
    -- TabType 61 CA nodes + common tip aliases. First tag = strongest preference.
    statScales = {
        -- Haste-first (grants haste or lives on attack/cast rate)
        ["Mindless Fury"] = { "hst" },
        ["Scourge Disciple"] = { "hst" },
        ["Depravity"] = { "hst", "crit" },
        ["Fetid Frenzy"] = { "hst" },
        ["Army of the Dead"] = { "hst", "crit" },
        ["Plague Horde"] = { "hst", "crit" },
        ["Unstoppable Frenzy"] = { "hst" },
        ["Graverobber"] = { "hst" },
        ["Forbidden Technique"] = { "hst" },
        ["Runic Animation"] = { "hst" },
        ["Unrelenting"] = { "hst" },
        ["Deadly Bond"] = { "hst" },
        ["Underking"] = { "hst" },
        ["Bone King"] = { "hst", "int" },
        ["Diabolical"] = { "int", "hst" },
        ["Grave Mastery"] = { "hst" },

        -- Intellect / SP first (damage coeffs, army power, player spells)
        ["Raise: Ghoul"] = { "int", "hst" },
        ["Raise: Abomination"] = { "int", "hst", "crit" },
        ["Raise: Banshee"] = { "int", "hst" },
        ["Sepulchral Might"] = { "int" },
        ["Ghoul Mastery"] = { "int", "hst" },
        ["Ghoulkeeper"] = { "int", "hst" },
        ["Ghoul Commander"] = { "int", "hst" },
        ["Ghoulish Mutation"] = { "int", "hst" },
        ["Greater Summoning"] = { "int" },
        ["Putrid Summoner"] = { "hst" },
        ["Life For Power"] = { "int" },
        ["Summoning Adept"] = { "int" },
        ["Summoning Expert"] = { "int" },
        ["Summoning Prodigy"] = { "int", "hst" },
        ["Summoning Mastery"] = { "int" },
        ["Master Animator"] = { "int" },
        ["Unrelenting Army"] = { "int", "hst" },
        ["Unrelenting Swarm"] = { "int", "hst" },
        ["Foul Invocation"] = { "int" },
        ["Zombimancy"] = { "int", "hst" },
        ["Animate: Bone Wraith"] = { "int", "hst" },
        ["Animate: Knight of Decay"] = { "int", "hst" },
        ["Animate: Skeletal Archer"] = { "int", "hst" },
        ["Animate: Tomb King"] = { "int", "hst" },
        ["Animate: Plaguefather"] = { "int", "hst" },
        ["Animate: Bone Construct"] = { "int" },
        ["Animate: Putrid Ghoul"] = { "int", "hst" },
        ["Skeletal Artillery"] = { "int", "hst" },
        ["Skeletal Mastery"] = { "int", "hst" },
        ["Artillery"] = { "int", "hst" },
        ["Fetid Mark"] = { "int" },
        ["Chomp"] = { "crit", "int" },
        ["Crypt Keeper"] = { "int", "hst" },
        ["March of the Dead"] = { "int" },
        ["Necrotic Power"] = { "int", "crit" },
        ["Plaguecraft"] = { "int", "hst" },
        ["Scourgelord"] = { "int" },
        ["Improved Unholy Command"] = { "int", "hst" },
        ["Lesser Summoning"] = { "int" },
        ["Mass Grave"] = { "int" },
        ["Overwhelming Force"] = { "int", "hst" },
        ["Tears of Lordaeron"] = { "int" },
        ["Raise: Gurgling Horror"] = { "int", "hst" },
        ["Raise: Revenant"] = { "int", "hst" },
        ["Raise: Unholy Colossus"] = { "int", "hst" },
        ["Raise: Flesh Golem"] = { "int", "hst" },

        -- Utility / no meaningful int/hst/crit gear tag
        ["Anti-Magic Shell"] = {},
        ["Flesh Symbiosis"] = {},
        ["Plague Protection"] = {},
        ["Putrifier"] = {},
        ["Summoner"] = {},
        ["Summoning Ritual"] = {},
        ["Scourge Summoning Ritual"] = {},
        ["Long March"] = {},
        ["Corpse Wagon"] = {},
        ["Lich's Prodigy"] = {},
        ["Bonescrap"] = {},
        ["Crypt Scarabs"] = {},
        ["Bone Plating"] = {},
        ["Wands"] = {},
        ["Animation Necromancer"] = {},
    },

    tips = {
        ["Mindless Fury"] = {
            verdict = "math_first_s",
            headline = "Best early Animation haste talent",
            lines = {
                "Take before Depravity — ASAP after Raise: Ghoul.",
            },
        },
        ["Sepulchral Might"] = {
            verdict = "math_first",
            headline = "Bigger army → more spell damage for you",
            lines = {
                "Raised-minion stamina feeds Crypt Swarm / Blight.",
                "Fill Life Force so the army (and this talent) keeps scaling.",
            },
        },
        ["Summoning Adept"] = {
            verdict = "free_passive",
            headline = "Free unlock at level 10 — always taken",
            lines = {
                "Passive-column Ability — separate unlock point, not Spec TE.",
                "Each filled Life Force slot is rough ST ~70 DPS early, ~150 mid-levels.",
            },
        },
        ["Summoning Expert"] = {
            verdict = "free_passive",
            headline = "Free unlock at level 30 — always taken",
            lines = {
                "Passive-column Ability — separate unlock point, not Spec TE.",
                "Fill new Life Force slots — empty Life Force is wasted damage.",
            },
        },
        ["Deadly Bond"] = {
            verdict = "free_passive",
            headline = "Free unlock at level 20 — always taken",
            lines = {
                "Passive-column Ability — separate unlock point, not Spec TE.",
                "Free Command procs multiply Command’s share of ghoul ST damage.",
            },
        },
        ["Diabolical"] = {
            verdict = "free_passive",
            headline = "Free unlock at level 40 — always taken",
            lines = {
                "Passive-column Ability — separate unlock point, not Spec TE.",
                "Spell stacks amp Crypt Swarm when you consume them.",
            },
        },
        ["Grave Mastery"] = {
            verdict = "free_passive",
            headline = "Free unlock at level 50 — always taken",
            lines = {
                "Passive-column Ability — separate unlock point, not Spec TE.",
                "Cheaper Animate / Raise / Command — more casts for free.",
            },
        },
        ["Summoning Prodigy"] = {
            verdict = "math_first",
            headline = "More Life Force = more minions",
            lines = {
                "Late summoning upgrade — keep Life Force full.",
            },
        },
        ["Summoning Mastery"] = {
            verdict = "math_first",
            headline = "Big army-size upgrade",
            lines = {
                "Also strengthens Sepulchral Might via more minion stamina.",
            },
        },
        ["Life For Power"] = {
            verdict = "math_first",
            headline = "Makes Life Force go further",
            lines = {
                "Worth it whenever you’re running a filled army.",
            },
        },
        ["Graverobber"] = {
            verdict = "math_first",
            headline = "Faster, cheaper Raise and Animate",
            lines = {
                "Keeps the army up and Animate CDs rolling — also a path gate.",
            },
        },
        ["Ghoulkeeper"] = {
            verdict = "math_first",
            headline = "Lets you field more ghouls",
            lines = {
                "More ghouls = more Command damage and Sepulchral value.",
            },
        },
        ["Ghoul Mastery"] = {
            verdict = "math_first",
            headline = "All your ghouls hit harder",
            lines = {
                "Always take on a ghoul-based Animation build.",
            },
        },
        ["Unrelenting Army"] = {
            verdict = "math_first",
            headline = "Free zombie DPS — no Life Force cost",
            lines = {
                "Harvest Plague can spawn Lesser Zombies on top of your raised army.",
            },
        },
        ["Putrid Summoner"] = {
            verdict = "math_first_a",
            headline = "Less friction when re-summoning",
            lines = {
                "Helps after wipeouts or when swapping the army.",
            },
        },
        ["Greater Summoning"] = {
            verdict = "math_first_a",
            headline = "Flat power to Raised minions",
            lines = {
                "Strong once your Life Force pool is decent.",
            },
        },
        ["Ghoul Commander"] = {
            verdict = "math_first",
            headline = "Stronger Command: Ghouls",
            lines = {
                "Command is a huge chunk of ghoul damage on long ST fights.",
            },
        },
        ["Ghoulish Mutation"] = {
            verdict = "math_first_a",
            headline = "Direct ghoul damage",
            lines = {
                "Solid once Mindless Fury and Life Force are online.",
            },
        },
        ["Foul Invocation"] = {
            verdict = "math_first_a",
            headline = "Pairs with plague / Unrelenting",
            lines = {
                "Best when Unrelenting Army / plague tools are in the build.",
            },
        },
        ["Army of the Dead"] = {
            dynamic = "army_of_the_dead",
            verdict = "math_first_s",
            headline = "+10% ghoul haste (and crit) with 1 Abomination",
            lines = {
                "Typical loadout: 1 Abom + fill leftover Life Force with ghouls.",
            },
        },
        ["Forbidden Technique"] = {
            verdict = "math_first",
            headline = "Command shortens Animate cooldowns",
            lines = {
                "Lets Bone Wraith / Archer fire far more often.",
            },
        },
        ["Mass Grave"] = {
            verdict = "situational",
            headline = "Crowd control — not army DPS",
            lines = {
                "Skip if you only care about lasting damage.",
            },
        },
        ["Raise: Abomination"] = {
            dynamic = "abom_loadout",
            verdict = "math_first",
            headline = "Costs 3 Life Force — enables Army of the Dead",
            lines = {
                "About three ghouls of ST damage; main upside is AotD’s ghoul haste.",
                "Use 1 Abom + fill the rest of Life Force with ghouls.",
            },
        },
        ["Unrelenting Swarm"] = {
            verdict = "math_first_b",
            headline = "Buffs Unrelenting / multi-target zombies",
            lines = {
                "Take after Unrelenting Army if you fight packs often.",
            },
        },
        ["Animate: Bone Wraith"] = {
            verdict = "math_first_a",
            headline = "Best scaling Animate (Bonestorm SP×0.4)",
            lines = {
                "Bonestorm is base + SP×0.4 per tick — direct Spell Power scaling.",
                "Tip math beats Tomb King’s ~10% army convert on the same 15s/60s window.",
                "No Life Force cost — pairs extremely well with Forbidden Technique.",
            },
        },
        ["Animate: Knight of Decay"] = {
            verdict = "math_first_a",
            headline = "Same job as Bone Wraith",
            lines = {
                "Pick whichever fits your path — treat them as equals for now.",
            },
        },
        ["Animate: Tomb King"] = {
            verdict = "math_first_b",
            headline = "Flat ~10% plague on minion hits",
            lines = {
                "Buff % does not scale with SP (ppl=0) — only the army under it does.",
                "≈10% of minion attacks for 15s; weaker SP scaling than Bone Wraith’s SP×0.4.",
                "Take later if you still want an army-wide plague window.",
            },
        },
        ["Animate: Skeletal Archer"] = {
            verdict = "math_first_s",
            headline = "First Animation talent — take this first",
            lines = {
                "Required early Animation spend (CA 7345 / spell 805040).",
                "Also strong DPS — bonus that the path pick hits hard.",
            },
        },
        ["Animate: Plaguefather"] = {
            verdict = "math_first_b",
            headline = "Hybrid Animate option",
            lines = {
                "Take after Wraith / Archer if you still want more burst.",
            },
        },
        ["Plague Horde"] = {
            verdict = "math_first_a",
            headline = "Army enrage — includes haste",
            lines = {
                "Take when points allow — army haste is always welcome.",
            },
        },
        ["Depravity"] = {
            verdict = "math_first_a",
            headline = "Army melee haste — after Mindless Fury",
            lines = {
                "Very good, but Mindless Fury comes first.",
            },
        },
        ["Fetid Frenzy"] = {
            verdict = "math_first_a",
            headline = "Proc haste across your Undead",
            lines = {
                "Stacks with Mindless Fury, Depravity, and Army of the Dead.",
            },
        },
        ["Scourge Disciple"] = {
            verdict = "math_first_a",
            headline = "Your haste goes up per Skeletal Archer",
            lines = {
                "Best with Animate: Skeletal Archer + Forbidden Technique.",
            },
        },
        ["Fetid Mark"] = {
            verdict = "math_first",
            headline = "Only for Skeletal Warrior builds",
            lines = {
                "Skip on a pure ghoul Animation setup.",
            },
        },
        ["Chomp"] = {
            verdict = "math_first_a",
            headline = "Abom crits harder and swings faster",
            lines = {
                "Take with Raise: Abomination / Army of the Dead setups.",
            },
        },
        ["Raise: Ghoul"] = {
            verdict = "math_first",
            headline = "Your main Life Force minion (1 LF)",
            lines = {
                "Command / heals scale with Intellect and Spell Power.",
                "Rough ST: ~70 DPS early, ~150 mid-levels per ghoul when geared.",
            },
        },
        ["Raise: Banshee"] = {
            verdict = "math_first",
            headline = "Mana-drain Raise (2 Life Force)",
            lines = {
                "Channels on one target — great vs caster bosses.",
                "Command drains mana and converts it to Frost damage.",
                "Pick Crypt Fiend instead when you need pack / AoE damage.",
            },
        },
        ["Animation Necromancer"] = {
            verdict = "math_first",
            headline = "Required to open the Animation tree",
            lines = {
                "Needs CoA Animation specialization (and Animate: Rotlings).",
            },
        },
        ["Scourge Summoning Ritual"] = {
            verdict = "situational",
            headline = "Utility ritual — not core army DPS",
            lines = {},
        },
        ["Lesser Summoning"] = {
            verdict = "math_first",
            headline = "Unlocks deeper Raise options",
            lines = {
                "Take when it gates talents you actually want.",
            },
        },
        ["Improved Unholy Command"] = {
            verdict = "math_first",
            headline = "Stronger Command damage",
            lines = {
                "Especially strong on long single-target fights.",
            },
        },
        ["Bone King"] = {
            verdict = "math_first_s",
            headline = "Second Animation talent — take after Archer",
            lines = {
                "Command → free instant Lichfrost/Blight (CA 7143 / spell 707175).",
                "Spend the proc on Lichfrost for bosses; Blight for packs.",
            },
        },
        ["Necrotic Power"] = {
            verdict = "math_first_b",
            headline = "Buffs your own spells",
            lines = {
                "Fine later — army and haste talents come first.",
            },
        },
        ["Wands"] = {
            verdict = "situational",
            headline = "Wand shooting — skip for army DPS",
            lines = {},
        },
        ["Raise: Gurgling Horror"] = {
            verdict = "math_first",
            headline = "Alternate Raise option",
            lines = {
                "Compare damage vs a ghoul for the same Life Force cost.",
            },
        },
        ["Raise: Revenant"] = {
            verdict = "math_first",
            headline = "Alternate Life Force minion",
            lines = {
                "Judge by damage for the Life Force it costs.",
            },
        },
        ["Raise: Unholy Colossus"] = {
            verdict = "math_first",
            headline = "Big Life Force minion",
            lines = {
                "Only worth it if it outdamages Abomination / several ghouls.",
            },
        },
        ["Raise: Flesh Golem"] = {
            verdict = "math_first",
            headline = "Big Life Force minion",
            lines = {
                "Often competing with Abomination + ghouls for the same LF.",
            },
        },
        ["Animate: Putrid Ghoul"] = {
            verdict = "math_first",
            headline = "Animate variant — not a first pick",
            lines = {
                "Doesn’t replace Bone Wraith / Archer as early Animate picks.",
            },
        },
        ["Skeletal Mastery"] = {
            verdict = "math_first_b",
            headline = "Only if you run skeletons",
            lines = {
                "Skip on a pure ghoul / Abom Animation build.",
            },
        },
        ["Artillery"] = {
            verdict = "math_first_b",
            headline = "Skeleton-path damage",
            lines = {
                "Skip for standard ghoul Animation.",
            },
        },
        ["Plaguecraft"] = {
            verdict = "math_first_b",
            headline = "Buffs your plague spells",
            lines = {
                "Army and haste talents are higher priority first.",
            },
        },
        ["Scourgelord"] = {
            verdict = "math_first",
            headline = "General damage buff",
            lines = {
                "Take when those damage types are a real part of your rotation.",
            },
        },
        ["Bonescrap"] = {
            verdict = "situational",
            headline = "Utility — not army DPS",
            lines = {},
        },
        ["Zombimancy"] = {
            verdict = "math_first",
            headline = "Buffs zombie / Unrelenting damage",
            lines = {
                "Skip if you never take the Unrelenting line.",
            },
        },
        ["Crypt Scarabs"] = {
            verdict = "situational",
            headline = "Utility / defense — not army DPS",
            lines = {},
        },
        ["Bone Plating"] = {
            verdict = "situational",
            headline = "Survivability — not army DPS",
            lines = {
                "Take for tough content if you’re dying; otherwise skip.",
            },
        },
        ["Will of the Necropolis"] = {
            verdict = "situational",
            headline = "Survivability — not army DPS",
            lines = {},
        },
        ["Acrid Aegis"] = {
            verdict = "situational",
            headline = "Defensive — skip when optimizing damage",
            lines = {},
        },
        ["Unholy Champion"] = {
            verdict = "math_first",
            headline = "Buff — only if you use that package",
            lines = {},
        },
        ["Fetid Pawns"] = {
            verdict = "situational",
            headline = "Not the same as Fetid Mark",
            lines = {
                "Skip for standard ghoul Animation damage.",
            },
        },
        ["Corpse Handling"] = {
            verdict = "situational",
            headline = "Utility — not army DPS",
            lines = {},
        },
        ["Flesh Laboratory"] = {
            verdict = "situational",
            headline = "Utility — skip for pure Animation damage",
            lines = {},
        },
        ["Locust"] = {
            verdict = "math_first",
            headline = "AoE / insect package",
            lines = {
                "Not a substitute for Life Force / haste talents.",
            },
        },
        ["Guts"] = {
            verdict = "situational",
            headline = "Utility — not lasting army DPS",
            lines = {},
        },
        ["Ritual Casting"] = {
            verdict = "math_first",
            headline = "Faster casting — behind Graverobber",
            lines = {
                "Graverobber is the better Raise/Animate spend first.",
            },
        },
        ["Night of the Living Dead"] = {
            verdict = "math_first",
            headline = "Burst cooldown",
            lines = {
                "Use on pull or burn phases.",
            },
        },
        ["Black Hook"] = {
            verdict = "math_first",
            headline = "Abomination toolkit",
            lines = {
                "Skip if you never run Abom / Colossus.",
            },
        },
        ["Sense Undead"] = {
            verdict = "recommended",
            headline = "+5% damage to Undead + minimap tracking",
            lines = {},
        },
        ["Overwhelming Force"] = {
            verdict = "math_first_a",
            headline = "Best Animation mana/RP sustain",
            lines = {
                "Procs from minion hits — prefer over Tears of Lordaeron.",
            },
        },
        ["Tears of Lordaeron"] = {
            verdict = "situational",
            headline = "Needs your crits — take Overwhelming Force instead",
            lines = {
                "Animation damage is mostly minions, so this procs much less often.",
            },
        },

        -- Preferred personal / army buffs (only one Ward and one Mandate at a time).
        ["Grim Mandate"] = {
            verdict = "math_first_s",
            headline = "Preferred Mandate — keep this up",
            lines = {
                "Use Grim Mandate over other Mandate buffs.",
                "One of Mancer’s four “keep up” buffs for Animation.",
            },
        },
        ["Razorice"] = {
            verdict = "math_first_s",
            headline = "Preferred frost buff — keep this up",
            lines = {
                "Strong Animation frost amp — prefer Razorice over weaker frost buffs.",
                "One of Mancer’s four “keep up” buffs for Animation.",
            },
        },
        ["Bone Ward"] = {
            verdict = "math_first_s",
            headline = "Preferred Ward — keep this up",
            lines = {
                "Best general Ward: armor + stamina on you and your Undead.",
                "Only one Ward can be active — pick Bone Ward over Fetid / Glacial Ward.",
                "One of Mancer’s four “keep up” buffs for Animation.",
            },
        },
        ["Chill of the Tomb"] = {
            verdict = "math_first_s",
            headline = "Preferred chill buff — keep this up",
            lines = {
                "Use Chill of the Tomb over weaker chill / frost alternatives.",
                "One of Mancer’s four “keep up” buffs for Animation.",
            },
        },
        ["Fetid Ward"] = {
            verdict = "situational",
            headline = "Use Bone Ward for better scaling",
            lines = {
                "Bone Ward scales better (armor + stamina on you and your Undead).",
                "Only one Ward can be active — prefer Bone Ward over Fetid Ward.",
            },
        },
        ["Glacial Ward"] = {
            verdict = "situational",
            headline = "Prefer Bone Ward / Chill of the Tomb",
            lines = {
                "Only one Ward can be active at a time.",
                "Default: Bone Ward. Prefer Chill of the Tomb for the chill slot.",
            },
        },
        ["Foul Mandate"] = {
            verdict = "situational",
            headline = "Prefer Grim Mandate instead",
            lines = {
                "Keep Grim Mandate as your default Mandate buff.",
            },
        },
    },

    nameAliases = {
        ["Fetid Mark"] = "Fetid Mark",
        ["Fetid Pawns"] = "Fetid Pawns",
        ["Rune of Razorice"] = "Razorice",
    },

    spellIds = {
        [500971] = "Raise: Ghoul",
        [801514] = "Raise: Ghoul",
        [707000] = "Raise: Ghoul",
        [504861] = "Raise: Banshee",
        [504862] = "Raise: Banshee",
        [504864] = "Raise: Banshee",
        [572638] = "Sepulchral Might",
        [706472] = "Sepulchral Might",
        [805674] = "Mindless Fury",
        [805786] = "Mindless Fury",
        [503757] = "Graverobber",
        [504556] = "Graverobber",
        [707015] = "Summoning Mastery",
        [805042] = "Summoning Mastery",
        [503740] = "Ghoul Mastery",
        [705747] = "Unrelenting Army",
        [705748] = "Unrelenting Army",
        [707880] = "Unrelenting Army",
        [704719] = "Unrelenting Swarm",
        [504415] = "Putrid Summoner",
        [560595] = "Putrid Summoner",
        [800048] = "Putrid Summoner",
        [704699] = "Greater Summoning",
        [520364] = "Foul Invocation",
        [804371] = "Foul Invocation",
        [524630] = "Depravity",
        [524631] = "Depravity",
        [638403] = "Depravity",
        [67761] = "Army of the Dead",
        [302910] = "Forbidden Technique",
        [302918] = "Forbidden Technique",
        [302922] = "Forbidden Technique",
        [561215] = "Forbidden Technique",
        [572408] = "Mass Grave",
        [803741] = "Mass Grave",
        [803744] = "Mass Grave",
        [42650] = "Raise: Abomination",
        [500989] = "Raise: Abomination",
        [500335] = "Raise: Abomination",
        [803139] = "Raise: Abomination",
        [805868] = "Crypt Scarabs",
        [503729] = "Bone Plating",
        [704695] = "Bone Plating",
        [579322] = "Fetid Mark",
        [706948] = "Fetid Mark",
        [706949] = "Fetid Mark",
        [707283] = "Chomp",
        [707284] = "Chomp",
        [707740] = "Chomp",
        [573072] = "Chomp",
        [302513] = "Fetid Frenzy",
        [302514] = "Fetid Frenzy",
        [531126] = "Scourge Disciple",
        [503730] = "Scourge Disciple",
        [805025] = "Scourge Disciple",
        [807653] = "Plague Horde",
        [807765] = "Plague Horde",
        [805032] = "Animate: Bone Wraith",
        [712317] = "Animate: Bone Wraith",
        [707175] = "Bone King",
        [805044] = "Animate: Tomb King",
        [355744] = "Animate: Tomb King",
        [500330] = "Animate: Skeletal Archer",
        [500331] = "Animate: Skeletal Archer",
        [500332] = "Animate: Skeletal Archer",
        [805040] = "Animate: Skeletal Archer",
        [531128] = "Overwhelming Force",
        [531129] = "Overwhelming Force",
        [531131] = "Overwhelming Force",
        [705751] = "Frost Runes",
        [705750] = "Frost Runes",
        [707007] = "March of the Dead",
        [705752] = "Tears of Lordaeron",
        [705753] = "Tears of Lordaeron",
        [706424] = "Tears of Lordaeron",
        [681529] = "Bone Ward",
        [681793] = "Bone Ward",
        [680388] = "Fetid Ward",
        [53343] = "Razorice",
    },
}

-- Hub → Guides: plain-English preferred buff list for Animation Necromancers.
function Mancer.AnimationTalentTips.PrintBuffGuide()
    Mancer.Print("Preferred buffs — keep these up")
    Mancer.Print("(Use these over the other Ward / Mandate / chill options.)")
    Mancer.Print("")
    Mancer.Print("  1. Grim Mandate")
    Mancer.Print("       Your default Mandate — prefer over Foul Mandate and the rest.")
    Mancer.Print("")
    Mancer.Print("  2. Razorice")
    Mancer.Print("       Preferred frost amp — keep it rolling.")
    Mancer.Print("")
    Mancer.Print("  3. Bone Ward")
    Mancer.Print("       Preferred Ward (armor + stam on you and your Undead).")
    Mancer.Print("       Only one Ward at a time — skip Fetid / Glacial for normal fights.")
    Mancer.Print("")
    Mancer.Print("  4. Chill of the Tomb")
    Mancer.Print("       Preferred chill buff — use this over weaker chill alternatives.")
    Mancer.Print("")
    Mancer.Print("Quick rule")
    Mancer.Print("  If you can hold only a few buffs: Grim Mandate + Razorice + Bone Ward + Chill of the Tomb.")
    Mancer.Print("  Hover a Ward / Mandate on your bars — Mancer tips mark Preferred vs Prefer X instead.")
end
