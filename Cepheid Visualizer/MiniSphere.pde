// MiniSphere.pde
class MiniSphere {
  PVector pos, vel;
  float size, life;
  color c;

  MiniSphere() {
    float m = 20;
    pos = new PVector(
      random(-roomSize.x/2 + m, roomSize.x/2 - m),
      random(-roomSize.y/2 + m, roomSize.y/2 - m),
      random(-roomSize.z/2 + m, roomSize.z/2 - m)
    );
    vel  = PVector.random3D().mult(random(1,2));
    size = random(15,25);
    life = 255;
    c    = color(random(360),80,100);
  }

  void update() {
    pos.add(vel);
    life -= 1.5;
    if (abs(pos.x)+size/2 > roomSize.x/2) vel.x *= -1;
    if (abs(pos.y)+size/2 > roomSize.y/2) vel.y *= -1;
    if (abs(pos.z)+size/2 > roomSize.z/2) vel.z *= -1;
  }

  void drawSceneSphere(PGraphics pg) {
    pg.pushMatrix();
      pg.translate(pos.x, pos.y, pos.z);
      pg.fill(c, map(life, 0, 255, 0, 100));
      pg.sphereDetail(10);
      pg.sphere(size);
    pg.popMatrix();
  }

  boolean isDead() {
    return life <= 0;
  }
}
