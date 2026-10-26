import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart' show GameMode;
import '../services/match_history_service.dart';
import '../services/settings_manager.dart';
import '../widgets/app_background.dart';
import '../widgets/button_widget.dart';
import 'learn_screen.dart';
import 'match_history_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

/// Main menu with staggered entrance animations.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void initState() {
    super.initState();
    // Note: starting.wav intentionally does NOT play here — it belongs to the
    // moment a match actually begins (GameScreen.initState), not to menu
    // navigation.
  }

  PageRouteBuilder _route(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final menuItems = <(String, IconData, VoidCallback)>[
      ('Play vs Computer', Icons.smart_toy_outlined, () {
        _openSetup(GameMode.vsComputer);
      }),
      ('Pass & Play', Icons.group_outlined, () {
        _openSetup(GameMode.passAndPlay);
      }),
      ('Learn Chess', Icons.school_outlined, () {
        Navigator.of(context).push(_route(const LearnScreen()));
      }),
      ('Match History', Icons.history_rounded, () {
        context.read<MatchHistoryService>().load();
        Navigator.of(context).push(_route(const MatchHistoryScreen()));
      }),
      ('Settings', Icons.settings_outlined, () {
        Navigator.of(context).push(_route(const SettingsScreen()));
      }),
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(flex: 3),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: _entry, curve: Curves.easeOutCubic)),
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.accent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: palette.accent.withValues(alpha: 0.3),
                                blurRadius: 26,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child:
                              Image.asset('assets/images/logo/logo.png'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'ROYAL COMBAT',
                          style: TextStyle(
                            fontFamily: 'Algerian',
                            fontSize: 34,
                            letterSpacing: 2.4,
                            color: palette.accent,
                            shadows: [
                              Shadow(
                                color: palette.accent.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CHESS ARENA',
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  ..._menuChildren(menuItems, palette),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Developed by Khan',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textSecondary.withValues(alpha: 0.6),
                      ),
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

  List<Widget> _menuChildren(
      List<(String, IconData, VoidCallback)> items, RoyalPalette palette) {
    // Uniform, well-balanced menu buttons: one shared width that adapts to
    // the screen (clamped so they never crowd tiny phones), larger height
    // and label than the in-panel buttons for effortless tapping.
    final screenW = MediaQuery.sizeOf(context).width;
    final buttonWidth = (screenW - 48).clamp(280.0, 400.0);
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final (label, icon, onTap) = items[i];
      final start = 0.12 + i * 0.09;
      final end = (start + 0.5).clamp(start, 1.0);
      final stagger = Interval(start, end, curve: Curves.easeOutCubic);
      final curved = CurvedAnimation(parent: _entry, curve: stagger);
      widgets.add(
        FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.45),
              end: Offset.zero,
            ).animate(curved),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: SizedBox(
                width: buttonWidth,
                child: RoyalButton(
                  label: label,
                  icon: icon,
                  secondary: true,
                  narrow: false,
                  height: 64,
                  fontSize: 19,
                  onPressed: onTap,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _openSetup(GameMode mode) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => SetupScreen(initialMode: mode),
        transitionsBuilder: (_, animation, _, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }
}
