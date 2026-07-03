import 'dart:async';

import 'package:flutter/material.dart';

import 'ads/rewarded_ads.dart';
import 'localization.dart';
import 'theme.dart';

/// Reason a rewarded ad is being offered — controls the prompt copy.
enum AdRewardKind { extraTime, hint }

/// Simulated AdMob Rewarded Video manager.
///
/// This does not talk to a real ad network; it reproduces the *UX contract* of
/// a rewarded video: an opt-in prompt, a non-skippable ~30 second playback with
/// a live countdown, and a reward callback that only fires once the video has
/// finished. Swap [_playSimulatedVideo] for the real AdMob SDK later.
class AdManager {
  AdManager({this.duration = const Duration(seconds: 30)});

  /// Length of the simulated rewarded video. Real AdMob rewarded ads are
  /// typically ~15-30s; the spec calls for 30 seconds.
  final Duration duration;

  final LocaleController _loc = LocaleController.instance;

  /// Offer a rewarded video for the given [kind].
  ///
  /// Returns `true` only if the user opted in **and** watched the full video
  /// (reward earned). Returns `false` if they declined.
  Future<bool> offerRewardedVideo(
    BuildContext context,
    AdRewardKind kind,
  ) async {
    // Opt-in prompt first (required for rewarded ads).
    final accepted = await _showPrompt(context, kind);
    if (accepted != true) return false;
    if (!context.mounted) return false;

    // Real AdMob on Android/iOS; simulated elsewhere or when no ad is loaded.
    if (rewardedAds.isSupported) {
      final rk = kind == AdRewardKind.hint ? RewardedKind.hint : RewardedKind.time;
      final result = await rewardedAds.show(rk);
      if (result == RewardedResult.earned) return true;
      if (result == RewardedResult.dismissed) return false;
      // unavailable (no fill / not loaded yet) → show why (diagnostic), then
      // fall back to the simulated ad so play continues.
      if (!context.mounted) return false;
      await _showAdDiagnostic(context, rewardedAds.lastError);
      if (!context.mounted) return false;
      await _playSimulatedVideo(context);
      return true;
    }

    await _playSimulatedVideo(context);
    return true;
  }

  /// Temporary on-screen diagnostic: shows why a real ad could not be shown
  /// (there is no logcat access in the build environment). Safe to remove once
  /// real ads are confirmed working.
  Future<void> _showAdDiagnostic(BuildContext context, String? error) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ad debug',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          error == null
              ? 'No ad loaded yet (no error reported). Showing simulated ad.'
              : 'Real ad not shown.\n\n$error',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPrompt(BuildContext context, AdRewardKind kind) {
    final titleKey = switch (kind) {
      AdRewardKind.hint => 'hint',
      AdRewardKind.extraTime => 'adTimeUpTitle',
    };
    final promptKey =
        kind == AdRewardKind.hint ? 'adHintPrompt' : 'adRewardPrompt';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimatedBuilder(
        animation: _loc,
        builder: (ctx, _) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(Icons.smart_display_outlined,
                  color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _loc.t(titleKey),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loc.t(promptKey),
                style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                _loc.t('adSkipInfo'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                _loc.t('noThanks'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_loc.t('watchVideo')),
            ),
          ],
        ),
      ),
    );
  }

  /// Blocking, non-skippable countdown overlay standing in for the video.
  Future<void> _playSimulatedVideo(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdPlaybackOverlay(duration: duration, loc: _loc),
    );
  }
}

class _AdPlaybackOverlay extends StatefulWidget {
  const _AdPlaybackOverlay({required this.duration, required this.loc});

  final Duration duration;
  final LocaleController loc;

  @override
  State<_AdPlaybackOverlay> createState() => _AdPlaybackOverlayState();
}

class _AdPlaybackOverlayState extends State<_AdPlaybackOverlay> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        t.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inSeconds;
    final progress = total == 0 ? 1.0 : (total - _remaining) / total;
    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF10141A),
        child: AnimatedBuilder(
          animation: widget.loc,
          builder: (context, _) => Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.ondemand_video_rounded,
                  size: 96,
                  color: Color(0x33FFFFFF),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AdMob • Ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 120),
                    Text(
                      widget.loc.tp('adWatching', {'n': _remaining.clamp(0, total)}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.loc.t('adSkipInfo'),
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
