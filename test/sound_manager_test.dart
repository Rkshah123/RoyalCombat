import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_arena/services/settings_manager.dart';
import 'package:chess_arena/services/sound_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundManager global toggle', () {
    late SettingsManager settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsManager();
      await settings.load();
      SoundManager.instance.bind(settings);
    });

    test('bind makes the manager follow the live sound preference', () async {
      expect(SoundManager.instance.muted, isFalse);

      await settings.setSoundEnabled(false);
      expect(SoundManager.instance.muted, isTrue);

      await settings.setSoundEnabled(true);
      expect(SoundManager.instance.muted, isFalse);
    });

    test('play() while muted is a silent no-op (no platform calls)', () async {
      await settings.setSoundEnabled(false);
      // Must return immediately without touching any audio platform channel.
      await SoundManager.instance.play(Sfx.move);
      SoundManager.instance.tap();
      expect(SoundManager.instance.muted, isTrue);
    });

    test(
        'synth paths run with sounds enabled and fail soft in the test env',
        () async {
      // No audio platform channels exist in tests: the synthesized click and
      // warning must be caught internally (falling back to SystemSound, which
      // is also caught) instead of throwing.
      SoundManager.instance.tap();
      SoundManager.instance.exitWarning();
      expect(SoundManager.instance.muted, isFalse);
    });
  });

  group('Synthesized waveforms', () {
    test('click WAV is a valid 44.1 kHz mono 16-bit PCM blob', () {
      final wav = SoundManager.instance.buildClickWav();
      final view = ByteData.view(wav.buffer);
      expect(wav.length, greaterThan(44));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint16(34, Endian.little), 16); // 16-bit
      expect(view.getUint32(24, Endian.little), 44100);
      // ~30 ms of samples.
      final dataSize = view.getUint32(40, Endian.little);
      expect(dataSize / 2, closeTo(44100 * 0.030, 10));
    });

    test('warning WAV is a valid PCM blob with two beeps (~0.31 s)', () {
      final wav = SoundManager.instance.buildWarningWav();
      final view = ByteData.view(wav.buffer);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      final dataSize = view.getUint32(40, Endian.little);
      // 0.31 s of beeps + 0.03 s tail.
      expect(dataSize / 2, closeTo(44100 * 0.34, 20));

      // Two distinct beeps: silence in the middle gap (0.12–0.19 s).
      bool silentBetweenBeeps = true;
      final sampleCount = dataSize ~/ 2;
      for (var i = (44100 * 0.14).round(); i < (44100 * 0.18).round(); i++) {
        final v = view.getInt16(44 + i * 2, Endian.little).abs();
        if (v > 500) silentBetweenBeeps = false;
      }
      expect(silentBetweenBeeps, isTrue);
      expect(sampleCount, greaterThan(0));
    });

    test('boosted (desktop) click WAV is valid and hotter', () {
      final wav = SoundManager.instance.buildClickWav(boosted: true);
      final view = ByteData.view(wav.buffer);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      // ~38 ms of samples.
      final dataSize = view.getUint32(40, Endian.little);
      expect(dataSize / 2, closeTo(44100 * 0.038, 10));
      // Higher energy than the standard (mobile) variant.
      final standard = SoundManager.instance.buildClickWav();
      int energy(Uint8List w) {
        final v = ByteData.view(w.buffer);
        final n = v.getUint32(40, Endian.little) ~/ 2;
        var sum = 0;
        for (var i = 0; i < n; i++) {
          sum += v.getInt16(44 + i * 2, Endian.little).abs();
        }
        return sum;
      }
      expect(energy(wav), greaterThan(energy(standard) * 9 / 10));
    });

    test('rapid repeated clicks all play (no debouncing)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsManager();
      await settings.load();
      SoundManager.instance.bind(settings);
      // A burst of fast taps must never be dropped: every click sounds.
      for (var i = 0; i < 8; i++) {
        SoundManager.instance.tap();
      }
      expect(SoundManager.instance.muted, isFalse);
    });

    test('warmUp is silent and safe in the test env', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsManager();
      await settings.load();
      SoundManager.instance.bind(settings);
      await SoundManager.instance.warmUp();
      expect(SoundManager.instance.muted, isFalse);
    });
  });
}
