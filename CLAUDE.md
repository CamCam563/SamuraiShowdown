# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A local-multiplayer 2D fighting game ("Samurai Showdown") written in **Processing (Java mode)**. Two players share one keyboard. It is a pixel-art sketch, not a Maven/Gradle project — there is no build file.

## Running

This is a Processing sketch. Every `.pde` file in the root is a *tab* of one sketch and they are concatenated into a single class at compile time (so all top-level functions/fields share one namespace). `SoundClip.java` is a real Java file compiled alongside them.

- **In the Processing IDE:** open any `.pde` here and press Run (▶). The main tab with `setup()`/`draw()` is [SamuraiProto.pde](SamuraiProto.pde).
- **Headless / CLI:** `processing-java --sketch=. --run` (requires `processing-java` on PATH).

There is no test suite, linter, or build step — verification is by running the sketch and playing.

Gotcha: Processing expects the sketch's main tab to match the folder name. The folder is `SamuraiShowdown` but the main tab is `SamuraiProto.pde`; if the IDE refuses to open it, rename the tab to `SamuraiShowdown.pde` (or the folder to `SamuraiProto`).

## Architecture

**Game state is two string state machines**, both driven from `draw()` in [SamuraiProto.pde](SamuraiProto.pde):
- `screen` — `"MENU"` / `"CONTROLS"` / `"GAME"` (top-level routing).
- `matchState` — `"ROUND_INTRO"` / `"FIGHTING"` / `"ROUND_OVER"` / `"MATCH_OVER"` (in-match flow). `canAct()` (input is only live during `FIGHTING` with no hitstop) gates almost all player input.

**Class hierarchy** (`Entity` → `Player` → `Samurai`/`Brawler`):
- [Entity.pde](Entity.pde) — base `Entity` (position, hp, img) plus the `HitBox` class with its `overlaps()` test.
- [Player.pde](Player.pde) — the big one. All shared fighter logic: physics, the per-frame animation state machine in `update()`, input-driven movement, blocking/parry/dash, attack buffering, sprite loading, and the ultimate-meter plumbing. Overridable hooks: `perFrame()`, `drawFlair()`, `startUltimate()`, `updateUltimate()`, `onLandHit()`, `startAttack()`, `canJump()`.
- [Characters.pde](Characters.pde) — the two concrete fighters. `Samurai` (sword, Iaijutsu ult) and `Brawler` (fists, combo system, dodge i-frames, Barrage ult). Each tunes the inherited stat fields in its constructor and implements its ultimate as a phase counter (`ultPhase`/`ultTimer`) inside `updateUltimate()`.
- [Particle.pde](Particle.pde) — `HitSpark`, the retro hit-spark particles pooled in the global `sparks` list.

**Combat resolution** lives in `SamuraiProto.pde`, not on the players: `checkHits()` → `resolveAttack()` compares the attacker's `getAttackHitBox()` against the defender's `getBodyHitBox()` and branches into parry / matched-block-chip / clean-hit, applying damage, knockback, hitstop (`impact()`), screen shake, and ult-meter gain. `resolveCollision()` is the separate push-box that keeps bodies from overlapping. Ultimates bypass this loop and call `ultStrike()` directly.

**Two-player input** is keyboard-only via the global `keys[]`/`keyCodes[]` arrays maintained in `keyPressed`/`keyReleased`. Player methods tell P1 from P2 with `this == p1` to read the right keys (e.g. `stanceName()`, `chosenAttackType()`, `dodge()`). P1 = left-hand letters (WASD/Space/F/R/Q); P2 = arrows + numpad, with `.,/` alternates for keyboards without a numpad.

## Sprites & assets (loading by convention)

Sprites are **loaded by filename convention, not a manifest**. `loadFrames(prefix)` in [Player.pde](Player.pde) probes `prefix0.png`, `prefix1.png`, … and stops at the first missing file (it temporarily mutes `System.err` so the expected "missing file" probe doesn't spam the console). `loadSpriteSet(charPrefix)` then pulls every animation for a character from `images/<category>/<charPrefix><category><n>.png` (e.g. `images/idle/samuraiidle0.png`).

- **To add a frame:** drop the next-numbered PNG into the right folder — no code change needed.
- **To add an animation category:** add a `loadAnimArray(...)` line in `loadSpriteSet`.
- Pixel art is upscaled by `SCALE = 16` with `noSmooth()`; art is tiny source PNGs. Each attack's active (hit-registering) frame is the second arg to `new AttackAnim(prefix, hitFrame)`.
- `data/` holds the two `.ttf` fonts; `data/highscore.txt` persists win streaks (`loadHighScore`/`saveHighScore`).

## Sound

[Sound.pde](Sound.pde) loads/plays clips; [SoundClip.java](SoundClip.java) wraps one `javax.sound.sampled.Clip`. **`SoundClip` must stay a `.java` file** — the Processing `.pde` preprocessor rejects `clip.open(...)` because `open()` collides with a built-in Processing function; `.java` files skip that preprocessing. Only **WAV** plays (the supplied `.mp3`s were converted to `.wav` siblings); `Sounds/generated/` holds synthesized effects. Every play is guarded by `soundReady`/null checks, so a missing or failed clip just stays silent instead of crashing.

## Conventions

- All timing is **frame-based at 60fps** (`frameRate(60)`); counters like `hitFreeze`, `stunTimer`, `roundClock`, and the ult timers are decremented per frame. `frameRate(30)` is used briefly to slow down round-over moments.
- "Game feel" globals at the top of [SamuraiProto.pde](SamuraiProto.pde) (`CHIP_DMG`, `HITSTUN`, `METER_DEAL`/`METER_TAKE`, `ROUND_DELAY`, etc.) are the central tuning knobs; per-character damage (`dmgMid`/`dmgLow`) and reach/hitbox fractions live as fields on each `Player` subclass.
- Press `H` in-game to toggle hitbox debug rendering (`showHitboxes`).
