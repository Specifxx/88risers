# 88 Risers — the RPG slice

A first playable piece of the game described in `docs/rpg/story-bible.md`, built in Godot 4.4.
Everything is made of simple shapes in code; there are no art assets yet.

## What is in it

- **Rhodes**, inside the Ring, with the eight founders, the Register and the wreck of Wukhan.
- **The east road**, with five Pinned on it. They come for you the moment you are outside the Ring and stop at its edge.
- **Tallow Ford**, a village of six people. Three can be recruited, each for a different reason; three cannot.
- **Fights** are turn-based. A Pinned that is only killed gets back up. To end one you throw chalk, bind it with a strap, find the true things to say before the strap gives, and say the rite.
- **Freedom**: anyone can be attacked and killed, founders included. Someone you kill outside the Ring comes back as one of the Pinned. Pell's strongbox can be robbed. Witnesses turn their village against you.
- There are no quest markers. Directions come from what people tell you, and the journal (J) keeps what you were told.

The slice ends when you tell Harry you have brought three recruits. You can keep playing afterwards.

## Controls

WASD move, mouse look (left/right arrows also turn), Shift run, E talk or use, J journal, H eat bread, Esc free the mouse.
In fights and conversations, click a choice or press its number.

## Not in it yet

- Villagers speak from written lines, with their own trust, willingness, ability and memory of what you did. They are not yet driven by a language model.
- No saving, no sound, one village.

## Run, test, export

```bash
godot --path game                         # play (Godot 4.4)
godot --path game -- --selftest [dir]     # automated play-through; saves screenshots to dir if given
godot --headless --path game --export-release Web ../public/game/index.html
```

The web build is committed in `public/game/`, so the site serves it at `/game/index.html`.
