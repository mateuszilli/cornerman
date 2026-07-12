// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get phaseReady => 'PRONTO';

  @override
  String get phaseGetReady => 'PREPARE-SE';

  @override
  String get phaseFight => 'LUTA';

  @override
  String get phaseRest => 'DESCANSO';

  @override
  String get phaseDone => 'FIM';

  @override
  String roundCounter(int current, int total) {
    return 'ROUND  $current / $total';
  }

  @override
  String get settingsTooltip => 'Configurações';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get buttonDone => 'PRONTO';

  @override
  String get sectionPresets => 'Predefinições';

  @override
  String get sectionRounds => 'Rounds';

  @override
  String get sectionDurations => 'Durações';

  @override
  String get sectionAudio => 'Áudio';

  @override
  String get sectionDevice => 'Dispositivo';

  @override
  String get numberOfRounds => 'Número de rounds';

  @override
  String get roundDuration => 'Duração do round';

  @override
  String get restDuration => 'Duração do descanso';

  @override
  String get prepDuration => 'Preparação';

  @override
  String get warningLead => 'Aviso prévio';

  @override
  String get volume => 'Volume';

  @override
  String get mute => 'Silenciar';

  @override
  String get countdownBeeps => 'Bipes de contagem regressiva (últimos 3s)';

  @override
  String get keepScreenAwake => 'Manter tela ativa';

  @override
  String get hapticFeedback => 'Vibração';

  @override
  String get saveAsPreset => 'Guardar como predefinição';

  @override
  String get presetName => 'Nome da predefinição';

  @override
  String get presetNameHint => 'ex. Meu Saco';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get reset => 'Reiniciar';

  @override
  String get start => 'Iniciar';

  @override
  String get pause => 'Pausar';

  @override
  String get resume => 'Retomar';

  @override
  String get skip => 'Pular';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';
}
