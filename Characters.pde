// =============================================================================
//                              CHARACTER ROSTER
// =============================================================================

//  SAMURAI: balanced sword fighter
class Samurai extends Player {
  // --- IAIJUTSU ULTIMATE ("Iai" draw-cut) ---
  // Time stops, he holds the sheathed draw, dashes a thrust clean through the
  // foe, stands behind with his back turned, and only when the blade clicks
  // home does the cut register: the enemy topples and takes the damage.
  final int   IAI_WINDUP    = 42;  // hold the sheathed draw stance
  final int   IAI_DASH_CAP  = 26;  // safety cap on the flash-dash
  final int   IAI_STAND     = 44;  // stand behind the foe, blade drawn
  final int   IAI_RESHEATHE = 36;  // sheathe + the foe falling
  final int   IAI_CLICK     = 12;  // the cut lands this far into the resheathe
  final int   IAI_DMG       = 55;
  final float IAI_DASH_VX   = 56;  // fast enough to cross max screen range

  int     iaiDir   = 1;            // dash direction
  boolean iaiHit   = false;       // strike already landed this ult
  float   iaiHitX  = 0, iaiHitY = 0;

  Samurai(float x, float y, boolean startRight) {
    super(x, y, startRight);

    // Automatically loads ALL samurai idle, walk, jump, etc.
    loadSpriteSet("samurai");

    highAttack = new AttackAnim("images/high/samuraihigh", 3);
    midAttack  = new AttackAnim("images/mid/samuraimid", 4);
    lowAttack  = new AttackAnim("images/low/samurailow", 3);
    name = "SAMURAI";

    hp = maxHp = 200;
  }

  void startUltimate() {
    iaiDir = facingRight ? 1 : -1;
    iaiHit = false;
    isUnsheathed  = false;        // blade returns to the sheath for the draw
    isUnsheathing = false;
    vx = 0;
    freezeOpponent(IAI_WINDUP + IAI_DASH_CAP + IAI_STAND + IAI_RESHEATHE + 10);
    if (idleImg != null) img = idleImg;
    sfx(sndIaiCharge, 0.9);   // ominous gather, builds into the draw
  }

  void updateUltimate() {
    Player opp = (this == p1) ? p2 : p1;
    ultTimer++;
    int myId = (this == p1) ? 1 : 2;

    if (ultPhase == 0) {                         // WINDUP — sword held in the sheath
      vx = 0;
      isUnsheathed = false;
      if (idleImg != null) img = idleImg;
      if (ultTimer % 3 == 0) {                   // rising spirit sparks
        spawnHitSparks(x + BASE_W * 0.5, y - BASE_H * random(0.2, 0.9));
      }
      if (ultTimer >= IAI_WINDUP) {
        ultPhase = 1;
        ultTimer = 0;
        parryFlash = 235;                        // the draw flash
        impact(6, 8);
        sfx(sndSlash1, 0.75);                    // the thrust whoosh
      }

    } else if (ultPhase == 1) {                  // DASH — thrust straight through the foe
      vx = iaiDir * IAI_DASH_VX;
      img = midFrameOr(midAttack.activeFrame);   // drawn-blade thrust pose
      float cx = x + BASE_W * 0.5;
      float ox = opp.x + opp.BASE_W * 0.5;
      boolean past = (iaiDir > 0) ? cx >= ox + opp.BASE_W * 0.55
                                  : cx <= ox - opp.BASE_W * 0.55;
      if (past || ultTimer >= IAI_DASH_CAP) {
        ultPhase = 2;
        ultTimer = 0;
        vx = 0;
        // settle just behind the opponent, back turned, blade still drawn
        x = constrain(opp.x + iaiDir * opp.BASE_W * 0.6, 0, width - BASE_W);
        facingRight = (iaiDir > 0);
      }

    } else if (ultPhase == 2) {                  // STAND — hold behind the foe, blade out
      vx = 0;
      facingRight = (iaiDir > 0);
      img = midFrameOr(midAttack.activeFrame);
      if (ultTimer >= IAI_STAND) {
        ultPhase = 3;
        ultTimer = 0;
      }

    } else {                                     // RESHEATHE — click; the foe falls + takes the cut
      vx = 0;
      if (idleImg != null) img = idleImg;        // sheathing
      if (!iaiHit && ultTimer >= IAI_CLICK) {
        iaiHit  = true;
        iaiHitX = opp.x + opp.BASE_W * 0.5;
        iaiHitY = opp.y - opp.BASE_H * 0.55;
        parryFlash = 220;
        impact(22, 22);
        sfx(sndIaiStrike, 1.0);                  // the delayed cut lands
        spawnHitSparks(iaiHitX, iaiHitY);
        ultStrike(IAI_DMG, iaiHitX, iaiHitY, iaiDir * 6, myId);
        opp.knockOver(iaiDir, 100);              // the enemy topples over
      }
      if (ultTimer >= IAI_RESHEATHE) {
        isUlting = false;
        isUnsheathed = false;
        facingRight = opp.x > x;                 // turn back toward the fallen foe
      }
    }
  }

