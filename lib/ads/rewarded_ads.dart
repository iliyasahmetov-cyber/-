// Platform-agnostic rewarded-ads facade.
//
// NOTE: real Google AdMob (google_mobile_ads) integration is temporarily
// disabled because google_mobile_ads 9.0.0 crashed at launch on-device with the
// current toolchain (AGP 9 / compileSdk 36). The app uses the simulated ad
// experience everywhere until real ads are re-added with a compatible setup.
// The AdMob implementation is preserved in git history and can be restored via
// a conditional import: `if (dart.library.io) 'rewarded_ads_admob.dart'`.
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
