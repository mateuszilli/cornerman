import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @phaseReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get phaseReady;

  /// No description provided for @phaseGetReady.
  ///
  /// In en, this message translates to:
  /// **'GET READY'**
  String get phaseGetReady;

  /// No description provided for @phaseFight.
  ///
  /// In en, this message translates to:
  /// **'FIGHT'**
  String get phaseFight;

  /// No description provided for @phaseRest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get phaseRest;

  /// No description provided for @phaseDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get phaseDone;

  /// No description provided for @roundCounter.
  ///
  /// In en, this message translates to:
  /// **'ROUND  {current} / {total}'**
  String roundCounter(int current, int total);

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @buttonDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get buttonDone;

  /// No description provided for @sectionPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get sectionPresets;

  /// No description provided for @sectionRounds.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get sectionRounds;

  /// No description provided for @sectionDurations.
  ///
  /// In en, this message translates to:
  /// **'Durations'**
  String get sectionDurations;

  /// No description provided for @sectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get sectionAudio;

  /// No description provided for @sectionDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get sectionDevice;

  /// No description provided for @numberOfRounds.
  ///
  /// In en, this message translates to:
  /// **'Number of rounds'**
  String get numberOfRounds;

  /// No description provided for @roundDuration.
  ///
  /// In en, this message translates to:
  /// **'Round duration'**
  String get roundDuration;

  /// No description provided for @restDuration.
  ///
  /// In en, this message translates to:
  /// **'Rest duration'**
  String get restDuration;

  /// No description provided for @prepDuration.
  ///
  /// In en, this message translates to:
  /// **'Get-ready (prep)'**
  String get prepDuration;

  /// No description provided for @warningLead.
  ///
  /// In en, this message translates to:
  /// **'Warning lead'**
  String get warningLead;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @countdownBeeps.
  ///
  /// In en, this message translates to:
  /// **'Countdown beeps (last 3s)'**
  String get countdownBeeps;

  /// No description provided for @keepScreenAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get keepScreenAwake;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @saveAsPreset.
  ///
  /// In en, this message translates to:
  /// **'Save current as preset'**
  String get saveAsPreset;

  /// No description provided for @presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get presetName;

  /// No description provided for @presetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. My Bag Work'**
  String get presetNameHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
