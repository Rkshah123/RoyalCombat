import 'package:chess/chess.dart' as ch;

import 'move_model.dart';

/// Owns the rules state of an ongoing match (backed by the `chess` package)
/// plus the animated piece list and history the UI needs.
class GameStateModel {
  ch.Chess _game = ch.Chess();
  List<BoardPiece> _pieces = [];
  final List<MoveRecord> _history = <MoveRecord>[];
  final List<List<BoardPiece>> _snapshots = <List<BoardPiece>>[];
  final List<List<String>> _capturedSnapshots = <List<String>>[];
  final List<String> _capturedByWhite = [];
  final List<String> _capturedByBlack = [];
  final DateTime startedAt = DateTime.now();

  List<BoardPiece> get pieces => List.unmodifiable(_pieces);
  List<MoveRecord> get history => List.unmodifiable(_history);
  List<String> get capturedByWhite => List.unmodifiable(_capturedByWhite);
  List<String> get capturedByBlack => List.unmodifiable(_capturedByBlack);
  bool get isWhiteTurn => _game.turn == ch.Color.WHITE;
  bool get inCheck => _game.in_check;
  bool get isCheckmate => _game.in_checkmate;
  bool get isStalemate => _game.in_stalemate;
  bool get insufficientMaterial => _game.insufficient_material;
  bool get threefoldRepetition => _game.in_threefold_repetition;
  bool get fiftyMoveRule => _game.half_moves >= 100;
  bool get isDraw =>
      _game.in_draw || _game.half_moves >= 100;
  bool get isGameOver => _game.game_over;
  int get moveCount => _history.length;
  String get fen => _game.fen;

  /// Square of a king that is in check (used for the red pulse effect).
  String? get checkSquare {
    if (!_game.in_check) return null;
    for (final p in _pieces) {
      if (p.alive && p.type == 'k' && p.isWhite == isWhiteTurn) return p.square;
    }
    return null;
  }

  /// The last played move for highlighting.
  MoveRecord? get lastMove => _history.isEmpty ? null : _history.last;

  /// Starts (or restarts) from the standard initial position.
  void newGame() {
    _game = ch.Chess();
    _history.clear();
    _snapshots.clear();
    _capturedSnapshots.clear();
    _capturedByWhite.clear();
    _capturedByBlack.clear();
    _buildInitialPieces();
  }

  /// Loads a custom position (used by the engine suite and tests).
  void loadFen(String fen) {
    _game = ch.Chess();
    if (!_game.load(fen)) {
      throw ArgumentError('Invalid FEN: $fen');
    }
    _history.clear();
    _snapshots.clear();
    _capturedSnapshots.clear();
    _capturedByWhite.clear();
    _capturedByBlack.clear();
    _buildInitialPieces();
  }

  void _buildInitialPieces() {
    var idCounter = 0;
    _pieces = [];
    for (final entry in ch.Chess.SQUARES.entries) {
      final piece = _game.get(entry.key as String);
      if (piece == null) continue;
      _pieces.add(
        BoardPiece(
          id: 'p${idCounter++}',
          type: piece.type.name,
          isWhite: piece.color == ch.Color.WHITE,
          square: entry.key as String,
        ),
      );
    }
  }

  /// Legal moves of the piece standing on [square] (empty when none).
  List<ch.Move> legalMovesFrom(String square) {
    final List moves = _game.generate_moves(<dynamic, dynamic>{'square': square});
    return moves.cast<ch.Move>();
  }

  /// All distinct destination squares for [square], with capture flag.
  Map<String, bool> legalTargetsFrom(String square) {
    final targets = <String, bool>{};
    for (final m in legalMovesFrom(square)) {
      final dest = ch.Chess.algebraic(m.to);
      final existing = targets[dest] ?? false;
      targets[dest] = existing || (m.flags & ch.Chess.BITS_CAPTURE) != 0;
    }
    return targets;
  }

