import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart';
import '../services/settings_manager.dart';

/// Renders one piece from the active board theme's bundled SVG set.
class PieceWidget extends StatelessWidget {
  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
  });

  final BoardPiece piece;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsManager>().boardTheme;
    return PieceWidget.static(
      assetKey: piece.assetKey,
      themeFolder: theme.assetFolder,
      size: size,
    );
  }

  /// A variant that does not depend on provider, usable in dialogs and tests.
  static Widget static({
    Key? key,
    required String assetKey,
    required String themeFolder,
    required double size,
  }) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/pieces/$themeFolder/$assetKey.svg',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Small static symbol used in the captured-piece tray.
class CapturedPieceIcon extends StatelessWidget {
  const CapturedPieceIcon({
    super.key,
    required this.type,
    required this.isWhite,
    required this.themeFolder,
    this.size = 18,
  });

  final String type;
  final bool isWhite;
  final String themeFolder;
  final double size;

  @override
  Widget build(BuildContext context) {
    const typeNames = <String, String>{
      'p': 'pawn',
      'n': 'knight',
      'b': 'bishop',
      'r': 'rook',
      'q': 'queen',
      'k': 'king',
    };
    return SvgPicture.asset(
      'assets/pieces/$themeFolder/'
          '${isWhite ? 'white' : 'black'}${typeNames[type] ?? type}.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
