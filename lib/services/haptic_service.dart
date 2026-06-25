import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

final hapticServiceProvider = Provider<HapticService>((ref) => HapticService());

class HapticService {
  Future<void> buzz() async {
    if (kIsWeb) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    await Vibration.vibrate(duration: 200);
  }

  Future<void> longBuzz() async {
    if (kIsWeb) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    await Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
  }
}
