// =============================================================================
//                               GLOBAL VARIABLES
// =============================================================================
boolean[] keys     = new boolean[256];
boolean[] keyCodes = new boolean[600];
Player p1;
Player p2;
ArrayList<HitSpark> sparks = new ArrayList<HitSpark>();

int p1Wins      = 0;
int p2Wins      = 0;
int roundsToWin = 2;
boolean showHitboxes = false;

//SCORE SYSTEM
int p1TotalWins = 0;
int p2TotalWins = 0;

int p1WinStreak = 0;
int p2WinStreak = 0;

int p1HighestStreak = 0;
int p2HighestStreak = 0;

String screen = "MENU";

//menu
String[] menuItems = { "VS MODE  (2 Players)", "CONTROLS", "QUIT" };
int menuIndex = 0;

//character select  (roster is intentionally easy to extend)
final int ROSTER_SIZE = 7;
String[]  rosterNames     = { "SAMURAI", "BRAWLER", "?", "?", "?", "?", "?" };
boolean[] rosterAvailable = { true, true, false, false, false, false, false };
PImage    samuraiIcon, brawlerIcon;                // editable icons (named per request)
PImage[]  rosterIcons = new PImage[ROSTER_SIZE];   // null slot => draw a "?" box

int     p1Cursor = 0, p2Cursor = 1;          // hovered slot per player
boolean p1Locked = false, p2Locked = false;  // confirmed?
int     p1CharIndex = 0, p2CharIndex = 1;    // committed picks used by spawnPlayers()
int     p1Flash = 0, p2Flash = 0;            // red-flash countdown when confirming a "?"

//end-of-match menu
String[] endMenuItems = { "PLAY AGAIN", "SWAP CHARACTERS", "MAIN MENU" };
int      endMenuIndex = 0;

// "ROUND_INTRO", "FIGHTING", "ROUND_OVER", "MATCH_OVER"
String matchState = "ROUND_INTRO";
String roundMsg   = "";
int    roundTimer = 0;
final int ROUND_DELAY     = 75;   // frames the "K.O.!" / "TIME" banner shows between non-deciding rounds
final int MATCH_END_DELAY = 60;   // short buffer showing "PLAYER X WINS!" before the menu appears

int currentRound = 1;
int introTimer   = 0;
final int INTRO_TIME = 110;
boolean fightVoicePlayed = false;   // gate the announcer to once per round

//GAME FEEL
int   hitFreeze  = 0;   // frames the action is paused after a hit (hitstop)
float shakeMag   = 0;   // current screen-shake strength
float parryFlash = 0;   // white flash on a parry

//COMBAT
//   Per-character damage lives on each class (dmgMid / dmgLow) in Characters.
int   CHIP_DMG  = 4;    // damage a correct block still takes (can NEVER KO)
int   HITSTUN   = 14;   // frames the victim is frozen after a clean hit

//ULTIMATE METER GAIN (per point of damage)
float METER_DEAL = 0.7;    // charge gained by the attacker (primary source) — halved: ult takes 2x as long to charge
float METER_TAKE = 0.35;   // charge gained by the victim   (secondary source)

//ROUND TIMER
int   roundTimeFrames = 99 * 60;   // 99-count clock at 60fps
int   roundClock      = roundTimeFrames;

//P2 KEYS (numpad) 
final int P2_ATTACK      = 96;   // Numpad 0
final int P2_BLOCK       = 110;  // Numpad .
final int P2_SHEATHE     = 101;  // Numpad 5

//P2 ALTERNATE KEYS (no numpad needed)
final int P2_ATTACK_ALT  = 46;   // .  period
final int P2_BLOCK_ALT   = 44;   // ,  comma
final int P2_SHEATHE_ALT = 47;   // /  slash

// =============================================================================
//                                  MAIN SETUP
// =============================================================================
PFont kiwiSoda;
PFont minecraft;

void setup() {
  noSmooth();
  size(1024, 768);
  kiwiSoda = createFont("KiwiSoda.ttf", 64);
  minecraft = createFont("Minecraft.ttf", 32);

  loadHighScore();
  loadSounds();

  // character-select icons (reuse the idle sprites; swap these paths for custom art)
  samuraiIcon = loadImage("images/idle/samuraiidle0.png");
  brawlerIcon = loadImage("images/idle/brawleridle0.png");
  rosterIcons[0] = samuraiIcon;
  rosterIcons[1] = brawlerIcon;
  // rosterIcons[2..6] stay null -> "?" boxes. To add a fighter later: drop an icon
  // here, set rosterNames/rosterAvailable, and extend makeFighter().

  frameRate(60);
  screen = "MENU";
  playMusic(musMenu);
}
void startMatch() {
  p1Wins = 0;
  p2Wins = 0;
  currentRound = 1;
  startRound();
}

