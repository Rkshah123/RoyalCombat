import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';
import 'learn_screen.dart';

/// Full-page reader for one lesson.
class LearnDetailScreen extends StatelessWidget {
  const LearnDetailScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              Icon(Icons.arrow_back, color: palette.textPrimary),
                          onPressed: () {
                            SoundManager.instance.tap();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontFamily: 'Algerian',
                              fontSize: 23,
                              letterSpacing: 1.2,
                              color: palette.accent,
                              shadows: [
                                Shadow(
                                  color: palette.accent.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                      children: [
                        for (final section in lesson.sections)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: palette.panel.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: palette.panelBorder.withValues(alpha: 0.55)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.heading,
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  section.body,
                                  style: TextStyle(
                                    color: palette.textPrimary.withValues(alpha: 0.92),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
}
