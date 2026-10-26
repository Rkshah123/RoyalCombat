import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart';
import '../models/player_model.dart';
import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';
import '../widgets/button_widget.dart';
import '../widgets/piece_widget.dart';
import 'game_screen.dart';

/// Pre-match configuration: side, difficulty, time control and theme preview.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.initialMode});

  final GameMode initialMode;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late GameMode _mode;
  int _selectedSide = 1; // 0 black, 1 white, 2 random
  int _difficulty = 1;
  int _timeIndex = 3;
  int _incrementIndex = 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final settings = context.read<SettingsManager>();
    _difficulty = settings.defaultDifficultyIndex;
    _timeIndex = settings.defaultTimeMinuteIndex;
    _incrementIndex = settings.defaultIncrementIndex;
  }

  bool get isVsComputer => _mode == GameMode.vsComputer;

  void _start() {
    final side = _selectedSide == 2
        ? (DateTime.now().millisecondsSinceEpoch % 2 == 0)
        : _selectedSide == 1;

    final PlayerInfo white;
    final PlayerInfo black;
    if (isVsComputer) {
      final difficulty = Difficulty.values[_difficulty];
      white = side
          ? PlayerFactory.human(true)
          : PlayerFactory.ai(true, difficulty);
      black = side
          ? PlayerFactory.ai(false, difficulty)
          : PlayerFactory.human(false);
    } else {
      white = PlayerFactory.human(true);
      black = PlayerFactory.human(false);
    }

    PlayerInfo human;
    if (isVsComputer) {
      human = side ? white : black;
    } else {
      // White starts: it is the first screen the local player controls.
      human = white;
    }

    final baseMinutes = SettingsManager.timeControlMinutes[_timeIndex];
    final increment = Duration(
        seconds: SettingsManager.incrementsSeconds[_incrementIndex]);

    Navigator.of(context).pushReplacement(_route(GameScreen(
      mode: _mode,
      humanSide: human,
      white: white,
      black: black,
      time: Duration(minutes: baseMinutes),
      increment: increment,
    )));
  }

  PageRouteBuilder _route(Widget page) => PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    final palette = settings.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: palette.textPrimary),
                        onPressed: () {
                          SoundManager.instance.tap();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Text(
                      isVsComputer ? 'Play vs Computer' : 'Pass & Play',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Algerian',
                        fontSize: 30,
                        color: palette.accent,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: palette.accent.withValues(alpha: 0.35),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _modeToggle(palette),
                    const SizedBox(height: 18),
                    _sidePicker(palette),
                    if (isVsComputer) ...[
                      const SizedBox(height: 18),
                      _difficultyPicker(palette),
                    ],
                    const SizedBox(height: 18),
                    _timePicker(palette),
                    const SizedBox(height: 24),
                    Center(
                      child: RoyalButton(
                        label: 'Start Match',
                        icon: Icons.flag_rounded,
                        onPressed: _start,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({
    required RoyalPalette palette,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(RoyalPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
          color: palette.textSecondary,
        ),
      ),
    );
  }

  Widget _modeToggle(RoyalPalette palette) {
    return _panel(
      palette: palette,
      child: SegmentedButton<GameMode>(
        segments: const [
          ButtonSegment(
            value: GameMode.vsComputer,
            icon: Icon(Icons.smart_toy_outlined),
            label: Text('Computer'),
          ),
          ButtonSegment(
            value: GameMode.passAndPlay,
            icon: Icon(Icons.group_outlined),
            label: Text('Pass & Play'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          SoundManager.instance.tap();
          setState(() => _mode = s.first);
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          selectedBackgroundColor: palette.accent,
          selectedForegroundColor: const Color(0xFF221606),
          foregroundColor: palette.textSecondary,
          side: BorderSide(color: palette.panelBorder),
        ),
      ),
    );
  }

  Widget _sidePicker(RoyalPalette palette) {
    Widget sideCard(int index, {String? label, bool? white, Widget? custom}) {
      final selected = _selectedSide == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            SoundManager.instance.tap();
            setState(() => _selectedSide = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(palette.accent.withValues(alpha: 0.18), palette.panel)
                  : palette.panel.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? palette.accent : palette.panelBorder.withValues(alpha: 0.5),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: custom ??
                  (white == null
                      ? Icon(Icons.casino_rounded,
                          color: palette.textPrimary, size: 34)
                      : PieceWidget.static(
                          assetKey: white ? 'whiteking' : 'blackking',
                          themeFolder: palette.theme.assetFolder,
                          size: 40,
                        )),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(palette, 'Play as'),
          Row(
            children: [
              sideCard(1, white: true),
              const SizedBox(width: 10),
              sideCard(2, custom: Icon(Icons.casino_rounded, color: palette.textPrimary, size: 34)),
              const SizedBox(width: 10),
              sideCard(0, white: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _difficultyPicker(RoyalPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(palette, 'Difficulty'),
          ...Difficulty.values.map((d) {
            final selected = Difficulty.values.indexOf(d) == _difficulty;
            return GestureDetector(
              onTap: () {
                SoundManager.instance.tap();
                setState(() => _difficulty = Difficulty.values.indexOf(d));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? Color.alphaBlend(
                          palette.accent.withValues(alpha: 0.2), palette.panel)
                      : palette.panel.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? palette.accent
                        : palette.panelBorder.withValues(alpha: 0.4),
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d.label,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      d.tagline,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _timePicker(RoyalPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(palette, 'Time control'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(SettingsManager.timeControlMinutes.length, (i) {
              final selected = i == _timeIndex;
              return GestureDetector(
                onTap: () {
                  SoundManager.instance.tap();
                  setState(() => _timeIndex = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.accent
                        : palette.panel.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? palette.accent : palette.panelBorder.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    SettingsManager.timeControlMinutes[i] == 0
                        ? 'No clock'
                        : '${SettingsManager.timeControlMinutes[i]} min',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF221606)
                          : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(SettingsManager.incrementsSeconds.length, (i) {
              final selected = i == _incrementIndex &&
                  SettingsManager.timeControlMinutes[_timeIndex] != 0;
              return GestureDetector(
                onTap: SettingsManager.timeControlMinutes[_timeIndex] == 0
                    ? null
                    : () {
                        SoundManager.instance.tap();
                        setState(() => _incrementIndex = i);
                      },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: SettingsManager.timeControlMinutes[_timeIndex] == 0
                      ? 0.35
                      : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.textPrimary
                          : palette.panel.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? palette.textPrimary
                            : palette.panelBorder.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '+${SettingsManager.incrementsSeconds[i]}s',
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF221606)
                            : palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
