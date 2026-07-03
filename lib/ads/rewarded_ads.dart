// Platform-agnostic rewarded-ads facade.
//
// Real Google AdMob only works on Android/iOS (the plugin uses `dart:io`), so
// we pick the implementation via a conditional import: the AdMob-backed one on
// mobile, and a no-op stub everywhere else (e.g. Flutter web, used for local
// testing). Callers use [rewardedAds] and never import the plugin directly.
import 'rewarded_ads_none.dart'
    if (dart.library.io) 'rewarded_ads_admob.dart';

enum RewardedKind { time, hint }

enum RewardedResult {
  /// The full video was watched and the reward was granted.
  earned,

  /// The ad was shown but closed before the reward was earned.
  dismissed,

  /// No ad was available/loaded (or the platform is unsupported).
  unavailable,
}

abstract class RewardedAds {
  /// Whether real rewarded ads are available on this platform.
  bool get isSupported;

  /// Initialise the SDK and start preloading ads.
  Future<void> init();

  /// Show a rewarded ad of [kind]. Reloads the next one automatically.
  Future<RewardedResult> show(RewardedKind kind);
}

/// App-wide singleton, resolved to the correct platform implementation.
final RewardedAds rewardedAds = createRewardedAdsImpl();
