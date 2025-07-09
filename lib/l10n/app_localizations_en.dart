// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FANLA';

  @override
  String get welcomeTitle => 'Rediscover the Fan Experience';

  @override
  String get welcomeSubtitle =>
      'Follow matches, listen to your team\'s chants and take your fan experience to the next level.';

  @override
  String get startButton => 'START';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get errorUnknown => 'An unknown error occurred';

  @override
  String get errorLoadingCountries => 'Failed to load countries';

  @override
  String get errorLoadingTeams => 'Failed to load teams';

  @override
  String get errorLoadingMatches => 'Failed to load matches';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get searchHint => 'Search...';

  @override
  String get popularCountries => 'Popular Countries';

  @override
  String get popularTeams => 'Popular Teams';

  @override
  String get featuredTeams => 'Featured Teams';

  @override
  String get explore => 'EXPLORE';

  @override
  String get matches => 'MATCHES';

  @override
  String teamCount(int count) {
    return '$count Teams';
  }

  @override
  String get allMatches => 'All Matches';

  @override
  String get upcomingMatches => 'Upcoming';

  @override
  String get pastMatches => 'Past';

  @override
  String get matchStatusPlanned => 'PLANNED';

  @override
  String get matchStatusPlaying => 'PLAYING';

  @override
  String get matchStatusFinished => 'FINISHED';

  @override
  String get lyricsActive => 'Lyrics Active';

  @override
  String get webSocketConnected => 'WebSocket Connected';

  @override
  String get webSocketDisconnected => 'WebSocket Disconnected';

  @override
  String get checkingTeamSounds => 'Checking team sounds...';

  @override
  String get allSoundsDownloaded => 'All sounds downloaded';

  @override
  String downloadingSound(int progress) {
    return 'Downloading sound: $progress%';
  }

  @override
  String readyToJoinMatch(int downloaded, int total) {
    return 'You are ready to join the match ($downloaded/$total sounds)';
  }

  @override
  String someSoundsMissing(int downloaded, int total) {
    return 'Some data\'s are missing ($downloaded/$total downloaded)';
  }

  @override
  String get downloadingSoundsTitle => 'Downloading data Files';

  @override
  String get matchDetailSoundsNeeded =>
      'All data files need to be downloaded to access match details.';

  @override
  String soundFilesDownloaded(int downloaded, int total) {
    return '$downloaded/$total data files downloaded';
  }

  @override
  String get ok => 'OK';

  @override
  String get stadiumNotAvailable => 'Stadium information not available';

  @override
  String get matchPreparingTitle => 'PREPARING FOR MATCH';

  @override
  String get matchPreparingSubtitle =>
      'Stadium atmosphere and fan enthusiasm are loading...';

  @override
  String get matchReadyTitle => 'READY FOR MATCH';

  @override
  String get matchReadySubtitle => 'Joining the Stadium!';

  @override
  String get joinStadium => 'OK';

  @override
  String get teamInfoNotFound => 'Team information not found.';

  @override
  String get advertisement => 'Advertisement';

  @override
  String get websiteUrl => 'fanla.net';

  @override
  String get privacyNotice =>
      'Fanla does not collect or store any personal data.';

  @override
  String get firstTeamSelectionTitle => 'Team Selection';

  @override
  String get firstTeamSelectionMessage =>
      'You will be subscribed to this team for free. If you want to change teams later, you will need to wait for 5 minutes.';

  @override
  String get firstTeamSelectionContinue => 'Continue';

  @override
  String get firstTeamSelectionCancel => 'Cancel';

  @override
  String get preparing => 'Preparing...';

  @override
  String downloadingLyrics(Object title) {
    return 'Downloading lyrics: $title';
  }

  @override
  String get downloadingSpecificData => 'Downloading specific data...';
}
