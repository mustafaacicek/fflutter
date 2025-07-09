import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fanlaflutter/models/match.dart';
import 'package:fanlaflutter/models/sound.dart';
import 'package:fanlaflutter/models/lyrics.dart';
import 'package:fanlaflutter/models/team_ad.dart';
import 'package:fanlaflutter/services/audio_service.dart';
import 'package:fanlaflutter/services/sound_manager.dart';
import 'package:fanlaflutter/services/websocket_service.dart';
import 'package:fanlaflutter/services/team_ad_service.dart';
// import 'package:fanlaflutter/utils/constants.dart'; // Artık kullanılmıyor
import 'package:fanlaflutter/providers/api_provider.dart';
import 'package:fanlaflutter/utils/app_theme.dart';
import 'package:torch_light/torch_light.dart';

class MatchDetailNewScreen extends StatefulWidget {
  final Match match;

  const MatchDetailNewScreen({Key? key, required this.match}) : super(key: key);

  @override
  State<MatchDetailNewScreen> createState() => _MatchDetailNewScreenState();
}

class _MatchDetailNewScreenState extends State<MatchDetailNewScreen> {
  // Services
  final AudioService _audioService = AudioService();
  late final SoundManager _soundManager;
  late final ApiProvider _apiProvider;
  final WebSocketService _webSocketService = WebSocketService();
  final TeamAdService _teamAdService = TeamAdService();

  // Reklam değişkenleri
  TeamAd? _topBannerAd;
  TeamAd? _bottomBannerAd;
  bool _isAdLoading = false;

  // WebSocket connection
  StreamSubscription? _webSocketSubscription;

  // Fields for sound state management
  Sound? _currentSound;
  List<Sound> _teamSounds = [];
  List<Lyrics>? _currentLyrics;
  bool _isLoading = true;

  // Flashlight state
  bool _flashlightEnabled = false;

  // Zaman senkronizasyonu için değişkenler
  int _serverTimeDifference =
      0; // Sunucu saati ile cihaz saati arasındaki fark (ms)
  List<int> _recentTimeDifferences = []; // Son zaman farklarını tutan liste