void startRound() {
  // ult meter carries over between rounds of a match (but a fresh match — round 1 — starts empty)
  float p1Meter = (currentRound > 1 && p1 != null) ? p1.ultMeter : 0;
  float p2Meter = (currentRound > 1 && p2 != null) ? p2.ultMeter : 0;
  spawnPlayers();
  p1.ultMeter = p1Meter;
  p2.ultMeter = p2Meter;
  matchState = "ROUND_INTRO";
  introTimer = INTRO_TIME;
  roundMsg   = "";
  hitFreeze  = 0;
  shakeMag   = 0;
  parryFlash = 0;
  roundClock = roundTimeFrames;
  fightVoicePlayed = false;
  playMusic(musFight, 0.22);   // fight track at half volume, under the action
  frameRate(60);
}

// =============================================================================
//                                  GAME LOOP
// =============================================================================
void draw() {
  //  route by screen 
  if (screen.equals("MENU")) {
    drawMenu();
    return;
  }
  if (screen.equals("CONTROLS")) {
    drawControls();
    return;
  }
  if (screen.equals("CHAR_SELECT")) {
    drawCharSelect();
    return;
  }

  // ============================ GAME ============================
  //  screen shake 
  pushMatrix();
  if (shakeMag > 0.5) {
    translate(random(-shakeMag, shakeMag), random(-shakeMag, shakeMag));
    shakeMag *= 0.85;
  } else {
    shakeMag = 0;
  }

  background(125, 139, 140);

  fill(60, 40, 20);
  noStroke();
  rect(0, 570, width, 320);

  p1.display();
  p2.display();

  boolean frozen = hitFreeze > 0;
  if (frozen) hitFreeze--;

  if (!frozen) {
    if (matchState.equals("ROUND_INTRO")) {
      p1.update();
      p2.update();
      introTimer--;
      if (!fightVoicePlayed && introTimer <= INTRO_TIME * 0.45) {   // "FIGHT!" appears
        sfx(sndFightVoice, 0.9);
        fightVoicePlayed = true;
      }
      if (introTimer <= 0) matchState = "FIGHTING";
    } else if (matchState.equals("FIGHTING")) {
      p1.update();
      p2.update();
      checkHits();

      //round clock
      if (matchState.equals("FIGHTING")) {
        roundClock--;
        if (roundClock <= 0) {
          impact(20, 16);
          if      (p1.hp > p2.hp) p1Wins++;
          else if (p2.hp > p1.hp) p2Wins++;
          matchState = "ROUND_OVER";
          frameRate(30);

          if (p1Wins >= roundsToWin) {
            roundMsg = "PLAYER 1 WINS!";  roundTimer = MATCH_END_DELAY;
          } else if (p2Wins >= roundsToWin) {
            roundMsg = "PLAYER 2 WINS!";  roundTimer = MATCH_END_DELAY;
          } else {
            roundTimer = ROUND_DELAY;
            if      (p1.hp > p2.hp) roundMsg = "TIME \u2014 P1 WINS";
            else if (p2.hp > p1.hp) roundMsg = "TIME \u2014 P2 WINS";
            else                    roundMsg = "DRAW";
          }
        }
      }
    } else {  // ROUND_OVER or MATCH_OVER
      p1.update();
      p2.update();
      roundTimer--;
      if (roundTimer <= 0 && matchState.equals("ROUND_OVER")) {
        if      (p1Wins >= roundsToWin) goToMatchOver(1);
        else if (p2Wins >= roundsToWin) goToMatchOver(2);
        else {
          currentRound++;
          startRound();
        }
      }
    }
  }

  // player collison
  resolveCollision(p1, p2);

  // hit-spark particle system
  for (int i = sparks.size() - 1; i >= 0; i--) {
    HitSpark s = sparks.get(i);
    s.update();
    s.display();
    if (s.isDead()) sparks.remove(i);
  }

  //hitbox debug
  if (showHitboxes) {
    drawPlayerHitboxes(p1);
    drawPlayerHitboxes(p2);
  }

  popMatrix();   // end screen-shake

  drawHUD();

  //parry
  if (parryFlash > 1) {
    noStroke();
    fill(255, 255, 255, parryFlash);
    rect(0, 0, width, height);
    parryFlash -= 34;     // fade out fast
  } else {
    parryFlash = 0;
  }
}

