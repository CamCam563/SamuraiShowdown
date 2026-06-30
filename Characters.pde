// =============================================================================
//                              CHARACTER ROSTER
// =============================================================================

//  SAMURAI: balanced sword fighter
class Samurai extends Player {
  // --- IAIJUTSU ULTIMATE ("Iai" draw-cut) ---
  final int   IAI_WINDUP   = 28;   // gather / sheathe
  final int   IAI_DASH_CAP = 22;   // safety cap on the flash-dash
  final int   IAI_PAUSE    = 14;   // delayed-slash hang time
  final int   IAI_RECOVER  = 18;   // resheathe / return control
  final int   IAI_DMG      = 55;
  final float IAI_DASH_VX  = 56;   // fast enough to cross max screen range

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
  }

  void startUltimate() {
    iaiDir = facingRight ? 1 : -1;
    iaiHit = false;
    isUnsheathed  = false;        // blade returns to the sheath for the draw
    isUnsheathing = false;
    vx = 0;
    freezeOpponent(IAI_WINDUP + IAI_DASH_CAP + IAI_PAUSE + IAI_RECOVER + 4);
    if (idleImg != null) img = idleImg;
  }

  void updateUltimate() {
    Player opp = (this == p1) ? p2 : p1;
    ultTimer++;

    if (ultPhase == 0) {                         // WINDUP — gather, sheathed
      vx = 0;
      if (idleImg != null) img = idleImg;
      if (ultTimer % 3 == 0) {                   // rising spirit sparks
        spawnHitSparks(x + BASE_W * 0.5, y - BASE_H * random(0.2, 0.9));
      }
      if (ultTimer >= IAI_WINDUP) {
        ultPhase = 1;
        ultTimer = 0;
        parryFlash = 235;                        // the draw flash
        impact(6, 8);
      }

    } else if (ultPhase == 1) {                  // DASH — flash through
      vx = iaiDir * IAI_DASH_VX;
      img = midFrameOr(midAttack.activeFrame);   // drawn-blade pose
      float cx = x + BASE_W * 0.5;
      float ox = opp.x + opp.BASE_W * 0.5;
      boolean crossed = (iaiDir > 0) ? cx >= ox : cx <= ox;
      if (!iaiHit && crossed) {
        iaiHit  = true;
        iaiHitX = ox;
        iaiHitY = opp.y - opp.BASE_H * 0.55;
        impact(16, 18);
        parryFlash = 200;
        spawnHitSparks(iaiHitX, iaiHitY);
        ultStrike(IAI_DMG, iaiHitX, iaiHitY, iaiDir * 16, (this == p1) ? 1 : 2);
      }
      if ((iaiHit && ultTimer >= 5) || ultTimer >= IAI_DASH_CAP) {
        ultPhase = 2;
        ultTimer = 0;
        vx = 0;
      }

    } else if (ultPhase == 2) {                  // PAUSE — delayed slash hangs
      vx = 0;
      img = midFrameOr(midAttack.activeFrame);
      if (ultTimer >= IAI_PAUSE) {
        ultPhase = 3;
        ultTimer = 0;
      }

    } else {                                     // RECOVER — resheathe, return
      vx = 0;
      if (idleImg != null) img = idleImg;
      facingRight = opp.x > x;
      if (ultTimer >= IAI_RECOVER) {
        isUlting = false;
        isUnsheathed = false;
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
    } else if (ultPhase == 1) {                   // speed streaks behind the dash
      for (int i = 1; i <= 5; i++) {
        float sx = x + BASE_W * 0.5 - iaiDir * i * 26;
        fill(255, 255, 255, 150 - i * 26);
        rect(sx, y - BASE_H * 0.75, iaiDir * 22, BASE_H * 0.5);
      }
    }
    if (iaiHit && (ultPhase == 1 || ultPhase == 2)) {   // the delayed slash line
      float a = (ultPhase == 2) ? map(ultTimer, 0, IAI_PAUSE, 255, 0) : 255;
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

    hp = maxHp = 200;

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
  final int   BAR_WINDUP   = 15;
  final int   BAR_RUSH_CAP = 18;
  final int   BAR_FLURRY   = 48;
  final int   BAR_HIT_GAP  = 5;    // frames between flurry hits
  final int   BAR_FINISH   = 14;
  final int   BAR_RECOVER  = 12;
  final int   BAR_HIT_DMG  = 7;
  final int   BAR_END_DMG  = 16;
  final float BAR_RUSH_VX  = 52;   // fast enough to close max screen range
  final float BAR_RANGE    = 0.95;  // stop rushing within this * BASE_W of the foe

  int     barDir   = 1;
  boolean barEnded = false;

  void startUltimate() {
    barDir   = facingRight ? 1 : -1;
    barEnded = false;
    vx = 0;
    freezeOpponent(BAR_WINDUP + BAR_RUSH_CAP + BAR_FLURRY + BAR_FINISH + BAR_RECOVER + 4);
    if (idleImg != null) img = idleImg;
  }

  void updateUltimate() {
    Player opp = (this == p1) ? p2 : p1;
    ultTimer++;
    int myId = (this == p1) ? 1 : 2;
    facingRight = (barDir > 0);

    if (ultPhase == 0) {                                   // WINDUP — fists glow
      vx = 0;
      if (idleImg != null) img = idleImg;
      if (ultTimer >= BAR_WINDUP) { ultPhase = 1; ultTimer = 0; }

    } else if (ultPhase == 1) {                            // RUSH — close the gap
      vx = barDir * BAR_RUSH_VX;
      img = flurryFrame();
      float gap = abs((opp.x + opp.BASE_W * 0.5) - (x + BASE_W * 0.5));
      if (gap <= BASE_W * BAR_RANGE || ultTimer >= BAR_RUSH_CAP) {
        ultPhase = 2; ultTimer = 0; vx = 0;
      }

    } else if (ultPhase == 2) {                            // FLURRY — rapid hits
      vx = 0;
      img = flurryFrame();
      if (ultTimer % BAR_HIT_GAP == 0) {
        float hx = opp.x + opp.BASE_W * 0.5;
        float hy = opp.y - opp.BASE_H * random(0.35, 0.75);
        impact(3, 5);
        spawnHitSparks(hx, hy);
        ultStrike(BAR_HIT_DMG, hx, hy, barDir * 2, myId);
      }
      if (ultTimer >= BAR_FLURRY) { ultPhase = 3; ultTimer = 0; }

    } else if (ultPhase == 3) {                            // FINISHER — heavy blow
      vx = 0;
      img = flurryFrame();
      if (!barEnded) {
        barEnded = true;
        float hx = opp.x + opp.BASE_W * 0.5;
        float hy = opp.y - opp.BASE_H * 0.5;
        impact(20, 22);
        parryFlash = 180;
        spawnHitSparks(hx, hy);
        ultStrike(BAR_END_DMG, hx, hy, barDir * 18, myId);
      }
      if (ultTimer >= BAR_FINISH) { ultPhase = 4; ultTimer = 0; }

    } else {                                               // RECOVER
      vx = 0;
      if (idleImg != null) img = idleImg;
      facingRight = opp.x > x;
      if (ultTimer >= BAR_RECOVER) isUlting = false;
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
    }
    popStyle();
  }
}
