import 'package:flutter/foundation.dart';

import 'package:chess/chess.dart' as ch;

/// Entry point run inside a background isolate via [compute].
/// Returns a JSON-safe map describing the chosen move.
Map<String, String?> aiThink(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int;
  final blunderChance = (request['blunderChance'] as num?)?.toDouble() ?? 0.0;
  final searcher = _AiSearcher(
    fen: fen,
    depth: depth,
    blunderChance: blunderChance,
  );
  final best = searcher.search();
  if (best.from < 0) return const {};
  return <String, String?>{
    'from': ch.Chess.algebraic(best.from),
    'to': ch.Chess.algebraic(best.to),
    'promotion': best.promotion?.name,
  };
}

class _AiSearcher {
  _AiSearcher({
    required this.fen,
    required this.depth,
    required this.blunderChance,
  });

  final String fen;
  final int depth;
  final double blunderChance;

  late final ch.Chess game = ch.Chess()..load(fen);

  static const int kingValue = 20000;
  static const int maxNodes = 300000;

  int _nodes = 0;

  // Piece-square tables. Index 0 = a8, index 63 = h1 (matches the chess
  // package layout). Tables are written from White's point of view with the
  // most advantageous squares positive.
  static const List<int> _pawnPst = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  static const List<int> _knightPst = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  static const List<int> _bishopPst = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];

  static const List<int> _rookPst = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];

  static const List<int> _queenPst = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];

  static const List<int> _kingPst = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ];

  static int _valueFor(ch.PieceType type) {
    switch (type) {
      case ch.Chess.PAWN:
        return 100;
      case ch.Chess.KNIGHT:
        return 320;
      case ch.Chess.BISHOP:
        return 330;
      case ch.Chess.ROOK:
        return 500;
      case ch.Chess.QUEEN:
        return 900;
      case ch.Chess.KING:
        return kingValue;
    }
    return 0;
  }

  static List<int> _pstFor(ch.PieceType type) {
    switch (type) {
      case ch.Chess.PAWN:
        return _pawnPst;
      case ch.Chess.KNIGHT:
        return _knightPst;
      case ch.Chess.BISHOP:
        return _bishopPst;
      case ch.Chess.ROOK:
        return _rookPst;
      case ch.Chess.QUEEN:
        return _queenPst;
      case ch.Chess.KING:
        return _kingPst;
    }
    return const [];
  }

  int _mirror(int index) {
    final rank = index ~/ 8;
    final file = index % 8;
    return (7 - rank) * 8 + file;
  }

  /// Static evaluation, from White's perspective in centipawns.
  int evaluate() {
    var score = 0;
    for (var sq = 0; sq <= ch.Chess.SQUARES_H1; sq++) {
      if ((sq & 0x88) != 0) {
        sq += 7;
        continue;
      }
      final piece = game.board[sq];
      if (piece == null) continue;
      final packed = (sq ~/ 16) * 8 + (sq % 16); // 0 = a8 ... 63 = h1
      var value = _valueFor(piece.type);
      final pst = _pstFor(piece.type);
      if (pst.isNotEmpty) {
        value += piece.color == ch.Color.WHITE ? pst[packed] : pst[_mirror(packed)];
      }
      score += piece.color == ch.Color.WHITE ? value : -value;
    }
    return score;
  }

  /// Ordered pseudo-legal move list: captures first (MVV-LVA), then others.
  List<ch.Move> orderedMoves() {
    final moves = game.generate_moves();
    int orderValue(ch.Move m) {
      var v = 0;
      if ((m.flags & ch.Chess.BITS_CAPTURE) != 0 ||
          (m.flags & ch.Chess.BITS_EP_CAPTURE) != 0) {
        final victim = m.captured != null ? _valueFor(m.captured!) : 100;
        final attacker = _valueFor(m.piece);
        v = 10 * victim - attacker;
      }
      if ((m.flags & ch.Chess.BITS_PROMOTION) != 0) {
        v += _valueFor(m.promotion!);
      }
      if ((m.flags & ch.Chess.BITS_KSIDE_CASTLE) != 0 ||
          (m.flags & ch.Chess.BITS_QSIDE_CASTLE) != 0) {
        v += 40;
      }
      return v;
    }

    moves.sort((a, b) => orderValue(b).compareTo(orderValue(a)));
    return moves;
  }

  int quiescence(int alpha, int beta, int side, int qdepth) {
    _nodes++;
    if (_nodes > maxNodes) throw const _SearchBudget();
    if (game.in_checkmate) {
      return -kingValue;
    }
    if (game.in_stalemate || game.in_draw) return 0;
    final standPat = side == 1 ? evaluate() : -evaluate();
    if (standPat >= beta) return standPat;
    if (standPat > alpha) alpha = standPat;
    if (qdepth <= 0) return alpha;

    for (final move in orderedMoves().take(16)) {
      final isCapture = (move.flags & ch.Chess.BITS_CAPTURE) != 0 ||
          (move.flags & ch.Chess.BITS_EP_CAPTURE) != 0 ||
          (move.flags & ch.Chess.BITS_PROMOTION) != 0;
      if (!isCapture) continue;
      game.make_move(move);
      final score = -quiescence(-beta, -alpha, -side, qdepth - 1);
      game.undo_move();
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int searchAlphaBeta(int depth, int alpha, int beta, int side) {
    if (game.in_draw) return 0;
    if (game.in_checkmate) {
      // Side to move is checkmated: worst possible score for them.
      return -kingValue + (10 - depth);
    }
    if (game.in_stalemate) return 0;
    _nodes++;
    if (_nodes > maxNodes) throw const _SearchBudget();
    if (depth <= 0) {
      return quiescence(alpha, beta, side, 2);
    }

    final moves = orderedMoves();
    if (moves.isEmpty) {
      return game.in_check ? (side == 1 ? -kingValue : kingValue) : 0;
    }

    var best = -kingValue * 2;
    for (final move in moves) {
      game.make_move(move);
      final score = -searchAlphaBeta(depth - 1, -beta, -alpha, -side);
      game.undo_move();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Root search; throws away half-legal weakening moves for easy levels via
  /// [blunderChance] picking for a slightly sub-optimal move.
  _RootMove search() {
    try {
      final side = game.turn == ch.Color.WHITE ? 1 : -1;
      final moves = orderedMoves();
      if (moves.isEmpty) return const _RootMove(-1, -1);

      final scored = <_RootMove>[];
      for (final move in moves) {
        game.make_move(move);
        int score;
        if (game.in_checkmate) {
          score = kingValue; // immediate win
        } else {
          score = -searchAlphaBeta(depth - 1, -kingValue * 2, kingValue * 2, -side);
        }
        game.undo_move();
        scored.add(_RootMove(move.from, move.to, promotion: move.promotion, score: score));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));

      // Difficulty-flavoured imperfection.
      if (blunderChance > 0 && scored.length > 2 && _random() % 100 < (blunderChance * 100)) {
        final window = scored.skip(1).take(scored.length > 3 ? 2 : 1).toList();
        return window[_random() % window.length];
      }
      return scored.first;
    } on _SearchBudget {
      // Node budget exhausted: fall back to the immediate greedy choice.
      final moves = orderedMoves();
      if (moves.isEmpty) return const _RootMove(-1, -1);
      var bestIdx = 0;
      var bestScore = -kingValue * 2;
      final side = game.turn == ch.Color.WHITE ? 1 : -1;
      for (var i = 0; i < moves.length; i++) {
        game.make_move(moves[i]);
        final score = -evaluateSide(-side);
        game.undo_move();
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      final m = moves[bestIdx];
      return _RootMove(m.from, m.to, promotion: m.promotion, score: bestScore);
    } catch (_) {
      // Any unexpected failure: play a random legal move instead of freezing.
      final moves = game.generate_moves();
      if (moves.isEmpty) return const _RootMove(-1, -1);
      final m = moves.first;
      return _RootMove(m.from, m.to, promotion: m.promotion);
    }
  }

  int evaluateSide(int side) => side == 1 ? evaluate() : -evaluate();

  static int _random() {
    // Lightweight deterministic-ish PRNG (no dart:math import cost).
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed;
  }

  static int _seed = 0x5f3759df;
}

class _RootMove {
  const _RootMove(this.from, this.to, {this.promotion, this.score = 0});

  final int from;
  final int to;
  final ch.PieceType? promotion;
  final int score;
}

class _SearchBudget implements Exception {
  const _SearchBudget();
}
