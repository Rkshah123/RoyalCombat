import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/game_state_model.dart' show HintMove;
import '../models/move_model.dart';
import '../services/settings_manager.dart';
import 'piece_widget.dart';

/// A fading, shrinking overlay copy of a just-captured piece.
class CaptureGhost {
  CaptureGhost({
    required this.id,
    required this.square,
    required this.type,
    required this.isWhite,
  });

  final String id;
  final String square;
  final String type;
  final bool isWhite;
}

/// The chess board: 64 themed tiles, animated pieces, move markers, check
/// pulse and hint glow. All interaction goes through [onTapSquare].
class ChessBoardWidget extends StatefulWidget {
  const ChessBoardWidget({
    super.key,
    required this.pieces,
    required this.whiteBottom,
    required this.selectedSquare,
    required this.displayTargets,
    required this.lastMove,
    required this.checkSquare,
    required this.hint,
    required this.captureGhosts,
    required this.onTapSquare,
    required this.inputEnabled,
    required this.animationsEnabled,
    // Arena look: no rank numbers / file letters on the board edge.
    this.showCoordinates = false,
  });

  final List<BoardPiece> pieces;
  final bool whiteBottom;
  final String? selectedSquare;
  final Map<String, bool> displayTargets;
  final MoveRecord? lastMove;
  final String? checkSquare;
  final HintMove? hint;
  final List<CaptureGhost> captureGhosts;
  final ValueChanged<String> onTapSquare;
  final bool inputEnabled;
  final bool animationsEnabled;
  final bool showCoordinates;

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy `late final` here would initialize the ticker
    // during dispose() (when no check/hint was ever shown) and crash.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// Runs the glow loop only while a check or hint highlight is on screen:
  /// an ever-repeating animation would also keep `pumpAndSettle` from ever
  /// finishing and waste battery otherwise.
  void _syncPulse() {
    final active = (widget.checkSquare != null || widget.hint != null) &&
        widget.animationsEnabled;
    if (active) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  String _squareAt(int col, int row) {
    final fileIdx = widget.whiteBottom ? col : 7 - col;
    final rank = widget.whiteBottom ? 8 - row : row + 1;
    return '${_files[fileIdx]}$rank';
  }

  ({int col, int row}) _positionOf(String square) {
    final fileIdx = _files.indexOf(square[0]);
    final rank = int.parse(square[1]);
    return (
      col: widget.whiteBottom ? fileIdx : 7 - fileIdx,
      row: widget.whiteBottom ? 8 - rank : rank - 1,
    );
  }

  void _handleTap(Offset local, double tileSize) {
    final col = (local.dx ~/ tileSize).clamp(0, 7);
    final row = (local.dy ~/ tileSize).clamp(0, 7);
    widget.onTapSquare(_squareAt(col, row));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final tile = side / 8;

        return GestureDetector(
          onTapUp:
              widget.inputEnabled ? (d) => _handleTap(d.localPosition, tile) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.panelBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.08),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildTiles(tile, palette),
                    ..._buildMoveMarkers(tile, palette),
                    if (widget.lastMove != null)
                      ..._buildLastMoveTrail(tile, palette),
                    _buildPieces(tile),
                    ..._ghosts(tile),
                    _buildHintOverlay(tile, palette),
                    _buildCheckOverlay(tile),
                    if (widget.selectedSquare != null)
                      _buildSelection(tile, palette),
                    if (widget.showCoordinates) _buildCoordinates(tile, palette),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- tiles --

  Widget _buildTiles(double tile, RoyalPalette palette) {
    final boardTheme = palette.theme;
    final children = <Widget>[];
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final square = _squareAt(col, row);
        final fileIdx = _files.indexOf(square[0]);
        final rank = int.parse(square[1]);
        final isLight = (fileIdx + rank) % 2 == 0;
        children.add(
          Positioned(
            left: col * tile,
            top: row * tile,
            width: tile,
            height: tile,
            child: ColoredBox(
              color: isLight ? boardTheme.lightSquare : boardTheme.darkSquare,
            ),
          ),
        );
      }
    }
    return Stack(children: children);
  }

  // ---------------------------------------------------------- move markers --

