import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import 'piece_widget.dart';

/// The six pieces demonstrated in "Learn How Pieces Move".
enum DemoPieceType { pawn, king, queen, rook, bishop, knight }

extension DemoPieceTypeLabel on DemoPieceType {
  String get name2 => switch (this) {
        DemoPieceType.pawn => 'Pawn',
        DemoPieceType.king => 'King',
        DemoPieceType.queen => 'Queen',
        DemoPieceType.rook => 'Rook',
        DemoPieceType.bishop => 'Bishop',
        DemoPieceType.knight => 'Knight',
      };

  String get assetKey => switch (this) {
        DemoPieceType.pawn => 'whitepawn',
        DemoPieceType.king => 'whiteking',
        DemoPieceType.queen => 'whitequeen',
        DemoPieceType.rook => 'whiterook',
        DemoPieceType.bishop => 'whitebishop',
        DemoPieceType.knight => 'whiteknight',
      };

  /// One-line rule shown under the demonstration board.
  String get rule => switch (this) {
        DemoPieceType.pawn =>
          'Moves one square forward (two on its first move) and captures one square diagonally. It can never move backwards.',
        DemoPieceType.king =>
          'Moves exactly one square in any direction - never onto an attacked square.',
        DemoPieceType.queen =>
          'Any distance in a straight line: across, up, down and diagonally.',
        DemoPieceType.rook =>
          'Any distance along ranks and files - straight horizontal or vertical lines only.',
        DemoPieceType.bishop =>
          'Any distance along the diagonals. It stays on one square colour forever.',
        DemoPieceType.knight =>
          'Moves in an L-shape and is the only piece that jumps over blockers.',
      };
}

/// Starting position of every demonstration: where the white piece stands and
/// which black dummies sit on the board.
({String square, Map<String, String> enemies}) _initialSetup(DemoPieceType t) {
  switch (t) {
    case DemoPieceType.pawn:
      return (square: 'e2', enemies: {'d3': 'p', 'f3': 'p'});
    case DemoPieceType.king:
      return (square: 'e4', enemies: {'d5': 'p'});
    case DemoPieceType.queen:
      return (square: 'd4', enemies: {'g7': 'p'});
    case DemoPieceType.rook:
      return (square: 'd4', enemies: {'d7': 'p'});
    case DemoPieceType.bishop:
      return (square: 'c4', enemies: {'f7': 'p'});
    case DemoPieceType.knight:
      // d3 and e5 are adjacent blockers the knight leaps over; d2 and f6 are
      // L-targets occupied by enemies (capturable).
      return (
        square: 'e4',
        enemies: {'d3': 'p', 'e5': 'p', 'd2': 'p', 'f6': 'p'},
      );
  }
}

/// Computed movement plan for one position.
class _DemoPlan {
  const _DemoPlan({
    required this.moves,
    required this.captures,
    required this.arrowEnds,
  });

  /// Empty squares the piece may travel to.
  final Set<String> moves;

  /// Enemy-occupied squares it may capture on.
  final Set<String> captures;

  /// Squares where an arrow is drawn from the piece (one per straight path).
  final List<String> arrowEnds;
}