void drawPlayerHitboxes(Player pl) {
  noFill();
  HitBox body = pl.getBodyHitBox();
  if (body != null) {
    stroke(255, 0, 0);
    rect(body.x, body.y, body.w, body.h);
  }
  HitBox atk = pl.getAttackHitBox();
  if (atk != null) {
    stroke(0, 255, 0);
    rect(atk.x, atk.y, atk.w, atk.h);
  }
}

// =============================================================================
//                                  MENU SCREENS
// =============================================================================
void drawMenu() {
  background(20, 22, 28);
  noStroke();
  fill(60, 40, 20);
  rect(0, 570, width, 220);

  textAlign(CENTER, CENTER);

  fill(235, 205, 110);
  textFont(minecraft);
  textSize(86);
  text("SAMURAI SHOWDOWN", width / 2, 190);
  fill(190);
  textSize(20);
  text("battle to the death", width / 2, 252);

  // options
  for (int i = 0; i < menuItems.length; i++) {
    boolean sel = (i == menuIndex);
    float yy = 380 + i * 56;
    if (sel) {
      fill(235, 205, 110);
      textSize(30);
      text("\u2192  " + menuItems[i] + "  \u2190", width / 2, yy);
    } else {
      fill(150);
      textSize(26);
      text(menuItems[i], width / 2, yy);
    }
  }

  fill(120);
  textSize(14);
  text("W / S  or  UP / DOWN  to move        ENTER or SPACE to select", width / 2, height - 40);

  textAlign(LEFT, BASELINE);
}

void drawControls() {
  background(20, 22, 28);

  textFont(minecraft);
  textAlign(CENTER, CENTER);
  fill(235, 205, 110);
  textSize(50);
  text("CONTROLS", width / 2, 90);

  textAlign(LEFT, CENTER);
  textSize(15);
  float lx = 150;
  float rx = width / 2 + 70;
  float ty = 200;
  float dy = 42;

  // Player 1
  fill(235, 205, 110);
  text("PLAYER 1", lx, ty - 52);
  fill(220);
  text("A / D       move", lx, ty);
  text("W           jump", lx, ty + dy);
  text("SPACE       strike  (toward=lunge, back=hop, S=low)", lx, ty + dy * 2);
  text("F           block   (hold S = low)", lx, ty + dy * 3);
  text("R           draw / sheathe", lx, ty + dy * 4);
  fill(235, 205, 110);
  text("Q           IAIJUTSU ultimate  (when meter full)", lx, ty + dy * 5);

  // Player 2
  fill(235, 205, 110);
  text("PLAYER 2", rx, ty - 52);
  fill(220);
  text("LEFT ARROW / RIGHT ARROW         move", rx, ty);
  text("UP ARROW           jump", rx, ty + dy);
  text("Num0 / .    strike  (toward=lunge, back=hop, \u2193=low)", rx, ty + dy * 2);
  text("Num. / ,    block   (hold \u2193 = low)", rx, ty + dy * 3);
  text("Num5 / /    dodge   (tap a direction to roll that way)", rx, ty + dy * 4);
  fill(235, 205, 110);
  text("Num+ / L    BARRAGE ultimate  (when meter full)", rx, ty + dy * 5);

  textAlign(CENTER, CENTER);
  fill(120);
  textSize(15);
  text("Player 2: use the numpad (NumLock ON), or  . , /  if you have no numpad", width / 2, ty + dy * 6 + 6);
  fill(185);
  textSize(18);
  text("Press ENTER to go back", width / 2, height - 50);

  textAlign(LEFT, BASELINE);
}

