import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// The three board/appearance themes backed by the bundled piece assets.
enum BoardTheme {
  royalWood(
    'Royal Wood',
    'woodtheme',
    Color(0xFFE8CFA8),
    Color(0xFF8F5A2B),
  ),
  emeraldField(
    'Emerald Field',
    'greentheme',
    Color(0xFFEEF2DB),
    Color(0xFF779455),
  ),
  midnightIce(
    'Midnight Ice',
    'blacktheme',
    Color(0xFFDFE5F2),
    Color(0xFF46536B),
  );

  final String label;
  final String assetFolder;
  final Color lightSquare;
  final Color darkSquare;

  const BoardTheme(this.label, this.assetFolder, this.lightSquare, this.darkSquare);
}

/// A palette describing every colour the UI needs for one theme so the whole
/// application follows the selected board theme.
class RoyalPalette {
  final BoardTheme theme;
  final Color bgTop;
  final Color bgBottom;
  final Color panel;
  final Color panelBorder;
  final Color accent;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;

  const RoyalPalette({
    required this.theme,
    required this.bgTop,
    required this.bgBottom,
    required this.panel,
    required this.panelBorder,
    required this.accent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const RoyalPalette wood = RoyalPalette(
    theme: BoardTheme.royalWood,
    bgTop: Color(0xFF1C1207),
    bgBottom: Color(0xFF2E1E0E),
    panel: Color(0xFF2B1D0E),
    panelBorder: Color(0xFF8F5A2B),
    accent: Color(0xFFE4B95B),
    accentSoft: Color(0x33E4B95B),
    textPrimary: Color(0xFFF4E9D3),
    textSecondary: Color(0xFFC9B28C),
  );

  static const RoyalPalette emerald = RoyalPalette(
    theme: BoardTheme.emeraldField,
    bgTop: Color(0xFF0D1B12),
    bgBottom: Color(0xFF173323),
    panel: Color(0xFF14301F),
    panelBorder: Color(0xFF3E7A57),
    accent: Color(0xFF9BD48A),
    accentSoft: Color(0x339BD48A),
    textPrimary: Color(0xFFEDF6E8),
    textSecondary: Color(0xFFA9C7A2),
  );

  static const RoyalPalette midnight = RoyalPalette(
    theme: BoardTheme.midnightIce,
    bgTop: Color(0xFF0B0F18),
    bgBottom: Color(0xFF16203A),
    panel: Color(0xFF141C33),
    panelBorder: Color(0xFF3D4E75),
    accent: Color(0xFF9BB3E4),
    accentSoft: Color(0x339BB3E4),
    textPrimary: Color(0xFFE9EEF9),
    textSecondary: Color(0xFFA4B1CE),
  );

  static RoyalPalette from(BoardTheme theme) {
    switch (theme) {
      case BoardTheme.royalWood:
        return wood;
      case BoardTheme.emeraldField:
        return emerald;
      case BoardTheme.midnightIce:
        return midnight;
    }
  }
}

/// Persists user preferences and exposes them to the whole app.
class SettingsManager extends ChangeNotifier {
  static const _keyBoardTheme = 'board_theme';
  static const _keySound = 'sound_enabled';
  static const _keyLegalMoves = 'show_legal_moves';
  static const _keyPieceAnimations = 'piece_animations';
  static const _keyDifficulty = 'default_difficulty';
  static const _keyTimeControl = 'default_time_control';
  static const _keyIncrement = 'default_increment';

  BoardTheme _boardTheme = BoardTheme.royalWood;
  bool _soundEnabled = true;
  bool _showLegalMoves = true;
  bool _pieceAnimations = true;
  int _defaultDifficultyIndex = 1;
  int _defaultTimeMinuteIndex = 3;
  int _defaultIncrementIndex = 0;

  RoyalPalette get palette => RoyalPalette.from(_boardTheme);
  BoardTheme get boardTheme => _boardTheme;
  bool get soundEnabled => _soundEnabled;
  bool get showLegalMoves => _showLegalMoves;
  bool get pieceAnimations => _pieceAnimations;
  int get defaultDifficultyIndex => _defaultDifficultyIndex;
  int get defaultTimeMinuteIndex => _defaultTimeMinuteIndex;
  int get defaultIncrementIndex => _defaultIncrementIndex;

  static const List<int> timeControlMinutes = [0, 1, 3, 5, 10, 15, 30];
  static const List<int> incrementsSeconds = [0, 2, 10, 30];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Tolerant typed reads: legacy installs (or older builds) may have stored
    // these keys under a different Dart type; a hard cast here would crash
    // before runApp() and leave the app stuck on the launch splash forever.
    _boardTheme = _readTheme(prefs);
    _soundEnabled = _readBool(prefs, _keySound, _soundEnabled);
    _showLegalMoves = _readBool(prefs, _keyLegalMoves, _showLegalMoves);
    _pieceAnimations = _readBool(prefs, _keyPieceAnimations, _pieceAnimations);
    _defaultDifficultyIndex =
        _readInt(prefs, _keyDifficulty, _defaultDifficultyIndex);
    _defaultTimeMinuteIndex =
        _readInt(prefs, _keyTimeControl, _defaultTimeMinuteIndex);
    _defaultIncrementIndex =
        _readInt(prefs, _keyIncrement, _defaultIncrementIndex);
    notifyListeners();
    // Rewrite every key with its proper type, healing any legacy data.
    await _save();
  }

  BoardTheme _readTheme(SharedPreferences prefs) {
    final raw = prefs.get(_keyBoardTheme);
    if (raw is String) {
      return BoardTheme.values
              .where((t) => t.name == raw)
              .firstOrNull ??
          BoardTheme.royalWood;
    }
    if (raw is int) {
      return BoardTheme.values[raw.clamp(0, BoardTheme.values.length - 1)];
    }
    return BoardTheme.royalWood;
  }

  static bool _readBool(SharedPreferences prefs, String key, bool fallback) {
    final raw = prefs.get(key);
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) {
      if (raw == 'true') return true;
      if (raw == 'false') return false;
    }
    return fallback;
  }

