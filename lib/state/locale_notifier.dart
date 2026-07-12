import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/prefs_service.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  Future<void> load() async {
    final code = await ref.read(prefsServiceProvider).loadLocale();
    state = code != null ? Locale(code) : null;
  }

  Future<void> setLocale(String? code) async {
    await ref.read(prefsServiceProvider).saveLocale(code);
    state = code != null ? Locale(code) : null;
  }
}
