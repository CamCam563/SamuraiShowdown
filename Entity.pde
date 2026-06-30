// =============================================================================
//                                   ENTITY
// =============================================================================
class Entity {
  float x, y;
  PImage img;
  int hp    = 100;
  int maxHp = 100;

  Entity(float x, float y) {
    this.x = x;
    this.y = y;
  }

  void update()  {}
  void display() {}
}

// =============================================================================
//                                   HITBOX
// =============================================================================
class HitBox {
  float x, y, w, h;
  String type;

  HitBox(float x, float y, float w, float h, String type) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.type = type;
  }

  boolean overlaps(HitBox other) {
    return !(x + w < other.x ||
             x > other.x + other.w ||
             y + h < other.y ||
             y > other.y + other.h);
  }
}
