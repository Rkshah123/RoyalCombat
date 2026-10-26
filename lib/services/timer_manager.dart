import 'dart:async';

import 'package:flutter/foundation.dart';

/// Two independent world clocks with optional Fischer increments.
/// Tick resolution is 100 ms so the displays feel smooth.
class TimerManager extends ChangeNotifier {
  static const _tick = Duration(milliseconds: 100);

  Duration _white = Duration.zero;
  Duration _black = Duration.zero;
  Duration _increment = Duration.zero;
  bool _unlimited = false;
  bool _running = false;
  bool _paused = false;
  bool _whiteActive = true;
  Timer? _timer;
  DateTime? _lastTickAt;
  void Function(bool whiteFlagged)? onTimeout;

  Duration get whiteRemaining => _unlimited ? Duration.zero : _white;
  Duration get blackRemaining => _unlimited ? Duration.zero : _black;
  bool get unlimited => _unlimited;
  bool get running => _running && !_paused;
  bool get whiteActive => _whiteActive;

  bool configure(Duration base, Duration increment) {
    _unlimited = base <= Duration.zero;
    _white = base;
    _black = base;
    _increment = increment;
    _running = false;
    _paused = false;
    _timer?.cancel();
    notifyListeners();
    return !_unlimited;
  }

  void start({required bool whiteFirst}) {
    if (_unlimited) {
      _running = false;
      return;
    }
    _whiteActive = whiteFirst;
    _running = true;
    _paused = false;
    _schedule();
    notifyListeners();
  }

  void switchTurn({required bool whiteNowActive}) {
    if (!_running || _unlimited) {
      _whiteActive = whiteNowActive;
      notifyListeners();
      return;
    }
    // Fischer increment for the player who just moved.
    if (_whiteActive) {
      _white += _increment;
    } else {
      _black += _increment;
    }
    _whiteActive = whiteNowActive;
    _schedule();
    notifyListeners();
  }

  /// Sets the active side without applying an increment (used by undo).
  void setActiveTurn(bool whiteActive) {
    _whiteActive = whiteActive;
    if (_running && !_paused) _schedule();
    notifyListeners();
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
    _lastTickAt = null;
    notifyListeners();
  }

  void resume() {
    if (_running) {
      _paused = false;
      _schedule();
      notifyListeners();
    }
  }

  void stop() {
    _running = false;
    _paused = false;
    _timer?.cancel();
    _lastTickAt = null;
    notifyListeners();
  }

  void disposeTimer() {
    _timer?.cancel();
    _timer = null;
    _lastTickAt = null;
  }

  void _schedule() {
    _timer?.cancel();
    _lastTickAt = null;
    if (!_running || _paused || _unlimited) return;
    _lastTickAt = DateTime.now();
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  void _onTick() {
    if (!_running || _paused || _unlimited) return;
    // Charge the real elapsed wall-clock time instead of a fixed tick, so
    // callbacks that fire late (GC, isolate work, throttling) never cause the
    // displayed clock to drift or jump: 5s of thinking always costs 5s.
    final now = DateTime.now();
    final elapsed = _lastTickAt == null
        ? _tick
        : now.difference(_lastTickAt!);
    _lastTickAt = now;
    if (_whiteActive) {
      if (_white <= Duration.zero) {
        _timeout(false);
        return;
      }
      _white -= elapsed;
      if (_white <= Duration.zero) {
        _white = Duration.zero;
        _timeout(false);
        return;
      }
    } else {
      if (_black <= Duration.zero) {
        _timeout(true);
        return;
      }
      _black -= elapsed;
      if (_black <= Duration.zero) {
        _black = Duration.zero;
        _timeout(true);
        return;
      }
    }
    notifyListeners();
  }

  void _timeout(bool whiteFlaggedBlack) {
    _timer?.cancel();
    _running = false;
    _lastTickAt = null;
    onTimeout?.call(whiteFlaggedBlack ? false : true);
  }

  /// Did [isWhite] run out of time?
  bool hasRunOut(bool isWhite) {
    if (_unlimited) return false;
    return isWhite ? _white <= Duration.zero : _black <= Duration.zero;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Formats a countdown for the clock widget: mm:ss, and adds tenths below 10s.
String formatClock(Duration d) {
  if (d < Duration.zero) d = Duration.zero;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d < const Duration(seconds: 10)) {
    final tenth = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$tenth';
  }
  return '$m:$s';
}