  // Local timing mechanism
  int _localCurrentMillisecond = 0;
  DateTime? _localTimerStartTime;
  Timer? _localPositionTimer;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _apiProvider = ApiProvider();
    _soundManager = SoundManager(apiProvider: _apiProvider);
    _initializeServices();
    _loadAllBannerAds(
      forceRefresh: true,
    ); // İlk yüklemede reklamları zorla yenile
  }

  // Ekran her görünür olduğunda çağrılır
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ekran tekrar görünür olduğunda reklamları yeniden yükle
    // Bu sayede maçtan çıkıp tekrar girdiğinizde güncel reklam durumunu göreceksiniz
    _loadAllBannerAds(forceRefresh: true);
  }

  @override
  void dispose() async {
    print('Disposing MatchDetailNewScreen');
    // Önce WebSocket aboneliğini iptal et
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    // Zamanlayıcıları iptal et
    _localPositionTimer?.cancel();
    _syncTimer?.cancel();
    _localPositionTimer = null;
    _syncTimer = null;

    // Ses çalmayı durdur ve kaynakları temizle
    _audioService.stop().then((_) {
      _audioService.dispose();
    });

    // Fener ışığını kapat
    if (_flashlightEnabled) {
      try {
        await TorchLight.disableTorch();
        print('Fener ışığı kapatıldı (dispose)');
      } catch (e) {
        print('Fener ışığını kapatma hatası: $e');
      }
    }

    // WebSocket bağlantısını tamamen kapat ve yeniden bağlanma girişimlerini önle
    _webSocketService.forceDisconnect();

    super.dispose();
  }

  // Flashlight durumunu değiştiren metod
  void _toggleFlashlight(bool enabled) async {
    try {
      setState(() {
        _flashlightEnabled = enabled;
      });

      if (enabled) {
        // Cihazın fener özelliğini destekleyip desteklemediğini kontrol et
        bool isSupported = await TorchLight.isTorchAvailable();

        if (isSupported) {
          // Feneri aç
          await TorchLight.enableTorch();
          print('Fener ışığı açıldı');
        } else {
          print('Bu cihaz fener özelliğini desteklemiyor');
        }
      } else {
        // Feneri kapat
        await TorchLight.disableTorch();
        print('Fener ışığı kapatıldı');
      }
    } catch (e) {
      print('Fener ışığı kontrolünde hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _buildContent(),
    );
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
    });

    // Initialize audio service
    await _audioService.init();

    // Load team sounds first and prepare them for playback
    await _loadTeamSounds();

    // Preload all sound files to ensure they're ready to play instantly
    await _preloadAllSoundFiles();

    // Connect to WebSocket only after all sounds are prepared
    _connectToWebSocket();

    // Eğer mevcut bir ses varsa, lyrics'i yükle (ilk girişte lyrics gösterimi için)
    if (_teamSounds.isNotEmpty) {
      // Varsayılan olarak ilk sesi seç
      final Sound firstSound = _teamSounds.first;
      setState(() {
        _currentSound = firstSound;
      });

      // Lyrics'i yükle
      await _loadLyricsForSound(firstSound.teamId, firstSound.id);
    }

    setState(() {
      _isLoading = false;
    });

    print('All services initialized and sounds preloaded');
  }

  // Tüm banner reklamları yükle
  // forceRefresh true ise, önbellekteki veriyi kullanmadan doğrudan API'den yeni veri çeker
  Future<void> _loadAllBannerAds({bool forceRefresh = false}) async {
    setState(() {
      _isAdLoading = true;
    });

    try {
      // Match'in team ID'sini kullanarak o takımın reklamlarını getir
      final teamId = widget.match.teamId;
      print(
        'Loading all banner ads for team ID: $teamId with forceRefresh: $forceRefresh',
      );

      // TOP_BANNER reklamını yükle
      final topAd = await _teamAdService.getActiveTeamAdByPosition(
        teamId,
        'TOP_BANNER',
        forceRefresh: forceRefresh,
      );

      // BOTTOM_BANNER reklamını yükle
      final bottomAd = await _teamAdService.getActiveTeamAdByPosition(
        teamId,
        'BOTTOM_BANNER',
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _topBannerAd = topAd;
          _bottomBannerAd = bottomAd;
          _isAdLoading = false;
        });

        print(
          'TOP_BANNER ad loaded: ${topAd != null ? topAd.title : 'No active ad'}',
        );
        print(
          'BOTTOM_BANNER ad loaded: ${bottomAd != null ? bottomAd.title : 'No active ad'}',
        );
      }
    } catch (e) {
      print('Error loading banner ads: $e');
      if (mounted) {
        setState(() {
          _isAdLoading = false;
        });
      }
    }
  }

  // Geriye uyumluluk için gerekirse buraya eski metodu ekleyebilirsiniz

  // Belirli bir ses için lyrics'i yükleyen yardımcı metot
  Future<void> _loadLyricsForSound(int teamId, int soundId) async {
    try {
      print('Loading lyrics for sound $soundId');
      final lyrics = await _soundManager.getSoundLyrics(teamId, soundId);
      if (lyrics != null && lyrics.isNotEmpty && mounted) {
        setState(() {
          _currentLyrics = lyrics;
        });
        print('Loaded ${lyrics.length} lyrics for sound $soundId');
      } else {
        print('No lyrics found in local storage for sound $soundId');

        // Eğer yerel depodan lyrics bulunamadıysa, mevcut sound nesnesinden kontrol et
        Sound? sound = _teamSounds.firstWhere(
          (s) => s.id == soundId,
          orElse: () => Sound(
            id: -1,
            title: '',
            soundUrl: '',
            teamId: -1,
            teamName: '',
            status: '',
            currentMillisecond: 0,
            updatedAt: DateTime.now(),
            isDownloaded: false,
          ),
        );

        if (sound.id != -1 &&
            sound.lyrics != null &&
            sound.lyrics!.isNotEmpty) {
          setState(() {
            _currentLyrics = sound.lyrics;
          });
          print('Using ${sound.lyrics!.length} lyrics from sound object');

          // Lyrics'i yerel depoya kaydet
          await _soundManager.saveSoundLyrics(teamId, soundId, sound.lyrics!);
          print('Saved lyrics to local storage for future use');
        }
      }
    } catch (e) {
      print('Error loading lyrics for sound $soundId: $e');
    }
  }

  Future<void> _loadTeamSounds() async {
    try {
      print('Loading team sounds for team ID: ${widget.match.teamId}');
      final sounds = await _apiProvider.getStoredSounds(widget.match.teamId);
      setState(() {
        _teamSounds = sounds;
      });
      print('Loaded ${sounds.length} team sounds');
    } catch (e) {
      print('Error loading team sounds: $e');
    }
  }

  // Tüm ses dosyalarını önceden hazırlayan metot
  Future<void> _preloadAllSoundFiles() async {
    if (_teamSounds.isEmpty) {
      print('No sounds to preload');
      return;
    }

    print('Preloading ${_teamSounds.length} sound files for instant playback');

    // Her ses için dosya yolunu al ve ön hafızaya yükle
    for (final sound in _teamSounds) {
      try {
        final String? filePath = await _soundManager.getSoundFilePath(
          sound.teamId,
          sound.id,
        );

        if (filePath != null) {
          // Dosyayı ön hafızaya yükle
          await _audioService.preloadAudioFile(filePath);
          print('Preloaded sound ${sound.id}: ${sound.title}');
        } else {
          print(
            'Sound file not found locally for sound ${sound.id}, attempting to download',
          );
          await _downloadMissingSound(sound);
        }
      } catch (e) {
        print('Error preloading sound ${sound.id}: $e');
      }
    }

    print('All sound files preloaded successfully');
  }

  // Eksik ses dosyasını indirme (private metot)
  Future<void> _downloadMissingSound(Sound sound) async {
    try {
      // ApiProvider'dan ses bilgilerini al
      final apiProvider = context.read<ApiProvider>();
      final response = await apiProvider.getSoundsByTeam(sound.teamId);

      if (response.success && response.data != null) {
        final serverSounds = response.data!;
        final serverSound = serverSounds.firstWhere(
          (s) => s.id == sound.id,
          orElse: () => Sound(
            id: -1,
            title: '',
            soundUrl: '',
            teamId: sound.teamId,
            teamName: '',
            status: '',
            currentMillisecond: 0,
            updatedAt: DateTime.now(),
            isDownloaded: false,
          ),
        );

        if (serverSound.id != -1) {
          // Tek bir sesi indir
          List<Sound> soundsToDownload = [serverSound];
          await _soundManager.downloadSpecificSounds(
            soundsToDownload,
            sound.teamId,
          );
          print('Downloaded missing sound: ${sound.id}');
        } else {
          print('Sound ${sound.id} not found on server');
        }
      } else {
        print(
          'Failed to get sounds from server: ${response.error ?? "Unknown error"}',
        );
      }
    } catch (e) {
      print('Error downloading missing sound ${sound.id}: $e');
    }
  }

  void _connectToWebSocket() {
    print('Connecting to WebSocket for match ID: ${widget.match.id}');

    // Bağlantı öncesi mevcut durumu temizle
    setState(() {
      // Mevcut ses durumunu sıfırla
      _currentSound = null;
      _currentLyrics = null;
    });

    // WebSocket bağlantısını kur - maç nesnesini de geçir
    print(
      'Connecting to WebSocket with match object that has team: ${widget.match.team != null ? "Yes" : "No"}',
    );

    // WebSocket bağlantısını kur ve maç nesnesini de geçir
    _webSocketService.connect(widget.match.id, match: widget.match).then((
      connected,
    ) {
      if (!connected) {
        // Bağlantı başarısız olursa kullanıcıya bildir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WebSocket bağlantısı kurulamadı. Takım serverUrl bilgisi: ${widget.match.team?.serverUrl ?? "Yok"}',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // Bağlantı başarılı olduğunda bildir
        print(
          'WebSocket connection established successfully for match ${widget.match.id}',
        );
      }
    });

    // Subscribe to the message stream
    _webSocketSubscription = _webSocketService.messageStream.listen(
      (Map<String, dynamic> update) {
        print('WebSocket message received: $update');
        _handleServerUpdate(update);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _reconnectWebSocket();
      },
      onDone: () {
        print('WebSocket connection closed');
        _reconnectWebSocket();
      },
    );
  }

  void _reconnectWebSocket() {
    // Attempt to reconnect after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _connectToWebSocket();
      }
    });
  }

  void _handleServerUpdate(Map<String, dynamic> update) {
    print('Received WebSocket update: $update');

    // Flashlight durumunu kontrol et
    if (update.containsKey('flashlightEnabled')) {
      final bool flashlightEnabled = update['flashlightEnabled'] ?? false;
      print('Flashlight state updated: $flashlightEnabled');
      _toggleFlashlight(flashlightEnabled);
    }

    // Parse sound data
    if (update.containsKey('soundId') &&
        update.containsKey('status') &&
        update.containsKey('currentMillisecond')) {
      final int soundId = update['soundId'];
      final String status = update['status'];
      final int currentMillisecond = update['currentMillisecond'];

      // startAtEpochMillis varsa kullan, yoksa şu anki zamanı kullan
      final int startAtEpochMillis = update.containsKey('startAtEpochMillis')
          ? update['startAtEpochMillis']
          : DateTime.now().millisecondsSinceEpoch;

      print(
        'WEBSOCKET UPDATE - soundId=$soundId, status=$status, position=$currentMillisecond, startAtEpoch=$startAtEpochMillis',
      );

      // Mevcut çalan ses ile gelen ses aynı mı kontrol et
      bool isSameSoundPlaying =
          _currentSound != null && _currentSound!.id == soundId;

      // Zaman farkını hesapla (sunucu saati ile cihaz saati arasındaki fark)
      final int currentEpochMillis = DateTime.now().millisecondsSinceEpoch;
      final int timeDifference = currentEpochMillis - startAtEpochMillis;

      // Sunucu zamanı farkını güncelle (ileride kullanmak için)
      _updateServerTimeDifference(startAtEpochMillis, currentEpochMillis);

      // Eğer STARTED veya RESUMED durumunda ve zaman farkı varsa, pozisyonu güncelle
      int adjustedPosition = currentMillisecond;

      // Pozisyon hesaplama algoritmasını iyileştir
      if ((status == 'STARTED' || status == 'RESUMED')) {
        // Eğer aynı ses çalıyorsa ve yerel zamanlayıcı çalışıyorsa
        if (isSameSoundPlaying && _localPositionTimer != null) {
          // Yerel zamanlayıcının pozisyonu ile gelen pozisyon arasında büyük fark varsa
          // (5 saniyeden fazla) gelen pozisyonu kullan, aksi halde yerel zamanlayıcıyı koru
          int positionDifference =
              (_localCurrentMillisecond - currentMillisecond).abs();
          if (positionDifference > 5000) {
            print(
              'Large position difference detected: $positionDifference ms. Using server position.',
            );
            adjustedPosition = currentMillisecond;
            // Zamanlayıcıyı yeniden başlat
            _stopLocalTimer();
            _startLocalTimer(adjustedPosition);
          } else {
            // Küçük farklar için yerel zamanlayıcıya güven
            print(
              'Small position difference: $positionDifference ms. Keeping local timer.',
            );
            // Yerel pozisyonu koru, ancak sunucu zamanını dikkate al
            if (timeDifference > 0 && timeDifference < 2000) {
              // 2 saniyeden az fark varsa
              adjustedPosition = _localCurrentMillisecond;
            }
          }
        } else {
          // Farklı ses çalıyorsa veya zamanlayıcı çalışmıyorsa, sunucu pozisyonunu kullan
          if (timeDifference > 0 && timeDifference < 10000) {
            // Makul bir zaman farkı kontrolü (10 saniyeden az)
            // Normal durumda, geçen süreyi ekle
            adjustedPosition = currentMillisecond + timeDifference;
            print(
              'Adjusting position due to time difference: original=$currentMillisecond, adjusted=$adjustedPosition, diff=$timeDifference',
            );
          } else if (timeDifference < -1000) {
            // Cihaz saati sunucu saatinden çok gerideyse (1 saniyeden fazla)
            print(
              'Warning: Device time is behind server time by ${-timeDifference}ms',
            );
            // Minimum pozisyonu koru
            adjustedPosition = currentMillisecond;
          } else if (timeDifference >= 10000) {
            // Zaman farkı çok büyükse (10 saniyeden fazla), bu muhtemelen eski bir mesaj
            // veya zaman senkronizasyon problemi - orijinal pozisyonu kullan
            print(
              'Warning: Time difference too large (${timeDifference}ms), using original position',
            );
            adjustedPosition = currentMillisecond;
          }
        }
      }

      // WebSocket mesajını işle
      _processWebSocketMessage(soundId, status, adjustedPosition);

      // Eğer ses çalmaya başladıysa veya devam ediyorsa, senkronizasyon kontrolünü başlat
      if (status == 'STARTED' || status == 'RESUMED') {
        _startSyncCheck();
      }
    }
  }

  // WebSocket mesajlarını işleyen yeni metot
  void _processWebSocketMessage(
    int soundId,
    String status,
    int currentMillisecond,
  ) async {
    print(
      'Processing WebSocket message: soundId=$soundId, status=$status, position=$currentMillisecond',
    );

    // Eğer mevcut sound'dan farklı bir sound geliyorsa, lyrics'i temizle ve yeni sound için lyrics'i yükle
    // Bu, sound değiştiğinde eski lyrics'in görünmesini engeller
    bool isSoundChanged = _currentSound == null || _currentSound!.id != soundId;
    if (isSoundChanged) {
      print(
        'Sound changed from ${_currentSound?.id} to $soundId, clearing lyrics and loading new ones',
      );
      setState(() {
        _currentLyrics = null; // Eski lyrics'i temizle
      });

      // Yeni sound için lyrics'i hemen yükle
      _loadLyricsForSound(widget.match.teamId, soundId);
    }

    // Öncelikle ses dosyasını yerel depodan yükle
    Sound? storedSound = await _getSoundFromLocalStorage(soundId);
    if (storedSound == null) {
      print('ERROR: Sound $soundId not found in local storage');
      return;
    }

    // Ses dosyasının yolunu al
    final String? filePath = await _soundManager.getSoundFilePath(
      storedSound.teamId,
      storedSound.id,
    );

    if (filePath == null) {
      print('Sound file path not found for sound $soundId');
      return;
    }

    // Güncel ses bilgilerini oluştur
    Sound updatedSound = Sound(
      id: soundId,
      title: storedSound.title,
      soundUrl: storedSound.soundUrl,
      soundImageUrl: storedSound.soundImageUrl,
      teamId: widget.match.teamId,
      teamName: widget.match.teamName,
      status: status,
      currentMillisecond: currentMillisecond,
      updatedAt: DateTime.now(),
      isDownloaded: true,
      lyrics: storedSound.lyrics,
    );

    // UI'ı güncelle
    setState(() {
      _currentSound = updatedSound;

      // Ses listesini güncelle
      int soundIndex = _teamSounds.indexWhere((s) => s.id == soundId);
      if (soundIndex >= 0) {
        _teamSounds[soundIndex] = updatedSound;
      } else {
        _teamSounds.add(updatedSound);
      }
    });

    print('Sound status updated to: $status for sound $soundId');

    // Duruma göre ses çalma işlemini yönet
    switch (status) {
      case 'STARTED':
        print(
          'STARTED command received - Playing sound: $soundId at position: $currentMillisecond',
        );
        // Önce mevcut sesi durdur ve temizle
        await _audioService.stop();
        _stopLocalTimer();

        // Yeni sesi çal
        await _audioService.forcePlayLocalAudio(
          filePath,
          startPositionMs: currentMillisecond,
        );
        _startLocalTimer(currentMillisecond);
        break;

      case 'RESUMED':
        print(
          'RESUMED command received - Resuming sound: $soundId at position: $currentMillisecond',
        );
        // Duraklatılmış sesi devam ettir veya yeni pozisyonda çal
        if (_audioService.isPlaying.value) {
          // Zaten çalıyorsa, pozisyonu güncelle
          await _audioService.seek(Duration(milliseconds: currentMillisecond));
        } else {
          // Çalmıyorsa, başlat
          await _audioService.forcePlayLocalAudio(
            filePath,
            startPositionMs: currentMillisecond,
          );
        }
        _startLocalTimer(currentMillisecond);
        break;

      case 'PAUSED':
        print('PAUSED command received - Pausing sound: $soundId');
        await _audioService.pause();
        _stopLocalTimer();
        break;

      case 'STOPPED':
        print('STOPPED command received - Stopping sound: $soundId');
        // Sesi tamamen durdur
        await _audioService.stop();
        _stopLocalTimer();
        break;
    }

    // Sound değiştiğinde lyrics'i zaten yüklediğimiz için, burada tekrar yüklemeye gerek yok
    // Ancak sound değişmediyse ve lyrics yoksa, yüklemeyi dene
    if (mounted &&
        !isSoundChanged &&
        (_currentLyrics == null || _currentLyrics!.isEmpty)) {
      await _loadLyricsForSound(widget.match.teamId, soundId);
    }
  }

  // Yerel depodan ses dosyasını yükle
  Future<Sound?> _getSoundFromLocalStorage(int soundId) async {
    try {
      final apiProvider = context.read<ApiProvider>();
      final List<Sound> storedSounds = await apiProvider.getStoredSounds(
        widget.match.teamId,
      );

      // Ses ID'sine göre sesi bul
      final sound = storedSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => Sound(
          id: -1,
          title: '',
          soundUrl: '',
          teamId: widget.match.teamId,
          teamName: widget.match.teamName,
          status: '',
          currentMillisecond: 0,
          updatedAt: DateTime.now(),
          isDownloaded: false,
        ),
      );

      // Eğer ses bulunamadıysa (dummy sound döndüyse)
      if (sound.id == -1) {
        print('Sound $soundId not found in local storage');
        return null;
      }

      print('Sound $soundId found in local storage');
      return sound;
    } catch (e) {
      print('Error loading sound from local storage: $e');
      return null;
    }
  }

  void _startLocalTimer(int initialMillisecond) {
    print('Starting local timer at position: $initialMillisecond ms');

    // Önce mevcut zamanlayıcıyı iptal et
    _stopLocalTimer();

    // Başlangıç zamanını ve pozisyonunu kaydet
    _localTimerStartTime = DateTime.now();
    _localCurrentMillisecond = initialMillisecond;

    // Her 50ms'de bir pozisyonu güncelleyen yeni bir zamanlayıcı başlat
    _localPositionTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (_localTimerStartTime != null && mounted) {
        // Başlangıçtan bu yana geçen süreyi hesapla
        final elapsed = DateTime.now()
            .difference(_localTimerStartTime!)
            .inMilliseconds;

        // Pozisyonu güncelle
        setState(() {
          _localCurrentMillisecond = initialMillisecond + elapsed;
        });

        // AudioService pozisyonunu sadece ses çalıyorsa güncelle
        // Bu, AudioService'in kendi pozisyon raporlamasıyla çakışmaları önler
        if (_audioService.isPlaying.value) {
          // Pozisyonu doğrudan güncelle, ancak AudioService'in kendi pozisyonunu ezme
          // Eğer AudioService pozisyonu ile hesaplanan pozisyon arasında büyük fark yoksa
          int currentServicePosition =
              _audioService.position.value.inMilliseconds;
          int positionDiff = (_localCurrentMillisecond - currentServicePosition)
              .abs();

          // Eğer fark 200ms'den fazlaysa güncelle (küçük farkları yok say)
          if (positionDiff > 200) {
            _audioService.position.value = Duration(
              milliseconds: _localCurrentMillisecond,
            );
          }
        }
      }
    });

    // Senkronizasyon kontrolünü ayrıca başlat
    _startSyncCheck();
  }

  void _stopLocalTimer() {
    _localPositionTimer?.cancel();
    _localPositionTimer = null;
    _localTimerStartTime = null;
  }

  Future<void> _playSoundFromStorage(Sound sound, int startPositionMs) async {
    try {
      // Get the local file path
      final String? filePath = await _soundManager.getSoundFilePath(
        sound.teamId,
        sound.id,
      );

      if (filePath == null) {
        print(
          'Sound file not found locally: Team ${sound.teamId}, Sound ${sound.id}',
        );
        // Ses dosyası bulunamadıysa indirmeyi dene
        downloadMissingSound(sound);
        return;
      }

      print('Playing sound from: $filePath at position: $startPositionMs ms');

      // forcePlayLocalAudio metodu dosyayı yükler, pozisyona gider ve çalmaya başlar
      await _audioService.forcePlayLocalAudio(
        filePath,
        startPositionMs: startPositionMs,
      );

      // Start the local timer to track position
      _startLocalTimer(startPositionMs);

      // Lyrics'leri her zaman yükle - bu sound için doğru lyrics'in gösterilmesini sağlar
      _soundManager.getSoundLyrics(sound.teamId, sound.id).then((lyrics) {
        if (lyrics != null && lyrics.isNotEmpty && mounted) {
          setState(() {
            _currentLyrics = lyrics;
          });
          print(
            'Loaded ${lyrics.length} lyrics for sound ${sound.id} in _playSoundFromStorage',
          );
        } else {
          print(
            'No lyrics found for sound ${sound.id} in _playSoundFromStorage',
          );

          // Eğer sound nesnesinin kendi lyrics'i varsa, onları kullan
          if (sound.lyrics != null && sound.lyrics!.isNotEmpty && mounted) {
            setState(() {
              _currentLyrics = sound.lyrics;
            });
            print(
              'Using ${sound.lyrics!.length} lyrics from sound object for sound ${sound.id}',
            );

            // Lyrics'i yerel depoya kaydet
            _soundManager.saveSoundLyrics(
              sound.teamId,
              sound.id,
              sound.lyrics!,
            );
            print('Saved lyrics to local storage for future use');
          }
        }
      });
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _loadSoundFromLocalStorage(
    int soundId,
    String status,
    int currentMillisecond,
  ) async {
    print(
      'Loading sound from local storage: soundId=$soundId, status=$status, position=$currentMillisecond',
    );

    // Öncelikle ses dosyasını yerel depodan yükle
    Sound? storedSound = await _getSoundFromLocalStorage(soundId);
    if (storedSound == null) {
      print('ERROR: Sound $soundId not found in local storage');
      return;
    }

    // Ses dosyasının yolunu al
    final String? filePath = await _soundManager.getSoundFilePath(
      storedSound.teamId,
      storedSound.id,
    );

    if (filePath == null) {
      print('Sound file path not found for sound $soundId');
      return;
    }

    // Güncel ses bilgilerini oluştur
    Sound updatedSound = Sound(
      id: soundId,
      title: storedSound.title,
      soundUrl: storedSound.soundUrl,
      soundImageUrl: storedSound.soundImageUrl,
      teamId: widget.match.teamId,
      teamName: widget.match.teamName,
      status: status,
      currentMillisecond: currentMillisecond,
      updatedAt: DateTime.now(),
      isDownloaded: true,
      lyrics: storedSound.lyrics,
    );

    // UI'ı güncelle
    setState(() {
      _currentSound = updatedSound;

      // Ses listesini güncelle
      int soundIndex = _teamSounds.indexWhere((s) => s.id == soundId);
      if (soundIndex >= 0) {
        _teamSounds[soundIndex] = updatedSound;
      } else {
        _teamSounds.add(updatedSound);
      }
    });

    print('Sound status updated to: $status for sound $soundId');

    // Lyrics'leri her zaman yükle - bu sound için doğru lyrics'in gösterilmesini sağlar
    _soundManager.getSoundLyrics(widget.match.teamId, soundId).then((lyrics) {
      if (lyrics != null && lyrics.isNotEmpty && mounted) {
        setState(() {
          _currentLyrics = lyrics;
        });
        print(
          'Loaded ${lyrics.length} lyrics for sound $soundId in _loadSoundFromLocalStorage',
        );
      } else {
        print(
          'No lyrics found for sound $soundId in _loadSoundFromLocalStorage',
        );
      }
    });

    // Duruma göre ses çalma işlemini yönet
    switch (status) {
      case 'STARTED':
        print(
          'STARTED command received - Playing sound: $soundId at position: $currentMillisecond',
        );
        // Önce mevcut sesi durdur ve temizle
        await _audioService.stop();
        _stopLocalTimer();

        // Yeni sesi çal
        await _audioService.forcePlayLocalAudio(
          filePath,
          startPositionMs: currentMillisecond,
        );
        _startLocalTimer(currentMillisecond);
        break;

      case 'RESUMED':
        print(
          'RESUMED command received - Resuming sound: $soundId at position: $currentMillisecond',
        );
        // Duraklatılmış sesi devam ettir veya yeni pozisyonda çal
        if (_audioService.isPlaying.value) {
          // Zaten çalıyorsa, pozisyonu güncelle
          await _audioService.seek(Duration(milliseconds: currentMillisecond));
        } else {
          // Çalmıyorsa, başlat
          await _audioService.forcePlayLocalAudio(
            filePath,
            startPositionMs: currentMillisecond,
          );
        }
        _startLocalTimer(currentMillisecond);
        break;

      case 'PAUSED':
        print('PAUSED command received - Pausing sound: $soundId');
        await _audioService.pause();
        _stopLocalTimer();
        break;

      case 'STOPPED':
        print('STOPPED command received - Stopping sound: $soundId');
        // Sesi tamamen durdur
        await _audioService.stop();
        _stopLocalTimer();
        break;
    }
  }

  // Eksik ses dosyasını indirme
  void downloadMissingSound(Sound sound) async {
    try {
      // Kullanıcıya bildirim göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sound.title} ses dosyası indiriliyor...'),
          duration: Duration(seconds: 2),
        ),
      );

      // ApiProvider'dan ses bilgilerini al
      final apiProvider = context.read<ApiProvider>();
      final response = await apiProvider.getSoundsByTeam(sound.teamId);

      if (response.success && response.data != null) {
        final serverSounds = response.data!;
        final serverSound = serverSounds.firstWhere(
          (s) => s.id == sound.id,
          orElse: () => Sound(
            id: -1,
            title: '',
            soundUrl: '',
            teamId: sound.teamId,
            teamName: '',
            status: '',
            currentMillisecond: 0,
            updatedAt: DateTime.now(),
            isDownloaded: false,
          ),
        );

        if (serverSound.id != -1) {
          // Tek bir sesi indir (SoundManager'a yeni bir metod eklemek gerekecek)
          List<Sound> soundsToDownload = [serverSound];
          await _soundManager.downloadSpecificSounds(
            soundsToDownload,
            sound.teamId,
          );

          // İndirme tamamlandıktan sonra bildirim göster
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${sound.title} indirildi'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error downloading missing sound: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ses dosyası indirilemedi: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Find the current lyric based on the current playback position
  Lyrics? _findCurrentLyric(int currentSecond) {
    if (_currentLyrics == null || _currentLyrics!.isEmpty) {
      return null;
    }

    // Sort lyrics by second to ensure they're in order
    final sortedLyrics = List<Lyrics>.from(_currentLyrics!);
    sortedLyrics.sort((a, b) => a.second.compareTo(b.second));

    // Find the last lyric that should be displayed at the current time
    Lyrics? currentLyric;

    for (var lyric in sortedLyrics) {
      if (lyric.second <= currentSecond) {
        currentLyric = lyric;
      } else {
        // We've found a lyric that's in the future, so stop here
        break;
      }
    }

    return currentLyric;
  }

  // Get status color based on sound status
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'STARTED':
      case 'RESUMED':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'STOPPED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to build team logo
  Widget _buildTeamLogo(String? logoUrl, String teamName) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: logoUrl != null
          ? Image.network(
              logoUrl,
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildTeamLogoFallback(teamName);
              },
            )
          : _buildTeamLogoFallback(teamName),
    );
  }

  // Helper method to build team logo fallback
  Widget _buildTeamLogoFallback(String teamName) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          teamName.isNotEmpty ? teamName[0].toUpperCase() : '?',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Sunucu ile cihaz arasındaki zaman farkını günceller
  void _updateServerTimeDifference(int serverTime, int localTime) {
    // Zaman farkını hesapla
    final int timeDiff = localTime - serverTime;

    // Son 10 ölçümü sakla (ortalama hesaplamak için)
    _recentTimeDifferences.add(timeDiff);
    if (_recentTimeDifferences.length > 10) {
      _recentTimeDifferences.removeAt(0);
    }

    // Ortalama zaman farkını hesapla (aşırı sapan değerleri filtreleyerek)
    if (_recentTimeDifferences.length >= 3) {
      try {
        // Sapan değerleri filtrele (standart sapmanın 2 katından fazla sapanları çıkar)
        final List<int> filteredDiffs = List<int>.from(_recentTimeDifferences);
        final double mean =
            filteredDiffs.reduce((a, b) => a + b) / filteredDiffs.length;
        final double variance =
            filteredDiffs
                .map((x) => pow(x - mean, 2) as double)
                .reduce((a, b) => a + b) /
            filteredDiffs.length;
        final double stdDev = sqrt(variance);

        final List<int> normalizedDiffs = filteredDiffs
            .where((x) => (x - mean).abs() < 2 * stdDev)
            .toList();

        if (normalizedDiffs.isNotEmpty) {
          _serverTimeDifference =
              normalizedDiffs.reduce((a, b) => a + b) ~/ normalizedDiffs.length;
          print(
            'Updated server time difference: $_serverTimeDifference ms (from ${normalizedDiffs.length} samples)',
          );
        }
      } catch (e) {
        print('Error calculating time difference: $e');
        // Hata durumunda basit ortalama kullan
        _serverTimeDifference =
            _recentTimeDifferences.reduce((a, b) => a + b) ~/
            _recentTimeDifferences.length;
      }
    } else if (_recentTimeDifferences.isNotEmpty) {
      // Çok az örnek varsa, basitçe ortalama al
      _serverTimeDifference =
          _recentTimeDifferences.reduce((a, b) => a + b) ~/
          _recentTimeDifferences.length;
      print('Initial server time difference: $_serverTimeDifference ms');
    }
  }

  // Periyodik senkronizasyon kontrolü için
  void _startSyncCheck() {
    // Mevcut zamanlayıcıyı iptal et
    _syncTimer?.cancel();

    // Her 5 saniyede bir senkronizasyon kontrolü yap
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_audioService.isPlaying.value && _currentSound != null) {
        // Gerçek ses pozisyonu ile hesaplanan pozisyon arasındaki farkı kontrol et
        final actualPosition = _audioService.position.value.inMilliseconds;
        final expectedPosition = _localCurrentMillisecond;

        // Pozisyon farkını hesapla
        final int positionDifference = (actualPosition - expectedPosition)
            .abs();

        // Eğer fark 300ms'den fazlaysa senkronize et, ama sıfıra dönmediğimizden emin ol
        if (positionDifference > 300 && expectedPosition > 0) {
          print(
            'Re-syncing audio: expected=${expectedPosition}ms, actual=${actualPosition}ms, diff=$positionDifference ms',
          );

          // Eğer beklenen pozisyon 0'a çok yakınsa, senkronizasyonu atla
          if (expectedPosition < 200) {
            print('Skipping sync as position is too close to start');
            return;
          }

          // Eğer fark çok büyükse (5 saniyeden fazla), muhtemelen bir hata var
          // veya WebSocket'ten yeni bir pozisyon geldi
          if (positionDifference > 5000) {
            print(
              'Large sync difference detected ($positionDifference ms), restarting local timer',
            );
            // Yerel zamanlayıcıyı yeniden başlat
            _stopLocalTimer();
            // Hangi pozisyonu kullanacağımızı belirle
            // Eğer gerçek pozisyon daha ilerideyse, onu kullan
            // Aksi halde beklenen pozisyonu kullan
            int newPosition = actualPosition > expectedPosition
                ? actualPosition
                : expectedPosition;
            _startLocalTimer(newPosition);
          } else {
            // Normal senkronizasyon: Gerçek pozisyon ve beklenen pozisyon arasındaki fark makul
            _audioService.seek(Duration(milliseconds: expectedPosition));
          }

          // Zamanlayıcıyı da senkronize et
          _localTimerStartTime = DateTime.now();
          _localCurrentMillisecond = expectedPosition;
        }
      }
    });
  }

  // Helper method to get match status text
  String _getMatchStatusText() {
    if (widget.match.isUpcoming()) {
      return 'YAKLAŞAN MAÇ';
    } else if (widget.match.isCompleted()) {
      return 'TAMAMLANDI';
    } else if (widget.match.isInProgress()) {
      return 'DEVAM EDİYOR';
    } else {
      return 'CANLI';
    }
  }

  // Reklam banner'ını oluşturan metod
  Widget _buildAdBanner() {
    // Eğer reklam yükleniyor veya aktif reklam yoksa boş container döndür
    if (_isAdLoading) {
      print('Ad not showing: still loading');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    if (_topBannerAd == null) {
      print('Ad not showing: no active ad found');
      return const SizedBox.shrink();
    }

    print(
      'Showing ad: ${_topBannerAd!.title}, imageUrl: ${_topBannerAd!.imageUrl}',
    );
    return GestureDetector(
      onTap: () async {
        // Reklam URL'sine yönlendir
        if (_topBannerAd?.redirectUrl != null &&
            _topBannerAd!.redirectUrl!.isNotEmpty) {
          final String url = _topBannerAd!.redirectUrl!;
          print('Attempting to launch URL: $url');

          // URL'nin http:// veya https:// ile başladığından emin ol
          String urlToLaunch = url;
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            urlToLaunch = 'https://$url';
            print('URL modified to: $urlToLaunch');
          }

          try {
            print('Launching URL: $urlToLaunch');
            await launchUrlString(
              urlToLaunch,
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            print('Error launching URL with launchUrlString: $e');

            // Fallback olarak Uri ile deneme yap
            try {
              final Uri uri = Uri.parse(urlToLaunch);
              print('Attempting to launch with Uri: $uri');
              // url_launcher paketindeki launchUrl fonksiyonunu kullan
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e2) {
              print('All attempts to launch URL failed: $e2');
            }
          }
        } else {
          print('No redirect URL available or URL is empty');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: _topBannerAd!.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 100,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 100,
              color: Colors.grey[100],
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 100,
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 28),
                  const SizedBox(height: 8),
                  Text(
                    _topBannerAd!.title ?? 'Reklam',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the main content of the screen - Countries Screen style
  Widget _buildContent() {
    return Column(
      children: [
        // Custom App Bar
        _buildAppBar(),

        // Reklam banner'ını app bar ile ana içerik arasına ekle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: _buildAdBanner(),
        ),

        // Main Content
        Expanded(
          child: _isLoading ? _buildLoadingIndicator() : _buildMainContent(),
        ),
      ],
    );
  }

  // Custom App Bar in Countries Screen style
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navigation and info row
          Row(
            children: [
              // Back button
              CircleAvatar(
                backgroundColor: Colors.grey[800],
                radius: 18,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              // WebSocket connection status indicator
              ValueListenableBuilder<bool>(
                valueListenable: _webSocketService.isConnected,
                builder: (context, isConnected, child) {
                  return CircleAvatar(
                    backgroundColor: isConnected
                        ? Colors.green[700]
                        : Colors.red[700],
                    radius: 18,
                    child: Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Match details row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Home team
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildTeamLogo(
                        widget.match.teamLogo,
                        widget.match.teamName,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.match.teamName,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                // Score
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "vs",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // const SizedBox(height: 4),
                        // Text(
                        //   _getMatchStatusText(),
                        //   style: GoogleFonts.montserrat(
                        //     fontWeight: FontWeight.w500,
                        //     fontSize: 10,
                        //     color: Colors.white70,
                        //   ),
                        //   textAlign: TextAlign.center,
                        // ),
                      ],
                    ),
                  ),
                ),

                // Away team
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildTeamLogo(
                        widget.match.getOpponentLogo(),
                        widget.match.getOpponentName(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.match.getOpponentName(),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 0),

          // Match date removed as requested
        ],
      ),
    );
  }

  // Loading indicator
  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
    );
  }

  // Main content with sound card and lyrics
  Widget _buildMainContent() {
    return Column(
      children: [
        // Title
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        //   child: Text(
        //     'Maç Sesleri',
        //     style: GoogleFonts.montserrat(
        //       fontSize: 22,
        //       fontWeight: FontWeight.bold,
        //       color: Colors.white,
        //     ),
        //   ),
        // ),
        // // Sound card and lyrics in white container with rounded corners
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: _buildSoundContent(),
          ),
        ),
      ],
    );
  }

  // Sound card and lyrics content
  Widget _buildSoundContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound card
          if (_currentSound != null) _buildSoundCard(_currentSound!),

          // Lyrics section
          if (_currentLyrics != null && _currentLyrics!.isNotEmpty)
            _buildLyricsCard(),

          // Bottom Banner Ad
          _buildBottomBannerAd(),
        ],
      ),
    );
  }

  // Sound card with image, title, and controls
  Widget _buildSoundCard(Sound sound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound header with title and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withBlue(220),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sound title and artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Çok sayıda çubuktan oluşan ses dalgası animasyonu
                      Row(
                        children: [
                          Container(
                            height: 40,
                            width: 150,
                            child: StreamBuilder<int>(
                              // Her 100ms'de bir yenilenen stream
                              stream: Stream.periodic(
                                const Duration(milliseconds: 100),
                                (i) => i,
                              ),
                              builder: (context, snapshot) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(
                                      25, // Çubuk sayısı
                                      (index) {
                                        // Ses çalınıyorsa rastgele yükseklikler oluştur
                                        final isPlaying =
                                            sound.status == 'STARTED' ||
                                            sound.status == 'RESUMED';

                                        // Ortaya doğru yükselen bir dağılım için
                                        final position =
                                            (index - 12.5).abs() / 12.5;
                                        final baseHeight = isPlaying
                                            ? 30.0 * (1 - position * 0.7)
                                            : 5.0;

                                        // Rastgele değişim ekle
                                        final randomFactor = isPlaying
                                            ? (Random().nextDouble() * 10 - 5)
                                            : 0.0;
                                        final height =
                                            (baseHeight + randomFactor).clamp(
                                              3.0,
                                              35.0,
                                            );

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          child: AnimatedContainer(
                                            duration: Duration(
                                              milliseconds: isPlaying ? 200 : 0,
                                            ),
                                            width: 3,
                                            height: height,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.cyan.shade300,
                                                  Colors.blue.shade400,
                                                  Colors.purple.shade400,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Boş alan bırakıyoruz
                          Expanded(child: Container()),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge ve flashlight icon yan yana
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(sound.status).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sound.status == 'STARTED' ||
                                    sound.status == 'RESUMED'
                                ? Icons.play_arrow
                                : sound.status == 'PAUSED'
                                ? Icons.pause
                                : Icons.stop,
                            color: Colors.white,
                            size: 16,
                          ),
                          //const SizedBox(width: 4),
                          // Text(
                          //   // Durum metnini daha belirgin hale getiriyoruz
                          //   sound.status == 'STARTED' ||
                          //           sound.status == 'RESUMED'
                          //       ? 'Oynatılıyor'
                          //       : sound.status == 'PAUSED'
                          //       ? 'Duraklatıldı'
                          //       : sound.status == 'STOPPED'
                          //       ? 'Durduruldu'
                          //       : '',
                          //   // Debug için durumu yazdırıyoruz
                          //   // '${sound.status}',
                          //   style: GoogleFonts.montserrat(
                          //     fontSize: 12,
                          //     color: Colors.white,
                          //     fontWeight: FontWeight.w500,
                          //   ),
                          // ),
                        ],
                      ),
                    ),

                    // El feneri simgesi - her zaman görünür
                    const SizedBox(width: 10),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _flashlightEnabled
                            ? AppTheme.primaryColor.withOpacity(0.8)
                            : Colors.grey.withOpacity(0.3),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.flashlight_on,
                          color: _flashlightEnabled
                              ? Colors.white
                              : Colors.grey[400],
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lyrics card
  Widget _buildLyricsCard() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _audioService.position,
      builder: (context, position, child) {
        final currentSecond = position.inSeconds;

        // Eğer şarkı sözleri yoksa ve çalan bir ses varsa, lyrics'i yüklemeyi dene
        if ((_currentLyrics == null || _currentLyrics!.isEmpty) &&
            _currentSound != null) {
          // Asenkron olarak lyrics'i yüklemeyi başlat
          _loadLyricsForSound(widget.match.teamId, _currentSound!.id);

          // Lyrics yüklenene kadar bir yükleniyor göstergesi göster
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.primaryColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Şarkı sözleri yükleniyor...',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (_currentLyrics == null || _currentLyrics!.isEmpty) {
          return const SizedBox.shrink();
        }

        // Şarkı sözlerini sırala
        final sortedLyrics = List<Lyrics>.from(_currentLyrics!);
        sortedLyrics.sort((a, b) => a.second.compareTo(b.second));

        // Mevcut şarkı sözünü bul
        final currentLyric = _findCurrentLyric(currentSecond);
        final int currentIndex = currentLyric != null
            ? sortedLyrics.indexWhere((lyric) => lyric.id == currentLyric.id)
            : -1;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.8),
                AppTheme.primaryColor.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lyrics header - daha şık bir başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'LYRICS',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Lyrics scrollable container
              Container(
                height: 220,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ShaderMask(
                  shaderCallback: (Rect rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.1, 0.9, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    itemCount: sortedLyrics.length,
                    itemBuilder: (context, index) {
                      final lyric = sortedLyrics[index];
                      final isCurrentLyric = currentIndex == index;
                      final isPastLyric = currentIndex > index;
                      final isNextLyric = index == currentIndex + 1;

                      // Şarkı sözü satırının animasyonlu geçişi için
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: EdgeInsets.symmetric(
                          vertical: isCurrentLyric ? 12 : 6,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: GoogleFonts.montserrat(
                            fontSize: isCurrentLyric
                                ? 18
                                : isNextLyric
                                ? 16
                                : 14,
                            fontWeight: isCurrentLyric
                                ? FontWeight.w700
                                : isNextLyric
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isCurrentLyric
                                ? Colors.white
                                : isPastLyric
                                ? Colors.white.withOpacity(0.5)
                                : isNextLyric
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white.withOpacity(0.3),
                            height: 1.5,
                            letterSpacing: isCurrentLyric ? 0.5 : 0,
                          ),
                          child: Row(
                            children: [
                              if (isCurrentLyric)
                                Container(
                                  width: 4,
                                  height: 24,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  lyric.lyric,
                                  textAlign: isCurrentLyric
                                      ? TextAlign.left
                                      : TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Minimum boşluk
              const SizedBox(height: 5),
            ],
          ),
        );
      },
    );
  }

  // Bottom Banner Ad Container
  Widget _buildBottomBannerAd() {
    // Reklam yoksa boş container döndür (gizli)
    if (_bottomBannerAd == null) {
      return const SizedBox.shrink();
    }

    // Reklam varsa göster
    return Container(
      height: 80,
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (_bottomBannerAd!.redirectUrl != null &&
                _bottomBannerAd!.redirectUrl!.isNotEmpty) {
              launchUrlString(_bottomBannerAd!.redirectUrl!);
            }
          },
          child: CachedNetworkImage(
            imageUrl: _bottomBannerAd!.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            errorWidget: (context, url, error) =>
                Center(child: Icon(Icons.error, color: Colors.grey[400])),
          ),
        ),
      ),
    );
  }

  // Bu metod artık kullanılmıyor, tüm reklamlar _loadAllBannerAds ile yükleniyor
}
