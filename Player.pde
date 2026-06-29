// =============================================================================
//                                 PLAYER
// =============================================================================

// Loads frames prefix0.png, prefix1.png, ... and stops at the first one that
// isn't there. loadImage stays the single source of truth, so any frame that
// actually exists is always loaded (no guessing about where files live).
// System.err is muted only for the duration of the loop, so the expected
// "file missing" probe on the one-past-the-last frame doesn't spam the console.
PImage[] loadFrames(String prefix) {
  ArrayList<PImage> temp = new ArrayList<PImage>();
  java.io.PrintStream realErr = System.err;
  System.setErr(new java.io.PrintStream(new java.io.OutputStream() {
    public void write(int b) { }
  }));
  try {
    int i = 0;
    while (true) {
      PImage img = loadImage(prefix + i + ".png");
      if (img == null) break;
      temp.add(img);
      i++;
    }
  } finally {
    System.setErr(realErr);   // always restore, even if loading throws
  }
  return temp.toArray(new PImage[temp.size()]);
}

class AttackAnim {
  PImage[] frames;
  int activeFrame;

  AttackAnim(String prefix, int hitFrame) {
    activeFrame = hitFrame;
    frames = loadFrames(prefix);
  }
}

class Player extends Entity {
  float vy;

  boolean onGround;
  boolean facingRight;

  boolean isUnsheathing = false;
  boolean isUnsheathed  = false;
  boolean isResheathing = false;

  boolean isAttacking   = false;
  boolean hasHit        = false;

  boolean isBlocking    = false;

  boolean isJumping     = false;

  boolean isParryWindow = false;
  int parryTimer = 0;
  final int PARRY_WINDOW = 10;

  boolean isStunned = false;
  int stunTimer = 0;

  // --- ULTIMATE / CHARGE METER ---
  float ultMeter = 0;          // 0 .. ULT_MAX
  final float ULT_MAX = 100;
  boolean isUlting = false;
  int ultPhase = 0;            // sub-state index within the ultimate
  int ultTimer = 0;            // frames left in current phase

  int animFrame  = 0;
  int animTimer  = 0;
  int animSpeed  = 6;

  float SPEED    = 5;

  final int SCALE = 16;

  int BASE_H;
  int BASE_W;

  String name    = "FIGHTER";
  color  tintCol;
  boolean usesSword = true;

  float speedSheathed   = 6;
  float speedUnsheathed = 3.5;

  int   dmgMid = 16;
  int   dmgLow = 10;

  float ATK_REACH         = 0.85;
  float LUNGE_REACH_BONUS = 0.50;
  float ATK_HEIGHT        = 0.50;
  float ATK_ORIGIN        = 0.90;
  float ATK_Y_HIGH        = 0.70;
  float ATK_Y_MID         = 0.50;
  float ATK_Y_LOW         = 0.78;

  float BODY_W            = 0.62;
  float BODY_H            = 1.00;

  String attackType        = "MID";
  String pendingAttackType = "MID";
  boolean pendingBackDash  = false;
  float lungeSpeed         = 22;
  float backDashSpeed      = 9;

  float vx = 0;
  int   dashTimer    = 0;
  int   lastTapLeft  = -999;
  int   lastTapRight = -999;
  final int   DASH_WINDOW = 14;
  final float DASH_SPEED  = 16;
  final int   DASH_DUR    = 10;

  int     attackBuffer    = 0;
  int     jumpBuffer      = 0;
  boolean attackAfterDraw = false;

  PImage[] unsheathAnim  = new PImage[0];
  PImage[] equipRun      = new PImage[0];
  PImage[] walkAnim      = new PImage[0];
  AttackAnim highAttack;
  AttackAnim midAttack;
  AttackAnim lowAttack;
  PImage[] jumpAnim      = new PImage[0];

  PImage[] blockAnim     = new PImage[0];
  PImage[] blockWalkAnim = new PImage[0];

  PImage idleImg;
  PImage[] idleAnim = new PImage[0];

