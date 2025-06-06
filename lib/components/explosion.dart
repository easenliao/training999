import 'package:flame/components.dart';
import 'package:training999/training_999.dart';

class ExplosionComponent extends SpriteAnimationComponent
    with HasGameRef<Training999> {
  ExplosionComponent({super.position})
      : super(
          size: Vector2.all(50),
          anchor: Anchor.center,
          removeOnFinish: false,
          priority: 200
        );

  @override
  Future<void> onLoad() async {
    animation = await game.loadSpriteAnimation(
      'explosion.png',
      SpriteAnimationData.sequenced(
        stepTime: 0.1,
        amount: 6,
        textureSize: Vector2.all(32),
        loop: false,
      ),
    );
  }
}
