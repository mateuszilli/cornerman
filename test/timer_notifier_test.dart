import 'package:flutter_test/flutter_test.dart';
import 'package:cornerman/models/timer_config.dart';
import 'package:cornerman/models/workout_phase.dart';
import 'package:cornerman/state/timer_notifier.dart';
import 'package:cornerman/services/audio_service.dart';
import 'package:cornerman/services/background_session_service.dart';
import 'package:cornerman/services/haptic_service.dart';
import 'package:cornerman/services/notification_fallback_service.dart';
import 'package:cornerman/services/prefs_service.dart';
import 'package:cornerman/models/workout_schedule.dart';
import 'package:cornerman/models/workout_snapshot.dart';
import 'package:cornerman/models/workout_state.dart';

// Stub services that record calls without side-effects.
class FakeAudioService implements AudioService {
  final List<AudioCue> played = [];

  @override
  void play(AudioCue cue) => played.add(cue);

  @override
  void stop() {}

  @override
  void setVolume(double v) {}

  @override
  void setMuted(bool m) {}

  @override
  void setDuckAudio(bool duckAudio) {}

  @override
  bool get muted => false;

  @override
  double get volume => 1.0;

  @override
  Future<void> preload() async {}

  @override
  void dispose() {}
}

class FakeHapticService implements HapticService {
  int buzzCount = 0;
  int longBuzzCount = 0;

  @override
  Future<void> buzz() async => buzzCount++;

  @override
  Future<void> longBuzz() async => longBuzzCount++;
}

class FakePrefsService implements PrefsService {
  @override
  Future<TimerConfig?> loadLastConfig() async => null;

  @override
  Future<void> saveConfig(TimerConfig c) async {}

  @override
  Future<List<NamedPreset>> loadUserPresets() async => [];

  @override
  Future<void> saveUserPresets(List<NamedPreset> presets) async {}

  @override
  Future<String?> loadLocale() async => null;

  @override
  Future<void> saveLocale(String? code) async {}
}

class FakeBackgroundSession implements BackgroundSession {
  @override
  Future<void> startSession() async {}

  @override
  Future<void> endSession() async {}

  @override
  void syncFromSnapshot(WorkoutSnapshot snapshot) {}
}

class FakeNotificationFallback implements NotificationFallback {
  @override
  Future<void> scheduleAll(WorkoutState state, WorkoutSchedule schedule) async {}

  @override
  Future<void> cancelAll() async {}
}

// Creates a notifier wired to fake services using a short config.
TimerNotifier _makeNotifier({
  int rounds = 3,
  int roundSeconds = 5,
  int restSeconds = 2,
  int prepSeconds = 3,
  int warningSeconds = 2,
}) {
  final cfg = TimerConfig(
    rounds: rounds,
    roundSeconds: roundSeconds,
    restSeconds: restSeconds,
    prepSeconds: prepSeconds,
    warningSeconds: warningSeconds,
    countdownBeeps: true,
    haptics: false,
    keepScreenAwake: false,
    volume: 1.0,
    muted: false,
    duckAudio: true,
  );
  final audio = FakeAudioService();
  final haptic = FakeHapticService();
  final prefs = FakePrefsService();
  final n = TimerNotifier(
    audioService: audio,
    hapticService: haptic,
    prefsService: prefs,
    backgroundSession: FakeBackgroundSession(),
    notificationFallback: FakeNotificationFallback(),
  );
  n.loadConfig(cfg);
  return n;
}

