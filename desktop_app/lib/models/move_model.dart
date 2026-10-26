import 'package:chess/chess.dart' as ch;

/// How a game may end.
enum GameEndReason {
  checkmate,
  stalemate,
  timeout,
  resignation,
  drawAgreed,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoveRule,
}

/// Difficulty of the computer opponent.
enum Difficulty {
  easy('Easy', 1, 'Learns with you'),
  medium('Medium', 2, 'A fair fight'),
  hard('Hard', 3, 'No mercy');

  final String label;
  final int searchDepth;
  final String tagline;

  const Difficulty(this.label, this.searchDepth, this.tagline);
}

/// Which mode the match is played in.
enum GameMode {
  vsComputer('Play vs Computer'),
  passAndPlay('Pass & Play');

  final String label;

  const GameMode(this.label);
}

/// A single piece on the board with a stable identity so the UI can animate
/// it from square to square.
class BoardPiece {
  final String id;
  String type; // p, n, b, r, q, k
  final bool isWhite;
  String square;
  bool alive;

  BoardPiece({
    required this.id,
    required this.type,
    required this.isWhite,
    required this.square,
    this.alive = true,
  });

  BoardPiece clone() =>
      BoardPiece(id: id, type: type, isWhite: isWhite, square: square, alive: alive);

  String get assetKey {
    const typeNames = <String, String>{
      'p': 'pawn',
      'n': 'knight',
      'b': 'bishop',
      'r': 'rook',
      'q': 'queen',
      'k': 'king',
    };
    return '${isWhite ? 'white' : 'black'}${typeNames[type] ?? type}';
  }
}

/// One recorded half-move in the scrollable move list.
class MoveRecord {
  final String san;
  final String from;
  final String to;
  final bool isCapture;
  final bool isCheck;
  final bool isMate;
  final String? promotion;
  final bool byWhite;

  const MoveRecord({
    required this.san,
    required this.from,
    required this.to,
    required this.isCapture,
    required this.isCheck,
    required this.isMate,
    required this.promotion,
    required this.byWhite,
  });

  bool get isCastle =>
      san.startsWith('O-O-O') || (san.startsWith('O-O') && !san.startsWith('O-O-O'));
}

/// Everything needed to describe a finished match.
class GameResult {
  final GameEndReason reason;
  final bool? whiteWon; // null = draw
  final int moveCount;
  final Duration duration;
  final String winnerName;
  final String loserName;

  const GameResult({
    required this.reason,
    required this.whiteWon,
    required this.moveCount,
    required this.duration,
    required this.winnerName,
    required this.loserName,
  });

  bool get isDraw => whiteWon == null;
}

/// Utility helpers built on top of the rules engine.
class ChessHelpers {
  static const List<String> files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  /// Converts an 0x88 square index from the chess package to algebraic.
  static String algebraic(int index) => ch.Chess.algebraic(index);

  /// Rank (1..8) and file (0..7) of a square like 'e4'.
  static int fileOf(String square) => files.indexOf(square[0]);

  static int rankOf(String square) => int.parse(square[1]);

  /// Square colour used for rendering.
  static bool isLightSquare(String square) =>
      (fileOf(square) + rankOf(square)) ~/ 2 == (fileOf(square) + rankOf(square)) / 2 &&
          (fileOf(square) + rankOf(square)) % 2 == 0;

  static String pieceLetter(ch.PieceType type) => type.name;

  /// Simple material value in pawns.
  static int materialValue(String type) {
    switch (type) {
      case 'p':
        return 1;
      case 'n':
        return 3;
      case 'b':
        return 3;
      case 'r':
        return 5;
      case 'q':
        return 9;
      default:
        return 0;
    }
  }
}
