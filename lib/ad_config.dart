/// AdMob identifiers. Ad unit / app IDs are NOT secrets — they are embedded in
/// every shipped app — so keeping them in source is standard.
class AdConfig {
  /// When true, use Google's official **test** ad units (always fill instantly,
  /// show a "Test Ad" label). This is the recommended way to verify the AdMob
  /// integration during development.
  ///
  /// Set to `false` for production so the owner's real units are used. Real
  /// ads also require the owner's real App ID in AndroidManifest.xml / Info.plist.
  static const bool useTestAds = true;

  // --- Owner's real AdMob units ---
  static const String _timeRewardReal = 'ca-app-pub-6393368605159065/4256434610';
  static const String _hintRewardReal = 'ca-app-pub-6393368605159065/4840934148';

  // --- Google official TEST units ---
  static const String _rewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _rewardedInterstitialTest =
      'ca-app-pub-3940256099942544/5354046379';

  /// Rewarded video shown when time runs out (+60s).
  static String get timeRewardUnitId =>
      useTestAds ? _rewardedTest : _timeRewardReal;

  /// Rewarded *interstitial* used by the Hint button.
  static String get hintRewardUnitId =>
      useTestAds ? _rewardedInterstitialTest : _hintRewardReal;
}
