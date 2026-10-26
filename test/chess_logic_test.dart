import 'package:flutter_test/flutter_test.dart';

import 'package:chess_arena/models/game_state_model.dart';
import 'package:chess_arena/models/move_model.dart';

void main() {
  group('GameStateModel - basics', () {
    test('new position has 32 pieces and standard turn', () {
      final game = GameStateModel()..newGame();
      expect(game.pieces.length, 32);
      expect(game.isWhiteTurn, isTrue);
      expect(game.history, isEmpty);
      expect(game.inCheck, isFalse);
    });

    test('pawn from e2 has exactly two legal moves (no indicator suppression)',
        () {
      final game = GameStateModel()..newGame();
      expect(game.legalTargetsFrom('e2').length, 2);
      expect(game.legalTargetsFrom('e2').keys, containsAll(['e3', 'e4']));
      // It is white's half of the board; black pawns cannot be moved now.
      expect(game.legalTargetsFrom('e7'), isEmpty);
    });

    test('piece asset keys map to bundled SVG file names', () {
      final game = GameStateModel()..newGame();
      expect(game.pieces, isNotEmpty);
      for (final p in game.pieces) {
        expect(
          p.assetKey,
          matches(RegExp(r'^(white|black)(pawn|knight|bishop|rook|queen|king)$')),
          reason: 'assets/pieces/<theme>/${p.assetKey}.svg must exist',
        );
      }
    });

    test('play e4 updates history, turn and last move', () {
      final game = GameStateModel()..newGame();
      final move = game.findMove('e2', 'e4');
      expect(move, isNotNull);
      final played = game.playMove(move!);
      expect(played, isNotNull);
      expect(game.isWhiteTurn, isFalse);
      expect(game.lastMove!.san, 'e4');
      expect(game.lastMove!.from, 'e2');
      expect(game.lastMove!.to, 'e4');
      // White's e2 pawn now stands on e4.
      expect(
        game.pieces
            .where((p) => p.alive && p.isWhite && p.square == 'e4')
            .length,
        1,
      );
    });
  });

  group('GameStateModel - special moves', () {
    test('castling moves king and rook together', () {
      final game = GameStateModel()
        ..loadFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final move = game.findMove('e1', 'g1');
      expect(move, isNotNull);
      expect((move!.flags & 32) != 0, isTrue); // king-side castle flag
      game.playMove(move);
      final king = game.pieces.firstWhere(
          (p) => p.alive && p.type == 'k' && p.isWhite);
      final rook = game.pieces.where(
          (p) => p.alive && p.type == 'r' && p.isWhite).toList();
      expect(king.square, 'g1');
      expect(rook.map((r) => r.square), containsAll(['a1', 'f1']));
      expect(game.lastMove!.san, 'O-O');
    });

    test('queen-side castling moves the rook to d1', () {
      final game = GameStateModel()
        ..loadFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final move = game.findMove('e1', 'c1');
      expect(move, isNotNull);
      game.playMove(move!);
      final rooks = game.pieces
          .where((p) => p.alive && p.type == 'r' && p.isWhite)
          .map((p) => p.square);
      expect(rooks, containsAll(['h1', 'd1']));
      expect(game.lastMove!.san, 'O-O-O');
    });

    test('en passant removes the bypassed black pawn', () {
      final game = GameStateModel()
        ..loadFen('rnbqkbnr/pppp1ppp/8/4Pp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      final move = game.findMove('e5', 'f6');
      expect(move, isNotNull);
      final played = game.playMove(move!);
      expect(played!.ghostSquare, 'f5'); // victim square for capture animation
      expect(game.capturedByWhite, contains('p'));
      // The f5 pawn is gone.
      final f5Pawns = game.pieces
          .where((p) => p.alive && p.type == 'p' && p.square == 'f5');
      expect(f5Pawns, isEmpty);
      // White pawn is on f6.
      expect(
          game.pieces
              .any((p) => p.alive && p.type == 'p' && p.isWhite && p.square == 'f6'),
          isTrue);
    });

    test('promotion promotes the pawn to the chosen piece', () {
      final game = GameStateModel()
        ..loadFen('8/P7/8/8/8/8/7k/K7 w - - 0 1');
      final move = game.findMove('a7', 'a8', promotion: 'q');
      expect(move, isNotNull);
      game.playMove(move!);
      expect(game.lastMove!.promotion, 'q');
      expect(game.lastMove!.san, 'a8=Q');
      final promoted = game.pieces
          .where((p) => p.alive && p.type == 'q' && p.isWhite)
          .toList();
      expect(promoted.length, 1);
      expect(promoted.first.square, 'a8');
      expect(game.history.length, 1);
      expect(game.playMove(move), isNull); // replaying is rejected: game over-ish
    });
  });

  group('GameStateModel - game endings', () {
    test('fools mate is detected as checkmate for black', () {
      final game = GameStateModel()..newGame();
      final seq = <List<String>>[
        ['f2', 'f3'],
        ['e7', 'e5'],
        ['g2', 'g4'],
        ['d8', 'h4'],
      ];
      for (final pair in seq) {
        final from = pair[0];
        final to = pair[1];
        final move = game.findMove(from, to);
        expect(move, isNotNull, reason: '$from-$to should be legal');
        expect(game.playMove(move!), isNotNull);
      }
      expect(game.isCheckmate, isTrue);
      expect(game.isGameOver, isTrue);
      expect(game.lastMove!.san, 'Qh4#');
      // The checked white king sits on e1.
      expect(game.checkSquare, 'e1');
    });

    test('stalemate with lone kings and cornered queen is a draw', () {
      final game = GameStateModel()
        ..loadFen('k7/8/1Q6/8/8/8/8/K7 b - - 0 1');
      expect(game.isStalemate, isTrue);
      expect(game.isCheckmate, isFalse);
      expect(game.isDraw, isTrue);
    });

    test('insufficient material (kings only) draws', () {
      final game = GameStateModel()
        ..loadFen('k7/8/8/8/8/8/8/K7 w - - 0 1');
      expect(game.insufficientMaterial, isTrue);
      expect(game.isDraw, isTrue);
    });

    test('undo restores the previous position', () {
      final game = GameStateModel()
        ..loadFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final move = game.findMove('e1', 'g1')!;
      game.playMove(move);
      expect(game.history.length, 1);
      expect(game.isWhiteTurn, isFalse);
      expect(game.undoPly(), isTrue);
      expect(game.history, isEmpty);
      expect(game.isWhiteTurn, isTrue);
      final king = game.pieces
          .firstWhere((p) => p.alive && p.type == 'k' && p.isWhite);
      expect(king.square, 'e1');
      final rook = game.pieces
          .firstWhere((p) => p.alive && p.isWhite && p.type == 'r' && p.square == 'h1');
      expect(rook.type, 'r');
    });

    test('captures are tracked per side', () {
      final game = GameStateModel()
        ..loadFen('rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2');
      final move = game.findMove('e4', 'd5');
      expect(move, isNotNull);
      final played = game.playMove(move!);
      expect(played, isNotNull);
      expect(played!.ghostSquare, 'd5');
      expect(game.capturedByWhite, contains('p'));
      expect(game.capturedByBlack, isEmpty);
    });

    test('material difference is reported correctly', () {
      final game = GameStateModel()
        ..loadFen('k7/8/8/3q4/8/8/8/K6R w - - 0 1');
      // White: rook (5). Black: queen (9). Diff = -4.
      expect(game.materialDiff(), -4);
    });
  });

  group('GameResult helpers', () {
    test('reason labels cover all endings', () {
      expect(GameEndReason.values.length, 8);
      expect(Difficulty.values.map((d) => d.label),
          containsAll(['Easy', 'Medium', 'Hard']));
    });
  });
}
