import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';

/// Full-screen arena artwork used behind every non-game panel (menu, setup,
/// Learn, Match History, Settings, splash).
///
/// The image covers the entire screen with `BoxFit.cover` and centered
/// alignment: the natural aspect ratio is preserved, overflow is cropped
/// symmetrically, nothing is stretched. A translucent theme scrim sits on top
/// so buttons, text, icons and panels stay readable in every board theme while
/// the artwork remains clearly visible.
///
/// The gameplay screen (and the match-result flow) deliberately do NOT use
/// this widget: the artwork is completely absent behind the chessboard during
/// a match and reappears automatically as soon as any non-game route is shown,
/// because every route paints its own background.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.scrimTop = 0.62,
    this.scrimBottom = 0.80,
  });

  final Widget child;

  /// Scrim strength at the top / bottom of the screen (palette tint over the
  /// artwork). Kept translucent so the image stays visible everywhere.
  final double scrimTop;
  final double scrimBottom;

  static const String assetPath = 'assets/images/background.png';

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return ColoredBox(
      color: palette.bgBottom,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.bgTop.withValues(alpha: scrimTop),
                  palette.bgBottom.withValues(alpha: scrimBottom),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
