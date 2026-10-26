import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/timer_manager.dart';

/// One player's clock. Pulses when running and switches to warning colours as
/// time runs low.
class TimerWidget extends StatelessWidget {
  const TimerWidget({
    super.key,
    required this.isWhite,
    required this.label,
    required this.isActive,
    required this.remaining,
    this.compact = false,
  });

  final bool isWhite;
  final String label;
  final bool isActive;
  final Duration remaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final unlimited = remaining == Duration.zero && !isActive;
    final lowTime = !unlimited && remaining < const Duration(seconds: 10);
    final midTime = !unlimited && !lowTime && remaining < const Duration(seconds: 30);

    Color clockColor;
    if (unlimited) {
      clockColor = palette.textSecondary;
    } else if (lowTime) {
      clockColor = const Color(0xFFFF6B6B);
    } else if (midTime) {
      clockColor = const Color(0xFFFFC46B);
    } else {
      clockColor = palette.textPrimary;
    }

    final panelColor = isActive
        ? Color.alphaBlend(palette.accent.withValues(alpha: 0.18), palette.panel)
        : palette.panel;

    Widget content = unlimited
        ? Text(
            '∞',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.bold,
            ),
          )
        : Text(
            formatClock(remaining),
            style: TextStyle(
              fontSize: compact ? 18 : 26,
              color: clockColor,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(
          color: isActive ? palette.accent : palette.panelBorder.withValues(alpha: 0.5),
          width: isActive ? 1.6 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 10 : 14,
            height: compact ? 10 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite ? Colors.white : const Color(0xFF23272F),
              border: Border.all(
                color: palette.panelBorder,
                width: 1,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 12),
          content,
        ],
      ),
    );
  }
}

/// Pulsing overlay dot shown in the AI's panel while it is thinking.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key, this.size = 14});

  final double size;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.22;
            final v = ((t - delay) % 1.0 + 1.0) % 1.0;
            return Opacity(
              opacity: 0.25 + 0.75 * (0.5 - (v - 0.5).abs()) * 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