void drawCharSelect() {
  background(20, 22, 28);
  noStroke();
  fill(60, 40, 20);
  rect(0, 570, width, 220);

  textFont(minecraft);
  textAlign(CENTER, CENTER);
  fill(235, 205, 110);
  textSize(54);
  text("CHOOSE YOUR FIGHTER", width / 2, 90);

  // roster row
  float boxW = 110, boxH = 130, gap = 14;
  float rowW = ROSTER_SIZE * boxW + (ROSTER_SIZE - 1) * gap;
  float startX = (width - rowW) / 2.0;
  float boxY = 250;

  for (int i = 0; i < ROSTER_SIZE; i++) {
    float bx = startX + i * (boxW + gap);

    // box background
    noStroke();
    fill(rosterAvailable[i] ? color(46, 50, 60) : color(32, 34, 40));
    rect(bx, boxY, boxW, boxH);

    // icon or "?"
    if (rosterIcons[i] != null) {
      PImage ic = rosterIcons[i];
      float pad = 14;
      float maxW = boxW - pad * 2, maxH = boxH - pad * 2;
      float sc = min(maxW / ic.width, maxH / ic.height);
      float dw = ic.width * sc, dh = ic.height * sc;
      image(ic, bx + (boxW - dw) / 2, boxY + (boxH - dh) / 2, dw, dh);
    } else {
      fill(120);
      textSize(64);
      text("?", bx + boxW / 2, boxY + boxH / 2);
    }

    // red flash when a player confirmed this locked slot
    int flash = 0;
    if (p1Cursor == i) flash = max(flash, p1Flash);
    if (p2Cursor == i) flash = max(flash, p2Flash);
    if (flash > 0) {
      noStroke();
      fill(200, 40, 40, flash * 12);
      rect(bx, boxY, boxW, boxH);
    }

    // name under box
    fill(rosterAvailable[i] ? color(210) : color(110));
    textSize(15);
    text(rosterNames[i], bx + boxW / 2, boxY + boxH + 22);
  }

  // cursors (P1 blue, P2 red); offset slightly so overlapping reads
  drawCursor(p1Cursor, startX, boxY, boxW, boxH, gap, color(90, 150, 255), "P1", p1Locked, -4);
  drawCursor(p2Cursor, startX, boxY, boxW, boxH, gap, color(235, 90, 90), "P2", p2Locked,  4);

  // tick flash timers
  if (p1Flash > 0) p1Flash--;
  if (p2Flash > 0) p2Flash--;

  // hints
  fill(120);
  textSize(14);
  text("P1:  A / D  move      SPACE  lock          P2:  ← / →  move      Num0 / .  lock",
    width / 2, height - 60);
  text("both players lock in to FIGHT", width / 2, height - 38);

  textAlign(LEFT, BASELINE);
}

void drawCursor(int idx, float startX, float boxY, float boxW, float boxH, float gap,
                color col, String label, boolean locked, float off) {
  float bx = startX + idx * (boxW + gap) + off;
  float by = boxY + off;
  noFill();
  strokeWeight(locked ? 6 : 3);
  stroke(col);
  rect(bx, by, boxW, boxH);
  noStroke();
  fill(col);
  textAlign(CENTER, CENTER);
  textSize(16);
  text(locked ? label + " READY" : label, bx + boxW / 2, by - 14);
  strokeWeight(1);
}

void selectMenu() {
  if (menuIndex == 0) {            // VS MODE -> pick fighters first
    resetCharSelect();
    screen = "CHAR_SELECT";
  } else if (menuIndex == 1) {     // CONTROLS
    screen = "CONTROLS";
  } else if (menuIndex == 2) {     // QUIT
    exit();
  }
}

void resetCharSelect() {
  p1Cursor = p1CharIndex;   // start on the last-used picks (nice for "swap")
  p2Cursor = p2CharIndex;
  p1Locked = false; p2Locked = false;
  p1Flash = 0; p2Flash = 0;
}

void tryLock(boolean isP1) {
  int cur = isP1 ? p1Cursor : p2Cursor;
  if (!rosterAvailable[cur]) {            // "?" slot -> flash red, do nothing else
    if (isP1) p1Flash = 18; else p2Flash = 18;
    sfx(sndMenuMove, 0.5);
    return;
  }
  if (isP1) p1Locked = true; else p2Locked = true;
  sfx(sndMenuSelect, 0.7);
  if (p1Locked && p2Locked) {            // both in -> commit + fight
    p1CharIndex = p1Cursor;
    p2CharIndex = p2Cursor;
    screen = "GAME";
    startMatch();
  }
}

void selectEndMenu() {
  if (endMenuIndex == 0) {                 // PLAY AGAIN (same fighters)
    startMatch();                          // stays on screen "GAME"
  } else if (endMenuIndex == 1) {          // SWAP CHARACTERS
    resetCharSelect();
    screen = "CHAR_SELECT";
    playMusic(musMenu);
  } else {                                 // MAIN MENU
    screen = "MENU";
    playMusic(musMenu);
  }
}