  PImage midFrameOr(int f) {
    if (midAttack != null && f >= 0 && f < midAttack.frames.length) return midAttack.frames[f];
    return idleImg;
  }

  void drawFlair() {
    if (!isUlting) return;
    pushStyle();
    noStroke();
    if (ultPhase == 0) {                          // gathering aura
      float pulse = 0.5 + 0.5 * sin(frameCount * 0.4);
      float r = BASE_W * (0.7 + 0.25 * pulse);
      fill(235, 205, 110, 60 + 60 * pulse);
      ellipse(x + BASE_W * 0.5, y - BASE_H * 0.5, r, r * 1.6);
    } else if (ultPhase == 1) {                   // speed streaks behind the thrust
      for (int i = 1; i <= 5; i++) {
        float sx = x + BASE_W * 0.5 - iaiDir * i * 26;
        fill(255, 255, 255, 150 - i * 26);
        rect(sx, y - BASE_H * 0.75, iaiDir * 22, BASE_H * 0.5);
      }
    }
    if (iaiHit && ultPhase == 3) {                // cut revealed as the blade clicks home
      float a = constrain(map(ultTimer, IAI_CLICK, IAI_RESHEATHE, 255, 0), 0, 255);
      stroke(255, 255, 255, a);
      strokeWeight(6);
      float len = BASE_H * 0.9;
      line(iaiHitX - len, iaiHitY - len * 0.5, iaiHitX + len, iaiHitY + len * 0.5);
      stroke(235, 205, 110, a);
      strokeWeight(2);
      line(iaiHitX - len, iaiHitY - len * 0.5, iaiHitX + len, iaiHitY + len * 0.5);
    }
    popStyle();
  }
}

//  BRAWLER: fist fighter 
class Brawler extends Player {
  int     comboCount = 0;
  int     comboTimer = 0;
  boolean wasAttacking = false;
  final int COMBO_WINDOW = 18;
  final int COMBO_MAX    = 4;

  int iframeTimer   = 0;
  int dodgeCooldown = 0;
  final int DODGE_SPEED   = 19;
  final int DODGE_IFRAMES = 12;
  final int DODGE_CD      = 26;

  Brawler(float x, float y, boolean startRight) {
    super(x, y, startRight);

    // Automatically loads ALL brawler idle, walk, jump, etc.
    loadSpriteSet("brawler");

    highAttack = new AttackAnim("images/high/brawlerhigh", 1);
    midAttack  = new AttackAnim("images/mid/brawlermid", 2);
    lowAttack  = new AttackAnim("images/low/brawlerlow", 2);
    name       = "BRAWLER";
    usesSword  = false;
    isUnsheathed = true;

    hp = maxHp = 160;

    speedSheathed   = 6.2;
    speedUnsheathed = 6.2;
    jumpForce       = -17;
    animSpeed       = 4;

    ATK_REACH         = 0.55;
    ATK_HEIGHT        = 0.45;
    ATK_ORIGIN        = 0.80;
    ATK_Y_HIGH        = 0.25;
    ATK_Y_MID         = 0.50;
    ATK_Y_LOW         = 0.78;
    LUNGE_REACH_BONUS = 0.30;
    lungeSpeed        = 15;

    dmgMid = 18;
    dmgLow = 12;
  }

  boolean canJump() {
    return onGround && !isAttacking && !isBlocking;
  }

  void startUnsheath() {
    dodge();
  }

  void dodge() {
    if (isStunned || isAttacking || !onGround || dodgeCooldown > 0) return;
    Player opp = (this == p1) ? p2 : p1;
    boolean left, right;
    if (this == p1) {
      left  = keys['A'];
      right = keys['D'];
    } else {
      left  = keyCodes[LEFT];
      right = keyCodes[RIGHT];
    }

    int dir;
    if (right && !left)      dir = 1;
    else if (left && !right) dir = -1;
    else                     dir = (opp.x > x) ? -1 : 1;

    vx            = dir * DODGE_SPEED;
    dashTimer     = 8;
    iframeTimer   = DODGE_IFRAMES;
    dodgeCooldown = DODGE_CD;
    isBlocking    = false;
    sfx(sndWhoosh, 0.55);
  }

  HitBox getBodyHitBox() {
    if (iframeTimer > 0) return null;
    return super.getBodyHitBox();
  }

