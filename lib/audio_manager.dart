import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Handles the game's calming audio: a looping ambient pad plus soft
/// select/match chimes. All sounds are gentle by design (see
/// `tool/generate_audio.py`). Exposes a mute toggle and is a [ChangeNotifier]
/// so the sound button can reflect state.
///
/// Browsers block audio until the first user gesture, so [startAmbient] is
/// called when the player taps "Play".
class AudioManager extends ChangeNotifier {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _ambient = AudioPlayer(playerId: 'ambient');
  final AudioPlayer _sfx = AudioPlayer(playerId: 'sfx');

  bool _muted = false;
  bool _initialized = false;
  bool _ambientStarted = false;

  bool get muted => _muted;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.setVolume(0.5);
      await _sfx.setReleaseMode(ReleaseMode.release);
    } catch (_) {
      // Audio is a non-critical enhancement; never let it break gameplay.
    }
  }

  Future<void> startAmbient() async {
    if (_muted) return;
    await init();
    try {
      if (_ambientStarted) {
        await _ambient.resume();
      } else {
        _ambientStarted = true;
        await _ambient.play(AssetSource('audio/ambient.wav'), volume: 0.5);
      }
    } catch (_) {}
  }

  Future<void> stopAmbient() async {
    try {
      await _ambient.pause();
    } catch (_) {}
  }

  Future<void> playMatch() async {
    if (_muted) return;
    try {
      await _sfx.play(AssetSource('audio/match.wav'), volume: 0.6);
    } catch (_) {}
  }

  Future<void> playSelect() async {
    if (_muted) return;
    try {
      await _sfx.play(AssetSource('audio/select.wav'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) {
      await stopAmbient();
    } else {
      await startAmbient();
    }
    notifyListeners();
  }

  Future<void> toggleMute() => setMuted(!_muted);

  @override
  void dispose() {
    _ambient.dispose();
    _sfx.dispose();
    super.dispose();
  }
}