// =============================================================================
//                                INPUT EVENTS
// =============================================================================
void keyPressed() {
  boolean repeat = (keyCode < 256 && keys[keyCode]) || (keyCode < 600 && keyCodes[keyCode]);
  if (keyCode < 256) keys[keyCode] = true;
  if (keyCode < 600) keyCodes[keyCode] = true;

  // MENU
  if (screen.equals("MENU")) {
    if (keyCode == UP   || key == 'w' || key == 'W') { menuIndex = (menuIndex + menuItems.length - 1) % menuItems.length; sfx(sndMenuMove, 0.6); }
    if (keyCode == DOWN || key == 's' || key == 'S') { menuIndex = (menuIndex + 1) % menuItems.length; sfx(sndMenuMove, 0.6); }
    if (keyCode == ENTER || keyCode == RETURN || key == ' ') { sfx(sndMenuSelect, 0.7); selectMenu(); }
    return;
  }

  // CONTROLS
  if (screen.equals("CONTROLS")) {
    if (keyCode == ENTER || keyCode == RETURN || key == ' ') { sfx(sndMenuSelect, 0.7); screen = "MENU"; }
    return;
  }

  // CHARACTER SELECT
  if (screen.equals("CHAR_SELECT")) {
    // P1 move (A/D)
    if (key == 'a' || key == 'A') { p1Cursor = (p1Cursor + ROSTER_SIZE - 1) % ROSTER_SIZE; sfx(sndMenuMove, 0.6); }
    if (key == 'd' || key == 'D') { p1Cursor = (p1Cursor + 1) % ROSTER_SIZE; sfx(sndMenuMove, 0.6); }
    // P2 move (arrows)
    if (keyCode == LEFT)  { p2Cursor = (p2Cursor + ROSTER_SIZE - 1) % ROSTER_SIZE; sfx(sndMenuMove, 0.6); }
    if (keyCode == RIGHT) { p2Cursor = (p2Cursor + 1) % ROSTER_SIZE; sfx(sndMenuMove, 0.6); }
    // confirm: P1 = SPACE, P2 = Num0 or .
    if (!repeat && key == ' ')                                          tryLock(true);
    if (!repeat && (keyCode == P2_ATTACK || keyCode == P2_ATTACK_ALT))  tryLock(false);
    return;
  }

  // ============================ GAME ============================
  if (key == 'h' || key == 'H') showHitboxes = !showHitboxes;

  if (canAct()) {
    // - P1 (left hand) -
    if (!repeat && (key == 'w' || key == 'W'))   p1.bufferJump();
    if (!repeat && (key == ' '))                 p1.bufferAttack();
    if (!repeat && (key == 'f' || key == 'F'))   p1.startBlock();
    if (!repeat && (key == 'r' || key == 'R'))   p1.startUnsheath();
    if (!repeat && (key == 'a' || key == 'A'))   p1.tryDash(-1);
    if (!repeat && (key == 'd' || key == 'D'))   p1.tryDash(1);
    if (!repeat && (key == 'q' || key == 'Q'))   p1.tryUltimate();

    // - P2 (arrows + numpad OR . , /) -
    if (!repeat && keyCode == UP)                                        p2.bufferJump();
    if (!repeat && (keyCode == P2_ATTACK  || keyCode == P2_ATTACK_ALT))  p2.bufferAttack();
    if (!repeat && (keyCode == P2_BLOCK   || keyCode == P2_BLOCK_ALT))   p2.startBlock();
    if (!repeat && (keyCode == P2_SHEATHE || keyCode == P2_SHEATHE_ALT)) p2.startUnsheath();
    if (!repeat && keyCode == LEFT)  p2.tryDash(-1);
    if (!repeat && keyCode == RIGHT) p2.tryDash(1);
    if (!repeat && (keyCode == 107 || key == 'l' || key == 'L')) p2.tryUltimate();  // Numpad + or L
  }

  // match over - 3-option menu (WASD/arrows + ENTER/SPACE)
  if (matchState.equals("MATCH_OVER")) {
    if (keyCode == UP || keyCode == LEFT || key == 'w' || key == 'W' || key == 'a' || key == 'A')
      { endMenuIndex = (endMenuIndex + endMenuItems.length - 1) % endMenuItems.length; sfx(sndMenuMove, 0.6); }
    if (keyCode == DOWN || keyCode == RIGHT || key == 's' || key == 'S' || key == 'd' || key == 'D')
      { endMenuIndex = (endMenuIndex + 1) % endMenuItems.length; sfx(sndMenuMove, 0.6); }
    if (keyCode == ENTER || keyCode == RETURN || key == ' ') { sfx(sndMenuSelect, 0.7); selectEndMenu(); }
    return;
  }
}

void keyReleased() {
  if (keyCode < 256) keys[keyCode] = false;
  if (keyCode < 600) keyCodes[keyCode] = false;

  if (screen.equals("GAME")) {
    if (key == 'f' || key == 'F') p1.stopBlock();
    if (keyCode == P2_BLOCK || keyCode == P2_BLOCK_ALT) p2.stopBlock();
  }
}

// =============================================================================
//                               CUSTOM FUNCTIONS
// =============================================================================
boolean canAct() {
  return matchState.equals("FIGHTING") && hitFreeze <= 0;
}

void impact(int freeze, float shake) {
  hitFreeze = max(hitFreeze, freeze);
  shakeMag  = max(shakeMag, shake);
}