  final float GRAVITY    = 0.6;
  float       jumpForce  = -15;
  final float GROUND_Y   = 600;

  Player(float x, float y, boolean startRight) {
    super(x, y);
    tintCol = color(255);
    this.vy = 0;
    this.onGround = true;
    this.facingRight = startRight;
  }

  // --- DYNAMIC SPRITE LOADING METHODS ---
  PImage[] loadAnimArray(String prefix) {
    return loadFrames(prefix);
  }

  void loadSpriteSet(String charPrefix) {
    idleAnim      = loadAnimArray("images/idle/" + charPrefix + "idle");
    unsheathAnim  = loadAnimArray("images/unsheath/" + charPrefix + "unsheath");
    equipRun      = loadAnimArray("images/equip/" + charPrefix + "equip");
    walkAnim      = loadAnimArray("images/walk/" + charPrefix + "walk");
    jumpAnim      = loadAnimArray("images/jump/" + charPrefix + "jump");
    blockAnim     = loadAnimArray("images/block/" + charPrefix + "block");
    blockWalkAnim = loadAnimArray("images/blockwalk/" + charPrefix + "blockwalk");

    if (idleAnim.length > 0) {
      idleImg = idleAnim[0];
      img = idleImg;
      BASE_H = idleImg.height * SCALE;
      BASE_W = idleImg.width  * SCALE;
    }
  }

  int attackDamage(String t) {
    if (t.equals("LOW")) return dmgLow;
    return dmgMid;
  }

  void takeDamage(int amount, float hx, float hy) {
    hp -= amount;
    if (hp < 0) hp = 0;
    spawnHitSparks(hx, hy);
  }

  boolean isDead() { return hp <= 0; }

  AttackAnim getCurrentAttack() {
    if (attackType.equals("HIGH")) return highAttack;
    if (attackType.equals("LOW"))  return lowAttack;
    return midAttack;
  }

  String stanceName() {
    boolean down;
    if (this == p1) down = keys['S'];
    else            down = keyCodes[DOWN];
    if (down) return "LOW";
    return "MID";
  }

  String chosenAttackType() {
    boolean down, left, right;
    if (this == p1) { down = keys['S'];      left = keys['A'];      right = keys['D']; }
    else            { down = keyCodes[DOWN]; left = keyCodes[LEFT]; right = keyCodes[RIGHT]; }
    if (down) return "LOW";
    Player opp = (this == p1) ? p2 : p1;
    boolean toward = (opp.x > x) ? right : left;
    if (toward) return "MID";
    return "HIGH";
  }

  boolean isHoldingBack() {
    boolean left, right;
    if (this == p1) { left = keys['A'];      right = keys['D']; }
    else            { left = keyCodes[LEFT]; right = keyCodes[RIGHT]; }
    Player opp = (this == p1) ? p2 : p1;
    return (opp.x > x) ? left : right;
  }

  PImage attackFrameImg(int f) {
    AttackAnim atk = getCurrentAttack();
    if (f >= 0 && f < atk.frames.length) {
      return atk.frames[f];
    }
    return idleImg;
  }

  void applyKnockback(float amt) { vx += amt; }

  // --- ULTIMATE HELPERS ---
  boolean ultReady() { return ultMeter >= ULT_MAX && !isUlting; }

  void addMeter(float amt) { ultMeter = constrain(ultMeter + amt, 0, ULT_MAX); }

  void tryUltimate() {
    if (!ultReady() || !canAct() || !onGround || isAttacking || isStunned || isUlting) return;
    ultMeter   = 0;
    isUlting   = true;
    ultPhase   = 0;
    ultTimer   = 0;
    // drop any conflicting states
    isBlocking    = false;
    isParryWindow = false;
    isUnsheathing = false;
    isResheathing = false;
    isAttacking   = false;
    Player opp  = (this == p1) ? p2 : p1;
    facingRight = opp.x > x;
    startUltimate();
  }

