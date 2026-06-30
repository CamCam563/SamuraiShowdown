// =============================================================================
//                                SOUND CLIP
// =============================================================================
// Plain-Java audio voice, wrapping one javax.sound.sampled Clip.
//
// This lives in a .java file ON PURPOSE: Processing's .pde preprocessor rejects
// the method call `clip.open(...)` because `open()` collides with a built-in
// Processing function. Java files in a sketch are handed straight to the
// compiler without that preprocessing step, so the call is legal here.
//
// Each clip owns its own mixer line, so different sounds overlap freely.
// Re-triggering the same clip restarts it from the top. Anything that goes
// wrong on load is swallowed, leaving ok=false so callers stay silent.

import javax.sound.sampled.*;
import java.io.File;

public class SoundClip {
  Clip clip;
  boolean ok = false;

  public SoundClip(String absPath) {
    try {
      File f = new File(absPath);
      AudioInputStream stream = AudioSystem.getAudioInputStream(f);
      clip = AudioSystem.getClip();
      clip.open(stream);
      stream.close();
      ok = true;
    } catch (Throwable e) {
      System.out.println("[sound] could not load " + absPath + " : " + e);
    }
  }

  // map a 0..1 linear volume onto the line's decibel gain control
  void setGain(float vol) {
    if (clip == null || !clip.isControlSupported(FloatControl.Type.MASTER_GAIN)) return;
    FloatControl g = (FloatControl) clip.getControl(FloatControl.Type.MASTER_GAIN);
    float v = Math.max(0f, Math.min(1f, vol));
    float dB = (v <= 0.0001f) ? g.getMinimum() : (float) (Math.log10(v) * 20.0);
    dB = Math.max(g.getMinimum(), Math.min(g.getMaximum(), dB));
    g.setValue(dB);
  }

  public void fire(float vol) {
    if (!ok) return;
    setGain(vol);
    clip.stop();
    clip.setFramePosition(0);
    clip.start();
  }

  public void startLoop(float vol) {
    if (!ok) return;
    setGain(vol);
    clip.setFramePosition(0);
    clip.loop(Clip.LOOP_CONTINUOUSLY);
  }

  public void halt() {
    if (ok) clip.stop();
  }
}