void spawnHitSparks(float x, float y) {
  int n = 10 + (int) random(4);                 // ~10-13 sparks per hit
  for (int i = 0; i < n; i++) sparks.add(new HitSpark(x, y));
}

// centre of the overlap between two boxes = where the strike landed
float[] contactPoint(HitBox a, HitBox b) {
  float ix1 = max(a.x, b.x);
  float iy1 = max(a.y, b.y);
  float ix2 = min(a.x + a.w, b.x + b.w);
  float iy2 = min(a.y + a.h, b.y + b.h);
  return new float[] { (ix1 + ix2) / 2.0, (iy1 + iy2) / 2.0 };
}

Player makeFighter(int idx, float x, float y, boolean startRight) {
  switch (idx) {
    case 1:  return new Brawler(x, y, startRight);
    default: return new Samurai(x, y, startRight);   // slot 0 / fallback
  }
}

void spawnPlayers() {
  p1 = makeFighter(p1CharIndex, 80,  570, true);
  p2 = makeFighter(p2CharIndex, 825, 570, false);
}

//push box
void resolveCollision(Player a, Player b) {
  if (a.isUlting || b.isUlting) return;   // let the ult dash pass through cleanly
  // figure out who is physically on the left right now (by sprite centre)
  float aCx = a.x + a.BASE_W / 2.0;
  float bCx = b.x + b.BASE_W / 2.0;
  Player left  = (aCx <= bCx) ? a : b;
  Player right = (left == a) ? b : a;

  // box edges
  float lw = left.BASE_W  * left.BODY_W;
  float rw = right.BASE_W * right.BODY_W;
  float lRight = left.x  + (left.BASE_W  - lw) / 2.0 + lw;   // left player's right edge
  float rLeft  = right.x + (right.BASE_W - rw) / 2.0;        // right player's left edge

  float overlap = lRight - rLeft;
  if (overlap <= 0) return;

  // only block when they actually share height lets a high jump overhead
  float lTop = left.y  - left.BASE_H  * left.BODY_H;
  float rTop = right.y - right.BASE_H * right.BODY_H;
  if (left.y <= rTop || right.y <= lTop) return;

  // shove both apart by half each
  float half = overlap / 2.0;
  left.x  -= half;
  right.x += half;

  // wall collision
  float rightMax = width - left.BASE_W;     // both share the same sprite footprint
  if (left.x < 0) {
    right.x += (0 - left.x);
    left.x  = 0;
  }
  if (right.x > rightMax) {
    left.x  -= (right.x - rightMax);
    right.x = rightMax;
  }
  left.x  = constrain(left.x, 0, rightMax);
  right.x = constrain(right.x, 0, rightMax);

  if (left.vx  > 0) left.vx  = 0;
  if (right.vx < 0) right.vx = 0;
}

boolean resolveAttack(Player attacker, Player defender, String defenderTag, int attackerId) {
  HitBox atk  = attacker.getAttackHitBox();
  HitBox body = defender.getBodyHitBox();
  if (atk == null || body == null || !atk.overlaps(body) || attacker.hasHit) return false;

  attacker.hasHit = true;
  float[] cp = contactPoint(atk, body);
  float hx = cp[0], hy = cp[1];

  //parry
  if (defender.isBlocking && defender.isParryWindow && defender.isFacing(attacker)) {
    attacker.isStunned = true;
    attacker.stunTimer = 30;
    roundMsg   = defenderTag + " PARRY!";
    parryFlash = 235;
    sfx(sndParry, 0.9);
    impact(16, 16);
    attacker.applyKnockback(attacker.facingRight ? -11 : 11);
    spawnHitSparks(hx, hy);
    return true;
  }

  //matched held block: chip
  if (defender.isBlockingType(atk.type) && defender.isFacing(attacker)) {
    int chip = min(CHIP_DMG, max(0, defender.hp - 1));   // block can't KO
    defender.takeDamage(chip, hx, hy);
    sfx(sndBlock, 0.8);
    impact(4, 5);
    defender.applyKnockback(attacker.facingRight ? 6 : -6);
    attacker.addMeter(chip * METER_DEAL);                // charge the ult meter
    defender.addMeter(chip * METER_TAKE);
  } else {
    //clean hit
    defender.isStunned = true;
    defender.stunTimer = HITSTUN;
    int dealt = attacker.attackDamage(atk.type);
    defender.takeDamage(dealt, hx, hy);
    attacker.onLandHit(atk.type, hx, hy);   // let the attacker react
    sfx(sndHit, 0.85);
    impact(9, 14);
    defender.applyKnockback(attacker.facingRight ? 13 : -13);
    attacker.addMeter(dealt * METER_DEAL);              // primary: dealing damage
    defender.addMeter(dealt * METER_TAKE);              // secondary: taking damage
  }

  if (defender.isDead()) endRound(attackerId);
  return true;
}