  List<Widget> _buildMoveMarkers(double tile, RoyalPalette palette) {
    if (widget.selectedSquare == null) return const [];
    final markers = <Widget>[];
    widget.displayTargets.forEach((square, isCapture) {
      final pos = _positionOf(square);
      final color = Color.alphaBlend(
        palette.accent.withValues(alpha: 0.9),
        Colors.black87,
      );
      if (isCapture) {
        markers.add(
          Positioned(
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
                  border: Border.all(color: color, width: tile * 0.06),
                ),
              ),
            ),
          ),
        );
      } else {
        markers.add(
          Positioned(
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
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        );
      }
    });
    return markers;
  }

  List<Widget> _buildLastMoveTrail(double tile, RoyalPalette palette) {
    final trail = <Widget>[];
    for (final square in [widget.lastMove!.from, widget.lastMove!.to]) {
      final pos = _positionOf(square);
      trail.add(
        Positioned(
          left: pos.col * tile,
          top: pos.row * tile,
          width: tile,
          height: tile,
          child: ColoredBox(
            color: palette.accent.withValues(alpha: 0.32),
          ),
        ),
      );
    }
    return trail;
  }

  Widget _buildSelection(double tile, RoyalPalette palette) {
    final pos = _positionOf(widget.selectedSquare!);
    return Positioned(
      left: pos.col * tile,
      top: pos.row * tile,
      width: tile,
      height: tile,
      child: Container(
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.22),
          border: Border.all(
            color: Color.alphaBlend(palette.accent, Colors.white),
            width: tile * 0.045,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- pieces  --

  Widget _buildPieces(double tile) {
    final children = <Widget>[];
    for (final piece in widget.pieces) {
      if (!piece.alive) continue;
      final pos = _positionOf(piece.square);
      final left = pos.col * tile;
      final top = pos.row * tile;
      final child = SizedBox(
        width: tile,
        height: tile,
        child: Center(
          child: PieceWidget(piece: piece, size: tile * 0.94),
        ),
      );
      if (widget.animationsEnabled) {
        children.add(
          AnimatedPositioned(
            key: ValueKey('anim-${piece.id}'),
            // 280ms ease-out-cubic: quick enough to stay responsive, long
            // enough to read as a glide rather than a snap. The cubic curve
            // starts fast and settles gently, so pieces never jump or hover.
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: left,
            top: top,
            width: tile,
            height: tile,
            child: IgnorePointer(child: child),
          ),
        );
      } else {
        children.add(
          Positioned(
            key: ValueKey('anim-${piece.id}'),
            left: left,
            top: top,
            width: tile,
            height: tile,
            child: IgnorePointer(child: child),
          ),
        );
      }
    }
    return IgnorePointer(
      child: Stack(children: children),
    );
  }

  List<Widget> _ghosts(double tile) {
    return widget.captureGhosts.map((ghost) {
      final pos = _positionOf(ghost.square);
      return Positioned(
        left: pos.col * tile,
        top: pos.row * tile,
        width: tile,
        height: tile,
        child: _CaptureGhostAnim(
          size: tile,
          type: ghost.type,
          isWhite: ghost.isWhite,
        ),
      );
    }).toList();
  }

  // ------------------------------------------------------ check & hint    --

  Widget _buildCheckOverlay(double tile) {
    final check = widget.checkSquare;
    if (check == null) return const SizedBox.shrink();
    final pos = _positionOf(check);
    return Positioned(
      left: pos.col * tile,
      top: pos.row * tile,
      width: tile,
      height: tile,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(
                        const Color(0x66E53935), const Color(0xF6E53935), t)!,
                    const Color(0x00E53935),
                  ],
                ),
                border: Border.all(
                  color: Color.lerp(
                      const Color(0x88E53935), const Color(0xE6E53935), t)!,
                  width: tile * 0.05,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHintOverlay(double tile, RoyalPalette palette) {
    final hint = widget.hint;
    if (hint == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [hint.from, hint.to].map((square) {
          final pos = _positionOf(square);
          return Positioned(
            left: pos.col * tile,
            top: pos.row * tile,
            width: tile,
            height: tile,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Container(
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.10 + 0.22 * t),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.4 + 0.5 * t),
                      width: tile * 0.05,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------- coordinates --

  Widget _buildCoordinates(double tile, RoyalPalette palette) {
    final style = TextStyle(
      fontSize: tile * 0.16,
      fontWeight: FontWeight.w700,
      color: palette.panelBorder,
      height: 1.0,
    );
    final children = <Widget>[];
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final square = _squareAt(col, row);
        final isLight = (_files.indexOf(square[0]) + int.parse(square[1])) % 2 == 0;
        final labelColor = isLight
            ? palette.theme.darkSquare.withValues(alpha: 0.85)
            : palette.theme.lightSquare.withValues(alpha: 0.85);
        // File letters on the bottom row.
        if (row == 7) {
          children.add(Positioned(
            left: col * tile + tile * 0.08,
            top: row * tile + tile * 0.70,
            child: Text(
              square[0].toUpperCase(),
              style: style.copyWith(color: labelColor),
            ),
          ));
        }
        // Rank numbers on the left column.
        if (col == 0) {
          children.add(Positioned(
            left: col * tile + tile * 0.06,
            top: row * tile + tile * 0.03,
            child: Text(
              square[1],
              style: style.copyWith(color: labelColor),
            ),
          ));
        }
      }
    }
    return IgnorePointer(child: Stack(children: children));
  }
}

class _CaptureGhostAnim extends StatelessWidget {
  const _CaptureGhostAnim({
    required this.size,
    required this.type,
    required this.isWhite,
  });

  final double size;
  final String type;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(
            scale: 1.0 - 0.75 * Curves.easeIn.transform(t),
            child: Center(
              child: PieceWidget.static(
                assetKey: '${isWhite ? 'white' : 'black'}$type',
                themeFolder: context.read<SettingsManager>().boardTheme.assetFolder,
                size: size * 0.94,
              ),
            ),
          ),
        );
      },
    );
  }
}
