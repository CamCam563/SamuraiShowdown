// =============================================================================
//                                  SOUND
// =============================================================================
// Audio for Samurai Showdown using Java's BUILT-IN sound (javax.sound.sampled).
// No Processing library to install — it ships with the JDK Processing runs on.
//
// The actual Clip handling lives in SoundClip.java (a real Java file), because
// the .pde preprocessor rejects `clip.open(...)` — `open()` clashes with a
// built-in Processing function. This tab just loads the clips and decides what
// plays when.
//
// Built-in Java only plays WAV, so the mp3 clips you added were converted to
// .wav next to them. The effects in Sounds/generated/ are synthesized fill-ins
// for events the clips don't cover (parry, block, impact, KO, menu blips,
// ult-ready chime, jump/dodge whoosh). Every play is guarded, so a missing
// file just stays silent instead of crashing the game.

// --- supplied clips (converted to wav) ---
SoundClip sndSlash1, sndSlash2;   // samurai sword swings (alternated)
SoundClip sndPunch;               // brawler fists
SoundClip sndFightVoice;          // announcer "FIGHT!"
SoundClip musMenu, musFight;      // looping background tracks

// --- generated effects ---
SoundClip sndParry, sndBlock, sndHit, sndKO;
SoundClip sndMenuMove, sndMenuSelect, sndUltReady, sndWhoosh;

// --- generated ultimate effects ---
SoundClip sndIaiCharge, sndIaiStrike;     // samurai Iaijutsu
SoundClip sndBarRoar, sndBarFinish;       // brawler Barrage
SoundClip sndBarGrab;                      // brawler Barrage grab lunge swoosh

boolean   soundReady   = false;
SoundClip currentMusic = null;

// build a clip from a sketch-relative path (absolute path handed to plain Java)
SoundClip clipFrom(String relPath) {
  return new SoundClip(sketchPath(relPath));
}

void loadSounds() {
  try {
    sndSlash1     = clipFrom("Sounds/fightsounds/swordslash1.wav");
    sndSlash2     = clipFrom("Sounds/fightsounds/swordslash2.wav");
    sndPunch      = clipFrom("Sounds/fightsounds/punch1.wav");
    sndFightVoice = clipFrom("Sounds/fightsounds/fightvoice.wav");
    musMenu       = clipFrom("Sounds/music/menumusic.wav");
    musFight      = clipFrom("Sounds/music/fightmusic.wav");

    sndParry      = clipFrom("Sounds/generated/parry.wav");
    sndBlock      = clipFrom("Sounds/generated/block.wav");
    sndHit        = clipFrom("Sounds/generated/hit.wav");
    sndKO         = clipFrom("Sounds/generated/ko.wav");
    sndMenuMove   = clipFrom("Sounds/generated/menu_move.wav");
    sndMenuSelect = clipFrom("Sounds/generated/menu_select.wav");
    sndUltReady   = clipFrom("Sounds/generated/ult_ready.wav");
    sndWhoosh     = clipFrom("Sounds/generated/whoosh.wav");

    sndIaiCharge  = clipFrom("Sounds/generated/ult_samurai_charge.wav");
    sndIaiStrike  = clipFrom("Sounds/generated/ult_samurai_strike.wav");
    sndBarRoar    = clipFrom("Sounds/generated/ult_brawler_charge.wav");
    sndBarFinish  = clipFrom("Sounds/generated/ult_brawler_finish.wav");
    sndBarGrab    = clipFrom("Sounds/generated/grab_swoosh.wav");

    soundReady = true;
  } catch (Throwable e) {
    println("[sound] disabled — audio init failed: " + e);
    soundReady = false;
  }
}

// one-shot effect at a given volume; harmless if audio is off
void sfx(SoundClip s, float vol) {
  if (!soundReady || s == null) return;
  s.fire(vol);
}
void sfx(SoundClip s) { sfx(s, 0.8); }

// samurai sword: alternate the two slashes so repeats don't feel canned
void playSlash() {
  sfx(random(1) < 0.5 ? sndSlash1 : sndSlash2, 0.85);
}
void playPunch() { sfx(sndPunch, 0.85); }

// swap the looping track; calling with the track already playing is a no-op
void playMusic(SoundClip track, float vol) {
  if (!soundReady || track == null || track == currentMusic) return;
  if (currentMusic != null) currentMusic.halt();
  track.startLoop(vol);          // sit music under the SFX
  currentMusic = track;
}
void playMusic(SoundClip track) { playMusic(track, 0.45); }
void stopMusic() {
  if (currentMusic != null) currentMusic.halt();
  currentMusic = null;
}
