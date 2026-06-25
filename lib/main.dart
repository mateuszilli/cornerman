import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/timer_config.dart';
import 'services/audio_service.dart';
import 'services/prefs_service.dart';
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
    ref.read(timerProvider.notifier).loadConfig(config);
    await ref.read(audioServiceProvider).preload();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cornerman',
      debugShowCheckedModeBanner: false,
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
