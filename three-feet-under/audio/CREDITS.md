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
## Real surface footsteps (2026-11-08)

Joseph SARDIN / BigSoundBank, CC0 1.0, original pages verified:
- Footsteps, Shoe on Concrete (0514): https://bigsoundbank.com/footsteps-shoe-on-concrete-s0514.html
- Footsteps on gravels #1 (0510): https://bigsoundbank.com/steps-on-gravels-s0510.html
- Original downloads: https://bigsoundbank.com/UPLOAD/mp3/0514.mp3?v=d and https://bigsoundbank.com/UPLOAD/mp3/0510.mp3?v=d
- Original MP3 and decoded WAV retained outside repo in D:/Codex/three feet under/footstep-source-review-20261107.
- real_* WAV: 48kHz mono PCM16, DC removal, target crop RMS -22 dBFS with .85 peak cap, 8ms edge fades. No echo baked in. Crops selected by waveform analysis; not claimed to have been listened to.
- Dedicated landing files select a stronger recorded contact; not a separately recorded jump. Source 0514 is modern sneakers on concrete, used as a hard-stone approximation, not authentic ancient footwear.
- Player now uses these recordings. Legacy Fantozzi OGGs remain for tablet/door dependencies. Their previous fixed echo is NOT used for new player steps.
- Surface metadata/raycast and voice pool are original code; no external footstep plugin or plugin license is claimed.

Original SHA256:
- 0514.mp3 `a1ef81474981815bf31ec022cb8a338a454c0b5d40f3364ec0a2c662eb5f2bed`
- 0510.mp3 `eb640b57f9fd3ddd71657da35a6b447b49f99b07f3de4da17d55b6b3e731f2cb`

Crop manifest (seconds in decoded original, shipped WAV SHA256):
- real_stone_1.wav 0514.mp3 [1.065, 1.41] `f84265d79f4e447bbe217d93c3a80c8dd9b8dff245002dcc6e03344ee304851b`
- real_stone_2.wav 0514.mp3 [2.465, 2.8099999999999996] `23e5952e5c51f86d20731489e24743a5eb69654695890310e34236fcaa48ffeb`
- real_stone_3.wav 0514.mp3 [3.1750000000000003, 3.5200000000000005] `c703fe862dae5609ebe8935dcd2e3e8cbf07c10d5823efe9d7c7112e1ea9a263`
- real_stone_4.wav 0514.mp3 [7.484999999999999, 7.83] `721745cd48fcb36b6d2c34b22d510348d742881dc6b25481a97fbf95eba4e7f9`
- real_stone_5.wav 0514.mp3 [8.205, 8.549999999999999] `1ce4ed9adc11467c12b275a7b04942cc8634babc46591cd9ad82785207341938`
- real_stone_6.wav 0514.mp3 [8.945, 9.29] `4a0d286ee4a761e5f0015f365e2396d90c230541c0f174ca4fcf5be5c2b5e525`
- real_stone_land.wav 0514.mp3 [0.365, 0.71] `60459a97199c9e9df0e3a4efddc4dd5f06256eb81b6d0ff76fc26d3de0b6c7ab`
- real_gravel_1.wav 0510.mp3 [1.165, 1.71] `d824baaab00114ecb27260bdf2c6dd0f744478f2a142cb08276be3ec9e147665`
- real_gravel_2.wav 0510.mp3 [2.125, 2.67] `7e915f3245aaf9a7108adbc83cf0941ba71110f80206d1c8075aa7d58bdccffc`
- real_gravel_3.wav 0510.mp3 [3.275, 3.82] `2fe25d2d740559e492c960d2309f7145bba3d164979870722bdb376555f050a9`
- real_gravel_4.wav 0510.mp3 [6.675, 7.220000000000001] `f1188a5c50494b9d3a916cecf9379e07062f11cad0038f457b140b4407fae371`
- real_gravel_5.wav 0510.mp3 [7.6049999999999995, 8.15] `6980fc638b349132792067cf969a55b302996a53344ea256a9e8459f0f82faa2`
- real_gravel_6.wav 0510.mp3 [9.355, 9.9] `9dbeb7542b7a0a0df301b6de4ec24302b876d940d123a3806ff80981ba6027d0`
- real_gravel_land.wav 0510.mp3 [0.365, 0.9099999999999999] `aae3744ea2b53994bf90a1fe0f039161ec088bc9e4a32faf07592b44272a613a`
