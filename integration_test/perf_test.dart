import 'package:cornerman/main.dart';
import 'package:cornerman/state/timer_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('active round: frame timing over a sustained capture',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CornermanApp(),
      ),
    );
    // Let async bootstrap (prefs load, audio preload, notification init)
    // settle before starting the workout.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    container.read(timerProvider).start();
    // Championship preset has a 10s prep phase; wait past it so the whole
    // capture window sits inside round 1 (180s long) with no coarse
    // rebuild (phase/round transition) in the middle of the measurement.
    await Future<void>.delayed(const Duration(seconds: 11));
    await tester.pump();

    await binding.watchPerformance(() async {
      await Future<void>.delayed(const Duration(seconds: 30));
    });
  });
}
