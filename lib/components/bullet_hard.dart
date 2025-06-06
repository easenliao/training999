import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:training999/training_999.dart';

class BulletHard extends SpriteComponent
    with HasGameRef<Training999>, CollisionCallbacks {
  late Vector2 _velocity;
  late Vector2 direction;
  Vector2 previousDirection = Vector2.zero(); // 儲存上一幀的方向向量

  BulletHard(position) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    add(RectangleHitbox());

    sprite =
        await gameRef.loadSprite('bullet_hard.png', srcSize: Vector2(7, 7));

    direction = (game.player.position - position).normalized();
    _velocity = Vector2(direction.x * 450, direction.y * 400);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) {
      return;
    }

    var desiredDirection = (game.player.position - position).normalized();
    // 計算當前方向與目標方向之間的夾角
    double angleDifference =
        _calculateAngleBetween(previousDirection, desiredDirection);
    // 限制角度變化在 30 度範圍內（約 0.52 弧度）
    double maxTurnAngle = 60 * (pi / 180); // 30 度轉換成弧度
    if (angleDifference > maxTurnAngle) {
      // 限制角度變化到最大允許角度
      desiredDirection =
          _limitAngleChange(previousDirection, desiredDirection, maxTurnAngle);
    }
    position.add(desiredDirection + _velocity * dt);
    previousDirection = desiredDirection;

    if (position.y < -game.gameSizeOfRadius / 2 ||
        position.y > game.size.y + game.gameSizeOfRadius / 4 ||
        position.x > game.size.x + game.gameSizeOfRadius / 2 ||
        position.x + size.x < -game.gameSizeOfRadius / 4) {
      removeFromParent();
    }
  }

  // 計算兩個向量之間的夾角
  double _calculateAngleBetween(Vector2 v1, Vector2 v2) {
    double dotProduct = v1.dot(v2);
    double magnitudeProduct = v1.length * v2.length;
    return acos(dotProduct / magnitudeProduct);
  }

  // 限制方向變化到給定的最大角度
  Vector2 _limitAngleChange(
      Vector2 currentDirection, Vector2 desiredDirection, double maxAngle) {
    // 當前方向與目標方向的夾角
    double currentAngle = atan2(currentDirection.y, currentDirection.x);
    double desiredAngle = atan2(desiredDirection.y, desiredDirection.x);

    // 計算兩者之間的差距
    double angleDifference = desiredAngle - currentAngle;

    // 確保角度差在 -π 到 π 之間
    if (angleDifference > pi) {
      angleDifference -= 2 * pi;
    } else if (angleDifference < -pi) {
      angleDifference += 2 * pi;
    }

    // 限制角度差在最大允許角度內
    double limitedAngleDifference = angleDifference.clamp(-maxAngle, maxAngle);

    // 計算新的角度
    double newAngle = currentAngle + limitedAngleDifference;

    // 根據新的角度計算新的方向向量
    return Vector2(cos(newAngle), sin(newAngle));
  }
}
