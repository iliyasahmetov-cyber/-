/// AdMob identifiers. Ad unit / app IDs are NOT secrets — they are embedded in
/// every shipped app — so keeping them in source is standard.
class AdConfig {
  /// AdMob **application** ID for Android (format `ca-app-pub-XXXX~YYYY`).
  ///
  /// TODO(owner): replace this Google TEST app id with your real AdMob App ID
  /// from AdMob → App settings (it starts with `ca-app-pub-6393368605159065~`).
  /// It must also be set in `android/app/src/main/AndroidManifest.xml`.
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Rewarded video shown when time runs out (+60s). Real unit provided by owner.
  static const String timeRewardUnitId =
      'ca-app-pub-6393368605159065/4256434610';

  /// Rewarded *interstitial* used by the Hint button. Real unit provided by owner.
  static const String hintRewardUnitId =
      'ca-app-pub-6393368605159065/4840934148';
}