  static int _readInt(SharedPreferences prefs, String key, int fallback) {
    final raw = prefs.get(key);
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBoardTheme, _boardTheme.name);
    await prefs.setBool(_keySound, _soundEnabled);
    await prefs.setBool(_keyLegalMoves, _showLegalMoves);
    await prefs.setBool(_keyPieceAnimations, _pieceAnimations);
    await prefs.setInt(_keyDifficulty, _defaultDifficultyIndex);
    await prefs.setInt(_keyTimeControl, _defaultTimeMinuteIndex);
    await prefs.setInt(_keyIncrement, _defaultIncrementIndex);
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    if (theme == _boardTheme) return;
    _boardTheme = theme;
    notifyListeners();
    await _save();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _save();
  }

  Future<void> setShowLegalMoves(bool value) async {
    _showLegalMoves = value;
    notifyListeners();
    await _save();
  }

  Future<void> setPieceAnimations(bool value) async {
    _pieceAnimations = value;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultDifficulty(int index) async {
    _defaultDifficultyIndex = index;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultTimeControl(int index) async {
    _defaultTimeMinuteIndex = index;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultIncrement(int index) async {
    _defaultIncrementIndex = index;
    notifyListeners();
    await _save();
  }

  Future<void> resetToDefaults() async {
    _boardTheme = BoardTheme.royalWood;
    _soundEnabled = true;
    _showLegalMoves = true;
    _pieceAnimations = true;
    _defaultDifficultyIndex = 1;
    _defaultTimeMinuteIndex = 3;
    _defaultIncrementIndex = 0;
    notifyListeners();
    await _save();
  }

  /// Convenience static lookup used by widgets that lack a context.
  static SettingsManager of(BuildContext context) => context.read<SettingsManager>();

  static SettingsManager watch(BuildContext context) => context.watch<SettingsManager>();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final t in this) {
      return t;
    }
    return null;
  }
}
