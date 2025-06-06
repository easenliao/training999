import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Route;
import 'package:training999/components/airplane.dart';
import 'package:training999/components/bullet_easy.dart';
import 'package:training999/components/bullet_hard.dart';
import 'package:training999/components/bullet_mid.dart';
import 'package:training999/components/explosion.dart';
import 'package:training999/components/info_text.dart';
import 'package:training999/components/score_text.dart';
import 'package:training999/components/star_background_creator.dart';
import 'package:training999/constant.dart';
import 'package:training999/page/menu_page.dart';
import 'package:training999/page/splash_page.dart';
import 'package:training999/provider/name/my_name_provider.dart';
import 'package:training999/provider/rank/model/rank.dart';
import 'package:training999/provider/rank/all_rank_provider.dart';
import 'package:training999/util/bullet_level.dart';
import 'package:training999/util/music_manager.dart';

import 'components/detect_close_to_bullet.dart';

class Training999 extends FlameGame
    with
        RiverpodGameMixin,
        DragCallbacks,
        TapCallbacks,
        HasCollisionDetection,
        HasKeyboardHandlerComponents {
  static const double _joystickControllerConstant = 1.5;
  static const double _keyControllerConstant = 1.5;
  double _timeElapsed = 0;

  late Airplane player;
  late DetectCloseToBullet detectCloseToBullet;
  late JoystickComponent joystickLeft;
  late JoystickComponent joystickRight;
  late double gameSizeOfRadius;
  int bulletCount = 0;
  bool isGameOver = true;
  int gameTime = 0;
  int lastTime = 0;
  int surviveTime = 0;
  int brilliantlyDodgedTheBullet = 0;

  late final RouterComponent router;
  late Set<LogicalKeyboardKey> pressedKeySets;
  late String myName;
  MusicManager musicManager = MusicManager();

  Training999() : super();

  @override
  bool get pauseWhenBackgrounded => true;

  // 0xFF001030
  // 0xFF000030
  @override
  Color backgroundColor() => const Color(0xFF001030);

  @override
  void stepEngine({double stepTime = 1 / 60}) {
    super.stepEngine();
  }

  @override
  Future onLoad() async {
    super.onLoad();
    // debugMode = kDebugMode;
    await musicManager.init();
    musicManager.playBgm();
    add(router = RouterComponent(initialRoute: "splash", routes: {
      'splash': Route(SplashPage.new),
      'menu': Route(MenuPage.new),
    }));

    await images.loadAllImages();
    gameSizeOfRadius = pow(
            pow(camera.viewport.size.x, 2) + pow(camera.viewport.size.y, 2),
            0.5) /
        2.0;
    player = Airplane();
    detectCloseToBullet = DetectCloseToBullet();
    add(StarBackGroundCreator());
    initJoystick();
    pressedKeySets = {};
  }

  @override
  void onMount() {
    ref.read(allRankProvider); // 提前觸發 allRankProvider 的 build
    addToGameWidgetBuild(() {
      // 在這裡才能操作riverpod
      ref.listen(myNameProvider, (previous, current) {
        if (current.hasValue && current.value!.name.isNotEmpty) {
          myName = current.value!.name;
          overlays.remove("enter_name");
        }
      }, onError: (error, stackTrace) {

      });
    });
    super.onMount();
  }

  void start() {
    isGameOver = false;
    overlays.clear();
    if (!contains(player)) {
      add(player);
      add(detectCloseToBullet);
    }
    if (!contains(joystickLeft) || !contains(joystickRight)) {
      addJoystick();
    }

    detectCloseToBullet.position = player.position;
    add(TimerComponent(
        period: 1,
        repeat: true,
        autoStart: true,
        removeOnFinish: true,
        onTick: () {
          if (isGameOver) {
            return;
          }

          if (gameTime == 0) {
            addBullet(BulletLevel.easy);
            add(InfoTextComponent('Game Start!', Vector2(size.x / 2, 0)));
          }

          if (gameTime > 0 && gameTime % 15 == 0) {
            addBullet(BulletLevel.middle);
            add(InfoTextComponent('高速彈發射!', Vector2(size.x / 2, 0)));
          }

          if (gameTime > 0 && gameTime % 25 == 0) {
            addBullet(BulletLevel.hard);
            add(InfoTextComponent('誘導彈發射!', Vector2(size.x / 2, 0)));
          }
          gameTime++;
        }));
  }

  void addBulletCountText() {
    if (gameTime != 0) {
      calcBulletCount();
      add(ScoreText());
    }
  }

  void addBullet(BulletLevel bulletLevel) {
    final Random _rng = Random(DateTime.now().millisecondsSinceEpoch);
    add(SpawnComponent(
        selfPositioning: true,
        factory: (int amount) {
          var angle = _rng.nextDouble() * 360;
          var radians = angle * pi / 180;
          Vector2 position = Vector2(gameSizeOfRadius * cos(radians),
                  gameSizeOfRadius * sin(radians))
              .translated(size.x / 2, size.y / 2);
          switch (bulletLevel) {
            case BulletLevel.easy:
              return BulletEasy(position);
            case BulletLevel.middle:
              return BulletMid(position);
            case BulletLevel.hard:
              return BulletHard(position);
          }
        },
        period: bulletLevel.getPeriod()));
  }

  void addBrilliantlyDodgedTheBulletText() {
    brilliantlyDodgedTheBullet++;
    add(InfoTextComponent('絕妙度過子彈！', size / 2));
  }

  @override
  void updateTree(double dt) {
    _timeElapsed += dt;
    // // make sure we update at most 60fps
    if (_timeElapsed > timePerFrame) {
      _timeElapsed -= timePerFrame;
      updateJoystick();
      updateKeys();
      super.updateTree(timePerFrame);
    }
  }

  @override
  void update(double dt) {
    if (!isGameOver) {
      var dateTime = DateTime.now();
      if (lastTime == 0) {
        lastTime = dateTime.millisecondsSinceEpoch;
      }
      var now = dateTime.millisecondsSinceEpoch;
      surviveTime = now - lastTime;
    }
    super.update(dt);
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    super.onKeyEvent(event, keysPressed);

    if (isGameOver) {
      return KeyEventResult.ignored;
    }

    _clearPressedKeys();
    for (final key in keysPressed) {
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
        pressedKeySets.add(key);
      } else if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS) {
        pressedKeySets.add(key);
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA) {
        pressedKeySets.add(key);
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        pressedKeySets.add(key);
      } else {
        return KeyEventResult.ignored;
      }
    }

    return KeyEventResult.handled;
  }

  void _clearPressedKeys() {
    pressedKeySets.clear();
  }

  void initJoystick() {
    joystickLeft = JoystickComponent(
        priority: 10,
        knob: SpriteComponent(
          size: Vector2(50, 50),
          sprite: Sprite(
            images.fromCache('Knob.png'),
          ),
        ),
        background: SpriteComponent(
          size: Vector2(64, 64),
          sprite: Sprite(
            images.fromCache('Joystick.png'),
          ),
        ),
        position: Vector2(64, canvasSize.y - 64));
    joystickRight = JoystickComponent(
        priority: 10,
        knob: SpriteComponent(
          size: Vector2(50, 50),
          sprite: Sprite(
            images.fromCache('Knob.png'),
          ),
        ),
        background: SpriteComponent(
          size: Vector2(64, 64),
          sprite: Sprite(
            images.fromCache('Joystick.png'),
          ),
        ),
        position: Vector2(canvasSize.x - 64, canvasSize.y - 64));
  }

  void addJoystick() {
    add(joystickLeft);
    add(joystickRight);
  }

  Future<void> gameover() async {
    isGameOver = true;
    musicManager.playExplosion();
    final now = Timestamp.now();
    // 等待新增成功才顯示排行榜View (否則會先顯示先前的排行榜資料, 才再出現這次這筆)
    await ref.read(allRankProvider.notifier).insertRecord(Rank(
        id: now.millisecondsSinceEpoch,
        name: myName,
        survivedTimeInMilliseconds: surviveTime,
        brilliantlyDodgedTheBullets: brilliantlyDodgedTheBullet,
        platform: Platform.isAndroid ? 'Android' : 'iOS',
        createdAt: now));
    overlays.add('rank');
    removeWhere((c) => c is JoystickComponent);
    removeWhere((c) => c is TimerComponent);
    removeWhere((c) => c is SpawnComponent);
  }

  void reset() {
    overlays.remove('rank');
    removeWhere((c) =>
        c is BulletEasy ||
        c is BulletMid ||
        c is BulletHard ||
        c is TimerComponent ||
        c is SpawnComponent ||
        c is ExplosionComponent ||
        c is ScoreText);
    bulletCount = 0;
    gameTime = 0;
    surviveTime = 0;
    lastTime = 0;
    brilliantlyDodgedTheBullet = 0;
  }

  void updateJoystick() {
    if (isGameOver) {
      return;
    }
    switch (joystickLeft.direction) {
      case JoystickDirection.left:
        player.position += Vector2(-_joystickControllerConstant, 0);
        break;
      case JoystickDirection.upLeft:
        player.position +=
            Vector2(-_joystickControllerConstant, -_joystickControllerConstant);
        break;
      case JoystickDirection.up:
        player.position += Vector2(0, -_joystickControllerConstant);
        break;
      case JoystickDirection.upRight:
        player.position +=
            Vector2(_joystickControllerConstant, -_joystickControllerConstant);
        break;
      case JoystickDirection.right:
        player.position += Vector2(_joystickControllerConstant, 0);
        break;
      case JoystickDirection.downRight:
        player.position +=
            Vector2(_joystickControllerConstant, _joystickControllerConstant);
        break;
      case JoystickDirection.down:
        player.position += Vector2(0, _joystickControllerConstant);
        break;
      case JoystickDirection.downLeft:
        player.position +=
            Vector2(-_joystickControllerConstant, _joystickControllerConstant);
        break;
      default:
        player.position += Vector2(0, 0);
        break;
    }

    switch (joystickRight.direction) {
      case JoystickDirection.left:
        player.position += Vector2(-_joystickControllerConstant, 0);
        break;
      case JoystickDirection.upLeft:
        player.position +=
            Vector2(-_joystickControllerConstant, -_joystickControllerConstant);
        break;
      case JoystickDirection.up:
        player.position += Vector2(0, -_joystickControllerConstant);
        break;
      case JoystickDirection.upRight:
        player.position +=
            Vector2(_joystickControllerConstant, -_joystickControllerConstant);
        break;
      case JoystickDirection.right:
        player.position += Vector2(_joystickControllerConstant, 0);
        break;
      case JoystickDirection.downRight:
        player.position +=
            Vector2(_joystickControllerConstant, _joystickControllerConstant);
        break;
      case JoystickDirection.down:
        player.position += Vector2(0, _joystickControllerConstant);
        break;
      case JoystickDirection.downLeft:
        player.position +=
            Vector2(-_joystickControllerConstant, _joystickControllerConstant);
        break;
      default:
        player.position += Vector2(0, 0);
        break;
    }
    player.position += joystickLeft.relativeDelta + joystickRight.relativeDelta;
  }

  void calcBulletCount() {
    bulletCount = children.whereType<BulletEasy>().length +
        children.whereType<BulletMid>().length +
        children.whereType<BulletHard>().length;
  }

  void updateKeys() {
    if (isGameOver) {
      return;
    }
    if (pressedKeySets.contains(LogicalKeyboardKey.arrowUp) ||
        pressedKeySets.contains(LogicalKeyboardKey.keyW)) {
      player.position += Vector2(0, -_keyControllerConstant);
    }
    if (pressedKeySets.contains(LogicalKeyboardKey.arrowDown) ||
        pressedKeySets.contains(LogicalKeyboardKey.keyS)) {
      player.position += Vector2(0, _keyControllerConstant);
    }
    if (pressedKeySets.contains(LogicalKeyboardKey.arrowLeft) ||
        pressedKeySets.contains(LogicalKeyboardKey.keyA)) {
      player.position += Vector2(-_keyControllerConstant, 0);
    }
    if (pressedKeySets.contains(LogicalKeyboardKey.arrowRight) ||
        pressedKeySets.contains(LogicalKeyboardKey.keyD)) {
      player.position += Vector2(_keyControllerConstant, 0);
    }
  }
}
