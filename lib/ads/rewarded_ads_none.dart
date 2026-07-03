import 'rewarded_ads.dart';

/// No-op implementation used on platforms without AdMob (e.g. web). Callers
/// fall back to the simulated ad experience when [isSupported] is false.
RewardedAds createRewardedAdsImpl() => _NoneRewardedAds();

class _NoneRewardedAds implements RewardedAds {
  @override
  bool get isSupported => false;

  @override
  String? get lastError => null;

  @override
  Future<void> init() async {}

  @override
  bool isReady(RewardedKind kind) => false;

  @override
  Future<bool> waitForReady(RewardedKind kind, Duration timeout) async =>
      false;

  @override
  Future<RewardedResult> show(RewardedKind kind) async =>
      RewardedResult.unavailable;
}
