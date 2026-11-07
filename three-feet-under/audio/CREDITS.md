# Audio credits

All sounds used in this project are **CC0 (public domain)**, fetched from
OpenGameArt. CC0 means no attribution is legally required, but we credit the
authors here anyway.

## Footsteps (`sfx/footstep/*.ogg`)

- Pack: **Fantozzi's Footsteps (Grass/Sand & Stone)** by Fantozzi (submitted by
  qubodup), **CC0**. 12 single steps recorded from
  `https://www.freesound.org/people/Fantozzi/packs/10338/`.
- Source: https://opengameart.org/content/fantozzis-footsteps-grasssand-stone
- Used: the 6 stone steps (`StoneL1–3`, `StoneR1–3`), renamed to
  `footstep_stone_1..6.ogg`.
- Post-processing (2026-11-07, FFmpeg, for realism): highpass 55 Hz, dual-tap
  room echo (16/32 ms reflections) to simulate the stone corridor, 110 Hz bass
  lift for body impact, limiter + loudnorm (-21 LUFS). The raw samples on their
  own sounded too "game-y" (dry, no room); the processed files are what ships.

## Stone door (`sfx/stone_door.ogg`)

- **Stone Door** by bonebrah, **CC0** — a short, deep stone-door slide, good
  for a stone door or hidden room.
- Source: https://opengameart.org/content/stone-door
- Used: sliding doors (`door.gd`, `dual_seal_door.gd`), plus pitch-shifted
  (0.42×) as the finish thud when a door stops in place, and (0.55–0.85×)
  replicas are reused from the footstep samples for the tablet scrape.

## Procedural ambience (no samples)

`ambience.gd` generates the tomb ambience at runtime with an
`AudioStreamGenerator` (no audio files): a low brown-noise rumble with a
16-second swell, random water drips (decaying sine pings) and a fall-whoosh
driven by the player's downward speed. It is original code by this project and
needs no attribution.

## License

CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/