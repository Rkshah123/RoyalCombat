import 'dart:async';

import 'dart:math' as math;

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'settings_manager.dart';

/// All game sound effects.
///
/// [Sfx.uiTap] and [Sfx.exitWarning] have no bundled asset: they are tiny
/// waveforms synthesized in memory at runtime (see [SoundManager]), so the
/// app's click feedback is not tied to an audio file at all.
///
/// Note: there is no dedicated "elimination" recording bundled with the game,
/// so [Sfx.elimination] reuses the existing capture recording, played slower
/// (deeper) and louder to read as a distinct "player down" sting instead of an
/// ordinary piece capture.
enum Sfx {
  move('audio/move.wav'),
  capture('audio/capture.wav'),
  // Distinct elimination sting: capture.wav at a lower playback rate.
  elimination('audio/capture.wav'),
  check('audio/check.wav'),
  victory('audio/victory.wav'),
  defeat('audio/defeat.wav'),
  // Synthesized UI click — played from generated PCM, never from a file.
  uiTap(null),
  popWindow('audio/popwindow.wav'),
  // Synthesized warning sting for exiting an ongoing match.
  exitWarning(null),
  starting('audio/starting.wav');

  final String? asset;

  const Sfx(this.asset);
}

/// Plays the bundled sound effects, honouring the user's sound preference.
///
/// Performance design (no lag, no dropped clicks):
/// - ONE [AudioPlayer] per effect, created lazily and **reused forever**.
///   Nothing is created or disposed per click — the heavy native player
///   churn that caused frame drops is gone.
/// - Every play first stops the player, so rapid repeats never overlap and
///   never get debounced away: EVERY click sounds, no matter how fast the
///   user clicks.
///
/// The manager is [bind] to the live [SettingsManager] at startup, so the
/// global Sound ON/OFF toggle takes effect immediately on every screen, panel
/// and gameplay state — sounds already playing are stopped, and nothing new
/// can start while the setting is OFF. Nothing bypasses the setting: every
/// effect goes through [play].
class SoundManager {
  static final SoundManager instance = SoundManager._();

  SoundManager._();

  SettingsManager? _settings;
  bool _muted = false;

  /// Persistent player per effect (at most one per [Sfx], reused forever).
  final Map<Sfx, AudioPlayer> _players = {};

  /// Cached synthesized waveforms (built once, reused for every play).
  Uint8List? _clickWavCache;
  Uint8List? _warningWavCache;

  /// Desktop speakers reproduce a click differently (and quieter) than phone
  /// speakers, so the desktop build uses a hotter, fuller click variant.
  static bool get _isDesktop =>
      const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
          .contains(defaultTargetPlatform);

  bool get muted => !_enabled;

  /// Whether any sound may currently be played. The bound settings are the
  /// single source of truth; the cached [_muted] flag covers the un-bound
  /// legacy path.
  bool get _enabled {
    final settings = _settings;
    if (settings != null) return settings.soundEnabled;
    return !_muted;
  }

  /// Connects the manager to the live settings object. Called once at app
  /// startup; afterwards every Sound ON/OFF toggle is picked up instantly.
  void bind(SettingsManager settings) {
    if (identical(_settings, settings)) return;
    _settings?.removeListener(_onSettingsChanged);
    _settings = settings;
    settings.addListener(_onSettingsChanged);
    _onSettingsChanged();
  }

  void _onSettingsChanged() {
    final settings = _settings;
    if (settings == null) return;
    _muted = settings.soundEnabled == false;
    if (_muted) _stopAllNow();
  }

  /// Legacy one-shot sync used by older call sites. With [bind] in place this
  /// is a no-op (the listener already keeps the state fresh); without a bound
  /// settings object it still honours the current preference.
  void updateFromSettings(BuildContext context) {
    if (_settings != null) return;
    _muted = context.read<SettingsManager>().soundEnabled == false;
    if (_muted) _stopAllNow();
  }

  /// Immediately silences everything that is currently playing.
  /// Players are stopped but kept alive, ready for the next instant play.
  void _stopAllNow() {
    for (final player in _players.values) {
      unawaited(() async {
        try {
          await player.stop();
        } catch (_) {}
      }());
    }
  }

  /// Initializes the click player once at startup (silent), so the very first
  /// real click does not pay the native-player creation cost.
  Future<void> warmUp() async {
    try {
      final player = _players.putIfAbsent(Sfx.uiTap, () => AudioPlayer());
      await player.setVolume(0);
      await player.play(BytesSource(_synthBytes(Sfx.uiTap)));
      unawaited(player.stop());
    } catch (_) {
      // Warming up is best-effort only.
    }
  }

  Future<void> play(
    Sfx sfx, {
    double volume = 1.0,
    double rate = 1.0,
  }) async {
    if (!_enabled) return;
    try {
      final player = _players.putIfAbsent(sfx, () => AudioPlayer());
      // Cut whatever this player is still doing, then play fresh: rapid
      // repeats are always clean and always audible (no debouncing).
      await player.stop();
      await player.setVolume(volume);
      final source = sfx.asset != null
          ? AssetSource(sfx.asset!)
          : BytesSource(_synthBytes(sfx));
      await player.play(source);
      if (rate != 1.0) {
        // Applied after play() so it is not reset by loading the source.
        unawaited(player.setPlaybackRate(rate));
      }
    } catch (e) {
      // Sound output is never allowed to break gameplay.
      if (sfx == Sfx.uiTap) {
        // Fallback that is also not an audio file: the OS's own UI click.
        try {
          await SystemSound.play(SystemSoundType.click);
        } catch (_) {
          debugPrint('SoundManager synth click failed: $e');
        }
      } else {
        debugPrint('SoundManager.play failed: $e');
      }
    }
  }

