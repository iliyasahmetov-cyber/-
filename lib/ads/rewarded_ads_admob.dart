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
  bool _initStarted = false;
  bool _initDone = false;

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> init() async {}

  Future<void> _ensureInit() async {
    if (_initDone || _initStarted || !isSupported) return;
    _initStarted = true;
    try {
      await MobileAds.instance.initialize();
      _initDone = true;
      _loadTime();
      _loadHint();
    } catch (_) {}
  }

  void _loadTime() {
    try {
      RewardedAd.load(
        adUnitId: AdConfig.timeRewardUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _timeAd = ad,
          onAdFailedToLoad: (_) => _timeAd = null,
        ),
      );
    } catch (_) {}
  }

  void _loadHint() {
    try {
      RewardedInterstitialAd.load(
        adUnitId: AdConfig.hintRewardUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) => _hintAd = ad,
          onAdFailedToLoad: (_) => _hintAd = null,
        ),
      );
    } catch (_) {}
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

  @override
  Future<RewardedResult> show(RewardedKind kind) async {
    if (!isSupported) return RewardedResult.unavailable;
    await _ensureInit();
    if (!_initDone) return RewardedResult.unavailable;

    // First request right after init: give the ad a chance to finish loading
    // before falling back to the simulated ad.
    await _waitUntilLoaded(kind, const Duration(seconds: 8));

    final completer = Completer<RewardedResult>();
    var earned = false;

    void done(RewardedResult r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    void attach(dynamic ad, void Function() reload) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (dynamic a) {
          a.dispose();
          reload();
          done(earned ? RewardedResult.earned : RewardedResult.dismissed);
        },
        onAdFailedToShowFullScreenContent: (dynamic a, dynamic e) {
          a.dispose();
          reload();
          done(RewardedResult.unavailable);
        },
      );
      ad.show(
        onUserEarnedReward: (dynamic a, dynamic reward) => earned = true,
      );
    }

    try {
      if (kind == RewardedKind.time) {
        final ad = _timeAd;
        _timeAd = null;
        if (ad == null) {
          _loadTime();
          return RewardedResult.unavailable;
        }
        attach(ad, _loadTime);
      } else {
        final ad = _hintAd;
        _hintAd = null;
        if (ad == null) {
          _loadHint();
          return RewardedResult.unavailable;
        }
        attach(ad, _loadHint);
      }
    } catch (_) {
      return RewardedResult.unavailable;
    }
    return completer.future;
  }
}
