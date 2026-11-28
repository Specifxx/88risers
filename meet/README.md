# 88 Risers: Meet Night

A club night at Rhodes Amphitheatre you can walk around in. Godot 4.4, built entirely in script.

What you can do: talk to the founders, pull them at the table (styles, surges, grip), chalk your hands
or throw chalk at people, lift a strap from someone's bag when nobody is looking (they will go looking
for it), hand out snacks, heckle, punch, stop passers-by and talk them into a pull, leave notes at the
lanterns, take photos, and deal with the occasional UFO. Everyone has their own wants and habits, a
different mood each night, and a small neural network (`scripts/mind.gd`) that learns what to make of you.
Prizes, results and what people think of you are saved on the device between visits.

Run: `godot --path meet`. Automated play-through: `godot --path meet -- --selftest [screenshot_dir]`.
Web build: `godot --headless --path meet --export-release Web ../public/meet/index.html`.

The founders' names and likenesses follow their cards on 88risers.com; their lines here are placeholder
banter. Notes at the lanterns are stored locally for now, so each player only sees their own.
