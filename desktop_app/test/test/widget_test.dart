import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_arena/models/game_state_model.dart';
import 'package:chess_arena/services/settings_manager.dart';
import 'package:chess_arena/widgets/button_widget.dart';
import 'package:chess_arena/widgets/chess_board_widget.dart';
import 'package:chess_arena/widgets/piece_movement_demo.dart';

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

  group('Piece SVG assets', () {
    test('no SVG relies on unsupported <style> class fills', () {
      // flutter_svg cannot parse <style> elements: class-based fills would
      // silently fall back to black. All piece art must use inline fills.
      final svgFiles = <String>[];
      for (final theme in ['woodtheme', 'greentheme', 'blacktheme']) {
        final dir = Directory('assets/pieces/$theme');
        if (dir.existsSync()) {
          svgFiles.addAll(
            dir.listSync().whereType<File>().map((f) => f.path),
          );
        }
      }
      expect(svgFiles, isNotEmpty);
      for (final path in svgFiles) {
        expect(
          File(path).readAsStringSync().contains('<style'),
          isFalse,
          reason: '$path uses unsupported <style> class fills',
        );
      }
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

  group('PieceMovementDemo', () {
    Future<void> pumpDemo(WidgetTester tester, DemoPieceType type) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = SettingsManager();
      await settings.load();
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 360,
          child: PieceMovementDemo(type: type),
        ),
        settings: settings,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('pawn shows forward moves and diagonal capture rings',
        (tester) async {
      await pumpDemo(tester, DemoPieceType.pawn);
      // Two forward squares + two diagonal capture dummies.
      expect(find.byKey(const Key('demo-move-e3')), findsOneWidget);
      expect(find.byKey(const Key('demo-move-e4')), findsOneWidget);
      expect(find.byKey(const Key('demo-capture-d3')), findsOneWidget);
      expect(find.byKey(const Key('demo-capture-f3')), findsOneWidget);
      expect(find.byKey(const Key('demo-move-d3')), findsNothing);
      // Board piece + two enemy dummies + header icon.
      expect(find.byType(SvgPicture), findsNWidgets(4));
    });

    testWidgets('capturing diagonally removes the enemy and relocates',
        (tester) async {
      await pumpDemo(tester, DemoPieceType.pawn);
      await tester.tap(find.byKey(const Key('demo-tap-d3')));
      await tester.pumpAndSettle();
      // The d3 pawn was captured: one SVG fewer, no d3 capture marker left.
      expect(find.byType(SvgPicture), findsNWidgets(3));
      expect(find.byKey(const Key('demo-capture-d3')), findsNothing);
      // From d3 the pawn keeps moving forward only.
      expect(find.byKey(const Key('demo-move-d4')), findsOneWidget);
    });

    testWidgets('knight jumps: blockers do not hide the L-targets',
        (tester) async {
      await pumpDemo(tester, DemoPieceType.knight);
      // Blockers on adjacent squares (d3, e5) must not remove any of the 8
      // L-targets; two of them are capturable enemies.
      const lTargets = ['c3', 'c5', 'd2', 'd6', 'f2', 'f6', 'g3', 'g5'];
      for (final target in lTargets) {
        final marked = find.byKey(Key('demo-move-$target'))
            .evaluate()
            .isNotEmpty ||
            find.byKey(Key('demo-capture-$target')).evaluate().isNotEmpty;
        expect(marked, isTrue, reason: 'knight target $target not marked');
      }
      expect(find.byKey(const Key('demo-capture-d2')), findsOneWidget);
      expect(find.byKey(const Key('demo-capture-f6')), findsOneWidget);
    });
  });
}
