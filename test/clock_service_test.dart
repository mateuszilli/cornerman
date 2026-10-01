import 'package:flutter_test/flutter_test.dart';
import 'package:cornerman/services/clock_service.dart';

void main() {
  group('ClockService', () {
    test('now() tracks real elapsed time from the anchor', () async {
      final clock = ClockService();
      final first = clock.now();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final second = clock.now();
      expect(second.difference(first).inMilliseconds, closeTo(200, 100));
    });

    test('now() is monotonically non-decreasing across calls', () {
      final clock = ClockService();
      var previous = clock.now();
      for (var i = 0; i < 1000; i++) {
        final current = clock.now();
        expect(current.isBefore(previous), isFalse);
        previous = current;
      }
    });
  });
}