  void startAttack() {
    if (isAttacking || !isUnsheathed || isBlocking) return;
    if (comboTimer > 0) comboCount = min(comboCount + 1, COMBO_MAX);
    else                comboCount = 1;

    isAttacking = true;
    animFrame   = 0;
    animTimer   = 0;
    attackType  = pendingAttackType;

    Player opp  = (this == p1) ? p2 : p1;
    facingRight = opp.x > x;

    float lunge = lungeSpeed;
    if (comboCount >= 2) lunge *= 0.35;

    if (attackType.equals("MID")) {
      vx = (facingRight ? 1 : -1) * lunge;
    } else if (attackType.equals("HIGH") && pendingBackDash) {
      vx = (facingRight ? -1 : 1) * backDashSpeed;
    }

    playPunch();
  }

  int attackDamage(String t) {
    int base = super.attackDamage(t);
    float scale = 1.0;
    if      (comboCount == 2) scale = 0.70;
    else if (comboCount == 3) scale = 0.55;
    else if (comboCount >= 4) scale = 0.45;
    return max(1, round(base * scale));
  }

  void perFrame() {
    if (iframeTimer   > 0) iframeTimer--;
    if (dodgeCooldown > 0) dodgeCooldown--;
    if (comboTimer > 0) {
      comboTimer--;
      if (comboTimer == 0) comboCount = 0;
    }
    if (wasAttacking && !isAttacking) comboTimer = COMBO_WINDOW;
    wasAttacking = isAttacking;
  }

  // --- BARRAGE ULTIMATE (Hundred Fists) ---
  // A SHORT-RANGE GRAB ult: the lunge only seizes a foe already within arm's
  // reach. Whiff the grab and the whole barrage is wasted — so it rewards
  // reading the opponent rather than firing from across the screen.
  final int   BAR_WINDUP   = 15;
  final int   BAR_GRAB     = 8;    // short forward lunge to seize the foe
  final int   BAR_WHIFF    = 16;   // recover after a missed grab (no damage)
  final int   BAR_FLURRY   = 48;
  final int   BAR_HIT_GAP  = 5;    // frames between flurry hits
  final int   BAR_WIND2    = 22;   // hold the wound-up pose before the haymaker lands
  final int   BAR_FINISH   = 14;   // follow-through after the punch connects
  final int   BAR_RECOVER  = 12;
  final int   BAR_HIT_DMG  = 7;
  final int   BAR_END_DMG  = 30;   // the haymaker hits HARD
  final float BAR_GRAB_VX  = 22;   // short hop forward — NOT a full-screen rush
  final float BAR_RANGE    = 0.85; // foe must be within this * BASE_W to be grabbed
  final float BAR_LAUNCH_VX = 38;  // sends the foe rocketing across the map
  final float BAR_LAUNCH_VY = 15;  // ...and up into an arc as they fly

  int     barDir     = 1;
  boolean barEnded   = false;
  boolean barGrabbed = false;

  void startUltimate() {
    barDir     = facingRight ? 1 : -1;
    barEnded   = false;
    barGrabbed = false;
    vx = 0;
    // worst case (grab connects): windup + grab + flurry + finish + recover.
    freezeOpponent(BAR_WINDUP + BAR_GRAB + BAR_FLURRY + BAR_WIND2 + BAR_FINISH + BAR_RECOVER + 4);
    if (idleImg != null) img = idleImg;
    sfx(sndBarRoar, 0.95);   // gritty rage rev before the lunge
  }

