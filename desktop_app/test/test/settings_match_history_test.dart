import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_arena/models/move_model.dart';
import 'package:chess_arena/services/match_history_service.dart';
import 'package:chess_arena/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsManager', () {
    test('loads defaults, persists changes and resets', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = SettingsManager();
      await settings.load();

      expect(settings.boardTheme, BoardTheme.royalWood);
      expect(settings.soundEnabled, isTrue);
      expect(settings.showLegalMoves, isTrue);
      expect(settings.pieceAnimations, isTrue);

      await settings.setBoardTheme(BoardTheme.emeraldField);
      await settings.setSoundEnabled(false);
      await settings.setDefaultDifficulty(2);
      expect(settings.boardTheme, BoardTheme.emeraldField);
      expect(settings.soundEnabled, isFalse);
      expect(settings.palette.theme, BoardTheme.emeraldField);

      // A fresh manager reads the same persisted values.
      final persisted = SettingsManager();
      await persisted.load();
      expect(persisted.boardTheme, BoardTheme.emeraldField);
      expect(persisted.soundEnabled, isFalse);
      expect(persisted.defaultDifficultyIndex, 2);

      await persisted.resetToDefaults();
      expect(persisted.boardTheme, BoardTheme.royalWood);
      expect(persisted.soundEnabled, isTrue);
    });

    test('tolerates legacy typed values from older installs', () async {
      // Older builds stored some keys with different Dart types.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'board_theme': 1, // legacy int index
        'sound_enabled': 0,
        'show_legal_moves': 'true',
        'default_difficulty': '2',
      });
      final legacy = SettingsManager();
      await legacy.load();
      expect(legacy.boardTheme, BoardTheme.emeraldField);
      expect(legacy.soundEnabled, isFalse);
      expect(legacy.showLegalMoves, isTrue);
      expect(legacy.defaultDifficultyIndex, 2);
    });

    test('every theme exposes a complete palette', () {
      for (final theme in BoardTheme.values) {
        final palette = RoyalPalette.from(theme);
        expect(palette.theme, theme);
        expect(palette.accent, isNot(Colors.transparent));
        expect(palette.theme.lightSquare, isNot(palette.theme.darkSquare));
      }
    });
  });

  group('MatchHistoryService', () {
    test('saves, limits and clears match records', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = MatchHistoryService();
      await service.load();
      expect(service.records, isEmpty);

      await service.add(
        mode: GameMode.vsComputer,
        reason: GameEndReason.checkmate,
        whiteWon: true,
        whiteName: 'You',
        blackName: 'Computer',
        moveCount: 41,
        timeControl: '10 min',
      );
      expect(service.records.length, 1);
      final record = service.records.single;
      expect(record.outcomeShort, 'White won');
      expect(record.reasonLabel, 'Checkmate');
      expect(record.timeControl, '10 min');

      await service.add(
        mode: GameMode.passAndPlay,
        reason: GameEndReason.stalemate,
        whiteWon: null,
        whiteName: 'White',
        blackName: 'Black',
        moveCount: 20,
        timeControl: 'No clock',
      );
      // Newest first on read access.
      expect(service.records.first.outcomeShort, 'Draw');

      await service.clear();
      expect(service.records, isEmpty);
    });
  });
}
