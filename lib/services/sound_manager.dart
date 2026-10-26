import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'settings_manager.dart';

/// All game sound effects.
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
  uiTap('audio/ui_tap.wav'),
  popWindow('audio/popwindow.wav'),
  starting('audio/starting.wav'),
  splashEnd('audio/splash_end.wav');

  final String asset;

  const Sfx(this.asset);

  /// Minimum gap between two plays of the same effect. Prevents overlapping
  /// or duplicated triggers of the same event (e.g. a double-tapped button).
  Duration get debounce {
    switch (this) {
      case Sfx.elimination:
      case Sfx.victory:
      case Sfx.defeat:
      case Sfx.starting:
        return const Duration(milliseconds: 600);
      case Sfx.check:
        return const Duration(milliseconds: 200);
      case Sfx.uiTap:
        return const Duration(milliseconds: 60);
      default:
        return const Duration(milliseconds: 90);
    }
  }
}

/// Plays the bundled sound effects, honouring the user's sound preference.
class SoundManager {
  static final SoundManager instance = SoundManager._();

  SoundManager._();

  bool _muted = false;
  final Map<Sfx, DateTime> _lastPlayed = {};

  bool get muted => _muted;

  void updateFromSettings(BuildContext context) {
    _muted = context.read<SettingsManager>().soundEnabled == false;
  }

  Future<void> play(
    Sfx sfx, {
    double volume = 1.0,
    double rate = 1.0,
  }) async {
    if (_muted) return;
    // Drop duplicates: the same effect fired twice in quick succession would
    // overlap and sound like a glitch instead of one clean sting.
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last) < sfx.debounce) return;
    _lastPlayed[sfx] = now;
    try {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.release);
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
      await player.play(AssetSource(sfx.asset), volume: volume);
      if (rate != 1.0) {
        // Applied after play() so it is not reset by loading the source.
        unawaited(player.setPlaybackRate(rate));
      }
    } catch (e) {
      // Sound output is never allowed to break gameplay.
      debugPrint('SoundManager.play failed: $e');
    }
  }

  /// The universal UI control sound: buttons, settings, chips, switches.
  void tap() => play(Sfx.uiTap, volume: 0.65);
}
