// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get phaseReady => 'LISTO';

  @override
  String get phaseGetReady => 'PREPÁRATE';

  @override
  String get phaseFight => 'PELEA';

  @override
  String get phaseRest => 'DESCANSO';

  @override
  String get phaseDone => 'FIN';

  @override
  String roundCounter(int current, int total) {
    return 'ROUND  $current / $total';
  }

  @override
  String get settingsTooltip => 'Ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get buttonDone => 'LISTO';

  @override
  String get sectionPresets => 'Preajustes';

  @override
  String get sectionRounds => 'Rounds';

  @override
  String get sectionDurations => 'Duraciones';

  @override
  String get sectionAudio => 'Audio';

  @override
  String get sectionDevice => 'Dispositivo';

  @override
  String get numberOfRounds => 'Número de rounds';

  @override
  String get roundDuration => 'Duración del round';

  @override
  String get restDuration => 'Duración del descanso';

  @override
  String get prepDuration => 'Preparación';

  @override
  String get warningLead => 'Aviso previo';

  @override
  String get volume => 'Volumen';

  @override
  String get mute => 'Silencio';

  @override
  String get countdownBeeps => 'Pitidos de cuenta atrás (últimos 3s)';

  @override
  String get keepScreenAwake => 'Mantener pantalla activa';

  @override
  String get hapticFeedback => 'Vibración';

  @override
  String get saveAsPreset => 'Guardar como preajuste';

  @override
  String get presetName => 'Nombre del preajuste';

  @override
  String get presetNameHint => 'p.ej. Mi Saco';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get reset => 'Reiniciar';

  @override
  String get start => 'Iniciar';

  @override
  String get pause => 'Pausa';

  @override
  String get resume => 'Continuar';

  @override
  String get skip => 'Saltar';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';
}