  // lock the opponent in place for the cinematic
  void freezeOpponent(int frames) {
    Player opp = (this == p1) ? p2 : p1;
    opp.isStunned   = true;
    opp.stunTimer   = max(opp.stunTimer, frames);
    opp.isAttacking = false;
    opp.isBlocking  = false;
    opp.isParryWindow = false;
    opp.hasHit      = false;
  }

  // deal damage directly (bypasses the normal hitbox loop) and handle KO.
  // the matchState guard makes repeated flurry hits after a KO harmless (endRound once).
  void ultStrike(int dmg, float hx, float hy, float knock, int attackerId) {
    Player opp = (this == p1) ? p2 : p1;
    opp.takeDamage(dmg, hx, hy);
    opp.applyKnockback(knock);
    if (opp.isDead() && matchState.equals("FIGHTING")) endRound(attackerId);
  }

  // overridable per-character ultimate hooks (default: do nothing)
  void startUltimate()  {}
  void updateUltimate() {}

  // gravity + horizontal physics tail, shared by update() and the ult driver
  void applyPhysics() {
    vy += GRAVITY;
    y  += vy;
    if (y >= GROUND_Y) {
      y = GROUND_Y;
      vy = 0;
      onGround = true;
    }
    x  += vx;
    vx *= 0.80;
    if (abs(vx) < 0.3) vx = 0;
    if (dashTimer > 0) dashTimer--;
    x = constrain(x, 0, width - BASE_W);
  }

  void bufferJump() { jumpBuffer = 6; }

  void bufferAttack() {
    pendingAttackType = chosenAttackType();
    pendingBackDash   = pendingAttackType.equals("HIGH") && isHoldingBack();
    if (isUnsheathed) {
      attackBuffer = 8;
    } else if (!isResheathing) {
      startUnsheath();
      attackAfterDraw = true;
    }
  }

  void tryDash(int dir) {
    if (!isAttacking && !isBlocking && !isStunned && onGround) {
      int lastTap = (dir < 0) ? lastTapLeft : lastTapRight;
      if (frameCount - lastTap <= DASH_WINDOW) {
        vx = dir * DASH_SPEED;
        dashTimer = DASH_DUR;
      }
    }
    if (dir < 0) lastTapLeft = frameCount;
    else         lastTapRight = frameCount;
  }

  void startAttack() {
    if (!isAttacking && isUnsheathed && !isBlocking) {
      isAttacking = true;
      animFrame   = 0;
      animTimer   = 0;
      attackType  = pendingAttackType;
      Player opp  = (this == p1) ? p2 : p1;
      facingRight = opp.x > x;

      if (attackType.equals("MID")) {
        vx = (facingRight ? 1 : -1) * lungeSpeed;
      } else if (attackType.equals("HIGH") && pendingBackDash) {
        vx = (facingRight ? -1 : 1) * backDashSpeed;
      }
    }
  }

  void startUnsheath() {
    if (!isUnsheathed && !isUnsheathing) {
      isUnsheathing = true;
      isResheathing = false;
      animFrame     = 0;
      animTimer     = 0;
      if (unsheathAnim.length == 0) {   
        isUnsheathing = false;
        isUnsheathed  = true;
      }
    } else if (isUnsheathed && !isResheathing) {
      isResheathing   = true;
      isUnsheathing   = false;
      isUnsheathed    = false;
      isBlocking      = false;
      attackAfterDraw = false;
      if (unsheathAnim.length > 0) animFrame = unsheathAnim.length - 1;
      animTimer       = 0;
      if (unsheathAnim.length == 0) isResheathing = false;   
    }
  }

  void startBlock() {
    if (isUnsheathed && !isAttacking && onGround) {
      if (!isBlocking) {           
        animFrame     = 0;
        animTimer     = 0;
        isParryWindow = true;       
        parryTimer    = PARRY_WINDOW;
      }
      isBlocking = true;
    }
  }

  void stopBlock() {
    isBlocking    = false;
    isParryWindow = false;
  }

  void jump() {
    if (canJump()) {
      vy        = jumpForce;
      onGround  = false;
      isJumping = true;
      animFrame = 0;
      animTimer = 0;
    }
  }

