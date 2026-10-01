import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockServiceProvider = Provider<ClockService>((ref) => ClockService());

/// Wall-clock-shaped `now()` that is immune to the system clock being
/// adjusted after the anchor is captured (user changes the device time, DST
/// falls back, an NTP correction jumps the clock). Backed by a monotonic
/// `Stopwatch` rather than repeated `DateTime.now()` reads, so a workout
/// mid-round can't be teleported forward or backward by a clock change —
/// only real elapsed time moves it.
///
/// This does not change how backgrounding is handled: the stopwatch keeps
/// advancing correctly across the entire workout because Phase 2 keeps the
/// process alive (foreground service / active audio session) for the
/// duration, so its underlying monotonic clock is never actually paused —
/// it just can't be fooled by wall-clock edits the way raw `DateTime.now()`
/// can.
class ClockService {
  ClockService()
      : _anchorWallClock = DateTime.now(),
        _stopwatch = Stopwatch()..start();

  final DateTime _anchorWallClock;
  final Stopwatch _stopwatch;

  DateTime now() => _anchorWallClock.add(_stopwatch.elapsed);
}
