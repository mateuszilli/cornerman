import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timer_config.dart';

final prefsServiceProvider = Provider<PrefsService>((ref) => PrefsService());

class PrefsService {
  static const _kConfig = 'last_config';
  static const _kUserPresets = 'user_presets';

  Future<TimerConfig?> loadLastConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kConfig);
    if (s == null) return null;
    try {
      return TimerConfig.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(TimerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConfig, config.toJsonString());
  }

  Future<List<NamedPreset>> loadUserPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kUserPresets);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => NamedPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUserPresets(List<NamedPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kUserPresets, jsonEncode(presets.map((p) => p.toJson()).toList()));
  }
}