  void update() {
    perFrame();
    if (isUlting) {
      updateUltimate();
      applyPhysics();
      return;
    }
    if (isStunned) {
      stunTimer--;
      if (stunTimer <= 0) isStunned = false;
      attackAfterDraw = false;
      vy += GRAVITY;
      y  += vy;
      if (y >= GROUND_Y) { y = GROUND_Y; vy = 0; onGround = true; }
      x  += vx;
      vx *= 0.80;
      if (abs(vx) < 0.3) vx = 0;
      x = constrain(x, 0, width - BASE_W);
      return;
    }

    if (attackAfterDraw && isUnsheathed && !isUnsheathing && canAct()) {
      startAttack();
      attackAfterDraw = false;
    }

    if (attackBuffer > 0 && canAct()) {
      attackBuffer--;
      if (!isAttacking && isUnsheathed && !isBlocking) {
        startAttack();
        attackBuffer = 0;
      }
    }

    if (jumpBuffer > 0 && canAct()) {
      jumpBuffer--;
      if (canJump()) {
        jump();
        jumpBuffer = 0;
      }
    }

    if (isParryWindow) {
      parryTimer--;
      if (parryTimer <= 0) isParryWindow = false;
    }

    if (isUnsheathed) SPEED = speedUnsheathed;
    else              SPEED = speedSheathed;

    boolean moving = false;

    if (canAct() && !isAttacking && !isUnsheathing && !isResheathing) {
      float currentSpeed = SPEED;
      if (isBlocking) currentSpeed = SPEED * 0.4;
      if (this == p1) {
        if (keys['A']) { x -= currentSpeed; facingRight = false; moving = true; }
        if (keys['D']) { x += currentSpeed; facingRight = true;  moving = true; }
      }
      if (this == p2) {
        if (keyCodes[LEFT])  { x -= currentSpeed; facingRight = false; moving = true; }
        if (keyCodes[RIGHT]) { x += currentSpeed; facingRight = true;  moving = true; }
      }
    }

    if (dashTimer > 0) moving = true;

    //ANIMATION LOGIC
    if (isAttacking) {
      animTimer++;
      if (animTimer >= animSpeed) {
        animTimer = 0;
        animFrame++;
        if (animFrame >= getCurrentAttack().frames.length) {
          animFrame   = 0;
          isAttacking = false;
          hasHit      = false;
        }
      }
      img = attackFrameImg(animFrame);

    } else if (isJumping && jumpAnim.length > 0) {
      int mid = jumpAnim.length / 2;
      int end = jumpAnim.length - 1;

      if (vy < 0) {
        animFrame = (int)map(vy, jumpForce, 0, 0, mid);
        animFrame = constrain(animFrame, 0, mid);
      } else {
        animFrame = (int)map(vy, 0, 15, mid + 1, end);
        animFrame = constrain(animFrame, mid + 1, end);
      }
      img = jumpAnim[animFrame];
      if (onGround) {
        isJumping = false;
        animFrame = 0;
      }

    } else if (isUnsheathing && unsheathAnim.length > 0) {
      animTimer++;
      if (animTimer >= animSpeed) {
        animTimer = 0;
        animFrame++;
        if (animFrame >= unsheathAnim.length) {
          animFrame     = unsheathAnim.length - 1;
          isUnsheathing = false;
          isUnsheathed  = true;
        }
      }
      img = unsheathAnim[animFrame];

    } else if (isResheathing && unsheathAnim.length > 0) {
      animTimer++;
      if (animTimer >= animSpeed) {
        animTimer = 0;
        animFrame--;
        if (animFrame < 0) {
          animFrame     = 0;
          isResheathing = false;
        }
      }
      if (!isResheathing) img = idleImg;
      else                img = unsheathAnim[animFrame];

    } else if (isBlocking && blockAnim.length > 0) {
      if (moving && blockWalkAnim.length > 0) {
        if (animFrame >= blockWalkAnim.length || animFrame < 0) animFrame = 0;
        animTimer++;
        if (animTimer >= animSpeed + 2) {
          animTimer = 0;
          animFrame = (animFrame + 1) % blockWalkAnim.length;
        }
        img = blockWalkAnim[animFrame];
      } else {
        animFrame = constrain(animFrame, 0, blockAnim.length - 1);
        animTimer++;
        if (animTimer >= animSpeed) {
          animTimer = 0;
          if (animFrame < blockAnim.length - 1) animFrame++;
        }
        img = blockAnim[animFrame];
      }

    } else if (moving && onGround && isUnsheathed && equipRun.length > 0) {
      if (animFrame >= equipRun.length) animFrame = 0;
      animTimer++;
      if (animTimer >= animSpeed) {
        animTimer = 0;
        animFrame = (animFrame + 1) % equipRun.length;
      }
      img = equipRun[animFrame];

    } else if (moving && onGround && !isUnsheathed && walkAnim.length > 0) {
      if (animFrame >= walkAnim.length) animFrame = 0;
      animTimer++;
      if (animTimer >= animSpeed) {
        animTimer = 0;
        animFrame = (animFrame + 1) % walkAnim.length;
      }
      img = walkAnim[animFrame];

    } else if (isUnsheathed && unsheathAnim.length > 0) {
      int lastFrame = unsheathAnim.length - 1;
      animFrame = lastFrame;
      img = unsheathAnim[lastFrame];

    } else if (idleAnim.length > 0) {
      if (animFrame >= idleAnim.length) animFrame = 0;
      animTimer++;
      if (animTimer >= 20) {
        animTimer = 0;
        animFrame = (animFrame + 1) % idleAnim.length;
      }
      img = idleAnim[animFrame];
    }

    applyPhysics();
  }

