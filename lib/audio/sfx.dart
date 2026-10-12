/// Tiny SFX service over audioplayers: a round-robin pool for one-shots
/// plus one looping music player.
///
/// Players are created lazily so importing this file never touches platform
/// channels (unit tests run without a Flutter binding — audio just stays
/// silent there). Every call is guarded: audio must never crash the game.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class Sfx {
  static const _poolSize = 4;
  static List<AudioPlayer>? _pool;
  static int _next = 0;
  static AudioPlayer? _music;
  static bool _musicOn = false;

  /// Master toggles (settings screen).
  static bool sfxEnabled = true;
  static bool musicEnabled = true;

  /// Null when no Flutter binding exists (pure Dart unit tests) — audio
  /// stays silent there. WidgetsBinding.instance throws synchronously
  /// when uninitialized, which is catchable (unlike the async platform
  /// error AudioPlayer itself would raise).
  static Object? _probeBinding() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }

  static List<AudioPlayer>? _ensurePool() {
    if (_probeBinding() == null) return null;
    if (_pool != null) return _pool;
    try {
      _pool = List.generate(_poolSize, (_) => AudioPlayer());
    } catch (_) {
      _pool = null;
    }
    return _pool;
  }

  static Future<void> _play(String file, {double volume = 1.0}) async {
    if (!sfxEnabled) return;
    try {
      final pool = _ensurePool();
      if (pool == null) return;
      final p = pool[_next];
      _next = (_next + 1) % _poolSize;
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource(file));
    } catch (_) {
      // audio must never crash the game
    }
  }

  static void click() => _play('audio/click.wav', volume: 0.6);
  static void coin() => _play('audio/pop1.wav', volume: 0.5);
  static void upgrade() => _play('audio/unlock.wav');
  static void milestone() => _play('audio/star.wav');
  static void zoneUnlock() => _play('audio/chime.wav');
  static void rescue() => _play('audio/bark.wav');
  static void prestige() => _play('audio/win.wav');

  static Future<void> startMusic() async {
    if (_musicOn || !musicEnabled || _probeBinding() == null) return;
    _musicOn = true;
    try {
      _music ??= AudioPlayer();
      final m = _music;
      if (m == null) return;
      await m.setReleaseMode(ReleaseMode.loop);
      await m.setVolume(0.35);
      await m.play(AssetSource('audio/music_loop.wav'));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    _musicOn = false;
    try {
      await _music?.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    final pool = _pool;
    _pool = null;
    if (pool != null) {
      for (final p in pool) {
        try {
          await p.dispose();
        } catch (_) {}
      }
    }
    try {
      await _music?.dispose();
    } catch (_) {}
    _music = null;
  }
}
