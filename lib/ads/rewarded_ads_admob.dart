import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_config.dart';
import 'rewarded_ads.dart';

RewardedAds createRewardedAdsImpl() => _AdMobRewardedAds();

/// Real AdMob rewarded ads for Android/iOS.
///
/// - Time reward → a standard Rewarded video (`timeRewardUnitId`).
/// - Hint → a Rewarded *Interstitial* (`hintRewardUnitId`).
///
/// Crash-safety: the SDK is initialised **lazily** (never at app startup) and
/// every SDK call is wrapped in try/catch. Combined with removing the auto-init
/// ContentProvider in the manifest, the app launches even if ads misbehave.
class _AdMobRewardedAds implements RewardedAds {
  RewardedAd? _timeAd;
  RewardedInterstitialAd? _hintAd;
  bool _initDone = false;
  String? _lastError;

  /// Shared init future so concurrent callers (startup + first ad) all wait for
  /// the same MobileAds.initialise() instead of bailing out early.
  Future<void>? _initFuture;

  static const _loadTimeout = Duration(seconds: 15);

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  String? get lastError => _lastError;

  /// Called at app startup: initialise and start preloading so ads are ready
  /// by the time the player opens one.
  @override
  Future<void> init() async {
    await _ensureInit();
  }

  Future<void> _ensureInit() async {
    if (_initDone || !isSupported) return;
    _initFuture ??= _runInit();
    await _initFuture;
  }

  Future<void> _runInit() async {
    try {
      await MobileAds.instance.initialize();
      _initDone = true;
      _loadTime();
      _loadHint();
    } catch (e) {
      _initFuture = null; // allow a retry on next show
      _lastError = 'init: $e';
    }
  }

  void _loadTime() {
    try {
      RewardedAd.load(
        adUnitId: AdConfig.timeRewardUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _timeAd = ad,
          onAdFailedToLoad: (err) {
            _timeAd = null;
            _lastError = 'time load: ${err.code} ${err.message}';
          },
        ),
      );
    } catch (e) {
      _lastError = 'time load ex: $e';
    }
  }

  void _loadHint() {
    try {
      RewardedInterstitialAd.load(
        adUnitId: AdConfig.hintRewardUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) => _hintAd = ad,
          onAdFailedToLoad: (err) {
            _hintAd = null;
            _lastError = 'hint load: ${err.code} ${err.message}';
          },
        ),
      );
    } catch (e) {
      _lastError = 'hint load ex: $e';
    }
  }

  /// Poll until the requested ad has loaded, or the timeout elapses.
  Future<void> _waitUntilLoaded(RewardedKind kind, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    bool loaded() =>
        kind == RewardedKind.time ? _timeAd != null : _hintAd != null;
    while (!loaded() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  String _kindLabel(RewardedKind kind) =>
      kind == RewardedKind.time ? 'time rewarded' : 'hint rewarded interstitial';

  @override
  Future<RewardedResult> show(RewardedKind kind) async {
    if (!isSupported) return RewardedResult.unavailable;
    await _ensureInit();
    if (!_initDone) {
      _lastError ??= 'AdMob init did not complete';
      return RewardedResult.unavailable;
    }

    // Give the ad a chance to finish loading before falling back.
    await _waitUntilLoaded(kind, _loadTimeout);

    final completer = Completer<RewardedResult>();

    try {
      if (kind == RewardedKind.time) {
        final ad = _timeAd;
        _timeAd = null;
        if (ad == null) {
          _loadTime();
          _lastError ??=
              '${_kindLabel(kind)}: not loaded after ${_loadTimeout.inSeconds}s';
          return RewardedResult.unavailable;
        }
        _showTimeAd(ad, completer);
      } else {
        final ad = _hintAd;
        _hintAd = null;
        if (ad == null) {
          _loadHint();
          _lastError ??=
              '${_kindLabel(kind)}: not loaded after ${_loadTimeout.inSeconds}s';
          return RewardedResult.unavailable;
        }
        _showHintAd(ad, completer);
      }
    } catch (e) {
      _lastError = 'show ex: $e';
      return RewardedResult.unavailable;
    }
    return completer.future;
  }

  void _showTimeAd(RewardedAd ad, Completer<RewardedResult> completer) {
    var earned = false;
    void done(RewardedResult r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadTime();
        done(earned ? RewardedResult.earned : RewardedResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadTime();
        _lastError = 'show failed: ${e.code} ${e.message}';
        done(RewardedResult.unavailable);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
  }

  void _showHintAd(
    RewardedInterstitialAd ad,
    Completer<RewardedResult> completer,
  ) {
    var earned = false;
    void done(RewardedResult r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    ad.fullScreenContentCallback =
        FullScreenContentCallback<RewardedInterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadHint();
        done(earned ? RewardedResult.earned : RewardedResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadHint();
        _lastError = 'show failed: ${e.code} ${e.message}';
        done(RewardedResult.unavailable);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
  }
}
