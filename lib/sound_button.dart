import 'package:flutter/material.dart';

import 'audio_manager.dart';
import 'theme.dart';

/// Small mute/unmute toggle used on the menu and in-game.
class SoundToggleButton extends StatelessWidget {
  const SoundToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.instance;
    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.surfaceHigh),
          ),
          child: IconButton(
            tooltip: audio.muted ? 'Sound off' : 'Sound on',
            onPressed: audio.toggleMute,
            icon: Icon(
              audio.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: audio.muted ? AppTheme.textSecondary : AppTheme.accent,
            ),
          ),
        );
      },
    );
  }
}
