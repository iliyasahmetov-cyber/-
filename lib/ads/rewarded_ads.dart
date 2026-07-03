// Platform-agnostic rewarded-ads facade.
//
// Real Google AdMob only works on Android/iOS (the plugin uses `dart:io`), so
// we pick the implementation via a conditional import: the AdMob-backed one on
// mobile, and a no-op stub everywhere else (e.g. Flutter web, used for local
// testing). Callers use [rewardedAds] and never import the plugin directly.
//
// IMPORTANT (crash-safety): the AdMob SDK is NOT touched at app startup — the
// auto-init ContentProvider is removed in AndroidManifest.xml and the SDK is
// initialised lazily, inside try/catch, only when the first ad is requested.
// If anything goes wrong the app still runs and falls back to the simulated ad.
// AdMob temporarily disabled (google_mobile_ads crashed at launch on-device
// with this toolchain and can't be verified without a device). Simulation only.
import 'rewarded_ads_none.dart';

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
