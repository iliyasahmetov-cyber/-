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
/// Ads are preloaded and re-loaded after each show. If nothing is loaded yet
/// (no fill, or a freshly created ad unit that has not started serving), [show]
/// returns [RewardedResult.unavailable] and the caller falls back gracefully.
class _AdMobRewardedAds implements RewardedAds {
  RewardedAd? _timeAd;
  RewardedInterstitialAd? _hintAd;
  bool _initialized = false;

  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      _loadTime();
      _loadHint();
    } catch (_) {
      // Never let ad setup crash the game.
    }
  }

  void _loadTime() {
    RewardedAd.load(
      adUnitId: AdConfig.timeRewardUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _timeAd = ad,
        onAdFailedToLoad: (_) => _timeAd = null,
      ),
    );
  }

  void _loadHint() {
    RewardedInterstitialAd.load(
      adUnitId: AdConfig.hintRewardUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) => _hintAd = ad,
        onAdFailedToLoad: (_) => _hintAd = null,
      ),
    );
  }

  @override
  Future<RewardedResult> show(RewardedKind kind) async {
    if (!isSupported) return RewardedResult.unavailable;
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
