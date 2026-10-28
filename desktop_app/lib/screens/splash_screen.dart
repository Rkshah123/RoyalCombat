import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/settings_manager.dart';
import '../services/sound_manager.dart';
import '../widgets/app_background.dart';
import 'main_menu.dart';

/// Golden hour splash: the crest fades and scales in, the title follows.
///
/// [playOpeningSounds] is true for the real application launch (the royal
/// fanfare plays exactly when the opening animation begins) and false when
/// the screen is shown again via "Back to title screen", which must be
/// completely silent.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.playOpeningSounds = true});

  final bool playOpeningSounds;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _crest = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final AnimationController _title = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.playOpeningSounds) {
      // The game-start fanfare now belongs to the application launch: it
      // plays exactly while the crest's opening animation begins, and it is
      // the ONLY launch sound (no extra beeps). It never fires on splash
      // re-visits from Settings.
      SoundManager.instance.play(Sfx.starting, volume: 0.85);
    }
    _title.forward();
    Future.delayed(const Duration(milliseconds: 2500), _go);
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainMenuScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _crest.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<SettingsManager>().palette;
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _crest,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(
                  opacity: _crest,
                  child: _Crest(palette: palette),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _title,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _title, curve: Curves.easeOut)),
                  child: Column(
                    children: [
                      Text(
                        'ROYAL COMBAT',
                        style: TextStyle(
                          fontFamily: 'Algerian',
                          fontSize: 40,
                          color: palette.accent,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: palette.accent.withValues(alpha: 0.35),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CHESS ARENA',
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w600,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 46),
              FadeTransition(
                opacity: _title,
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                  backgroundColor: palette.panelBorder.withValues(alpha: 0.4),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The crest presented at splash: the knight inside a golden ring.
class _Crest extends StatelessWidget {
  const _Crest({required this.palette});

  final RoyalPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            palette.accent.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: palette.accent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.35),
            blurRadius: 34,
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Image.asset('assets/images/logo/logo.png', fit: BoxFit.contain),
    );
  }
}
