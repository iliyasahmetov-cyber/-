# Pao Pao (Onet Connect)

A bilingual (RU/EN) Flutter puzzle game — classic "connect two identical tiles"
gameplay aimed at adults and seniors. Targets Android, iOS and web.

## Project layout

```
lib/
  main.dart            # app entry, MaterialApp + root locale rebuild
  game_engine.dart     # 8x12 board matrix, scoring, lives, timer, deadlock shuffle
  path_finder.dart     # modified 0-1 BFS, max 2 turns, routes around outer border
  localization.dart    # rigid RU/EN string table + LocaleController (ChangeNotifier)
  ad_manager.dart      # simulated AdMob rewarded-video (30s) prompts + playback
  theme.dart           # muted slate / blue-grey palette
  tile_art.dart        # CustomPainter tiles + 12 vector glyphs (no image assets)
  screens/
    main_menu.dart
    game_screen.dart
test/widget_test.dart  # pathfinder + engine unit tests
```

## Standard commands

Flutter SDK is installed at `~/flutter` and is on `PATH` via `~/.bashrc`
(Flutter 3.44.x / Dart 3.12.x). Dependencies come from `pubspec.yaml`.

- Lint/analyze: `flutter analyze`
- Test: `flutter test`
- Run (web dev, for manual testing in the VM's Chrome):
  `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`
  then open `http://localhost:8080`. Press `R` in that terminal for hot restart.
- Build release: `flutter build apk` / `flutter build ios` / `flutter build web`.

## Cursor Cloud specific instructions

- The web dev server is the practical way to manually test here (Chrome is
  available; no Android/iOS emulator). Serve on `:8080` as above and drive it
  with the browser.
- Rewarded ads are **simulated**, not real AdMob. `AdManager.duration` defaults
  to 30s and the ad plays as a non-skippable countdown overlay. Both ad triggers
  (time-out / lives-out → `+1 life / +60s`, and the Hint button) go through
  `AdManager.offerRewardedVideo`.
- The countdown clock is **paused during any ad or modal dialog** (the game
  screen sets an internal `_busy` flag and calls `GameEngine.pause()`), so the
  timer does not drain while an ad plays.
- To manually exercise the "time is up" reward loop without waiting 3 minutes,
  temporarily construct the engine with a short clock in
  `screens/game_screen.dart` (`GameEngine(startSeconds: 15)`) and revert before
  committing.
- The Hint highlight (teal pulsing border) persists until the next tile tap —
  `GameEngine.select` clears it — so there is no auto-timeout to race against.
- Tiles are intentionally **structurally similar** (a design requirement), so
  automated/manual UI agents may struggle to eyeball identical pairs; use the
  **Hint** button to reveal a guaranteed-connectable pair for a reliable match.
- Localization gotcha: screens subscribe directly to `LocaleController` via
  `AnimatedBuilder`. This is deliberate — `main.dart` passes `MainMenuScreen` as
  a `const home`, and a const widget instance is skipped by the root rebuild, so
  each screen must listen to the locale itself to switch languages live.
- Board size is always the full 8×12 (96 tiles) on every level. Difficulty
  scales via number of distinct tile designs (`GameEngine.minTileTypes` →
  `maxTileTypes`) and a shrinking per-pair time budget — never by reducing the
  tile count. `tile_art.dart` must provide a glyph for every id up to
  `maxTileTypes` (currently 16) or higher levels would render duplicate shapes.
- Audio is optional/enhancement-only: `AudioManager` swallows errors so it can
  never break gameplay. Browsers block autoplay, so ambient starts on the first
  user gesture (the "Play" button). Regenerate the WAV assets with
  `python3 tool/generate_audio.py` (procedural, no third-party audio).

### Android / APK builds

- The Android SDK is installed at `~/android-sdk` (cmdline-tools + platform
  36/35, build-tools 36, NDK 28, CMake) and `ANDROID_HOME`/`PATH` are exported in
  `~/.bashrc`; `flutter config --android-sdk ~/android-sdk` has been run. JDK 21
  is the system Java. These persist via the VM snapshot and are NOT part of the
  update script (do not add SDK installation there).
- Build an installable APK: `flutter build apk --release`
  (output: `build/app/outputs/flutter-apk/app-release.apk`). Release is signed
  with the debug keystore (see `android/app/build.gradle.kts`) so it installs on
  a device; for Google Play upload, add a real release `signingConfig` /
  keystore and prefer `flutter build appbundle` (AAB).
- If the SDK is ever missing on a fresh VM, reinstall cmdline-tools from
  `https://developer.android.com/studio` (Linux command-line tools zip), run
  `sdkmanager --licenses`, then `flutter build apk` (Gradle auto-installs the
  matching platform/NDK/CMake).
