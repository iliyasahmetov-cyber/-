import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio_manager.dart';
import 'localization.dart';
import 'screens/main_menu.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  AudioManager.instance.init();
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