  /// Promotions available for [from]->[to]; empty when not a promotion move.
  List<ch.Move> promotionCandidates(String from, String to) {
    final List moves = _game.generate_moves(<dynamic, dynamic>{'square': from});
    return moves
        .cast<ch.Move>()
        .where((m) => m.to == _squareIndex(to) && (m.flags & ch.Chess.BITS_PROMOTION) != 0)
        .toList();
  }

  static int _squareIndex(String square) => ch.Chess.SQUARES[square] as int;

  /// Finds the exact engine move matching from/to/promotion (or a plain
  /// non-promotion move when promotion is null).
  ch.Move? findMove(String from, String to, {String? promotion}) {
    final List moves = _game.generate_moves(<dynamic, dynamic>{'square': from});
    for (final m in moves.cast<ch.Move>()) {
      if (ch.Chess.algebraic(m.to) != to) continue;
      final isPromo = (m.flags & ch.Chess.BITS_PROMOTION) != 0;
      if (isPromo) {
        if (promotion == null) {
          // Caller must pick a promotion piece first.
          continue;
        }
        if (m.promotion!.name != promotion) continue;
      } else if (promotion != null) {
        continue;
      }
      return m;
    }
    return null;
  }

  /// Applies [move]; returns outcome details, or null when illegal.
  PlayedMove? playMove(ch.Move move) {
    if (!isLegalToPlay(move)) return null;
    _snapshots.add(List.of(_pieces.map((p) => p.clone())));
    _capturedSnapshots.add([..._capturedByWhite, ..._capturedByBlack]);

    final fromSquare = ch.Chess.algebraic(move.from);
    final toSquare = ch.Chess.algebraic(move.to);
    // Pre-compute the capture victim for the UI capture animation.
    String? victimSquare;
    String victimType = '';
    bool victimWhite = false;
    if ((move.flags & ch.Chess.BITS_EP_CAPTURE) != 0) {
      // The bypassed pawn sits beside the destination square, on the same file
      // as the capture target (e.g. white e5 -> f6 removes the pawn on f5).
      final moverWhite = move.color == ch.Color.WHITE;
      victimSquare = '${toSquare[0]}${moverWhite ? '5' : '4'}';
    } else if ((move.flags & ch.Chess.BITS_CAPTURE) != 0) {
      victimSquare = toSquare;
    }
    if (victimSquare != null) {
      final victim = _pieces.firstWhere(
        (p) => p.alive && p.square == victimSquare! && p.isWhite != (move.color == ch.Color.WHITE),
      );
      victimType = victim.type;
      victimWhite = victim.isWhite;
    }

    // SAN must be computed before the move is applied.
    final san = _game.move_to_san(move);
    final promoType = move.promotion?.name;

    if (!_game.move(<dynamic, dynamic>{'from': fromSquare, 'to': toSquare, 'promotion': promoType})) {
      _snapshots.removeLast();
      _capturedSnapshots.removeLast();
      return null;
    }

    _synchronizePieces(move, fromSquare, toSquare, promoType);

    if (victimSquare != null) {
      final moverWhite = move.color == ch.Color.WHITE;
      _recordCapture(moverWhite, victimType);
    }

    final isCapture = (move.flags & ch.Chess.BITS_CAPTURE) != 0 ||
        (move.flags & ch.Chess.BITS_EP_CAPTURE) != 0;
    final record = MoveRecord(
      san: san,
      from: fromSquare,
      to: toSquare,
      isCapture: isCapture,
      isCheck: _game.in_check,
      isMate: _game.in_checkmate,
      promotion: promoType,
      byWhite: move.color == ch.Color.WHITE,
    );
    _history.add(record);
    return PlayedMove(
      record: record,
      ghostSquare: victimSquare,
      ghostType: victimType,
      ghostWhite: victimWhite,
    );
  }