void main() {
  group('TimerNotifier — idle/start', () {
    test('starts in idle phase', () {
      final n = _makeNotifier();
      expect(n.state.phase, WorkoutPhase.idle);
      expect(n.state.isRunning, false);
    });

    test('start() enters prep when prepSeconds > 0', () {
      final n = _makeNotifier(prepSeconds: 5);
      n.start();
      expect(n.state.phase, WorkoutPhase.prep);
      expect(n.state.isRunning, true);
      n.dispose();
    });

    test('start() skips prep and enters round when prepSeconds == 0', () {
      final n = _makeNotifier(prepSeconds: 0);
      n.start();
      expect(n.state.phase, WorkoutPhase.round);
      n.dispose();
    });
  });

  group('TimerNotifier — pause/resume', () {
    test('pause stops isRunning', () {
      final n = _makeNotifier();
      n.start();
      n.pause();
      expect(n.state.isRunning, false);
      n.dispose();
    });

    test('resume restores isRunning', () {
      final n = _makeNotifier();
      n.start();
      n.pause();
      n.resume();
      expect(n.state.isRunning, true);
      n.dispose();
    });

    test('remaining time does not change while paused', () async {
      final n = _makeNotifier(roundSeconds: 30, prepSeconds: 0);
      n.start();
      // Let it tick briefly.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      n.pause();
      final snap = n.state.remainingMs;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(n.state.remainingMs, snap);
      n.dispose();
    });
  });

  group('TimerNotifier — reset', () {
    test('reset returns to idle', () {
      final n = _makeNotifier();
      n.start();
      n.reset();
      expect(n.state.phase, WorkoutPhase.idle);
      expect(n.state.isRunning, false);
    });
  });

  group('TimerNotifier — skipPhase', () {
    test('skipPhase from prep enters round 1', () {
      final n = _makeNotifier(prepSeconds: 10);
      n.start(); // → prep
      n.skipPhase(); // → round 1
      expect(n.state.phase, WorkoutPhase.round);
      expect(n.state.currentRound, 1);
      n.dispose();
    });

    test('skipPhase from round enters rest (not last round)', () {
      final n = _makeNotifier(rounds: 3, prepSeconds: 0);
      n.start(); // → round 1
      n.skipPhase(); // → rest
      expect(n.state.phase, WorkoutPhase.rest);
      n.dispose();
    });

    test('skipPhase from rest enters next round', () {
      final n = _makeNotifier(rounds: 3, prepSeconds: 0);
      n.start(); // round 1
      n.skipPhase(); // rest (after round 1)
      n.skipPhase(); // round 2
      expect(n.state.phase, WorkoutPhase.round);
      expect(n.state.currentRound, 2);
      n.dispose();
    });

    test('skipPhase on last round enters finished', () {
      final n = _makeNotifier(rounds: 2, prepSeconds: 0);
      n.start(); // round 1
      n.skipPhase(); // rest
      n.skipPhase(); // round 2
      n.skipPhase(); // finished (no rest after last round)
      expect(n.state.phase, WorkoutPhase.finished);
      n.dispose();
    });
  });

  group('TimerNotifier — audio cues via skipPhase', () {
    test('bell plays when entering a round', () {
      const cfg = TimerConfig(
        rounds: 3,
        roundSeconds: 5,
        restSeconds: 2,
        prepSeconds: 0,
        warningSeconds: 2,
        countdownBeeps: true,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start(); // enters round 1 → fires AudioCue.start
      expect(audio.played, contains(AudioCue.start));
      n.dispose();
    });

    test('bell (finish) plays when leaving a round', () {
      const cfg = TimerConfig(
        rounds: 3,
        roundSeconds: 5,
        restSeconds: 2,
        prepSeconds: 0,
        warningSeconds: 2,
        countdownBeeps: false,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start(); // round 1
      audio.played.clear();
      n.skipPhase(); // ends round → AudioCue.finish
      expect(audio.played, contains(AudioCue.finish));
      n.dispose();
    });

    test('end sound plays when workout finishes', () {
      const cfg = TimerConfig(
        rounds: 1,
        roundSeconds: 5,
        restSeconds: 2,
        prepSeconds: 0,
        warningSeconds: 2,
        countdownBeeps: false,
        haptics: false,
        keepScreenAwake: false,
        volume: 1.0,
        muted: false,
        duckAudio: true,
      );
      final audio = FakeAudioService();
      final n = TimerNotifier(
        audioService: audio,
        hapticService: FakeHapticService(),
        prefsService: FakePrefsService(),
        backgroundSession: FakeBackgroundSession(),
        notificationFallback: FakeNotificationFallback(),
      );
      n.loadConfig(cfg);
      n.start(); // round 1 (only round)
      audio.played.clear();
      n.skipPhase(); // finishes — fires end + finish
      expect(audio.played, contains(AudioCue.end));
      expect(n.state.phase, WorkoutPhase.finished);
      n.dispose();
    });
  });

  group('TimerNotifier — notifyListeners fires only on coarse change', () {
    test('ticking within a phase updates the hot-path notifiers but does '
        'not call notifyListeners; crossing a phase boundary does', () async {
      final n = _makeNotifier(
        rounds: 2,
        roundSeconds: 2,
        restSeconds: 1,
        prepSeconds: 0,
        warningSeconds: 1,
      );
      n.start(); // round 1 begins — this itself is a coarse (forced) notify.

      var notifyCount = 0;
      n.addListener(() => notifyCount++);

      final progressValuesSeen = <double>{};
      n.progressNotifier.addListener(
        () => progressValuesSeen.add(n.progressNotifier.value),
      );

      // Sit well inside round 1 (2s long) — several ticks, no phase change.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(notifyCount, 0,
          reason: 'no phase/round/running transition occurred');
      expect(progressValuesSeen.length, greaterThan(1),
          reason: 'progress notifier should still update every tick');

      // Cross into rest — a coarse transition — notifyListeners must fire.
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(notifyCount, greaterThan(0));
      expect(n.state.phase, WorkoutPhase.rest);

      n.dispose();
    });
  });

  group('TimerNotifier — wall-clock based (no drift)', () {
    test('remaining decreases over real time', () async {
      final n = _makeNotifier(roundSeconds: 10, prepSeconds: 0);
      n.start();
      final before = n.state.remainingMs;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final after = n.state.remainingMs;
      expect(after, lessThan(before));
      n.dispose();
    });

    test('remaining tracks wall clock within 200ms tolerance', () async {
      final n = _makeNotifier(roundSeconds: 10, prepSeconds: 0);
      n.start();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      n.pause();
      const expected = 10000 - 500;
      expect(n.state.remainingMs, closeTo(expected, 200));
      n.dispose();
    });
  });
}
