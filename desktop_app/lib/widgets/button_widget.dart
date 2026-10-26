import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/sound_manager.dart';

/// A pressed-chrome "royal" rounded button used across every screen.
/// Scales down slightly when pressed, plays the tap sound, and follows the
/// current board theme palette.
class RoyalButton extends StatefulWidget {
  const RoyalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.narrow = false,
    this.fontSize = 17,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool narrow;
  final double fontSize;
  final double height;

  @override
  State<RoyalButton> createState() => _RoyalButtonState();
}

class _RoyalButtonState extends State<RoyalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    final enabled = widget.onPressed != null;
    // Secondary buttons sit on the arena artwork, so their translucent panel
    // fill is kept strong enough to stay readable while the image shows
    // through around the app.
    final gradient = widget.secondary
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.panel.withValues(alpha: 0.92),
              palette.panel.withValues(alpha: 0.74),
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.accent,
              Color.alphaBlend(palette.accent.withValues(alpha: 0.75), Colors.black),
            ],
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: enabled
          ? () {
              SoundManager.instance.tap();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.narrow ? 18 : 28),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.secondary
                    ? palette.panelBorder
                    : Color.alphaBlend(palette.accent.withValues(alpha: 0.55), Colors.white),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
                if (!widget.secondary && enabled)
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.25),
                    offset: const Offset(0, 0),
                    blurRadius: 18,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.height >= 62 ? 24 : 20,
                    color: widget.secondary ? palette.accent : const Color(0xFF221606),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      // Readability: the platform default font in bold instead
                      // of the decorative GoudyStout, which is too blocky at
                      // label size. GoudyStout stays reserved for big titles.
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: widget.secondary
                            ? palette.textPrimary
                            : const Color(0xFF221606),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
