import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/rewarded_ads.dart';
import 'audio_manager.dart';
import 'localization.dart';
import 'screens/main_menu.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape gameplay: the 12×8 board is wider than tall, so tiles are larger.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Hide Android status + navigation bars; swipe from edge to reveal.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  AudioManager.instance.init();
  // Start AdMob init + preload in the background — menu opens instantly.
  rewardedAds.init();
  runApp(const PaoPaoApp());
}

class PaoPaoApp extends StatelessWidget {
  const PaoPaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the entire tree when the language changes so every label
    // (Play, Score, Time, ads, Game Over…) switches dynamically.
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Pao Pao',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData(),
          home: const MainMenuScreen(),
        );
      },
    );
  }
}