  void updateUltimate() {
    Player opp = (this == p1) ? p2 : p1;
    ultTimer++;
    int myId = (this == p1) ? 1 : 2;
    facingRight = (barDir > 0);

    if (ultPhase == 0) {                                   // WINDUP — fists glow
      vx = 0;
      if (idleImg != null) img = idleImg;
      if (ultTimer >= BAR_WINDUP) {
        ultPhase = 1; ultTimer = 0;
        sfx(sndBarGrab, 0.9);          // swoosh as the hands lunge out
      }

    } else if (ultPhase == 1) {                            // GRAB — short lunge to seize
      img = flurryFrame();
      float gap = abs((opp.x + opp.BASE_W * 0.5) - (x + BASE_W * 0.5));
      if (gap <= BASE_W * BAR_RANGE) {                     // hands close on the foe — barrage is on
        barGrabbed = true;
        vx = 0;
        // snap right up against them so the flurry lands cleanly
        x = constrain(opp.x - barDir * BASE_W * 0.5, 0, width - BASE_W);
        ultPhase = 2; ultTimer = 0;
      } else if (ultTimer >= BAR_GRAB) {                   // step expired without contact — whiff
        vx = 0;
        ultPhase = 5; ultTimer = 0;
        // free the foe early so a missed grab is punishable, not a safe poke
        opp.stunTimer = min(opp.stunTimer, BAR_WHIFF);
        opp.isStunned = opp.stunTimer > 0;
      } else {                                             // still lunging forward
        vx = barDir * BAR_GRAB_VX;
      }

    } else if (ultPhase == 2) {                            // FLURRY — rapid hits
      vx = 0;
      img = flurryFrame();
      if (ultTimer % BAR_HIT_GAP == 0) {
        float hx = opp.x + opp.BASE_W * 0.5;
        float hy = opp.y - opp.BASE_H * random(0.35, 0.75);
        impact(3, 5);
        sfx(sndPunch, 0.5);          // rapid jabs
        spawnHitSparks(hx, hy);
        ultStrike(BAR_HIT_DMG, hx, hy, barDir * 2, myId);
      }
      if (ultTimer >= BAR_FLURRY) { ultPhase = 3; ultTimer = 0; }

    } else if (ultPhase == 3) {                            // FINISHER — wind-up then haymaker
      vx = 0;
      img = flurryFrame();
      if (ultTimer == 0) {
        sfx(sndBarRoar, 1.0);          // re-roar: he loads the haymaker
      }
      if (ultTimer < BAR_WIND2) {
        // WIND-UP: hold the pose; build tension with a rising shake.
        shakeMag = max(shakeMag, map(ultTimer, 0, BAR_WIND2, 1, 6));
      } else if (!barEnded) {
        // IMPACT: the big punch lands.
        barEnded = true;
        float hx = opp.x + opp.BASE_W * 0.5;
        float hy = opp.y - opp.BASE_H * 0.5;
        impact(24, 30);                // heavier hit-pause + shake than the flurry
        parryFlash = 200;
        sfx(sndBarFinish, 1.0);        // big punch sound on impact
        spawnHitSparks(hx, hy);
        ultStrike(BAR_END_DMG, hx, hy, barDir * BAR_LAUNCH_VX, myId);
        opp.vy = -BAR_LAUNCH_VY;       // ...and launch them airborne (arc across the map)
        opp.onGround = false;
      }
      if (ultTimer >= BAR_WIND2 + BAR_FINISH) { ultPhase = 4; ultTimer = 0; }

    } else {                                               // RECOVER (4) / WHIFF RECOVER (5)
      vx = 0;
      if (idleImg != null) img = idleImg;
      facingRight = opp.x > x;
      int recover = (ultPhase == 5) ? BAR_WHIFF : BAR_RECOVER;
      if (ultTimer >= recover) isUlting = false;
    }
  }

  PImage flurryFrame() {
    if (midAttack != null && midAttack.frames.length > 0) {
      return midAttack.frames[(ultTimer / 2) % midAttack.frames.length];
    }
    return idleImg;
  }

  void drawFlair() {
    if (!isUlting) return;
    pushStyle();
    noStroke();
    if (ultPhase == 0) {                                   // rage aura
      float pulse = 0.5 + 0.5 * sin(frameCount * 0.5);
      fill(220, 70, 30, 60 + 70 * pulse);
      ellipse(x + BASE_W * 0.5, y - BASE_H * 0.5, BASE_W * (0.8 + 0.3 * pulse), BASE_H);
    } else if (ultPhase == 2) {                            // flurry impact bursts
      Player opp = (this == p1) ? p2 : p1;
      for (int i = 0; i < 3; i++) {
        float fx = opp.x + opp.BASE_W * 0.5 + random(-30, 30);
        float fy = opp.y - opp.BASE_H * random(0.3, 0.8);
        fill(255, 200, 60, random(120, 220));
        float s = random(10, 22);
        rect(fx - s / 2, fy - s / 2, s, s);
      }
    } else if (ultPhase == 3 && !barEnded) {               // finisher wind-up: charging fist
      float fistX = x + BASE_W * (barDir > 0 ? 0.85 : 0.15);
      float fistY = y - BASE_H * 0.5;
      float t = constrain(ultTimer / (float) BAR_WIND2, 0, 1);
      // core glow tightens and brightens as the punch loads
      fill(255, 130, 40, 80 + 140 * t);
      ellipse(fistX, fistY, BASE_W * (0.7 - 0.4 * t), BASE_W * (0.7 - 0.4 * t));
      // energy motes converging on the fist
      for (int i = 0; i < 3; i++) {
        float a = random(TWO_PI);
        float r = lerp(BASE_W * 0.7, BASE_W * 0.1, t) + random(-6, 6);
        fill(255, 220, 120, random(120, 220) * t);
        float s = random(6, 14);
        rect(fistX + cos(a) * r - s / 2, fistY + sin(a) * r - s / 2, s, s);
      }
    }
    popStyle();
  }
}
