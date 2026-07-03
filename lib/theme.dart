import 'package:flutter/material.dart';

/// Calming, understated palette aimed at adults and seniors: muted slate and
/// blue-grey oak tones, warm off-white text and a single restrained amber
/// accent. Nothing bright or childish — low saturation to avoid eye strain.
class AppTheme {
  static const Color background = Color(0xFF1B2128);
  static const Color backgroundAlt = Color(0xFF232B34);
  static const Color surface = Color(0xFF2A333D);
  static const Color surfaceHigh = Color(0xFF334049);

  static const Color textPrimary = Color(0xFFE9E3D6);
  static const Color textSecondary = Color(0xFF9AA6B1);

  static const Color accent = Color(0xFFC29A5B); // muted antique amber
  static const Color accentSoft = Color(0xFF7C8B7A); // muted sage

  // Tile face (polished blue-grey oak / slate).
  static const Color tileTop = Color(0xFF48586A);
  static const Color tileBottom = Color(0xFF35414F);
  static const Color tileEdgeLight = Color(0xFF5C6E82);
  static const Color tileEdgeDark = Color(0xFF232C36);

  static const Color tileSelected = Color(0xFFC29A5B);
  static const Color tileHint = Color(0xFF7FA8A0);

  static ThemeData themeData() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accentSoft,
        surface: surface,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
            fontFamily: 'serif',
          ),
    );
  }
}