void checkHits() {
  if (resolveAttack(p1, p2, "P2", 1)) return;   // P1 attacks P2 (checked first)
  resolveAttack(p2, p1, "P1", 2);               // P2 attacks P1
}

void endRound(int winnerId) {
  if (winnerId == 1) p1Wins++;
  else               p2Wins++;
  impact(30, 22);
  sfx(sndKO, 0.95);

  // deciding K.O. \u2014 show the "WINS!" banner briefly, then the ROUND_OVER timer rolls into the menu
  if (p1Wins >= roundsToWin || p2Wins >= roundsToWin) {
    roundMsg   = (winnerId == 1) ? "PLAYER 1 WINS!" : "PLAYER 2 WINS!";
    roundTimer = MATCH_END_DELAY;
  } else {
    roundMsg   = (winnerId == 1) ? "PLAYER 1 \u2014 K.O.!" : "PLAYER 2 \u2014 K.O.!";
    roundTimer = ROUND_DELAY;
  }
  matchState = "ROUND_OVER";
  frameRate(30);
}

// transition straight into the match-over menu (winner banner + Play Again / Swap / Main Menu)
void goToMatchOver(int winnerId) {
  matchState   = "MATCH_OVER";
  endMenuIndex = 0;
  frameRate(60);

  if (winnerId == 1) {
    roundMsg = "PLAYER 1 WINS!";
    p1TotalWins++;
    p1WinStreak++;
    p2WinStreak = 0; // Reset P2's streak
    if (p1WinStreak > p1HighestStreak) {
      p1HighestStreak = p1WinStreak;
      saveHighScore();
    }
  } else {
    roundMsg = "PLAYER 2 WINS!";
    p2TotalWins++;
    p2WinStreak++;
    p1WinStreak = 0; // Reset P1's streak
    if (p2WinStreak > p2HighestStreak) {
      p2HighestStreak = p2WinStreak;
      saveHighScore();
    }
  }
}

// =============================================================================
//                                    HUD
// =============================================================================
// themed ultimate charge bar. samurai = katana gold->crimson, brawler = rage orange->red.
void drawUltBar(float bx, float by, float w, float h, float pct, boolean ready,
                boolean leftAligned, boolean samurai, String label) {
  pct = constrain(pct, 0, 1);
  pushStyle();
  noStroke();

  // track
  fill(28, 28, 34);
  rect(bx, by, w, h, 3);

  // fill (mirrors the health bars: P1 grows right, P2 grows left)
  color cMid  = samurai ? color(235, 205, 110) : color(240, 150, 40);
  color cFull = samurai ? color(163, 31, 35)   : color(200, 30, 20);
  fill(lerpColor(cMid, cFull, pct));
  float fw = (w - 4) * pct;
  if (leftAligned) rect(bx + 2,          by + 2, fw, h - 4, 2);
  else             rect(bx + w - 2 - fw, by + 2, fw, h - 4, 2);

  // pulsing glow + READY cue when full
  if (ready) {
    float pulse = 0.5 + 0.5 * sin(frameCount * 0.3);
    noFill();
    stroke(255, 240, 160, 120 + 120 * pulse);
    strokeWeight(2);
    rect(bx, by, w, h, 3);
    noStroke();
    textFont(minecraft);
    textSize(12);
    textAlign(CENTER, CENTER);
    fill(20, 16, 8, 200 + 55 * pulse);
    text(label + "  READY", bx + w / 2, by + h / 2 - 1);
  }
  popStyle();
}

