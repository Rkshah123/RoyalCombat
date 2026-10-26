import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart';
import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/button_widget.dart';
import '../widgets/piece_widget.dart';
import 'main_menu.dart';
import 'setup_screen.dart';

/// Post-match screen with the result, stats and rematch shortcuts.
/// Also owns the single victory/defeat sting for the finished match, so the
/// sound fires exactly once per result and never overlaps the elimination
/// sting that already played on the board.
class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key, required this.result, this.humanWon});

  final GameResult result;

  /// true → the local player won, false → they lost, null → a draw (or the
  /// winner is a second human in Pass & Play, which still celebrates).
  final bool? humanWon;

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  @override
  void initState() {
    super.initState();
    // Small delay: the screen fades in over ~600ms and the elimination sting
    // (checkmate/resignation) has just played — don't pile sounds on top.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      SoundManager.instance.play(switch (widget.humanWon) {
        true => Sfx.victory,
        false => Sfx.defeat,
        null => Sfx.popWindow,
      }, volume: widget.humanWon == null ? 0.5 : 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final (title, subtitle) = _titles(widget.result);
    final result = widget.result;

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ResultCrest(palette: palette, result: result),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Algerian',
                        fontSize: 40,
                        letterSpacing: 2,
                        color: result.isDraw ? palette.textPrimary : palette.accent,
                        shadows: [
                          Shadow(
                            color: palette.accent.withValues(alpha: 0.35),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _statsCard(palette),
                    const SizedBox(height: 28),
                    RoyalButton(
                      label: 'Rematch',
                      icon: Icons.replay_rounded,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(_route(const SetupScreen(initialMode: GameMode.vsComputer)));
                      },
                    ),
                    const SizedBox(height: 10),
                    RoyalButton(
                      label: 'New Game Setup',
                      secondary: true,
                      icon: Icons.tune_rounded,
                      onPressed: () => Navigator.of(context).pushReplacement(_route(const SetupScreen(initialMode: GameMode.vsComputer))),
                    ),
                    const SizedBox(height: 10),
                    RoyalButton(
                      label: 'Main Menu',
                      secondary: true,
                      icon: Icons.home_outlined,
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        _route(const MainMenuScreen()),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _titles(GameResult result) {
    if (result.isDraw) {
      return ('Draw', _reasonText(result.reason));
    }
    final winner = result.whiteWon == true ? 'White' : 'Black';
    return ('$winner wins!', '${result.winnerName} won by ${_reasonText(result.reason)}');
  }

  String _reasonText(GameEndReason reason) {
    switch (reason) {
      case GameEndReason.checkmate:
        return 'checkmate';
      case GameEndReason.stalemate:
        return 'stalemate';
      case GameEndReason.timeout:
        return 'timeout';
      case GameEndReason.resignation:
        return 'resignation';
      case GameEndReason.drawAgreed:
        return 'agreement';
      case GameEndReason.insufficientMaterial:
        return 'insufficient material';
      case GameEndReason.threefoldRepetition:
        return 'threefold repetition';
      case GameEndReason.fiftyMoveRule:
        return 'the fifty-move rule';
    }
  }

  Widget _statsCard(RoyalPalette palette) {
    final result = widget.result;
    final rows = <(String, String)>[
      ('Result', result.isDraw ? '½ – ½' : result.whiteWon == true ? '1 – 0' : '0 – 1'),
      ('Reason', _reasonText(result.reason)),
      ('Moves', '${(result.moveCount / 2).ceil()} played'),
      ('Duration', _format(result.duration)),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      k,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    v,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  PageRouteBuilder _route(Widget page) => PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      );
}

/// Trophy crest that scales and glows on entry.
class _ResultCrest extends StatefulWidget {
  const _ResultCrest({required this.palette, required this.result});

  final RoyalPalette palette;
  final GameResult result;

  @override
  State<_ResultCrest> createState() => _ResultCrestState();
}

class _ResultCrestState extends State<_ResultCrest>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ScaleTransition(
      scale: CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.result.isDraw ? palette.panelBorder : palette.accent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.result.isDraw ? palette.panelBorder : palette.accent)
                  .withValues(alpha: 0.4),
              blurRadius: 34,
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Center(
          child: PieceWidget.static(
            assetKey: widget.result.isDraw
                ? 'whiteking'
                : (widget.result.whiteWon == true ? 'whiteking' : 'blackking'),
            themeFolder: palette.theme.assetFolder,
            size: double.infinity,
          ),
        ),
      ),
    );
  }
}
