import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';
import '../widgets/piece_movement_demo.dart';
import 'learn_detail_screen.dart';

/// A single structured lesson shown on the Learn screen.
class Lesson {
  const Lesson({
    required this.title,
    required this.icon,
    required this.summary,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String summary;
  final List<LessonSection> sections;
}

class LessonSection {
  const LessonSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

const List<Lesson> kLessons = [
  Lesson(
    title: 'How the Pieces Move',
    icon: Icons.directions_walk_rounded,
    summary: 'The movement rules of all six pieces.',
    sections: [
      LessonSection(
        heading: 'Pawn',
        body:
            'Pawns move one square forward, or two squares on their very first move. '
            'They capture one square diagonally forward and can never move backwards. '
            'Pawns are the only pieces that capture differently from how they move.',
      ),
      LessonSection(
        heading: 'Knight',
        body:
            'The knight is the jumper of the army. It moves in an L-shape: two squares '
            'in one direction and one more at a right angle. Only the knight can leap '
            'over other pieces.',
      ),
      LessonSection(
        heading: 'Bishop',
        body:
            'Bishops glide any number of squares diagonally. Each bishop stays on one '
            'colour of squares for the entire game.',
      ),
      LessonSection(
        heading: 'Rook',
        body:
            'The rook travels any number of squares horizontally or vertically - '
            'straight lines only.',
      ),
      LessonSection(
        heading: 'Queen',
        body:
            'The most powerful piece: the queen combines the rook and the bishop, '
            'moving any number of squares in a straight line - across, up, down or '
            'diagonally.',
      ),
      LessonSection(
        heading: 'King',
        body:
            'The king moves one square in any direction. He can never move onto a '
            'square attacked by an enemy piece, and protecting him is the object of '
            'the game.',
      ),
    ],
  ),
  Lesson(
    title: 'Check, Checkmate & Stalemate',
    icon: Icons.local_fire_department_rounded,
    summary: 'How kings are attacked and games are won.',
    sections: [
      LessonSection(
        heading: 'Check',
        body:
            'A king is in check when it is attacked by an enemy piece. You must answer '
            'the check immediately: move the king, capture the attacker, or block the '
            'attack with another piece.',
      ),
      LessonSection(
        heading: 'Checkmate',
        body:
            'If the check cannot be answered by any legal move, the king is in '
            'checkmate and the game ends instantly. Royal Combat highlights your king '
            'with a red glow and plays a sting the moment a checkmate is delivered.',
      ),
      LessonSection(
        heading: 'Stalemate',
        body:
            'If a player is not in check but has no legal moves, the position is '
            'stalemate and the game is a draw - not a defeat for the stalemated side! '
            'This trap catches many beginners, so always leave your opponent a move.',
      ),
    ],
  ),
  Lesson(
    title: 'Special Moves',
    icon: Icons.auto_awesome_rounded,
    summary: 'Castling, en passant and promotion.',
    sections: [
      LessonSection(
        heading: 'Castling',
        body:
            'Once per game a king and rook may move together. The king slides two '
            'squares towards a rook and the rook jumps to the other side of the king. '
            'Castling is only legal when neither piece has moved, the squares between '
            'them are empty, and the king does not pass through - or land on - an '
            'attacked square.',
      ),
      LessonSection(
        heading: 'En passant',
        body:
            'French for "in passing". Immediately after an enemy pawn advances two '
            'squares past your pawn, you may capture it as if it had only advanced one '
            'square - but only on that very next move.',
      ),
      LessonSection(
        heading: 'Promotion',
        body:
            'When a pawn reaches the last rank it is promoted to a queen, rook, bishop '
            'or knight of your choice. Almost always the queen is best - Royal Combat '
            'shows a promotion picker the moment your pawn lands.',
      ),
    ],
  ),
  Lesson(
    title: 'Draws & Scoring',
    icon: Icons.balance_rounded,
    summary: 'Every way a game can end level.',
    sections: [
      LessonSection(
        heading: 'Stalemate & bare kings',
        body:
            'A stalemate is a draw, and so is a position where neither side can '
            'possibly deliver checkmate - for example king vs king, or king and '
            'bishop vs king.',
      ),
      LessonSection(
        heading: 'Threefold repetition',
        body:
            'If the exact same position appears three times in a game, either player '
            'may claim a draw. Royal Combat detects this automatically.',
      ),
      LessonSection(
        heading: 'Fifty-move rule',
        body:
            'If 50 consecutive moves pass with no capture and no pawn move, the game '
            'can be drawn. This prevents endless shuffling in hopeless positions.',
      ),
      LessonSection(
        heading: 'Material value',
        body:
            'Pieces are commonly valued: pawn 1, knight 3, bishop 3, rook 5, queen 9. '
            'Royal Combat live-updates a material badge (+3 etc.) next to the player '
            'panels so you can see who has won material at a glance.',
      ),
    ],
  ),
  Lesson(
    title: 'Chess Strategy Basics',
    icon: Icons.insights_rounded,
    summary: 'Five habits of strong players.',
    sections: [
      LessonSection(
        heading: 'Control the centre',
        body:
            'Opening with pawns towards the centre (e4, d4, e5, d5) controls the most '
            'important squares and gives your pieces room.',
      ),
      LessonSection(
        heading: 'Develop your pieces',
        body:
            'Bring knights and bishops off the back rank early. Avoid moving the same '
            'piece twice and never block your own centre pawns.',
      ),
      LessonSection(
        heading: 'Castle early',
        body:
            'Tuck your king behind a wall of pawns before launching an attack. An '
            'exposed king is the most common cause of lost games at every level.',
      ),
      LessonSection(
        heading: 'Don\'t hang pieces',
        body:
            'Before every move, look for what your opponent could capture for free. '
            'Use the Hint button in Royal Combat to have the engine double-check your '
            'plans while you learn.',
      ),
      LessonSection(
        heading: 'Think ahead',
        body:
            'Strong players follow the pattern: check the opponent\'s threats, list '
            'candidate moves, calculate the replies, then play. Even thinking one and '
            'a half moves deep beats moving instantly.',
      ),
    ],
  ),
];

/// Learn Chess hub - the lesson library plus the interactive
/// "Learn How Pieces Move" demonstrations.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  /// Shared, highly readable screen-title style (headings only).
  static TextStyle _screenTitle(RoyalPalette palette) => TextStyle(
        fontFamily: 'Algerian',
        fontSize: 28,
        letterSpacing: 1.8,
        color: palette.accent,
        shadows: [
          Shadow(
            color: palette.accent.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
                          onPressed: () {
                            SoundManager.instance.tap();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Learn Chess',
                          style: _screenTitle(palette),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      children: [
                        // --------------------------------- piece movement demos --
                        Text(
                          'LEARN HOW PIECES MOVE',
                          style: TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w800,
                            color: Color.alphaBlend(
                                palette.accent.withValues(alpha: 0.55),
                                palette.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final type in DemoPieceType.values) ...[
                          PieceMovementDemo(type: type),
                          const SizedBox(height: 14),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'LESSON LIBRARY',
                          style: TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w800,
                            color: Color.alphaBlend(
                                palette.accent.withValues(alpha: 0.55),
                                palette.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final lesson in kLessons) ...[
                          _lessonCard(context, palette, lesson),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lessonCard(BuildContext context, RoyalPalette palette, Lesson lesson) {
    return GestureDetector(
      onTap: () {
        SoundManager.instance.tap();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => LearnDetailScreen(lesson: lesson),
            transitionsBuilder: (_, a, _, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.panel.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.alphaBlend(palette.accentSoft, palette.panel),
                border: Border.all(
                    color: palette.panelBorder.withValues(alpha: 0.5)),
              ),
              child: Icon(lesson.icon, color: palette.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.summary,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