void drawHUD() {
  int barW   = 340;
  int barH   = 22;
  int barY   = 100;
  int barPad = 3;

  //  P1 health (left) 
  float p1Pct = (float)p1.hp / p1.maxHp;
  noStroke();
  fill(50);
  rect(20, barY, barW, barH, 4);
  fill(176, 199, 119);
  rect(20 + barPad, barY + barPad, (barW - barPad * 2) * p1Pct, barH - barPad * 2, 3);

  //  P2 health (right, drains toward center) 
  float p2Pct = (float)p2.hp / p2.maxHp;
  fill(50);
  rect(width - 20 - barW, barY, barW, barH, 4);
  float p2BarW = (barW - barPad * 2) * p2Pct;
  fill(lerpColor(color(76, 199, 119), color(176, 199, 119), p2Pct));
  rect(width - 20 - barW + barPad + (barW - barPad * 2 - p2BarW), barY + barPad, p2BarW, barH - barPad * 2, 3);

  //  round-win pips 
  for (int i = 0; i < roundsToWin; i++) {
    fill(i < p1Wins ? color(255, 220, 0) : color(60, 60, 80));
    rect(20 + i * 28, 135, 20, 20, 3);
  }
  for (int i = 0; i < roundsToWin; i++) {
    fill(i < p2Wins ? color(255, 220, 0) : color(60, 60, 80));
    rect(width - 10 - (i + 1) * 28, 135, 20, 20, 3);
  }

  //  ultimate charge meters (slim bar tucked under each health bar)
  int ultY = 124;
  int ultH = 10;
  drawUltBar(20, ultY, barW, ultH, p1.ultMeter / p1.ULT_MAX, p1.ultReady(), true,  true,  "IAIJUTSU");
  drawUltBar(width - 20 - barW, ultY, barW, ultH, p2.ultMeter / p2.ULT_MAX, p2.ultReady(), false, false, "BARRAGE");

  //  labels
  textFont(kiwiSoda);
  textSize(65);
  fill(60, 76, 104);
  textAlign(LEFT);
  text("P1  " + p1.name, 20, 80);
  fill(163, 31, 35);
  textAlign(RIGHT);
  text(p2.name + "  P2", width - 20, 80);

  //round timer
  int secs = constrain(ceil(roundClock / 60.0), 0, 99);
  fill(197, 214, 214);
  textSize(96);
  textAlign(CENTER);
  text(nf(secs, 2), width / 2, 100);

  //center messages
  if (matchState.equals("ROUND_INTRO")) {
    fill(255, 240, 100);
    if (introTimer > INTRO_TIME * 0.45) {
      textSize(270);
      text("ROUND " + currentRound, width / 2, height / 2);
    } else {
      textSize(275);
      text("FIGHT!", width / 2, height / 2);
    }
    fill(230);
    textSize(17);
    text("P1   A/D move   W jump   SPACE strike (fwd=lunge / back=hop / S=low)   F block (S=low)   R sheathe   Q ULTIMATE",
      width / 2, height - 42);
    text("P2   LEFT ARROW RIGHT ARROW move   UP ARROW jump   strike Num0 or .   block Num. or ,   dodge Num5 or /   Num+/L ULTIMATE   (DOWN ARROW=low)",
      width / 2, height - 22);
    textAlign(LEFT);
  } else if (matchState.equals("ROUND_OVER") || matchState.equals("MATCH_OVER")) {
    fill(255, 240, 100);
    textSize(matchState.equals("MATCH_OVER") ? 44 : 34);
    text(roundMsg, width / 2, matchState.equals("MATCH_OVER") ? height / 2 - 60 : height / 2);
    if (matchState.equals("MATCH_OVER")) {
      for (int i = 0; i < endMenuItems.length; i++) {
        boolean sel = (i == endMenuIndex);
        float yy = height / 2 + 20 + i * 46;
        if (sel) {
          fill(235, 205, 110);
          textSize(28);
          text("→  " + endMenuItems[i] + "  ←", width / 2, yy);
        } else {
          fill(150);
          textSize(24);
          text(endMenuItems[i], width / 2, yy);
        }
      }
      fill(120);
      textSize(13);
      text("W / S  or  arrows  to move        ENTER or SPACE to select", width / 2, height / 2 + 20 + endMenuItems.length * 46 + 14);
    }
    textAlign(LEFT);
  } else if (!roundMsg.equals("")) {
    fill(255, 240, 100);
    textSize(28);
    text(roundMsg, width / 2, height / 2 - 120);
    textAlign(LEFT);
  }
 //SCOREBOARD
  textFont(minecraft);
  textSize(18);
  fill(255);
  
  //P1
  textAlign(LEFT);
  text("Samurai Streak: " + p1WinStreak, 20, 175);
  text("Best Streak: " + p1HighestStreak, 20, 200);
  
  //P2
  textAlign(RIGHT);
  text("Brawler Streak: " + p2WinStreak, width - 20, 175);
  text("Best Streak: " + p2HighestStreak, width - 20, 200);
  
  // Reset alignment for everything else
  textAlign(LEFT);
}
void loadHighScore() {
  String[] data = loadStrings(dataPath("highscore.txt"));
  if (data != null && data.length >= 2) {
    p1HighestStreak = int(data[0]);
    p2HighestStreak = int(data[1]);
  } else {
    p1HighestStreak = 0;
    p2HighestStreak = 0;
  }
}

void saveHighScore() {
  String[] data = {
    str(p1HighestStreak),
    str(p2HighestStreak)
  };

  saveStrings(dataPath("highscore.txt"), data);
}
