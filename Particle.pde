// =============================================================================
//                                 EFFECTS
// =============================================================================

// retro hit spark: a small square pixel that flies out and falls
class HitSpark {
  float x, y, vx, vy;
  float life    = 15;     // frames of lifetime
  float maxLife = 15;
  float size;
  color c;

  HitSpark(float x, float y) {
    this.x = x;
    this.y = y;
    float ang = random(TWO_PI);
    float spd = random(2, 6);
    vx = cos(ang) * spd;
    vy = sin(ang) * spd - 1.5;          // slight upward bias on the burst
    size = floor(random(2, 5));         // 2-4 px blocky sparks
    c = (random(1) < 0.5) ? color(255, 255, 255)   // white core
                          : color(255, 220, 60);    // yellow spark
  }

  void update() {
    x  += vx;
    y  += vy;
    vy += 0.4;        // gravity
    vx *= 0.96;       // slight drag
    life--;
  }

  void display() {
    float a = map(life, 0, maxLife, 0, 255);
    noStroke();
    fill(c, a);
    rect(floor(x - size / 2), floor(y - size / 2), size, size);  // integer = crisp pixels
  }

  boolean isDead() { return life <= 0; }
}
