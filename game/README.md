# 88 Risers — the RPG slice

A first playable piece of the game described in `docs/rpg/story-bible.md`, built in Godot 4.4.

People, trees and grass are free public-domain models from Quaternius; ground, stone, wood and metal
textures are from ambientCG (see `assets/CREDITS.md`). The architecture is generated in code
(`scripts/asia.gd`), and the roof tile, lacquer, lattice and cloth textures, the banner and the crest
emblem are generated from scratch or from the club crest in `public/crest.jpg`.

## What is in it

- **Rhodes**, inside the Ring: a gate with stone guardian lions, the Register pavilion, tiled halls, club banners, lanterns, the wreck of Wukhan, and a tavern you can walk into.
- **The east road**, with five Pinned on it. They come for you the moment you are outside the Ring and stop at its edge.
- **Tallow Ford**, a village of six people. Three can be recruited, each for a different reason; three cannot.
- **Fighting** is in real time. Left click (or F) swings whatever you are holding; whether it lands depends on your skill with that kind of weapon and how much wind you have left. Right click (or C) blocks. Armour and a shield take their share of what gets through.
- **The rite.** A Pinned that is beaten down lies there for a short while. Begin the rite over it (E): throw chalk, bind it with a strap, find the true things to say before the strap gives, and say the words. Leave it and it sinks, and is back later.
- **Things.** Weapons, armour, a shield, food and drink, chalk and straps are all items with weight and worth. Tab opens the pack: click to wield, wear, take off, eat or drink. Traders buy and sell. Crates and chests can be searched; if they belong to someone living, that is theft.
- **Skills** rise only by use: blade, blunt weapon, spear, hand-to-hand, block, athletics, acrobatics, speechcraft.
- **Minds.** Every person has a small neural network of their own (`scripts/mind.gd`) that learns, from what happens to them and what they hear, how dealing with you tends to go. Temperament differs per person, so the same act lands differently; opinions depend on the situation; and news travels only when one person tells another. The words they speak are written lines chosen by their state of mind.
- **Lives.** People keep a post, drift to the fire, the well or the tavern, stop to talk to each other, greet or avoid you, and go home at night. A day lasts about twelve minutes.
- **The founders** follow their cards on 88risers.com (hair, beard, build, clothing), and their card is shown when you talk to them.
- **The table.** Sit down in the tavern and pull against a founder: toproll, hook or press, first to three pins, five coin a side.
- **Freedom**: anyone can be struck and killed, founders included. The brave fight back, the rest run, and guards who see it come for you. The dead leave their belongings, and outside the Ring they come back as one of the Pinned. Those who see a crime remember it and tell others; coin can make amends, at a price.
- There are no quest markers. Directions come from what people tell you, and the journal (J) keeps what you were told.

The slice ends when you tell Harry you have brought three recruits. You can keep playing afterwards.

## Controls

WASD move, mouse look (left/right arrows also turn), Shift run, Space jump, left click or F attack, right click or C block,
E talk or use, Tab inventory, V first or third person, J journal, H eat bread, Esc free the mouse.
In conversations and the rite, click a choice or press its number.

## Not in it yet

- No saving and no sound, so minds start fresh each time you load.
- One village, one interior.
- The buildings, lions, lanterns and gates are built from textured shapes in code, not sculpted models. Clothing is from a European-medieval pack, recoloured.
- Founders match their cards in hair, beard, build and colour only; faces are generic and everyone shares one skin tone.

## Run, test, export

```bash
godot --path game                         # play (Godot 4.4)
godot --path game -- --selftest [dir]     # automated play-through; saves screenshots to dir if given
godot --headless --path game --export-release Web ../public/game/index.html
```

The web build is committed in `public/game/`, so the site serves it at `/game/index.html`.