  bool isLegalToPlay(ch.Move move) {
    // A move object from generate_moves is always considered by move_to_san /
    // move(); double check the mover is the side to move.
    final moverWhite = move.color == ch.Color.WHITE;
    return moverWhite == isWhiteTurn;
  }

  void _synchronizePieces(ch.Move move, String from, String to, String? promo) {
    BoardPiece target = _pieces.firstWhere(
      (p) => p.alive && p.square == from,
      orElse: () => throw StateError('No piece at $from to animate'),
    );

    // En passant capture removes a pawn on a different square: beside the
    // destination square, on the capture target's file (white e5 -> f6
    // removes the pawn standing on f5).
    if ((move.flags & ch.Chess.BITS_EP_CAPTURE) != 0) {
      final victimRank = target.isWhite ? '5' : '4';
      final victimSquare = '${to[0]}$victimRank';
      final victim = _pieces.firstWhere(
        (p) => p.alive && p.square == victimSquare,
        orElse: () => throw StateError('No en-passant victim at $victimSquare'),
      );
      victim.alive = false;
    } else if ((move.flags & ch.Chess.BITS_CAPTURE) != 0) {
      final victim = _pieces.firstWhere(
        (p) => p.alive && p.square == to && identical(p, target) == false,
        orElse: () => throw StateError('No capture victim at $to'),
      );
      victim.alive = false;
    }
    target.square = to;
    if (promo != null) {
      target.type = promo;
    }

    // Rook relocation for castling.
    if ((move.flags & ch.Chess.BITS_KSIDE_CASTLE) != 0) {
      final rank = target.isWhite ? 1 : 8;
      _moveRook('h$rank', 'f$rank');
    } else if ((move.flags & ch.Chess.BITS_QSIDE_CASTLE) != 0) {
      final rank = target.isWhite ? 1 : 8;
      _moveRook('a$rank', 'd$rank');
    }
  }

  void _moveRook(String from, String to) {
    final rook = _pieces.firstWhere(
      (p) => p.alive && p.square == from && p.type == 'r',
      orElse: () => throw StateError('No rook at $from for castling'),
    );
    rook.square = to;
  }

  void _recordCapture(bool byWhite, String type) {
    (byWhite ? _capturedByWhite : _capturedByBlack).add(type);
  }

  /// Rolls back one half-move (or a whole snapshot when available).
  bool undoPly() {
    if (_snapshots.isEmpty) return false;
    _game.undo_move();
    final restored = _snapshots.removeLast();
    _pieces = List.of(restored.map((p) => p.clone()));
    if (_capturedSnapshots.isNotEmpty) {
      final caps = _capturedSnapshots.removeLast();
      _capturedByWhite
        ..clear()
        ..addAll(caps.sublist(0, caps.length ~/ 2));
      _capturedByBlack
        ..clear()
        ..addAll(caps.sublist(caps.length ~/ 2));
    }
    if (_history.isNotEmpty) _history.removeLast();
    return true;
  }

  /// Number of frames (plies) remaining for [isWhite].
  int pliesBy(bool isWhite) {
    var n = 0;
    for (final r in _history) {
      if (r.byWhite == isWhite) n++;
    }
    return n;
  }

  /// Christiansen-style material score (positive = white ahead).
  int materialDiff() {
    var diff = 0;
    for (final p in _pieces) {
      if (!p.alive || p.type == 'k') continue;
      diff += (p.isWhite ? 1 : -1) * ChessHelpers.materialValue(p.type);
    }
    return diff;
  }
}

/// Result of applying a move: the record plus capture animation details.
class PlayedMove {
  const PlayedMove({
    required this.record,
    required this.ghostSquare,
    required this.ghostType,
    required this.ghostWhite,
  });

  final MoveRecord record;
  final String? ghostSquare;
  final String ghostType;
  final bool ghostWhite;
}

/// Small helper shape for a pending hint.
class HintMove {
  final String from;
  final String to;

  const HintMove(this.from, this.to);
}
