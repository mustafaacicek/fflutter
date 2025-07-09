import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'FANLA'**
  String get appName;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Rediscover the Fan Experience'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow matches, listen to your team\'s chants and take your fan experience to the next level.'**
  String get welcomeSubtitle;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startButton;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorGeneric;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errorUnknown;

  /// No description provided for @errorLoadingCountries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load countries'**
  String get errorLoadingCountries;

  /// No description provided for @errorLoadingTeams.
  ///
  /// In en, this message translates to:
  /// **'Failed to load teams'**
  String get errorLoadingTeams;

  /// No description provided for @errorLoadingMatches.
  ///
  /// In en, this message translates to:
  /// **'Failed to load matches'**
  String get errorLoadingMatches;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @popularCountries.
  ///
  /// In en, this message translates to:
  /// **'Popular Countries'**
  String get popularCountries;

  /// No description provided for @popularTeams.
  ///
  /// In en, this message translates to:
  /// **'Popular Teams'**
  String get popularTeams;

  /// No description provided for @featuredTeams.
  ///
  /// In en, this message translates to:
  /// **'Featured Teams'**
  String get featuredTeams;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'EXPLORE'**
  String get explore;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'MATCHES'**
  String get matches;

  /// No description provided for @teamCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Teams'**
  String teamCount(int count);

  /// No description provided for @allMatches.
  ///
  /// In en, this message translates to:
  /// **'All Matches'**
  String get allMatches;

  /// No description provided for @upcomingMatches.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingMatches;

  /// No description provided for @pastMatches.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get pastMatches;

  /// No description provided for @matchStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'PLANNED'**
  String get matchStatusPlanned;

  /// No description provided for @matchStatusPlaying.
  ///
  /// In en, this message translates to:
  /// **'PLAYING'**
  String get matchStatusPlaying;

  /// No description provided for @matchStatusFinished.
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get matchStatusFinished;

  /// No description provided for @lyricsActive.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Active'**
  String get lyricsActive;

  /// No description provided for @webSocketConnected.
  ///
  /// In en, this message translates to:
  /// **'WebSocket Connected'**
  String get webSocketConnected;

  /// No description provided for @webSocketDisconnected.
  ///
  /// In en, this message translates to:
  /// **'WebSocket Disconnected'**
  String get webSocketDisconnected;

  /// No description provided for @checkingTeamSounds.
  ///
  /// In en, this message translates to:
  /// **'Checking team sounds...'**
  String get checkingTeamSounds;

  /// No description provided for @allSoundsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'All sounds downloaded'**
  String get allSoundsDownloaded;

  /// No description provided for @downloadingSound.
  ///
  /// In en, this message translates to:
  /// **'Downloading sound: {progress}%'**
  String downloadingSound(int progress);

  /// No description provided for @readyToJoinMatch.
  ///
  /// In en, this message translates to:
  /// **'You are ready to join the match ({downloaded}/{total} sounds)'**
  String readyToJoinMatch(int downloaded, int total);

  /// No description provided for @someSoundsMissing.
  ///
  /// In en, this message translates to:
  /// **'Some data\'s are missing ({downloaded}/{total} downloaded)'**
  String someSoundsMissing(int downloaded, int total);

  /// No description provided for @downloadingSoundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading data Files'**
  String get downloadingSoundsTitle;

  /// No description provided for @matchDetailSoundsNeeded.
  ///
  /// In en, this message translates to:
  /// **'All data files need to be downloaded to access match details.'**
  String get matchDetailSoundsNeeded;

  /// No description provided for @soundFilesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{downloaded}/{total} data files downloaded'**
  String soundFilesDownloaded(int downloaded, int total);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @stadiumNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Stadium information not available'**
  String get stadiumNotAvailable;

  /// No description provided for @matchPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'PREPARING FOR MATCH'**
  String get matchPreparingTitle;

  /// No description provided for @matchPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stadium atmosphere and fan enthusiasm are loading...'**
  String get matchPreparingSubtitle;

  /// No description provided for @matchReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'READY FOR MATCH'**
  String get matchReadyTitle;

  /// No description provided for @matchReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Joining the Stadium!'**
  String get matchReadySubtitle;

  /// No description provided for @joinStadium.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get joinStadium;

  /// No description provided for @teamInfoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Team information not found.'**
  String get teamInfoNotFound;

  /// No description provided for @advertisement.
  ///
  /// In en, this message translates to:
  /// **'Advertisement'**
  String get advertisement;

  /// No description provided for @websiteUrl.
  ///
  /// In en, this message translates to:
  /// **'fanla.net'**
  String get websiteUrl;

  /// No description provided for @privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Fanla does not collect or store any personal data.'**
  String get privacyNotice;

  /// No description provided for @firstTeamSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Team Selection'**
  String get firstTeamSelectionTitle;

  /// No description provided for @firstTeamSelectionMessage.
  ///
  /// In en, this message translates to:
  /// **'You will be subscribed to this team for free. If you want to change teams later, you will need to wait for 5 minutes.'**
  String get firstTeamSelectionMessage;

  /// No description provided for @firstTeamSelectionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get firstTeamSelectionContinue;

  /// No description provided for @firstTeamSelectionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get firstTeamSelectionCancel;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @downloadingLyrics.
  ///
  /// In en, this message translates to:
  /// **'Downloading lyrics: {title}'**
  String downloadingLyrics(Object title);

  /// No description provided for @downloadingSpecificData.
  ///
  /// In en, this message translates to:
  /// **'Downloading specific data...'**
  String get downloadingSpecificData;
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
      <String>['en', 'es', 'tr'].contains(locale.languageCode);

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
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
