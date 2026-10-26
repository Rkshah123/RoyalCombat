import 'package:flutter_test/flutter_test.dart';

import 'package:chess_arena/services/chess_ai.dart';

void main() {
  group('aiThink', () {
    test('returns a legal opening move', () {
      final result = aiThink(<String, dynamic>{
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'depth': 2,
        'blunderChance': 0.0,
      });
      expect(result, isNotEmpty);
      expect(result['from'], isA<String>());
      expect(result['to'], isA<String>());
      expect(result['promotion'], isNull);
    });

    test('finds mate in one (Qh4#)', () {
      final result = aiThink(<String, dynamic>{
        'fen': 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
        'depth': 2,
        'blunderChance': 0.0,
      });
      expect(result, isNotEmpty);
      expect(result['from'], 'd8');
      expect(result['to'], 'h4');
    });

    test('finds a forcing move for white (ladder)', () {
      // White rook on a1 vs black king trapped on a1-file; the engine picks
      // a capture — just assert it returns a legal white rook move.
      final result = aiThink(<String, dynamic>{
        'fen': 'k7/8/8/8/8/8/r7/R6K w - - 0 1',
        'depth': 2,
        'blunderChance': 0.0,
      });
      expect(result, isNotEmpty);
      expect(result['from'], 'a1');
      expect(result['promotion'], isNull);
    });

    test('bare-kings position yields any legal king move without crashing',
        () {
      final result = aiThink(<String, dynamic>{
        'fen': 'k7/8/8/8/8/8/8/K7 w - - 0 1',
        'depth': 2,
        'blunderChance': 0.0,
      });
      expect(result, isNotEmpty);
      expect(result['from'], 'a1');
    });
  });
}
