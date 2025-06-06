import 'package:firebase_core/firebase_core.dart';
import 'package:flame/flame.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training999/firebase_options.dart';
import 'package:training999/training_999.dart';
import 'package:training999/util/my_provider_observer.dart';
import 'package:training999/widget/enter_name_widget.dart';
import 'package:training999/widget/ranking_list_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();

  var game = Training999();
  runApp(ProviderScope(
    observers: [MyProviderObserver()],
    child: MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false, // 避免顯示鍵盤變更遊戲畫布大小(造成星星背景也被鍵盤推上去)
        body: RiverpodAwareGameWidget<Training999>(
          overlayBuilderMap: {
            'enter_name': (context, game) => const EnterNameWidget(),
            'rank': (context, game) {
              game.addBulletCountText();
              return RankingListWidget(
                voidCallback: () {
                  game.reset();
                  game.overlays.remove('rank');
                  game.router.pushNamed("menu");
                },
              );
            }
          },
          game: kDebugMode ? Training999() : game,
          key: GlobalKey(),
        ),
      ),
    ),
  ));
}
