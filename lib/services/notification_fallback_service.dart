import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/workout_schedule.dart';
import '../models/workout_state.dart';

final notificationFallbackServiceProvider =
    Provider<NotificationFallbackService>((ref) => NotificationFallbackService());

/// The subset of [NotificationFallbackService] that `TimerNotifier` depends
/// on, so tests can fake it without touching the platform-channel plugin.
abstract class NotificationFallback {
  Future<void> scheduleAll(WorkoutState state, WorkoutSchedule schedule);
  Future<void> cancelAll();
}

/// Belt-and-braces fallback for iOS: pre-schedules a local notification for
/// every *boundary* cue (preStart/start/preFinish/finish/workoutEnd) so cues
/// still fire audibly if the primary background-audio-session path
/// (`BackgroundSessionService`) ever gets suspended — low-power mode, an OS
/// edge case, etc.
///
/// Deliberately excludes the 3-2-1 countdown beeps: iOS caps an app at 64
/// pending local notifications, and a full championship workout's beeps
/// alone would blow that budget. Boundary cues (~49 for a 12-round workout)
/// fit comfortably and matter more than the beeps if the OS ever suspends
/// the app. Beeps still fire normally via the live primary path.
///
/// No-op on Android: the foreground service keeps the process alive live,
/// so a second, redundant notification channel would just be spam.
///
/// NOTE: for these notifications to play the correct cue sound on iOS,
/// bell.wav/clapper.wav/beep.wav must additionally be added to the Runner
/// Xcode target's "Copy Bundle Resources" build phase — declaring them as
/// Flutter assets (already done, for in-app playback) is not sufficient;
/// iOS notification sounds must be top-level app-bundle resources.
class NotificationFallbackService implements NotificationFallback {
  static const _fallbackTypes = {
    CueType.preStart,
    CueType.start,
    CueType.preFinish,
    CueType.finish,
    CueType.workoutEnd,
  };

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// The boundary cues selected for the fallback. Exposed standalone so it
  /// can be unit-tested (cue count under the 64 cap, beeps excluded)
  /// without touching the plugin's platform channel.
  static List<CueEvent> fallbackCues(WorkoutSchedule schedule) =>
      schedule.cues.where((c) => _fallbackTypes.contains(c.type)).toList();

  @override
  Future<void> scheduleAll(WorkoutState state, WorkoutSchedule schedule) async {
    if (!_isIOS || state.startedAt == null) return;
    await cancelAll();
    final now = DateTime.now();
    for (final cue in fallbackCues(schedule)) {
      final at = state.startedAt!
          .add(cue.at)
          .add(state.pausedOffset)
          .subtract(state.skipOffset);
      if (at.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        id: cue.seq,
        title: _titleFor(cue.type),
        body: null,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(sound: _soundFor(cue.type)),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_initialized || !_isIOS) return;
    await _plugin.cancelAll();
  }

  String _titleFor(CueType type) => switch (type) {
        CueType.start => 'Round starts',
        CueType.finish => 'Round ends',
        CueType.preStart || CueType.preFinish => 'Get ready',
        CueType.workoutEnd => 'Workout complete',
        CueType.beep => 'Beep',
      };

  String _soundFor(CueType type) => switch (type) {
        CueType.start || CueType.finish || CueType.workoutEnd => 'bell.wav',
        CueType.preStart || CueType.preFinish => 'clapper.wav',
        CueType.beep => 'beep.wav',
      };
}