_DemoPlan _computePlan(DemoPieceType type, String from, Set<String> enemies) {
  final files = 'abcdefgh';
  final f = files.indexOf(from[0]);
  final r = int.parse(from[1]);
  bool onBoard(int x, int y) => x >= 0 && x < 8 && y >= 1 && y <= 8;
  String at(int x, int y) => '${files[x]}$y';
  bool occupied(int x, int y) =>
      !onBoard(x, y) || enemies.contains(at(x, y)) || at(x, y) == from;
  bool enemyAt(int x, int y) => onBoard(x, y) && enemies.contains(at(x, y));

  final moves = <String>{};
  final captures = <String>{};
  final arrows = <String>[];

  void addStep(int x, int y) {
    if (!onBoard(x, y)) return;
    if (enemyAt(x, y)) {
      captures.add(at(x, y));
    } else if (!occupied(x, y)) {
      moves.add(at(x, y));
    }
  }

  switch (type) {
    case DemoPieceType.pawn:
      // White pawn only, forward never onto an occupied square.
      if (!occupied(f, r + 1)) {
        moves.add(at(f, r + 1));
        arrows.add(at(f, r + 1));
        if (r == 2 && !occupied(f, r + 2)) {
          moves.add(at(f, r + 2));
          arrows.add(at(f, r + 2));
        }
      }
      for (final dx in [-1, 1]) {
        if (enemyAt(f + dx, r + 1)) {
          captures.add(at(f + dx, r + 1));
          arrows.add(at(f + dx, r + 1));
        }
      }
    case DemoPieceType.king:
      for (final dy in [-1, 0, 1]) {
        for (final dx in [-1, 0, 1]) {
          if (dx == 0 && dy == 0) continue;
          addStep(f + dx, r + dy);
          if (onBoard(f + dx, r + dy)) arrows.add(at(f + dx, r + dy));
        }
      }
    case DemoPieceType.knight:
      const jumps = [
        (-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1),
      ];
      for (final (dx, dy) in jumps) {
        addStep(f + dx, r + dy);
        if (onBoard(f + dx, r + dy)) arrows.add(at(f + dx, r + dy));
      }
    case DemoPieceType.rook:
      const dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)];
      for (final (dx, dy) in dirs) {
        var x = f + dx;
        var y = r + dy;
        while (onBoard(x, y) && !enemyAt(x, y) && at(x, y) != from) {
          moves.add(at(x, y));
          x += dx;
          y += dy;
        }
        if (enemyAt(x, y)) {
          captures.add(at(x, y));
          arrows.add(at(x, y));
        } else if (x - dx != f || y - dy != r) {
          // Ray ended at the board edge (or own square) - arrow to the last
          // square actually reached.
          final lastX = x - dx;
          final lastY = y - dy;
          if (lastX != f || lastY != r) arrows.add(at(lastX, lastY));
        }
      }
    case DemoPieceType.bishop:
      const dirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
      for (final (dx, dy) in dirs) {
        var x = f + dx;
        var y = r + dy;
        while (onBoard(x, y) && !enemyAt(x, y) && at(x, y) != from) {
          moves.add(at(x, y));
          x += dx;
          y += dy;
        }
        if (enemyAt(x, y)) {
          captures.add(at(x, y));
          arrows.add(at(x, y));
        } else if (x - dx != f || y - dy != r) {
          final lastX = x - dx;
          final lastY = y - dy;
          if (lastX != f || lastY != r) arrows.add(at(lastX, lastY));
        }
      }
    case DemoPieceType.queen:
      final rookPlan = _computePlan(DemoPieceType.rook, from, enemies);
      final bishopPlan = _computePlan(DemoPieceType.bishop, from, enemies);
      moves.addAll(rookPlan.moves);
      moves.addAll(bishopPlan.moves);
      captures.addAll(rookPlan.captures);
      captures.addAll(bishopPlan.captures);
      arrows.addAll(rookPlan.arrowEnds);
      arrows.addAll(bishopPlan.arrowEnds);
  }

  return _DemoPlan(moves: moves, captures: captures, arrowEnds: arrows);
}

/// An interactive mini chessboard demonstrating how one piece moves.
///
/// The piece starts on a themed board with a few black dummies. Every legal
/// destination is marked (dot = quiet move, ring = capture) and arrows show
/// the movement paths. Tapping a marked square smoothly glides the piece
/// there, capturing dummies along the way; the reset chip restores the start.
class PieceMovementDemo extends StatefulWidget {
  const PieceMovementDemo({super.key, required this.type});

  final DemoPieceType type;

  @override
  State<PieceMovementDemo> createState() => _PieceMovementDemoState();
}

class _PieceMovementDemoState extends State<PieceMovementDemo> {
  static const _files = 'abcdefgh';

