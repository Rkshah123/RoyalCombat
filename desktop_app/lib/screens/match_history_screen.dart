import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/move_model.dart';
import '../services/match_history_service.dart';
import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';

/// Persisted match results with clear-history support.
class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final history = context.watch<MatchHistoryService>();

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
                          icon:
                              Icon(Icons.arrow_back, color: palette.textPrimary),
                          onPressed: () {
                            SoundManager.instance.tap();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Match History',
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
                        const Spacer(),
                        if (history.records.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear history',
                            icon: Icon(Icons.delete_outline,
                                color: palette.textSecondary),
                            onPressed: () async {
                              SoundManager.instance.play(Sfx.popWindow);
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: palette.panel,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                        color: palette.panelBorder),
                                  ),
                                  title: Text(
                                    'Clear history?',
                                    style: TextStyle(
                                      fontFamily: 'Algerian',
                                      color: palette.accent,
                                    ),
                                  ),
                                  content: Text(
                                    'All saved match records will be removed.',
                                    style: TextStyle(
                                        color: palette.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: Text('Cancel',
                                          style: TextStyle(
                                              color: palette.textPrimary)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: Text(
                                        'Clear',
                                        style: TextStyle(
                                            color:
                                                Color(0xFFFF6B6B)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await history.clear();
                                SoundManager.instance.tap();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: history.records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events_outlined,
                                    color: palette.textSecondary
                                        .withValues(alpha: 0.5),
                                    size: 56),
                                const SizedBox(height: 12),
                                Text(
                                  'No matches yet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Finished games are recorded here.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color:
                                        palette.textSecondary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                            itemBuilder: (context, i) {
                              final record = history.records[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: palette.panel.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          palette.panelBorder.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.alphaBlend(
                                            palette.accentSoft, palette.panel),
                                        border: Border.all(
                                            color: palette.panelBorder
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        record.whiteWon == null
                                            ? '½'
                                            : record.whiteWon == true
                                                ? '1'
                                                : '0',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: palette.accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${record.outcomeShort} · ${record.reasonLabel}',
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'White: ${record.whiteName}   Black: ${record.blackName}',
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${_modeLabel(record.mode)} · ${record.timeControl} · ${record.moveCount} half-moves · ${_date(record.playedAt)}',
                                            style: TextStyle(
                                              color: palette.textSecondary
                                                  .withValues(alpha: 0.75),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemCount: history.records.length,
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

  String _modeLabel(GameMode mode) =>
      mode == GameMode.vsComputer ? 'vs Computer' : 'Pass & Play';

  String _date(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
