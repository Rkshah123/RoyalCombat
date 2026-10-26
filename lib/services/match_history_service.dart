import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state_model.dart';
import '../models/move_model.dart';
import '../models/player_model.dart';

/// One finished match persisted between app runs.
class MatchRecord {
  final DateTime playedAt;
  final GameMode mode;
  final GameEndReason reason;
  final bool? whiteWon;
  final String whiteName;
  final String blackName;
  final int moveCount;
  final String timeControl;

  const MatchRecord({
    required this.playedAt,
    required this.mode,
    required this.reason,
    required this.whiteWon,
    required this.whiteName,
    required this.blackName,
    required this.moveCount,
    required this.timeControl,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'playedAt': playedAt.millisecondsSinceEpoch,
        'mode': mode.name,
        'reason': reason.name,
        'whiteWon': whiteWon,
        'whiteName': whiteName,
        'blackName': blackName,
        'moveCount': moveCount,
        'timeControl': timeControl,
      };

  static MatchRecord fromJson(Map<String, dynamic> json) => MatchRecord(
        playedAt: DateTime.fromMillisecondsSinceEpoch(json['playedAt'] as int),
        mode: GameMode.values.where((m) => m.name == json['mode']).first,
        reason: GameEndReason.values.where((r) => r.name == json['reason']).first,
        whiteWon: json['whiteWon'] as bool?,
        whiteName: json['whiteName'] as String? ?? 'White',
        blackName: json['blackName'] as String? ?? 'Black',
        moveCount: json['moveCount'] as int? ?? 0,
        timeControl: json['timeControl'] as String? ?? 'No limit',
      );

  String get outcomeShort {
    if (whiteWon == null) return 'Draw';
    return whiteWon == true ? 'White won' : 'Black won';
  }

  String get reasonLabel {
    switch (reason) {
      case GameEndReason.checkmate:
        return 'Checkmate';
      case GameEndReason.stalemate:
        return 'Stalemate';
      case GameEndReason.timeout:
        return 'Timed out';
      case GameEndReason.resignation:
        return 'Resignation';
      case GameEndReason.drawAgreed:
        return 'Draw agreed';
      case GameEndReason.insufficientMaterial:
        return 'Insufficient material';
      case GameEndReason.threefoldRepetition:
        return 'Threefold repetition';
      case GameEndReason.fiftyMoveRule:
        return 'Fifty-move rule';
    }
  }
}

/// Persists match records in shared preferences.
class MatchHistoryService extends ChangeNotifier {
  static const _key = 'match_history_v1';
  static const int maxRecords = 50;

  List<MatchRecord> _records = [];

  List<MatchRecord> get records => List.unmodifiable(_records.reversed);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Older installs might hold a non-string under this key; never let a
    // corrupt store crash the app before the first frame.
    final raw = prefs.get(_key);
    if (raw == null || raw is! String) {
      _records = [];
      notifyListeners();
      return;
    }
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<dynamic, dynamic>>()
          .map((e) => MatchRecord.fromJson(e.cast<String, dynamic>()))
          .toList();
      _records = list;
    } catch (_) {
      _records = [];
    }
    notifyListeners();
  }

  Future<void> add({
    required GameMode mode,
    required GameEndReason reason,
    required bool? whiteWon,
    required String whiteName,
    required String blackName,
    required int moveCount,
    required String timeControl,
  }) async {
    _records.add(MatchRecord(
      playedAt: DateTime.now(),
      mode: mode,
      reason: reason,
      whiteWon: whiteWon,
      whiteName: whiteName,
      blackName: blackName,
      moveCount: moveCount,
      timeControl: timeControl,
    ));
    if (_records.length > maxRecords) {
      _records = _records.sublist(_records.length - maxRecords);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> addFromResult({
    required GameMode mode,
    required GameResult result,
    required PlayerInfo white,
    required PlayerInfo black,
    required String timeControl,
  }) async {
    await add(
      mode: mode,
      reason: result.reason,
      whiteWon: result.whiteWon,
      whiteName: white.name,
      blackName: black.name,
      moveCount: result.moveCount,
      timeControl: timeControl,
    );
  }

  Future<void> clear() async {
    _records = [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_records.map((r) => r.toJson()).toList()));
  }

  /// Build a user-facing game result out of the raw rule state.
  static GameResult buildResult({
    required GameEndReason reason,
    required bool? whiteWon,
    required GameStateModel state,
    required PlayerInfo white,
    required PlayerInfo black,
  }) {
    final winner = whiteWon == null ? null : (whiteWon ? white : black);
    final loser = whiteWon == null ? null : (whiteWon ? black : white);
    return GameResult(
      reason: reason,
      whiteWon: whiteWon,
      moveCount: state.moveCount,
      duration: DateTime.now().difference(state.startedAt),
      winnerName: winner?.name ?? '',
      loserName: loser?.name ?? '',
    );
  }
}