  /// Resolves the in-memory waveform for a synthesized effect (built once).
  Uint8List _synthBytes(Sfx sfx) {
    switch (sfx) {
      case Sfx.exitWarning:
        return _warningWavCache ??= _buildWarningWav();
      case Sfx.uiTap:
      default:
        return _clickWavCache ??= _buildClickWav(boosted: _isDesktop);
    }
  }

  /// The universal UI control sound: buttons, settings, chips, switches.
  void tap() => play(Sfx.uiTap, volume: _isDesktop ? 1.0 : 0.8);

  /// Warns that a match is still ongoing while the user tries to leave it.
  void exitWarning() => play(Sfx.exitWarning, volume: 0.8);

  // ------------------------------------------------------- synthesis ----

  /// A rich mechanical UI click, ~30 ms: a narrowband noise "tick" ring-
  /// modulated around 3 kHz (the metal contact transient), a woody 1.4 kHz
  /// body and a subtle low thump for weight — crisp and satisfying, never a
  /// tonal beep. 44.1 kHz mono 16-bit.
  ///
  /// [boosted] (desktop only) raises the energy — full-volume body and a
  /// slightly longer tail — because desktop playback reads noticeably
  /// quieter than a phone speaker with the identical waveform. Mobile keeps
  /// the exact original mix.
  @visibleForTesting
  Uint8List buildClickWav({bool boosted = false}) =>
      _buildClickWav(boosted: boosted);

  /// A two-beep 880 Hz caution sting (~0.31 s) signalling that a live match
  /// would be abandoned.
  @visibleForTesting
  Uint8List buildWarningWav() => _buildWarningWav();

  Uint8List _buildClickWav({bool boosted = false}) {
    const sampleRate = 44100;
    // Mobile mix (perfect per user testing) vs hotter desktop mix.
    final lengthMs = boosted ? 38 : 30;
    final tickGain = boosted ? 0.62 : 0.55;
    final tickTau = boosted ? 0.0014 : 0.0012;
    final bodyGain = boosted ? 0.50 : 0.38;
    final bodyTau = boosted ? 0.0035 : 0.0028;
    final thumpGain = boosted ? 0.20 : 0.16;
    final count = sampleRate * lengthMs ~/ 1000;
    final samples = Float32List(count);
    final noise = math.Random(7); // deterministic, still broadband
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      // 1) Metal contact transient: broadband noise ring-modulated around
      //    3.2 kHz — a narrowband "tick" instead of harsh hiss.
      final raw = noise.nextDouble() * 2 - 1;
      final tick = raw * math.sin(2 * math.pi * 3200 * t) *
          math.exp(-t / tickTau) *
          tickGain;
      // 2) Woody body: fast-decaying mid sine gives the click weight.
      final body = math.sin(2 * math.pi * 1450 * t) *
          math.exp(-t / bodyTau) *
          bodyGain;
      // 3) Subtle low thump so phone speakers still carry it.
      final thump = math.sin(2 * math.pi * 480 * t) *
          math.exp(-t / 0.006) *
          thumpGain;
      var value = tick + body + thump;
      // Hard attack at the very first sample.
      if (i == 0) value += 0.30;
      // Smooth tail so the clip ends in silence (no cut-off click).
      final fade = (i / count) < 0.85
          ? 1.0
          : 1.0 - ((i / count) - 0.85) / 0.15;
      samples[i] = (value * fade).clamp(-1.0, 1.0);
    }
    return _encodeWavPcm16(samples);
  }

  Uint8List _buildWarningWav() {
    const sampleRate = 44100;
    const beeps = [(0.0, 0.12), (0.19, 0.31)];
    final count = (sampleRate * (beeps.last.$2 + 0.03)).round();
    final samples = Float32List(count);
    for (final (start, end) in beeps) {
      final i0 = (start * sampleRate).round();
      final i1 = (end * sampleRate).round();
      final span = i1 - i0;
      for (var i = i0; i < i1; i++) {
        final t = (i - i0) / sampleRate;
        final p = (i - i0) / span;
        // Gentle attack, full sustain, quick release — no harsh clicks.
        final envelope =
            p < 0.08 ? p / 0.08 : (p > 0.85 ? (1 - p) / 0.15 : 1.0);
        samples[i] += (math.sin(2 * math.pi * 880 * t) * 0.55 +
                math.sin(2 * math.pi * 1760 * t) * 0.22) *
            envelope;
      }
    }
    for (var i = 0; i < count; i++) {
      samples[i] = samples[i].clamp(-1.0, 1.0);
    }
    return _encodeWavPcm16(samples);
  }

  /// Encodes float samples (-1..1) as a 44.1 kHz mono 16-bit PCM WAV blob.
  Uint8List _encodeWavPcm16(Float32List samples) {
    const sampleRate = 44100;
    final count = samples.length;
    final data = ByteData(count * 2);
    for (var i = 0; i < count; i++) {
      data.setInt16(i * 2, (samples[i] * 32767).round(), Endian.little);
    }
    final out = Uint8List(44 + count * 2);
    final view = ByteData.view(out.buffer);

    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        out[offset + i] = text.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    view.setUint32(4, 36 + count * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little); // PCM chunk size
    view.setUint16(20, 1, Endian.little); // PCM format
    view.setUint16(22, 1, Endian.little); // mono
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    view.setUint16(32, 2, Endian.little); // block align
    view.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    view.setUint32(40, count * 2, Endian.little);
    out.setAll(44, data.buffer.asUint8List());
    return out;
  }
}
