// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'FANLA';

  @override
  String get welcomeTitle => 'Redescubre la Experiencia del Aficionado';

  @override
  String get welcomeSubtitle =>
      'Sigue los partidos, escucha los cánticos de tu equipo y lleva tu experiencia de aficionado al siguiente nivel.';

  @override
  String get startButton => 'COMENZAR';

  @override
  String get languageSettings => 'Configuración de Idioma';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get loading => 'Cargando...';

  @override
  String get retry => 'Reintentar';

  @override
  String get errorGeneric => 'Ha ocurrido un error';

  @override
  String get errorUnknown => 'Ha ocurrido un error desconocido';

  @override
  String get errorLoadingCountries => 'Error al cargar países';

  @override
  String get errorLoadingTeams => 'Error al cargar equipos';

  @override
  String get errorLoadingMatches => 'Error al cargar partidos';

  @override
  String get noInternetConnection => 'Sin conexión a Internet';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get popularCountries => 'Países Populares';

  @override
  String get popularTeams => 'Equipos Populares';

  @override
  String get featuredTeams => 'Equipos Destacados';

  @override
  String get explore => 'EXPLORAR';

  @override
  String get matches => 'PARTIDOS';

  @override
  String teamCount(int count) {
    return '$count Equipos';
  }

  @override
  String get allMatches => 'Todos los Partidos';

  @override
  String get upcomingMatches => 'Próximos';

  @override
  String get pastMatches => 'Pasados';

  @override
  String get matchStatusPlanned => 'PLANIFICADO';

  @override
  String get matchStatusPlaying => 'EN JUEGO';

  @override
  String get matchStatusFinished => 'FINALIZADO';

  @override
  String get lyricsActive => 'Letras Activas';

  @override
  String get webSocketConnected => 'WebSocket Conectado';

  @override
  String get webSocketDisconnected => 'WebSocket Desconectado';

  @override
  String get checkingTeamSounds => 'Comprobando datos del equipo...';

  @override
  String get allSoundsDownloaded => 'Todos los datos descargados';

  @override
  String downloadingSound(int progress) {
    return 'Descargando datos: $progress%';
  }

  @override
  String readyToJoinMatch(int downloaded, int total) {
    return 'Estás listo para unirte al partido ($downloaded/$total datos)';
  }

  @override
  String someSoundsMissing(int downloaded, int total) {
    return 'Faltan algunos datos ($downloaded/$total descargados)';
  }

  @override
  String get downloadingSoundsTitle => 'Descargando archivos de datos';

  @override
  String get matchDetailSoundsNeeded =>
      'Es necesario descargar todos los archivos de datos para acceder a los detalles del partido.';

  @override
  String soundFilesDownloaded(int downloaded, int total) {
    return '$downloaded/$total archivos de datos descargados';
  }

  @override
  String get ok => 'Aceptar';

  @override
  String get stadiumNotAvailable => 'Información del estadio no disponible';

  @override
  String get matchPreparingTitle => 'PREPARANDO PARA EL PARTIDO';

  @override
  String get matchPreparingSubtitle =>
      'La atmósfera del estadio y el entusiasmo de los aficionados están cargando...';

  @override
  String get matchReadyTitle => 'LISTO PARA EL PARTIDO';

  @override
  String get matchReadySubtitle => '¡Uniéndose al Estadio!';

  @override
  String get joinStadium => 'ACEPTAR';

  @override
  String get teamInfoNotFound => 'Información del equipo no encontrada.';

  @override
  String get advertisement => 'Publicidad';

  @override
  String get websiteUrl => 'fanla.net';

  @override
  String get privacyNotice =>
      'Fanla no recopila ni almacena ningún dato personal.';

  @override
  String get firstTeamSelectionTitle => 'Selección de Equipo';

  @override
  String get firstTeamSelectionMessage =>
      'Te suscribirás a este equipo de forma gratuita. Si deseas cambiar de equipo más adelante, deberás esperar 5 minutos.';

  @override
  String get firstTeamSelectionContinue => 'Continuar';

  @override
  String get firstTeamSelectionCancel => 'Cancelar';

  @override
  String get preparing => 'Preparando...';

  @override
  String downloadingLyrics(Object title) {
    return 'Descargando letras: $title';
  }

  @override
  String get downloadingSpecificData => 'Descargando datos específicos...';
}
