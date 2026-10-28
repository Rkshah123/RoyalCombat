import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:chess/chess.dart' as ch;

import 'package:provider/provider.dart';

import '../models/game_state_model.dart';
import '../models/move_model.dart';
import '../models/player_model.dart';
import '../services/chess_ai.dart';
import '../services/match_history_service.dart';
import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../services/timer_manager.dart';
import '../widgets/button_widget.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/piece_widget.dart';
import '../widgets/timer_widget.dart';
import 'game_over_screen.dart';
import 'main_menu.dart';

/// The live match screen: annotated animated board, player panels with
/// clocks, move history and the control bar.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    required this.humanSide,
    required this.white,
    required this.black,
    required this.time,
    required this.increment,
  });

  final GameMode mode;
  final PlayerInfo humanSide;
  final PlayerInfo white;
  final PlayerInfo black;
  final Duration time;
  final Duration increment;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final GameStateModel _game = GameStateModel();
  final TimerManager _timers = TimerManager();
  final ScrollController _historyController = ScrollController();

  bool _whiteBottom = true;
  String? _selected;
  Map<String, bool> _targets = {};
  bool _aiThinking = false;
  HintMove? _hint;
  Timer? _hintTimer;
  final List<CaptureGhost> _ghosts = [];
  Timer? _ghostTimer;
  bool _finished = false;
  bool _showHistory = false;

  /// Match-start choreography: the two players slide toward each other while
  /// the starting sting plays. Runs once per freshly started match.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  PlayerInfo get white => widget.white;
  PlayerInfo get black => widget.black;

  PlayerInfo get activePlayer {
    if (_game.isWhiteTurn) return white;
    return black;
  }

  PlayerInfo get localPlayer => widget.humanSide;

  bool get humanTurn =>
      (widget.mode == GameMode.passAndPlay) ||
      (!(localPlayer.isAi) && _game.isWhiteTurn == localPlayer.isWhite);

  @override
  void initState() {
    super.initState();
    _game.newGame();
    _timers.configure(widget.time, widget.increment);
    _timers.onTimeout = _onTimeout;
    _whiteBottom = localPlayer.isWhite;
    // The starting fanfare is NOT played here anymore: it now belongs to the
    // application launch (splash opening animation), per the sound design.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entry.forward();
      _timers.start(whiteFirst: true);
      _maybeAiTurn();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _timers.disposeTimer();
    _timers.dispose();
    _hintTimer?.cancel();
    _ghostTimer?.cancel();
    _historyController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- movement --

  void _onSquareTap(String square) {
    if (_finished || _aiThinking) return;
    if (_selected != null && _targets.containsKey(square)) {
      _commitPlayerMove(_selected!, square);
      return;
    }
    final piece = _game.pieces
        .where((p) => p.alive && p.square == square)
        .firstOrNull;
    if (piece == null) {
      _clearSelection();
      setState(() {});
      return;
    }
    if (piece.isWhite != _game.isWhiteTurn || !humanTurn) {
      _clearSelection();
      setState(() {});
      return;
    }
    _selected = square;
    _targets = _game.legalTargetsFrom(square);
    SoundManager.instance.play(Sfx.uiTap, volume: 0.3);
    setState(() {});
  }

  void _clearSelection() {
    _selected = null;
    _targets = {};
  }

  Future<void> _commitPlayerMove(String from, String to) async {
    final candidates = _game.promotionCandidates(from, to);
    String? promotion;
    if (candidates.isNotEmpty) {
      promotion = await _askPromotion(candidates.first.color == ch.Color.WHITE);
      _clearSelection();
      setState(() {});
      if (promotion == null) return;
    }
    _clearSelection();
    final move = _game.findMove(from, to, promotion: promotion);
    if (move == null) return;
    await _applyMove(move);
  }

  Future<void> _applyMove(ch.Move move) async {
    final played = _game.playMove(move);
    if (played == null) return;

    setState(() {
      if (played.ghostSquare != null) {
        final ghost = CaptureGhost(
          id: 'ghost-${DateTime.now().microsecondsSinceEpoch}',
          square: played.ghostSquare!,
          type: played.ghostType,
          isWhite: played.ghostWhite,
        );
        _ghosts.add(ghost);
        _ghostTimer?.cancel();
        _ghostTimer = Timer(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => _ghosts.removeWhere((g) => g.id == ghost.id));
          }
        });
      }

      // Sounds: an elimination (checkmate = a player goes down) gets its own
      // sting; captures and plain moves get theirs; check adds a warning.
      if (played.record.isMate) {
        SoundManager.instance.play(Sfx.elimination, volume: 1.0, rate: 0.8);
      } else if (played.record.isCheck) {
        SoundManager.instance.play(Sfx.check);
      } else if (played.record.isCapture) {
        SoundManager.instance.play(Sfx.capture, volume: 0.95);
      } else {
        SoundManager.instance.play(Sfx.move);
      }
      _timers.switchTurn(whiteNowActive: _game.isWhiteTurn);
    });

    _scrollHistory();
    await Future.delayed(const Duration(milliseconds: 60));
    _checkEndConditions();
    if (mounted && !_finished) {
      _maybeAiTurn();
    }
  }

  // ------------------------------------------------------------------ AI  --

  Future<void> _maybeAiTurn() async {
    if (_finished) return;
    final mover = activePlayer;
    if (!mover.isAi) return;
    setState(() => _aiThinking = true);

    final fen = _game.fen;
    final depth = mover.difficulty?.searchDepth ?? 2;
    final blunderChance = switch (mover.difficulty) {
      Difficulty.easy => 0.35,
      Difficulty.medium => 0.06,
      _ => 0.0,
    };

    // The computer ponders for a short, human-feeling beat: at most half a
    // second. If the search finishes sooner we hold the position until the
    // full think window has elapsed; a slower search is never padded.
    const thinkWindow = Duration(milliseconds: 450);
    final startedAt = DateTime.now();
    final result = await compute(aiThink, <String, dynamic>{
      'fen': fen,
      'depth': depth,
      'blunderChance': blunderChance,
    });
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < thinkWindow) {
      await Future.delayed(thinkWindow - elapsed);
    }

    if (!mounted) return;
    setState(() => _aiThinking = false);
    if (_finished || result.isEmpty) {
      // Extremely defensive: nothing sensible to play. Let the game end
      // naturally elsewhere.
      return;
    }
    final move = _game.findMove(
      result['from']!,
      result['to']!,
      promotion: result['promotion'],
    );
    if (move == null) return;
    await _applyMove(move);
  }

  Future<void> _showHint() async {
    if (_finished || _aiThinking || !humanTurn) return;
    SoundManager.instance.play(Sfx.uiTap);
    setState(() => _hint = null);
    final fen = _game.fen;
    final result = await compute(aiThink, <String, dynamic>{
      'fen': fen,
      'depth': 3,
      'blunderChance': 0.0,
    });
    if (!mounted || _finished) return;
    if (result.isEmpty) return;
    setState(() {
      _hint = HintMove(result['from'] as String, result['to'] as String);
      _selected = null;
      _targets = {};
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  // ------------------------------------------------------------ undo / etc --

  Future<void> _undo() async {
    if (_aiThinking || _game.history.isEmpty || _finished) return;
    SoundManager.instance.play(Sfx.uiTap);

    var plies = 1;
    if (widget.mode == GameMode.vsComputer) {
      // On the human's turn the last move always belongs to the computer;
      // roll back that pair so the human plays again.
      plies = 2;
      if (plies > _game.history.length) plies = _game.history.length;
    }
    for (var i = 0; i < plies && _game.history.isNotEmpty; i++) {
      _game.undoPly();
    }
    _clearSelection();
    setState(() {
      _hint = null;
      _ghosts.clear();
    });
    _timers.setActiveTurn(_game.isWhiteTurn);
    // If after undo it is the AI to move (can happen when only one ply
    // existed), let it respond.
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) _maybeAiTurn();
  }

  Future<void> _flip() async {
    SoundManager.instance.play(Sfx.uiTap);
    setState(() => _whiteBottom = !_whiteBottom);
  }

  Future<void> _resign() async {
    if (_finished) return;
    final palette = context.read<SettingsManager>().palette;
    SoundManager.instance.play(Sfx.popWindow);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RoyalDialog(
        palette: palette,
        title: 'Resign the match?',
        body: 'Your opponent will be declared the winner.',
        actions: [
          DialogActionButton(
            palette: palette,
            label: 'Keep playing',
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          DialogActionButton(
            palette: palette,
            label: 'Resign',
            danger: true,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _endGame(
      reason: GameEndReason.resignation,
      whiteWon: null,
      resignedSide: _game.isWhiteTurn,
    );
  }

  /// Was insufficient material offered to the winner? (FIDE timeout rule)
  bool _winnerLacksMatingMaterial(bool winnerIsWhite) {
    var material = 0;
    for (final p in _game.pieces) {
      if (!p.alive || !p.isWhite == winnerIsWhite) continue;
      if (p.type == 'k') continue;
      material++;
    }
    return material == 0 || material == 1;
  }

  void _onTimeout(bool whiteFlagged) {
    if (_finished) return;
    // The winner must have mating material, otherwise it is a draw.
    if (_winnerLacksMatingMaterial(!whiteFlagged)) {
      _endGame(reason: GameEndReason.timeout, whiteWon: null);
    } else {
      _endGame(reason: GameEndReason.timeout, whiteWon: !whiteFlagged);
    }
  }

  void _checkEndConditions() {
    if (_finished) return;
    if (_game.isCheckmate) {
      _endGame(
        reason: GameEndReason.checkmate,
        whiteWon: !_game.isWhiteTurn,
      );
      return;
    }
    if (_game.isStalemate) {
      _endGame(reason: GameEndReason.stalemate, whiteWon: null);
      return;
    }
    if (_game.insufficientMaterial) {
      _endGame(reason: GameEndReason.insufficientMaterial, whiteWon: null);
      return;
    }
    if (_game.threefoldRepetition) {
      _endGame(reason: GameEndReason.threefoldRepetition, whiteWon: null);
      return;
    }
    if (_game.fiftyMoveRule) {
      _endGame(reason: GameEndReason.fiftyMoveRule, whiteWon: null);
      return;
    }
  }

  void _endGame({
    required GameEndReason reason,
    required bool? whiteWon,
    bool? resignedSide,
  }) {
    if (_finished) return;
    _finished = true;
    _timers.stop();
    _clearSelection();
    if (reason == GameEndReason.resignation) {
      // The resigning side loses.
      whiteWon = !(resignedSide ?? true);
    }

    final result = MatchHistoryService.buildResult(
      reason: reason,
      whiteWon: whiteWon,
      state: _game,
      white: white,
      black: black,
    );

    final humanWon = widget.mode == GameMode.passAndPlay
        ? result.whiteWon != null
        : (result.whiteWon == null ? null : (result.whiteWon == localPlayer.isWhite));

    // Resignation is a concession, not a move: play the elimination sting here
    // because no move sound (capture/checkmate) already covered the moment.
    // The victory/defeat sting itself is played once by the game-over screen.
    if (reason == GameEndReason.resignation && whiteWon != null) {
      SoundManager.instance.play(Sfx.elimination, volume: 1.0, rate: 0.8);
    }

    context.read<MatchHistoryService>().addFromResult(
          mode: widget.mode,
          result: result,
          white: white,
          black: black,
          timeControl: _timeControlLabel(),
        );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => GameOverScreen(
          result: result,
          humanWon: humanWon,
        ),
        transitionsBuilder: (_, animation, _, child) {
          final scaled = CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: scaled,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(scaled),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  String _timeControlLabel() {
    if (widget.time <= Duration.zero) return 'No clock';
    final m = widget.time.inMinutes;
    final inc = widget.increment.inSeconds;
    return inc == 0 ? '$m min' : '$m min + $inc';
  }

  void _scrollHistory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_historyController.hasClients) return;
      _historyController.animateTo(
        _historyController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ----------------------------------------------------------------- build --

  String _materialBadge(bool isWhite) {
    final diff = _game.materialDiff();
    final mine = isWhite ? diff : -diff;
    if (mine <= 0) return '';
    return '+$mine';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    final palette = settings.palette;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.bgTop, palette.bgBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    child: _boardColumn(palette, settings, wide: true),
                  ),
                  SizedBox(
                    width: 340,
                    child: _sidePanel(palette, settings),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: _boardColumn(palette, settings),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _showHistory
                      ? _historyPanel(palette, compact: true)
                      : const SizedBox.shrink(),
                ),
                _controlBar(palette),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _boardColumn(RoyalPalette palette, SettingsManager settings,
      {bool wide = false}) {
    final board = AspectRatio(
      aspectRatio: 1,
      child: ChessBoardWidget(
        pieces: _game.pieces,
        whiteBottom: _whiteBottom,
        selectedSquare: _selected,
        displayTargets:
            settings.showLegalMoves ? _targets : const {},
        lastMove: _game.lastMove,
        checkSquare: _game.checkSquare,
        hint: _hint,
        captureGhosts: _ghosts,
        onTapSquare: _onSquareTap,
        inputEnabled: !_finished && !_aiThinking && humanTurn,
        animationsEnabled: settings.pieceAnimations,
      ),
    );

    final animatedBoard = _showEntry(
      board,
      scaleFrom: 0.9,
      curve: Curves.easeOutCubic,
    );

    if (wide) {
      // Wide layout: both players and their clocks already live in the side
      // panel, so repeating them here would only steal height from the board.
      // Give the board the full column instead and let the AspectRatio keep
      // it perfectly square and centered.
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Center(child: animatedBoard),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // The two players approach the board: the top one slides down and
          // the bottom one slides up while the starting sting plays.
          _showEntry(
            _playerPanel(
              palette: palette,
              settings: settings,
              player: _topPlayer,
              isWhite: _topPlayer.isWhite,
              compact: false,
            ),
            slideFrom: const Offset(0, -0.9),
          ),
          const SizedBox(height: 10),
          // Center loosens the tight Expanded constraints so AspectRatio can
          // keep the board perfectly square (a stretched frame otherwise
          // leaves an empty band below the grid).
          Expanded(
            child: Center(child: animatedBoard),
          ),
          const SizedBox(height: 10),
          _showEntry(
            _playerPanel(
              palette: palette,
              settings: settings,
              player: _bottomPlayer,
              isWhite: _bottomPlayer.isWhite,
              compact: false,
            ),
            slideFrom: const Offset(0, 0.9),
          ),
        ],
      ),
    );
  }

  /// Entrance wrapper for the match-start choreography. Only active while
  /// [_entry] is running; afterwards children render statically.
  Widget _showEntry(
    Widget child, {
    Offset slideFrom = Offset.zero,
    double scaleFrom = 1.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    final curved = CurvedAnimation(parent: _entry, curve: curve);
    Widget result = AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        Widget inner = slideFrom == Offset.zero
            ? child
            : SlideTransition(
                position: Tween<Offset>(begin: slideFrom, end: Offset.zero)
                    .animate(curved),
                child: child,
              );
        if (scaleFrom != 1.0) {
          inner = ScaleTransition(
            scale: Tween<double>(begin: scaleFrom, end: 1.0).animate(curved),
            child: inner,
          );
        }
        return FadeTransition(opacity: curved, child: inner);
      },
    );
    // Once the entrance finished, plain children avoid extra repaint work.
    if (_entry.isCompleted) result = child;
    return result;
  }

  PlayerInfo get _topPlayer =>
      _whiteBottom ? black : white;

  PlayerInfo get _bottomPlayer =>
      _whiteBottom ? white : black;

  Widget _sidePanel(RoyalPalette palette, SettingsManager settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.panelBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            _showEntry(
              _playerPanel(
                palette: palette,
                settings: settings,
                player: _topPlayer,
                isWhite: _topPlayer.isWhite,
                compact: true,
              ),
              slideFrom: const Offset(0, -0.9),
            ),
            const SizedBox(height: 10),
            Expanded(child: _showEntry(_historyPanel(palette, compact: false))),
            const SizedBox(height: 10),
            _showEntry(
              _playerPanel(
                palette: palette,
                settings: settings,
                player: _bottomPlayer,
                isWhite: _bottomPlayer.isWhite,
                compact: true,
              ),
              slideFrom: const Offset(0, 0.9),
            ),
            const SizedBox(height: 10),
            _showEntry(_controlBar(palette, vertical: true)),
          ],
        ),
      ),
    );
  }

  Widget _playerPanel({
    required RoyalPalette palette,
    required SettingsManager settings,
    required PlayerInfo player,
    required bool isWhite,
    required bool compact,
  }) {
    final isActive = _game.isWhiteTurn == isWhite && !_finished;
    final captured = isWhite ? _game.capturedByWhite : _game.capturedByBlack;
    final themeFolder = palette.theme.assetFolder;
    final materialBadge = _materialBadge(isWhite);

    final capturedRow = Row(
      children: [
        if (player.isAi) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: palette.panelBorder.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              player.difficulty?.label ?? 'AI',
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 9 : 10.5,
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final type in _sortCaptured(captured))
                CapturedPieceIcon(
                  type: type,
                  isWhite: !isWhite,
                  themeFolder: themeFolder,
                  size: compact ? 15 : 20,
                ),
            ],
          ),
        ),
      ],
    );

    final name = Row(
      children: [
        Container(
          width: compact ? 22 : 26,
          height: compact ? 22 : 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(palette.accentSoft, palette.panel),
            border: Border.all(
              color: isActive ? palette.accent : palette.panelBorder,
              width: 1.4,
            ),
          ),
          child: Text(
            isWhite ? 'W' : 'B',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11 : 13,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            player.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? Color.alphaBlend(palette.accentSoft, palette.panel)
            : palette.panel.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: isActive ? palette.accent : palette.panelBorder.withValues(alpha: 0.5),
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    name,
                    const SizedBox(width: 6),
                    if (_aiThinking && player.isAi) ThinkingIndicator(),
                  ],
                ),
                const SizedBox(height: 4),
                capturedRow,
              ],
            ),
          ),
          if (materialBadge.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                materialBadge,
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          // The clock repaints itself on every timer tick so it counts down
          // in real time, even while nothing else on the screen changes.
          AnimatedBuilder(
            animation: _timers,
            builder: (context, _) => TimerWidget(
              isWhite: isWhite,
              label: player.name,
              isActive: isActive,
              remaining:
                  isWhite ? _timers.whiteRemaining : _timers.blackRemaining,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _sortCaptured(List<String> captured) {
    final copy = [...captured];
    copy.sort((a, b) => ChessHelpers.materialValue(b)
        .compareTo(ChessHelpers.materialValue(a)));
    return copy;
  }

  Widget _historyPanel(RoyalPalette palette, {required bool compact}) {
    final records = _game.history;
    final children = <Widget>[];
    for (var i = 0; i < records.length; i += 2) {
      final moveNo = i ~/ 2 + 1;
      final whiteMove = records[i];
      final blackMove = i + 1 < records.length ? records[i + 1] : null;
      final isCurrentWhite = records.length - 1 == i;
      final isCurrentBlack = blackMove != null && records.length - 1 == i + 1;
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 26 : 32,
                child: Text(
                  '$moveNo.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: compact ? 11 : 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: _moveChip(
                  whiteMove.san,
                  palette,
                  highlight: isCurrentWhite,
                  compact: compact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _moveChip(
                  blackMove?.san ?? '',
                  palette,
                  highlight: isCurrentBlack,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget list;
    if (children.isEmpty) {
      list = Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            'Move history appears here',
            style: TextStyle(
              color: palette.textSecondary.withValues(alpha: 0.7),
              fontSize: compact ? 11.5 : 13,
            ),
          ),
        ),
      );
    } else {
      list = SingleChildScrollView(
        controller: _historyController,
        child: Column(children: children),
      );
    }

    return Container(
      height: compact ? double.infinity : 118,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.5)),
      ),
      child: list,
    );
  }

  Widget _moveChip(String san, RoyalPalette palette,
      {required bool highlight, required bool compact}) {
    if (san.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: highlight
            ? palette.accent.withValues(alpha: 0.25)
            : palette.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        san,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: compact ? 11.5 : 13.5,
          fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _controlBar(RoyalPalette palette, {bool vertical = false}) {
    final buttons = <(IconData, String, VoidCallback)>[
      (Icons.undo_rounded, 'Undo', () => _undo()),
      (Icons.lightbulb_outline, 'Hint', () => _showHint()),
      (Icons.swap_vert_rounded, 'Flip', () => _flip()),
      (Icons.history_edu_rounded, 'Moves',
          vertical ? () => setState(() => _showHistory = !_showHistory) : () {}),
      (Icons.flag_outlined, 'Resign', () => _resign()),
      (Icons.close_rounded, 'Exit', () => _exitGame()),
    ];

    final enabled = <(IconData, String, VoidCallback)>[];
    for (final b in buttons) {
      final (icon, label, onTap) = b;
      final isUndo = label == 'Undo';
      final isMoves = label == 'Moves';
      final isHint = label == 'Hint';
      if (isMoves && vertical) {
        // The side panel already shows history; hide the toggle there.
        enabled.add((icon, label, () {}));
        continue;
      }
      enabled.add((
        icon,
        label,
        (isUndo && (_game.history.isEmpty || _aiThinking || _finished)) ||
                (isHint && (vertical || _aiThinking || _finished || !humanTurn))
            ? () {}
            : onTap
      ));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in enabled)
          _ControlIcon(
            palette: palette,
            icon: entry.$1,
            label: entry.$2,
            onTap: entry.$3,
            disabled: entry.$3 == (() {}),
          ),
      ],
    );
  }

  Future<void> _exitGame() async {
    if (_finished) return;
    final palette = context.read<SettingsManager>().palette;
    // Exiting an ONGOING match is a destructive action: instead of the old
    // click/pop sound, a short warning sting plays here (only while the game
    // is actually running, and only if sounds are enabled).
    SoundManager.instance.exitWarning();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => _RoyalDialog(
        palette: palette,
        title: 'Leave the match?',
        body: 'Ongoing progress will be abandoned and the game paused.',
        actions: [
          DialogActionButton(
            palette: palette,
            label: 'Stay',
            onTap: () => Navigator.of(ctx).pop('stay'),
          ),
          DialogActionButton(
            palette: palette,
            label: 'Abandon match',
            danger: true,
            onTap: () => Navigator.of(ctx).pop('exit'),
          ),
        ],
      ),
    );
    if (choice == 'exit') {
      _timers.stop();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const MainMenuScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 420),
        ),
      );
    }
  }

  Future<String?> _askPromotion(bool white) async {
    final settings = context.read<SettingsManager>();
    SoundManager.instance.play(Sfx.popWindow);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: settings.palette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: settings.palette.panelBorder),
        ),
        title: Text(
          'Promote pawn',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Algerian',
            color: settings.palette.accent,
            fontSize: 22,
          ),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (_, key) in [
              ('Queen', 'q'),
              ('Rook', 'r'),
              ('Bishop', 'b'),
              ('Knight', 'n'),
            ])
              GestureDetector(
                onTap: () {
                  SoundManager.instance.tap();
                  Navigator.of(ctx).pop(key);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PieceWidget.static(
                        assetKey: '${white ? 'white' : 'black'}$key',
                        themeFolder: settings.palette.theme.assetFolder,
                        size: 44,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.disabled,
  });

  final RoyalPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    SoundManager.instance.updateFromSettings(context);
    return GestureDetector(
      onTap: disabled ? null : () {
        // Every UI control answers with the same tap sound.
        SoundManager.instance.tap();
        onTap();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.4 : 1.0,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 40,
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.panel.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.panelBorder, width: 1),
                ),
                child: Icon(icon, size: 19, color: palette.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared dialog shells and buttons.
class _RoyalDialog extends StatelessWidget {
  const _RoyalDialog({
    required this.palette,
    required this.title,
    required this.body,
    required this.actions,
  });

  final RoyalPalette palette;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.panelBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Algerian',
                fontSize: 21,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: actions
                  .map((w) => Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: w,
                      )))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class DialogActionButton extends StatelessWidget {
  const DialogActionButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final RoyalPalette palette;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return RoyalButton(
      label: label,
      secondary: !danger,
      narrow: true,
      fontSize: 13.5,
      onPressed: onTap,
    );
  }
}