  HitBox getAttackHitBox() {
    AttackAnim atk = getCurrentAttack();
    if (!isAttacking || animFrame != atk.activeFrame) return null;
    String t     = attackType;
    float  reach = ATK_REACH;
    if (t.equals("MID")) reach += LUNGE_REACH_BONUS;
    float hbW = BASE_W * reach;
    float hbH = BASE_H * ATK_HEIGHT;
    float hbX = facingRight ? x + BASE_W * ATK_ORIGIN
                            : x + BASE_W * (1 - ATK_ORIGIN) - hbW;
    float yFrac = ATK_Y_MID;
    if      (t.equals("HIGH")) yFrac = ATK_Y_HIGH;
    else if (t.equals("LOW"))  yFrac = ATK_Y_LOW;
    float hbY = (y - BASE_H) + BASE_H * yFrac - hbH / 2;
    return new HitBox(hbX, hbY, hbW, hbH, t);
  }

  HitBox getBodyHitBox() {
    if (isUlting) return null;   // invulnerable during the cinematic
    float bw = BASE_W * BODY_W;
    float bh = BASE_H * BODY_H;
    float bx = x + (BASE_W - bw) / 2;
    float by = y - bh;
    return new HitBox(bx, by, bw, bh, "BODY");
  }

  boolean isBlockingType(String attackType) {
    if (!isBlocking) return false;
    return stanceName().equals(attackType);
  }

  boolean isFacing(Player other) {
    if (facingRight) return other.x > x;
    else             return other.x < x;
  }

  void perFrame()  {}
  void drawFlair() {}
  void onLandHit(String t, float hx, float hy) {}

  boolean canJump() {
    return onGround && !isAttacking && !isUnsheathed && !isBlocking;
  }

  void display() {
    if (img == null) return;
    drawFlair();
    int drawW = img.width  * SCALE;
    int drawH = img.height * SCALE;
    float drawY = y - drawH;
    tint(tintCol);
    if (facingRight) {
      image(img, x, drawY, drawW, drawH);
    } else {
      float drawX = (x + BASE_W) - drawW;
      pushMatrix();
      translate(drawX + drawW, drawY);
      scale(-1, 1);
      image(img, 0, 0, drawW, drawH);
      popMatrix();
    }
    noTint();
  }
}