  late String _square;
  late Set<String> _enemies;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final setup = _initialSetup(widget.type);
    _square = setup.square;
    _enemies = {...setup.enemies.keys};
  }

  ({int col, int row}) _posOf(String square) {
    final fileIdx = _files.indexOf(square[0]);
    final rank = int.parse(square[1]);
    return (col: fileIdx, row: 8 - rank);
  }

  void _onTapTarget(String square) {
    final plan = _computePlan(widget.type, _square, _enemies);
    final isCapture = plan.captures.contains(square);
    if (!plan.moves.contains(square) && !isCapture) return;
    setState(() {
      if (isCapture) {
        _enemies.remove(square);
        SoundManager.instance.play(Sfx.capture, volume: 0.9);
      } else {
        SoundManager.instance.play(Sfx.move, volume: 0.8);
      }
      _square = square;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final boardTheme = palette.theme;
    final plan = _computePlan(widget.type, _square, _enemies);

    return LayoutBuilder(builder: (context, constraints) {
      final side = (constraints.maxWidth - 36).clamp(220.0, 320.0);
      final tile = side / 8;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.panel.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(palette.accentSoft, palette.panel),
                    border: Border.all(
                        color: palette.panelBorder.withValues(alpha: 0.5)),
                  ),
                  child: PieceWidget.static(
                    assetKey: widget.type.assetKey,
                    themeFolder: boardTheme.assetFolder,
                    size: double.infinity,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.type.name2,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Reset demonstration',
                  icon: Icon(Icons.restart_alt_rounded,
                      size: 20, color: palette.textSecondary),
                  onPressed: () {
                    SoundManager.instance.tap();
                    setState(_reset);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: _board(side, tile, plan, palette),
            ),
            const SizedBox(height: 12),
            Text(
              widget.type.rule,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _board(
      double side, double tile, _DemoPlan plan, RoyalPalette palette) {
    final boardTheme = palette.theme;
    final piecePos = _posOf(_square);

    final tiles = <Widget>[];
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final isLight = (col + (8 - row)) % 2 == 0;
        tiles.add(Positioned(
          left: col * tile,
          top: row * tile,
          width: tile,
          height: tile,
          child: ColoredBox(
            color: isLight ? boardTheme.lightSquare : boardTheme.darkSquare,
          ),
        ));
      }
    }

    final hitTargets = <Widget>[];
    void addTap(String square) {
      final pos = _posOf(square);
      hitTargets.add(Positioned(
        left: pos.col * tile,
        top: pos.row * tile,
        width: tile,
        height: tile,
        child: GestureDetector(
          key: ValueKey('demo-tap-$square'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTapTarget(square),
        ),
      ));
    }

    for (final s in plan.moves) {
      addTap(s);
    }
    for (final s in plan.captures) {
      addTap(s);
    }

    final markers = <Widget>[];
    for (final s in plan.moves) {
      final pos = _posOf(s);
      markers.add(Positioned(
        key: ValueKey('demo-move-$s'),
        left: pos.col * tile,
        top: pos.row * tile,
        width: tile,
        height: tile,
        child: Center(
          child: Container(
            width: tile * 0.3,
            height: tile * 0.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                      palette.accent.withValues(alpha: 0.9), Colors.black87)
                  .withValues(alpha: 0.85),
            ),
          ),
        ),
      ));
    }
    for (final s in plan.captures) {
      final pos = _posOf(s);
      markers.add(Positioned(
        key: ValueKey('demo-capture-$s'),
        left: pos.col * tile,
        top: pos.row * tile,
        width: tile,
        height: tile,
        child: Center(
          child: Container(
            width: tile * 0.92,
            height: tile * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.alphaBlend(
                    palette.accent.withValues(alpha: 0.9), Colors.black87),
                width: tile * 0.06,
              ),
            ),
          ),
        ),
      ));
    }

    final enemyPieces = <Widget>[];
    for (final s in _enemies) {
      final pos = _posOf(s);
      enemyPieces.add(Positioned(
        left: pos.col * tile,
        top: pos.row * tile,
        width: tile,
        height: tile,
        child: IgnorePointer(
          child: Center(
            child: PieceWidget.static(
              assetKey: 'blackpawn',
              themeFolder: boardTheme.assetFolder,
              size: tile * 0.94,
            ),
          ),
        ),
      ));
    }

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.panelBorder, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Stack(
          children: [
            ...tiles,
            CustomPaint(
              size: Size(side, side),
              painter: _PathArrowPainter(
                tile: tile,
                from: piecePos,
                ends: plan.arrowEnds.map(_posOf).toList(),
                color: palette.accent,
              ),
            ),
            ...markers,
            ...enemyPieces,
            // The demonstration piece: glides between squares exactly like on
            // the real game board.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: piecePos.col * tile,
              top: piecePos.row * tile,
              width: tile,
              height: tile,
              child: Center(
                child: PieceWidget.static(
                  assetKey: widget.type.assetKey,
                  themeFolder: boardTheme.assetFolder,
                  size: tile * 0.94,
                ),
              ),
            ),
            ...hitTargets,
          ],
        ),
      ),
    );
  }
}

/// Draws accent arrows from the piece's square to the end of every movement
/// path, with a small arrowhead at the destination.
class _PathArrowPainter extends CustomPainter {
  const _PathArrowPainter({
    required this.tile,
    required this.from,
    required this.ends,
    required this.color,
  });

  final double tile;
  final ({int col, int row}) from;
  final List<({int col, int row})> ends;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tile * 0.085
      ..strokeCap = StrokeCap.round;

    final start = Offset(
      from.col * tile + tile / 2,
      from.row * tile + tile / 2,
    );

    for (final end in ends) {
      final endCenter = Offset(
        end.col * tile + tile / 2,
        end.row * tile + tile / 2,
      );
      // Shorten the line so it does not cover the piece or the arrowhead.
      final direction = (endCenter - start);
      if (direction.distance < tile * 0.9) continue;
      final unit = direction / direction.distance;
      final lineStart = start + unit * (tile * 0.55);
      final lineEnd = endCenter - unit * (tile * 0.16);
      canvas.drawLine(lineStart, lineEnd, paint);

      // Arrowhead.
      final headPaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      final tip = endCenter;
      final left = tip - unit * (tile * 0.34) + _perp(unit) * (tile * 0.13);
      final right = tip - unit * (tile * 0.34) - _perp(unit) * (tile * 0.13);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(path, headPaint);
    }
  }

  static Offset _perp(Offset unit) => Offset(-unit.dy, unit.dx);

  @override
  bool shouldRepaint(covariant _PathArrowPainter old) =>
      old.from != from || old.ends.length != ends.length || old.color != color;
}
