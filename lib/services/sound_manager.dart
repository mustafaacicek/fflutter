import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sound.dart';
import '../models/team.dart';
import '../models/lyrics.dart';
import '../providers/api_provider.dart';
import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';

class SoundManager {
  ApiProvider _apiProvider;

  // Singleton pattern
  static final SoundManager _instance = SoundManager._internal();

  // Map to track which sounds are already decoded
  final Map<int, bool> _decodedSounds = {};

  // Takım değişikliği için zaman kısıtlaması (1 saat = 3600000 milisaniye)
  static const int teamChangeCooldownMs = 300000;

  factory SoundManager({required ApiProvider apiProvider}) {
    _instance._apiProvider = apiProvider;
    return _instance;
  }

  SoundManager._internal() : _apiProvider = ApiProvider();

  // Current download progress
  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> downloadStatus = ValueNotifier<String>('');
  final ValueNotifier<bool> isDownloading = ValueNotifier<bool>(false);

  // Takım değişikliği zamanını kaydet
  Future<void> saveTeamChangeTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_team_change_time', now);
  }

  // Son takım değişikliğinden bu yana geçen süreyi kontrol et
  Future<int> getTimeUntilNextTeamChange() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChangeTime = prefs.getInt('last_team_change_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedTime = now - lastChangeTime;

    if (elapsedTime >= teamChangeCooldownMs) {
      return 0; // Değişiklik yapılabilir
    } else {
      return teamChangeCooldownMs - elapsedTime; // Kalan süre (ms cinsinden)
    }
  }

  // Check if team has changed and handle sound downloads
  Future<bool> handleTeamChange(Team newTeam, BuildContext context) async {
    final int? currentTeamId = await _apiProvider.getCurrentTeamId();

    // If no current team or same team, no need to show warning
    if (currentTeamId == null || currentTeamId == newTeam.id) {
      await syncTeamSounds(newTeam.id, context: context);
      return true;
    }

    // Takım değişikliği için kalan süreyi kontrol et
    final int remainingTime = await getTimeUntilNextTeamChange();

    // Show warning dialog
    final bool shouldContinue = await _showTeamChangeWarning(
      context,
      newTeam,
      remainingTime,
    );
    if (shouldContinue) {
      // Delete sounds from previous team
      await deleteTeamSounds(currentTeamId);

      // Clear old team sounds from API provider
      await _apiProvider.clearTeamSounds(currentTeamId);

      // Sync new team sounds with context for localization
      await syncTeamSounds(newTeam.id, context: context);

      // Save team change time
      await saveTeamChangeTime();

      return true;
    }

    return false;
  }

  // Show warning dialog when changing teams
  Future<bool> _showTeamChangeWarning(
    BuildContext context,
    Team newTeam,
    int remainingTimeMs,
  ) async {
    // Eğer kalan süre varsa, takım değişikliği yapılamaz
    if (remainingTimeMs > 0) {
      // Kalan süreyi dakika ve saniye olarak hesapla
      final int remainingMinutes = (remainingTimeMs / 60000).floor();
      final int remainingSeconds = ((remainingTimeMs % 60000) / 1000).floor();

      // Dil seçimine göre metin belirleme
      String title;
      String message;
      String buttonText;

      final locale = Localizations.localeOf(context).languageCode;

      if (locale == 'en') {
        title = 'Team Change Cooldown';
        message =
            'You cannot change teams right now. Please wait ${remainingMinutes}m ${remainingSeconds}s before changing teams again.';
        buttonText = 'OK';
      } else if (locale == 'es') {
        title = 'Tiempo de Espera';
        message =
            'No puedes cambiar de equipo ahora. Por favor espera ${remainingMinutes}m ${remainingSeconds}s antes de cambiar de equipo nuevamente.';
        buttonText = 'OK';
      } else {
        // Varsayılan olarak Türkçe
        title = 'Takım Değişikliği Bekleme Süresi';
        message =
            'Şu anda takım değiştiremezsiniz. Lütfen tekrar takım değiştirmek için ${remainingMinutes}d ${remainingSeconds}s bekleyin.';
        buttonText = 'Tamam';
      }

      // Bekleme süresi uyarı dialogu göster
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withBlue(220),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 40,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Dialog'u kapat
                      Navigator.of(context).pop();
                      // Önceki ekrana dön (teams sekmesine)
                      Navigator.of(context).pop();
                      // Ekstra güvenlik için bir kez daha pop
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      buttonText,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      return false; // Takım değişikliğine izin verme
    }

    // Dil seçimine göre metin belirleme
    String title;
    String message;
    String cancelText;
    String continueText;

    final locale = Localizations.localeOf(context).languageCode;

    if (locale == 'en') {
      title = 'Team Change';
      message =
          'You are about to switch your team to ${newTeam.name}. Once changed, you will not be able to switch teams again for 5 minutes. Do you want to continue?';
      cancelText = 'Cancel';
      continueText = 'Continue';
    } else if (locale == 'es') {
      title = 'Cambio de Equipo';
      message =
          'Estás a punto de cambiar tu equipo a ${newTeam.name}. Una vez realizado el cambio, no podrás cambiar de equipo nuevamente durante 5 minutos. ¿Quieres continuar?';
      cancelText = 'Cancelar';
      continueText = 'Continuar';
    } else {
      // Varsayılan olarak Türkçe
      title = 'Takım Değiştirilecek';
      message =
          'Takımınızı ${newTeam.name} olarak değiştirmek üzeresiniz. Değişikliği yaparsanız, 5 dakika boyunca tekrar takım değiştiremezsiniz. Devam etmek istiyor musunuz?';
      cancelText = 'İptal';
      continueText = 'Devam Et';
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withBlue(220),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    // Container(
                    //   padding: const EdgeInsets.all(16),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withOpacity(0.2),
                    //     shape: BoxShape.circle,
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: const Color(0xFFFF5722).withOpacity(0.3),
                    //         blurRadius: 15,
                    //         spreadRadius: 5,
                    //       ),
                    //     ],
                    //   ),
                    //   child: const Icon(
                    //     Icons.sports_soccer,
                    //     color: Colors.white,
                    //     size: 40,
                    //   ),
                    // ),
                    // const SizedBox(height: 25),

                    // Başlık
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // İçerik
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // İptal butonu
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                              Navigator.of(
                                context,
                              ).pop(); // Önceki ekrana dön (teams sekmesine)
                            },
                            child: Text(
                              cancelText,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Devam butonu
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                            child: Text(
                              continueText,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  // Sync team sounds with server and local storage
  Future<void> syncTeamSounds(int teamId, {BuildContext? context}) async {
    try {
      // Update download status
      downloadProgress.value = 0.1; // Initial value
      // Use localized string if context is available, otherwise use default string
      downloadStatus.value = context != null
          ? AppLocalizations.of(context).checkingTeamSounds
          : 'Checking team data...';
      isDownloading.value = true;

      // Get sounds from server
      final response = await _apiProvider.getSoundsByTeam(teamId);
      if (!response.success || response.data == null) {
        downloadStatus.value = context != null
            ? 'Error: ${response.error}'
            : 'Data could not be retrieved: ${response.error}';
        isDownloading.value = false;
        return;
      }

      final List<Sound> serverSounds = response.data!;

      // Get stored sounds
      final List<Sound> storedSounds = await _apiProvider.getStoredSounds(
        teamId,
      );

      // Find sounds to download and sounds to delete
      final List<Sound> soundsToDownload = [];
      final Map<int, bool> existingSounds = {};

      for (var serverSound in serverSounds) {
        final storedSound = storedSounds.firstWhere(
          (s) => s.id == serverSound.id,
          orElse: () => Sound(
            id: -1,
            title: '',
            soundUrl: '',
            teamId: teamId,
            teamName: '',
            status: '',
            currentMillisecond: 0,
            updatedAt: DateTime.now(),
            isDownloaded: false,
          ),
        );

        if (storedSound.id == -1 ||
            storedSound.soundUrl != serverSound.soundUrl ||
            storedSound.soundImageUrl != serverSound.soundImageUrl) {
          soundsToDownload.add(serverSound);
        }

        existingSounds[serverSound.id] = true;
        serverSound.isDownloaded = true;
      }

      // Download new sounds
      if (soundsToDownload.isNotEmpty) {
        await _downloadSounds(soundsToDownload, teamId, context: context);
      } else {
        // Use localized string if context is available, otherwise use default string
        downloadStatus.value = context != null
            ? AppLocalizations.of(context).allSoundsDownloaded
            : 'All data up to date';
      }

      // Save updated sounds to local storage
      await _apiProvider.saveTeamSounds(serverSounds, teamId);

      isDownloading.value = false;
      downloadStatus.value = '';
    } catch (e) {
      print('Error syncing team data: $e');
      downloadStatus.value = 'Error: $e';
      isDownloading.value = false;
    }
  }

  // Download sounds from server and save to local storage
  Future<void> _downloadSounds(
    List<Sound> sounds,
    int teamId, {
    BuildContext? context,
  }) async {
    isDownloading.value = true;
    // Use localized string if context is available, otherwise use default string
    downloadStatus.value = context != null
        ? AppLocalizations.of(context).preparing
        : 'Preparing...';
    downloadProgress.value = 0.0;

    // Create team directory if it doesn't exist
    final appDir = await getApplicationDocumentsDirectory();
    final teamDirectory = Directory('${appDir.path}/team_$teamId');
    if (!await teamDirectory.exists()) {
      await teamDirectory.create(recursive: true);
    }

    for (int i = 0; i < sounds.length; i++) {
      final sound = sounds[i];
      // Use localized string if context is available, otherwise use default string
      downloadStatus.value = context != null
          ? AppLocalizations.of(context).preparing
          : 'Preparing...';

      // 1. Download sound file
      final soundFile = File('${teamDirectory.path}/sound_${sound.id}.mp3');
      bool soundDownloaded = false;
      if (!await soundFile.exists()) {
        try {
          final soundResponse = await http.get(Uri.parse(sound.soundUrl));
          await soundFile.writeAsBytes(soundResponse.bodyBytes);
          print('Data downloaded');
          soundDownloaded = true;
        } catch (e) {
          print('Error downloading sound: $e');
          continue; // Skip to next sound if this one fails
        }
      } else {
        soundDownloaded = true;
        print('Data already exists');
      }

      // 2. Download sound image if available
      bool imageDownloaded = false;
      if (sound.soundImageUrl != null && sound.soundImageUrl!.isNotEmpty) {
        final imageFile = File('${teamDirectory.path}/image_${sound.id}.jpg');
        if (!await imageFile.exists()) {
          try {
            final imageResponse = await http.get(
              Uri.parse(sound.soundImageUrl!),
            );
            await imageFile.writeAsBytes(imageResponse.bodyBytes);
            print('Image downloaded for sound: ${sound.title}');
            imageDownloaded = true;
          } catch (e) {
            print('Error downloading image: $e');
            // Continue if image download fails
          }
        } else {
          imageDownloaded = true;
          print('Image already exists for sound: ${sound.title}');
        }
      }

      // 3. Save lyrics if available, otherwise get from API
      bool lyricsDownloaded = false;
      final lyricsFile = File('${teamDirectory.path}/lyrics_${sound.id}.json');

      // First check existing lyrics
      if (sound.lyrics != null && sound.lyrics!.isNotEmpty) {
        if (!await lyricsFile.exists()) {
          try {
            await saveSoundLyrics(sound.teamId, sound.id, sound.lyrics!);
            print('Lyrics saved for sound: ${sound.title}');
            lyricsDownloaded = true;
          } catch (e) {
            print('Error saving lyrics: $e');
          }
        } else {
          lyricsDownloaded = true;
          print('Lyrics already exists for sound: ${sound.title}');
        }
      }

      // Try to get lyrics from API if not downloaded
      if (!lyricsDownloaded) {
        try {
          // Use localized string if context is available, otherwise use default string
          downloadStatus.value = context != null
              ? AppLocalizations.of(context).downloadingLyrics(sound.title)
              : 'Downloading lyrics: ${sound.title}';
          final lyricsResponse = await _apiProvider.getSoundLyrics(
            teamId,
            sound.id,
          );
          if (lyricsResponse.success &&
              lyricsResponse.data != null &&
              lyricsResponse.data!.isNotEmpty) {
            await saveSoundLyrics(teamId, sound.id, lyricsResponse.data!);
            print('Lyrics downloaded and saved for sound: ${sound.title}');
            lyricsDownloaded = true;
          }
        } catch (e) {
          print('Error downloading lyrics: $e');
        }
      }

      downloadProgress.value = (i + 1) / sounds.length;

      // Update download status if sound file was successfully downloaded
      if (soundDownloaded) {
        await _apiProvider.updateSoundDownloadStatus(teamId, sound.id, true);

        // Log download status
        print(
          'Download status updated for sound ${sound.id}: '
          'Sound: $soundDownloaded, Image: $imageDownloaded, Lyrics: $lyricsDownloaded',
        );
      }
    }

    downloadProgress.value = 1.0;
    // Use localized string if context is available, otherwise use default string
    downloadStatus.value = context != null
        ? AppLocalizations.of(context).allSoundsDownloaded
        : 'All data downloaded';
    isDownloading.value = false;
  }

  // Belirli sesleri indirmek için public metod
  Future<void> downloadSpecificSounds(
    List<Sound> sounds,
    int teamId, {
    BuildContext? context,
  }) async {
    // Indicate that a specific download operation has started
    isDownloading.value = true;
    // Use localized string if context is available, otherwise use default string
    downloadStatus.value = context != null
        ? AppLocalizations.of(context).downloadingSpecificData
        : 'Downloading specific data...';
    downloadProgress.value = 0.0;

    // Use _downloadSounds method to perform the download operation
    await _downloadSounds(sounds, teamId, context: context);
  }

  // Get sound file path
  Future<String?> getSoundFilePath(int teamId, int soundId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final soundFile = File(
        '${directory.path}/team_$teamId/sound_$soundId.mp3',
      );

      if (await soundFile.exists()) {
        // If the file exists but hasn't been decoded yet, decode it now
        if (!_decodedSounds.containsKey(soundId) ||
            _decodedSounds[soundId] != true) {
          try {
            await _decodeAudioFile(soundFile.path, teamId, soundId);
          } catch (e) {
            print('Error decoding data file on demand: $e');
          }
        }
        return soundFile.path;
      }

      return null;
    } catch (e) {
      print('Error getting data file path: $e');
      return null;
    }
  }

  // Get sound image file path
  Future<String?> getSoundImageFilePath(int teamId, int soundId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageFile = File(
        '${directory.path}/team_$teamId/image_$soundId.jpg',
      );

      if (await imageFile.exists()) {
        return imageFile.path;
      }

      return null;
    } catch (e) {
      print('Error getting data image file path: $e');
      return null;
    }
  }

  // Get sound lyrics from local storage
  Future<List<Lyrics>?> getSoundLyrics(int teamId, int soundId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final lyricsFile = File(
        '${directory.path}/team_$teamId/lyrics_$soundId.json',
      );

      if (await lyricsFile.exists()) {
        final String jsonContent = await lyricsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonContent);
        return jsonList.map((json) => Lyrics.fromJson(json)).toList();
      }

      return null;
    } catch (e) {
      print('Error getting lyrics: $e');
      return null;
    }
  }

  // Save sound lyrics to local storage
  Future<bool> saveSoundLyrics(
    int teamId,
    int soundId,
    List<Lyrics> lyrics,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final teamDirectory = Directory('${directory.path}/team_$teamId');

      // Create directory if it doesn't exist
      if (!await teamDirectory.exists()) {
        await teamDirectory.create(recursive: true);
      }

      final lyricsFile = File('${teamDirectory.path}/lyrics_$soundId.json');
      final String jsonContent = jsonEncode(
        lyrics.map((lyric) => lyric.toJson()).toList(),
      );
      await lyricsFile.writeAsString(jsonContent);

      print('Lyrics saved for data $soundId');
      return true;
    } catch (e) {
      print('Error saving data lyrics: $e');
      return false;
    }
  }

  // Decode audio file and store in memory
  Future<void> _decodeAudioFile(
    String filePath,
    int teamId,
    int soundId,
  ) async {
    try {
      print('Decoding audio file: $filePath');

      // Create a temporary AudioPlayer instance for decoding
      final tempPlayer = AudioPlayer();

      // Load the audio file
      await tempPlayer.setFilePath(filePath);

      // Wait for the audio to be fully loaded and decoded
      await tempPlayer.load();

      // Mark this sound as decoded
      _decodedSounds[soundId] = true;

      // Save the decoded state to shared preferences
      await _apiProvider.updateSoundDecodeStatus(teamId, soundId, true);

      print('Audio file successfully decoded: $filePath');

      // Dispose the temporary player
      await tempPlayer.dispose();
    } catch (e) {
      print('Error during audio decoding: $e');
      // Mark as not decoded
      _decodedSounds[soundId] = false;
    }
  }

  // Check if a sound is already decoded
  bool isSoundDecoded(int soundId) {
    return _decodedSounds.containsKey(soundId) &&
        _decodedSounds[soundId] == true;
  }

  // Delete all sounds for a team
  Future<void> deleteTeamSounds(int teamId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final teamDirectory = Directory('${directory.path}/team_$teamId');
      final decodedDirectory = Directory(
        '${directory.path}/team_${teamId}_decoded',
      );

      // Delete the sound files directory (contains both audio and images)
      if (await teamDirectory.exists()) {
        await teamDirectory.delete(recursive: true);
      }

      // Delete the decoded audio directory
      if (await decodedDirectory.exists()) {
        await decodedDirectory.delete(recursive: true);
      }

      // Clear the decoded sounds tracking for this team
      _decodedSounds.removeWhere((key, value) {
        // Get the sound file to check if it belongs to this team
        final cacheKey = 'team_${teamId}_sound_$key';
        return cacheKey.contains('team_$teamId');
      });

      await _apiProvider.clearTeamSounds(teamId);
    } catch (e) {
      print('Error deleting team datas: $e');
    }
  }
}
