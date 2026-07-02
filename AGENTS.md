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
