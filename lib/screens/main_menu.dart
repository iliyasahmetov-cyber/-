import 'package:flutter/material.dart';

import '../localization.dart';
import '../theme.dart';
import '../tile_art.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = LocaleController.instance;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.backgroundAlt, AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _LogoTiles(),
                const SizedBox(height: 28),
                Text(
                  loc.t('appTitle'),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t('appSubtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Spacer(flex: 2),
                _MenuButton(
                  icon: Icons.play_arrow_rounded,
                  label: loc.t('play'),
                  primary: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GameScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _MenuButton(
                  icon: Icons.help_outline_rounded,
                  label: loc.t('howToPlay'),
                  onTap: () => _showHowTo(context, loc),
                ),
                const Spacer(flex: 2),
                const _LanguageToggle(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, LocaleController loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.t('howToPlay'),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          loc.t('howToPlayBody'),
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.t('resume')),
          ),
        ],
      ),
    );
  }
}

/// Four sample tiles arranged as a small logo, showcasing the muted art.
class _LogoTiles extends StatelessWidget {
  const _LogoTiles();

  @override
  Widget build(BuildContext context) {
    const ids = [1, 6, 9, 5];
    return SizedBox(
      height: 82,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 74,
                height: 82,
                child: CustomPaint(
                  painter: TilePainter(
                    tileId: id,
                    state: TileVisualState.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? AppTheme.accent : AppTheme.surfaceHigh,
          foregroundColor: primary ? Colors.black87 : AppTheme.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(label),
      ),
    );
  }
}

/// Clean "Language / Язык" segmented toggle. Switches the whole UI instantly.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final loc = LocaleController.instance;
    return Column(
      children: [
        Text(
          loc.t('languageToggle'),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.surfaceHigh),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _langChip('РУС', AppLanguage.ru, loc),
              _langChip('ENG', AppLanguage.en, loc),
            ],
          ),
        ),
      ],
    );
  }

  Widget _langChip(String label, AppLanguage lang, LocaleController loc) {
    final selected = loc.language == lang;
    return GestureDetector(
      onTap: () => loc.setLanguage(lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black87 : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
