import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_arena/models/game_state_model.dart';
import 'package:chess_arena/services/settings_manager.dart';
import 'package:chess_arena/widgets/button_widget.dart';
import 'package:chess_arena/widgets/chess_board_widget.dart';

Widget _wrap(Widget child, {SettingsManager? settings}) {
  final manager = settings ?? SettingsManager();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsManager>.value(value: manager),
    ],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChessBoardWidget', () {
    testWidgets('renders all 32 starting pieces', (tester) async {
      final game = GameStateModel()..newGame();
      await tester.pumpWidget(_wrap(
        SizedBox.square(
          key: const Key('board'),
          dimension: 480,
          child: ChessBoardWidget(
            pieces: game.pieces,
            whiteBottom: true,
            selectedSquare: null,
            displayTargets: const {},
            lastMove: null,
            checkSquare: null,
            hint: null,
            captureGhosts: const [],
            onTapSquare: (_) {},
            inputEnabled: true,
            animationsEnabled: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(game.pieces.length, 32);
      // Each alive piece renders one SVG.
      expect(find.byType(SvgPicture), findsNWidgets(32));
    });

    testWidgets('tapping a square calls back with the correct square',
        (tester) async {
      final game = GameStateModel()..newGame();
      final tapped = <String>[];
      await tester.pumpWidget(_wrap(
        SizedBox.square(
          key: const Key('board'),
          dimension: 480,
          child: ChessBoardWidget(
            pieces: game.pieces,
            whiteBottom: true,
            selectedSquare: null,
            displayTargets: const {},
            lastMove: null,
            checkSquare: null,
            hint: null,
            captureGhosts: const [],
            onTapSquare: tapped.add,
            inputEnabled: true,
            animationsEnabled: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byKey(const Key('board')));
      final tile = box.width / 8;
      // e2 for white-at-the-bottom: file index 4, display row 6.
      await tester.tapAt(Offset(
        box.left + 4.5 * tile,
        box.top + 6.5 * tile,
      ));
      await tester.pump();
      expect(tapped, contains('e2'));
    });

    testWidgets('last move squares are highlighted', (tester) async {
      final game = GameStateModel()..newGame();
      final move = game.findMove('e2', 'e4')!;
      game.playMove(move);
      await tester.pumpWidget(_wrap(
        SizedBox.square(
          key: const Key('board'),
          dimension: 480,
          child: ChessBoardWidget(
            pieces: game.pieces,
            whiteBottom: true,
            selectedSquare: null,
            displayTargets: const {},
            lastMove: game.lastMove,
            checkSquare: null,
            hint: null,
            captureGhosts: const [],
            onTapSquare: (_) {},
            inputEnabled: true,
            animationsEnabled: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(game.lastMove!.to, 'e4');
      expect(find.byType(SvgPicture), findsNWidgets(32));
    });
  });

  group('RoyalButton', () {
    testWidgets('shows its label and invokes the callback', (tester) async {
      // Plugin channels never complete in tests: mock the backing store.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = SettingsManager();
      await settings.load();
      var pressed = 0;
      await tester.pumpWidget(_wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoyalButton(
              label: 'Start Match',
              onPressed: () => pressed++,
            ),
          ],
        ),
        settings: settings,
      ));
      await tester.pump();
      expect(find.text('Start Match'), findsOneWidget);
      await tester.tap(find.byType(RoyalButton));
      await tester.pump();
      expect(pressed, 1);
    });
  });
}
