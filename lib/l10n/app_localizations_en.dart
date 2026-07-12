// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get phaseReady => 'READY';

  @override
  String get phaseGetReady => 'GET READY';

  @override
  String get phaseFight => 'FIGHT';

  @override
  String get phaseRest => 'REST';

  @override
  String get phaseDone => 'DONE';

  @override
  String roundCounter(int current, int total) {
    return 'ROUND  $current / $total';
  }

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get buttonDone => 'DONE';

  @override
  String get sectionPresets => 'Presets';

  @override
  String get sectionRounds => 'Rounds';

  @override
  String get sectionDurations => 'Durations';

  @override
  String get sectionAudio => 'Audio';

  @override
  String get sectionDevice => 'Device';

  @override
  String get numberOfRounds => 'Number of rounds';

  @override
  String get roundDuration => 'Round duration';

  @override
  String get restDuration => 'Rest duration';

  @override
  String get prepDuration => 'Get-ready (prep)';

  @override
  String get warningLead => 'Warning lead';

  @override
  String get volume => 'Volume';

  @override
  String get mute => 'Mute';

  @override
  String get countdownBeeps => 'Countdown beeps (last 3s)';

  @override
  String get keepScreenAwake => 'Keep screen awake';

  @override
  String get hapticFeedback => 'Haptic feedback';

  @override
  String get saveAsPreset => 'Save current as preset';

  @override
  String get presetName => 'Preset name';

  @override
  String get presetNameHint => 'e.g. My Bag Work';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get reset => 'Reset';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get skip => 'Skip';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';
}
