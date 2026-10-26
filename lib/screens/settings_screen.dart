import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart' show Difficulty;
import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';
import '../widgets/piece_widget.dart';
import 'splash_screen.dart';

/// Preferences, appearance and the "Developed by Khan" showcase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    final palette = settings.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                children: [
                  Row(
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
                        'Settings',
                        style: TextStyle(
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Section(
                    palette: palette,
                    title: 'Board Theme',
                    child: Column(
                      children: [
                        for (final theme in BoardTheme.values)
                          _ThemeOptionCard(
                            palette: palette,
                            theme: theme,
                            selected: settings.boardTheme == theme,
                            onTap: () {
                              // Standard UI click only — no extra effects on
                              // theme changes.
                              SoundManager.instance.tap();
                              settings.setBoardTheme(theme);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    palette: palette,
                    title: 'Preferences',
                    child: Column(
                      children: [
                        _ToggleRow(
                          palette: palette,
                          icon: Icons.volume_up_rounded,
                          title: 'Sound effects',
                          value: settings.soundEnabled,
                          onChanged: (v) => settings.setSoundEnabled(v),
                        ),
                        const SizedBox(height: 8),
                        _ToggleRow(
                          palette: palette,
                          icon: Icons.spoke_outlined,
                          title: 'Show legal move hints',
                          value: settings.showLegalMoves,
                          onChanged: (v) => settings.setShowLegalMoves(v),
                        ),
                        const SizedBox(height: 8),
                        _ToggleRow(
                          palette: palette,
                          icon: Icons.animation_rounded,
                          title: 'Smooth piece movement',
                          value: settings.pieceAnimations,
                          onChanged: (v) => settings.setPieceAnimations(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    palette: palette,
                    title: 'Match Defaults',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Difficulty',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<int>(
                          segments: [
                            for (final (i, d) in Difficulty.values.indexed)
                              ButtonSegment(
                                value: i,
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(d.label, maxLines: 1),
                                ),
                              ),
                          ],
                          selected: {settings.defaultDifficultyIndex},
                          onSelectionChanged: (s) {
                            SoundManager.instance.tap();
                            settings.setDefaultDifficulty(s.first);
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            selectedBackgroundColor: palette.accent,
                            selectedForegroundColor: const Color(0xFF221606),
                            foregroundColor: palette.textSecondary,
                            side: BorderSide(color: palette.panelBorder),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Time control',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, minutes)
                                in SettingsManager.timeControlMinutes.indexed)
                              ChoiceChip(
                                label: Text(
                                    minutes == 0 ? 'No clock' : '$minutes min'),
                                selected:
                                    settings.defaultTimeMinuteIndex == i,
                                onSelected: (_) {
                                  SoundManager.instance.tap();
                                  settings.setDefaultTimeControl(i);
                                },
                                selectedColor: palette.accent,
                                backgroundColor:
                                    palette.panel.withValues(alpha: 0.6),
                                labelStyle: TextStyle(
                                  color: settings.defaultTimeMinuteIndex == i
                                      ? const Color(0xFF221606)
                                      : palette.textPrimary,
                                  fontSize: 12.5,
                                ),
                                side: BorderSide(
                                    color: palette.panelBorder
                                        .withValues(alpha: 0.6)),
                                showCheckmark: false,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const DevelopedByKhanPanel(),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        SoundManager.instance.play(Sfx.popWindow);
                        context.read<SettingsManager>().resetToDefaults();
                      },
                      icon: Icon(Icons.restart_alt_rounded,
                          size: 18, color: palette.textSecondary),
                      label: Text(
                        'Reset all settings',
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => const SplashScreen(),
                          transitionsBuilder: (_, a, _, child) =>
                              FadeTransition(
                            opacity:
                                CurvedAnimation(parent: a, curve: Curves.easeOut),
                            child: child,
                          ),
                          transitionDuration:
                              const Duration(milliseconds: 400),
                        ),
                      ),
                      icon: Icon(Icons.logout_rounded,
                          size: 18, color: palette.textSecondary),
                      label: Text(
                        'Back to title screen',
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 13),
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
}

// --------------------------------------------------------------------------
// Building blocks
// --------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.palette, required this.title, required this.child});

  final RoyalPalette palette;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.55), palette.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.palette,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final RoyalPalette palette;
  final BoardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipPalette = RoyalPalette.from(theme);
    final checkers = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Column(
          children: [
            for (var r = 0; r < 4; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 4; c++)
                      Expanded(
                        child: ColoredBox(
                          color: (r + c) % 2 == 0
                              ? theme.lightSquare
                              : theme.darkSquare,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(palette.accentSoft, palette.panel)
                : palette.panel.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.accent : palette.panelBorder.withValues(alpha: 0.45),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  checkers,
                  PieceWidget.static(
                    assetKey: 'whiteknight',
                    themeFolder: chipPalette.theme.assetFolder,
                    size: 34,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.label,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _describe(theme),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? palette.accent : palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _describe(BoardTheme theme) {
    switch (theme) {
      case BoardTheme.royalWood:
        return 'Classic golden walnut finish';
      case BoardTheme.emeraldField:
        return 'Fresh tournament green';
      case BoardTheme.midnightIce:
        return 'Cool slate for late nights';
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final RoyalPalette palette;
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.panelBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14.5,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              SoundManager.instance.tap();
              onChanged(v);
            },
            activeThumbColor: palette.accent,
            activeTrackColor: palette.accent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

/// The polished "Developed by Khan" showcase panel.
class DevelopedByKhanPanel extends StatelessWidget {
  const DevelopedByKhanPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(palette.accent.withValues(alpha: 0.16), palette.panel),
            palette.panel,
          ],
        ),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.14),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 34, height: 1, color: palette.accent.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.workspace_premium_rounded,
                    color: palette.accent, size: 22),
              ),
              Container(width: 34, height: 1, color: palette.accent.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                palette.accent,
                Color.alphaBlend(palette.accent, Colors.white),
              ],
            ).createShader(bounds),
            child: Text(
              'Developed by Khan',
              style: TextStyle(
                fontFamily: 'Algerian',
                fontSize: 24,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ROYAL COMBAT · CHESS ARENA',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Designed and crafted with care for players who love the royal game.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Version 1.0.0 · 2026',
            style: TextStyle(
              color: palette.textSecondary.withValues(alpha: 0.75),
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
