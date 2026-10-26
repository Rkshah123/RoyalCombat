import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/match_history_service.dart';
import 'services/settings_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phones play in portrait; desktop windows resize freely.
  final isMobile = {
    TargetPlatform.android,
    TargetPlatform.iOS,
  }.contains(defaultTargetPlatform);
  if (isMobile) {
    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF1C1207),
  ));

  final settings = SettingsManager();
  final history = MatchHistoryService();
  // Never let a corrupt or unreadable store block the first frame.
  try {
    await settings.load();
  } catch (e) {
    debugPrint('Settings load failed, using defaults: $e');
  }
  try {
    await history.load();
  } catch (e) {
    debugPrint('Match history load failed, starting empty: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: history),
      ],
      child: const RoyalCombatApp(),
    ),
  );
}

class RoyalCombatApp extends StatelessWidget {
  const RoyalCombatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    final palette = settings.palette;

    return MaterialApp(
      title: 'Royal Combat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: palette.bgBottom,
        colorScheme: ColorScheme.dark(
          primary: palette.accent,
          secondary: palette.accent,
          surface: palette.panel,
        ),
        // Small UI text uses the platform's default font: GoudyStout is
        // reserved for headings and buttons (set explicitly where used) —
        // it is far too wide for body text and wraps badly.
        textTheme: const TextTheme().apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
