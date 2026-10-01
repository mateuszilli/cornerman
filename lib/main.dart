import 'package:audio_service/audio_service.dart' as svc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'models/timer_config.dart';
import 'services/audio_service.dart';
import 'services/background_session_service.dart';
import 'services/notification_fallback_service.dart';
import 'services/prefs_service.dart';
import 'state/locale_notifier.dart';
import 'state/timer_notifier.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: CornermanApp()));
}

class CornermanApp extends ConsumerStatefulWidget {
  const CornermanApp({super.key});

  @override
  ConsumerState<CornermanApp> createState() => _CornermanAppState();
}

class _CornermanAppState extends ConsumerState<CornermanApp> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = ref.read(prefsServiceProvider);
    final saved = await prefs.loadLastConfig();
    final config = saved ?? TimerConfig.championship;

    // Must be read (not watched) before timerProvider so both audio_service
    // and Riverpod resolve to the exact same handler instance — audio_service
    // registers whatever `builder` returns as THE platform-facing session,
    // and TimerNotifier binds its transport controls to the Riverpod-cached
    // singleton, so the two must not be separate instances.
    final backgroundSession = ref.read(backgroundSessionServiceProvider);
    await svc.AudioService.init(
      builder: () => backgroundSession,
      config: const svc.AudioServiceConfig(
        androidNotificationChannelId: 'com.cornerman.cornerman.channel.audio',
        androidNotificationChannelName: 'Workout timer',
        // Keep the full foreground service (and its notification/controls)
        // alive through pause, not just while actively counting down.
        androidStopForegroundOnPause: false,
      ),
    );

    final notificationFallback = ref.read(notificationFallbackServiceProvider);
    await notificationFallback.init();
    await notificationFallback.requestPermission();

    ref.read(timerProvider).loadConfig(config);
    await ref.read(audioServiceProvider).preload();
    await ref.read(localeProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Cornerman',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
