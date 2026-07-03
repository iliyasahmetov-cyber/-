import 'package:flutter/material.dart';

import '../audio_manager.dart';
import '../localization.dart';
import '../sound_button.dart';
import '../theme.dart';
import '../tile_art.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = LocaleController.instance;
    // Listen directly so the menu rebuilds on language changes even though it
    // is provided as a (const) `home` widget.
    return AnimatedBuilder(
      animation: loc,
      builder: (context, _) => _buildMenu(context, loc),
    );
  }

  Widget _buildMenu(BuildContext context, LocaleController loc) {
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
          child: Stack(
            children: [
              // One tidy, centered block for every orientation; scrolls only if
              // the screen is too short.
              LayoutBuilder(
                builder: (context, c) {
                  final landscape = c.maxWidth > c.maxHeight;
                  final Widget inner = landscape
                      // Two columns, centered and kept close together so it is
                      // tidy (not scattered) AND everything — including the
                      // language toggle — fits without scrolling.
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(child: _branding(loc)),
                              const SizedBox(width: 28),
                              Flexible(child: _controls(context, loc)),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _branding(loc),
                            const SizedBox(height: 24),
                            _controls(context, loc),
                          ],
                        );
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                        child: Center(child: inner),
                      ),
                    ),
                  );
                },
              ),
              const Positioned(
                top: 6,
                right: 10,
                child: SoundToggleButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branding(LocaleController loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LogoTiles(),
        const SizedBox(height: 16),
        Text(
          loc.t('appTitle'),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc.t('appSubtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, LocaleController loc) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuButton(
            icon: Icons.play_arrow_rounded,
            label: loc.t('play'),
            primary: true,
            onTap: () {
              // First user gesture → safe to start audio on web.
              AudioManager.instance.startAmbient();
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
          const SizedBox(height: 24),
          const _LanguageToggle(),
        ],
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
      height: 58,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SizedBox(
                width: 52,
                height: 58,
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
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? AppTheme.accent : AppTheme.surfaceHigh,
          foregroundColor: primary ? Colors.black87 : AppTheme.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 22),
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
